require ("ISUI/ISUIElement")
local Settings = require "EquipmentUI/Settings"
local EquipmentSlot = require("EquipmentUI/UI/Slots/EquipmentSlot")
local DragAndDrop = require("EquipmentUI/DragAndDrop")

---@class EquipmentDragItemRenderer : ISUIElement
---@field public equipmentPanel EquipmentPanel
---@field public inventoryPane ISInventoryPane
---@field public playerNum integer
local EquipmentDragItemRenderer = ISUIElement:derive("DragItemRenderer")

---@param inventoryPane ISInventoryPane
---@param playerNum integer
---@return EquipmentDragItemRenderer
function EquipmentDragItemRenderer:new(inventoryPane, playerNum)
    ---@type EquipmentDragItemRenderer
    local o = ISUIElement:new(0, 0, 0, 0)
    setmetatable(o, self)
    self.__index = self

    o.inventoryPane = inventoryPane
    o.playerNum = playerNum

    return o
end

function EquipmentDragItemRenderer:prerender()
    self:bringToTop()
end

function EquipmentDragItemRenderer:render()
    if self.inventoryPane.dragging then return end

    local item = DragAndDrop.getDraggedItem()
    if not item then return end

    local lootPage = getPlayerLoot(self.playerNum)
    if not lootPage then return end

    if self.inventoryPane.dragging or lootPage.inventoryPane.dragging then
        return
    end

    local x = self:getMouseX()
    local y = self:getMouseY()

    self:suspendStencil()
    self:drawTextureCenteredAndSquare(item:getTex(), x, y, 32 * Settings.SCALE, 1, EquipmentSlot.getItemColor(item))
    self:resumeStencil()
end

return EquipmentDragItemRenderer
