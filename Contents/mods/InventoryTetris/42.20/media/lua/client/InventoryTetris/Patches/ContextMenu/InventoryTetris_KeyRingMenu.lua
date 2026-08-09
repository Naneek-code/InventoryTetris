-- Smangsty: Adds the maintained key-ring popup to inventory context menus.
local KeyRingMenu = require("InventoryTetris/UI/KeyRingMenu")

local function findSelectedKeyRing(items)
    for _, entry in ipairs(items) do
        if instanceof(entry, "InventoryItem") then
            if KeyRingMenu.isKeyRing(entry) then
                return entry
            end
        elseif entry.items then
            for _, item in ipairs(entry.items) do
                if KeyRingMenu.isKeyRing(item) then
                    return item
                end
            end
        end
    end

    return nil
end

local function addKeyRingContextOption(playerNum, context, items)
    local keyRing = findSelectedKeyRing(items)
    if not keyRing then return end

    local label = getTextOrNull("UI_tetris_keyring_open") or "Open Key Ring"
    context:addOption(label, keyRing, KeyRingMenu.open, playerNum)
end

Events.OnFillInventoryObjectContextMenu.Add(addKeyRingContextOption)
