local SETTINGS = require("EquipmentUI/Settings")

-- Toggle the UI when pressing the select button on the controller
local og_ISInventoryPage_onJoypadDown = ISInventoryPage.onJoypadDown
function ISInventoryPage:onJoypadDown(button)
    og_ISInventoryPage_onJoypadDown(self, button)

    local playerNum = self.player

    local inventoryPage = getPlayerInventory(playerNum)
    if not inventoryPage then return end

    if button == SETTINGS.TOGGLE_UI_CONTROLLER_BIND then
        if SETTINGS.InventoryTetris then
            if inventoryPage.equipmentUiPanel.isClosed then
                self:toggleEquipmentUIForController()
            end 
            setJoypadFocus(playerNum, inventoryPage.equipmentUiPanel);
        else
            self:toggleEquipmentUIForController()
        end
    end
end

-- Resize UIs when toggling the equipment UI
local standAloneOpen = false
function ISInventoryPage:toggleEquipmentUIForController()
    local playerNum = self.player
    if not playerNum then return end

    local inventoryPage = getPlayerInventory(playerNum)
    if not inventoryPage then return end

    local lootPage = getPlayerLoot(playerNum)
    if not lootPage then return end

    local equipmentPanel = inventoryPage.equipmentUiPanel
    if not equipmentPanel then return end

    equipmentPanel.isClosed = not equipmentPanel.isClosed
    equipmentPanel:setVisible(not equipmentPanel.isClosed)

    -- Only resize the loot ui for layouts where the loot inventory is to the right of the player inventory and aligned with it without a large gap between them
    local resizeLoot = 
        lootPage:getY() == inventoryPage:getY() and 
        lootPage:getHeight() == inventoryPage:getHeight() and
        lootPage:getX() > inventoryPage:getX() and
        lootPage:getX() - (inventoryPage:getX() + inventoryPage:getWidth()) < 200


    -- Don't resize the UIs if the equipment UI is undocked
    if not equipmentPanel.isDocked then
        return
    end

    local x = getPlayerScreenLeft(self.player) + 0.0
    local w = 0.0

    -- If we're opening the equipment UI and there's enough space to do so, just open it
    if not equipmentPanel.isClosed and inventoryPage:getX() - equipmentPanel:getWidth() > x then
        standAloneOpen = true
        return
    end

    if standAloneOpen then
        standAloneOpen = false
        return -- Just close the equipment UI without resizing the other UIs
    end


    if not resizeLoot then
        x = inventoryPage:getX()
        w = inventoryPage:getWidth()
    else
        x = inventoryPage:getX()
        w = lootPage:getX() + lootPage:getWidth() - x
    end

    if not equipmentPanel.isClosed then
        x = x + equipmentPanel:getWidth()
        w = w - equipmentPanel:getWidth()
    else
        x = x - equipmentPanel:getWidth()
        w = w + equipmentPanel:getWidth()
    end

    if resizeLoot then
        inventoryPage:setWidth(w/2)
        inventoryPage:setX(x)
        lootPage:setWidth(w/2)
        lootPage:setX(x + w/2)
    else
        inventoryPage:setWidth(w)
        inventoryPage:setX(x)
    end
end

--  Handle switching focus between the inventories and equipment UIs
local og_ISInventoryPage_onJoypadDirLeft = ISInventoryPage.onJoypadDirLeft
function ISInventoryPage:onJoypadDirLeft(joypadData)
    og_ISInventoryPage_onJoypadDirLeft(self, joypadData)
    if self == getPlayerInventory(self.player) then
        if self.equipmentUiPanel:isVisible() then
            setJoypadFocus(self.player, self.equipmentUiPanel);
        end
    end
end

local og_ISInventoryPage_onJoypadDirRight = ISInventoryPage.onJoypadDirRight
function ISInventoryPage:onJoypadDirRight(joypadData)
    og_ISInventoryPage_onJoypadDirRight(self, joypadData)
    if self == getPlayerLoot(self.player) then
        local inventoryPage = getPlayerInventory(self.player)
        if not inventoryPage then return end

        local equipmentUi = inventoryPage.equipmentUiPanel
        if equipmentUi:isVisible() then
            setJoypadFocus(self.player, equipmentUi);
        end
    end
end

