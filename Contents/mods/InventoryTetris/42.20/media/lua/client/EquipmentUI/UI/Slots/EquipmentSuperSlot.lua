require ("ISUI/ISPanel")
local Settings = require("EquipmentUI/Settings")
local ControllerNode = require("Notloc/UI/ControllerNode")
local EquipmentSlot = require("EquipmentUI/UI/Slots/EquipmentSlot")
local DragAndDrop = require("EquipmentUI/DragAndDrop")
local ClothingItemExtraService = require("EquipmentUI/ClothingItemExtraService")

local MINI_ICON_SCALE = 0.375
local MINI_ICON_SIZE = 32 * MINI_ICON_SCALE
local BG_COLOR = { r = 0.4, g = 0.4, b = 0.4 }
local BG_TEXTURE = getTexture("media/ui/equipmentui/ItemSlot.png")

---@class EquipmentSuperSlot : ISPanel
---@field public slotDefinition SlotDefinition
---@field public bodySlotDisplay BodySlotDisplay
---@field public inventoryPane ISInventoryPane
---@field public playerNum integer
---@field public slots EquipmentSlot[]
---@field public slotsByBodyLocation table<ItemBodyLocation, EquipmentSlot>
---@field public expanded boolean
---@field public bodyLocationGroup BodyLocationGroup
---@field public controllerNode ControllerNode
---@field public popup SuperSlotPopup
local EquipmentSuperSlot = ISPanel:derive("EquipmentSuperSlot");

---@param slotDefinition SlotDefinition
---@param bodySlotDisplay BodySlotDisplay
---@param inventoryPane ISInventoryPane
---@param playerNum integer
---@param popup SuperSlotPopup
---@return EquipmentSuperSlot
function EquipmentSuperSlot:new(slotDefinition, bodySlotDisplay, inventoryPane, playerNum, popup)
    ---@type EquipmentSuperSlot
    local o = ISPanel:new(0, 0, (Settings.SUPER_SLOT_SIZE + Settings.SUPER_SLOT_SUB_ITEM_WIDTH), Settings.SUPER_SLOT_SIZE);
	setmetatable(o, self)
    self.__index = self

    if slotDefinition.position then
        o:setX(Settings.SCALE * slotDefinition.position.x + Settings.EQUIPMENT_UI_X_OFFSET);
        o:setY(Settings.SCALE * slotDefinition.position.y + Settings.EQUIPMENT_UI_Y_OFFSET);
    end

    o.slotDefinition = slotDefinition;
    o.bodySlotDisplay = bodySlotDisplay;
    o.inventoryPane = inventoryPane;
    o.playerNum = playerNum;
	o.moveWithMouse = true;

    o.slots = {}
    o.slotsByBodyLocation = {}
    o.mouseDownX = 0;
    o.mouseDownY = 0;

    o.popup = popup;

    o.bodyLocationGroup = getSpecificPlayer(playerNum):getWornItems():getBodyLocationGroup();

	return o;
end

function EquipmentSuperSlot:initialise()
    ISPanel.initialise(self);

    table.insert(Settings.OnScaleChanged, function(scale)
        self:setX(scale * self.slotDefinition.position.x + Settings.EQUIPMENT_UI_X_OFFSET);
        self:setY(scale * self.slotDefinition.position.y + Settings.EQUIPMENT_UI_Y_OFFSET);
        self:setWidth(Settings.SUPER_SLOT_SIZE + Settings.SUPER_SLOT_SUB_ITEM_WIDTH);
        self:setHeight(Settings.SUPER_SLOT_SIZE);
    end)

    ControllerNode
        :injectControllerNode(self)
        :setJoypadDownHandler(self.controllerNodeOnJoypadDown)
        :setLoseJoypadFocusHandler(function()
            self:setExpanded(false)
        end)
        :setChildrenNodeProvider(self.getVisibleControllerNodes, self)
end

