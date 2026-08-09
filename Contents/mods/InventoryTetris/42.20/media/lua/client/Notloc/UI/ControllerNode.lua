---@diagnostic disable: redundant-parameter

---@class (partial) ISUIElement
---@field public controllerNode ControllerNode

--- ControllerNode is a class that can be injected into UI elements to provide
--- simple joypad navigation and focus handling. It can be used to quickly create complex
--- UIs that are navigable with a controller with minimal navigation logic required.
---@class ControllerNode
---@field uiElement ISUIElement
---@field processRealEvents boolean
---@field childrenNodeProvider function
---@field childrenNodeProviderArgs table
---@field selectedChild ControllerNode
---@field handleJoypadDown function
---@field handleJoypadDir function
---@field handleLoseJoypadFocus function
---@field handleGainJoypadFocus function
---@field isFocused boolean
local ControllerNode = {}
ControllerNode.FOCUS_COLOR = { r = 0.2, g = 1.0, b = 1.0, a = 0.4 }
ControllerNode.menuFocusSupression = {}

---@param uiElement ISUIElement
---@return ControllerNode
function ControllerNode:injectControllerNode(uiElement, processRealEvents)
    local o = {}
    setmetatable(o, { __index = ControllerNode })
    self.__index = self
    
    o.uiElement = uiElement
    o.processRealEvents = processRealEvents
    uiElement.controllerNode = o
    o:hookJoypadEvents()

    ---@cast o ControllerNode
    return o
end

---@param playerObj IsoPlayer
function ControllerNode:isController(playerObj)
    return playerObj:getJoypadBind() ~= -1
end

---@return ControllerNode
function ControllerNode:doSimpleFocusHighlight()
    self.og_render = self.uiElement.render
    self.uiElement.render = function(uiElement)
        self.og_render(uiElement)
        if self.isFocused then
            uiElement:drawRectBorder(0, 0, uiElement:getWidth(), uiElement:getHeight(), 0.4, self.FOCUS_COLOR.r, self.FOCUS_COLOR.g, self.FOCUS_COLOR.b)
            uiElement:drawRectBorder(1, 1, uiElement:getWidth() - 2, uiElement:getHeight() - 2, 0.4, self.FOCUS_COLOR.r, self.FOCUS_COLOR.g, self.FOCUS_COLOR.b)
        end
    end
    return self
end

--- Sets a function that will provide the valid children nodes of this controller node.
--- Useful for dynamic UIs where the children nodes change based on some condition.
---@return ControllerNode
function ControllerNode:setChildrenNodeProvider(func, ...)
    self.childrenNodeProvider = func
    self.childrenNodeProviderArgs = {...}
    return self
end

--- Sets a custom handler for the joypad button down event.
---@return ControllerNode
function ControllerNode:setJoypadDownHandler(func)
    self.handleJoypadDown = func
    return self
end

--- Sets a custom handler for the joypad direction event.
--- (Vanilla has separate handlers for each direction, this is a single handler for all directions)
---@return ControllerNode
function ControllerNode:setJoypadDirHandler(func)
    self.handleJoypadDir = func
    return self
end

---@return ControllerNode
function ControllerNode:setLoseJoypadFocusHandler(func)
    self.handleLoseJoypadFocus = func
    return self
end

---@return ControllerNode
function ControllerNode:setGainJoypadFocusHandler(func)
    self.handleGainJoypadFocus = func
    return self
end

function ControllerNode:hookJoypadEvents()
    self.og_onJoypadDown = self.uiElement.onJoypadDown
    self.uiElement.onJoypadDown = function(uiElement, button, joypadData)
        self:onJoypadDown(button, joypadData)
    end

    self.og_onJoypadDirLeft = self.uiElement.onJoypadDirLeft
    self.uiElement.onJoypadDirLeft = function(uiElement, joypadData)
        self:onJoypadDir(-1, 0, joypadData)
    end

    self.og_onJoypadDirRight = self.uiElement.onJoypadDirRight
    self.uiElement.onJoypadDirRight = function(uiElement, joypadData)
        self:onJoypadDir(1, 0, joypadData)
    end

    self.og_onJoypadDirUp = self.uiElement.onJoypadDirUp
    self.uiElement.onJoypadDirUp = function(uiElement, joypadData)
        self:onJoypadDir(0, -1, joypadData)
    end

    self.og_onJoypadDirDown = self.uiElement.onJoypadDirDown
    self.uiElement.onJoypadDirDown = function(uiElement, joypadData)
        self:onJoypadDir(0, 1, joypadData)
    end

    self.og_onLoseJoypadFocus = self.uiElement.onLoseJoypadFocus
    self.uiElement.onLoseJoypadFocus = function(uiElement, joypadData)
        self:onLoseJoypadFocus(joypadData)
    end

    self.og_onGainJoypadFocus = self.uiElement.onGainJoypadFocus
    self.uiElement.onGainJoypadFocus = function(uiElement, joypadData)
        self:onGainJoypadFocus(joypadData)
    end
