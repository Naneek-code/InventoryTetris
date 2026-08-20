if not getActivatedMods():contains("\\TEST_FRAMEWORK") or not isDebugEnabled() then return end
local TestFramework = require("TestFramework/TestFramework")
local TestUtils = require("TestFramework/TestUtils")
local TetrisItemData = require("InventoryTetris/Data/TetrisItemData")
local TetrisItemCalculator = require("InventoryTetris/Data/TetrisItemCalculator")
local TetrisItemCategory = require("InventoryTetris/Data/TetrisItemCategory")
local TetrisContainerData = require("InventoryTetris/Data/TetrisContainerData")
local ItemContainerGrid = require("InventoryTetris/Model/ItemContainerGrid")

TestFramework.registerTestModule("Inventory Tetris", "Item Data Precedence Tests", function ()
    local Tests = TestUtils.newTestModule("client/InventoryTetris/Tests/ItemDataPrecedenceTests.lua")

    local testFullType = "InventoryTetris.Test.Precedence"
    local testContainerKey = "InventoryTetris.Test.CustomContainer_20"
    local originalItemData
    local originalDevItemData
    local originalPackCount
    local originalDynamicSize
    local originalStackMultiplier
    local originalFeatherWeight
    local originalContainerData
    local originalDevContainerData
    local originalPlayerContainerData
    local originalDevPlayerContainerData
    local originalEnablePlayerInventoryGrid

    function Tests._setup()
        originalItemData = TetrisItemData._itemData[testFullType]
        originalDevItemData = TetrisItemData._devItemData[testFullType]
        originalPackCount = #TetrisItemData._itemDataPacks
        originalDynamicSize = TetrisItemCalculator._dynamicSizeItems[testFullType]
        originalStackMultiplier = SandboxVars.InventoryTetris.StackSizeMultiplier
        originalFeatherWeight = FeatherWeight
        originalContainerData = TetrisContainerData._containerDefinitions[testContainerKey]
        originalDevContainerData = TetrisContainerData._devContainerDefinitions[testContainerKey]
        originalPlayerContainerData = TetrisContainerData._containerDefinitions["none"]
        originalDevPlayerContainerData = TetrisContainerData._devContainerDefinitions["none"]
        originalEnablePlayerInventoryGrid = SandboxVars.InventoryTetris.EnablePlayerInventoryGrid

        TetrisItemData._itemData[testFullType] = nil
        TetrisItemData._devItemData[testFullType] = nil
        TetrisItemCalculator._dynamicSizeItems[testFullType] = nil
        TetrisContainerData._containerDefinitions[testContainerKey] = nil
        TetrisContainerData._devContainerDefinitions[testContainerKey] = nil
        TetrisContainerData._devContainerDefinitions["none"] = nil
        SandboxVars.InventoryTetris.StackSizeMultiplier = 1.0
        SandboxVars.InventoryTetris.EnablePlayerInventoryGrid = false
    end

    function Tests._teardown()
        while #TetrisItemData._itemDataPacks > originalPackCount do
            table.remove(TetrisItemData._itemDataPacks)
        end

        TetrisItemData._itemData[testFullType] = originalItemData
        TetrisItemData._devItemData[testFullType] = originalDevItemData
        TetrisItemCalculator._dynamicSizeItems[testFullType] = originalDynamicSize
        TetrisContainerData._containerDefinitions[testContainerKey] = originalContainerData
        TetrisContainerData._devContainerDefinitions[testContainerKey] = originalDevContainerData
        TetrisContainerData._containerDefinitions["none"] = originalPlayerContainerData
        TetrisContainerData._devContainerDefinitions["none"] = originalDevPlayerContainerData
        SandboxVars.InventoryTetris.StackSizeMultiplier = originalStackMultiplier
        SandboxVars.InventoryTetris.EnablePlayerInventoryGrid = originalEnablePlayerInventoryGrid
        FeatherWeight = originalFeatherWeight
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

    function Tests.test_dynamicItemsHonorStableDevOverrides()
        local devData = {width = 4, height = 5, maxStackSize = 7}
        TetrisItemCalculator._dynamicSizeItems[testFullType] = true
        TetrisItemData._devItemData[testFullType] = devData

        local resolved = TetrisItemData._getItemDataByFullType(nil, testFullType, false)
        TestUtils.assert(resolved == devData)
    end

    function Tests.test_authoredItemDefinitionBeatsAutomaticFluidSizing()
        local fluidScript = { getCapacity = function() return 10 end }
        local script = {
            containsComponent = function(_, componentType)
                return componentType == ComponentType.FluidContainer
            end,
            getComponentScriptFor = function() return fluidScript end,
        }
        local item = {
            getFullType = function() return testFullType end,
            getScriptItem = function() return script end,
            getFluidContainer = function() return nil end,
            IsInventoryContainer = function() return false end,
        }

        -- Smangsty: Server-authored item footprints outrank every automatic sizing heuristic, including fluid metadata.
        TetrisItemData._itemData[testFullType] = {width = 7, height = 4, maxStackSize = 3}
        local width, height = TetrisItemData.getItemSize(item, false)
        TestUtils.assert(width == 7)
        TestUtils.assert(height == 4)

        TetrisItemData._devItemData[testFullType] = {width = 8, height = 5, maxStackSize = 4}
        width, height = TetrisItemData.getItemSize(item, false)
        TestUtils.assert(width == 8)
        TestUtils.assert(height == 5)
    end

    function Tests.test_authoredContainerDefinitionBeatsAutomaticContainerData()
        local storedDefinition = {
            corrected = true,
            gridDefinitions = {{size = {width = 6, height = 4}, position = {x = 0, y = 0}}},
        }
        local devDefinition = {
            corrected = true,
            gridDefinitions = {{size = {width = 9, height = 5}, position = {x = 0, y = 0}}},
        }
        local container = { getType = function() return "InventoryTetris.Test.CustomContainer" end }

        TetrisContainerData._containerDefinitions[testContainerKey] = storedDefinition
        local resolved = TetrisContainerData._getContainerDefinitionByKey(container, testContainerKey)
        TestUtils.assert(resolved == storedDefinition)

        -- Smangsty: Dev Tool container layouts are authored server data and must remain the highest-precedence definition.
        TetrisContainerData._devContainerDefinitions[testContainerKey] = devDefinition
        resolved = TetrisContainerData._getContainerDefinitionByKey(container, testContainerKey)
        TestUtils.assert(resolved == devDefinition)
    end

    function Tests.test_playerInventoryGridIsOptInAndDevOverrideWins()
        local container = {
            getType = function() return "none" end,
            getCapacity = function() return 0 end,
        }
        local legacyDefinition = {
            gridDefinitions = {
                {size = {width = 1, height = 1}, position = {x = 0, y = 0}},
                {size = {width = 1, height = 1}, position = {x = 1, y = 0}},
            },
        }

        TetrisContainerData._containerDefinitions["none"] = legacyDefinition
        SandboxVars.InventoryTetris.EnablePlayerInventoryGrid = false
        local resolved = TetrisContainerData._getContainerDefinitionByKey(container, "none")
        TestUtils.assert(resolved == legacyDefinition)

        SandboxVars.InventoryTetris.EnablePlayerInventoryGrid = true
        resolved = TetrisContainerData._getContainerDefinitionByKey(container, "none")
        TestUtils.assert(#resolved.gridDefinitions == 1)
        TestUtils.assert(resolved.gridDefinitions[1].size.width == 4)
        TestUtils.assert(resolved.gridDefinitions[1].size.height == 3)
        TestUtils.assert(resolved.validCategories == nil)
        TestUtils.assert(resolved.maxSize == nil)

        local devDefinition = {
            gridDefinitions = {{size = {width = 5, height = 6}, position = {x = 0, y = 0}}},
        }
        TetrisContainerData._devContainerDefinitions["none"] = devDefinition
        resolved = TetrisContainerData._getContainerDefinitionByKey(container, "none")
        TestUtils.assert(resolved == devDefinition)
    end

    function Tests.test_playerInventorySettingDoesNotReplaceAuthoredCustomLayout()
        local container = {
            getType = function() return "none" end,
            getCapacity = function() return 0 end,
        }
        local customDefinition = {
            gridDefinitions = {{size = {width = 7, height = 4}, position = {x = 0, y = 0}}},
        }

        TetrisContainerData._containerDefinitions["none"] = customDefinition
        SandboxVars.InventoryTetris.EnablePlayerInventoryGrid = true
        local resolved = TetrisContainerData._getContainerDefinitionByKey(container, "none")
        TestUtils.assert(resolved == customDefinition)

        local customStockShape = {
            gridDefinitions = {
                {size = {width = 1, height = 1}, position = {x = 0, y = 0}},
                {size = {width = 1, height = 1}, position = {x = 1, y = 0}},
            },
            maxSize = 1,
        }
        TetrisContainerData._containerDefinitions["none"] = customStockShape
        resolved = TetrisContainerData._getContainerDefinitionByKey(container, "none")
        TestUtils.assert(resolved == customStockShape)
    end

    function Tests.test_playerInventoryMigrationClearsObsoleteSecondGridOnly()
        local gridOne = {stacks = {{x = 0, y = 0}}}
        local gridTwo = {stacks = {{x = 1, y = 0}}}
        local modData = {gridContainers = {none = {[1] = gridOne, [2] = gridTwo}}}
        local oldTetrisClient = TetrisClient
        TetrisClient = nil

        ItemContainerGrid._discardLegacyPlayerGridData({
            player = {getModData = function() return modData end},
            inventory = {getType = function() return "none" end},
        })

        TetrisClient = oldTetrisClient
        TestUtils.assert(modData.gridContainers.none[1] == gridOne)
        TestUtils.assert(modData.gridContainers.none[2] == nil)
    end

    function Tests.test_fluidSizingUsesStableScriptComponentBeforeRuntimeAttachment()
        local fluidScript = { getCapacity = function() return 10 end }
        local script = {
            containsComponent = function(_, componentType)
                return componentType == ComponentType.FluidContainer
            end,
            getComponentScriptFor = function() return fluidScript end,
        }
        local item = {
            getScriptItem = function() return script end,
            getFluidContainer = function() return nil end,
        }

        local width, height = TetrisItemCalculator._calculateItemSize(item, TetrisItemCategory.MISC)
        TestUtils.assert(width == 2)
        TestUtils.assert(height == 3)
    end

    function Tests.test_unknownModItemsKeepGenericSizingFallbacks()
        FeatherWeight = nil

        local plainScript = {
            getActualWeight = function() return 3.2 end,
            containsComponent = function() return false end,
        }
        local plainItem = {
            getScriptItem = function() return plainScript end,
            getFluidContainer = function() return nil end,
            getActualWeight = function() return 3.2 end,
        }

        local width, height = TetrisItemCalculator._calculateItemSize(plainItem, TetrisItemCategory.MISC)
        TestUtils.assert(width == 2)
        TestUtils.assert(height == 3)

        local runtimeFluid = { getCapacity = function() return 15 end }
        local fluidItem = {
            getScriptItem = function() return plainScript end,
            getFluidContainer = function() return runtimeFluid end,
        }

        width, height = TetrisItemCalculator._calculateItemSize(fluidItem, TetrisItemCategory.MISC)
        TestUtils.assert(width == 3)
        TestUtils.assert(height == 3)
    end

    function Tests.test_weightMultiplierDoesNotShrinkRangedWeaponFootprint()
        FeatherWeight = {
            sizingScriptWeight = function() return 4.0 end,
        }
        local item = {
            getScriptItem = function()
                return { getActualWeight = function() return 0.4 end }
            end,
        }

        local width, height = TetrisItemCalculator._calculateRangedWeaponSize(item)
        TestUtils.assert(width == 5)
        TestUtils.assert(height == 2)
    end

    function Tests.test_explicitStackMultiplierUsesCanonicalBaseValue()
        local mockItem = {
            getFullType = function() return testFullType end,
            IsInventoryContainer = function() return false end,
        }

        TetrisItemData._itemData[testFullType] = {width = 1, height = 1, maxStackSize = 30}
        TestUtils.assert(TetrisItemData.getBaseMaxStackSize(mockItem) == 30)
        TestUtils.assert(TetrisItemData.getMaxStackSize(mockItem) == 30)

        SandboxVars.InventoryTetris.StackSizeMultiplier = 2.0
        TestUtils.assert(TetrisItemData.getBaseMaxStackSize(mockItem) == 30)
        TestUtils.assert(TetrisItemData.getMaxStackSize(mockItem) == 60)

        TetrisItemData._itemData[testFullType] = {width = 1, height = 1, maxStackSize = 1}
        TestUtils.assert(TetrisItemData.getMaxStackSize(mockItem) == 1)

        -- Smangsty: Auto-calculated values already include the multiplier and must never get doubled here.
        TetrisItemData._itemData[testFullType] = {width = 1, height = 1, maxStackSize = 60, _autoCalculated = true}
        TestUtils.assert(TetrisItemData.getMaxStackSize(mockItem) == 60)
    end

    TestFramework.addCodeCoverage(Tests, TetrisItemData, "TetrisItemData")
    return Tests
end)
