--[[
TheNexusAvenger

Handles saving data for a DataStore key.
--]]

local SaveData = {}
SaveData.__index = SaveData

local HttpService = game:GetService("HttpService")



--[[
Creates the save data instance.
--]]
function SaveData.new(DataStoreName,Key,DataStoreService,MessagingService)
    --Create the object.
    local SaveDataObject = {}
    setmetatable(SaveDataObject,SaveData)

    --Initialize the data.
    SaveDataObject.DataStoreName = DataStoreName
    SaveDataObject.DataStoreKey = Key
    SaveDataObject.MessagingServiceKey = "NSD_"..SaveDataObject.DataStoreKey
    SaveDataObject.DataStoreService = DataStoreService
    SaveDataObject.MessagingService = MessagingService
    SaveDataObject:Initialize()

    --Return the object.
    return SaveDataObject
end

--[[
Initializes the data and connections.
--]]
function SaveData:Initialize()
    self.Connected = true
    self.AutoSaveDelay = 5
    self.AllowOverwriteOfFailedLoad = false
    self.SendDataChangeUpdates = true
    self.DataLoadSuccessful = false
    self.Data = {}
    self.PendingUpdates = {}
    self.KeysPendingFetchUpdates = {}
    self.OnUpdateEvents = {}

    --Connect the messaging service.
    local Worked,ErrorMessage = pcall(function()
        self.MessagingServiceListenEvent = self.MessagingService:SubscribeAsync(self.MessagingServiceKey,function(Message)
            self:HandleRemoteChange(HttpService:JSONDecode(Message.Data))
        end)
    end)
    if not Worked then
        warn("Failed to subscribe to changes for "..self.MessagingServiceKey.." because "..tostring(ErrorMessage))
    end

    --Get the DataStore.
    local Worked,DataStore = pcall(function()
        return self.DataStoreService:GetDataStore(self.DataStoreName)
    end)
    if not Worked then
        error("Failed to get DataStore for "..self.DataStoreName.." because "..tostring(DataStore))
        return
    end
    self.DataStore = DataStore

    --Load the data.
    local Worked,ErrorMessage = pcall(function()
        self.Data = DataStore:GetAsync(self.DataStoreKey) or {}
        self.DataLoadSuccessful = true
    end)
    if not Worked then
        warn("Failed to get data from "..self.DataStoreName.." -> "..self.DataStoreKey.." because "..tostring(ErrorMessage))
    end
end

--[[
Starts flushing the data in the background.
--]]
function SaveData:StartBackgroundFlushing()
    coroutine.wrap(function()
        while self.Connected do
            wait(self.AutoSaveDelay)
            pcall(function()
                if self.Connected then
                    self:Flush()
                end
            end)
        end
    end)()
end

--[[
Sets if messages are sent when a key is
updated or if the data needs to be re-fetched (i.e. string
or entry is >1000 characters). By default, this is true.
--]]
function SaveData:SetSendDataChangeUpdates(Value)
    self.SendDataChangeUpdates = Value
end

--[[
Sets if data can be overwriten if the loading
of data failed. This should be kept true if player data
is involved. By default, this is true.
--]]
function SaveData:SetAllowOverwriteOfFailedLoad(Value)
    self.AllowOverwriteOfFailedLoad = Value
end

--[[
Returns if the data loaded successfully. If an error
occured (such as a DataStore failure), false is returned.
--]]
function SaveData:DataLoadedSuccessfully()
    return self.DataLoadSuccessful
end

--[[
Returns if an object is too long to send.
--]]
function SaveData:CanSendObject(Object)
    return string.len(HttpService:JSONEncode(HttpService:JSONEncode(Object))) <= 850
end

--[[
Publishes a change to the messaging service.
--]]
function SaveData:PublishChange(Object)
    if self.SendDataChangeUpdates then
        self.MessagingService:PublishAsync(self.MessagingServiceKey,HttpService:JSONEncode(Object))
    end
end

--[[
Publishes a change to the messaging service in the background.
--]]
function SaveData:PublishChangeBackground(Object)
    if self.SendDataChangeUpdates then
        coroutine.wrap(function()
            local Worked,ErrorMessage = pcall(function()
                self:PublishChange(Object)
            end)
            if not Worked then
                warn("Failed to publish change for "..self.MessagingServiceKey.." because "..tostring(ErrorMessage))
            end
        end)()
    end
end

