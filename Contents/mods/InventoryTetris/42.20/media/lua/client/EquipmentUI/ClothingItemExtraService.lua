local ClothingItemExtraService = {}

---@type table<string, InventoryItem>
local _extraItemCache = {}

---@param item InventoryItem
---@return ItemBodyLocation
function ClothingItemExtraService.getDefaultBodyLocation(item)
    return item:getBodyLocation() or item:canBeEquipped()
end

---@param module string
---@param extra string
---@return ItemBodyLocation|nil
function ClothingItemExtraService.getExtraItemBodyLocation(module, extra)
    local item = _extraItemCache[extra]
    if not item then
        item = instanceItem(module .. "." .. extra)
        -- Smangsty: Ignore missing modded clothing extras instead of crashing Equipment UI.
        if not item then
            return nil
        end
        _extraItemCache[extra] = item
    end
    return item:getBodyLocation()
end

--- Some items are valid for a variety of slots (i.e rings and watches)
---@param item InventoryItem
---@return table<ItemBodyLocation, boolean>
ClothingItemExtraService.getBodyLocationsForItem = function(item)
    local bodyLocationsMap = {}
    
    local defaultBodyLocation = ClothingItemExtraService.getDefaultBodyLocation(item)
    if not defaultBodyLocation then
        return bodyLocationsMap
    end
    
    bodyLocationsMap[defaultBodyLocation] = true

    local extraOptions = item:getClothingItemExtra()
    if extraOptions then
        local module = item:getModule()
        for i=0, extraOptions:size()-1 do
            local extra = extraOptions:get(i)
            local extraBodyLocation = ClothingItemExtraService.getExtraItemBodyLocation(module, extra)
            if extraBodyLocation then
                bodyLocationsMap[extraBodyLocation] = true
            end
        end
    end

    return bodyLocationsMap
end

--- Returns the module qualified extra item type related to the given bodyslot
--- Needed so we can call the ISInventoryContextMenu::wearExtra function properly
---@param item InventoryItem
---@param targetBodyLocation ItemBodyLocation
---@return string|nil
ClothingItemExtraService.findExtraOptionForBodyLocation = function(item, targetBodyLocation)
    local extraOptions = item:getClothingItemExtra()
    if not extraOptions then
        return nil
    end

    for i=0, extraOptions:size()-1 do
        local module = item:getModule()
        local extra = extraOptions:get(i)
        local extraBodyLocation = ClothingItemExtraService.getExtraItemBodyLocation(module, extra)
        if extraBodyLocation == targetBodyLocation then
            return moduleDotType(module, extra);
        end
    end

    return nil
end

return ClothingItemExtraService
