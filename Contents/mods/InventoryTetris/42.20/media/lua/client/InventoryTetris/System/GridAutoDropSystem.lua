local ItemContainerGrid = require("InventoryTetris/Model/ItemContainerGrid")
local KeyRingSupport = require("InventoryTetris/KeyRingSupport")
local ItemUtil = require("Notloc/ItemUtil")

-- Responsible for forcing items out of the player's inventory when it slips into an invalid state
local GridAutoDropSystem = {}

local CHECK_INTERVAL_MS = 300
local CANDIDATE_GRACE_MS = 500
GridAutoDropSystem._lastCheck = 0

-- Smangsty: Keys inside vanilla key-ring containers are exempt from spatial auto-drop.
local function isInsideKeyRing(item)
    return KeyRingSupport.isContainer(item and item:getContainer())
end

local function getCandidateSource(candidate)
    if type(candidate) == "table" and candidate.sourceContainer then
        return candidate.sourceContainer
    end
    return nil
end

local function getCandidateDetectedAt(candidate)
    if type(candidate) == "table" and candidate.detectedAt then
        return candidate.detectedAt
    end
    return 0
end

local function isSourceStillOnPlayer(sourceContainer, playerObj)
    if not sourceContainer or not playerObj then return false end

    local playerInventory = playerObj:getInventory()
    if sourceContainer == playerInventory then return true end

    local containingItem = sourceContainer:getContainingItem()
    return containingItem and playerInventory:containsRecursive(containingItem) or false
end

local function isPlaceCursorActive(playerNum)
    local cell = getCell()
    local cursor = cell and cell:getDrag(playerNum) or nil
    return cursor and cursor.Type == "ISPlace3DItemCursor" or false
end

function GridAutoDropSystem._isActionQueueIdle(playerObj)
    if not playerObj then return false end
    local actionQueueObj = ISTimedActionQueue.getTimedActionQueue(playerObj)
    return not actionQueueObj or not actionQueueObj.queue or #actionQueueObj.queue == 0
end

function GridAutoDropSystem._processItems(playerNum, itemMap)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or playerObj:isDead() then return {} end

    -- Smangsty: UI teardown/rebuild can briefly leave the player's inventory page unavailable.
    -- Keep the candidates queued instead of making decisions against a half-destroyed inventory UI.
    if not getPlayerInventory(playerNum) then return nil end

    local isDisorganized = playerObj:hasTrait(CharacterTrait.DISORGANIZED)
    local containers = ItemUtil.getAllEquippedContainers(playerObj)
    local hotbar = getPlayerHotbar(playerNum)
    local gridCache = {}
    local resolvedItems = {}

    for item, candidate in pairs(itemMap) do
        local sourceContainer = getCandidateSource(candidate)

        -- Smangsty: MP and timed actions can move an item after overflow noticed it; stale references don't get a second vote.
        if not isSourceStillOnPlayer(sourceContainer, playerObj) or not sourceContainer:contains(item) then
            resolvedItems[item] = true
        else
            local inHotbar = hotbar and hotbar:isInHotbar(item)
            local isHeld = playerObj:isHandItem(item)
            local isProtected = item:isEquipped() or isHeld or inHotbar or isInsideKeyRing(item) or ItemContainerGrid.isLiveAnimalCarrier(item)

            if isProtected then
                resolvedItems[item] = true
            else
                local currentContainer = item:getContainer()
                if not currentContainer then
                    resolvedItems[item] = true
                else
                    local containerGrid = gridCache[currentContainer] or ItemContainerGrid.GetOrCreate(currentContainer, playerNum)
                    gridCache[currentContainer] = containerGrid

                    local existingStack = containerGrid:findStackByItem(item)
                    if existingStack then
                        resolvedItems[item] = true
                    elseif containerGrid:canAddItem(item) and containerGrid:autoPositionItem(item, isDisorganized) then
                        resolvedItems[item] = true
                    else
                        local queuedTransfer = false
                        for _, container in ipairs(containers) do
                            local targetGrid = ItemContainerGrid.GetOrCreate(container, playerNum)
                            if currentContainer ~= container and targetGrid:canAddItem(item) then
                                local transfer = ISInventoryTransferAction:new(playerObj, item, currentContainer, container, 1)
                                transfer.enforceTetrisRules = true
                                ISTimedActionQueue.add(transfer)
                                queuedTransfer = true
                                break
                            end
                        end

                        if queuedTransfer or GridAutoDropSystem._handleDropItem(item, playerNum) then
                            resolvedItems[item] = true
                        end
                    end
                end
            end
        end
    end

    return resolvedItems
