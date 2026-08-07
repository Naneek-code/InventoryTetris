-- Feather Weight - scales item weights so grid space, not weight, is what
-- limits what you can carry.
--
-- ONE setting drives all of this: TetrisMPConfig.ITEM_WEIGHT_MULTIPLIER, mirrored
-- by the "Item Weight Multiplier" sandbox option. 1.0 turns the feature off.
--
-- Why a multiplier instead of a flat weight: a flat value makes weight carry no
-- information at all -- a fridge and a nail become identical. Scaling preserves
-- the ordering, so grid space is what limits you day to day, but loading up on
-- genuinely heavy things still slows you down.
--
-- Lives in shared/ on purpose. Item weight drives encumbrance client-side and is
-- re-validated server-side, so both ends must agree. In MP this must be enabled
-- on the server and on every client.
--
---------------------------------------------------------------------------
-- HOW ITEM WEIGHT ACTUALLY WORKS, because the whole design hangs off it
---------------------------------------------------------------------------
--
-- InventoryItem.actualWeight is a per-instance field, COPIED FROM THE SCRIPT ITEM
-- WHEN THE ITEM IS CONSTRUCTED and never refreshed afterwards. It is only written
-- to the save when isCustomWeight() is true (fish, trapped animals), so for every
-- ordinary item the weight you see is whatever the script item said at the moment
-- that item was built.
--
-- Two consequences, and between them they were the entire "the multiplier works
-- randomly" bug:
--
--   1. Scaling the script items only affects items built AFTERWARDS. Anything the
--      game had already deserialized -- your own inventory, the containers in the
--      chunks that loaded during connect -- keeps its vanilla weight forever. That
--      is why some items scaled and the rest looked vanilla, and why it came out
--      differently on every reconnect: it is a race against world loading.
--      Fixed by applying as early as the sandbox values exist (OnInitWorld /
--      OnLoadMapZones, well before chunks stream in) and by repairing any item
--      that was built too early, in normalizeItem below.
--
--   2. Inventory Tetris works out how big an item is IN THE GRID from its weight.
--      So a weight that arrived late did not just show the wrong number, it
--      resized the item: a car hood at vanilla 15kg is 5x6 slots, at 10% it is
--      1x2, at 1% it is 1x1. Same item, different session, different footprint,
--      and the same story for book stack sizes.
--      Fixed by never letting the grid see a scaled weight: everything Tetris
--      sizes from goes through the sizing* helpers below, which report the
--      ORIGINAL weight. Footprints are now identical whatever the multiplier is.
--
---------------------------------------------------------------------------
-- There are TWO sources of item weight in this game and both need handling:
--
--   1. Script items (items.txt). getScriptManager():getAllItems() covers every
--      one of these, including items added by other mods.
--
--   2. Moveables -- furniture, appliances, the heavy things. These do NOT read
--      their weight from a script item. ISMoveableSpriteProps.new reads the
--      sprite's PickUpWeight world property instead (rawWeight / 10), then
--      stamps it onto the instantiated item. Scaling only script items leaves
--      every couch and dresser at full weight, which is exactly the category
--      that matters most for carrying capacity.

-- Intentional global, matching TetrisMPConfig / TetrisItemData.
FeatherWeight = {}

local TAG = "[INVENTORY_TETRISP] FeatherWeight:"

-- Nothing is ever scaled below this. A zero-weight item upsets recipe and
-- container-capacity code, and it makes the unscaling maths below undefined.
local WEIGHT_FLOOR = 0.001

-- Weights are floats; anything closer than this counts as "the same weight".
local EPSILON = 0.000001

-- fullName -> the weight the item shipped with, captured before anything is
-- scaled. Every apply recomputes from this rather than from the item's current
-- weight, so applying twice in one session cannot compound the scaling.
local originalWeights = {}
local haveOriginals = false

-- The multiplier currently baked into the script items. 1.0 means untouched.
local appliedMultiplier = 1.0

-- Bumped every time the script items are (re)scaled. Callers that sweep a
-- container use it to sweep once and then leave it alone: once the script items
-- are scaled, every item built afterwards is already correct, so a container is
-- only ever worth checking once per generation.
local generation = 0

local moveablePatchInstalled = false

-- nil = not tested yet. Set to false permanently if this build of the game does
-- not expose the per-instance weight API, so the repair pass stops trying.
local canRepairItems = nil

local function getMultiplier()
    if not TetrisMPConfig or not TetrisMPConfig.getItemWeightMultiplier then
        return 1.0
    end
    return TetrisMPConfig.getItemWeightMultiplier()
end

local function scaleWeight(base)
    if type(base) ~= "number" then return base end

    -- Feature off: hand back the original untouched, floor and all. This is also
    -- what restores vanilla weights if the multiplier is turned off mid-session.
    if appliedMultiplier >= 1.0 then return base end

    local weight = base * appliedMultiplier
    if weight < WEIGHT_FLOOR then
        weight = WEIGHT_FLOOR
    end

    return weight
