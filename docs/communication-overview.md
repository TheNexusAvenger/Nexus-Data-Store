# Communication Overview
This page includes information about how data is saved and communicated
between servers.

# SaveData
`SaveData` uses the `DataStoreService` for storing data the `MessagingService`
to communicate the changes within a few seconds being done in most cases. The
actual data itself is saved to the `DataStore` and key specified in the constructor
(which is done internally through `NexusDataStore`) as a dictionary with the keys
and values. This provides direct compatibility with PlayerDataStore and doesn't require
a special strucutre to function. All keys are assumed to be strings, but values can
be any type supported by data stores.

Messages are sent between servers either containing the new value that was set using
`SaveData:Set(Key, Value)` or `SaveData:Increment(Key, Value)` if the message is short enough.
If it isn't, it is marked as a key that needs to be fetched by the other servers.
After a successful `UpdateAsync` while flushing, a message is sent to the other servers
of the keys to fetch and update.

# BulkMessagingService
During testing with the Innovation Security Training Facility, it was discovered that
bulk writes of data would send too many small messages. Since the `MessagingService`
limits are based on the number of requests rather than the total data sent, combining requests
and sending them as one is an option. The `BulkMessagingService` is an internal class
that acts like the regular `MessagingService` except that it buffers requests. This allows
for sending more smaller requests at the cost of latency. At worst, it adds 1 second to the
send time. Since the `MessagingService` is meant to send data between servers in less than
1 second, this may be significant.

When a message is sent through the service, it will add the request to send later after
sending out the existing messages if the new message would put the message over the data
limit. The message is sent as a JSON string containing a dictionary with the key being the
topic and the values being a list of messages since there may be more than 1 message sent
in the buffer. On the receiving end, the `SubscribeAsync` messages are called in order of
how they were buffered as if it was the original `MessagingService`.