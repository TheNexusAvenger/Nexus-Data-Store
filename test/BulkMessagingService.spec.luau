--Tests the BulkMessagingService class.
--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local BulkMessagingService = require(ServerScriptService:WaitForChild("NexusDataStore"):WaitForChild("BulkMessagingService"))



return function()
    describe("2 bulk messaging service instances", function()
        it("should replicate data.", function()
            --Create the mock message service.
            local MockMessagingService = {
                Event = Instance.new("BindableEvent"),
                PublishAsync = function(self,Topic,Message)
                    if string.len(Message) > 950 then error("Long message sent.") end
                    self.LastMessage = Message
                    self.Event:Fire({Data=Message})
                end,
                SubscribeAsync = function(self,Topic,Callback)
                    return self.Event.Event:Connect(Callback)
                end,
                AssertLastMessage = function(self, Object)
                    if not Object then
                        expect(Object).to.equal(nil)
                    else
                        expect(HttpService:JSONEncode(Object)).to.equal(self.LastMessage)
                    end
                end,
            } :: any

            --Create the 2 instances.
            local SendingBulkMessagingService = BulkMessagingService.new(MockMessagingService) :: MessagingService & {
                FlushMessages: (any) -> (),
            }
            local ReceivingBulkMessagingService = BulkMessagingService.new(MockMessagingService)

            --Connect the SubscribeAsync calls.
            local LastSubscribe = {}
            local SubscribeCalls = {0, 0, 0}
            ReceivingBulkMessagingService:SubscribeAsync("Test1", function(Value)
                SubscribeCalls[1] = SubscribeCalls[1] + 1
                LastSubscribe[1] = Value.Data
            end)
            ReceivingBulkMessagingService:SubscribeAsync("Test2", function(Value)
                SubscribeCalls[2] = SubscribeCalls[2] + 1
                LastSubscribe[2] = Value.Data
            end)
            ReceivingBulkMessagingService:SubscribeAsync("Test3", function(Value)
                SubscribeCalls[3] = SubscribeCalls[3] + 1
                LastSubscribe[3] = Value.Data
            end)

            --Send several small messages and assert they weren't flushed.
            SendingBulkMessagingService:PublishAsync("Test1", "Message1")
            SendingBulkMessagingService:PublishAsync("Test1", "Message2")
            SendingBulkMessagingService:PublishAsync("Test1", "Message3")
            SendingBulkMessagingService:PublishAsync("Test2", "Message1")
            task.wait()
            MockMessagingService:AssertLastMessage(nil)
            expect(SubscribeCalls[1]).to.equal(0)
            expect(SubscribeCalls[2]).to.equal(0)
            expect(SubscribeCalls[3]).to.equal(0)
            expect(#LastSubscribe).to.equal(0)

            --Flush the messages and assert the correct calls were made.
            SendingBulkMessagingService:FlushMessages()
            task.wait()
            MockMessagingService:AssertLastMessage({Test1 = {"Message1", "Message2", "Message3"}, Test2 = {"Message1"}})
            expect(SubscribeCalls[1]).to.equal(3)
            expect(SubscribeCalls[2]).to.equal(1)
            expect(SubscribeCalls[3]).to.equal(0)
            expect(#LastSubscribe).to.equal(2)
            expect(LastSubscribe[1]).to.equal("Message3")
            expect(LastSubscribe[2]).to.equal("Message1")
            SendingBulkMessagingService:FlushMessages()
            task.wait()
            expect(SubscribeCalls[1]).to.equal(3)
            expect(SubscribeCalls[2]).to.equal(1)
            expect(SubscribeCalls[3]).to.equal(0)

            --Send 100 messages and assert they were sent.
            --Messages being too long will throw an error.
            local ListOfMessages = {}
            for i = 1, 100 do
                local Message = "Message"..tostring(i)
                table.insert(ListOfMessages, Message)
                SendingBulkMessagingService:PublishAsync("Test3", Message)
            end
            task.wait()
            expect(SubscribeCalls[3]).to.equal(56)
            SendingBulkMessagingService:FlushMessages()
            task.wait()
            expect(SubscribeCalls[1]).to.equal(3)
            expect(SubscribeCalls[2]).to.equal(1)
            expect(SubscribeCalls[3]).to.equal(100)
            expect(#LastSubscribe).to.equal(3)
            expect(LastSubscribe[1]).to.equal("Message3")
            expect(LastSubscribe[2]).to.equal("Message1")
            expect(LastSubscribe[3]).to.equal("Message100")
        end)
    end)
end