--Sends messages in bulk through 1 topic to prevent too many topics being used.
--!strict

local NOT_CONNECTED_WARNING_DELAY_SECONDS = 10

local BulkMessagingService = {}
BulkMessagingService.__index = BulkMessagingService

local HttpService = game:GetService("HttpService")

export type BulkMessagingService = {
    Topic: string,
    MessagingService: MessagingService,
    PendingMessages: {[string]: {any}},
    SubscribedEvents: {[string]: BindableEvent},
    PendingFlush: boolean,
} & typeof(setmetatable({}, BulkMessagingService))



--[[
Creates a bulk messaging service.
--]]
function BulkMessagingService.new(MessagingService: MessagingService): BulkMessagingService
    --Create the object.
    local self = setmetatable({
        Topic = "NexusBulkMessagingService",
        MessagingService = MessagingService,
        PendingMessages = {},
        SubscribedEvents = {},
        PendingFlush = false,
    }, BulkMessagingService) :: BulkMessagingService

    --Set up subscribing.
    local SubscribeAsyncComplete = false
    task.spawn(function()
        xpcall(function()
            MessagingService:SubscribeAsync(self.Topic, function(MessageData)
                for Topic, Packets in HttpService:JSONDecode(MessageData.Data) do
                    local Event = self.SubscribedEvents[Topic]
                    if Event then
                        for _,Packet in Packets do
                            Event:Fire({Data = Packet, Sent = MessageData.Sent})
                        end
                    end
                end
            end)
        end, function(ErrorMessage: string)
            warn(`Listening to messaging service failed because {ErrorMessage}`)
        end)
        SubscribeAsyncComplete = true
    end)
    task.delay(NOT_CONNECTED_WARNING_DELAY_SECONDS, function()
        if SubscribeAsyncComplete then return end
        warn(`MessagingService::SubscribeAsync failed to complete in {NOT_CONNECTED_WARNING_DELAY_SECONDS} seconds. Messages may not be received.`)
    end)

    --Return the object.
    return self
end

--[[
Starts the passive loop for flushing messages.
--]]
function BulkMessagingService.StartPassiveLoop(self: BulkMessagingService): ()
    task.spawn(function()
        while true do
            xpcall(function()
                self:FlushMessages()
            end, function(ErrorMessage: string)
                warn("Passive flush failed because "..tostring(ErrorMessage))
            end)
            task.wait(1)
        end
    end)
end

--[[
Returns if an object is too long to send.
--]]
function BulkMessagingService.CanSendObject(self: BulkMessagingService, Object: any): boolean
    return string.len(HttpService:JSONEncode(HttpService:JSONEncode(Object))) <= 800
end

--[[
Clones the pending messages and adds the new message.
Returns the clone of the data.
--]]
function BulkMessagingService.AddPacket(self: BulkMessagingService, Topic: string, Message: any): {[string]: {any}}
    --Clone the pending messages.
    local PendingMessages = {}
    for Topic, Packets in self.PendingMessages do
        PendingMessages[Topic] = {}
        for i, Packet in Packets do
            PendingMessages[Topic][i] = Packet
        end
    end

    --Add the message.
    if not PendingMessages[Topic] then
        PendingMessages[Topic] = {}
    end
    table.insert(PendingMessages[Topic], Message)

    --Return the messages.
    return PendingMessages
end

--[[
Flushes the current messages.
--]]
function BulkMessagingService.FlushMessages(self: BulkMessagingService)
    if self.PendingFlush then
        local MessagesJSON = HttpService:JSONEncode(self.PendingMessages)
        self.PendingMessages = {}
        self.PendingFlush = false
        self.MessagingService:PublishAsync(self.Topic, MessagesJSON)
    end
end

--[[
Publishes a message for a given topic.
--]]
function BulkMessagingService.PublishAsync(self: BulkMessagingService, Topic: string, Message: any): ()
    --Flush if the new message would make the packet too big.
    if not self:CanSendObject(self:AddPacket(Topic, Message)) then
        self:FlushMessages()
    end

    --Add the message to send.
    if not self.PendingMessages[Topic] then
        self.PendingMessages[Topic] = {}
    end
    table.insert(self.PendingMessages[Topic], Message)
    self.PendingFlush = true
end

--[[
Subscribes to messages being sent for a topic.
--]]
function BulkMessagingService.SubscribeAsync(self: BulkMessagingService, Topic: string, Callback: (any) -> ()): RBXScriptConnection
    --Create the event.
    if not self.SubscribedEvents[Topic] then
        self.SubscribedEvents[Topic] = Instance.new("BindableEvent")
    end

    --Connect and return the event.
    return self.SubscribedEvents[Topic].Event:Connect(Callback)
end



return BulkMessagingService