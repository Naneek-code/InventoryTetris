-- Tracks the current drag and drop operation for keyboard and mouse players.
-- Main body of the class is part of the EquipmentUI mod.
---@class DragAndDrop
---@field convertItemStackToItem function
---@field startDrag function
---@field prepareDrag function
---@field isDragging function
---@field isDragOwner function
---@field cancelDrag function
---@field endDrag function
---@field getDraggedItem function
---@field convertItemToStack function
---@diagnostic disable-next-line: undefined-global
local DragAndDrop = require("EquipmentUI/DragAndDrop") or DragAndDrop -- Temp fix until EquipmentUI also removes its globals

function DragAndDrop.isDraggedItemRotated()
    return ISMouseDrag.rotateDrag
end

function DragAndDrop.rotateDraggedItem()
    ISMouseDrag.rotateDrag = not ISMouseDrag.rotateDrag
end

local function isItemLocked(item)
    if not item then return false end
    local modData = item:getModData()
    if modData and modData.tetrisLockTime then
        if getTimestampMs() < modData.tetrisLockTime then
            return true
        end
    end
    return false
end

local function checkLockForItems(items)
    if not items then return false end
    if items.size then
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if isItemLocked(item) then
                return true
            end
        end
    else
        for _, item in ipairs(items) do
            if isItemLocked(item) then
                return true
            end
        end
    end
    return false
end

local og_prepareDrag = DragAndDrop.prepareDrag
function DragAndDrop.prepareDrag(owner, vanillaStacks, x, y)
    if isClient() then
        if vanillaStacks then
            local items = ISInventoryPane.getActualItems(vanillaStacks)
            if checkLockForItems(items) then
                return -- Abort drag completely
            end
        end
    end
    og_prepareDrag(owner, vanillaStacks, x, y)
    ISMouseDrag.rotateDrag = vanillaStacks[1] and vanillaStacks[1].isRotated or vanillaStacks.isRotated
end

-- Cleans out invalid entries
local function cleanDraggedStacks()
    if not ISMouseDrag.dragging then
        return
    end

    -- Clean single stack
    if ISMouseDrag.dragging.items then
        if not ISMouseDrag.dragging.items[1] then
            ISMouseDrag.dragging = nil
        end
        return
    end

    -- Clean multiple stacks
    for i = #ISMouseDrag.dragging, 1, -1 do
        local dragged = ISMouseDrag.dragging[i]
        -- Smangsty: Vanilla key-ring drags may contain raw InventoryItem rows.
        if dragged.items and #dragged.items == 0 then
            table.remove(ISMouseDrag.dragging, i)
        end
    end

    if #ISMouseDrag.dragging == 0 then
        ISMouseDrag.dragging = nil
    end
end

-- Smangsty: Normalize vanilla key-ring rows into unique Tetris drag stacks.
local function getNormalizedKeyRingDraggedStacks()
    local focus = ISMouseDrag.draggingFocus
    if not focus or not focus.tetrisVanillaPane or not ISMouseDrag.dragging then
        return nil
    end

    local actualItems = ISInventoryPane.getActualItems(ISMouseDrag.dragging)
    local seenItems = {}
    local normalizedStacks = {}

    for _, item in ipairs(actualItems) do
        if instanceof(item, "InventoryItem") and not seenItems[item] then
            seenItems[item] = true
            table.insert(normalizedStacks, DragAndDrop.convertItemToStack(item))
        end
    end

    return normalizedStacks
end

function DragAndDrop.getDraggedStack()
    local normalizedStacks = getNormalizedKeyRingDraggedStacks()
    if normalizedStacks then
        return normalizedStacks[1]
    end
    if not ISMouseDrag.dragging then
        return nil
    end

    if ISMouseDrag.dragging[1] then
        return ISMouseDrag.dragging[1]
    end

    cleanDraggedStacks()
    return ISMouseDrag.dragging
end

function DragAndDrop.getDraggedStacks()
    local normalizedStacks = getNormalizedKeyRingDraggedStacks()
    if normalizedStacks then
        return normalizedStacks
    end
    cleanDraggedStacks()
    return ISMouseDrag.dragging
end

return DragAndDrop