function EquipmentSuperSlot:createChildren()
    for _, bodyLocation in ipairs(self.slotDefinition.bodyLocations) do
        local slot = EquipmentSlot:new(0, 0, bodyLocation, self.bodySlotDisplay, self.inventoryPane, self.playerNum);
        slot:initialise();
        self.slotsByBodyLocation[bodyLocation] = slot;
        self.slots[#self.slots + 1] = slot;
    end
end

---@param item InventoryItem
---@param bodyLocation ItemBodyLocation
function EquipmentSuperSlot:setItem(item, bodyLocation)
    if self.slotsByBodyLocation[bodyLocation] then
        self.slotsByBodyLocation[bodyLocation]:setItem(item);
    end
end

function EquipmentSuperSlot:setOverrideItem(item, bodyLocation)
    local slot = self.slotsByBodyLocation[bodyLocation]
    if not slot then
        slot = EquipmentSlot:new(0, 0, bodyLocation, self.bodySlotDisplay, self.inventoryPane, self.playerNum);
        slot:initialise();
        self.slotsByBodyLocation[bodyLocation] = slot;
        self.slots[#self.slots + 1] = slot;
    end
    slot:setItem(item);
end

function EquipmentSuperSlot:clearItem()
    for _, slot in ipairs(self.slots) do
        slot:clearItem();
    end
end

function EquipmentSuperSlot:hasItem()
    return self:getTopItem() ~= nil
end

function EquipmentSuperSlot:getTopItem()
    local slot = self:getTopSlot();
    return slot and slot.item or nil;
end

function EquipmentSuperSlot:getTopSlot()
    for _, slot in pairs(self.slotsByBodyLocation) do
        if slot.item then
            return slot;
        end
    end
    return nil;
end

function EquipmentSuperSlot:getVisibleControllerNodes()
    if not self.expanded then return nil end

    local slots = {}
    for _, slot in pairs(self.slotsByBodyLocation) do
        if slot:isVisible() then
            table.insert(slots, slot.controllerNode)
        end
    end
    return slots
end

function EquipmentSuperSlot:getNthItem(index)
    local count = 0;
    for _, slot in pairs(self.slotsByBodyLocation) do
        if slot.item then
            count = count + 1;
            if count == index then
                return slot.item;
            end
        end
    end
    return nil;
end

function EquipmentSuperSlot:getItemCount()
    local count = 0
    for _, slot in pairs(self.slotsByBodyLocation) do
        if slot.item then
            count = count + 1;
        end
    end
    return count
end

---@param item InventoryItem
---@param bodyLocation ItemBodyLocation
function EquipmentSuperSlot:doesItemConflict(item, bodyLocation)
    if not bodyLocation then
        return false
    end

    for _, slot in pairs(self.slotsByBodyLocation) do
        if slot.item and slot.item ~= item and (bodyLocation == slot.bodyLocation or self.bodyLocationGroup:isExclusive(bodyLocation, slot.bodyLocation)) then
            return true
        end
    end
    return false
end

function EquipmentSuperSlot:isDraggingMyItem()
    local dragItem = DragAndDrop.getDraggedItem();
    if dragItem then
        for _, slot in pairs(self.slotsByBodyLocation) do
            if slot.item == dragItem then
                return true;
            end
        end
    end
    return false;
end

function EquipmentSuperSlot:determineTargetSlot(item)
    -- Find all valid slots for this item
    local bodyLocationMap = ClothingItemExtraService.getBodyLocationsForItem(item);

    -- Find the best slot to put it in
    -- Preference is:
    -- 1. The slot the item is already in
    -- 2. An empty slot that can accept the item
    -- 3. The "default slot" for the item (first body location)
    local currentSlot = nil
    local emptySlot = nil
    local defaultSlot = nil

    for bodyLocation, slot in pairs(self.slotsByBodyLocation) do
        if slot.item == item then
            currentSlot = slot
            break
        end
        if bodyLocationMap[bodyLocation] and not slot.item and not emptySlot then
            emptySlot = slot
        end
        if bodyLocationMap[bodyLocation] and not defaultSlot then
            defaultSlot = slot
        end
    end

    return currentSlot or emptySlot or defaultSlot
end

function EquipmentSuperSlot:prerender()
    local itemCount = self:getItemCount();

    local hasControllerFocus = self.controllerNode and self.controllerNode.isFocused
    local bgColor = hasControllerFocus and ControllerNode.FOCUS_COLOR or BG_COLOR

    if itemCount > 0 then
        local slotWidth = (itemCount > 1 and Settings.SUPER_SLOT_SIZE + Settings.SUPER_SLOT_SUB_ITEM_WIDTH or Settings.SUPER_SLOT_SIZE);

        self:drawRect(0, 0, slotWidth, Settings.SUPER_SLOT_SIZE, 0.85, 0, 0, 0);
        self:drawTextureScaled(BG_TEXTURE, 0, 0, slotWidth, Settings.SUPER_SLOT_SIZE, 1, bgColor.r, bgColor.g, bgColor.b);
        self:drawRectBorder(0, 0, slotWidth, Settings.SUPER_SLOT_SIZE, 1, 1, 1, 1);
    else
        self:drawRect(0, 0, Settings.SUPER_SLOT_SIZE, Settings.SUPER_SLOT_SIZE, 0.65, 0, 0, 0);
        self:drawTextureScaled(BG_TEXTURE, 0, 0, Settings.SUPER_SLOT_SIZE, Settings.SUPER_SLOT_SIZE, 1, bgColor.r, bgColor.g, bgColor.b);
        self:drawRectBorder(0, 0, Settings.SUPER_SLOT_SIZE, Settings.SUPER_SLOT_SIZE, 1, 1, 1, 1);
    end

    local dragItem = DragAndDrop.getDraggedItem();
    if dragItem then
        local targetSlot = self:determineTargetSlot(dragItem)
        if targetSlot then
            local canAcceptItem = targetSlot and targetSlot.item ~= dragItem
            local hasConflictingItems = self:doesItemConflict(dragItem, targetSlot.bodyLocation)

            local col = (canAcceptItem and hasConflictingItems) and Settings.MIDDLE_COLOR
                or (canAcceptItem and Settings.GOOD_COLOR)
                or (hasConflictingItems and Settings.BAD_COLOR)
                or nil

            if col then
                self:drawRect(1, 1, Settings.SUPER_SLOT_SIZE - 2, Settings.SUPER_SLOT_SIZE - 2, 0.5, col.r, col.g, col.b);
            end
        end
    end

    if self.expanded and itemCount < 2 then
        self:toggleExpanded();
    end
end

function EquipmentSuperSlot:render()
    --if the mouse is over the super slot, draw the name of the slot
    if self:isMouseOver() or self.controllerNode.isFocused then
        local name = getText(self.slotDefinition.name);
        local width = getTextManager():MeasureStringX(UIFont.Small, name);
        local height = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight();

        local center = Settings.SUPER_SLOT_SIZE / 2
        local x = center - width / 2 - 3
        local y = -height - 2

        self:drawRect(x, y, width + 8, height+4, 0.9, 0, 0, 0);

        self:drawRectBorder(x, y, width + 8, height+4, 1, 1, 1, 1);
        self:drawTextCentre(name, center, y, 1, 1, 1, 1, UIFont.Small);
    end

    local itemsToDraw = {};

    -- Index slots for drawing
    local index = 1;
    for _, bodyLocation in ipairs(self.slotDefinition.bodyLocations) do
        local slot = self.slotsByBodyLocation[bodyLocation];
        if slot.item and index <= 4 then
            itemsToDraw[index] = slot.item;
            index = index + 1;
        end
    end

    -- If no items, nothing to draw
    local count = index - 1
    if count == 0 then
        return
    end

    local xOff = (Settings.SUPER_SLOT_SIZE - Settings.SLOT_SIZE) / 2;
    local yOff = (Settings.SUPER_SLOT_SIZE - Settings.SLOT_SIZE) / 2;
    local mainAlpha = 1.0;
    if itemsToDraw[1] == DragAndDrop.getDraggedItem() then
        mainAlpha = 0.5;
    end

    -- Draw primary item
    -- Smangsty: Use B42.20 aspect-fit rendering for primary and sub-item icons.
    local mainIconSize = Settings.SLOT_SIZE - (Settings.SCALE * 2);
    self:drawTextureScaledAspect(itemsToDraw[1]:getTex(), xOff + Settings.SCALE, yOff + Settings.SCALE, mainIconSize, mainIconSize, mainAlpha, EquipmentSlot.getItemColor(itemsToDraw[1]));

    -- Draw sub items to the side
    if count > 1 then
        local slotSize = Settings.SUPER_SLOT_SIZE + Settings.SUPER_SLOT_SUB_ITEM_WIDTH
        local scaledSize = MINI_ICON_SIZE * Settings.SCALE
        for i = 2, count do
            self:drawRect(slotSize - scaledSize - 1, (scaledSize * (i - 2)), scaledSize+1, scaledSize+1, 0.7, 0, 0, 0);
            self:drawRectBorder(slotSize - scaledSize - 1, (scaledSize * (i - 2)), scaledSize+1, scaledSize+1, 0.4, 1, 1, 1);
            self:drawTextureScaledAspect(itemsToDraw[i]:getTex(), slotSize - scaledSize, scaledSize * (i - 2), scaledSize, scaledSize, 1, EquipmentSlot.getItemColor(itemsToDraw[i]));
        end

        self:drawRectBorder(Settings.SUPER_SLOT_SIZE - 1, 0, Settings.SUPER_SLOT_SUB_ITEM_WIDTH + 1, Settings.SUPER_SLOT_SIZE, 1, 1, 1, 1);
    end

    if self.controllerNode.isFocused and not self.controllerNode.selectedChild then
        self.bodySlotDisplay:doTooltipForItem(self, itemsToDraw[1]);
    elseif not DragAndDrop.isDragging() and self:isMouseOver() then
        -- Smangsty: A plugged-in controller does not get to put mouse hover in witness protection.
        local x = self:getMouseX();
        local y = self:getMouseY();

        if y > Settings.SUPER_SLOT_SIZE then
            return
        end

        local index = self:mousePositionToSlotIndex(x, y);
        if index ~= -1 and index <= count then
            self.bodySlotDisplay:doTooltipForItem(self, itemsToDraw[index]);
        else
            self.bodySlotDisplay:closeTooltip();
        end
    end
end

function EquipmentSuperSlot:mousePositionToSlotIndex(x, y)
    if x > 0 and y > 0 and x < Settings.SUPER_SLOT_SIZE and y < Settings.SUPER_SLOT_SIZE then
        return 1;
    end

    if x > Settings.SUPER_SLOT_SIZE and y > 0 and x < (Settings.SUPER_SLOT_SIZE + Settings.SUPER_SLOT_SUB_ITEM_WIDTH) and y < Settings.SUPER_SLOT_SIZE then
        return math.floor(y / MINI_ICON_SIZE / Settings.SCALE) + 2;
    end

    return -1;
end

function EquipmentSuperSlot:onRightMouseUp(x, y)
    local index = self:mousePositionToSlotIndex(x, y);
    if index == -1 then
        return
    end

    local item = self:getNthItem(index);
    if item then
        EquipmentSlot.openItemContextMenu(self, x, y, item, self.inventoryPane, self.playerNum)
        ---@diagnostic disable-next-line: redundant-return-value, return-type-mismatch
        return true
    end
end

function EquipmentSuperSlot:onMouseDown(x, y)
    self.mouseDownX = x;
    self.mouseDownY = y;
    
    local item = self:getTopItem();
    if item then
        local stack = DragAndDrop.convertItemToStack(item);
        DragAndDrop.prepareDrag(self, stack, x, y);
        return true;
    end

    ISPanel.onMouseDown(self, x, y);
end

function EquipmentSuperSlot:onMouseMove(dx, dy)
    local item = DragAndDrop.getDraggedItem()
    if not item then return end
    
    local targetSlot = self:determineTargetSlot(item)
    if targetSlot then
        local defaultBodyLocation = ClothingItemExtraService.getDefaultBodyLocation(item)
        if self:doesItemConflict(item, defaultBodyLocation) then
            self:setExpanded(true);
        end
    else 
        DragAndDrop.startDrag(self);
    end
end

function EquipmentSuperSlot:onMouseMoveOutside(x, y)
    if not DragAndDrop.isDragging() then  
        DragAndDrop.startDrag(self);
    end

    -- if the mouse is more than 10 pixels away from the edge of the super slot, close it
    local limit = 10 * Settings.SCALE
    if self.expanded and not self.popup:isMouseOver() and not self:isDraggingMyItem() and (math.abs(x - self.mouseDownX) > limit or math.abs(y - self.mouseDownY) > limit) then
        self:setExpanded(false);
    end
end

function EquipmentSuperSlot:onMouseUp(x, y)
    if DragAndDrop.isDragging() then
        self:handleDragDrop(x, y);
    else
        self:handleSlotClick(x, y);
    end
    DragAndDrop.endDrag();
end

function EquipmentSuperSlot:onMouseUpOutside(x, y)
    DragAndDrop.cancelDrag(self, EquipmentSuperSlot.dropOrUnequip);
end

function EquipmentSuperSlot:handleDragDrop(x, y)
    local item = DragAndDrop.getDraggedItem();
    local targetSlot = self:determineTargetSlot(item)
    if item and targetSlot then
        self:handleClothingDrop(item, targetSlot.bodyLocation);
    end

    DragAndDrop.endDrag();
end

---@param item InventoryItem
---@param bodyLocation ItemBodyLocation
function EquipmentSuperSlot:handleClothingDrop(item, bodyLocation)
    local slot = self.slotsByBodyLocation[bodyLocation];
    if slot then
        local defaultBodyLocation = ClothingItemExtraService.getDefaultBodyLocation(item)
        if defaultBodyLocation == bodyLocation then
            ISInventoryPaneContextMenu.onWearItems({item}, self.playerNum);
        else
            local extra = ClothingItemExtraService.findExtraOptionForBodyLocation(item, bodyLocation);
            if not extra then return; end
            ISInventoryPaneContextMenu.onClothingItemExtra(item, extra, getSpecificPlayer(self.playerNum));
        end
    end
end

function EquipmentSuperSlot:handleSlotClick(x, y)
    local dx = math.abs(x - self.mouseDownX);
    local dy = math.abs(y - self.mouseDownY);
    if dx < 5 and dy < 5 then
        self:toggleExpanded();
    end
    ISPanel.onMouseUp(self, x, y);
end

function EquipmentSuperSlot:toggleExpanded()
    self:setExpanded(not self.expanded);
end

function EquipmentSuperSlot:setExpanded(expanded)
    if self.expanded == expanded then
        return
    end

    self.expanded = expanded and self:getItemCount() > 1;
    if self.expanded then
        self:openPopup();

        local firstSlot = self:getTopSlot()
        self.controllerNode:setSelectedChild(firstSlot and firstSlot.controllerNode);
    else
        self.popup:setVisible(false);
        self.controllerNode:setSelectedChild(nil);
    end
end

function EquipmentSuperSlot:openPopup()
    self.popup:setX(self:getAbsoluteX());
    self.popup:setY(self:getAbsoluteY() + self:getHeight());
    self.popup:setVisible(true);

    self.popup:bringToTop()
    self.bodySlotDisplay:bringTooltipToTop()

    local equipmentSlots = {}
    for _, slot in pairs(self.slotsByBodyLocation) do
        table.insert(equipmentSlots, slot);
    end

    self.popup:applySlots(equipmentSlots)
end

function EquipmentSuperSlot:dropOrUnequip()
    local item = self:getTopItem()
    if item then
        EquipmentSlot.doDropOrUnequip(self, item)
    end
end

function EquipmentSuperSlot:unequip()
    local item = self:getTopItem()
    if item then
        ISInventoryPaneContextMenu.unequipItem(item, self.playerNum)
    end
end

function EquipmentSuperSlot:controllerNodeOnJoypadDown(button)
    if button == Joypad.BButton then
        self:toggleExpanded()
        return true
    end
    if button == Joypad.XButton then
        self:unequip()
        return true
    end
    if button == Joypad.AButton then
        local item = self:getTopItem()
        if item then
            local x = self.width
            local y = self.height/2
            EquipmentSlot.openItemContextMenu(self, x, y, item, self.inventoryPane, self.playerNum)
        end
        return true
    end
    return false
end

return EquipmentSuperSlot
