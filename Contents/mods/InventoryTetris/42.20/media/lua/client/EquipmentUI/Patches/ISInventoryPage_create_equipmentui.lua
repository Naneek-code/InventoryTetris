require("InventoryAndLoot") -- I do not remember what this is

local SETTINGS = require("EquipmentUI/Settings")
local SidePanelManager = require("Notloc/UI/SidePanels/SidePanelManager")
local EquipmentPanel = require("EquipmentUI/UI/EquipmentPanel")
local EquipmentDragItemRenderer = require("EquipmentUI/UI/EquipmentDragItemRenderer")

---@class ISInventoryPage
---@field player integer
---@field notlocSidePanelManager SidePanelManager

local EQUIPMENT_UI_TOGGLE_TEX = getTexture("media/ui/EquipmentUI/equipment_icon.png")

local equipmentUiPanelsByPlayerNum = {}

---@param playerNum integer
---@return EquipmentPanel
function GetPlayerEquipmentUi(playerNum)
    return equipmentUiPanelsByPlayerNum[playerNum]
end

local og_createChildren = ISInventoryPage.createChildren
function ISInventoryPage:createChildren()
    og_createChildren(self)

    local playerNum = self.player

    if self.onCharacter and playerNum then
        local sidePanelManager = SidePanelManager.getOrCreate(self)

        self.equipmentUiPanel = EquipmentPanel:new(getText("UI_equipment_equipment"), "EquipmentUILayout", SETTINGS.EQUIPMENT_WIDTH, self.inventoryPane, playerNum);
        sidePanelManager:addSidePanel(self.equipmentUiPanel, EQUIPMENT_UI_TOGGLE_TEX, {r=1, g=0.8, b=0.5, a=1}, "equipment_toggle_window")

        equipmentUiPanelsByPlayerNum[playerNum] = self.equipmentUiPanel

        if not SETTINGS.InventoryTetris then
            local dragRenderer = EquipmentDragItemRenderer:new(self.inventoryPane, playerNum)
            dragRenderer:initialise()
            dragRenderer:addToUIManager()

            local og_removeFromUIManager = self.removeFromUIManager
            self.removeFromUIManager = function(self)
                og_removeFromUIManager(self)
                dragRenderer:removeFromUIManager()
            end
        end
    end
end
