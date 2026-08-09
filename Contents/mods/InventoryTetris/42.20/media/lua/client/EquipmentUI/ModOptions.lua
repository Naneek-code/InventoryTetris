---@diagnostic disable: need-check-nil, param-type-mismatch

local EQUIPMENT_UI_SETTINGS = require ("EquipmentUI/Settings")

-- Smangsty: Keep the legacy option ID so existing Equipment UI settings persist.
local EquipmentUIModOptions = PZAPI.ModOptions:create("EQUIPMENT_UI", getText("UI_optionscreen_binding_EquipmentUI"))

local key = "EQUIPMENT_UI_SCALE_INDEX"
local uiName = getText("UI_equipment_options_scale")

local hideEquippedItemsTickBox = EquipmentUIModOptions:addTickBox("HIDE_EQUIPPED_ITEMS", getText("UI_equipment_options_hide_equipped_items"), false, "tooltip")

local uiScaleDropdown = EquipmentUIModOptions:addComboBox(key, uiName, "tooltip")
uiScaleDropdown:addItem("0.5x", false)
uiScaleDropdown:addItem("1x", true)
uiScaleDropdown:addItem("1.5x", false)
uiScaleDropdown:addItem("2x", false)
uiScaleDropdown:addItem("2.5x", false)
uiScaleDropdown:addItem("3x", false)
uiScaleDropdown:addItem("3.5x", false)
uiScaleDropdown:addItem("4x", false)

local wookiePresent = getActivatedMods():contains("WookieeGamepadSupport") or getActivatedMods():contains("\\WookieeGamepadSupport")
local toggleUiControllerBindDropdown = EquipmentUIModOptions:addComboBox("TOGGLE_UI_CONTROLLER_BIND_INDEX", getText("UI_equipment_options_toggle_ui_controller_bind"), "tooltip")
toggleUiControllerBindDropdown:addItem(" A  /  X ", false)
toggleUiControllerBindDropdown:addItem(" B  /  O ", false)
toggleUiControllerBindDropdown:addItem(" X  /  [ ] ", false)
toggleUiControllerBindDropdown:addItem(" Y  /  /\\ ", false)
toggleUiControllerBindDropdown:addItem(" LB /  L1 ", false)
toggleUiControllerBindDropdown:addItem(" RB /  R1 ", false)
toggleUiControllerBindDropdown:addItem("  < /  - ", not wookiePresent)
toggleUiControllerBindDropdown:addItem("  > /  + ", false)
toggleUiControllerBindDropdown:addItem(" LS /  L3 ", wookiePresent)
toggleUiControllerBindDropdown:addItem(" RS /  R3 ", false)
-- Use left and right triangles as iconography for the start and select buttons

function EquipmentUIModOptions:apply()
    local scale = self:getOption("EQUIPMENT_UI_SCALE_INDEX"):getValue() * 0.5 -- Multiply by 0.5 to get the actual scale, only works due to the dropdown's values being 0.5x, 1x, 1.5x, etc.
    EQUIPMENT_UI_SETTINGS:applyScale(scale)

    local hideEquippedItems = self:getOption("HIDE_EQUIPPED_ITEMS"):getValue()
    EQUIPMENT_UI_SETTINGS:applyHideEquippedItems(hideEquippedItems)

    local toggleUiControllerBindIndex = self:getOption("TOGGLE_UI_CONTROLLER_BIND_INDEX"):getValue()
    EQUIPMENT_UI_SETTINGS:applyToggleUiControllerBind(toggleUiControllerBindIndex)
end

-- I don't remember why I had to do it this way
local og_load = PZAPI.ModOptions.load
function PZAPI.ModOptions:load()
    og_load(self)
    pcall(function ()
        EquipmentUIModOptions:apply()
    end)
end

return EquipmentUIModOptions
