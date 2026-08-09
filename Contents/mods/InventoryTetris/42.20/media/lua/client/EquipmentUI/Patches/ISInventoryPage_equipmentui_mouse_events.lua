local DragAndDrop = require("EquipmentUI/DragAndDrop")

function ISInventoryPage:isMouseOverEquipmentUi()
    if(self.equipmentUiPanel and self.equipmentUiPanel.playerNum == 0) then
        local mouseX = getMouseX()
        local mouseY = getMouseY()
        if mouseX >= self.equipmentUiPanel:getAbsoluteX() and mouseX <= self.equipmentUiPanel:getAbsoluteX() + self.equipmentUiPanel:getWidth() and
            mouseY >= self.equipmentUiPanel:getAbsoluteY() and mouseY <= self.equipmentUiPanel:getAbsoluteY() + self.equipmentUiPanel:getHeight() then
            return true
        end

        if mouseX >= self.equipmentUiPanel.toggleElement:getAbsoluteX() and mouseX <= self.equipmentUiPanel.toggleElement:getAbsoluteX() + self.equipmentUiPanel.toggleElement:getWidth() and
            mouseY >= self.equipmentUiPanel.toggleElement:getAbsoluteY() and mouseY <= self.equipmentUiPanel.toggleElement:getAbsoluteY() + self.equipmentUiPanel.toggleElement:getHeight() then
            return true
        end
    end
    return false
end

local og_onMouseDownOutside = ISInventoryPage.onMouseDownOutside
function ISInventoryPage:onMouseDownOutside(x, y)
    local wasPin = self.pin
    if self.equipmentUiPanel and self.equipmentUiPanel.isDocked and self:isMouseOverEquipmentUi() then
        self.pin = true
    end 
    local ret =  og_onMouseDownOutside(self, x, y)
    self.pin = wasPin
    return ret
end

local og_onRightMouseDownOutside = ISInventoryPage.onRightMouseDownOutside
function ISInventoryPage:onRightMouseDownOutside(x, y)
    local wasPin = self.pin
    if self.equipmentUiPanel and self.equipmentUiPanel.isDocked and self:isMouseOverEquipmentUi() then
        self.pin = true
    end 
    local ret =  og_onRightMouseDownOutside(self, x, y)
    self.pin = wasPin
    return ret
end

local og_onMouseMoveOutside = ISInventoryPage.onMouseMoveOutside
function ISInventoryPage:onMouseMoveOutside(dx, dy)
    if DragAndDrop.isDragging() and self.isCollapsed then
        self.isCollapsed = false;
        if isClient() and not self.onCharacter then
            self.inventoryPane.inventory:requestSync();
        end
        self:clearMaxDrawHeight();
        self.collapseCounter = 0;
    end

	local wasPin = self.pin
    if self.equipmentUiPanel and self.equipmentUiPanel.isDocked and self:isMouseOverEquipmentUi() then
        self.pin = true
    end
    local ret = og_onMouseMoveOutside(self, dx, dy)
    self.pin = wasPin
    return ret
end
