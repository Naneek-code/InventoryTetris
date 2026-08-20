local TetrisItemCategory = require("InventoryTetris/Data/TetrisItemCategory")
local TetrisContainerData = require("InventoryTetris/Data/TetrisContainerData")

local SQUISH_FACTOR = 3
local FLOAT_CORRECTION = 0.001
local MAX_ITEM_WIDTH = 10
local MAX_ITEM_HEIGHT = 12

local TetrisItemCalculator = {}

local function sizingWeight(item)
    if FeatherWeight then return FeatherWeight.sizingWeight(item) end
    return item:getActualWeight()
end

local function sizingScriptWeight(item)
    if FeatherWeight then return FeatherWeight.sizingScriptWeight(item) end
    local script = item and item.getScriptItem and item:getScriptItem()
    return script and script:getActualWeight() or (item and item:getActualWeight() or 0)
end

local function sizingBaseWeight(item)
    if FeatherWeight then return FeatherWeight.sizingBaseWeight(item) end
    return item:getWeight()
end

local function getFluidContainerCapacity(item)
    local script = item and item.getScriptItem and item:getScriptItem()
    local fluidType = ComponentType and ComponentType.FluidContainer
    if script and fluidType and script.containsComponent and script:containsComponent(fluidType) then
        local fluidScript = script:getComponentScriptFor(fluidType)
        if fluidScript then
            -- Smangsty: Footprints are cached by item type; prefer stable script capacity so instance timing/state cannot change the cached shape.
            return fluidScript:getCapacity()
        end
    end

    -- Unknown mod items can still expose only a runtime fluid component; keep the generic compatibility fallback.
    local fluidContainer = item and item.getFluidContainer and item:getFluidContainer()
    return fluidContainer and fluidContainer:getCapacity() or nil
end

TetrisItemCalculator._dynamicSizeItems = {} -- Defined in TetrisItemData instead, directly overwrites this

function TetrisItemCalculator.calculateItemInfo(item)
    local category = TetrisItemCategory.getCategory(item)

    local data = {}
    data.maxStackSize = TetrisItemCalculator._calculateItemStackability(item, category)
    data.width, data.height = TetrisItemCalculator._calculateItemSize(item, category)

    if data.width > MAX_ITEM_WIDTH then data.width = MAX_ITEM_WIDTH end
    if data.height > MAX_ITEM_HEIGHT then data.height = MAX_ITEM_HEIGHT end

    data._autoCalculated = true
    return data
end

function TetrisItemCalculator.calculateItemInfoSquished(unsquishedData)
    local data = {}
    data.width = unsquishedData.width
    data.height = unsquishedData.height
    data.maxStackSize = unsquishedData.maxStackSize

    data.width = math.ceil(data.width / SQUISH_FACTOR)
    data.height = math.ceil(data.height / SQUISH_FACTOR)

    data._autoCalculated = true
    return data
end

---@param item InventoryItem
---@param category string
---@return number
---@return number
function TetrisItemCalculator._calculateItemSize(item, category)
    local fluidCapacity = getFluidContainerCapacity(item)
    if fluidCapacity then
        return TetrisItemCalculator._calculateFluidContainerSize(item, category, fluidCapacity)
    end

    local calculation = TetrisItemCalculator._itemClassToSizeCalculation[category]
    if type(calculation) == "function" then
        ---@cast calculation fun(item: InventoryItem): number, number
        return calculation(item)
    else
        return calculation.x, calculation.y
    end
end

function TetrisItemCalculator._calculateItemSizeMagazine(item)
    local width = 1
    local height = 1

    local maxAmmo = item:getMaxAmmo()
    if maxAmmo > 15 then
        height = 2
        width = 1
    end
    if maxAmmo > 30 then
        height = 3
        width = 1
    end
    if maxAmmo > 45 then
        height = 2
        width = 2
    end

    return width, height
end

function TetrisItemCalculator._calculateRangedWeaponSize(item)
    local width = 2
    local height = 1

    -- Read the original script weight so weight scaling never changes the Tetris footprint.
    local weight = sizingScriptWeight(item)

    if weight >= 2 then
        width = 3
        height = 1
    end
    if weight >= 3 then
        width = 3
        height = 2
    end
    if weight >= 4 then
        width = 5
        height = 2
    end
    if weight >= 5 then
        width = 6
        height = 2
    end
    if weight >= 6 then
        width = 7
        height = 2
    end

    return width, height
