--[[
TheNexusAvenger

Tests the LocalSaveData class.
--]]
--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local LocalSaveData = require(ServerScriptService:WaitForChild("NexusDataStore"):WaitForChild("LocalSaveData"))

return function()
    local TestLocalSaveData = nil
    beforeEach(function()
        TestLocalSaveData = LocalSaveData.new()
    end)
    afterEach(function()
        TestLocalSaveData:Disconnect()
    end)

    describe("A local SaveData", function()
        it("should have unused functions.", function()
            TestLocalSaveData:SetSendDataChangeUpdates(true)
            TestLocalSaveData:SetAllowOverwriteOfFailedLoad(true)
            TestLocalSaveData:Flush()
            expect(TestLocalSaveData:DataLoadedSuccessfully()).to.equal(false)
        end)

        it("should store data.", function()
            expect(TestLocalSaveData:Get("TestKey")).to.equal(nil)
            TestLocalSaveData:Set("TestKey", "TestValue")
            expect(TestLocalSaveData:Get("TestKey")).to.equal("TestValue")
        end)

        it("should increment values.", function()
            TestLocalSaveData:Increment("TestKey", 4)
            expect(TestLocalSaveData:Get("TestKey")).to.equal(4)
            TestLocalSaveData:Increment("TestKey", 2)
            expect(TestLocalSaveData:Get("TestKey")).to.equal(6)
        end)

        it("should update single keys.", function()
            TestLocalSaveData:Set("TestKey1", 1)
            TestLocalSaveData:Set("TestKey2", 2)
            TestLocalSaveData:Update("TestKey1", function(Value1: number)
                return Value1 + 2
            end)
            expect(TestLocalSaveData:Get("TestKey1")).to.equal(3)
            expect(TestLocalSaveData:Get("TestKey2")).to.equal(2)
        end)

        it("should update multiple keys.", function()
            TestLocalSaveData:Set("TestKey1", 1)
            TestLocalSaveData:Set("TestKey2", 2)
            TestLocalSaveData:Update({"TestKey1", "TestKey2"}, function(Value1: number, Value2: number)
                return Value1 + 2, Value2 + 2
            end)
            expect(TestLocalSaveData:Get("TestKey1")).to.equal(3)
            expect(TestLocalSaveData:Get("TestKey2")).to.equal(4)
        end)

        it("should update multiple keys with nil values.", function()
            TestLocalSaveData:Set("TestKey1", 1)
            TestLocalSaveData:Set("TestKey2", 2)
            TestLocalSaveData:Set("TestKey4", 4)
            TestLocalSaveData:Update({"TestKey1", "TestKey2", "TestKey3", "TestKey4"}, function(Value1: number, Value2: number?, Value3: number, Value4: number)
                return Value1 + 2, nil, (Value2 :: number) + 2, Value4 + 2
            end)
            expect(TestLocalSaveData:Get("TestKey1")).to.equal(3)
            expect(TestLocalSaveData:Get("TestKey2")).to.equal(nil)
            expect(TestLocalSaveData:Get("TestKey3")).to.equal(4)
            expect(TestLocalSaveData:Get("TestKey4")).to.equal(6)
        end)

        it("should fire OnUpdate events for new values.", function()
            local FiredValue = nil
            TestLocalSaveData:OnUpdate("TestKey", function(Value)
                FiredValue = Value
            end)
            TestLocalSaveData:Set("TestKey", "TestValue")
            task.wait()
            expect(FiredValue).to.equal("TestValue")
        end)

        it("should fire not  events for existing values.", function()
            TestLocalSaveData:Set("TestKey", "TestValue")

            local FiredValue = nil
            TestLocalSaveData:OnUpdate("TestKey", function(Value)
                FiredValue = Value
            end)
            TestLocalSaveData:Set("TestKey", "TestValue")
            task.wait()
            expect(FiredValue).to.equal(nil)
        end)
    end)
end