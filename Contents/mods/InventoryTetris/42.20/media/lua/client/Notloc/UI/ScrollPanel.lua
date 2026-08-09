require ("ISUI/ISUIElement")

---@class ScrollPanel : ISUIElement
---@field public contentHeightGetter fun(self: ScrollPanel): number
---@field public sensitivity number
---@field private contentPanel ISUIElement
---@field private lastScrollX number
---@field private lastScrollY number
---@field private vscroll ISScrollBar
local ScrollPanel = ISUIElement:derive("ScrollPanel");

---@param x number
---@param y number
---@param width number
---@param height number
---@return ScrollPanel
function ScrollPanel:new(x, y, width, height)
    ---@type ScrollPanel
    local o = ISUIElement:new(x, y, width, height);
    setmetatable(o, self);
    self.__index = self;
    o.sensitivity = 24
    return o;
end

local function customOnMouseUp(self, x, y)
    if self.parent and self.parent.onMouseUpOutside then
        self.parent:onMouseUpOutside(x, y)
    end
end

function ScrollPanel:createChildren()
    ISUIElement.createChildren(self);
    self:addScrollBars();

    self.contentPanel = ISUIElement:new(0, 0, self.width, self.height);
    self.contentPanel.onMouseUp = customOnMouseUp
    self.contentPanel.prerender = function() self:setStencilRect(0, 0, self.width, self.height) end
    self.contentPanel.render = function() self:clearStencilRect() end
    self:addChild(self.contentPanel);
end

function ScrollPanel:prerender()
    local height = self.contentHeightGetter and self.contentHeightGetter(self) or 100
    if height ~= self.lastContentHeight then
        self.vscroll:setHeight(self.height);
        self:setScrollHeight(height);
        self:updateScrollbars();
        self.lastContentHeight = height
    end

    self:updateContentScrolling();

    if self:isVScrollBarVisible() then
        self.contentPanel:setWidth(self.width - self.vscroll.width);
    else
        self.contentPanel:setWidth(self.width);
    end
    self.contentPanel:setHeight(self.height);
end

function ScrollPanel:updateContentScrolling()
    local lastX = self.lastScrollX or 0
    local lastY = self.lastScrollY or 0
    local scrollX = self:getXScroll()
    local scrollY = self:getYScroll()

    if lastX == scrollX and lastY == scrollY then
        return
    end

    local children = self.contentPanel:getChildren()
    for _, child in pairs(children) do
        child:setX(child:getX() - lastX + scrollX)
        child:setY(child:getY() - lastY + scrollY)
    end

    self.lastScrollX = scrollX
    self.lastScrollY = scrollY
end

function ScrollPanel:addScrollChild(child)
    self.contentPanel:addChild(child);
end

function ScrollPanel:removeScrollChild(child)
    self.contentPanel:removeChild(child);
end

function ScrollPanel:onMouseUp(x, y)
    ISUIElement.onMouseUp(self, x, y);
    if self.parent and self.parent.onMouseUpOutside then
        self.parent:onMouseUpOutside(x, y)
    end
end

function ScrollPanel:onMouseWheel(delta)
    local scrollDelta = delta * self.sensitivity
    self:setYScroll(self:getYScroll() - scrollDelta)
    return true
end

return ScrollPanel;