--[[
TheNexusAvenger

Tests the SaveData class.
--]]
--!strict

local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")

local SaveData = require(ServerScriptService:WaitForChild("NexusDataStore"):WaitForChild("SaveData"))

return function()
    local MockDataStore = nil
    local MockDataStoreService = ({
        GetDataStore = function(_, Key)
            return MockDataStore
        end
    } :: any) :: DataStoreService
    local MockMessagingService: MessagingService & {AssertLastMessage: (any, any) -> (), LastMessage: any} = nil
    local SaveData1, SaveData2 = nil, nil

    beforeEach(function()
        MockDataStore = {
            GetAsync = function(self,Key)
                return self.Data
            end,
            UpdateAsync = function(self, Key, Callback)
                self.Data = Callback(self.Data)
            end,
            AssertSave = function(self, Data)
                if not Data then
                    assert(Data == nil)
                else
                    assert(HttpService:JSONEncode(Data) == HttpService:JSONEncode(self.Data))
                end
            end,
        }
        MockMessagingService = {
            Event = Instance.new("BindableEvent"),
            PublishAsync = function(self, Topic, Message)
                self.LastMessage = Message
                self.Event:Fire({Data=Message})
            end,
            SubscribeAsync = function(self, Topic, Callback)
                return self.Event.Event:Connect(Callback)
            end,
            AssertLastMessage = function(self, Object)
                if not Object then
                    assert(Object == nil)
                else
                    local ActualObject = HttpService:JSONDecode(MockMessagingService.LastMessage)
                    assert(ActualObject.SyncId ~= nil)
                    ActualObject.SyncId = nil
                    if Object.Keys then
                        assert(HttpService:JSONEncode(Object.Keys) == HttpService:JSONEncode(ActualObject.Keys))
                    end
                    assert(Object.Action == ActualObject.Action)
                    assert(Object.Value == ActualObject.Value)
                end
            end,
        } :: MessagingService & {AssertLastMessage: (any, any) -> (), LastMessage: any}

        SaveData1 = SaveData.new("TestDataStore", "TestKey", MockDataStoreService, MockMessagingService :: any) :: SaveData.SaveData & {MessagingServiceBufferTime: number}
        SaveData2 = SaveData.new("TestDataStore", "TestKey", MockDataStoreService, MockMessagingService :: any) :: SaveData.SaveData & {MessagingServiceBufferTime: number}
        SaveData1.MessagingServiceBufferTime = 0
        SaveData2.MessagingServiceBufferTime = 0
    end)

    describe("A working DataStore", function()
        it("should fetch and replicate data.", function()
            --Connect the OnUpdate calls.
            local LastOnUpdate = {}
            SaveData1:OnUpdate("Test1", function(Value)
                LastOnUpdate[1] = Value
            end)
            SaveData1:OnUpdate("Test2", function(Value)
                LastOnUpdate[2] = Value
            end)
            SaveData1:OnUpdate("Test3", function(Value)
                LastOnUpdate[3] = Value
            end)
            SaveData1:OnUpdate("Test4",function(Value)
                LastOnUpdate[4] = Value
            end)
            SaveData1:OnUpdate("Test5",function(Value)
                LastOnUpdate[5] = Value
            end)

            --Set a value and assert it was replicated but not flushed.
            expect(SaveData1:DataLoadedSuccessfully()).to.equal(true)
            SaveData1:Set("Test1", "Value1")
            task.wait()
            expect(SaveData1:Get("Test1")).to.equal("Value1")
            expect(SaveData2:Get("Test1")).to.equal("Value1")
            expect(LastOnUpdate[1]).to.equal("Value1")
            MockMessagingService:AssertLastMessage({Action = "Set", Key = "Test1", Value = "Value1"})
            SaveData2:Set("Test1", "Value2")
            task.wait()
            expect(SaveData1:Get("Test1")).to.equal("Value2")
            expect(SaveData2:Get("Test1")).to.equal("Value2")
            expect(LastOnUpdate[1]).to.equal("Value2")
            MockMessagingService:AssertLastMessage({Action = "Set", Key = "Test1", Value = "Value2"})
            MockDataStore:AssertSave(nil)

            --Flush the data and assert it was set correctly.
            SaveData1:Flush()
            MockDataStore:AssertSave({Test1 = "Value2"})
            MockMessagingService:AssertLastMessage({Action = "Set", Key = "Test1", Value = "Value2"})

            --Increment a value and assert it was replicated but not flushed.
            SaveData1:Increment("Test2", 3)
            task.wait()
            expect(SaveData1:Get("Test2")).to.equal(3)
            expect(SaveData2:Get("Test2")).to.equal(3)
            expect(LastOnUpdate[2]).to.equal(3)
            MockMessagingService:AssertLastMessage({Action = "Set", Key = "Test2", Value = 3})
            SaveData1:Increment("Test2",4)
            task.wait()
            expect(SaveData1:Get("Test2")).to.equal(7)
            expect(SaveData2:Get("Test2")).to.equal(7)
            expect(LastOnUpdate[2]).to.equal(7)
            MockMessagingService:AssertLastMessage({Action = "Set", Key = "Test2", Value = 7})

            --Flush the data and assert it was set correctly.
            SaveData1:Flush()
            MockDataStore:AssertSave({Test1 = "Value2", Test2 = 7})
            MockMessagingService:AssertLastMessage({Action = "Set", Key = "Test2", Value = 7})

            --Update a key and assert it was replicated and flushed.
            SaveData1:Update("Test1", function(OldValue: string)
                return OldValue.."_3"
            end)
            task.wait()
            expect(SaveData1:Get("Test1")).to.equal("Value2_3")
            expect(SaveData2:Get("Test1")).to.equal("Value2_3")
            expect(LastOnUpdate[1]).to.equal("Value2_3")
            MockDataStore:AssertSave({Test1 = "Value2_3", Test2 = 7})
            MockMessagingService:AssertLastMessage({Action = "Fetch", Keys = {"Test1"}})

            --Update multiple keys and assert it was replicated and flushed.
            SaveData2:Update({"Test1", "Test2"}, function(OldValue1: string, OldValue2: number)
                return OldValue1.."_4", OldValue2 + 3
            end)
            task.wait()
            expect(SaveData1:Get("Test1")).to.equal("Value2_3_4")
            expect(SaveData2:Get("Test1")).to.equal("Value2_3_4")
            expect(SaveData1:Get("Test2")).to.equal(10)
            expect(SaveData2:Get("Test2")).to.equal(10)
            expect(LastOnUpdate[1]).to.equal("Value2_3_4")
            expect(LastOnUpdate[2]).to.equal(10)
            MockDataStore:AssertSave({Test1 = "Value2_3_4", Test2 = 10})
            MockMessagingService:AssertLastMessage({Action = "Fetch", Keys = {"Test1", "Test2"}})

            --Update missing keys and assert it was replicaed correctly.
            SaveData1:Update({"Test1", "Test2", "Test3", "Test4"},function(OldValue1: string, OldValue2: number, OldValue3: any, OldValue4: number)
                return OldValue1.."_5", OldValue2 + 2, nil, OldValue2 + 3
            end)
            task.wait()
            expect(SaveData1:Get("Test1")).to.equal("Value2_3_4_5")
            expect(SaveData2:Get("Test1")).to.equal("Value2_3_4_5")
            expect(SaveData1:Get("Test2")).to.equal(12)
            expect(SaveData2:Get("Test2")).to.equal(12)
            expect(SaveData1:Get("Test3")).to.equal(nil)
            expect(SaveData2:Get("Test3")).to.equal(nil)
            expect(SaveData1:Get("Test4")).to.equal(13)
            expect(SaveData2:Get("Test4")).to.equal(13)
            expect(LastOnUpdate[1]).to.equal("Value2_3_4_5")
            expect(LastOnUpdate[2]).to.equal(12)
            expect(LastOnUpdate[4]).to.equal(13)
            MockDataStore:AssertSave({Test1 = "Value2_3_4_5", Test2 = 12, Test4 = 13})
            MockMessagingService:AssertLastMessage({Action = "Fetch", Keys = {"Test1", "Test2", "Test3", "Test4"}})

            --Set a long string and assert it was not replicated.
            SaveData1:Set("Test5", string.rep("Test", 500))
            task.wait()
            expect(SaveData1:Get("Test5")).to.equal(string.rep("Test",500))
            expect(SaveData2:Get("Test5")).to.equal(nil)
            expect(LastOnUpdate[5]).to.equal(string.rep("Test",500))
            MockDataStore:AssertSave({Test1 = "Value2_3_4_5", Test2 = 12, Test4 = 13})
            MockMessagingService:AssertLastMessage({Action = "Fetch", Keys = {"Test1", "Test2", "Test3", "Test4"}})
            SaveData1:Flush()
            MockDataStore:AssertSave({Test1 = "Value2_3_4_5", Test2 = 12, Test4 = 13, Test5 = string.rep("Test", 500)})
            MockMessagingService:AssertLastMessage({Action = "Fetch", Keys = {"Test5"}})

            --Disconnect the first component under testing and assert changes aren't replicated.
            SaveData1:Disconnect()
            SaveData2:Set("Test1", "Value6")
            task.wait()
            expect(SaveData2:Get("Test1")).to.equal("Value6")
            expect(SaveData1:Get("Test1")).to.equal("Value2_3_4_5")
            expect(LastOnUpdate[1]).to.equal("Value2_3_4_5")
            MockMessagingService:AssertLastMessage({Action = "Set", Key = "Test1", Value = "Value6"})
        end)

        it("should update with nil values.", function()
            --Set initial values.
            SaveData1:Set("Test1", "Value1")
            SaveData1:Set("Test2", "Value2")
            SaveData1:Flush()
            MockDataStore:AssertSave({Test1 = "Value1", Test2 = "Value2"})

            --Update so that the second key is nil.
            SaveData1:Update({"Test1", "Test2"}, function(Value1: string?, Value2: string?)
                expect(Value1).to.equal("Value1")
                expect(Value2).to.equal("Value2")
                return "Value3", nil
            end)
            MockDataStore:AssertSave({Test1="Value3"})

            --Update so that the first key is nil.
            SaveData1:Update({"Test1", "Test2"}, function(Value1: string?, Value2: string?)
                expect(Value1).to.equal("Value3")
                expect(Value2).to.equal(nil)
                return nil, "Value4"
            end)
            MockDataStore:AssertSave({Test2 = "Value4"})

            --Set a key to nil.
            SaveData1:Set("Test2", nil)
            SaveData1:Flush()
            MockDataStore:AssertSave({})
        end)

        it("should buffer write-heavy cases.", function()
            --Set the messaging service buffer time for the test (setup overrides to 0 for other tests).
            SaveData1.MessagingServiceBufferTime = 0.2

            --Write a value and assert it was instantly set.
            SaveData1:Set("Test1", 0)
            task.wait()
            expect(SaveData1:Get("Test1")).to.equal(0)
            expect(SaveData2:Get("Test1")).to.equal(0)
            MockMessagingService:AssertLastMessage({Action = "Set", Key = "Test1", Value = 0})

            --Write 100 values and assert they weren't sent due to the buffer time.
            task.wait(0.1)
            for i = 1, 100 do
                SaveData1:Set("Test1", i)
            end
            task.wait()
            expect(SaveData1:Get("Test1")).to.equal(100)
            expect(SaveData2:Get("Test1")).to.equal(0)
            MockMessagingService:AssertLastMessage({Action = "Set", Key = "Test1", Value = 0})

            --Write a different value and assert it was sent.
            SaveData1:Set("Test2", 1)
            task.wait()
            expect(SaveData1:Get("Test1")).to.equal(100)
            expect(SaveData2:Get("Test1")).to.equal(0)
            expect(SaveData1:Get("Test2")).to.equal(1)
            expect(SaveData2:Get("Test2")).to.equal(1)
            MockMessagingService:AssertLastMessage({Action = "Set", Key = "Test2", Value = 1})

            --Wait the buffer time to clear and assert value was updated.
            task.wait(0.15)
            expect(SaveData1:Get("Test1")).to.equal(100)
            expect(SaveData2:Get("Test1")).to.equal(100)
            MockMessagingService:AssertLastMessage({Action = "Set", Key = "Test1", Value = 100})

            --Write the value again and assert the buffer time is used.
            SaveData1:Set("Test1", 101)
            task.wait()
            expect(SaveData1:Get("Test1")).to.equal(101)
            expect(SaveData2:Get("Test1")).to.equal(100)
            MockMessagingService:AssertLastMessage({Action = "Set", Key = "Test1", Value = 100})
            task.wait(0.25)
            expect(SaveData1:Get("Test1")).to.equal(101)
            expect(SaveData2:Get("Test1")).to.equal(101)
            MockMessagingService:AssertLastMessage({Action = "Set", Key = "Test1", Value = 101})

            --Assert a new value after the buffer time is replicated.
            task.wait(0.25)
            SaveData1:Set("Test1", 102)
            task.wait()
            expect(SaveData1:Get("Test1")).to.equal(102)
            expect(SaveData2:Get("Test1")).to.equal(102)
            MockMessagingService:AssertLastMessage({Action = "Set", Key = "Test1", Value = 102})
        end)
    end)

    describe("A malfunctioning DataStore or MessagingService", function()
        it("should display errors when the MessagingService fails.", function()
            local FailingMessagingService = {
                SubscribeAsync = function()
                    error("Test failure")
                end,
                PublishAsync = function()
                
                end,
            }
            local SaveData = SaveData.new("TestDataStore", "TestKey", MockDataStoreService, FailingMessagingService :: any)
            SaveData:Set("Test1","Value1")
            expect(SaveData:Get("Test1")).to.equal("Value1")
            SaveData:Flush()
            MockDataStore:AssertSave({Test1 = "Value1"})
        end)

        it("should throw an error when it fails to get the DataStore.", function()
            local FailingDataStoreService = {
                GetDataStore = function()
                    error("Test failure")
                end,
            }
            expect(function()
                SaveData.new("TestDataStore", "TestKey", FailingDataStoreService :: any, MockMessagingService)
            end).to.throw()
        end)

        it("should block writes when data fails to load.", function()
            MockDataStore.GetAsync = function(_, _): (any)
                error("Test failure")
            end
            local SaveData = SaveData.new("TestDataStore", "TestKey", MockDataStoreService, MockMessagingService)
            expect(SaveData:DataLoadedSuccessfully()).to.equal(false)
            SaveData:Set("Test1", "Value1")
            expect(SaveData:Get("Test1")).to.equal("Value1")
            SaveData:Flush()
            MockDataStore:AssertSave(nil)
            SaveData:SetAllowOverwriteOfFailedLoad(true)
            SaveData:Flush()
            MockDataStore:AssertSave({Test1 = "Value1"})
        end)

        it("should retry updates when an update fails.", function()
            --Replace the OnUpdate method temporarily to error.
            local OriginalUpdateAsync = MockDataStore.UpdateAsync
            MockDataStore.UpdateAsync = function()
                error("Test failure")
            end

            --Test an error with UpdateAsync.
            expect(SaveData1:DataLoadedSuccessfully()).to.equal(true)
            SaveData1:Set("Test1","Value1")
            expect(SaveData1:Get("Test1")).to.equal("Value1")
            expect(function()
                SaveData1:Flush()
            end).to.throw()
            MockDataStore:AssertSave(nil)

            --Revert UpdateAsync and assert the data gets saved.
            MockDataStore.UpdateAsync = OriginalUpdateAsync
            SaveData1:Flush()
            MockDataStore:AssertSave({Test1 = "Value1"})
        end)

        it("should retry messagess when a publish fails.", function()
            --Replace the PublishAsync method temporarily to error.
            local OriginalPublishAsync = MockMessagingService.PublishAsync
            MockMessagingService.PublishAsync = function()
                error("Test failure")
            end

            --Test an error with PublishAsync.
            expect(SaveData1:DataLoadedSuccessfully()).to.equal(true)
            SaveData1:Set("Test1", string.rep("Test", 500))
            expect(SaveData1:Get("Test1")).to.equal(string.rep("Test", 500))
            SaveData1:Flush()
            MockDataStore:AssertSave({Test1 = string.rep("Test", 500)})
            MockMessagingService:AssertLastMessage(nil)

            --Revert PublishAsync and assert the changes get sent.
            MockMessagingService.PublishAsync = OriginalPublishAsync
            SaveData1:Flush()
            MockDataStore:AssertSave({Test1 = string.rep("Test", 500)})
            MockMessagingService:AssertLastMessage({Action = "Fetch", Keys = {"Test1"}})
        end)
    end)
end