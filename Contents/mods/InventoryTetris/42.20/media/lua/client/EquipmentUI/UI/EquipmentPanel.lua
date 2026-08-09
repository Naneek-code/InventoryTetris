local Settings = require ("EquipmentUI/Settings")
local SidePanel = require("Notloc/UI/SidePanels/SidePanel")
local ScrollPanel = require("Notloc/UI/ScrollPanel")
local ControllerNode = require("Notloc/UI/ControllerNode")
local BodySlotDisplay = require("EquipmentUI/UI/BodySlotDisplay")
local SuperSlotPopup = require("EquipmentUI/UI/Slots/EquipmentSuperSlotPopup")
local EquipmentUI = require("EquipmentUI/EquipmentUI")

local VERSION = "v"..EquipmentUI.version.major.."."..EquipmentUI.version.minor.."."..EquipmentUI.version.revision

local ITEMS_VISIBLE_TEX = getTexture("media/ui/equipmentui/ItemsVisible.png")
local ITEMS_HIDDEN_TEX = getTexture("media/ui/equipmentui/ItemsHidden.png")

---@class EquipmentPanel : SidePanel
---@field public clothingPanel BodySlotDisplay
---@field public inventoryPane ISInventoryPane
---@field public playerNum integer
---@field public popup SuperSlotPopup
---@field public controllerNode ControllerNode
local EquipmentPanel = SidePanel:derive("EquipmentPanel");

function EquipmentPanel:createChildren()
    SidePanel.createChildren(self);

    local upperBarHeight = SidePanel.UPPER_BAR_HEIGHT
    local lowerBarHeight = SidePanel.LOWER_BAR_HEIGHT

    local popup = SuperSlotPopup:new(0,0,0,0)
    popup:setVisible(false)
    popup:addToUIManager()
    self.popup = popup

    self.scrollPanel = ScrollPanel:new(0, upperBarHeight, self.width, self.height - upperBarHeight - lowerBarHeight);
    self:addChild(self.scrollPanel);

    self.clothingPanel = BodySlotDisplay:new(0, 0, self.width, 0, self.inventoryPane, self.playerNum, self.popup);
    self.scrollPanel:addScrollChild(self.clothingPanel);

    self.scrollPanel.contentHeightGetter = function()
        return self.clothingPanel.height
    end

    if not Settings.InventoryTetris then
        self.toggleHideItemsButtons = ISButton:new(self.width - 20, self.height-15, 16, 16, "", self, self.onToggleHiddenItems);
        self.toggleHideItemsButtons:initialise()
        self.toggleHideItemsButtons.anchorBottom = true
        self.toggleHideItemsButtons.anchorTop = false
        self.toggleHideItemsButtons.anchorRight = true
        self.toggleHideItemsButtons.anchorLeft = false
        self.toggleHideItemsButtons.borderColor = {r=0, g=0, b=0, a=0};
        self.toggleHideItemsButtons.backgroundColor = {r=0, g=0, b=0, a=0};
        self.toggleHideItemsButtons:setImage(Settings.HIDE_EQUIPPED_ITEMS and ITEMS_HIDDEN_TEX or ITEMS_VISIBLE_TEX)
        self:addChild(self.toggleHideItemsButtons);

        -- This callback fires when any setting changes, so this works
        table.insert(Settings.OnScaleChanged, function(_scale)
            self.toggleHideItemsButtons:setImage(Settings.HIDE_EQUIPPED_ITEMS and ITEMS_HIDDEN_TEX or ITEMS_VISIBLE_TEX);
        end)
    end

    ControllerNode
        :injectControllerNode(self, true)
        :setChildrenNodeProvider(self.clothingPanel.getControllerNodes, self.clothingPanel)

    self.equipmentUi = self.clothingPanel -- Legacy naming
end

function EquipmentPanel:prerender()
    SidePanel.prerender(self);

    local upperBarHeight = SidePanel.UPPER_BAR_HEIGHT
    local lowerBarHeight = SidePanel.LOWER_BAR_HEIGHT
    self.scrollPanel:setHeight(self.height - upperBarHeight - lowerBarHeight);
    self.scrollPanel:setWidth(self.width);

    local hasScrollBar = self.scrollPanel:isVScrollBarVisible()

    local xOffset = hasScrollBar and 12 or 0

    self:setWidth(Settings.EQUIPMENT_WIDTH + xOffset)
    
    self:drawText(VERSION, 4, self.height - 28, 1, 1, 1, 0.25, UIFont.Small);
end

function EquipmentPanel:render()
    SidePanel.render(self)
end

function EquipmentPanel:updateTooltip()
    self.clothingPanel:updateTooltip();
end

function EquipmentPanel:onToggleHiddenItems()
    Settings.HIDE_EQUIPPED_ITEMS = not Settings.HIDE_EQUIPPED_ITEMS
    self.toggleHideItemsButtons:setImage(Settings.HIDE_EQUIPPED_ITEMS and ITEMS_HIDDEN_TEX or ITEMS_VISIBLE_TEX);
end

-- Controller Window focus handling
function EquipmentPanel:onJoypadDirLeft(joypadData)
    setJoypadFocus(self.playerNum, getPlayerLoot(self.playerNum));
end

function EquipmentPanel:onJoypadDirRight(joypadData)
    setJoypadFocus(self.playerNum, getPlayerInventory(self.playerNum));
end

function EquipmentPanel:onJoypadDown(button)

    -- Makes the ui close
    if button == Joypad.YButton then
        setJoypadFocus(self.playerNum, nil);
        local inv = getPlayerInventory(self.playerNum)
        if inv then
            ---@diagnostic disable-next-line: param-type-mismatch
            inv:onLoseJoypadFocus(nil)
        end
    end

    if button == Settings.TOGGLE_UI_CONTROLLER_BIND then
        local inv = getPlayerInventory(self.playerNum)
        if not inv then return end

        inv:toggleEquipmentUIForController();
        setJoypadFocus(self.playerNum, inv);
    end

    if Settings.InventoryTetris then
        if button == Joypad.LBumper then
            setJoypadFocus(self.playerNum, getPlayerInventory(self.playerNum));
        end
        if button == Joypad.RBumper then
            setJoypadFocus(self.playerNum, getPlayerLoot(self.playerNum));
        end
    end
end

return EquipmentPanel
