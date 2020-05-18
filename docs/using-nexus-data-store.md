# Using Nexus Data Store
This page covers an example using most of the current APIs
in the system.

For the following example, assume you have a coins system.
When loading players, you need to load the coins value. Since
Nexus Data Store uses a cache, it would be redundant to store
the coins value in a second location.

```lua
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local NexusDataStore = require(ServerScriptService:WaitForChild("NexusDataStore"))

Players.PlayerAdded:Connect(function(Player)
    --Fetch the data.
    --Even with GetAsync()s failing, the data can be loaded; it just won't be saved in case UpdateAsync() isn't failing.
    local PlayerData = NexusDataStore:GetSaveData(Player)

    --Create the leaderstats for the player's coins.
    local Leaderstats = Instance.new("Folder")
    Leaderstats.Name = "leaderstats"
    Leaderstats.Parent = Player

    local Coins = Instance.new("IntValue")
    Coins.Name = "Coins"
    Coins.Value = PlayerData:Get("Coins") or 0
    Coins.Parent = Leaderstats
end)
```

With the old PlayerDataStore, there was no way to listen
for the value changing, and thus required manual updating
of values. With Nexus Data Store, `OnUpdate` can be used.
If the data is updated in another server, than the value will
be changed. This can be useful for admin systems for awarding
currencies or banning players in real time. You do need to
keep flushing data in mind.

```lua
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local NexusDataStore = require(ServerScriptService:WaitForChild("NexusDataStore"))

Players.PlayerAdded:Connect(function(Player)
    --Fetch the data.
    --Even with GetAsync()s failing, the data can be loaded; it just won't be saved in case UpdateAsync() isn't failing.
    local PlayerData = NexusDataStore:GetSaveData(Player)

    --Create the leaderstats for the player's coins.
    local Leaderstats = Instance.new("Folder")
    Leaderstats.Name = "leaderstats"
    Leaderstats.Parent = Player

    local Coins = Instance.new("IntValue")
    Coins.Name = "Coins"
    Coins.Value = PlayerData:Get("Coins") or 0
    Coins.Parent = Leaderstats

    --Connect updating the value.
    PlayerData:OnUpdate("Coins",function(NewCoins)
        Coins.Value = NewCoins
    end)
end)

Players.PlayerRemoving:Connect(function(Player)
    --Flush the data and close the event connections by clearing the data.
    --The data most likely has been flushed internally; this just clears up the resources.
    NexusDataStore:RemoveFromCache(Player)
end)

--[[
Awards the player a set of coins.
Even if player data failed to load, this can be called
since the data will not be overwritten.
--]]
local function AwardCoins(Player,Coins)
    --Can also call the following, but it isn't as easy to read:
    --NexusDataStore:GetSaveData(Player):Set("Coins",(NexusDataStore:GetSaveData(Player):Get("Coins") or 0) + Coins)
    NexusDataStore:GetSaveData(Player):Increment("Coins",Coins)
end

--[[
Remotely awards coins for a player.
--]]
local function AwardCoinsRemove(UserId,Coins)
    --Set the coins.
    local DataStore = NexusDataStore:GetSaveDataById(UserId)
    DataStore:Incrementt("Coins",Coins)

    --Remove the data from the cache. This flushes the data to the DataStores and disconnects events.
    --Be aware Flush can throw errors if UpdateAsync fails.
    if not Players:GetPlayerFromId(UserId) then
        NexusDataStore:RemoveFromCache(UserId)
    end
end
```

Like PlayerDataStore, you can also update values using
`Update` instead of getting and setting values in case
there is something that needs to save at the same time
(like a shop). You can pass in multiple keys and update
multiple values at the same time.

```lua
local ServerScriptService = game:GetService("ServerScriptService")

local NexusDataStore = require(ServerScriptService:WaitForChild("NexusDataStore"))

--[[
Buys a buff for 10 coins.
--]]
local function BuyBuff(Player)
    local DataStore = NexusDataStore:GetSaveData(Player)
    if Player:Get("Coins") or 0 >= 10 then
        --Update the Coins and Buffs values.
        --Note: This should be pcalled.
        DataStore:Update({"Coins","Buffs"},function(OldCoins,OldBuffs)
            return (OldCoins or 0) - 10,(OldBuffs or 0) + 1
        end)
    end
end
```

Unlike PlayerDataStore, Nexus Data Store can be used with
non-Player data. For example, the following code works for
a cross-server, real-time ban system.
```lua
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local NexusDataStore = require(ServerScriptService:WaitForChild("NexusDataStore"))
local BanDataStore = NexusDataStore:GetDataStore("GlobalGameData","Bans") --DataStore: GlobalGameData, Key: Bans

--[[
Bans a player.
--]]
local function BanPlayer(UserId,Messsage)
    DataStore:Update("BannedUsers",function(OldBans)
        OldBans = OldBans or {}
        OldBans[UserId] = Message
        return OldBans
    end)
end

--[[
Kicks a player if they are banned.
--]]
local function KickPlayerIfBanned(Player)
    local Bans = BanDataStore:Get("BannedUsers") or {}
    local BanMessage = Bans[Player.UserId]
    if BanMessage then
        Player:Kick(BanMessage)
    end
end

--Connect the bans changing.
BanDataStore:OnUpdate("BannedUsers",function(BansList)
    BansList = BansList or {}

    --Kick the existing players.
    for _,Player in pairs(Players:GetPlayers()) do
        KickPlayerIfBanned(Player)
    end
end)

--Players joining.
Players.PlayerAdded:Connect(KickPlayerIfBanned)
```