require ("ISUI/ISPanel")
local Settings = require ("EquipmentUI/Settings")
local ControllerNode = require("Notloc/UI/ControllerNode")
local DragAndDrop = require("EquipmentUI/DragAndDrop")
local ClothingItemExtraService = require("EquipmentUI/ClothingItemExtraService")

local BG_COLOR = {r=0, g=0, b=0, a=0.95}

---@class EquipmentSlot : ISPanel
---@field public item InventoryItem
---@field public bodyLocation ItemBodyLocation
---@field public bodySlotDisplay BodySlotDisplay
---@field public inventoryPane ISInventoryPane
---@field public playerNum integer
---@field public bodyLocationGroup BodyLocationGroup
---@field public controllerNode ControllerNode
local EquipmentSlot = ISPanel:derive("EquipmentSlot");

---@param x number
---@param y number
---@param bodyLocation ItemBodyLocation
---@param bodySlotDisplay BodySlotDisplay
---@param inventoryPane ISInventoryPane
---@param playerNum integer
---@return EquipmentSlot
function EquipmentSlot:new(x, y, bodyLocation, bodySlotDisplay, inventoryPane, playerNum)
	---@type EquipmentSlot
    local o = ISPanel:new(x, y, Settings.SLOT_SIZE, Settings.SLOT_SIZE);
	setmetatable(o, self)
    self.__index = self
	o.x = x;
	o.y = y;

    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
    o.backgroundColor = BG_COLOR

    o.bodyLocation = bodyLocation;
    o.bodySlotDisplay = bodySlotDisplay;
    o.inventoryPane = inventoryPane;
    o.playerNum = playerNum;

    o.bodyLocationGroup = getSpecificPlayer(playerNum):getWornItems():getBodyLocationGroup();

	return o;
end

function EquipmentSlot:initialise()
    ISPanel.initialise(self);

    table.insert(Settings.OnScaleChanged, function(scale)
        self:setWidth(Settings.SLOT_SIZE)
        self:setHeight(Settings.SLOT_SIZE)
    end);

    ControllerNode
        :injectControllerNode(self)
        :setJoypadDownHandler(self.controllerNodeOnJoypadDown)
end

function EquipmentSlot:setItem(item)
    self.item = item;
end

function EquipmentSlot:clearItem()
    self.item = nil;
end

function EquipmentSlot:prerender()
    local hasControllerFocus = self.controllerNode and self.controllerNode.isFocused
    self.backgroundColor = hasControllerFocus and ControllerNode.FOCUS_COLOR or BG_COLOR
    ISPanel.prerender(self);

    local dragItem = DragAndDrop.getDraggedItem();
    if dragItem and dragItem ~= self.item then
        local defaultBodyLocation = ClothingItemExtraService.getDefaultBodyLocation(dragItem)
        if defaultBodyLocation then
            local conflicts = defaultBodyLocation == self.bodyLocation or self.bodyLocationGroup:isExclusive(defaultBodyLocation, self.bodyLocation)
            if conflicts then
                self:drawRect(1, 1, self.width-2, self.height-2, 0.5, 1, 0, 0);
            end
        end
    end
end

function EquipmentSlot:render()
    local item = self.item
    if not item then return end

    local alpha = 1.0
    if self.item == DragAndDrop.getDraggedItem() then
        alpha = 0.5
    end

    local tex = item:getTex()
    -- Smangsty: Use B42.20 aspect-fit rendering so item icons stay contained.
    self:drawTextureScaledAspect(tex, 1, 1, self.width - 2, self.height - 2, alpha, self.getItemColor(self.item));
    -- Smangsty: Controller presence is not controller ownership; focused joypad input wins, otherwise mouse hover stays live.
    if self.controllerNode.isFocused then
        self.bodySlotDisplay:doTooltipForItem(self, self.item);
    elseif self:isMouseOver() then
        self.bodySlotDisplay:doTooltipForItem(self, self.item);
    end
end

function EquipmentSlot:onRightMouseUp(x, y)
    if self.item then
        EquipmentSlot.openItemContextMenu(self, x, y, self.item, self.inventoryPane, self.playerNum);
    end
end

function EquipmentSlot:onMouseDown(x, y)
    if self.item then
        DragAndDrop.prepareDrag(self, DragAndDrop.convertItemToStack(self.item), x, y);
    end
end

function EquipmentSlot:onMouseMove(dx, dy)
    DragAndDrop.startDrag(self);
end

function EquipmentSlot:onMouseMoveOutside(dx, dy)
    DragAndDrop.startDrag(self);
end

function EquipmentSlot:onMouseUp(x, y)
    DragAndDrop.endDrag();
end

function EquipmentSlot:onMouseUpOutside(x, y)
    DragAndDrop.cancelDrag(self, EquipmentSlot.dropOrUnequip);
