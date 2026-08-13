-- Smangsty: Opens key rings through a vanilla-backed semantic inventory popup.
local TetrisItemData = require("InventoryTetris/Data/TetrisItemData")
local OPT = require("InventoryTetris/Settings")
local KeyRingSupport = require("InventoryTetris/KeyRingSupport")

local KeyRingMenu = {}

function KeyRingMenu.isKeyRing(item)
    return KeyRingSupport.isItem(item)
end

local function getAnchor(gridUi, gridStack, item)
    if not gridUi or not gridStack then return nil, nil end

    local stride = OPT.CELL_SIZE - 1
    local width = TetrisItemData.tryGetItemSize(item, gridStack.isRotated) or 1
    local x = gridUi:getAbsoluteX() + gridStack.x * stride + width * stride + 1
    local y = gridUi:getAbsoluteY() + gridStack.y * stride
    return x, y
end

local function findInContainerUi(containerUi, item)
    if not containerUi or not containerUi.gridUis then return nil end

    for _, gridUis in pairs(containerUi.gridUis) do
        for _, gridUi in pairs(gridUis) do
            local gridStack = gridUi.grid:findStackByItem(item)
            if gridStack then
                return gridUi, gridStack
            end
        end
    end
end

local function findInWindow(window, item)
    if not window then return nil end

    local gridUi, gridStack = findInContainerUi(window.gridContainerUi, item)
    if gridUi then return gridUi, gridStack end

    for _, child in ipairs(window.childWindows or {}) do
        gridUi, gridStack = findInWindow(child, item)
        if gridUi then return gridUi, gridStack end
    end
end

local function findInPane(pane, item)
    if not pane then return nil end

    for _, containerUi in ipairs(pane.gridContainerUis or {}) do
        local gridUi, gridStack = findInContainerUi(containerUi, item)
        if gridUi then
            return pane.tetrisWindowManager, gridUi, gridStack
        end
    end

    local manager = pane.tetrisWindowManager
    if manager then
        for _, window in ipairs(manager.childWindows or {}) do
            local gridUi, gridStack = findInWindow(window, item)
            if gridUi then
                return manager, gridUi, gridStack
            end
        end
    end
end

local function findSource(item, playerNum)
    local inventoryPage = getPlayerInventory(playerNum)
    local manager, gridUi, gridStack = findInPane(inventoryPage and inventoryPage.inventoryPane, item)
    if manager then return manager, gridUi, gridStack end

    local lootPage = getPlayerLoot(playerNum)
    return findInPane(lootPage and lootPage.inventoryPane, item)
end

function KeyRingMenu.open(keyRing, playerNum, sourceGridUi, gridStack)
    if not KeyRingMenu.isKeyRing(keyRing) then return end

    local manager = sourceGridUi and sourceGridUi.inventoryPane and sourceGridUi.inventoryPane.tetrisWindowManager or nil
    if not manager then
        manager, sourceGridUi, gridStack = findSource(keyRing, playerNum)
    end
    if not manager then return end

    local x, y = getAnchor(sourceGridUi, gridStack, keyRing)
    return manager:openKeyRingPopup(keyRing, x, y)
end

return KeyRingMenu