end

function ControllerNode:unhookJoypadEvents()
    self.uiElement.onJoypadDown = self.og_onJoypadDown
    self.uiElement.onJoypadDirLeft = self.og_onJoypadDirLeft
    self.uiElement.onJoypadDirRight = self.og_onJoypadDirRight
    self.uiElement.onJoypadDirUp = self.og_onJoypadDirUp
    self.uiElement.onJoypadDirDown = self.og_onJoypadDirDown
    self.uiElement.onLoseJoypadFocus = self.og_onLoseJoypadFocus
    self.uiElement.onGainJoypadFocus = self.og_onGainJoypadFocus
end

-- All joypad events are handled by the controller node and will follow the same pattern as this one
function ControllerNode:onJoypadDown(button, joypadData)
    -- If we have a selected child node, we try to pass the event to it first
    if self.selectedChild and self.selectedChild:onJoypadDown(button, joypadData) then
        return true
    end

    -- If we have a custom handler for this event, we call it now
    if self.handleJoypadDown and self.handleJoypadDown(self.uiElement, button, joypadData) then
        return true
    end

    -- Lastly, we defer to the original ui element if it has joyfocus
    if self.processRealEvents then
        self.og_onJoypadDown(self.uiElement, button, joypadData)
    end
    return false
end

function ControllerNode:onJoypadDir(dx, dy, joypadData)
    if self.selectedChild and self.selectedChild:onJoypadDir(dx, dy, joypadData) then
        return true
    end

    if self.handleJoypadDir and self.handleJoypadDir(self.uiElement, dx, dy, joypadData) then
        return true
    end

    if self.childrenNodeProvider then
        local childrenNodes = self.childrenNodeProvider(unpack(self.childrenNodeProviderArgs))
        if self:tryNavigateChildren(childrenNodes, dx, dy) then
            return true
        end
    end

    if self.processRealEvents then
        if dx == -1 then
            self.og_onJoypadDirLeft(self.uiElement, joypadData)
        elseif dx == 1 then
            self.og_onJoypadDirRight(self.uiElement, joypadData)
        elseif dy == -1 then
            self.og_onJoypadDirUp(self.uiElement, joypadData)
        elseif dy == 1 then
            self.og_onJoypadDirDown(self.uiElement, joypadData)
        end
    end
    return false
end

--- Automatically navigate to the nearest child in the direction of the input.
--- This is chained up the controller node hierarchy until a node can handle the input.
--- More or less the main feature of the controller node.
function ControllerNode:tryNavigateChildren(children, dx, dy)
    if not children or #children == 0 then
        return false
    end

    local selectedChild = self.selectedChild
    if not selectedChild then
        self.selectedChild = children[1]
        self.selectedChild:onGainJoypadFocus()
        return true
    end

    local x = selectedChild.uiElement:getAbsoluteX()
    local y = selectedChild.uiElement:getAbsoluteY()

    -- Use the input direction to determine the next child to select
    local nearestChild = nil
    local nearestDistance = math.huge
    for _, child in ipairs(children) do
        if child ~= selectedChild then
            local cx = child.uiElement:getAbsoluteX()
            local cy = child.uiElement:getAbsoluteY()

            local isLeft = dx == -1 and cx < x
            local isRight = dx == 1 and cx > x
            local isUp = dy == -1 and cy < y
            local isDown = dy == 1 and cy > y
            if isLeft or isRight or isUp or isDown then
                -- A mid heuristic, but should work for most contemporary UI layouts
                ---@type number
                local distance = math.abs(cx - x) + math.abs(cy - y)

                local angle = math.atan2(cy - y, cx - x)
                local isAngleGood = false
                if isRight then
                    isAngleGood = angle > -math.pi/4 and angle < math.pi/4
                elseif isLeft then
                    isAngleGood = angle > 3*math.pi/4 or angle < -3*math.pi/4
                elseif isUp then
                    isAngleGood = angle > -3*math.pi/4 and angle < -math.pi/4
                elseif isDown then
                    isAngleGood = angle > math.pi/4 and angle < 3*math.pi/4
                end

                if isAngleGood and distance < nearestDistance then
                    nearestChild = child
                    nearestDistance = distance
                end
            end
        end
    end

    if nearestChild then
        self:setSelectedChild(nearestChild)
        return true
    end
