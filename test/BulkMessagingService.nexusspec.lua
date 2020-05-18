--[[
TheNexusAvenger

Tests the BulkMessagingService class.
--]]

local NexusUnitTesting = require("NexusUnitTesting")
local BulkMessagingServiceTest = NexusUnitTesting.UnitTest:Extend()

local BulkMessagingService = require(game:GetService("ServerScriptService"):WaitForChild("NexusDataStore"):WaitForChild("BulkMessagingService"))
local HttpService = game:GetService("HttpService")



--[[
Sets up the unit test.
--]]
function BulkMessagingServiceTest:Setup()
    --Create the mock MessagingService.
    self.MockMessagingService = {
        Event = Instance.new("BindableEvent"),
        PublishAsync = function(self,Topic,Message)
            if string.len(Message) > 950 then error("Long message sent.") end
            self.LastMessage = Message
            self.Event:Fire({Data=Message})
        end,
        SubscribeAsync = function(self,Topic,Callback)
            return self.Event.Event:Connect(Callback)
        end,
        AssertLastMessage = function(_,Object)
            if not Object then
                self:AssertEquals(Object,nil,"Last message is incorrect.")
            else
                self:AssertEquals(HttpService:JSONEncode(Object),self.MockMessagingService.LastMessage,"Last message is incorrect.")
            end
        end,
    }

    --Create the components under testing.
    self.CuT1 = BulkMessagingService.new(self.MockMessagingService)
    self.CuT2 = BulkMessagingService.new(self.MockMessagingService)
end

--[[
Tests replicating between the components under testing.
--]]
NexusUnitTesting:RegisterUnitTest(BulkMessagingServiceTest.new("Replication"):SetRun(function(self)
    --Connect the SubscribeAsync calls.
    local LastSubscribe = {}
    local SubscribeCalls = {0,0,0}
    self.CuT2:SubscribeAsync("Test1",function(Value)
        SubscribeCalls[1] = SubscribeCalls[1] + 1
        LastSubscribe[1] = Value.Data
    end)
    self.CuT2:SubscribeAsync("Test2",function(Value)
        SubscribeCalls[2] = SubscribeCalls[2] + 1
        LastSubscribe[2] = Value.Data
    end)
    self.CuT2:SubscribeAsync("Test3",function(Value)
        SubscribeCalls[3] = SubscribeCalls[3] + 1
        LastSubscribe[3] = Value.Data
    end)

    --Send several small messages and assert they weren't flushed.
    self.CuT1:PublishAsync("Test1","Message1")
    self.CuT1:PublishAsync("Test1","Message2")
    self.CuT1:PublishAsync("Test1","Message3")
    self.CuT1:PublishAsync("Test2","Message1")
    self.MockMessagingService:AssertLastMessage(nil)
    self:AssertEquals(SubscribeCalls,{0,0,0},"An incorrect amount of calls were made.")
    self:AssertEquals(LastSubscribe,{},"The incorrect packets were passed.")

    --Flush the messages and assert the correct calls were made.
    self.CuT1:FlushMessages()
    self.MockMessagingService:AssertLastMessage({Test1={"Message1","Message2","Message3"},Test2={"Message1"}})
    self:AssertEquals(SubscribeCalls,{3,1,0},"An incorrect amount of calls were made.")
    self:AssertEquals(LastSubscribe,{"Message3","Message1"},"The incorrect packets were passed.")
    self.CuT1:FlushMessages()
    self:AssertEquals(SubscribeCalls,{3,1,0},"An incorrect amount of calls were made.")

    --Send 100 messages and assert they were sent.
    --Messages being too long will throw an error.
    local ListOfMessages = {}
    for i = 1,100 do
        local Message = "Message"..tostring(i)
        table.insert(ListOfMessages,Message)
        self.CuT1:PublishAsync("Test3",Message)
    end
    self:AssertEquals(SubscribeCalls[3],56,"An incorrect amount of calls were made for test 3.")
    self.CuT1:FlushMessages()
    self:AssertEquals(SubscribeCalls,{3,1,100},"An incorrect amount of calls were made.")
    self:AssertEquals(LastSubscribe,{"Message3","Message1","Message100"},"The incorrect packets were passed.")
end))



return true