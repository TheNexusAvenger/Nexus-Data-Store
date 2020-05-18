--[[
TheNexusAvenger

Sends messages in bulk through 1 topic to prevent
too many topics being used.
--]]

local BulkMessagingService = {}
BulkMessagingService.__index = BulkMessagingService

local HttpService = game:GetService("HttpService")



--[[
Creates a bulk messaging service.
--]]
function BulkMessagingService.new(MessagingService)
    --Create the object.
    local BulkMessagingServiceObject = {}
    setmetatable(BulkMessagingServiceObject,BulkMessagingService)

    --Set up the properties.
    BulkMessagingServiceObject.Topic = "NexusBulkMessagingService"
    BulkMessagingServiceObject.MessagingService = MessagingService
    BulkMessagingServiceObject.PendingMessages = {}
    BulkMessagingServiceObject.SubscribedEvents = {}
    BulkMessagingServiceObject.PendingFlush = false

    --Set up subscribing.
    local Worked,ErrorMessage = pcall(function()
        MessagingService:SubscribeAsync(BulkMessagingServiceObject.Topic,function(MessageData)
            for Topic,Packets in pairs(HttpService:JSONDecode(MessageData.Data)) do
                local Event = BulkMessagingServiceObject.SubscribedEvents[Topic]
                if Event then
                    for _,Packet in pairs(Packets) do
                        Event:Fire({Data=Packet,Sent=MessageData.Sent})
                    end
                end
            end
        end)
    end)
    if not Worked then
        warn("Listening to messaging service failed because "..tostring(ErrorMessage))
    end

    --Return the object.
    return BulkMessagingServiceObject
end

--[[
Starts the passive loop for flushing messages.
--]]
function BulkMessagingService:StartPassiveLoop()
    coroutine.wrap(function()
        while true do
            local Worked,ErrorMessage = pcall(function()
                self:FlushMessages()
            end)
            if not Worked then
                warn("Passive flush failed because "..tostring(ErrorMessage))
            end
            wait(1)
        end
    end)()
end

--[[
Returns if an object is too long to send.
--]]
function BulkMessagingService:CanSendObject(Object)
    return string.len(HttpService:JSONEncode(HttpService:JSONEncode(Object))) <= 800
end

--[[
Clones the pending messages and adds the new message.
Returns the clone of the data.
--]]
function BulkMessagingService:AddPacket(Topic,Message)
    --Clone the pending messages.
    local PendingMessages = {}
    for Topic,Packets in pairs(self.PendingMessages) do
        PendingMessages[Topic] = {}
        for i,Packet in pairs(Packets) do
            PendingMessages[Topic][i] = Packet
        end
    end

    --Add the message.
    if not PendingMessages[Topic] then
        PendingMessages[Topic] = {}
    end
    table.insert(PendingMessages[Topic],Message)

    --Return the messages.
    return PendingMessages
end

--[[
Flushes the current messages.
--]]
function BulkMessagingService:FlushMessages()
    if self.PendingFlush then
        local MessagesJSON = HttpService:JSONEncode(self.PendingMessages)
        self.PendingMessages = {}
        self.PendingFlush = false
        self.MessagingService:PublishAsync(self.Topic,MessagesJSON)
    end
end

--[[
Publishes a message for a given topic.
--]]
function BulkMessagingService:PublishAsync(Topic,Message)
    --Flush if the new message would make the packet too big.
    if not BulkMessagingService:CanSendObject(self:AddPacket(Topic,Message)) then
        self:FlushMessages()
    end

    --Add the message to send.
    if not self.PendingMessages[Topic] then
        self.PendingMessages[Topic] = {}
    end
    table.insert(self.PendingMessages[Topic],Message)
    self.PendingFlush = true
end

--[[
Subscribes to messages being sent for a topic.
--]]
function BulkMessagingService:SubscribeAsync(Topic,Callback)
    --Create the event.
    if not self.SubscribedEvents[Topic] then
        self.SubscribedEvents[Topic] = Instance.new("BindableEvent")
    end

    --Connect and return the event.
    return self.SubscribedEvents[Topic].Event:Connect(Callback)
end



return BulkMessagingService