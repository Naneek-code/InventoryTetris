local _SidePanelToggle = require("Notloc/UI/SidePanels/SidePanelToggle")
local DragAndDrop = require("EquipmentUI/DragAndDrop")

local POPOUT_TEX = getTexture("media/ui/Notloc/SidePanel/popout.png")
local ATTACH_TEX = getTexture("media/ui/Notloc/SidePanel/attach.png")
local CLOSE_TEX = getTexture("media/ui/Notloc/SidePanel/close.png")

local COLLAPSE_TEX = getTexture("media/ui/Panel_Icon_Collapse.png");
local PIN_TEX = getTexture("media/ui/Panel_Icon_Pin.png");

-- Vanilla constants
local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local BUTTON_HGT = FONT_HGT_SMALL + 6

local function getLayoutModData(layoutId, playerObj, isController)
    local postfix = isController and "_controller" or ""
    local modData = playerObj:getModData()[layoutId..postfix];
    if not modData then
        modData = {
            isDocked = true,
            isClosed = false
        };
        playerObj:getModData()[layoutId..postfix] = modData;
    end
    return modData;
end

---@class SidePanel : ISPanel
---@field public title string
---@field public layoutId string
---@field public inventoryPane ISInventoryPane
---@field public inventoryPage ISInventoryPage
---@field public playerNum integer
---@field public char IsoPlayer
---@field public isDocked boolean
---@field public isClosed boolean
---@field public isCollapsed boolean
---@field public collapseCounter number
---@field public pin boolean
---@field public defaultWidth number
---@field public toggleElement SidePanelToggle
---@field public popoutButton ISButton
---@field public closeButton ISButton
---@field public pinButton ISButton
---@field public collapseButton ISButton
---@field public titlebarbkg Texture
local SidePanel = ISPanel:derive("SidePanel");

local fontHeight = getTextManager():getFontHeight(UIFont.Small)
SidePanel.UPPER_BAR_HEIGHT = math.max(16, fontHeight + 1)
SidePanel.LOWER_BAR_HEIGHT = BUTTON_HGT/2 + 2

---@param title string
---@param layoutId string
---@param width number
---@param inventoryPane ISInventoryPane
---@param playerNum integer
function SidePanel:new(title, layoutId, width, inventoryPane, playerNum)
	---@cast inventoryPane.parent ISInventoryPage
    local inventoryPage = inventoryPane.parent

    ---@type SidePanel
    local o = ISPanel:new(0, 0, width, inventoryPage:getHeight());
	setmetatable(o, self);
    self.__index = self;

    o.title = title;
    o.layoutId = layoutId;
    o.inventoryPane = inventoryPane
    o.inventoryPage = inventoryPage
    o.playerNum = playerNum

	o.char = getSpecificPlayer(playerNum);
	o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
	o.backgroundColor = {r=0, g=0, b=0, a=0.8};

    o.titlebarbkg = getTexture("media/ui/Panel_TitleBar.png");

    local modData = getLayoutModData(layoutId, o.char, o:isController());
    o.isDocked = modData.isDocked;
    o.isClosed = modData.isClosed;

    local playerObj = getSpecificPlayer(playerNum)
    local isController = playerObj:getJoypadBind() ~= -1
    o.isClosed = isController or o.isClosed

    o.isCollapsed = false;
    o.collapseCounter = 0;
    o.pin = true;

    o.defaultWidth = width;

    return o;
end

function SidePanel:isController()
    return JoypadState.players[self.playerNum + 1] and JoypadState.players[self.playerNum + 1].isActive
end

function SidePanel:initialise()
    ISPanel.initialise(self)

    -- Do any layout resizing now to avoid weird issues with anchors on first frame size changes
    if self.playerNum == 0 then
        local postfix = self:isController() and "_controller" or ""
		ISLayoutManager.RegisterWindow(self.layoutId .. postfix, SidePanel, self)
	end
end

