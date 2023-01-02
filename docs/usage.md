# Usage
## Getting Save Data
Nexus Data Store's main module supports 3 ways of getting `SaveData`:
- `GetDataStore(DataStoreName: string, Key: string): SaveData` - Fetchs
  the save data using the `DataStoreName` as the `DataStore` and `Key`
  for the `Key` in the DataStore. This can be for any data, such
  as ban lists or game events.
- `GetSaveDataById(UserId: number): SaveData` - Fetches the save data
  for a player with their user id.
- `GetSaveData(PlayerOrId: Player | number): SaveData` - Fetches the
  save data for a player. Unlike PlayerDataStore, a user id can also
  be supplied, which calls `GetSaveDataById`. `GetSaveData` is always
  recommended for `Player`s when possible because it will flush data
  when a player leaves automatically.

For `GetDataStore`, `GetSaveDataById`, and `GetSaveData` with user ids,
it is recommended to use `RemoveFromCache(DataStoreName: Player | number | string, Key: string?): ()`
when no longer needed to clear connections. The arguments passed in to
`RemoveFromCache` will match the arguments for `GetDataStore`, `GetSaveDataById`,
and `GetSaveData`.

## Reading / Writing
Simple read/write operations are done with `Get` and `Set`, as well as
`Increment` for numbers. All functions operate immediately and perform
operations in the background. `Get`, `Set`, and `Increment` are expected
to never present an error to caller (except for `Increment` when attempting
to increment a non-number) and return with no delay. This is unless `Flush`
is used, which performs a DataStore update.

```lua
local NexusDataStore = ...
local SaveData = NexusDataStore:GetSaveData(game.Players.TestPlayer)

--Setting values (can be any type supported by JSONEncode).
SaveData:Set("MyKey1", 2)
SaveData:Set("MyKey2", {MyKey="MyValue"})
print(SaveData:Get("MyKey1")) --2
print(SaveData:Get("MyKey2")) --table 0x...

--Incrementing values
SaveData:Increment("MyKey1", 3)
print(SaveData:Get("MyKey1")) --5

--OPTIONAL call to flush data (DataStore update). This is not needed in most cases and can throw errors.
SaveData:Flush()
```

## Atomic Updates
`Update` is similar to `UpdateAsync` where it is given a key and a callback
function. However, `Update` can accept a list of keys and a callback that
returns multiple values to update to perform them atomically. Unlike the
simple read/write, `Update` will immediately call `Flush` and may throw errors.

```lua
local NexusDataStore = ...
local SaveData = NexusDataStore:GetSaveData(game.Players.TestPlayer)

--Update a single key.
SaveData:Update("MyKey1", function(ExistingValue: number): (number)
    if ExistingValue == nil then
        ExistingValue = 1
    end
    return ExistingValue * 2
end)

--Update multiple values at the same time (will complete or fail together).
SaveData:Update({"MyKey1", "MyKey1LastValue", "MyKey2"}, function(ExistingValue1: number, ExistingValue2: number, ExistingValue3: string): (number, number, string)
    if ExistingValue1 == nil then
        ExistingValue1 = 1
    end
    if ExistingValue2 == nil then
        ExistingValue2 = 1
    end
    return ExistingValue1 * 2, ExistingValue2 * 3, tostring(ExistingValue3)..tostring(ExistingValue1)..tostring(ExistingValue2)
end)
```

## Listening To Updates
In order to listen to changes, `OnUpdate` allows for listening to event changes.
The event created by `OnUpdate` will invoke by changes from the host server
with `Set` and `Increment` immediately as well as external changes. `OnUpdate`
will return a connection that can be disconnected. `RemoveFromCache`
will disconnect all `OnUpdate` values for the `SaveData`.

```lua
local NexusDataStore = ...
local SaveData = NexusDataStore:GetSaveData(game.Players.TestPlayer)

local EventConnection = SaveData:OnUpdate("MyKey", function(CurrentValue: number): ()
    print(CurrentValue)
end)
SaveData:Set("MyKey", 4) --Will print 4

EventConnection:Disconnect() --In order to clean up the event.
```

## Handling Loading Failures
If the 3 static functions for getting `SaveData` entries fail to get a
`DataStore` object, it will error. However, if it gets a `DataStore`
object but then fails to read the data, `Set` and `Increment` will work
but will not save any values. Warnings will appear when this happens.
`DataLoadedSuccessfully(): boolean` is how to check if this fail-safe
state is active. It is recommended to alert the player that this happened
and their data is safe when this happens.

```lua
local NexusDataStore = ...
local SaveData = NexusDataStore:GetSaveData(game.Players.TestPlayer)

if not SaveData:DataLoadedSuccessfully() then
    --Alert player their datta did not load and won't save.
end
```