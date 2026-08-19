---@class ControllerNode
---@field injectControllerNode fun(self: ControllerNode, uiElement: ISUIElement) : ControllerNode
---@field doSimpleFocusHighlight fun(self: ControllerNode) : ControllerNode
---@field setJoypadDownHandler fun(self: ControllerNode, handler: fun(self: ISUIElement, button: integer): boolean) : ControllerNode
---@field setJoypadDirHandler fun(self: ControllerNode, handler: fun(self: ISUIElement, dx: integer, dy: integer, joypadData: JoypadData): boolean) : ControllerNode
local ControllerNode = require("Notloc/UI/ControllerNode") -- From EquipmentUI

function ControllerNode.ensureVisible(uiElement)
    local current = uiElement.parent
    while current do
        if current.Type == "ISInventoryPane" then
            current:scrollToPositionX(uiElement:getAbsoluteX() - 10)
            current:scrollToPositionY(uiElement:getAbsoluteY() + 50)
            return
        end
        current = current.parent
    end
end

function ControllerNode.ensureVisibleXY(uiElement, screenX, screenY)
    local current = uiElement.parent
    while current do
        if current.Type == "ISInventoryPane" then
            current:scrollToPositionX(screenX - 50)
            current:scrollToPositionY(screenY - 50)
            return
        end
        current = current.parent
    end
end

-- FuX: Child Tetris surfaces can own focus directly, so clearing focus alone does not run ISInventoryPage:onLoseJoypadFocus.
function ControllerNode.exitInventory(playerNum)
    setJoypadFocus(playerNum, nil)

    local inventoryPage = getPlayerInventory(playerNum)
    local lootPage = getPlayerLoot(playerNum)
    if inventoryPage then
        if inventoryPage.inventoryPane then
            inventoryPage.inventoryPane.doController = false
        end
        inventoryPage:setVisible(false)
    end
    if lootPage then
        if lootPage.inventoryPane then
            lootPage.inventoryPane.doController = false
        end
        lootPage:setVisible(false)
    end

    local playerObj = getSpecificPlayer(playerNum)
    if playerObj then
        playerObj:setBannedAttacking(false)
        if playerObj:getVehicle() and playerObj:getVehicle():isDriver(playerObj) then
            local dashboard = getPlayerVehicleDashboard(playerNum)
            if dashboard then dashboard:addToUIManager() end
        end
    end
end

return ControllerNode
