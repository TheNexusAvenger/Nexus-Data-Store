--[[
TheNexusAvenger

Handles saving data for a DataStore key.
--]]
--!strict

local SaveData = {}
SaveData.__index = SaveData

local HttpService = game:GetService("HttpService")

export type SaveData = {
    new: (DataStoreName: string, Key: string, DataStoreService: DataStoreService, MessagingService: MessagingService) -> (SaveDataInternal),
    SetSendDataChangeUpdates: (self: SaveData, Value: boolean) -> (),
    SetAllowOverwriteOfFailedLoad: (self: SaveData, Value: boolean) -> (),
    DataLoadedSuccessfully: (self: SaveData) -> (boolean),
    Flush: (self: SaveData) -> (),
    Get: (self: SaveData, Key: string) -> (any),
    Set: (self: SaveData, Key: string, Value: any) -> (),
    Increment: (self: SaveData, Key: string, Value: number) -> (),
    Update: <T...>(self: SaveData, Keys: string | {string}, UpdateFunction: (T...) -> (T...)) -> (),
    OnUpdate: (self: SaveData, Key: string, Callback: (any) -> ()) -> RBXScriptConnection,
}

export type SaveDataInternal = SaveData & {
    StartBackgroundFlushing: (self: SaveData) -> (),
    Disconnect: (self: SaveData) -> (),
}


--[[
Creates the save data instance.
--]]
function SaveData.new(DataStoreName: string, Key: string, DataStoreService: DataStoreService, MessagingService: MessagingService): SaveDataInternal
    --Create the object.
    local SaveDataObject = {}
    setmetatable(SaveDataObject, SaveData)

    --Initialize the data.
    SaveDataObject.DataStoreName = DataStoreName
    SaveDataObject.DataStoreKey = Key
    SaveDataObject.MessagingServiceKey = "NSD_"..SaveDataObject.DataStoreKey
    SaveDataObject.DataStoreService = DataStoreService
    SaveDataObject.MessagingService = MessagingService
    SaveDataObject:Initialize()

    --Return the object.
    return (SaveDataObject :: any) :: SaveDataInternal
end

--[[
Initializes the data and connections.
--]]
function SaveData:Initialize(): ()
    self.Connected = true
    self.AutoSaveDelay = 10
    self.MessagingServiceBufferTime = 10
    self.AllowOverwriteOfFailedLoad = false
    self.SendDataChangeUpdates = true
    self.DataLoadSuccessful = false
    self.Data = {}
    self.PendingUpdates = {}
    self.KeysPendingFetchUpdates = {}
    self.OnUpdateEvents = {}
    self.SyncId = HttpService:GenerateGUID()
    self.LastKeyUpdateMessageTimes = {}
    self.QueuedKeyUpdateMessages = {}

    --Connect the messaging service.
    xpcall(function()
        self.MessagingServiceListenEvent = self.MessagingService:SubscribeAsync(self.MessagingServiceKey, function(Message)
            self:HandleRemoteChange(HttpService:JSONDecode(Message.Data))
        end)
    end, function(ErrorMessage: string): ()
        warn("Failed to subscribe to changes for "..tostring(self.MessagingServiceKey).." because "..tostring(ErrorMessage))
    end)

    --Get the DataStore.
    local Worked,DataStore = pcall(function()
        return self.DataStoreService:GetDataStore(self.DataStoreName)
    end)
    if not Worked then
        error("Failed to get DataStore for "..tostring(self.DataStoreName).." because "..tostring(DataStore))
        return
    end
    self.DataStore = DataStore

    --Load the data.
    xpcall(function()
        self.Data = DataStore:GetAsync(self.DataStoreKey) or {}
        self.DataLoadSuccessful = true
    end, function(ErrorMessage: string): ()
        warn("Failed to get data from "..tostring(self.DataStoreName).." -> "..tostring(self.DataStoreKey).." because "..tostring(ErrorMessage))
    end)
end

--[[
Starts flushing the data in the background.
--]]
function SaveData:StartBackgroundFlushing(): ()
    task.spawn(function()
        while self.Connected do
            task.wait(self.AutoSaveDelay)
            pcall(function()
                if self.Connected then
                    self:Flush()
                end
            end)
        end
    end)
end

--[[
Sets if messages are sent when a key is
updated or if the data needs to be re-fetched (i.e. string
or entry is >1000 characters). By default, this is true.
--]]
function SaveData:SetSendDataChangeUpdates(Value: boolean): ()
    self.SendDataChangeUpdates = Value
end