end

function ControllerNode:setSelectedChild(childNode)
    if not self.isFocused then
        self.selectedChild = childNode
        return
    end

    if self.selectedChild then
        self.selectedChild:onLoseJoypadFocus()
    end
    self.selectedChild = childNode
    if self.selectedChild then
        self.selectedChild:onGainJoypadFocus()
    end
end

function ControllerNode:validateSelectedChild()
    if not self.selectedChild then
        return true
    end

    local children = self.childrenNodeProvider and self.childrenNodeProvider(unpack(self.childrenNodeProviderArgs)) or {}
    for _, child in ipairs(children) do
        if child == self.selectedChild then
            return true
        end
    end
    return false
end

function ControllerNode:refreshSelectedChild()
    if self:validateSelectedChild() then
        return
    end

    local children = self.childrenNodeProvider and self.childrenNodeProvider(unpack(self.childrenNodeProviderArgs)) or {}
    self.selectedChild = children[1]
    if self.selectedChild then
        self.selectedChild:onGainJoypadFocus()
    end
end

function ControllerNode:getLeafChild()
    local current = self
    while current.selectedChild do
        current = current.selectedChild
    end
    return current
end

-- No early returns here, everything needs to know when the focus is lost/gained
function ControllerNode:onLoseJoypadFocus(joypadData)
    -- We do not process the controllerNode lose focus events when opening a context menu
    if not joypadData or not ControllerNode.menuFocusSupression[joypadData.player] then
        self.isFocused = false
        if self.selectedChild then
            self.selectedChild:onLoseJoypadFocus()
        end
        if self.handleLoseJoypadFocus then 
            self.handleLoseJoypadFocus(self.uiElement, joypadData)
        end
    end

    if joypadData then
        ControllerNode.menuFocusSupression[joypadData.player] = nil
    end

    if self.processRealEvents then
        self.og_onLoseJoypadFocus(self.uiElement, joypadData)
    end
end

function ControllerNode:onGainJoypadFocus(joypadData)
    self.isFocused = true

    if self.selectedChild and not self:validateSelectedChild() then
        self.selectedChild = nil -- No onLoseJoypadFocus because it shouldn't have focus in the first place at this point
    end

    if not self.selectedChild then
        local children = self.childrenNodeProvider and self.childrenNodeProvider(unpack(self.childrenNodeProviderArgs)) or {}
        self.selectedChild = children[1]
    end

    if self.selectedChild then
        self.selectedChild:onGainJoypadFocus()
    else
        self.ensureVisible(self.uiElement)
    end
    if self.handleGainJoypadFocus then
        self.handleGainJoypadFocus(self.uiElement, joypadData)
    end
    if self.processRealEvents then
        self.og_onGainJoypadFocus(self.uiElement, joypadData)
    end
end

function ControllerNode:focusContextMenu(playerNum, menu)
    -- Prevent the controller nodes from visually losing focus when the menu opens
    ControllerNode.menuFocusSupression[playerNum] = true

    local origin = getJoypadFocus(playerNum)
    menu.origin = origin
    menu.mouseOver = 1
    setJoypadFocus(playerNum, menu)
end

-- FIX ME
function ControllerNode.ensureVisible(uiElement)
    local current = uiElement.parent
    while current do
        if current.hscroll then
            current:ensureChildIsVisible(uiElement, 50)
            return
        end
        current = current.parent
    end
end

return ControllerNode