end

function EquipmentSlot:dropOrUnequip()
    local item = self.item
    self:doDropOrUnequip(item)
end

---@param self EquipmentSlot|EquipmentSuperSlot
---@param item InventoryItem
function EquipmentSlot.doDropOrUnequip(self, item)
    if item then
        if not Settings.InventoryTetris then
            if self.inventoryPane:isMouseOver() then
                ISInventoryPaneContextMenu.unequipItem(item, self.playerNum)
                return
            end
            local loot = getPlayerLoot(self.playerNum)
            if loot and loot.inventoryPane:isMouseOver() then
                local inv = loot.inventoryPane.inventory
                loot.inventoryPane:transferItemsByWeight({item}, inv)
            end
        end

        local playerObj = getSpecificPlayer(self.playerNum)
        local vehicle = playerObj:getVehicle()
        if vehicle then
            return
        end

        if not ISUIElement.isMouseOverAnyUI() then
            ISInventoryPaneContextMenu.dropItem(item, self.playerNum)
        end
    end
end


-- STATIC METHODS


-- Assumes all items are the same type
---@param items InventoryItem[]
---@param inventoryPane ISInventoryPane
---@return umbrella.ISInventoryPane.ItemRecord[]
local function createVanillaStacksFromItems(items, inventoryPane)
    ---@type umbrella.ISInventoryPane.ItemRecord
    local vanillaStack = {}
    vanillaStack.items = {}
    vanillaStack.invPanel = inventoryPane

    if items[1] then
        vanillaStack.name = items[1]:getName()
        vanillaStack.cat = items[1]:getDisplayCategory() or items[1]:getCategory();
    end

    local weight = 0.0
    table.insert(vanillaStack.items, items[1])
    for _, item in ipairs(items) do
        table.insert(vanillaStack.items, item)
        weight = weight + item:getUnequippedWeight()
    end
    vanillaStack.weight = weight
    vanillaStack.count = #items + 1

    return {vanillaStack}
end

EquipmentSlot.openItemContextMenu = function(uiContext, x, y, item, invPane, playerNum)
    local container = item:getContainer()

    local player = getSpecificPlayer(playerNum)
    local isInInv = container and container:isInCharacterInventory(player)
    local menu = ISInventoryPaneContextMenu.createMenu(playerNum, isInInv, createVanillaStacksFromItems({item}, invPane), uiContext:getAbsoluteX()+x, uiContext:getAbsoluteY()+y)
    if not menu then return end

    local unequipAllOption = menu:addOption("Unequip All", player, EquipmentSlot.unequipAll);

    local unequipIdx = nil
    local unequipAllIdx = nil
    for i, option in ipairs(menu.options) do
        if option.onSelect == ISInventoryPaneContextMenu.onUnEquip then
            unequipIdx = i
        end
        if option == unequipAllOption then
            unequipAllIdx = i
        end
    end

    if unequipIdx then
        table.remove(menu.options, unequipAllIdx)
        table.insert(menu.options, unequipIdx+1, unequipAllOption)
    end

    if menu and menu.numOptions > 1 and uiContext.controllerNode and uiContext.controllerNode.isFocused then
        uiContext.controllerNode:focusContextMenu(playerNum, menu)
    end
end

---@param player IsoPlayer
EquipmentSlot.unequipAll = function(player)
    local wornItems = player:getWornItems()
    for i=0, wornItems:size()-1 do
        local wornItem = wornItems:get(i)
        local item = wornItem:getItem()
        if item and not item:isHidden() then
            ISInventoryPaneContextMenu.unequipItem(item, player:getPlayerNum())
        end
    end
end

function EquipmentSlot.getItemColor(item)
    if not item then
        return 1,1,1
    end
    if not item:allowRandomTint() then
        return item:getR(), item:getG(), item:getB()
    end

    local colorInfo = item:getColorInfo()
    local r = colorInfo:getR()
    local g = colorInfo:getG()
    local b = colorInfo:getB()
    
    -- Limit how dark the item can appear if all colors are close to 0
    local limit = 0.2
    while r < limit and g < limit and b < limit do
        r = r + limit / 4
        g = g + limit / 4
        b = b + limit / 4
    end
    return r,g,b
end

function EquipmentSlot:controllerNodeOnJoypadDown(button)
    local item = self.item
    if button == Joypad.XButton then
        ISInventoryPaneContextMenu.unequipItem(item, self.playerNum)
        return true
    end
    if button == Joypad.AButton then
        if item then
            local x = self.width
            local y = self.height/2
            EquipmentSlot.openItemContextMenu(self, x, y, item, self.inventoryPane, self.playerNum)
        end
        return true
    end
    return false
end

return EquipmentSlot
