--[[
TheNexusAvenger

Tests the SaveData class.
--]]

local NexusUnitTesting = require("NexusUnitTesting")
local SaveDataTest = NexusUnitTesting.UnitTest:Extend()

local SaveData = require(game:GetService("ServerScriptService"):WaitForChild("NexusDataStore"):WaitForChild("SaveData"))
local HttpService = game:GetService("HttpService")



--[[
Sets up the unit test.
--]]
function SaveDataTest:Setup()
    --Create the mock DataStoreService.
    self.MockDataStore = {
        GetAsync = function(self,Key)
            return self.Data
        end,
        UpdateAsync = function(self,Key,Callback)
            self.Data = Callback(self.Data)
        end,
        AssertSave = function(_,Data)
            if not Data then
                self:AssertEquals(Data,nil,"Saved data is incorrect.")
            else
                self:AssertEquals(HttpService:JSONEncode(Data),HttpService:JSONEncode(self.MockDataStore.Data),"Saved data is incorrect.")
            end
        end,
    }
    self.MockDataStoreService = {
        GetDataStore = function(_,Key)
            return self.MockDataStore
        end
    }

    --Create the mock MessagingService.
    self.MockMessagingService = {
        Event = Instance.new("BindableEvent"),
        PublishAsync = function(self,Topic,Message)
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
                local ActualObject = HttpService:JSONDecode(self.MockMessagingService.LastMessage)
                self:AssertNotNil(ActualObject.SyncId,"Sync id not populated.")
                ActualObject.SyncId = nil
                self:AssertEquals(Object,ActualObject,"Last message is incorrect.")
            end
        end,
    }

    --Create the components under testing.
    self.CuT1 = SaveData.new("TestDataStore","TestKey",self.MockDataStoreService,self.MockMessagingService)
    self.CuT2 = SaveData.new("TestDataStore","TestKey",self.MockDataStoreService,self.MockMessagingService)
end