end

function GridAutoDropSystem._handleDropItem(item, playerNum)
    -- Smangsty: Live animal carriers are vanilla-owned state; passive overflow recovery never puts the damn chicken down for you.
    if ItemContainerGrid.isLiveAnimalCarrier(item) then return true end

    if GridAutoDropSystem._isItemUndroppable(item) then
        return GridAutoDropSystem._forceItemIntoInventoryOrHands(item, playerNum)
    end

    local playerObj = getSpecificPlayer(playerNum)
    local sourceContainer = item and item:getContainer() or nil
    local floorContainer = ISInventoryPage.GetFloorContainer(playerNum)
    if not playerObj or not sourceContainer or not floorContainer then return false end

    item:setFavorite(false) -- We don't play favorites here
    local transfer = ISInventoryTransferAction:new(playerObj, item, sourceContainer, floorContainer, 1)
    ISTimedActionQueue.add(transfer)
    return true
end

-- Certain furniture items (like the fridge) can't be dropped on the floor as an item, they must be placed in the world.
-- We can't do that on the player's behalf, so we'll just force the item into their inventory or hands.
function GridAutoDropSystem._isItemUndroppable(item)
    return instanceof(item, "Moveable") and item:getSpriteGrid() == nil and not item:CanBeDroppedOnFloor()
end

function GridAutoDropSystem._forceItemIntoInventoryOrHands(item, playerNum)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return false end
    if GridAutoDropSystem._attemptToForcePositionItem(item, playerObj, playerNum) then return true end
    if GridAutoDropSystem._attemptToForceEquipItem(item, playerObj, playerNum) then return true end
    return false
end

function GridAutoDropSystem._attemptToForcePositionItem(item, playerObj, playerNum)
    local inventory = playerObj:getInventory()
    local grid = ItemContainerGrid.GetOrCreate(inventory, playerNum)
    if grid:canAddItem(item) then
        ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, item, item:getContainer(), inventory, 1))
        return true
    end

    local wornItems = playerObj:getWornItems()
    for i = 0, wornItems:size()-1 do
        local wornItem = wornItems:get(i):getItem()
        if wornItem:IsInventoryContainer() then
            local grid = ItemContainerGrid.GetOrCreate(wornItem:getInventory(), playerNum)
            if grid:canAddItem(item) then
                ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, item, item:getContainer(), wornItem:getInventory(), 1))
                return true
            end
        end
    end
end

---@param item InventoryItem
---@param playerObj IsoPlayer
---@param playerNum integer
function GridAutoDropSystem._attemptToForceEquipItem(item, playerObj, playerNum)
    local primHand = playerObj:getPrimaryHandItem()
    local secHand = playerObj:getSecondaryHandItem()
    local requiresBothHands = item:isRequiresEquippedBothHands()

    if not instanceof(primHand, "Moveable") then
        ISTimedActionQueue.add(ISEquipWeaponAction:new(playerObj, item, 0, true, requiresBothHands));
        return true
    end

    if not requiresBothHands and not instanceof(secHand, "Moveable") then
        ISTimedActionQueue.add(ISEquipWeaponAction:new(playerObj, item, 0, false, requiresBothHands));
        return true
    end

    return false
end

function GridAutoDropSystem._processQueues()
    local now = getTimestampMs()
    if now - GridAutoDropSystem._lastCheck < CHECK_INTERVAL_MS then return end
    GridAutoDropSystem._lastCheck = now

    for playerNum, itemMap in pairs(ItemContainerGrid._unpositionedItemSetsByPlayer) do
        local playerObj = getSpecificPlayer(playerNum)
        if not playerObj or playerObj:isDead() then
            ItemContainerGrid._unpositionedItemSetsByPlayer[playerNum] = nil
        elseif not isPlaceCursorActive(playerNum) and GridAutoDropSystem._isActionQueueIdle(playerObj) then
            -- Smangsty: Timed actions and the 3D placement cursor own transient inventory state; auto-drop can wait its damn turn.
            local readyItems = {}
            for item, candidate in pairs(itemMap) do
                if now - getCandidateDetectedAt(candidate) >= CANDIDATE_GRACE_MS then
                    readyItems[item] = candidate
                end
            end

            local resolvedItems = GridAutoDropSystem._processItems(playerNum, readyItems)
            if resolvedItems then
                for item, _ in pairs(resolvedItems) do
                    if itemMap[item] == readyItems[item] then
                        itemMap[item] = nil
                    end
                end
            end
        end
    end
end

Events.OnTick.Add(GridAutoDropSystem._processQueues)

return GridAutoDropSystem
