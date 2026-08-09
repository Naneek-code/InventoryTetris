local Settings = require("EquipmentUI/Settings")
local ControllerNode = require("Notloc/UI/ControllerNode")

local MAX_COLUMN = 3

---@class SuperSlotPopup : ISUIElement
---@field public visibleSlots number
---@field public equipmentSlots EquipmentSlot[]
---@field public controllerNode ControllerNode
local EquipmentSuperSlotPopup = ISUIElement:derive("EquipmentSuperSlotPopup")

function EquipmentSuperSlotPopup:createChildren()
    ControllerNode
        :injectControllerNode(self)
        :setChildrenNodeProvider(self.getControllerNodes, self)
end

function EquipmentSuperSlotPopup:getControllerNodes()
    local nodes = {}
    if not self.equipmentSlots or not self:isVisible() then
        return nodes
    end

    for _, slot in ipairs(self.equipmentSlots) do
        if slot.item then
            table.insert(nodes, slot.controllerNode)
        end
    end
    return nodes
end

---@param equipmentSlots EquipmentSlot[]
function EquipmentSuperSlotPopup:applySlots(equipmentSlots)
    self.equipmentSlots = equipmentSlots;
    self:_layoutSlots()
end

function EquipmentSuperSlotPopup:_layoutSlots()
    self:clearChildren()

    self.visibleSlots = 0;
    local column = 0;
    local row = 0;

    local scale = Settings.SCALE

    for _, slot in ipairs(self.equipmentSlots) do
        if slot.item then
            self:addChild(slot);
            slot:setVisible(true);
            slot:setX((column * Settings.SLOT_SIZE) + scale*2 - column);
            slot:setY((row * Settings.SLOT_SIZE) + scale*2 - row);

            self.visibleSlots = self.visibleSlots + 1;
            column = column + 1;

            if column >= 3 then
                column = 0;
                row = row + 1;
            end
        else
            slot:setVisible(false);
        end
    end
end

function EquipmentSuperSlotPopup:prerender()
    -- Resize based on visible slots
    local count = self.visibleSlots;
    local countX = count > MAX_COLUMN and MAX_COLUMN or count;
    local countY = count > MAX_COLUMN and math.ceil(count / MAX_COLUMN) or 1;
    self:setWidth(countX * Settings.SLOT_SIZE + 4 - countX);
    self:setHeight(Settings.SUPER_SLOT_SIZE + Settings.SUPER_SLOT_VERTICAL_OFFSET + Settings.SLOT_SIZE * countY + 4 - countY);

    -- Draw background for sub-slots
    local slotCount = self.visibleSlots
    local xCount = math.min(slotCount, 3);
    local yCount = math.ceil(slotCount / 3);
    local width = Settings.SLOT_SIZE * xCount + Settings.SUB_SLOT_THING - xCount;
    local height = Settings.SLOT_SIZE * yCount + Settings.SUB_SLOT_THING - yCount;
    self:drawRect(0, 0, width, height, 0.9, 0, 0, 0);
    self:drawRectBorder(0, 0, width, height, 0.8, 1, 1, 1);
end

return EquipmentSuperSlotPopup