--[[
Tests replicating between the components under testing.
--]]
NexusUnitTesting:RegisterUnitTest(SaveDataTest.new("Replication"):SetRun(function(self)
    --Connect the OnUpdate calls.
    local LastOnUpdate = {}
    self.CuT1:OnUpdate("Test1",function(Value)
        LastOnUpdate[1] = Value
    end)
    self.CuT1:OnUpdate("Test2",function(Value)
        LastOnUpdate[2] = Value
    end)
    self.CuT1:OnUpdate("Test3",function(Value)
        LastOnUpdate[3] = Value
    end)
    self.CuT1:OnUpdate("Test4",function(Value)
        LastOnUpdate[4] = Value
    end)
    self.CuT1:OnUpdate("Test5",function(Value)
        LastOnUpdate[5] = Value
    end)

    --Set a value and assert it was replicated but not flushed.
    self:AssertTrue(self.CuT1:DataLoadedSuccessfully(),"Data not loaded.")
    self.CuT1:Set("Test1","Value1")
    self:AssertEquals(self.CuT1:Get("Test1"),"Value1","Value wasn't set.")
    self:AssertEquals(self.CuT2:Get("Test1"),"Value1","Value wasn't replicated.")
    self:AssertEquals(LastOnUpdate[1],"Value1","OnUpdate wasn't invoked correctly.")
    self.MockMessagingService:AssertLastMessage({Action="Set",Key="Test1",Value="Value1"})
    self.CuT2:Set("Test1","Value2")
    self:AssertEquals(self.CuT1:Get("Test1"),"Value2","Value wasn't set.")
    self:AssertEquals(self.CuT2:Get("Test1"),"Value2","Value wasn't replicated.")
    self:AssertEquals(LastOnUpdate[1],"Value2","OnUpdate wasn't invoked correctly.")
    self.MockMessagingService:AssertLastMessage({Action="Set",Key="Test1",Value="Value2"})
    self.MockDataStore:AssertSave(nil)

    --Flush the data and assert it was set correctly.
    self.CuT1:Flush()
    self.MockDataStore:AssertSave({Test1="Value2"})
    self.MockMessagingService:AssertLastMessage({Action="Set",Key="Test1",Value="Value2"})

    --Increment a value and assert it was replicated but not flushed.
    self.CuT1:Increment("Test2",3)
    self:AssertEquals(self.CuT1:Get("Test2"),3,"Value wasn't set.")
    self:AssertEquals(self.CuT2:Get("Test2"),3,"Value wasn't replicated.")
    self:AssertEquals(LastOnUpdate[2],3,"OnUpdate wasn't invoked correctly.")
    self.MockMessagingService:AssertLastMessage({Action="Set",Key="Test2",Value=3})
    self.CuT1:Increment("Test2",4)
    self:AssertEquals(self.CuT1:Get("Test2"),7,"Value wasn't set.")
    self:AssertEquals(self.CuT2:Get("Test2"),7,"Value wasn't replicated.")
    self:AssertEquals(LastOnUpdate[2],7,"OnUpdate wasn't invoked correctly.")
    self.MockMessagingService:AssertLastMessage({Action="Set",Key="Test2",Value=7})

    --Flush the data and assert it was set correctly.
    self.CuT1:Flush()
    self.MockDataStore:AssertSave({Test1="Value2",Test2=7})
    self.MockMessagingService:AssertLastMessage({Action="Set",Key="Test2",Value=7})

    --Update a key and assert it was replicated and flushed.
    self.CuT1:Update("Test1",function(OldValue)
        return OldValue.."_3"
    end)
    self:AssertEquals(self.CuT1:Get("Test1"),"Value2_3","Value wasn't set.")
    self:AssertEquals(self.CuT2:Get("Test1"),"Value2_3","Value wasn't replicated.")
    self:AssertEquals(LastOnUpdate[1],"Value2_3","OnUpdate wasn't invoked correctly.")
    self.MockDataStore:AssertSave({Test1="Value2_3",Test2=7})
    self.MockMessagingService:AssertLastMessage({Action="Fetch",Keys={"Test1"}})

    --Update multiple keys and assert it was replicated and flushed.
    self.CuT2:Update({"Test1","Test2"},function(OldValue1,OldValue2)
        return OldValue1.."_4",OldValue2 + 3
    end)
    self:AssertEquals(self.CuT1:Get("Test1"),"Value2_3_4","Value wasn't set.")
    self:AssertEquals(self.CuT2:Get("Test1"),"Value2_3_4","Value wasn't replicated.")
    self:AssertEquals(self.CuT1:Get("Test2"),10,"Value wasn't set.")
    self:AssertEquals(self.CuT2:Get("Test2"),10,"Value wasn't replicated.")
    self:AssertEquals(LastOnUpdate[1],"Value2_3_4","OnUpdate wasn't invoked correctly.")
    self:AssertEquals(LastOnUpdate[2],10,"OnUpdate wasn't invoked correctly.")
    self.MockDataStore:AssertSave({Test1="Value2_3_4",Test2=10})
    self.MockMessagingService:AssertLastMessage({Action="Fetch",Keys={"Test1","Test2"}})

    --Update missing keys and assert it was replicaed correctly.
    self.CuT1:Update({"Test1","Test2","Test3","Test4"},function(OldValue1,OldValue2,OldValue3,OldValue4)
        return OldValue1.."_5",OldValue2 + 2,nil,OldValue2 + 3
    end)
    self:AssertEquals(self.CuT1:Get("Test1"),"Value2_3_4_5","Value wasn't set.")
    self:AssertEquals(self.CuT2:Get("Test1"),"Value2_3_4_5","Value wasn't replicated.")
    self:AssertEquals(self.CuT1:Get("Test2"),12,"Value wasn't set.")
    self:AssertEquals(self.CuT2:Get("Test2"),12,"Value wasn't replicated.")
    self:AssertEquals(self.CuT1:Get("Test3"),nil,"Value wasn't set.")
    self:AssertEquals(self.CuT2:Get("Test3"),nil,"Value wasn't replicated.")
    self:AssertEquals(self.CuT1:Get("Test4"),13,"Value wasn't set.")
    self:AssertEquals(self.CuT2:Get("Test4"),13,"Value wasn't replicated.")
    self:AssertEquals(LastOnUpdate[1],"Value2_3_4_5","OnUpdate wasn't invoked correctly.")
    self:AssertEquals(LastOnUpdate[2],12,"OnUpdate wasn't invoked correctly.")
    self:AssertEquals(LastOnUpdate[4],13,"OnUpdate wasn't invoked correctly.")
    self.MockDataStore:AssertSave({Test1="Value2_3_4_5",Test2=12,Test4=13})
    self.MockMessagingService:AssertLastMessage({Action="Fetch",Keys={"Test1","Test2","Test3","Test4"}})

    --Set a long string and assert it was not replicated.
    self.CuT1:Set("Test5",string.rep("Test",500))
    self:AssertEquals(self.CuT1:Get("Test5"),string.rep("Test",500),"Value wasn't set.")
    self:AssertEquals(self.CuT2:Get("Test5"),nil,"Value was replicated.")
    self:AssertEquals(LastOnUpdate[5],string.rep("Test",500),"OnUpdate wasn't invoked correctly.")
    self.MockDataStore:AssertSave({Test1="Value2_3_4_5",Test2=12,Test4=13})
    self.MockMessagingService:AssertLastMessage({Action="Fetch",Keys={"Test1","Test2","Test3","Test4"}})
    self.CuT1:Flush()
    self.MockDataStore:AssertSave({Test1="Value2_3_4_5",Test2=12,Test4=13,Test5=string.rep("Test",500)})
    self.MockMessagingService:AssertLastMessage({Action="Fetch",Keys={"Test5"}})

    --Disconnect the first component under testing and assert changes aren't replicated.
    self.CuT1:Disconnect()
    self.CuT2:Set("Test1","Value6")
    self:AssertEquals(self.CuT2:Get("Test1"),"Value6","Value wasn't set.")
    self:AssertEquals(self.CuT1:Get("Test1"),"Value2_3_4_5","Value was replicated.")
    self:AssertEquals(LastOnUpdate[1],"Value2_3_4_5","OnUpdate was invoked.")
    self.MockMessagingService:AssertLastMessage({Action="Set",Key="Test1",Value="Value6"})
end))

