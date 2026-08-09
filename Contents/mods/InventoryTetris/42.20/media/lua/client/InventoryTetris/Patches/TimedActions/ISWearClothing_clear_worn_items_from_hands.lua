-- Smangsty: Clear an item from the hands after vanilla successfully equips it as worn clothing.
---@diagnostic disable: duplicate-set-field

require("TimedActions/ISWearClothing")

local og_complete = ISWearClothing.complete

function ISWearClothing:complete()
    local completed = og_complete(self)
    if not completed or not self.item or not self.character then
        return completed
    end

    local bodyLocation = self.item:getBodyLocation()
    if bodyLocation and bodyLocation ~= "" and self.character:getWornItem(bodyLocation) == self.item then
        if self.character:getPrimaryHandItem() == self.item or self.character:getSecondaryHandItem() == self.item then
            self.character:removeFromHands(self.item)
        end
    end

    return completed
end