--[[
Sets if data can be overwriten if the loading
of data failed. This should be kept true if player data
is involved. By default, this is true.
--]]
function SaveData:SetAllowOverwriteOfFailedLoad(Value: boolean): ()
    self.AllowOverwriteOfFailedLoad = Value
end

--[[
Returns if the data loaded successfully. If an error
occured (such as a DataStore failure), false is returned.
--]]
function SaveData:DataLoadedSuccessfully(): boolean
    return self.DataLoadSuccessful
end

--[[
Returns if an object is below the limit of sending
through the messaging service.
--]]
function SaveData:CanSendObject(Object: any): boolean
    --This looks weird because the limit is by data, not by message length.
    --1 JSONEncode is required to convert the message to a string, then another
    --JSONEncode is required for the BulkMessagingService. The last JSONEncode
    --seems to be done internally for escaping characters.
    return string.len(HttpService:JSONEncode(HttpService:JSONEncode(HttpService:JSONEncode(Object)))) <= 800
end

--[[
Publishes a change to the messaging service.
--]]
function SaveData:PublishChange(Object: any): ()
    if self.SendDataChangeUpdates then
        self.MessagingService:PublishAsync(self.MessagingServiceKey, HttpService:JSONEncode(Object))
    end
end

--[[
Publishes a change to the messaging service in the background.
--]]
function SaveData:PublishChangeBackground(Object: any): ()
    if self.SendDataChangeUpdates then
        task.spawn(function()
            xpcall(function()
                local Key = Object.Key
                if Object.Action == "Set" and Key and self.MessagingServiceBufferTime > 0 then
                    if not self.LastKeyUpdateMessageTimes[Key] or tick() - self.LastKeyUpdateMessageTimes[Key] >= self.MessagingServiceBufferTime then
                        self.LastKeyUpdateMessageTimes[Key] = tick()
                        self:PublishChange(Object)
                    elseif not self.QueuedKeyUpdateMessages[Object.Key] then
                        self.QueuedKeyUpdateMessages[Key] = true
                        task.delay(self.MessagingServiceBufferTime - (tick() - self.LastKeyUpdateMessageTimes[Key]), function()
                            self.QueuedKeyUpdateMessages[Key] = nil
                            self:PublishChangeBackground({Action = "Set", Key = Key, Value = self:Get(Key), SyncId = self.SyncId})
                        end)
                    end
                else
                    self:PublishChange(Object)
                end
            end, function(ErrorMessage: string): ()
                warn("Failed to publish change for "..tostring(self.MessagingServiceKey).." because "..tostring(ErrorMessage))
            end)
        end)
    end
end

--[[
Internally sets a value. Invokes OnUpdate callbacks if they
are connected.
--]]
function SaveData:InternalSet(Key: string, Value: any): ()
    --Set the value.
    local ExistingValue = self.Data[Key]
    self.Data[Key] = Value

    --Invoke the OnUpdate connections.
    if Value ~= ExistingValue and self.OnUpdateEvents[Key] then
        self.OnUpdateEvents[Key]:Fire(Value)
    end
end

--[[
Handles remote changes being invoked by the messaging service.
--]]
function SaveData:HandleRemoteChange(Object: any): ()
    --Ignore remote changes if the DataStore didn't load.
    if not self.DataStore then
        return
    end

    if Object.Action and Object.SyncId ~= self.SyncId then
        if Object.Action == "Fetch" then
            --Fetch data that was too long to send.
            xpcall(function()
                local NewData = self.DataStore:GetAsync(self.DataStoreKey) or {}
                for _, Key in Object.Keys do
                    self:InternalSet(Key, NewData[Key])
                end
            end, function(ErrorMessage: string): ()
                warn("Failed to fetch changes from "..tostring(self.DataStoreName).." -> "..tostring(self.DataStoreKey).." because "..tostring(ErrorMessage))
            end)
        elseif Object.Action == "Set" then
            --Set the value.
            self:InternalSet(Object.Key, Object.Value)

            --Add the update function.
            table.insert(self.PendingUpdates, {
                Keys = {Object.Key},
                UpdateFunction = function(OldValue)
                    return self.Data[Object.Key]
                end,
            })
        end
    end
end

