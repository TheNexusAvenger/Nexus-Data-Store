--Implementation of SaveData that does not use external services.
--This should only be used for testing or DataStores going offline.
--!strict

local SaveData = require(script.Parent:WaitForChild("SaveData"))

local LocalSaveData = {}
LocalSaveData.__index = LocalSaveData

export type LocalSaveData = {
    Data: {[string]: any},
    OnUpdateEvents: {[string]: BindableEvent},
} & typeof(setmetatable({}, LocalSaveData))



--[[
Creates the memory save data instance.
--]]
function LocalSaveData.new(): LocalSaveData
    return setmetatable({
        Data = {},
        OnUpdateEvents = {},
    }, LocalSaveData) :: LocalSaveData
end

--[[
Sets if messages are sent when a key is
updated or if the data needs to be re-fetched (i.e. string
or entry is >1000 characters). By default, this is true.
--]]
function LocalSaveData.SetSendDataChangeUpdates(self: LocalSaveData, Value: boolean): ()
    --No implementation.
end

--[[
Sets if data can be overwriten if the loading
of data failed. This should be kept true if player data
is involved. By default, this is true.
--]]
function LocalSaveData.SetAllowOverwriteOfFailedLoad(self: LocalSaveData, Value: boolean): ()
    --No implementation.
end

--[[
Returns if the data loaded successfully. If an error
occured (such as a DataStore failure), false is returned.
--]]
function LocalSaveData.DataLoadedSuccessfully(self: LocalSaveData): boolean
    return false
end

--[[
Flushes the data to the DataStore. If the data failed
to initialize and SetAllowOverwriteOfFailedLoad was not set
to true, no data will be flushed to prevent overwriting data.
--]]
function LocalSaveData.Flush(self: LocalSaveData): ()
    --No implementation.
end

--[[
Returns the stored value for a given key.
--]]
function LocalSaveData.Get(self: LocalSaveData, Key: string): any
    return self.Data[Key]
end

--[[
Sets the stored value for a given key.
--]]
function LocalSaveData.Set(self: LocalSaveData, Key: string, Value: any): ()
    --Ignore the set if the value is the same.
    if Value == self:Get(Key) then
        return
    end

    --Set the value and fire the changed event if it exists.
    self.Data[Key] = Value
    if self.OnUpdateEvents[Key] then
        self.OnUpdateEvents[Key]:Fire(Value)
    end
end

--[[
Increments the stored value for a given key.
--]]
function LocalSaveData.Increment(self: LocalSaveData, Key: string, Value: number): ()
    self:Set(Key, (self.Data[Key] or 0) + Value)
end

--[[
Updates and saves (flushes) the changed values for the key
or keys. If multiple keys are given, the update function
will pass the old values and expect the new values to be returned.
This is intended for important updates that need to happen together.
--]]
function LocalSaveData.Update<T...>(self: LocalSaveData, Keys: string | {string}, UpdateFunction: (T...) -> (T...))
    --Convert the key to a table.
    if type(Keys) == "string" then
        Keys = {Keys}
    end

    --Get the current values.
    local Values = {} :: {any}
    for i, Key in Keys :: {string} do
        Values[i] = self:Get(Key)
    end

    --Update the values.
    local NewValues = table.pack(UpdateFunction(table.unpack(Values)))
    for i, Key in Keys :: {string} do
        self:Set(Key, NewValues[i])
    end
end

--[[
Invokes the given callback when the value for a given
key changes. Returns the connection to disconnect the
changes.
--]]
function LocalSaveData.OnUpdate(self: LocalSaveData, Key: string, Callback: (any) -> ()): RBXScriptConnection
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
function LocalSaveData.Disconnect(self: LocalSaveData): ()
    for _, Event in self.OnUpdateEvents do
        Event:Destroy()
    end
    self.OnUpdateEvents = {}
end



return LocalSaveData