end

---------------------------------------------------------------------------
-- 1. Script items
---------------------------------------------------------------------------

local function snapshotOriginals(allItems)
    if haveOriginals then return end

    for i = 1, allItems:size() do
        local item = allItems:get(i - 1)
        pcall(function()
            originalWeights[item:getFullName()] = item:getActualWeight()
        end)
    end

    haveOriginals = true
end

local function applyScriptItemWeights()
    if not getScriptManager then
        return false
    end

    local allItems = getScriptManager():getAllItems()
    if not allItems then
        return false
    end

    -- Must happen before the first item is touched, and only once per session.
    snapshotOriginals(allItems)

    local scaled, skipped = 0, 0

    for i = 1, allItems:size() do
        local item = allItems:get(i - 1)

        local ok = pcall(function()
            local name = item:getFullName()

            local base = originalWeights[name]
            if base == nil then
                -- An item registered after our snapshot. Its current weight has
                -- never been through here, so it is still the original.
                base = item:getActualWeight()
                originalWeights[name] = base
            end

            item:setActualWeight(scaleWeight(base))
        end)

        if ok then
            scaled = scaled + 1
        else
            skipped = skipped + 1
        end
    end

    print(TAG .. " script items: multiplier=" .. tostring(appliedMultiplier)
        .. " scaled=" .. tostring(scaled)
        .. " skipped=" .. tostring(skipped))

    return true
end

---------------------------------------------------------------------------
-- 2. Moveables (furniture)
---------------------------------------------------------------------------

local function installMoveablePatch()
    if moveablePatchInstalled then return end

    if not ISMoveableSpriteProps or not ISMoveableSpriteProps.new then
        print(TAG .. " moveable patch skipped, ISMoveableSpriteProps unavailable")
        return
    end

    moveablePatchInstalled = true

    local og_new = ISMoveableSpriteProps.new

    -- Varargs rather than a named parameter, because this is reached both as
    -- ISMoveableSpriteProps.new(sprite) and via the fromObject helpers.
    ISMoveableSpriteProps.new = function(...)
        local s = og_new(...)

        -- customItem moveables (radios and friends) take their weight from a real
        -- script item, which applyScriptItemWeights already scaled. Scaling those
        -- again would compound. Only the generic sprite-prop path needs us.
        if s and not s.customItem and type(s.weight) == "number" then
            s.weight = scaleWeight(s.weight)
            s.rawWeight = s.weight * 10
        end

        return s
    end

    -- og_new recomputes weight from the raw sprite properties every call, so this
    -- wrapper cannot compound even when the same sprite is inspected repeatedly,
    -- and it reads appliedMultiplier fresh so it never needs reinstalling.
    print(TAG .. " moveable patch installed, furniture weights now scale too")
end

---------------------------------------------------------------------------
-- 3. Repairing items that were built before the scaling landed
---------------------------------------------------------------------------

--- Brings one already-constructed item into line with its (scaled) script item.
---
--- Deliberately conservative: it only touches items still carrying the EXACT
--- weight they were built with. Anything given a weight at runtime is left alone
--- -- fish and trapped animals (isCustomWeight, a real measured weight that was
--- never scaled), moveable furniture (weight comes from the sprite, already
--- scaled by the patch above), foraged items (weight already scaled, then
--- modified). Rescaling any of those would be wrong in a way that persists.
---@param item InventoryItem
function FeatherWeight.normalizeItem(item)
    if appliedMultiplier >= 1.0 or canRepairItems == false or not item then
        return
    end

    if canRepairItems == nil then
        -- One-time probe. If this build does not expose the API, give up for good
        -- rather than paying for a failing pcall on every item, every frame.
        canRepairItems = pcall(function()
            local _ = item:getActualWeightUnmodded()
            local _ = item:isCustomWeight()
        end)
        if not canRepairItems then
            print(TAG .. " per-item weight repair unavailable on this build")
            return
        end
    end

    if item:isCustomWeight() then return end

    local script = item:getScriptItem()
    if not script then return end

    local original = originalWeights[script:getFullName()]
    if not original then return end

    local current = item:getActualWeightUnmodded()
    if math.abs(current - original) > EPSILON then
        -- Not a stale item: something set this weight on purpose.
        return
    end

    local target = script:getActualWeight()
    if math.abs(current - target) <= EPSILON then
        return
    end

    item:setActualWeight(target)
end

--- Changes whenever the script items are rescaled. See `generation` above.
---@return number
function FeatherWeight.getGeneration()
    return generation
end

