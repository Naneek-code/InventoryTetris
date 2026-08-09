-- Smangsty: Centralizes vanilla key-ring detection for semantic, non-spatial handling.
local KeyRingSupport = {}

function KeyRingSupport.isItem(item)
    return item and (item:isItemType(ItemType.KEY_RING) or item:hasTag(ItemTag.KEY_RING)) or false
end

function KeyRingSupport.isContainer(container)
    if not container then return false end
    if container:getType() == "KeyRing" then return true end
    return KeyRingSupport.isItem(container:getContainingItem())
end

return KeyRingSupport