function SidePanel:createChildren()
    ISPanel.createChildren(self);

    local titleBarHeight = getTextManager():getFontHeight(UIFont.Small)

    self.popoutButton = ISButton:new(self:getWidth() - 20, 1, 16, 16, "", self, self.onPopoutOrAttach);
    self.popoutButton.internal = "POP";
    self.popoutButton.borderColor = {r=0, g=0, b=0, a=0};
    self.popoutButton.backgroundColor = {r=0, g=0, b=0, a=0};
    self.popoutButton:initialise();
    self.popoutButton:instantiate();
    self.popoutButton:setImage(self.isDocked and POPOUT_TEX or ATTACH_TEX);
    self.popoutButton:setAnchorRight(true);
    self.popoutButton:setAnchorLeft(false);
    self:addChild(self.popoutButton);

    self.closeButton = ISButton:new(2, 1, 20, titleBarHeight - 2, "", self, self.onClose);
    self.closeButton.internal = "CLOSE";
    self.closeButton.borderColor = {r=0, g=0, b=0, a=0};
    self.closeButton.backgroundColor = {r=0, g=0, b=0, a=0};
    self.closeButton:initialise();
    self.closeButton:instantiate();
    self.closeButton:setImage(CLOSE_TEX);
    self:addChild(self.closeButton);
    self.closeButton:setVisible(not self.isDocked);

    self.pinButton = ISButton:new(self.width - 42, 0, titleBarHeight, titleBarHeight, "", self, SidePanel.doPin);
    self.pinButton.anchorRight = true;
    self.pinButton.anchorLeft = false;
    self.pinButton:initialise();
    self.pinButton.borderColor.a = 0;
    self.pinButton.backgroundColor.a = 0;
    self.pinButton.backgroundColorMouseOver.a = 0;
    self.pinButton:setImage(PIN_TEX);
    self:addChild(self.pinButton);
    self.pinButton:setVisible(false);

    self.collapseButton = ISButton:new(self.pinButton:getX(), 0, titleBarHeight, titleBarHeight, "", self, SidePanel.doCollapse);
    self.collapseButton.anchorRight = true;
    self.collapseButton.anchorLeft = false;
    self.collapseButton:initialise();
    self.collapseButton.borderColor.a = 0;
    self.collapseButton.backgroundColor.a = 0;
    self.collapseButton.backgroundColorMouseOver.a = 0;
    self.collapseButton:setImage(COLLAPSE_TEX);
    self:addChild(self.collapseButton);
    self.collapseButton:setVisible(false);
end

function SidePanel:prerender()
    if self.isDocked and not self.inventoryPage:isVisible() then
        self:setVisible(false);
        return;
    end

    if self.pin or DragAndDrop.isDragging()then
        self:uncollapseWindow();
    end

    local invPage = self.inventoryPane.parent
    if invPage and self.isDocked then
        self:setHeight(invPage.height);
        self:setX(invPage:getX() - self.width + 1);
        self:setY(invPage:getY());
    end

    if not self.isCollapsed then
	    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b);
		self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b);
    end

    local upperBarHeight = SidePanel.UPPER_BAR_HEIGHT
    self:drawTextureScaled(self.titlebarbkg, 2, 1, self.width - 4, upperBarHeight, 1, 1, 1, 1);
    self:drawRectBorder(0, 0, self.width, upperBarHeight, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b);

    self:drawText(self.title, 24, 0, 1, 1, 1, 1, UIFont.Small);

    if not self.isCollapsed then
        local lowerBarHeight = SidePanel.LOWER_BAR_HEIGHT
        self:drawTextureScaled(self.titlebarbkg, 2, self.height - lowerBarHeight, self.width - 4, lowerBarHeight, 1, 1, 1, 1);
        self:drawRectBorder(0, self.height - lowerBarHeight, self.width, lowerBarHeight, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b);
    end
end

function SidePanel:render()
    if self.joyfocus then
        self:drawRectBorder(0, 0, self.width, self.height, 0.4, 0.2, 1.0, 1.0);
        self:drawRectBorder(1, 1, self.width-2, self.height-2, 0.4, 0.2, 1.0, 1.0);
    end
end

function SidePanel:onInventoryVisibilityChanged(isVisible)
    if not self.isDocked and not self:isController() then return; end
    self:setVisible(isVisible and not self.isClosed);
end

function SidePanel:onPopoutOrAttach()
    self.isDocked = not self.isDocked;
    self.popoutButton:setImage(self.isDocked and POPOUT_TEX or ATTACH_TEX);
    if not self.isDocked then
        self:setX(self:getX() - 8);
    else
        self:setVisible(self.inventoryPage:isVisible());
    end

    self.closeButton:setVisible(not self.isDocked);

    if self.isDocked then
        self:doPin();
        self.pinButton:setVisible(false);
        self.collapseButton:setVisible(false);
    else
        self.pinButton:setVisible(not self.pin);
        self.collapseButton:setVisible(self.pin);
    end

    local modData = getLayoutModData(self.layoutId, self.char, self:isController());
    modData.isDocked = self.isDocked;

    if self.toggleElement then
        -- Twice to avoid changing state, but to update the buttons
        self.toggleElement:onToggleSidePanel();
        self.toggleElement:onToggleSidePanel();
    end
end


function SidePanel:onClose()
    self:closeSidePanel();
end

function SidePanel:closeSidePanel()
    self.isClosed = true;
    self:setVisible(false);

    local modData = getLayoutModData(self.layoutId, self.char, self:isController());
    modData.isClosed = true;

    self.inventoryPage:bringToTop();
end

function SidePanel:toggleSidePanel()
    if self.isClosed or not self:isVisible() then
        self.isClosed = false;
        if self.isDocked or self:isController() then
            self:setVisible(self.inventoryPage:isVisible());
            if self.inventoryPage:isVisible() then
                -- Uncollapse the inventory page when opening the docked side panel
                self.inventoryPage.collapseCounter = 0;
                self.inventoryPage.isCollapsed = false;
                self.inventoryPage:clearMaxDrawHeight();
            end
        else
            self:setVisible(true);
        end
    else
        self:onClose();
    end

    local modData = getLayoutModData(self.layoutId, self.char, self:isController());
    modData.isClosed = self.isClosed;

    if not self.isClosed and not self.isDocked then
        self:bringToTop();
    end

    return not self.isClosed;
