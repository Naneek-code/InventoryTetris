if not getActivatedMods():contains("\\TEST_FRAMEWORK") or not isDebugEnabled() then return end

local TestFramework = require("TestFramework/TestFramework")
local TestUtils = require("TestFramework/TestUtils")

local TetrisContainerData = require("InventoryTetris/Data/TetrisContainerData")
local TetrisItemCategory = require("InventoryTetris/Data/TetrisItemCategory")
local TetrisItemData = require("InventoryTetris/Data/TetrisItemData")
local TetrisValidation = require("InventoryTetris/Data/TetrisValidation")

TestFramework.registerTestModule("Inventory Tetris", "Compatibility Regression Tests", function ()
    local Tests = TestUtils.newTestModule("client/InventoryTetris/Tests/CompatibilityRegressionTests.lua")

    function Tests.test_b42FoodSeedsClassifyAsSeed()
        local seed = instanceItem("Base.CilantroSeed")
        TestUtils.assert(TetrisItemCategory.getCategory(seed) == TetrisItemCategory.SEED)
    end

    function Tests.test_firstAidKitAcceptsVanillaSutureThread()
        local kit = instanceItem("Base.FirstAidKit")
        local container = kit:getItemContainer()
        local containerDef = TetrisContainerData.getContainerDefinition(container)

        TestUtils.assert(TetrisValidation.validateInsert(container, containerDef, instanceItem("Base.Thread")))
        TestUtils.assert(TetrisValidation.validateInsert(container, containerDef, instanceItem("Base.DentalFloss")))
    end

    function Tests.test_smallDrawstringBagsAcceptSeeds()
        local seed = instanceItem("Base.CilantroSeed")
        local bagTypes = {
            "Base.SeedBag_Farming",
            "Base.SeedBag",
            "Base.DiceBag",
            "Base.GemBag",
        }

        for _, bagType in ipairs(bagTypes) do
            local bag = instanceItem(bagType)
            local container = bag:getItemContainer()
            local containerDef = TetrisContainerData.getContainerDefinition(container)
            TestUtils.assert(TetrisValidation.validateInsert(container, containerDef, seed))
        end
    end

    function Tests.test_hydrationBackpacksUseBackpackFootprint()
        local bagTypes = {
            "Base.Bag_HydrationBackpack",
            "Base.Bag_HydrationBackpack_Camo",
        }

        for _, bagType in ipairs(bagTypes) do
            local bag = instanceItem(bagType)
            local width, height = TetrisItemData.getItemSizeUnsquished(bag, false)
            TestUtils.assert(width == 3 and height == 4)

            local squished = TetrisItemData.getItemData_squishState(bag, true)
            TestUtils.assert(squished.width == 1 and squished.height == 2)
        end
    end

    function Tests.test_sugarPackagesHaveMatchingFootprints()
        local sugar = instanceItem("Base.Sugar")
        local brownSugar = instanceItem("Base.SugarBrown")
        local sugarW, sugarH = TetrisItemData.getItemSizeUnsquished(sugar, false)
        local brownW, brownH = TetrisItemData.getItemSizeUnsquished(brownSugar, false)

        TestUtils.assert(sugarW == 1 and sugarH == 2)
        TestUtils.assert(brownW == sugarW and brownH == sugarH)
        TestUtils.assert(TetrisItemData.getMaxStackSize(brownSugar) == TetrisItemData.getMaxStackSize(sugar))
    end

    return Tests
end)
