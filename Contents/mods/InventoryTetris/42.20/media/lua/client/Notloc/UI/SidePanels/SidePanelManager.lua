require ("ISUI/ISUIElement")
local SidePanelToggle = require("Notloc/UI/SidePanels/SidePanelToggle")

local MANAGER_OFFSET_Y = 4
local TOGGLE_WIDTH = 16
local TOGGLE_HEIGHT_WITH_PADDING = 24


---@class SidePanelData
---@field public sidePanel SidePanel
---@field public toggle SidePanelToggle
---@field public keybind string|nil
---@field public isVisible boolean

---@class SidePanelManager : ISUIElement
---@field public inventoryPage ISInventoryPage
---@field public playerNum integer
---@field public sidePanelData SidePanelData[]
local SidePanelManager = ISUIElement:derive("SidePanelManager");

---@param inventoryPage ISInventoryPage
---@param playerNum integer
---@return SidePanelManager
function SidePanelManager:new(inventoryPage, playerNum)
    ---@type SidePanelManager
    local o = ISUIElement:new(0, 0, 0, 0);
	setmetatable(o, self);
    self.__index = self;

    o.inventoryPage = inventoryPage
    o.playerNum = playerNum

    o.sidePanelData = {}

    Events.OnKeyPressed.Add(function(key)
        for _, data in ipairs(o.sidePanelData) do
            if data.keybind and key == getCore():getKey(data.keybind) then
                data.toggle:onToggleSidePanel()
            end
        end
    end);

    local og_removeFromUIManager = inventoryPage.removeFromUIManager
    inventoryPage.removeFromUIManager = function()
        og_removeFromUIManager(inventoryPage)
        o:removeFromUIManager()
    end

    local og_bringToTop = inventoryPage.bringToTop
    inventoryPage.bringToTop = function()
        og_bringToTop(inventoryPage)
        o:bringToTop()
    end

    return o
end

---@param inventoryPage ISInventoryPage
---@return SidePanelManager
function SidePanelManager.getOrCreate(inventoryPage)
    if not inventoryPage.notlocSidePanelManager then
        inventoryPage.notlocSidePanelManager = SidePanelManager:new(inventoryPage, inventoryPage.player)
        inventoryPage.notlocSidePanelManager:initialise()
        inventoryPage.notlocSidePanelManager:addToUIManager()
    end
    return inventoryPage.notlocSidePanelManager
end

function SidePanelManager:removeFromUIManager()
    for _, pair in ipairs(self.sidePanelData) do
        pair.sidePanel:removeFromUIManager()
    end
    ISUIElement.removeFromUIManager(self)
end

function SidePanelManager:addSidePanel(sidePanel, toggleTexture, toggleColor, keybind)
    sidePanel:initialise()
    sidePanel:addToUIManager()

    local toggleCallback = function (sidePanel, state)
        self:onToggleSidePanel(sidePanel, state)
    end

    local toggle = SidePanelToggle:new(sidePanel, toggleCallback, toggleTexture, toggleColor)
    self:addChild(toggle)
    toggle:shrink()

    local data = {}
    data.sidePanel = sidePanel
    data.toggle = toggle
    data.keybind = keybind

    table.insert(self.sidePanelData, data)

    self:sortToggles()
    self:ensureOnlyOneDockedPanelOpen()

    self:bringToTop()
end

function SidePanelManager:sortToggles()
    for i, pair in ipairs(self.sidePanelData) do
        local toggle = pair.toggle
        toggle:setY((i-1) * TOGGLE_HEIGHT_WITH_PADDING)
    end
end

function SidePanelManager:onToggleSidePanel(targetPanel, state)
    if state then
        self:ensureOnlyOneDockedPanelOpen(targetPanel)
    end

    for i, pair in ipairs(self.sidePanelData) do
        pair.toggle:updateSize()
    end
end

function SidePanelManager:ensureOnlyOneDockedPanelOpen(targetPanel)
    local openPanel = (targetPanel and targetPanel.isDocked) and targetPanel or nil
    for i, pair in ipairs(self.sidePanelData) do
        local sidePanel = pair.sidePanel
        if sidePanel.isDocked and not sidePanel.isClosed then
            if openPanel and openPanel ~= sidePanel then
                sidePanel:closeSidePanel()
            else
                openPanel = sidePanel
            end
        end
    end
end

function SidePanelManager:updateVisibilityBasedOnInv(isInvVisible)
    for _, pair in ipairs(self.sidePanelData) do
        local toggle = pair.toggle
        toggle:setVisible(isInvVisible)

        if not pair.sidePanel.isClosed then
            pair.sidePanel:onInventoryVisibilityChanged(isInvVisible);
        end
    end
end

function SidePanelManager:prerender()
    local isInvVisible = self.inventoryPage:isVisible() and (self.inventoryPage.pin or not self.inventoryPage.isCollapsed)
    if self._lastInvVisible == nil or isInvVisible ~= self._lastInvVisible then
        self._lastInvVisible = isInvVisible
        self:updateVisibilityBasedOnInv(isInvVisible)
    end

    if isInvVisible then
        self:updateHoveredToggle()
    end

    local titleBarHeight = self.inventoryPage:titleBarHeight()

    self:setX(self.inventoryPage:getX() - TOGGLE_WIDTH)
    self:setY(titleBarHeight + self.inventoryPage:getY() + MANAGER_OFFSET_Y)
    self:setHeight(self.inventoryPage:getHeight() - titleBarHeight - MANAGER_OFFSET_Y)
end

function SidePanelManager:updateHoveredToggle()
    if self._hoveredIndex then
        local data = self.sidePanelData[self._hoveredIndex]
        if data then
            data.toggle.mouseOver = false
            data.toggle:updateSize()
        end
    end

    self:setWidth(0) -- Prevents the manager from capturing mouse events

    self._hoveredIndex = self:determineIndexUnderMouse()
    if self._hoveredIndex then
        local data = self.sidePanelData[self._hoveredIndex]
        if data then
            data.toggle.mouseOver = true
            data.toggle:updateSize()
        end

        self:setWidth(TOGGLE_WIDTH) -- Allows the manager to capture mouse events
    end
end

function SidePanelManager:determineIndexUnderMouse()
    local mouseX = self:getMouseX()
    local mouseY = self:getMouseY()

    if mouseX < -TOGGLE_WIDTH/2 or mouseX > TOGGLE_WIDTH + TOGGLE_WIDTH/2 then
        return nil
    end

    local index = math.floor((mouseY + 2) / TOGGLE_HEIGHT_WITH_PADDING) + 1
    if index > #self.sidePanelData or index < 1 then
        return nil
    end

    return index
end

return SidePanelManager
