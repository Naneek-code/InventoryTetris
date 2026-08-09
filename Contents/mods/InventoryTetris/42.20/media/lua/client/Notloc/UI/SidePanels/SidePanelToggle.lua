require("ISUI/ISUIElement")
local TOGGLE_BG_TEX = getTexture("media/ui/Notloc/SidePanel/toggle.png")
local WHITE = {r=1, g=1, b=1, a=1}

---@class SidePanelToggle : ISUIElement
---@field sidePanel SidePanel
---@field texture Texture
---@field color table
---@field mouseOver boolean
---@field onToggleCallback fun(sidePanel: SidePanel, isOpen: boolean)
local SidePanelToggle = ISUIElement:derive("SidePanelToggle");

---@param sidePanel SidePanel
---@param onToggleCallback fun(sidePanel: SidePanel, isOpen: boolean)
---@param texture Texture
---@param color table
---@return SidePanelToggle
function SidePanelToggle:new(sidePanel, onToggleCallback, texture, color)
	---@type SidePanelToggle
    local o = ISUIElement:new(0, 0, 16, 20);
	setmetatable(o, self);
    self.__index = self;

    o.texture = texture
    o.color = color
    o.sidePanel = sidePanel
    o.onToggleCallback = onToggleCallback

    sidePanel.toggleElement = o

    return o;
end

function SidePanelToggle:onToggleSidePanel()
	local state = self.sidePanel:toggleSidePanel()
    if self.onToggleCallback then
        self.onToggleCallback(self.sidePanel, state)
    end
end

function SidePanelToggle:prerender()
    self:setStencilRect(0, 0, self.width, self.height);
    self:drawTextureScaledAspect(TOGGLE_BG_TEX, 0, 0, 16, 20, 0.9, 0.75, 0.75, 0.75);
end

function SidePanelToggle:render()
    local isOpen = not self.sidePanel.isClosed
    local col = isOpen and self.color or WHITE
    self:drawTextureScaledAspect(self.texture, 3, 3, 12, 14, 1, col.r, col.g, col.b);
    self:clearStencilRect();
end

function SidePanelToggle:onMouseDown(x, y)
    self:onToggleSidePanel()
    return true
end

function SidePanelToggle:onMouseMove(dx, dy)
    if self:isMouseOver() then
        self.backgroundColor = {r=0.3, g=0.3, b=0.3, a=0.3}
    else
        self.backgroundColor = {r=0, g=0, b=0, a=0}
    end
end

function SidePanelToggle:onMouseMoveOutside(dx, dy)
    self.backgroundColor = {r=0, g=0, b=0, a=0}
end

function SidePanelToggle:updateSize()
    local dockedAndVisible = self.sidePanel.isDocked and not self.sidePanel.isClosed
    if self.mouseOver or dockedAndVisible then
        self:expand()
    else
        self:shrink()
    end
end

function SidePanelToggle:shrink()
    self:setWidth(9)
    self:setX(7)
end

function SidePanelToggle:expand()
    self:setWidth(16)
    self:setX(0)
end

return SidePanelToggle
