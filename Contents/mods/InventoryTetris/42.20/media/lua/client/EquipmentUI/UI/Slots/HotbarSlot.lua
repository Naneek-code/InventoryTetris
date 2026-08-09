require ("ISUI/ISPanel")
local Settings = require ("EquipmentUI/Settings")
local ControllerNode = require("Notloc/UI/ControllerNode")
local EquipmentSlot = require("EquipmentUI/UI/Slots/EquipmentSlot")
local DragAndDrop = require("EquipmentUI/DragAndDrop")

local BG_TEXTURE = getTexture("media/ui/equipmentui/ItemSlot.png")
local BG_COLOR = {r=0.4, g=0.4, b=0.4}

---@class HotbarSlot : ISPanel
---@field public hotbar ISHotbar
---@field public bodySlotDisplay BodySlotDisplay
---@field public inventoryPane ISInventoryPane
---@field public playerNum integer
---@field public index integer
---@field public mouseDownX number
---@field public mouseDownY number
---@field public controllerNode ControllerNode
local HotbarSlot = ISPanel:derive("HotbarSlot");

---@param hotbar ISHotbar
---@param bodySlotDisplay BodySlotDisplay
---@param inventoryPane ISInventoryPane
---@param playerNum integer
function HotbarSlot:new(hotbar, bodySlotDisplay, inventoryPane, playerNum)
    ---@type HotbarSlot
    local o = ISPanel:new(50, 50, Settings.SUPER_SLOT_SIZE, Settings.SUPER_SLOT_SIZE);
	setmetatable(o, self)
    self.__index = self

    o.hotbar = hotbar;
    o.bodySlotDisplay = bodySlotDisplay;
    o.inventoryPane = inventoryPane;
    o.playerNum = playerNum;

	o.moveWithMouse = true;

    o.mouseDownX = 0;
    o.mouseDownY = 0;

	return o;
end

function HotbarSlot:initialise()
    ISPanel.initialise(self);
    ControllerNode
        :injectControllerNode(self)
        :setJoypadDownHandler(self.controllerNodeOnJoypadDown)

    table.insert(Settings.OnScaleChanged, function(scale)
        self:setWidth(Settings.SUPER_SLOT_SIZE)
        self:setHeight(Settings.SUPER_SLOT_SIZE)
    end);
end

function HotbarSlot:getItem()
   return self.hotbar.attachedItems[self.index] 
end

function HotbarSlot:prerender()
    if not self.index then
        return
    end

    local itemCount = 0;

    local color = self.controllerNode.isFocused and ControllerNode.FOCUS_COLOR or BG_COLOR;

    self:drawRect(0, 0, Settings.SUPER_SLOT_SIZE, Settings.SUPER_SLOT_SIZE, 0.65, 0, 0, 0);
    self:drawTextureScaled(BG_TEXTURE, 0, 0, Settings.SUPER_SLOT_SIZE, Settings.SUPER_SLOT_SIZE, 1, color.r, color.g, color.b);
    self:drawRectBorder(0, 0, Settings.SUPER_SLOT_SIZE, Settings.SUPER_SLOT_SIZE, 1, 1, 1, 1);

    local dragItem = DragAndDrop.getDraggedItem();
    if dragItem and dragItem ~= self:getItem() then
        if self:canAttachItem(dragItem) then
           local col = Settings.GOOD_COLOR
           if self:getItem() then
               col = Settings.MIDDLE_COLOR
           end
            self:drawRect(1, 1, Settings.SUPER_SLOT_SIZE - 2, Settings.SUPER_SLOT_SIZE - 2, 0.5, col.r, col.g, col.b);
        end
    end
end

