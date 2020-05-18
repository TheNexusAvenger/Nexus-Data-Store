# Nexus Data Store
Nexus Data Store is a successor to PlayerDataStore by stravant.
Nexus Data Store provides the same functionality of buffering
DataStore requests with the addition of cross-server communication
for changes using the `MessagingService`. Assuming proper listening
using `OnUpdate`, data of players in a game can be manipulates from
other servers within 2 seconds of the server making the change.

## Why Nexus Data Store
Nexus Data Store abstracts the implementation of manipulating DataStores
while adding the following functionality:
* Buffer requests to prevent flooding writes to the `DataStore`s.
* Listening for updates using `OnUpdate` since `OnUpdate` in `DataStore`s is non-functional.
* Preventing overriding of player data when data fails to initialize.
* Automation tests with replication and failure conditions.

## vs DataStore2
[DataStore2](https://devforum.roblox.com/t/how-to-use-datastore2-data-store-caching-and-data-loss-prevention/136317)
has the same fundimentals of caching/buffering data before saving it
but uses a different setup and focuses on backups. Additionally, there
is no built-in cross-server communication. Nexus Data Store is intended
to replace PlayerDataStore and focus on manipulating player data, potentially
in multiple servers. It isn't easy to migrate between DataStore2, and moving
away from DataStore2 shouldn't nessessarily be done.