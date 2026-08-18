-- Smangsty: Require the B42 inventory page directly; the legacy InventoryAndLoot alias is not portable to Linux.
require("ISUI/ISInventoryPage")

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

        local dragRenderer = nil
        if not SETTINGS.InventoryTetris then
            dragRenderer = EquipmentDragItemRenderer:new(self.inventoryPane, playerNum)
            dragRenderer:initialise()
            dragRenderer:addToUIManager()
        end

        local og_removeFromUIManager = self.removeFromUIManager
        self.removeFromUIManager = function(page)
            local equipmentPanel = page.equipmentUiPanel
            if equipmentPanel then
                -- Smangsty: Rebuilt inventory pages should not leave immortal Equipment UI callbacks behind.
                SETTINGS:removeScaleChangedListeners(equipmentPanel)
                if equipmentUiPanelsByPlayerNum[playerNum] == equipmentPanel then
                    equipmentUiPanelsByPlayerNum[playerNum] = nil
                end
            end

            og_removeFromUIManager(page)
            if dragRenderer then
                dragRenderer:removeFromUIManager()
            end
        end
    end
end