end

function TetrisItemCalculator._calculateMeleeWeaponSize(item)
    local width = 1
    local height = 1

    local weight = sizingScriptWeight(item)

    if weight >= 0.5 then
        width = 1
        height = 2
    end
    if weight >= 1.6 then
        width = 1
        height = 3
    end
    if weight >= 2.5 then
        width = 1
        height = 4
    end
    if weight >= 3.5 then
        width = 2
        height = 4
    end
    if weight >= 4 then
        width = 2
        height = 5
    end

    return width, height
end

function TetrisItemCalculator._calculateItemSizeClothing(item)
    local width = 2
    local height = 2

    -- This shouldn't happen, but just in case a mod does something weird
    if item:IsClothing() == false then
        TetrisItemCalculator.itemSizes[item:getFullType()] = {x = width, y = height}
        return
    end

    local bulletDef = item:getBulletDefense()
    if bulletDef >= 50 then
        width = 3
        height = 3
    else
        -- Read the original script weight to ignore wetness and weight scaling.
        local weight = sizingScriptWeight(item)
        if weight >= 3.0 then
            width = 3
            height = 3
        elseif weight <= 0.5 then
            width = 1
            height = 1
        elseif weight <= 1.0 then
            width = 1
            height = 2
        end
    end

    return width, height
end

---comment
---@param item InventoryContainer
function TetrisItemCalculator._calculateItemSizeContainer(item)
    if item:hasTag(ItemTag.KEY_RING) then
        return 1, 1
    end

    local containerDefinition = TetrisContainerData.getContainerDefinition(item:getItemContainer())
    if #containerDefinition.gridDefinitions == 1 then
        local gridDef = containerDefinition.gridDefinitions[1]
        local x,y = gridDef.size.width, gridDef.size.height
        x = x + SandboxVars.InventoryTetris.BonusGridSize
        y = y + SandboxVars.InventoryTetris.BonusGridSize
        return x, y
    end

    local innerSize = TetrisContainerData.calculateInnerSize(item:getItemContainer())
    local x, y = TetrisItemCalculator._calculateContainerItemSizeFromInner(innerSize)
    return x, y
end

-- Returns dimensions for a container item based on the number of items it can hold
-- Always returns a dimension that is >= innerSize
function TetrisItemCalculator._calculateContainerItemSizeFromInner(innerSize)
    local MAX_ITEM_DIM = 12
    if innerSize > MAX_ITEM_DIM * MAX_ITEM_DIM then
        return MAX_ITEM_DIM, MAX_ITEM_DIM
    end

    local best = 99999999
    local bestX = 1
    local bestY = 1

    for x = 1, MAX_ITEM_DIM do
        for y = 1, MAX_ITEM_DIM do
            local result = x * y
            local diff = math.abs(result - innerSize) + math.abs(x - y) -- Encourage square shapes 
            if diff < best and result >= innerSize then
                best = diff
                bestX = x
                bestY = y
            end
        end
    end

    return bestX, bestY
end

function TetrisItemCalculator._calculateMiscSize(item)
    return TetrisItemCalculator._calculateItemSizeWeightBased(item)
end

function TetrisItemCalculator._calculateItemSizeWeightBased(item, weight)
    local width = 1
    local height = 1

    local weight = weight or sizingWeight(item)

    if weight < 1 then
        width = 1
        height = 1
    elseif weight < 2 then
        width = 1
        height = 2
    elseif weight < 3 then
        width = 2
        height = 2
    elseif weight < 4 then
        width = 2
        height = 3
    elseif weight < 5 then
        width = 3
        height = 3
    else
        return TetrisItemCalculator._calculateItemDimensions(weight * 2, 2)
    end

    return width, height
end

function TetrisItemCalculator._calculateFoodSize(item)
    -- Read the original script weight to ignore partial consumption and weight scaling.
    local weight = sizingScriptWeight(item)
    local x, y = TetrisItemCalculator._calculateItemSizeWeightBasedTall(item, weight)

    -- Cap the size of food items
    -- Handles these stupid fish
    if x * y > 18 then
        local x2 = math.min(x, 6)
        local y2 = math.min(y, 3)
        return x2, y2
    end
    return x, y
end

