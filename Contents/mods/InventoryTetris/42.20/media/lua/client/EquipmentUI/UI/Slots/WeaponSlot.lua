require ("ISUI/ISPanel")
local c = require ("EquipmentUI/Settings")
local ControllerNode = require("Notloc/UI/ControllerNode")
local EquipmentSlot = require("EquipmentUI/UI/Slots/EquipmentSlot")
local DragAndDrop = require("EquipmentUI/DragAndDrop")

local BG_COLOR = {r=1, g=1, b=1}
local TWO_HAND_OFFSET = 1.3;

---@class WeaponSlot : ISPanel
---@field public weaponSlotDef WeaponSlotDefinition
---@field public bodySlotDisplay BodySlotDisplay
---@field public inventoryPane ISInventoryPane
---@field public playerNum integer
---@field public player IsoPlayer
---@field public isSecondary boolean
---@field public primaryTexture Texture
---@field public secondaryTexture Texture
---@field public draw2hSlot boolean
---@field public controllerNode ControllerNode
local WeaponSlot = ISPanel:derive("WeaponSlot");

---@param weaponSlotDef WeaponSlotDefinition
---@param bodySlotDisplay BodySlotDisplay
---@param inventoryPane ISInventoryPane
---@param playerNum integer
---@param isSecondary boolean
---@return WeaponSlot
function WeaponSlot:new(weaponSlotDef, bodySlotDisplay, inventoryPane, playerNum, isSecondary)
    ---@type WeaponSlot
    local o = ISPanel:new(0, 0, c.WEAPON_SLOT_SIZE, c.WEAPON_SLOT_SIZE);
	setmetatable(o, self)
    self.__index = self

    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
    o.backgroundColor = {r=0, g=0, b=0, a=0.15};

    o.weaponSlotDef = weaponSlotDef;
    o.bodySlotDisplay = bodySlotDisplay;
    o.inventoryPane = inventoryPane;
    o.playerNum = playerNum;
    o.player = getSpecificPlayer(playerNum);
    o.isSecondary = isSecondary;

    o.primaryTexture = getTexture("media/ui/HandMain2_Off.png");
	o.secondaryTexture = getTexture("media/ui/HandSecondary2_Off.png");

	return o;
end

function WeaponSlot:initialise()
    ISPanel.initialise(self);

    table.insert(c.OnScaleChanged, function(scale)
       self:applyScale(scale)
    end)
    self:applyScale(c.SCALE)
    ControllerNode
        :injectControllerNode(self)
        :setJoypadDownHandler(self.controllerNodeOnJoypadDown)
end

function WeaponSlot:applyScale(scale)
    local x = (scale * self.weaponSlotDef.position.x + c.EQUIPMENT_UI_X_OFFSET);
    local y = (scale * self.weaponSlotDef.position.y + c.EQUIPMENT_UI_Y_OFFSET);

    self:setX(x)
    self:setY(y)
    self:setWidth(c.WEAPON_SLOT_SIZE)
    self:setHeight(c.WEAPON_SLOT_SIZE)
end

function WeaponSlot:getHandItem()
    if self.isSecondary then
        return self.player:getSecondaryHandItem();
    else
        return self.player:getPrimaryHandItem();
    end
end

function WeaponSlot:prerender()
    local tex = self.isSecondary and self.secondaryTexture or self.primaryTexture;
    local hasControllerFocus = self.controllerNode and self.controllerNode.isFocused
    local bgColor = hasControllerFocus and ControllerNode.FOCUS_COLOR or BG_COLOR

    local r, g, b = bgColor.r, bgColor.g, bgColor.b;

    local item = self:getHandItem();
    local dragItem = DragAndDrop.getDraggedItem();
    if dragItem then
        if dragItem ~= item and self:canAcceptItem(dragItem) then
            if item then
                r = c.MIDDLE_COLOR.r;
                g = c.MIDDLE_COLOR.g;
                b = c.MIDDLE_COLOR.b;
            else
                r = c.GOOD_COLOR.r;
                g = c.GOOD_COLOR.g;
                b = c.GOOD_COLOR.b;
            end
        end

        if not self.isSecondary and dragItem:isTwoHandWeapon() then
            self.draw2hSlot = true;
        end
    else
        self.draw2hSlot = false;
    end

    self:drawTextureScaledUniform(tex, 0, 0, c.SCALE, 1, r,g,b);

    if self.draw2hSlot then
        self:bringToTop()
        self:setWidth(c.WEAPON_SLOT_SIZE * (TWO_HAND_OFFSET+1))
        self:drawTextureScaledUniform(self.primaryTexture, c.WEAPON_SLOT_SIZE * TWO_HAND_OFFSET, 0, c.SCALE, 1, c.GOOD_COLOR.r, c.GOOD_COLOR.g, c.GOOD_COLOR.b);
    else
        self:setWidth(c.WEAPON_SLOT_SIZE)
    end
end

