# Roblox-Open-Cloud
## Creating API Key
In order to interact with Nexus Data Store using Roblox Open Cloud,
an API key needs to be created. This can be done in the [credentials view](https://create.roblox.com/credentials)
of the Roblox Creator Dashboard. For each experience for the API key that
is set up, DataStore access must be set for the DataStore you intend to use
with "Read Entry" and "Update Entry". For MessagingService, "Publish"
permissions are required. For `GetSaveData` and `GetSaveDataById`,
`PlayerDataStore_PlayerData` is the DataStore name.

## Getting Values
All of the keys in the `SaveData` used by Nexus Data Store are stored
as a single key in the DataStore. All the keys and values in the `SaveData`
can be fetched with a single request. Be aware the example below does
not have any error checking and does not handle the `SaveData` being
unpopulated.

```python
import requests

gameId = ...
apiKey = ...
dataStoreName = "MyDataStore" # For GetSaveData and GetSaveDataById, use "PlayerDataStore_PlayerData"
dataStoreKey = "MyKey" # For GetSaveData and GetSaveDataById, use "PlayerList$USER_ID" where USER_ID is the id of the player.
url = "https://apis.roblox.com/datastores/v1/universes/" + str(gameId) + "/standard-datastores/datastore/entries/entry?datastoreName=" + dataStoreName + "&entryKey=" + dataStoreKey
response = requests.get(url, headers={
    "x-api-key": apiKey
}).json() # response is a dictionary with all the keys and values for the SaveData.
```

## Setting Values
Setting values is much more complicated because you need to get the existing
data, modify the data, and message the servers. Again, the example below does
not have any error checking and does not handle the `SaveData` being
unpopulated.

```python
import json
import requests

gameId = ...
apiKey = ...
dataStoreName = "MyDataStore" # For GetSaveData and GetSaveDataById, use "PlayerDataStore_PlayerData"
dataStoreKey = "MyKey" # For GetSaveData and GetSaveDataById, use "PlayerList$USER_ID" where USER_ID is the id of the player.
newKey = "MyKey"
newValue = "MyValue

# Get the existing values and override the value.
overridesUrl = "https://apis.roblox.com/datastores/v1/universes/" + str(gameId) + "/standard-datastores/datastore/entries/entry?datastoreName=" + dataStoreName + "&entryKey=" + dataStoreKey
overridesResponse = requests.get(overridesUrl, headers={
    "x-api-key": apiKey
}).json()
overridesResponse[newKey] = newValue

# Send the new values.
requests.post(overridesUrl, json=overridesResponse, headers={
    "x-api-key": apiKey
})

# Messaging service call.
messageUrl = "https://apis.roblox.com/messaging-service/v1/universes/" + str(gameId) + "/topics/NexusBulkMessagingService"
requests.post(messageUrl, json={
    "message": json.dumps({
        "NSD_" + dataStoreKey: [
            json.dumps({
                "Action": "Set", # If Value is too long, use "Fetch" instead.
                "Key": newKey,
                "Value": newValue # If Value is too long, don't include it.
            }),
        ],
    })
}, headers={
    "x-api-key": apiKey
})
```