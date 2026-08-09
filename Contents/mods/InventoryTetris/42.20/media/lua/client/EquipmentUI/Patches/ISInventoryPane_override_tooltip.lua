require ("ISUI/ISInventoryPane")

---@class ISInventoryPane
---@field doController boolean

Events.OnGameStart.Add(function()
    -- Check if equipment UI should be driving the tooltip
    local og_updateTooltip = ISInventoryPane.updateTooltip
    function ISInventoryPane:updateTooltip()
        ---@cast self.parent ISInventoryPage
        local inventoryPage = self.parent
        if not inventoryPage then return og_updateTooltip(self) end

        ---@type EquipmentPanel
        local equipmentUi = inventoryPage.equipmentUiPanel
        if not equipmentUi then return og_updateTooltip(self) end

        local superSlotPopup = equipmentUi and equipmentUi.popup

        local equipmentUiHasFocus = inventoryPage:isMouseOverEquipmentUi() or equipmentUi.controllerNode.isFocused
        local superSlotPopupHasFocus = superSlotPopup:isMouseOver() or superSlotPopup.controllerNode.isFocused

        if equipmentUiHasFocus or superSlotPopupHasFocus then
            return equipmentUi:updateTooltip()
        else
            og_updateTooltip(self)
        end
    end

    -- My custom tooltip function
    function ISInventoryPane:doTooltipForItem(item)
        ---@cast self.parent ISInventoryPage
        local inventoryPage = self.parent

        if not inventoryPage:isVisible() then return end

        local weightOfStack = 0.0
        if item and not instanceof(item, "InventoryItem") then
            if #item.items > 2 then
                weightOfStack = item.weight
            end
            item = item.items[1]
        end

        local context = getPlayerContextMenu(self.player)
        if not context then return end

        if context:isAnyVisible() then
            item = nil
        end

        ---@diagnostic disable-next-line: need-check-nil
        if item and self.toolRender and (item == self.toolRender.item) and (weightOfStack == self.toolRender.tooltip:getWeightOfStack()) and self.toolRender:isVisible() then
            return
        end

        if item and not ISMouseDrag.dragging then
            if self.toolRender then
                self.toolRender:setItem(item)
                self.toolRender:setVisible(true)
                self.toolRender:addToUIManager()
                self.toolRender:bringToTop()
            else
                self.toolRender = ISToolTipInv:new(item)
                self.toolRender:initialise()
                self.toolRender:addToUIManager()
                self.toolRender:setVisible(true)
                self.toolRender:setOwner(self)
                self.toolRender:setCharacter(getSpecificPlayer(self.player))
                self.toolRender.anchorBottomLeft = { x = self:getAbsoluteX() + self.column2, y = inventoryPage:getAbsoluteY() }
            end
            local equipmentPanel = GetPlayerEquipmentUi(self.player)
            self.toolRender.followMouse = not self.doController and not equipmentPanel.controllerNode.isFocused
            ---@diagnostic disable-next-line: need-check-nil
            self.toolRender.tooltip:setWeightOfStack(weightOfStack)
        elseif self.toolRender then
            self.toolRender:removeFromUIManager()
            self.toolRender:setVisible(false)
        end

        local inventoryPage = getPlayerInventory(self.player)
        local inventoryTooltip = inventoryPage and inventoryPage.inventoryPane.toolRender
        local lootPage = getPlayerLoot(self.player)
        local lootTooltip = lootPage and lootPage.inventoryPane.toolRender

        ---@diagnostic disable-next-line: param-type-mismatch
        UIManager.setPlayerInventoryTooltip(self.player, inventoryTooltip and inventoryTooltip.javaObject or nil, lootTooltip and lootTooltip.javaObject or nil)
    end
end)
