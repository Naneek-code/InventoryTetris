require "Hotbar/ISHotbar"
Events.OnGameBoot.Add(function()

    ---@class ISHotbar
    ---@field notloc_onRefresh fun(self: ISHotbar)

    local og_refresh = ISHotbar.refresh
    function ISHotbar:refresh()
        local oldAvailableSlots = self.availableSlot
        og_refresh(self)
        -- Smangsty: Vanilla may call refresh without changing slots; don't rebuild Equipment UI for a no-op.
        if self.notloc_onRefresh and self.availableSlot ~= oldAvailableSlots then
            self.notloc_onRefresh(self)
        end
    end
end)