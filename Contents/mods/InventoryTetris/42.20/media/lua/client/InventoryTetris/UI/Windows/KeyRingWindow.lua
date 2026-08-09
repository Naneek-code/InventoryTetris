-- Smangsty: Presents key-ring contents with vanilla inventory behavior outside the Tetris grid.
require("ISUI/ISCollapsableWindow")
require("ISUI/ISInventoryPane")

local KeyRingWindow = ISCollapsableWindow:derive("InventoryTetrisKeyRingWindow")

function KeyRingWindow:new(x, y, keyRing, playerNum)
    local inventory = keyRing and keyRing:getInventory() or nil
    if not inventory then return nil end

    local playerObj = getSpecificPlayer(playerNum)
    local itemCount = inventory:getItems():size()
    local width = 300
    local height = math.min(260, math.max(105, 52 + itemCount * 24))

    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.keyRing = keyRing
    o.inventory = inventory
    o.playerNum = playerNum
    o.player = playerNum
    o.isKeyRingPopup = true
    o.closeWithParent = true
    o.onCharacter = playerObj and inventory:isInCharacterInventory(playerObj) or false
    o.title = keyRing:getName(playerObj)
    o.isCollapsed = false
    o.pin = true
    o.childWindows = {}
    o.render3DItems = {}
    o.selectedSqDrop = nil

    return o
end

function KeyRingWindow:initialise()
    ISCollapsableWindow.initialise(self)
end

function KeyRingWindow:isCycleContainerKeyDown()
    return false
end

function KeyRingWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    self:setResizable(false)

    local titleHeight = self:titleBarHeight()
    local pane = ISInventoryPane:new(0, titleHeight, self.width, self.height - titleHeight, self.inventory, 1.0)
    pane.player = self.playerNum
    pane.inventoryPage = self
    -- Smangsty: Keep key-ring contents on vanilla list behavior while removing redundant headers.
    pane.tetrisVanillaPane = true
    pane.tetrisHideHeaders = true
    pane.tetrisSplitKeysById = true
    pane:initialise()
    pane:setMode("details")

    self:addChild(pane)
    self.inventoryPane = pane
    pane:refreshContainer()
end

function KeyRingWindow:prerender()
    if not self.keyRing or not self.keyRing:getContainer() then
        self:close()
        return
    end

    ISCollapsableWindow.prerender(self)
end

return KeyRingWindow