--[[
Tests errors in the initialization.
--]]
NexusUnitTesting:RegisterUnitTest(SaveDataTest.new("InitializationErrors"):SetRun(function(self)
    --Test an error when connecting the MessagingService.
    local FailingMessagingService = {
        SubscribeAsync = function()
            error("Test failure")
        end,
        PublishAsync = function()
        
        end,
    }
    local CuT = SaveData.new("TestDataStore","TestKey",self.MockDataStoreService,FailingMessagingService)
    CuT:Set("Test1","Value1")
    self:AssertEquals(CuT:Get("Test1"),"Value1","Value wasn't set.")
    CuT:Flush()
    self.MockDataStore:AssertSave({Test1="Value1"})

    --Test an error when getting the DataStore.
    local FailingDataStoreService = {
        GetDataStore = function()
            error("Test failure")
        end,
    }
    self:AssertErrors(function()
        SaveData.new("TestDataStore","TestKey",FailingDataStoreService,self.MockMessagingService)
    end)

    --Test an error when getting the initial data.
    self.MockDataStore.GetAsync = function()
        error("Test failure")
    end
    local CuT = SaveData.new("TestDataStore","TestKey",self.MockDataStoreService,self.MockMessagingService)
    self:AssertFalse(CuT:DataLoadedSuccessfully(),"Data was loaded.")
    CuT:Set("Test1","Value1")
    self:AssertEquals(CuT:Get("Test1"),"Value1","Value wasn't set.")
    CuT:Flush()
    self.MockDataStore:AssertSave(nil)
    CuT:SetAllowOverwriteOfFailedLoad(true)
    CuT:Flush()
    self.MockDataStore:AssertSave({Test1="Value1"})
end))

--[[
Tests errors with UpdateAsync.
--]]
NexusUnitTesting:RegisterUnitTest(SaveDataTest.new("UpdateAsyncErrors"):SetRun(function(self)
    --Replace the OnUpdate method temporarily to error.
    local OriginalUpdateAsync = self.MockDataStore.UpdateAsync
    self.MockDataStore.UpdateAsync = function()
        error("Test failure")
    end

    --Test an error with UpdateAsync.
    self:AssertTrue(self.CuT1:DataLoadedSuccessfully(),"Data wasn't loaded.")
    self.CuT1:Set("Test1","Value1")
    self:AssertEquals(self.CuT1:Get("Test1"),"Value1","Value wasn't set.")
    self:AssertErrors(function()
        self.CuT1:Flush()
    end)
    self.MockDataStore:AssertSave(nil)

    --Revert UpdateAsync and assert the data gets saved.
    self.MockDataStore.UpdateAsync = OriginalUpdateAsync
    self.CuT1:Flush()
    self.MockDataStore:AssertSave({Test1="Value1"})
end))

--[[
Tests errors with PublishAsync.
--]]
NexusUnitTesting:RegisterUnitTest(SaveDataTest.new("PublishAsyncErrors"):SetRun(function(self)
    --Replace the PublishAsync method temporarily to error.
    local OriginalPublishAsync = self.MockMessagingService.PublishAsync
    self.MockMessagingService.PublishAsync = function()
        error("Test failure")
    end

    --Test an error with PublishAsync.
    self:AssertTrue(self.CuT1:DataLoadedSuccessfully(),"Data wasn't loaded.")
    self.CuT1:Set("Test1",string.rep("Test",500))
    self:AssertEquals(self.CuT1:Get("Test1"),string.rep("Test",500),"Value wasn't set.")
    self.CuT1:Flush()
    self.MockDataStore:AssertSave({Test1=string.rep("Test",500)})
    self.MockMessagingService:AssertLastMessage(nil)

    --Revert PublishAsync and assert the changes get sent.
    self.MockMessagingService.PublishAsync = OriginalPublishAsync
    self.CuT1:Flush()
    self.MockDataStore:AssertSave({Test1=string.rep("Test",500)})
    self.MockMessagingService:AssertLastMessage({Action="Fetch",Keys={"Test1"}})
end))



return true