local DragAndDrop = require("InventoryTetris/System/DragAndDrop")

-- Tracks the current drag and drop operation for controller players.
local ControllerDragAndDrop = {}

ControllerDragAndDrop.dragging = {}
ControllerDragAndDrop.draggingTetris = {}
ControllerDragAndDrop.dragOwner = {}
ControllerDragAndDrop.rotateDrag = {}

ControllerDragAndDrop.ownersForCancel = {}

function ControllerDragAndDrop.isDragging(playerNum)
    return ControllerDragAndDrop.dragging[playerNum] ~= nil
end

function ControllerDragAndDrop.isDragOwner(playerNum, testOwner)
    return ControllerDragAndDrop.dragOwner[playerNum] == testOwner
end

function ControllerDragAndDrop.isDraggedItemRotated(playerNum)
    return ControllerDragAndDrop.rotateDrag[playerNum]
end

function ControllerDragAndDrop.rotateDraggedItem(playerNum)
    ControllerDragAndDrop.rotateDrag[playerNum] = not ControllerDragAndDrop.rotateDrag[playerNum]
end

function ControllerDragAndDrop.getDraggedStack(playerNum)
    return ControllerDragAndDrop.dragging[playerNum]
end

function ControllerDragAndDrop.getDraggedTetrisStack(playerNum)
    return ControllerDragAndDrop.draggingTetris[playerNum]
end

function ControllerDragAndDrop.getDraggedItem(playerNum)
    local stack = ControllerDragAndDrop.dragging[playerNum]
    return DragAndDrop.convertItemStackToItem(stack)
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

function ControllerDragAndDrop.startDrag(playerNum, owner, tetrisStack, vanillaStack)
    if isClient() then
        if vanillaStack then
            local items = ISInventoryPane.getActualItems(vanillaStack)
            if checkLockForItems(items) then
                return -- Abort drag completely for controller players
            end
        end
    end

    ControllerDragAndDrop.dragging[playerNum] = vanillaStack
    ControllerDragAndDrop.draggingTetris[playerNum] = tetrisStack
    ControllerDragAndDrop.dragOwner[playerNum] = owner
    ControllerDragAndDrop.rotateDrag[playerNum] = vanillaStack[1] and vanillaStack[1].isRotated or vanillaStack.isRotated
end

function ControllerDragAndDrop.endDrag(playerNum)
    ControllerDragAndDrop.dragging[playerNum] = nil
    ControllerDragAndDrop.draggingTetris[playerNum] = nil
    ControllerDragAndDrop.dragOwner[playerNum] = nil
    ControllerDragAndDrop.rotateDrag[playerNum] = nil
    ControllerDragAndDrop.ownersForCancel = {}
end

return ControllerDragAndDrop
