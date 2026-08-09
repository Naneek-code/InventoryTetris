local DragAndDrop = {}
DragAndDrop.ownersForCancel = {}

function DragAndDrop.isDragging()
    return ISMouseDrag.dragging ~= nil
end

function DragAndDrop.getDraggedItem()
    if DragAndDrop.isDragging() then
        return DragAndDrop.convertItemStackToItem(ISMouseDrag.dragging)
    end
    return nil
end

function DragAndDrop.isDragOwner(testOwner)
    return ISMouseDrag.dragOwner == testOwner
end

function DragAndDrop.prepareDrag(owner, itemStack, x, y)
    DragAndDrop.ownersForCancel = {}

    ISMouseDrag.dragOwner = owner
    ISMouseDrag.itemsToDrag = itemStack
    ISMouseDrag.localXStart = x;
    ISMouseDrag.localYStart = y;
end

function DragAndDrop.startDrag(owner)
    if owner ~= ISMouseDrag.dragOwner then
        return
    end

    if not ISMouseDrag.dragging and ISMouseDrag.itemsToDrag then
        local x = owner:getMouseX()
        local y = owner:getMouseY()

        local dragLimit = 8
        if math.abs(x - ISMouseDrag.localXStart) > dragLimit or math.abs(y - ISMouseDrag.localYStart) > dragLimit then

            ISMouseDrag.dragging = ISMouseDrag.itemsToDrag
            ISMouseDrag.itemsToDrag = nil
        end
    end
end

function DragAndDrop.endDrag()
    ISMouseDrag.itemsToDrag = nil
	ISMouseDrag.dragging = nil;
    ISMouseDrag.dragOwner = nil;
    DragAndDrop.ownersForCancel = {}
end

function DragAndDrop.cancelDrag(owner, cancelCallback)
    if owner ~= ISMouseDrag.dragOwner then
        return
    end
    DragAndDrop.ownersForCancel[owner] = {callback = cancelCallback}
end

function DragAndDrop.convertItemToStack(item)
    return { items = {item, item} } -- First item is the "representative" item, same as in vanilla
end

---@return InventoryItem|nil
function DragAndDrop.convertItemStackToItem(items)
    if instanceof(items, "InventoryItem") then
        return items
    -- Converts a vanilla "stack" of items into a single item
    elseif items then
        if items.items then
            return items.items[1]
        else
            return DragAndDrop.convertItemStackToItem(items[1])
        end
    end
    return nil
end

-- Delay the cancelation of the drag to the next tick, so that the drag receivers can process the drag
DragAndDrop.processCancelation = function()
    for owner, val in pairs(DragAndDrop.ownersForCancel) do
        if ISMouseDrag.dragOwner == owner then
            if val.callback then
                val.callback(owner)
            end
            DragAndDrop.endDrag()
            break
        end
    end
    DragAndDrop.ownersForCancel = {}
end

Events.OnTick.Add(DragAndDrop.processCancelation)

return DragAndDrop