function TetrisItemCalculator._calculateFluidContainerSize(item, category, fluidCapacity)
    -- Smangsty: Script capacity is stable during item construction; runtime fluid components can arrive after the first cached size lookup.
    fluidCapacity = fluidCapacity or getFluidContainerCapacity(item)
    if not fluidCapacity then
        return TetrisItemCalculator._calculateMiscSize(item)
    end

    -- Small containers are 1x1
    if fluidCapacity <= 0.5 then
        return 1, 1
    end

    local slots = math.max(math.pow(fluidCapacity, 0.85), 2)
    local x, y = TetrisItemCalculator._calculateItemDimensions(slots, 2)

    if x > y then
        local temp = x
        x = y
        y = temp
    end

    -- If the fluid container is a moveable item, use the moveable size calculation if it's larger
    if category == TetrisItemCategory.MOVEABLE then
        local mX, mY = TetrisItemCalculator._calculateMoveableSize(item)
        if mX * mY > x * y then
            return mX, mY
        end
    end

    return x, y
end

function TetrisItemCalculator._calculateItemSizeWeightBasedTall(item, weight)
    local width, height = TetrisItemCalculator._calculateItemSizeWeightBased(item, weight)
    return height, width
end

function TetrisItemCalculator._calculateEntertainmentSize(item)
    local width = 1
    local height = 1
    return width, height
end

function TetrisItemCalculator._calculateMoveableSize(item)
    local weight = sizingBaseWeight(item) -- Ignores fluid weight and the sandbox weight multiplier.
    return TetrisItemCalculator._calculateItemDimensions(weight * 2 + 2, 2)
end

function TetrisItemCalculator._calculateAnimalCorpseSize(item)
    local weight = sizingWeight(item)
    if weight < 1 then
        return 1, 1
    end

    local slots = math.pow(weight, 1.5) * 2
    return TetrisItemCalculator._calculateItemDimensions(slots, 3)
end

function TetrisItemCalculator._calculateBookSize(item)
    local weight = sizingWeight(item)
    if weight < 0.2 then
        return 1, 1
    end
    return 1, 2
end

TetrisItemCalculator._itemClassToSizeCalculation = {
    [TetrisItemCategory.AMMO] = {x = 1, y = 1},
    [TetrisItemCategory.CORPSEANIMAL] = TetrisItemCalculator._calculateAnimalCorpseSize,
    [TetrisItemCategory.BOOK] = TetrisItemCalculator._calculateBookSize,
    [TetrisItemCategory.CLOTHING] = TetrisItemCalculator._calculateItemSizeClothing,
    [TetrisItemCategory.CONTAINER] = TetrisItemCalculator._calculateItemSizeContainer,
    [TetrisItemCategory.ENTERTAINMENT] = TetrisItemCalculator._calculateEntertainmentSize,
    [TetrisItemCategory.FOOD] = TetrisItemCalculator._calculateFoodSize,
    [TetrisItemCategory.HEALING] = TetrisItemCalculator._calculateItemSizeWeightBased,
    [TetrisItemCategory.KEY] = {x = 1, y = 1},
    [TetrisItemCategory.MAGAZINE] = TetrisItemCalculator._calculateItemSizeMagazine,
    [TetrisItemCategory.ATTACHMENT] = TetrisItemCalculator._calculateItemSizeWeightBased,
    [TetrisItemCategory.MELEE] = TetrisItemCalculator._calculateMeleeWeaponSize,
    [TetrisItemCategory.MISC] = TetrisItemCalculator._calculateMiscSize,
    [TetrisItemCategory.MOVEABLE] = TetrisItemCalculator._calculateMoveableSize,
    [TetrisItemCategory.RANGED] = TetrisItemCalculator._calculateRangedWeaponSize,
    [TetrisItemCategory.SEED] = {x = 1, y = 1},
}

--- Determine two numbers that multiply *close* to the target slot count
---@param target number -- The target slot count
---@param accuracy number -- Reduces the importance of squaring the shape
function TetrisItemCalculator._calculateItemDimensions(target, accuracy)
    local best = 99999999
    local bestX = 1
    local bestY = 1

    if not accuracy then
        accuracy = 1
    end

    for x = 1, MAX_ITEM_WIDTH do
        for y = 1, MAX_ITEM_HEIGHT do
            local result = x * y
            local diff = math.abs(result - target) + math.abs(x - y)/accuracy -- Encourage square shapes 
            if diff < best then
                best = diff
                bestX = x
                bestY = y
            end
        end
    end

    return bestX, bestY
