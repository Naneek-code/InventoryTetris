-- Intentional global so exported Tetris data packs can register compatibility overrides.
EquipmentSlotOverrides = {}

EquipmentSlotOverrides._slotOverrides = {}
EquipmentSlotOverrides._devSlotOverrides = {}

function EquipmentSlotOverrides.getBodyLocationKey(item)
    if not item then return nil end

    local bodyLocation = item.getBodyLocation and item:getBodyLocation() or nil
    if (not bodyLocation or bodyLocation == "") and item.canBeEquipped then
        bodyLocation = item:canBeEquipped()
    end
    if not bodyLocation or bodyLocation == "" then return nil end

    return tostring(bodyLocation)
end

function EquipmentSlotOverrides.getSlotName(item)
    local key = EquipmentSlotOverrides.getBodyLocationKey(item)
    if not key then return nil end

    return EquipmentSlotOverrides._devSlotOverrides[key] or EquipmentSlotOverrides._slotOverrides[key]
end

function EquipmentSlotOverrides.registerSlotOverrides(slotPack)
    if type(slotPack) ~= "table" then return end

    for bodyLocation, slotName in pairs(slotPack) do
        if type(slotName) == "string" and slotName ~= "" then
            EquipmentSlotOverrides._slotOverrides[tostring(bodyLocation)] = slotName
        end
    end
end

return EquipmentSlotOverrides
