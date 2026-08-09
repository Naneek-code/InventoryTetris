require ("ISUI/ISPanelJoypad")
local EquipmentSlot = require("EquipmentUI/UI/Slots/EquipmentSlot")
local EquipmentSuperSlot = require("EquipmentUI/UI/Slots/EquipmentSuperSlot")
local WeaponSlot = require("EquipmentUI/UI/Slots/WeaponSlot")
local HotbarSlot = require("EquipmentUI/UI/Slots/HotbarSlot")

local SUPER_SLOT_DEFS = require("EquipmentUI/Definitions/EquipmentSlotDefinitions")
local WEAPON_SLOT_DEFS = require("EquipmentUI/Definitions/WeaponSlotDefinitions")
local SETTINGS = require("EquipmentUI/Settings")

local MALE_BODY_TEX = getTexture("media/ui/defense/male_base.png")
local FEMALE_BODY_TEX = getTexture("media/ui/defense/female_base.png")

---@class BodySlotDisplay : ISPanelJoypad
---@field public inventoryPane ISInventoryPane
---@field public playerNum integer
---@field public char IsoPlayer
---@field public bodyOutline Texture
---@field public dynamicEquipmentY number
---@field public dynamicSlotsByBodyLocation table<ItemBodyLocation, EquipmentSlot>
---@field public dynamicSlotPool EquipmentSlot[]
---@field public superSlotsByBodyLocation table<ItemBodyLocation, EquipmentSuperSlot[]>
---@field public primarySlot WeaponSlot
---@field public secondarySlot WeaponSlot
---@field public hotbarSlots HotbarSlot[]
---@field public hotbarSlotPool HotbarSlot[]
---@field public popup SuperSlotPopup
local BodySlotDisplay = ISPanelJoypad:derive("BodySlotDisplay");

---@param x number
---@param y number
---@param width number
---@param height number
---@param inventoryPane ISInventoryPane
---@param playerNum integer
---@param popup SuperSlotPopup
---@return BodySlotDisplay
function BodySlotDisplay:new(x, y, width, height, inventoryPane, playerNum, popup)
	---@type BodySlotDisplay
    local o = ISPanelJoypad:new(x, y, width, height);
	setmetatable(o, self);
    self.__index = self;

    o.inventoryPane = inventoryPane
    o.playerNum = playerNum

	o.char = getSpecificPlayer(playerNum);
	o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
	o.backgroundColor = {r=0, g=0, b=0, a=0.8};
	o.bodyOutline = o.char:isFemale() and FEMALE_BODY_TEX or MALE_BODY_TEX

    o.hotbarSlots = {}
    o.hotbarSlotPool = {}

    o.popup = popup
    o.dynamicEquipmentY = SETTINGS.EQUIPMENT_DYNAMIC_SLOT_Y_OFFSET

   return o;
end

function BodySlotDisplay:createChildren()
    ISPanelJoypad.createChildren(self);
    self:createEquipmentSlots();
    self:createWeaponSlots();

    table.insert(SETTINGS.OnScaleChanged, function()
        local hotbar = getPlayerHotbar(self.playerNum)
        self:updateDynamicEquipmentSlots()
        self:updateHotbarSlots(hotbar)
        self:setWidth(SETTINGS.EQUIPMENT_WIDTH)
    end)

    self:updateSlots()
    self:updateDynamicEquipmentSlots()
end

function BodySlotDisplay:createEquipmentSlots()
    self.dynamicSlotPool = {}
    self.dynamicSlotsByBodyLocation = {};
    self.superSlots = {}
    self.superSlotsByBodyLocation = {};

    for _, superSlotDef in pairs(SUPER_SLOT_DEFS) do
        local superslot = EquipmentSuperSlot:new(superSlotDef, self, self.inventoryPane, self.playerNum, self.popup);
        superslot:initialise();
        superslot.moveWithMouse = false
        self:addChild(superslot);
        table.insert(self.superSlots, superslot)

        for _, bodyLocation in pairs(superslot.slotDefinition.bodyLocations) do
            local list = self.superSlotsByBodyLocation[bodyLocation]
            if not list then
                list = {}
                self.superSlotsByBodyLocation[bodyLocation] = list;
            end
            table.insert(list, superslot);
        end
    end
end