--[[
Internally sets a value. Invokes OnUpdate callbacks if they
are connected.
--]]
function SaveData:InternalSet(Key,Value)
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
function SaveData:HandleRemoteChange(Object)
    --Ignore remote changes if the DataStore didn't load.
    if not self.DataStore then
        return
    end

    if Object.Action then
        if Object.Action == "Fetch" then
            --Fetch data that was too long to send.
            local Worked,ErrorMessage = pcall(function()
                local NewData = self.DataStore:GetAsync(self.DataStoreKey) or {}
                for _,Key in pairs(Object.Keys) do
                    self:InternalSet(Key,NewData[Key])
                end
            end)
            if not Worked then
                warn("Failed to fetch changes from "..self.DataStoreName.." -> "..self.DataStoreKey.." because "..tostring(ErrorMessage))
            end
        elseif Object.Action == "Set" then
            --Set the value.
            local OriginalValue = self.Data[Object.Key]
            self:InternalSet(Object.Key,Object.Value)

            --Add the update function.
            table.insert(self.PendingUpdates,{
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
function SaveData:Flush()
    --Return if there is no data to change.
    if #self.PendingUpdates == 0 and self.KeysPendingFetchUpdates == 0 then
        return
    end

    --Warn if the data can't be saved.
    if not self.DataStore then
        warn("DataStore did not initialize correctly; unable to save data for "..self.DataStoreName.." -> "..self.DataStoreKey)
        return
    end
    if not self:DataLoadedSuccessfully() and not self.AllowOverwriteOfFailedLoad then
        warn("The data failed to load; refusing to save data for "..self.DataStoreName.." -> "..self.DataStoreKey)
        return
    end

    --Update the data.
    if #self.PendingUpdates > 0 then
        self.DataStore:UpdateAsync(self.DataStoreKey,function(OldData)
            OldData = OldData or {}

            --Invoke the update methods.
            for _,PendingUpdate in pairs(self.PendingUpdates) do
                local Keys,UpdateFunction = PendingUpdate.Keys,PendingUpdate.UpdateFunction
            
                --Get the values of the keys.
                local Values = {}
                for i,Key in pairs(Keys) do
                    Values[i] = self.Data[Key]
                end

                --Update the values.
                for i,Value in pairs({UpdateFunction(unpack(Values))}) do
                    local Key = Keys[i]
                    if Key then
                        self:InternalSet(Key,Value)
                        OldData[Key] = Value
                    end
                end
            end

            --Clear the update methods.
            self.PendingUpdates = {}

            --Set the other keys.
            for Key,Value in pairs(OldData) do
                self:InternalSet(Key,Value)
            end

            --Return the modified data.
            return OldData
        end)
    end

    --Invoke the update message.
    if #self.KeysPendingFetchUpdates > 0 then
        local Worked,ErrorMessage = pcall(function()
            self:PublishChange({Action="Fetch",Keys=self.KeysPendingFetchUpdates})
            self.KeysPendingFetchUpdates = {}
        end)
        if not Worked then
            warn("Failed to publish change for "..self.MessagingServiceKey.." because "..tostring(ErrorMessage))
        end
    end
end

--[[
Returns the stored value for a given key.
--]]
function SaveData:Get(Key)
    return self.Data[Key]
end

--[[
Sets the stored value for a given key.
--]]
function SaveData:Set(Key,Value)
    --Set the value.
    self:InternalSet(Key,Value)

    --Invoke the change object.
    local ActionObject = {Action="Set",Key=Key,Value=Value}
    if self:CanSendObject(ActionObject) then
        self:PublishChangeBackground(ActionObject)
    else
        table.insert(self.KeysPendingFetchUpdates,Key)
    end
    
    --Add the update function.
    table.insert(self.PendingUpdates,{
        Keys = {Key},
        UpdateFunction = function(OldValue)
            return self.Data[Key]
        end,
    })
end

--[[
Increments the stored value for a given key.
--]]
function SaveData:Increment(Key,Value)
    self:Set(Key,(self.Data[Key] or 0) + Value)
end

--[[
Updates and saves (flushes) the changed values for the key
or keys. If multiple keys are given, the update function
will pass the old values and expect the new values to be returned.
This is intended for important updates that need to happen together.
--]]
function SaveData:Update(Keys,UpdateFunction)
    --Convert the key to a table.
    if type(Keys) == "string" then
        Keys = {Keys}
    end

    --Add the keys to fetch.
    for _,Key in pairs(Keys) do
        table.insert(self.KeysPendingFetchUpdates,Key)
    end

    --Add the update function.
    table.insert(self.PendingUpdates,{
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
function SaveData:OnUpdate(Key,Callback)
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
function SaveData:Disconnect()
    self.Connected = false

    --Disconnect the OnUpdates.
    for _,Event in pairs(self.OnUpdateEvents) do
        Event:Destroy()
    end
    self.OnUpdateEvents = {}

    --Disconnect the messaging service.
    if self.MessagingServiceListenEvent then
        self.MessagingServiceListenEvent:Disconnect()
        self.MessagingServiceListenEvent = nil
    end

    --Flush the data.
    self:Flush()
end



return SaveData