function WeaponSlot:render()
    local item = self:getHandItem();
    if not item then
        return
    end

    local alpha = 1.0
    if item == DragAndDrop.getDraggedItem() then
        alpha = 0.5
    end

    if self.isSecondary then
        self:drawTextureCenteredAndSquare(item:getTex(), c.WEAPON_SLOT_SECONDARY_X_OFFSET, c.WEAPON_SLOT_SECONDARY_Y_OFFSET, c.WEAPON_SLOT_SECONDARY_SIZE, alpha, self.getItemColor(item));
    else
        self:drawTextureCenteredAndSquare(item:getTex(), 1 + c.WEAPON_SLOT_PRIMARY_OFFSET, c.WEAPON_SLOT_PRIMARY_OFFSET, c.WEAPON_SLOT_PRIMARY_SIZE, alpha, self.getItemColor(item));
    end

    if self:isMouseOver() or self.controllerNode.isFocused then
        self.bodySlotDisplay:doTooltipForItem(self, item);
    end
end

function WeaponSlot.getItemColor(item)
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

function WeaponSlot:onRightMouseUp(x, y)
    local item = self:getHandItem();
    if item then
        EquipmentSlot.openItemContextMenu(self, x, y, item, self.inventoryPane, self.playerNum);
    end
end

function WeaponSlot:onMouseDown(x, y)
    local item = self:getHandItem();
    if item then
        DragAndDrop.prepareDrag(self, DragAndDrop.convertItemToStack(item), x, y);
    end
end

function WeaponSlot:onMouseMove(dx, dy)
    DragAndDrop.startDrag(self);
end

function WeaponSlot:onMouseMoveOutside(dx, dy)
    DragAndDrop.startDrag(self);
end

function WeaponSlot:onMouseUp(x, y)
    if DragAndDrop.isDragging() then
        self:handleItemDrop(DragAndDrop.getDraggedItem(), x, y);
    end
    DragAndDrop.endDrag();
end

function WeaponSlot:onMouseUpOutside(x, y)
    DragAndDrop.cancelDrag(self, WeaponSlot.dropOrUnequip);
end

function WeaponSlot:handleItemDrop(item, x, y)
    local playerObj = getSpecificPlayer(self.playerNum)
    local requiresBothHands = item:isRequiresEquippedBothHands()
    
    if self.draw2hSlot then
        if x > c.WEAPON_SLOT_SIZE * TWO_HAND_OFFSET then
            requiresBothHands = true
        end
    end

    if requiresBothHands then
        ISInventoryPaneContextMenu.equipWeapon(item, true, true, self.playerNum)
    elseif self:canAcceptItem(item) then
        if not self.isSecondary then
            ISInventoryPaneContextMenu.equipWeapon(item, true, false, self.playerNum)
        else
            ISInventoryPaneContextMenu.equipWeapon(item, false, false, self.playerNum)
        end
    end
end

function WeaponSlot:canAcceptItem(item)
    local isFood = item:getCategory() == "Food" and not item:getScriptItem():isCantEat()
    if isFood then
        return false
    end

    local isClothes = item:getCategory() == "Clothing"
    if isClothes then
        return false
    end

    return self:isHandGood(item)
end

function WeaponSlot:isHandGood(item)
    local playerObj = getSpecificPlayer(self.playerNum)
    local hand = self.isSecondary and 
                    playerObj:getBodyDamage():getBodyPart(BodyPartType.Hand_L) or 
                    playerObj:getBodyDamage():getBodyPart(BodyPartType.Hand_R)

    local isAlreadyEquipped = self.isSecondary and playerObj:isSecondaryHandItem(item) or playerObj:isPrimaryHandItem(item)
    local isInOtherHand = self.isSecondary and playerObj:isPrimaryHandItem(item) or playerObj:isSecondaryHandItem(item)

    if (not isAlreadyEquipped or isInOtherHand) and not hand:isDeepWounded() and (hand:getFractureTime() == 0 or hand:getSplintFactor() > 0) then
        -- forbid reequipping skinned items to avoid multiple problems for now
        local add = true;
        if isInOtherHand and item:getScriptItem():getReplaceWhenUnequip() then
            return false
        end
        return true
    end
end

function WeaponSlot:dropOrUnequip()
    local item = self:getHandItem();
    if item then
        if not c.InventoryTetris then
            if self.inventoryPane:isMouseOver() then
                ISInventoryPaneContextMenu.unequipItem(item, self.playerNum)
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

function WeaponSlot:controllerNodeOnJoypadDown(button)
    if button == Joypad.AButton then
        local item = self:getHandItem();
        if item then
            EquipmentSlot.openItemContextMenu(self, self:getWidth(), self:getHeight(), item, self.inventoryPane, self.playerNum);
        end
        return true
    end

    if button == Joypad.XButton then
        local item = self:getHandItem();
        if item then
            ISInventoryPaneContextMenu.unequipItem(item, self.playerNum)
        end
        return true
    end

    return false
end

return WeaponSlot