function BodySlotDisplay:updateDynamicEquipmentSlots()
    for key, slot in pairs(self.dynamicSlotsByBodyLocation) do
        slot:setVisible(false)
        table.insert(self.dynamicSlotPool, slot)
        self.dynamicSlotsByBodyLocation[key] = nil
    end

    local player = getSpecificPlayer(self.playerNum)
    local wornItems = player:getWornItems()

    local MAX_COLUMN = 5

    local column = 0
    local row = 0
    for i = 1, wornItems:size() do
        local wornItem = wornItems:get(i-1)
        if not wornItem:getItem():isHidden() then
            local bodyLocation = wornItem:getLocation()
            if not self.superSlotsByBodyLocation[bodyLocation] then
                if column >= MAX_COLUMN then
                    column = 0
                    row = row + 1
                end

                local slot = self:createDynamicEquipmentSlot(bodyLocation)
                slot:setX(SETTINGS.EQUIPMENT_DYNAMIC_SLOT_X_OFFSET + (column * (SETTINGS.SLOT_SIZE + SETTINGS.EQUIPMENT_DYNAMIC_SLOT_MARGIN)));
                slot:setY(SETTINGS.EQUIPMENT_DYNAMIC_SLOT_Y_OFFSET + (row * (SETTINGS.SLOT_SIZE + SETTINGS.EQUIPMENT_DYNAMIC_SLOT_MARGIN)));
                slot:setItem(wornItem:getItem())
                self.dynamicSlotsByBodyLocation[bodyLocation] = slot

                column = column + 1
            end
        end
    end

    if column > 0 then
        row = row + 1
    end

    self.dynamicEquipmentY = SETTINGS.EQUIPMENT_DYNAMIC_SLOT_Y_OFFSET + ((row) * (SETTINGS.SLOT_SIZE + 4)) + 8
end

