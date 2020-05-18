--[[
TheNexusAvenger

Main module for Nexus Data Store.
Intended to be a replacement for Stravant's PlayerDataStore
with the additions of cross-server updating.

GitHub: https://github.com/TheNexusAvenger/Nexus-Data-Store
--]]

local PLAYERDATASTORE_DATA_STORE = "PlayerDataStore_PlayerData"
local PLAYERDATASTORE_ID_PREFIX = "PlayerList$"

local SaveData = require(script:WaitForChild("SaveData"))
local BulkMessagingService = require(script:WaitForChild("BulkMessagingService"))

local NexusDataStore = {}
NexusDataStore.SaveDataCache = {}
NexusDataStore.SaveDataCacheEvents = {}
NexusDataStore.DataStoreService = game:GetService("DataStoreService")
NexusDataStore.MessagingService = BulkMessagingService.new(game:GetService("MessagingService"))
NexusDataStore.MessagingService:StartPassiveLoop()



--[[
Returns the SavaData structure for
a given DataStore key.
--]]
function NexusDataStore:GetDataStore(DataStoreName,Key)
    --Add the cache entry if it doesn't exist.
    if not self.SaveDataCache[DataStoreName] then
        self.SaveDataCache[DataStoreName] = {}
    end
    if not self.SaveDataCache[DataStoreName][Key] then
        self.SaveDataCache[DataStoreName][Key] = SaveData.new(DataStoreName,Key,self.DataStoreService,self.MessagingService)
        self.SaveDataCache[DataStoreName][Key]:StartBackgroundFlushing()
    end

    --Return the cached entry.
    return self.SaveDataCache[DataStoreName][Key]
end

--[[
Returns the SavaData structure for
a given user id.
--]]
function NexusDataStore:GetSaveDataById(UserId)
    return self:GetDataStore(PLAYERDATASTORE_DATA_STORE,PLAYERDATASTORE_ID_PREFIX..tostring(UserId))
end

--[[
Returns the SavaData structure for
a given player. Automatically flushes
data when the player leaves, but does
not remove the data from the cache in
case it is still neded.
--]]
function NexusDataStore:GetSaveData(Player)
    --Get the save data.
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
    return SaveData
end

--[[
Flushes all SaveData. Yields for all of
them to finish flushing.
--]]
function NexusDataStore:FlushAll()
    --Start flushing all of the data.
    local SavesRemaining = 0
    for _,DataStore in pairs(self.SaveDataCache) do
        for _,SaveData in pairs(DataStore) do
            SavesRemaining = SavesRemaining + 1
            coroutine.wrap(function()
                local Worked,ErrorMessage = pcall(function()
                    SaveData:Flush()
                end)
                if not Worked then
                    warn("Flush for "..SaveData.DataStoreName.." -> "..SaveData.DataStoreKey.." failed because "..tostring(ErrorMessage))
                end
                SavesRemaining = SavesRemaining - 1
            end)()
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
function NexusDataStore:RemoveFromCache(DataStoreName,Key)
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
            for _,Event in pairs(self.SaveDataCacheEvents[DataStoreName][Key]) do
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



return NexusDataStore