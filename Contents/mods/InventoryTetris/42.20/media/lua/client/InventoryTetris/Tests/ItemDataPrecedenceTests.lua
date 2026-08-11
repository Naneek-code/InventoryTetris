if not getActivatedMods():contains("\\TEST_FRAMEWORK") or not isDebugEnabled() then return end
local TestFramework = require("TestFramework/TestFramework")
local TestUtils = require("TestFramework/TestUtils")
local TetrisItemData = require("InventoryTetris/Data/TetrisItemData")

TestFramework.registerTestModule("Inventory Tetris", "Item Data Precedence Tests", function ()
    local Tests = TestUtils.newTestModule("client/InventoryTetris/Tests/ItemDataPrecedenceTests.lua")

    local testFullType = "InventoryTetris.Test.Precedence"
    local originalItemData
    local originalDevItemData
    local originalPackCount

    function Tests._setup()
        originalItemData = TetrisItemData._itemData[testFullType]
        originalDevItemData = TetrisItemData._devItemData[testFullType]
        originalPackCount = #TetrisItemData._itemDataPacks

        TetrisItemData._itemData[testFullType] = nil
        TetrisItemData._devItemData[testFullType] = nil
    end

    function Tests._teardown()
        while #TetrisItemData._itemDataPacks > originalPackCount do
            table.remove(TetrisItemData._itemDataPacks)
        end

        TetrisItemData._itemData[testFullType] = originalItemData
        TetrisItemData._devItemData[testFullType] = originalDevItemData
    end

    function Tests.test_customAndDevOverridesWin()
        -- Smangsty: Protect server/admin-authored item data from future bundled data-pack precedence regressions.
        TetrisItemData.registerItemDefinitions({
            [testFullType] = {width = 1, height = 1, maxStackSize = 1},
        })

        TetrisItemData.registerItemDefinitions({
            [testFullType] = {width = 2, height = 2, maxStackSize = 2},
        })

        local customData = TetrisItemData._getItemDataByFullType(nil, testFullType, false)
        TestUtils.assert(customData.width == 2)
        TestUtils.assert(customData.height == 2)
        TestUtils.assert(customData.maxStackSize == 2)

        TetrisItemData._devItemData[testFullType] = {width = 3, height = 3, maxStackSize = 3}

        local devData = TetrisItemData._getItemDataByFullType(nil, testFullType, false)
        TestUtils.assert(devData.width == 3)
        TestUtils.assert(devData.height == 3)
        TestUtils.assert(devData.maxStackSize == 3)

        TetrisItemData._devItemData[testFullType] = nil

        local restoredCustomData = TetrisItemData._getItemDataByFullType(nil, testFullType, false)
        TestUtils.assert(restoredCustomData.width == 2)
        TestUtils.assert(restoredCustomData.height == 2)
        TestUtils.assert(restoredCustomData.maxStackSize == 2)
    end

    TestFramework.addCodeCoverage(Tests, TetrisItemData, "TetrisItemData")
    return Tests
end)