--- Repairs every item in a container, and in any container inside it.
---@param inventory ItemContainer
---@param depth number|nil
function FeatherWeight.normalizeContainer(inventory, depth)
    if appliedMultiplier >= 1.0 or canRepairItems == false or not inventory then
        return
    end

    depth = depth or 0
    if depth > 4 then return end

    local items = inventory:getItems()
    if not items then return end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            FeatherWeight.normalizeItem(item)

            if item:IsInventoryContainer() then
                FeatherWeight.normalizeContainer(item:getItemContainer(), depth + 1)
            end
        end
    end
end

local function normalizeAllPlayers()
    if appliedMultiplier >= 1.0 then return end

    -- Dedicated servers have no local players and no player accessors.
    if not getNumActivePlayers or not getSpecificPlayer then return end

    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player then
            FeatherWeight.normalizeContainer(player:getInventory())
        end
    end
end

---------------------------------------------------------------------------
-- 4. Weights for Inventory Tetris to size items from
---------------------------------------------------------------------------
--
-- These always report the ORIGINAL, unscaled weight, so an item's grid footprint
-- and stack size never move when the multiplier changes. Without this, the whole
-- point of the mod quietly evaporates at low multipliers: everything scales down
-- past the 1kg threshold and every item in the game becomes 1x1.

--- Converts a weight expressed in the scaled world back to the vanilla scale.
--- Uses the item's own original/current ratio rather than the raw multiplier, so
--- items sitting on the WEIGHT_FLOOR come back exact too.
---@param item InventoryItem
---@param weight number
---@return number
function FeatherWeight.unscaleWeight(item, weight)
    if appliedMultiplier >= 1.0 or not item or type(weight) ~= "number" then
        return weight
    end

    -- A real measured weight that was never scaled. Leave it be.
    if canRepairItems == true and item:isCustomWeight() then
        return weight
    end

    local script = item:getScriptItem()
    if not script then return weight end

    local original = originalWeights[script:getFullName()]
    if not original then return weight end

    local scaled = script:getActualWeight()
    if not scaled or scaled <= 0 then return weight end

    return weight * (original / scaled)
end

--- Vanilla-scale replacement for item:getActualWeight().
function FeatherWeight.sizingWeight(item)
    FeatherWeight.normalizeItem(item)
    return FeatherWeight.unscaleWeight(item, item:getActualWeight())
end

--- Vanilla-scale replacement for item:getScriptItem():getActualWeight().
--- Reads the snapshot directly, so it is exact regardless of the item's state.
function FeatherWeight.sizingScriptWeight(item)
    local script = item:getScriptItem()
    if not script then return item:getActualWeight() end

    local scriptWeight = script:getActualWeight()
    if appliedMultiplier >= 1.0 then return scriptWeight end

    return originalWeights[script:getFullName()] or scriptWeight
end

--- Vanilla-scale replacement for item:getWeight().
function FeatherWeight.sizingBaseWeight(item)
    FeatherWeight.normalizeItem(item)
    return FeatherWeight.unscaleWeight(item, item:getWeight())
end

---------------------------------------------------------------------------
-- 5. Applying, and reapplying when the value turns up late
---------------------------------------------------------------------------

local function applyAll()
    local multiplier = getMultiplier()

    -- Every hook below calls this; the work only happens when the answer has
    -- actually changed. That is what lets us hook the world-load sequence in
    -- several places without scanning the item list five times per load.
    if multiplier == appliedMultiplier and haveOriginals then
        return
    end

    appliedMultiplier = multiplier

    if not applyScriptItemWeights() then
        print(TAG .. " skipped, script manager unavailable")
        return
    end

    generation = generation + 1

    installMoveablePatch()

    -- Anything the game built before this point is still carrying vanilla
    -- weights. Encumbrance reads the player's inventory every tick, so fix that
    -- one eagerly; everything else is repaired the moment Tetris looks at it.
    normalizeAllPlayers()
end

-- SandboxVars are populated by SandboxOptions.load(), which IsoWorld.init runs
-- AFTER it fires OnInitWorld and BEFORE OnLoadMapZones. So OnLoadMapZones is the
-- earliest point the real multiplier is readable, and it is still well before
-- chunks stream in and start building items.
--
-- Everything after it is a safety net for load orders we cannot see (dedicated
-- servers, clients taking their sandbox values from the server mid-connect).
-- applyAll no-ops unless the value changed, so the extra hooks are free.
Events.OnInitWorld.Add(applyAll)
Events.OnLoadMapZones.Add(applyAll)
Events.OnLoadedMapZones.Add(applyAll)
Events.OnGameStart.Add(applyAll)

-- A player arriving is the one moment worth sweeping even when nothing changed:
-- their inventory came off the save (or off the server) rather than being built
-- fresh, and encumbrance reads it every tick.
Events.OnCreatePlayer.Add(function()
    applyAll()
    normalizeAllPlayers()
end)

if Events.OnServerStarted then
    Events.OnServerStarted.Add(applyAll)
end

if Events.OnConnected then
    Events.OnConnected.Add(applyAll)
end