---@param bodyLocation ItemBodyLocation
---@return EquipmentSlot
function BodySlotDisplay:createDynamicEquipmentSlot(bodyLocation)
    if #self.dynamicSlotPool > 0 then
        local slot = self.dynamicSlotPool[#self.dynamicSlotPool]  
        if slot then
            table.remove(self.dynamicSlotPool, #self.dynamicSlotPool)
            slot.bodyLocation = bodyLocation
            slot:setVisible(true)
            slot:setItem(nil)
            return slot
        end
    end

    local slot = EquipmentSlot:new(50, 50, bodyLocation, self, self.inventoryPane, self.playerNum);
    slot.borderColor = {r=1, g=1, b=1, a=1};
    slot:initialise();
    self:addChild(slot);
    return slot
end

function BodySlotDisplay:createWeaponSlots()
    self.primarySlot = WeaponSlot:new(WEAPON_SLOT_DEFS.primary, self, self.inventoryPane, self.playerNum, false);
    self.primarySlot:initialise();
    self:addChild(self.primarySlot);

    self.secondarySlot = WeaponSlot:new(WEAPON_SLOT_DEFS.secondary, self, self.inventoryPane, self.playerNum, true);
    self.secondarySlot:initialise();
    self:addChild(self.secondarySlot);
end

function BodySlotDisplay:updateSlots()
    for _, slot in pairs(self.dynamicSlotsByBodyLocation) do
        slot.item = nil
    end

    for _, superSlot in ipairs(self.superSlots) do
        for _, slot in ipairs(superSlot.slots) do
            slot.item = nil
        end
    end

    local wornItems = self.char:getWornItems()
    for i=1,wornItems:size() do
        local wornItem = wornItems:get(i-1)
        local bodyLocation = wornItem:getLocation()
        
        local slotList = self.superSlotsByBodyLocation[bodyLocation]
        if slotList then
            for _, slot in pairs(slotList) do
                slot:setItem(wornItem:getItem(), bodyLocation)
            end
        end

        if self.dynamicSlotsByBodyLocation[bodyLocation] then
            self.dynamicSlotsByBodyLocation[bodyLocation]:setItem(wornItem:getItem())
        end
    end
end

function BodySlotDisplay:updateHotbarSlots(hotbar)
    if not hotbar then
        return
    end

    self:disableHotbarSlots()

    local y = self.dynamicEquipmentY + SETTINGS.HOTBAR_SLOT_Y_OFFSET

    local row = 0
    local column = 0
    local slots = hotbar.availableSlot
    for i, slot in ipairs(slots) do
        if column >= 5 then
            column = 0
            row = row + 1
        end

        local newSlot = self:createHotbarSlot(hotbar)
        newSlot:setX(SETTINGS.HOTBAR_SLOT_X_OFFSET + (column * (SETTINGS.SUPER_SLOT_SIZE + SETTINGS.HOTBAR_SLOT_MARGIN)));
        newSlot:setY(y + (row * (SETTINGS.SUPER_SLOT_SIZE + SETTINGS.HOTBAR_SLOT_MARGIN)));

        newSlot.index = i

        column = column + 1
    end

    local newHeight = y + ((row + 1) * (SETTINGS.SUPER_SLOT_SIZE + SETTINGS.HOTBAR_SLOT_MARGIN)) + SETTINGS.EQUIPMENT_UI_BOTTOM_PADDING
    self:setHeight(newHeight)
end

function BodySlotDisplay:createHotbarSlot(hotbar)
    local newSlot = nil
    if #self.hotbarSlotPool > 0 then -- Used to remove from the end, but we do the front now for controller support
        newSlot = self.hotbarSlotPool[1] -- Kind of a lazy fix, but we refresh these every frame so they can't be changing order
        table.remove(self.hotbarSlotPool, 1) -- Eventually need to rewrite this to only update the slots that changed
        newSlot:setVisible(true)
        
    else
        newSlot = HotbarSlot:new(hotbar, self, self.inventoryPane, self.playerNum);
        newSlot:initialise();
        self:addChild(newSlot);
    end

    table.insert(self.hotbarSlots, newSlot)
    return newSlot
end

function BodySlotDisplay:disableHotbarSlots()
    for _, slot in pairs(self.hotbarSlots) do
        slot:setVisible(false)
        slot.index = nil
        table.insert(self.hotbarSlotPool, slot) 
    end
    table.wipe(self.hotbarSlots)
end

function BodySlotDisplay:prerender()
    self:renderHeaderCentered(getText("UI_equipment_equipment"), 12)
    self:renderHeaderCentered(getText("UI_equipment_hotbar"), self.dynamicEquipmentY + 12)
    self:drawTextureScaledUniform(self.bodyOutline, SETTINGS.EQUIPMENT_UI_X_OFFSET, SETTINGS.EQUIPMENT_UI_Y_OFFSET, SETTINGS.SCALE, 1, 1, 1, 1);

    -- Refresh equipped item info each frame
    -- OnClothingUpdated doesn't always fire when expected
    self:updateSlots()
    self:updateDynamicEquipmentSlots()

    local hotbar = getPlayerHotbar(self.playerNum)
    if hotbar and not hotbar.notloc_onRefresh then
        hotbar.notloc_onRefresh = function(hotbar)
            self:updateHotbarSlots(hotbar)
        end
        self:updateHotbarSlots(hotbar)
    end
end

function BodySlotDisplay:renderHeader(text, height)
    local hotbarTextW = getTextManager():MeasureStringX(UIFont.Small, text);
    local hotbarTextH = getTextManager():getFontHeight(UIFont.Small);
    self:drawText(text, 8, height - hotbarTextH/2, 1, 1, 1, 1, UIFont.Small);
    self:drawRectBorder(12 + hotbarTextW, height, self.width - 24 - hotbarTextW, 1, 1, 1, 1, 1);
end

function BodySlotDisplay:renderHeaderCentered(text, height)
    local hotbarTextW = getTextManager():MeasureStringX(UIFont.Small, text);
    local hotbarTextH = getTextManager():getFontHeight(UIFont.Small);
    self:drawText(text, self.width/2 - hotbarTextW/2, height - hotbarTextH/2, 1, 1, 1, 1, UIFont.Small);
    -- two borders, one on each side
    self:drawRectBorder(12, height, self.width/2 - hotbarTextW/2 - 18, 1, 1, 1, 1, 1);
    self:drawRectBorder(self.width/2 + hotbarTextW/2 + 6, height, self.width/2 - hotbarTextW/2 - 18, 1, 1, 1, 1, 1);
end

function BodySlotDisplay:onMouseDown(x, y)
    ---@diagnostic disable-next-line: redundant-return-value, return-type-mismatch
    return false
end

function BodySlotDisplay:doTooltipForItem(owner, item)
    self.tooltipOwner = owner
    self.inventoryPane:doTooltipForItem(item)
end

local function tableContains(haystack, needle)
    for _, v in pairs(haystack) do
        if v == needle then
            return true
        end
    end
    return false
end

function BodySlotDisplay:updateTooltip()
    if not self.inventoryPane.toolRender then
        return
    end

    local owner = nil
    for _, child in pairs(self.children) do
        if child:isMouseOver() or (child.controllerNode and child.controllerNode.isFocused) then
            owner = child
        end
    end

    if not owner and (self.popup:isMouseOver() or self.popup.controllerNode.isFocused) then
        owner = self.popup
    end

    if not owner or (self.tooltipOwner ~= owner and (not owner.children or not tableContains(owner.children, self.tooltipOwner))) then
        self:closeTooltip()
    end
end

function BodySlotDisplay:bringTooltipToTop()
    if self.inventoryPane.toolRender then
        self.inventoryPane.toolRender:bringToTop()
    end
end

function BodySlotDisplay:closeTooltip()
    if self.inventoryPane.toolRender then
        self.inventoryPane.toolRender:removeFromUIManager()
        self.inventoryPane.toolRender:setVisible(false)
        self.tooltipOwner = nil
    end
end

function BodySlotDisplay:getControllerNodes()
    local nodes = {}
    for _, slot in pairs(self.dynamicSlotsByBodyLocation) do
        table.insert(nodes, slot.controllerNode)
    end
    for _, slots in pairs(self.superSlotsByBodyLocation) do
        for _, slot in pairs(slots) do
            table.insert(nodes, slot.controllerNode)
        end
    end
    for _, slot in pairs(self.hotbarSlots) do
        table.insert(nodes, slot.controllerNode)
    end
    table.insert(nodes, self.primarySlot.controllerNode)
    table.insert(nodes, self.secondarySlot.controllerNode)
    return nodes
end

return BodySlotDisplay