function HotbarSlot:render()
    if not self.index then
        return
    end
    local item = self:getItem()

    --if the mouse is over the super slot, draw the name of the slot
    if self:isMouseOver() or self.controllerNode.isFocused then
        local slot = self.hotbar.availableSlot[self.index]
        if slot then
            local name = getTextOrNull("IGUI_HotbarAttachment_" .. slot.slotType) or slot.name;

            local width = getTextManager():MeasureStringX(UIFont.Small, name);
            local height = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight();

            local center = Settings.SUPER_SLOT_SIZE / 2


            if center - width / 2 + self.x < 0 then
                center = width / 2 + 3
            elseif center + width / 2 + self.x > self.bodySlotDisplay.width then
                center = Settings.SUPER_SLOT_SIZE - width / 2 - 3
            end

            local x = center - width / 2 - 3
            local y = -height - 2

            self:drawRect(x, y, width + 8, height+4, 0.9, 0, 0, 0);
            self:drawRectBorder(x, y, width + 8, height+4, 1, 1, 1, 1);
            self:drawTextCentre(name, center, y, 1, 1, 1, 1, UIFont.Small);

            self:bringToTop();

            if item then
                self.bodySlotDisplay:doTooltipForItem(self, item);
            end
        end
    end

    if not item then 
        return
    end

    local xOff = (Settings.SUPER_SLOT_SIZE - Settings.SLOT_SIZE) / 2;
    local yOff = (Settings.SUPER_SLOT_SIZE - Settings.SLOT_SIZE) / 2;
    local mainAlpha = 1.0;
    if item == DragAndDrop.getDraggedItem() then
        mainAlpha = 0.5;
    end
    local iconSize = Settings.SLOT_SIZE - (Settings.SCALE * 2);
    -- Smangsty: Use B42.20 aspect-fit rendering so hotbar icons stay contained.
    self:drawTextureScaledAspect(item:getTex(), xOff + Settings.SCALE, yOff + Settings.SCALE, iconSize, iconSize, mainAlpha, EquipmentSlot.getItemColor(item));
end


function HotbarSlot:onRightMouseUp(x, y)
    local item = self:getItem()
    if item then
        EquipmentSlot.openItemContextMenu(self, x, y, item, self.inventoryPane, self.playerNum)
    end
end

function HotbarSlot:onMouseDown(x, y)
    local item = self:getItem()
    if item then
        DragAndDrop.prepareDrag(self, DragAndDrop.convertItemToStack(item), x, y);
    end
end

function HotbarSlot:onMouseMove(dx, dy)
    DragAndDrop.startDrag(self);
end

function HotbarSlot:onMouseMoveOutside(dx, dy)
    DragAndDrop.startDrag(self);
end

function HotbarSlot:onMouseUp(x, y)
    local draggedItem = DragAndDrop.getDraggedItem();
    if draggedItem and draggedItem ~= self:getItem() then
        self:attachItemIfPossible(draggedItem);
    end
    DragAndDrop.endDrag();
end

function HotbarSlot:onMouseUpOutside(x, y)
    DragAndDrop.cancelDrag(self, HotbarSlot.dropOrUnequip);
end


function HotbarSlot:attachItemIfPossible(item)
    local slot = self.hotbar.availableSlot[self.index]
    if not slot then return end

    local slotDef = slot.def;

    for i, v in pairs(slotDef.attachments) do
        if item:getAttachmentType() == i then
            local doIt = true;
            if self.hotbar.replacements and self.hotbar.replacements[item:getAttachmentType()] then
                local replacement = self.hotbar.replacements[item:getAttachmentType()];
                if replacement == "null" then
                    doIt = false;
                end
            end
            if doIt then
                self.hotbar:attachItem(item, v, self.index, slotDef, true);
                return
            end
        end
    end
end

function HotbarSlot:canAttachItem(item)
    local slot = self.hotbar.availableSlot[self.index]
    if not slot then return false end

    local slotDef = slot.def;
    for i, v in pairs(slotDef.attachments) do
        if item:getAttachmentType() == i then
            local doIt = true;
            if self.hotbar.replacements and self.hotbar.replacements[item:getAttachmentType()] then
                local replacement = self.hotbar.replacements[item:getAttachmentType()];
                if replacement == "null" then
                    doIt = false;
                end
            end
            if doIt then
                return true
            end
        end
    end
    return false
end

function HotbarSlot:dropOrUnequip()
    local item = self:getItem()
    if item then
        if not Settings.InventoryTetris then
            if self.inventoryPane:isMouseOver() then
                self.hotbar:removeItem(item, true)
                return
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

function HotbarSlot:controllerNodeOnJoypadDown(button)
    local item = self:getItem()
    if button == Joypad.XButton then
        if item then
            self.hotbar:removeItem(item, true)
        end
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

return HotbarSlot