end

---@deprecated
function SidePanel:toggleWindow()
    self:toggleSidePanel();
end

function SidePanel:onMouseDown(x, y)
    if self.isDocked then return; end

    -- if over the title bar, then drag the window
    local upperBarHeight = SidePanel.UPPER_BAR_HEIGHT
    if y < upperBarHeight then
        self.dragging = true;
        self.dragX = x;
        self.dragY = y;
        return true
    end

    -- if over the bottom bar, and not docked, then resize the window
    local lowerBarHeight = SidePanel.LOWER_BAR_HEIGHT
    if y > self:getHeight() - lowerBarHeight then
        self.resizing = true;
        self.dragX = x;
        self.dragY = y;
        return true
    end
end

function SidePanel:onMouseDownOutside(x, y)
    -- check if the mouse is over this window
    if self:isMouseOver() then return; end


    if self.isDocked then
        if self.inventoryPage:isMouseOver() then
            self:uncollapseWindow();
            return
        end
    end
    self:collapseWindow();
end

function SidePanel:onRightMouseDownOutside(x, y)
    self:onMouseDownOutside(x, y)
end

function SidePanel:onMouseUp(x, y)
    self.dragging = false;
    self.resizing = false;
end

function SidePanel:onMouseUpOutside(x, y)
    self.dragging = false;
    self.resizing = false;
end

function SidePanel:onMouseMove(dx, dy)
    local player = getSpecificPlayer(self.playerNum)
    if player:isAiming() then return; end

    if not isMouseButtonDown(0) and not isMouseButtonDown(1) and not isMouseButtonDown(2) then
        self:uncollapseWindow();
    end

    local panCameraKey = getCore():getKey("PanCamera")
    if self.isCollapsed and panCameraKey ~= 0 and isKeyDown(panCameraKey) then
        return
    end

    if self.toggleElement then
        self.toggleElement:bringToTop();
    end

    if self.dragging then
        self:setX(self:getX() + dx);
        self:setY(self:getY() + dy);
        ---@diagnostic disable-next-line: redundant-return-value, return-type-mismatch
        return true
    end

    if self.resizing then
        local newHeight = self:getHeight() + dy
        if newHeight < 100 then newHeight = 100; end
        self:setHeight(newHeight);
        ---@diagnostic disable-next-line: redundant-return-value, return-type-mismatch
        return true
    end
end

function SidePanel:onMouseMoveOutside(dx, dy)
    if not DragAndDrop.isDragging() and not self.pin then
        self.collapseCounter = self.collapseCounter + getGameTime():getMultiplier() / 0.8;

        local playerObj = getSpecificPlayer(self.playerNum)
        if playerObj and playerObj:isAiming() then
            self.collapseCounter = 1000
        end

        if self.collapseCounter > 120 and not self.isCollapsed then
            self:collapseWindow();
        end
    end

    if self.dragging then
        self:setX(self:getX() + dx);
        self:setY(self:getY() + dy);
        ---@diagnostic disable-next-line: redundant-return-value, return-type-mismatch
        return true
    end

    if self.resizing then
        local newHeight = self:getHeight() + dy
        if newHeight < 100 then newHeight = 100; end
        self:setHeight(newHeight);
        ---@diagnostic disable-next-line: redundant-return-value, return-type-mismatch
        return true
    end
end

function SidePanel:collapseWindow()
    self.isCollapsed = true;
    self:setMaxDrawHeight(self.inventoryPage:titleBarHeight());
end

function SidePanel:uncollapseWindow()
    self.isCollapsed = false;
    self:clearMaxDrawHeight();
    self.collapseCounter = 0;
end

function SidePanel:doPin()
    self.pin = true

    if not self.isDocked then
        self.pinButton:setVisible(false)
        self.collapseButton:setVisible(true)
    end
end

function SidePanel:doCollapse()
    if self.isDocked then return; end

    self.pin = false
    self.pinButton:setVisible(true)
    self.collapseButton:setVisible(false)
end

function SidePanel:RestoreLayout(name, layout)
    ISLayoutManager.DefaultRestoreWindow(self, layout)
    if layout.pin == 'true' or layout.pin == nil then
        self:doPin()
    else
        self:doCollapse()
        self:collapseWindow()
    end
end

function SidePanel:SaveLayout(name, layout)
    if self.pin then layout.pin = 'true' else layout.pin = 'false' end
    ISLayoutManager.DefaultSaveWindow(self, layout)
end

function SidePanel:bringToTop()
    ISPanel.bringToTop(self)
    if self.isDocked then
        self.inventoryPage.notlocSidePanelManager:bringToTop()
    end
end

-- Controller Window focus handling
function SidePanel:onJoypadDirLeft(joypadData)
    setJoypadFocus(self.playerNum, getPlayerLoot(self.playerNum));
end

function SidePanel:onJoypadDirRight(joypadData)
    setJoypadFocus(self.playerNum, getPlayerInventory(self.playerNum));
end

function SidePanel:onJoypadDown(button)

end

return SidePanel
