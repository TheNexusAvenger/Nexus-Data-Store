# API-Reference
The reference include APIs intended to be used. Internal APIs are
not listed and should not be relied on as they may change
in future versions.

# `NexusDataStore`
`NexusDataStore` is a static class for storing a cache of `SaveData`s.
Additionally, all calls for the `MessagingService` are made through single topic
instead of individual topics to prevent reaching the limit of subscriptions.

## `static SaveData NexusDataStore:GetDataStore(string DataStoreName,string Key)`
Returns the `SavaData` structure for
a given DataStore key.

## `static SaveData NexusDataStore:GetSaveDataById(integer UserId)`
Returns the `SavaData` structure for
a given user id.

## `static void NexusDataStore:GetSaveData(Player Player)`
Returns the `SavaData` structure for
a given player. Automatically flushes
data when the player leaves, but does
not remove the data from the cache in
case it is still neded.

## `static void NexusDataStore:FlushAll()`
Flushes all `SaveData`. Yields for all of
them to finish flushing.

## `static void NexusDataStore:RemoveFromCache(string DataStoreName,string Key)`
## `static void NexusDataStore:RemoveFromCache(Player Player)`
## `static void NexusDataStore:RemoveFromCache(integer UserId)`
Disconnects the change events from the
save data for the given key and removes it from
the cache. If NexusDataStore:GetDataStore() or other
`SaveData` fetcher methods are called, the cache entry
is recreated.

# `SaveData`
`SaveData` directly handles reading and writing data to the `DataStore`s.
It is not recommended to be created directly since it might be possible for
multiple instances of the same key to get out of sync.

## `void SaveData:SetSendDataChangeUpdates(boolean Value)`
Sets if messages are sent when a key is
updated or if the data needs to be re-fetched (i.e. string
or entry is >1000 characters). By default, this is true.

## `void SaveData:SetAllowOverwriteOfFailedLoad(boolean Value)`
Sets if data can be overwriten if the loading
of data failed. This should be kept true if player data
is involved. By default, this is true.

## `boolean SaveData:DataLoadedSuccessfully()`
Returns if the data loaded successfully. If an error
occured (such as a DataStore failure), false is returned.

## `void SaveData:Flush()`
Flushes the data to the DataStore. If the data failed
to initialize and SetAllowOverwriteOfFailedLoad was not set
to true, no data will be flushed to prevent overwriting data.

## `variant SaveData:Get(string Key)`
Returns the stored value for a given key.

## `void SaveData:Set(string Key,variant Value)`
Sets the stored value for a given key.

## `void SaveData:Increment(string Key,variant Value)`
Increments the stored value for a given key.

## `void SaveData:Update(string Key,function UpdateFunction)`
## `void SaveData:Update(List<string> Key,function UpdateFunction)`
Updates and saves (flushes) the changed values for the key
or keys. If multiple keys are given, the update function
will pass the old values and expect the new values to be returned.
This is intended for important updates that need to happen together.

## `RBXScriptSignal SaveData:OnUpdate(string Key,function Callback) `
Invokes the given callback when the value for a given
key changes. Returns the connection to disconnect the
changes.

## `void SaveData:Disconnect()`
Disconnects the events.