--[[
Flushes the data to the DataStore. If the data failed
to initialize and SetAllowOverwriteOfFailedLoad was not set
to true, no data will be flushed to prevent overwriting data.
--]]
function SaveData:Flush(): ()
    --Return if there is no data to change.
    if #self.PendingUpdates == 0 and #self.KeysPendingFetchUpdates == 0 then
        return
    end

    --Warn if the data can't be saved.
    if not self.DataStore then
        warn("DataStore did not initialize correctly; unable to save data for "..tostring(self.DataStoreName).." -> "..tostring(self.DataStoreKey))
        return
    end
    if not self:DataLoadedSuccessfully() and not self.AllowOverwriteOfFailedLoad then
        warn("The data failed to load; refusing to save data for "..tostring(self.DataStoreName).." -> "..tostring(self.DataStoreKey))
        return
    end

    --Update the data.
    if #self.PendingUpdates > 0 then
        self.DataStore:UpdateAsync(self.DataStoreKey, function(OldData: any): any
            OldData = OldData or {}

            --Invoke the update methods.
            for _, PendingUpdate in self.PendingUpdates :: {{Keys: {string}, UpdateFunction: (any) -> (any)}} do
                local Keys, UpdateFunction = PendingUpdate.Keys, PendingUpdate.UpdateFunction

                --Get the values of the keys.
                local Values = {}
                for i, Key in Keys do
                    Values[i] = self.Data[Key]
                end

                --Update the values.
                local NewValues = table.pack(UpdateFunction(table.unpack(Values)))
                for i, Key in Keys do
                    local Value = NewValues[i]
                    self:InternalSet(Key, Value)
                    OldData[Key] = Value
                end
            end

            --Clear the update methods.
            self.PendingUpdates = {}

            --Set the other keys.
            for Key, Value in OldData do
                self:InternalSet(Key, Value)
            end

            --Return the modified data.
            return OldData
        end)
    end

    --Invoke the update message.
    if #self.KeysPendingFetchUpdates > 0 then
        xpcall(function()
            self:PublishChange({Action = "Fetch", Keys = self.KeysPendingFetchUpdates, SyncId = self.SyncId})
            self.KeysPendingFetchUpdates = {}
        end, function(ErrorMessage: string): ()
            warn("Failed to publish change for "..tostring(self.MessagingServiceKey).." because "..tostring(ErrorMessage))
        end)
    end
end

--[[
Returns the stored value for a given key.
--]]
function SaveData:Get(Key: string): any
    return self.Data[Key]
end

--[[
Sets the stored value for a given key.
--]]
function SaveData:Set(Key: string, Value: any): ()
    --Set the value.
    self:InternalSet(Key, Value)

    --Invoke the change object.
    local ActionObject = {Action = "Set", Key = Key, Value = Value, SyncId = self.SyncId}
    if self:CanSendObject(ActionObject) then
        self:PublishChangeBackground(ActionObject)
    else
        table.insert(self.KeysPendingFetchUpdates, Key)
    end
    
    --Add the update function.
    table.insert(self.PendingUpdates, {
        Keys = {Key},
        UpdateFunction = function(OldValue: any): any
            return self.Data[Key]
        end,
    })
end

--[[
Increments the stored value for a given key.
--]]
function SaveData:Increment(Key: string, Value: number): ()
    self:Set(Key,(self.Data[Key] or 0) + Value)
end

--[[
Updates and saves (flushes) the changed values for the key
or keys. If multiple keys are given, the update function
will pass the old values and expect the new values to be returned.
This is intended for important updates that need to happen together.
--]]
function SaveData:Update<T...>(Keys: string | {string}, UpdateFunction: (T...) -> (T...))
    --Convert the key to a table.
    if type(Keys) == "string" then
        Keys = {Keys}
    end

    --Add the keys to fetch.
    for _, Key in Keys :: {string} do
        table.insert(self.KeysPendingFetchUpdates,Key)
    end

    --Add the update function.
    table.insert(self.PendingUpdates, {
        Keys = Keys,
        UpdateFunction = UpdateFunction,
    })

    --Flush the data.
    self:Flush()
end

--[[
Invokes the given callback when the value for a given
key changes. Returns the connection to disconnect the
changes.
--]]
function SaveData:OnUpdate(Key: string, Callback: (any) -> ()): RBXScriptConnection
    --Create the event.
    if not self.OnUpdateEvents[Key] then
        self.OnUpdateEvents[Key] = Instance.new("BindableEvent")
    end

    --Connect the event.
    return self.OnUpdateEvents[Key].Event:Connect(Callback)
end

--[[
Disconnects the events.
--]]
function SaveData:Disconnect(): ()
    self.Connected = false

    --Disconnect the OnUpdates.
    for _, Event in self.OnUpdateEvents do
        Event:Destroy()
    end
    self.OnUpdateEvents = {}

    --Disconnect the messaging service.
    if self.MessagingServiceListenEvent then
        self.MessagingServiceListenEvent:Disconnect()
        self.MessagingServiceListenEvent = nil :: any
    end

    --Flush the data.
    self:Flush()
end



return SaveData