end






-- Item Stackability

local function roundStackability(stackability)
    return math.max(1, math.floor(stackability + 0.5))
end

-- Smangsty: Keep multiplier validation centralized so automatic and explicit stack definitions obey the same rules.
function TetrisItemCalculator.applyStackSizeMultiplier(maxStack)
    if maxStack <= 1 then
        return 1
    end

    local multiplier = SandboxVars
        and SandboxVars.InventoryTetris
        and tonumber(SandboxVars.InventoryTetris.StackSizeMultiplier)
        or 1.0
    if multiplier ~= multiplier or multiplier == math.huge or multiplier == -math.huge or multiplier <= 0 then
        multiplier = 1.0
    end
    return roundStackability(maxStack * multiplier)
end

---@param item InventoryItem
function TetrisItemCalculator._simpleWeightStackability(item)
    local weight = sizingScriptWeight(item) -- Avoid wetness and sandbox weight scaling.
    return math.ceil(0.75 / weight)
end

function TetrisItemCalculator._calculateItemStackability(item, itemClass)
    local maxStack = 1
    if getFluidContainerCapacity(item) or TetrisItemCalculator._dynamicSizeItems[item:getFullType()] then
        return maxStack
    end

    local calculation = TetrisItemCalculator._itemClassToStackabilityCalculation[itemClass]
    if type(calculation) == "function" then
        maxStack = calculation(item)
    elseif calculation then
        maxStack = calculation
    end

    return TetrisItemCalculator.applyStackSizeMultiplier(maxStack)
end

function TetrisItemCalculator._calculateAmmoStackability(item)
    local maxStack = 30

    local weight = sizingScriptWeight(item)
    if weight >= 0.0375 then
        maxStack = 12
    elseif weight >= 0.025 then
        maxStack = 30
    elseif weight >= 0.0125 then
        maxStack = 60
    elseif weight >= 0.00625 then
        maxStack = 120
    end

    return maxStack
end

function TetrisItemCalculator._calculateEntertainmentStackability(item)
    local maxStack = 1

    local mediaData = item:getMediaData()
    if mediaData then
        local category = mediaData:getCategory()
        if category == "CDs" then
            maxStack = 10
        end
    end

    return maxStack
end

function TetrisItemCalculator._calculateSeedStackability(item)
    local type = item:getFullType()

    if string.find(type, "BagSeed") then
        return 4
    else
        return 50
    end
end

function TetrisItemCalculator._calculateMoveableStackability(item)
    return 1
end

---@param item InventoryItem
function TetrisItemCalculator._calculateFoodStackability(item)
    local weight = sizingScriptWeight(item) -- Ignore partial consumption and sandbox weight scaling.
    return roundStackability(1 / weight)
end

function TetrisItemCalculator._weaponStackability(item)
    local weight = sizingWeight(item) * 2
    return roundStackability(1 / weight)
end

TetrisItemCalculator._itemClassToStackabilityCalculation = {
    [TetrisItemCategory.AMMO] = TetrisItemCalculator._calculateAmmoStackability,
    [TetrisItemCategory.BOOK] = TetrisItemCalculator._simpleWeightStackability,
    [TetrisItemCategory.CLOTHING] = TetrisItemCalculator._simpleWeightStackability,
    [TetrisItemCategory.CONTAINER] = 1,
    [TetrisItemCategory.ENTERTAINMENT] = TetrisItemCalculator._calculateEntertainmentStackability,
    [TetrisItemCategory.HEALING] = TetrisItemCalculator._simpleWeightStackability,
    [TetrisItemCategory.FOOD] = TetrisItemCalculator._calculateFoodStackability,
    [TetrisItemCategory.KEY] = 1,
    [TetrisItemCategory.MAGAZINE] = 1,
    [TetrisItemCategory.MELEE] = TetrisItemCalculator._weaponStackability,
    [TetrisItemCategory.MISC] = TetrisItemCalculator._simpleWeightStackability,
    [TetrisItemCategory.MOVEABLE] = TetrisItemCalculator._calculateMoveableStackability,
    [TetrisItemCategory.RANGED] = 1,
    [TetrisItemCategory.SEED] = TetrisItemCalculator._calculateSeedStackability,
}

return TetrisItemCalculator
