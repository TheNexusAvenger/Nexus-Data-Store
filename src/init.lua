--[[
TheNexusAvenger

Main module for Nexus Data Store.
Intended to be a replacement for Stravant's PlayerDataStore
with the additions of cross-server updating.

GitHub: https://github.com/TheNexusAvenger/Nexus-Data-Store
--]]
--!strict

local PLAYERDATASTORE_DATA_STORE = "PlayerDataStore_PlayerData"
local PLAYERDATASTORE_ID_PREFIX = "PlayerList$"

local SaveData = require(script:WaitForChild("SaveData"))
local BulkMessagingService = require(script:WaitForChild("BulkMessagingService"))

local NexusDataStore = {}
NexusDataStore.SaveDataCache = {} :: {[string]: {[string]: SaveData.SaveDataInternal}}
NexusDataStore.SaveDataCacheEvents = {}
NexusDataStore.SaveDataLoading = {}
NexusDataStore.SaveDataLoadedEvent = Instance.new("BindableEvent")
NexusDataStore.DataStoreService = game:GetService("DataStoreService")
NexusDataStore.MessagingService = BulkMessagingService.new(game:GetService("MessagingService")) :: (MessagingService & {StartPassiveLoop: (any) -> ()})
NexusDataStore.MessagingService:StartPassiveLoop()

export type SaveData = SaveData.SaveData

export type NexusDataStore = {
    GetDataStore: (self: NexusDataStore, DataStoreName: string, Key: string) -> (SaveData),
    GetSaveDataById: (self: NexusDataStore, UserId: number) -> (SaveData),
    GetSaveData: (self: NexusDataStore, PlayerOrId: Player | number) -> (SaveData),
    RemoveFromCache: (self: NexusDataStore, DataStoreName: Player | number | string, Key: string?) -> (),
}



--[[
Returns the SavaData structure for
a given DataStore key.
--]]
function NexusDataStore:GetDataStore(DataStoreName: string, Key: string): SaveData
    --Add the cache entry if it doesn't exist.
    if not self.SaveDataCache[DataStoreName] then
        self.SaveDataCache[DataStoreName] = {}
        self.SaveDataLoading[DataStoreName] = {}
    end
    while self.SaveDataLoading[DataStoreName][Key] do
        self.SaveDataLoadedEvent.Event:Wait()
    end
    if not self.SaveDataCache[DataStoreName][Key] then
        self.SaveDataLoading[DataStoreName][Key] = true
        self.SaveDataCache[DataStoreName][Key] = SaveData.new(DataStoreName, Key, self.DataStoreService, self.MessagingService)
        self.SaveDataCache[DataStoreName][Key]:StartBackgroundFlushing()
        self.SaveDataLoading[DataStoreName][Key] = nil
        self.SaveDataLoadedEvent:Fire()
    end

    --Return the cached entry.
    return self.SaveDataCache[DataStoreName][Key] :: SaveData
end

--[[
Returns the SavaData structure for
a given user id.
--]]
function NexusDataStore:GetSaveDataById(UserId: number): SaveData
    return self:GetDataStore(PLAYERDATASTORE_DATA_STORE, PLAYERDATASTORE_ID_PREFIX..tostring(UserId)) :: SaveData
end

--[[
Returns the SavaData structure for
a given player. Automatically flushes
data when the player leaves, but does
not remove the data from the cache in
case it is still neded.
--]]
function NexusDataStore:GetSaveData(PlayerOrId: Player | number): SaveData
    --Return the save data for an id.
    if typeof(PlayerOrId) == "number" then
        return self:GetSaveDataById(PlayerOrId :: number)
    end

    --Get the save data.
    local Player = (PlayerOrId :: Player)
    local SaveData = self:GetSaveDataById(Player.UserId)

    --Connect flushing the data when the player leaves.
    local Key = PLAYERDATASTORE_ID_PREFIX..tostring(Player.UserId)
    if not self.SaveDataCacheEvents[PLAYERDATASTORE_DATA_STORE] then
        self.SaveDataCacheEvents[PLAYERDATASTORE_DATA_STORE] = {}
    end
    if not self.SaveDataCacheEvents[PLAYERDATASTORE_DATA_STORE][Key] then
        self.SaveDataCacheEvents[PLAYERDATASTORE_DATA_STORE][Key] = {
            Player.AncestryChanged:Connect(function()
                SaveData:Flush()
            end)
        }
    end

    --Return the save data.
    return SaveData :: SaveData
end

--[[
Flushes all SaveData. Yields for all of
them to finish flushing.
--]]
function NexusDataStore:FlushAll(): ()
    --Start flushing all of the data.
    local SavesRemaining = 0
    for _,DataStore in self.SaveDataCache do
        for _,SaveData in DataStore do
            SavesRemaining = SavesRemaining + 1
            task.spawn(function()
                xpcall(function()
                    SaveData:Flush()
                end, function(ErrorMessage: string): ()
                    warn("Flush for "..SaveData.DataStoreName.." -> "..SaveData.DataStoreKey.." failed because "..tostring(ErrorMessage))
                end)
                SavesRemaining = SavesRemaining - 1
            end)
        end
    end

    --Wait for all of the saves to finish.
    while SavesRemaining > 0 do
        wait()
    end
end

--[[
Disconnects the change events from the
save data for the given key and removes it from
the cache. If NexusDataStore:GetDataStore() or other
SaveData fetcher methods are called, the cache entry
is recreated.
--]]
function NexusDataStore:RemoveFromCache(DataStoreName: Player | number | string, Key: string?): ()
    --Determine the key.
    if typeof(DataStoreName) == "number" then
        DataStoreName = PLAYERDATASTORE_DATA_STORE
        Key = PLAYERDATASTORE_ID_PREFIX..tostring(DataStoreName)
    elseif typeof(DataStoreName) == "Instance" then
        DataStoreName = PLAYERDATASTORE_DATA_STORE
        Key = PLAYERDATASTORE_ID_PREFIX..tostring(DataStoreName.UserId)
    end

    if self.SaveDataCache[DataStoreName] and self.SaveDataCache[DataStoreName][Key] then
        --Disconnect and remove the cached entry.
        self.SaveDataCache[DataStoreName][Key]:Disconnect()
        self.SaveDataCache[DataStoreName][Key] = nil

        --Disconnect the events.
        if self.SaveDataCacheEvents[DataStoreName] and self.SaveDataCacheEvents[DataStoreName][Key] then
            for _,Event in self.SaveDataCacheEvents[DataStoreName][Key] do
                Event:Disconnect()
            end
            self.SaveDataCacheEvents[DataStoreName][Key] = nil
        end
    end
end



--Set up flushing all the data on close.
game:BindToClose(function()
    NexusDataStore:FlushAll()
end)



return (NexusDataStore :: any) :: NexusDataStore