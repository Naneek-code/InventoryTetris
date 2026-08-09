-- Injects the new rendering elements into the InventoryPane and disables the original system.
---@diagnostic disable: duplicate-set-field

require("ISUI/ISPanel")
require("ISUI/ISButton")
require("ISUI/ISMouseDrag")
require("TimedActions/ISTimedActionQueue")
require("TimedActions/ISEatFoodAction")
require("ISUI/ISInventoryPane")
local ItemStack = require("InventoryTetris/Model/ItemStack")
local DragAndDrop = require("InventoryTetris/System/DragAndDrop")
local ControllerDragAndDrop = require("InventoryTetris/System/ControllerDragAndDrop")
local OPT = require("InventoryTetris/Settings")
local Version = require("Notloc/Versioning/Version")
local ItemGridContainerUI = require("InventoryTetris/UI/Container/ItemGridContainerUI")
local TetrisWindowManager = require("InventoryTetris/UI/Windows/TetrisWindowManager")

-- I use on game boot because I want to make sure other mods have loaded before I patch this in
Events.OnGameBoot.Add(function()

    local og_new = ISInventoryPane.new
    function ISInventoryPane:new(x, y, width, height, inventory, zoom)
        local o = og_new(self, x, y, width, height, inventory, zoom)
        o.gridContainerUis = {}
        return o
    end

    -- Smangsty: Keep the vanilla key-ring pane compact without changing item behavior.
    local function applyHeaderlessVanillaPane(self)
        if not self.tetrisHideHeaders then return end
        if self.expandAll then self.expandAll:setVisible(false) end
        if self.collapseAll then self.collapseAll:setVisible(false) end
        if self.filterMenu then self.filterMenu:setVisible(false) end
        if self.nameHeader then self.nameHeader:setVisible(false) end
        if self.typeHeader then self.typeHeader:setVisible(false) end
        self.headerHgt = 0
        self.column3 = self.width + 1
    end

    -- Smangsty: Split visually identical keys by vanilla key ID without changing item data.
    local function splitKeyRingGroupsByKeyId(self)
        if not self.tetrisSplitKeysById or not self.itemslist then return end

        local splitItemsList = {}
        local splitItemIndex = {}

        for _, group in ipairs(self.itemslist) do
            if instanceof(group, "InventoryItem") or not group.items then
                table.insert(splitItemsList, group)
            else
                local groupsByKey = {}
                local keyOrder = {}

                -- Vanilla stores a dummy duplicate at index 1; real items begin at index 2.
                for i = 2, #group.items do
                    local item = group.items[i]
                    local keyId = item:getKeyId()
                    local identity = keyId == -1 and ("item:" .. tostring(item:getID())) or ("key:" .. tostring(keyId))
                    local splitGroup = groupsByKey[identity]

                    if not splitGroup then
                        splitGroup = {
                            items = {},
                            count = 1,
                            invPanel = self,
                            name = (group.name or item:getDisplayName()) .. string.char(31) .. identity,
                            cat = group.cat,
                            weight = 0,
                            equipped = group.equipped,
                            inHotbar = group.inHotbar,
                        }
                        groupsByKey[identity] = splitGroup
                        table.insert(keyOrder, identity)
                    end

                    table.insert(splitGroup.items, item)
                    splitGroup.weight = splitGroup.weight + item:getUnequippedWeight()
                end

                for _, identity in ipairs(keyOrder) do
                    local splitGroup = groupsByKey[identity]
                    local firstItem = splitGroup.items[1]
                    if firstItem then
                        table.insert(splitGroup.items, 1, firstItem)
                        splitGroup.count = #splitGroup.items
                        if self.collapsed[splitGroup.name] == nil then
                            self.collapsed[splitGroup.name] = true
                        end
                        table.insert(splitItemsList, splitGroup)
                        splitItemIndex[splitGroup.name] = splitGroup
                    end
                end
            end
        end

        self.itemslist = splitItemsList
        self.itemindex = splitItemIndex
        table.wipe(self.selected)
    end
    local og_createChildren = ISInventoryPane.createChildren
    function ISInventoryPane:createChildren()
        og_createChildren(self)
        if self.tetrisVanillaPane then
            applyHeaderlessVanillaPane(self)
            return
        end

        self.tetrisWindowManager = TetrisWindowManager:new(self, self.player)

        self.hscroll = ISScrollBar:new(self, false)
        self.hscroll:initialise()
        self:addChild(self.hscroll)

        self.tetrisContentPane = ISUIElement:new(0, 0, self.width, self.height)
        self.tetrisContentPane:initialise()
        self.tetrisContentPane.prerender = function() 
            self.tetrisContentPane:setStencilRect(0, 0, self.tetrisContentPane.width, self.tetrisContentPane.height)
        end
        self.tetrisContentPane.render = function() 
            self.tetrisContentPane:clearStencilRect()
        end

        self:addChild(self.tetrisContentPane)

        self.onApplyGridScaleCallback = function(scale)
            self:onApplyGridScale(scale)
        end
        OPT.OnValueChanged.SCALE:add(self.onApplyGridScaleCallback)

        self.onApplyContainerInfoScaleCallback = function(scale)
            self:onApplyContainerInfoScale(scale)
        end
        OPT.OnValueChanged.CONTAINER_INFO_SCALE:add(self.onApplyContainerInfoScaleCallback)
    end

    function ISInventoryPane:onApplyGridScale(scale)
        for _, gridContainerUi in ipairs(self.gridContainerUis) do
            gridContainerUi:onApplyGridScale(scale)
        end

        local windows = self:getChildWindows()
        for _, window in ipairs(windows) do
            if window.onApplyGridScale then
                window:onApplyGridScale(scale)
            end
        end

        self:refreshContainer()
    end

    function ISInventoryPane:onApplyContainerInfoScale(scale)
        for _, gridContainerUi in ipairs(self.gridContainerUis) do
            gridContainerUi:onApplyContainerInfoScale(scale)
        end

        local windows = self:getChildWindows()
        for _, window in ipairs(windows) do
            if window.onApplyContainerInfoScale then
                window:onApplyContainerInfoScale(scale)
            end
        end

        self:refreshContainer()
    end

    local og_refreshContainer = ISInventoryPane.refreshContainer
    function ISInventoryPane:refreshContainer()
        if self.tetrisVanillaPane then
            local result = og_refreshContainer(self)
            splitKeyRingGroupsByKeyId(self)
            applyHeaderlessVanillaPane(self)
            return result
        end

        -- Do this for mod compatibility only, tetris has no use for this
        og_refreshContainer(self)
        -- Hide these buttons because they are updated every refresh
        if self.expandAll then self.expandAll:setVisible(false) end
        if self.collapseAll then self.collapseAll:setVisible(false) end
        if self.filterMenu then self.filterMenu:setVisible(false) end

        self:refreshItemGrids()
        self.parent:checkTetrisSearch()
    end

    function ISInventoryPane:refreshItemGrids(forceFullRefresh)
        local oldGridContainerUis = {}
        for _, gridContainerUi in ipairs(self.gridContainerUis) do
            self.tetrisContentPane:removeChild(gridContainerUi)
            oldGridContainerUis[gridContainerUi.inventory] = gridContainerUi
        end

        self.gridContainerUis = {}

        local inventories = {}

        ---@type ISInventoryPage?
        local inventoryPage = self.parent
        if inventoryPage and inventoryPage.onCharacter then
            if ISInventoryPage.applyBackpackOrder then
                inventoryPage:applyBackpackOrder()
            end

            -- Gather and sort the backpack buttons by their Y position
            local buttonsAndY = {}
            for _, button in ipairs(inventoryPage.backpacks) do
                table.insert(buttonsAndY, {button = button, y = button:getY()})
            end
            table.sort(buttonsAndY, function(a, b) return a.y < b.y end)

            -- Rebuild the inventories list in Y order
            for _, buttonAndY in ipairs(buttonsAndY) do
                local button = buttonAndY.button
                local inventory = button.inventory
                table.insert(inventories, inventory)
            end
        else
            inventories[1] = self.inventory
        end

        local x = 10
        local y = 10
        for _, inventory in ipairs(inventories) do
            local itemGridContainerUi = oldGridContainerUis[inventory]
            if itemGridContainerUi and forceFullRefresh then
                itemGridContainerUi:unregisterEvents()
                itemGridContainerUi = nil
            end

            if not itemGridContainerUi then
                itemGridContainerUi = ItemGridContainerUI:new(inventory, self, self.player)
                itemGridContainerUi:initialise()
            end

            itemGridContainerUi:setY(y)
            itemGridContainerUi:setX(10)
            self.tetrisContentPane:addChild(itemGridContainerUi)

            x = math.max(x, itemGridContainerUi:getX() + itemGridContainerUi:getWidth() + 8)
            y = y + itemGridContainerUi:getHeight() + 8

            table.insert(self.gridContainerUis, itemGridContainerUi)
        end

        self.tetrisLastScrollX = 0
        self.tetrisLastScrollY = 0

        self:setScrollWidth(x)
        self:setScrollHeight(y)

        self:updateTetrisContentPanel()
    end

    function ISInventoryPane:updateTetrisContentPanel()
        local lastX = self.tetrisLastScrollX or 0
        local lastY = self.tetrisLastScrollY or 0

        local xScroll = self:getXScroll()
        local yScroll = self:getYScroll()

        -- If the x scroll is larger than the actual scroll width, clamp it
        -- Makes the content slide back into view on the x axis as the window becomes wider
        if -xScroll + self.tetrisContentPane:getWidth() > self:getScrollWidth() then
            xScroll = -math.max(0, self:getScrollWidth() - self.tetrisContentPane:getWidth())
            self:setXScroll(xScroll)
        end

        for _, gridContainerUi in ipairs(self.gridContainerUis) do
            gridContainerUi:setX(gridContainerUi:getX() - lastX + xScroll)
            gridContainerUi:setY(gridContainerUi:getY() - lastY + yScroll)
        end

        self.tetrisLastScrollX = xScroll
        self.tetrisLastScrollY = yScroll
    end

    function ISInventoryPane:findContainerGridUiUnderMouse()
        if not self.gridContainerUis then return nil end
        for _, containerUi in ipairs(self.gridContainerUis) do
            if containerUi:isMouseOver() then
                return containerUi
            end
        end

        for _, window in ipairs(self:getChildWindows()) do
            if window:isMouseOver() and window.gridContainerUi then
                return window.gridContainerUi
            end
        end

        return nil
    end

    local og_renderdetails = ISInventoryPane.renderdetails
    function ISInventoryPane:renderdetails(doDragged)
        -- Smangsty: Suppress vanilla's dragged-row ghost; Inventory Tetris renders the drag icon.
        if self.tetrisVanillaPane and doDragged then
            return
        end
        return og_renderdetails(self, doDragged)
    end

    local og_prerender = ISInventoryPane.prerender
    function ISInventoryPane:prerender()
        if self.tetrisVanillaPane then
            return og_prerender(self)
        end

        og_prerender(self);

        self.nameHeader:setVisible(false)
        self.typeHeader:setVisible(false)

        local isVScrollBarVisible = self:isVScrollBarVisible()
        local isHScrollBarVisible = self.hscroll and (self.hscroll:getWidth() < self:getScrollWidth())
        local xOffset = isVScrollBarVisible and 13 or 0
        local yOffset = isHScrollBarVisible and 13 or 0
        
        self.tetrisContentPane:setWidth(self.width - xOffset)
        self.tetrisContentPane:setHeight(self.height - yOffset)

        self.hscroll:setWidth(self.width - xOffset)
        self.hscroll:setY(self.height - 15)

        self:updateTetrisContentPanel()

        -- Draw the version at the bottom left
        if self.parent.onCharacter then
            local version = "v"..Version.format(InventoryTetris.version)
            self:drawText(version, 8 - self:getXScroll(), self.height - 18 - self:getYScroll() - yOffset, 0.3, 0.3, 0.3, 0.82, UIFont.Small)
        end
    end

    local og_render = ISInventoryPane.render
    function ISInventoryPane:render()
        if self.tetrisVanillaPane then
            return og_render(self)
        end

        og_render(self)
        if self.mode ~= "grid" then
            self.mode = "grid" -- Let a single frame pass before we start rendering the grid
            self:refreshItemGrids() -- Updates the scroll size
        end
    end

    local og_doButtons = ISInventoryPane.doButtons
    function ISInventoryPane:doButtons(...)
        if self.tetrisVanillaPane then
            return og_doButtons(self, ...)
        end
    end

    local og_updateTooltip = ISInventoryPane.updateTooltip
    function ISInventoryPane:updateTooltip()
        if self.mode ~= "grid" or not self.gridContainerUis then
            return og_updateTooltip(self)
        end

        if not self:isReallyVisible() then
            return -- in the main menu
        end

        local isController = JoypadState.players[self.player+1] ~= nil

        if not isController and self.parent:isMouseOverEquipmentUi() then
            return GetPlayerEquipmentUi(self.player):updateTooltip()
        else
            if isController then
                local item = self:findSelectedControllerItem()
                self:doTooltipForItem(item)
            else
                local item = nil

                if not self.doController and not self.dragging and not self.draggingMarquis then
                    local containerGridUi = self:findContainerGridUiUnderMouse()
                    if containerGridUi then
                        local stack = containerGridUi:findGridStackUnderMouse()
                        item = stack and ItemStack.getFrontItem(stack, containerGridUi.inventory) or nil
                    end
                end

                self:doTooltipForItem(item)
            end
        end
    end

    function ISInventoryPane:doTooltipForItem(item)
        local weightOfStack = 0.0
        if item and not instanceof(item, "InventoryItem") then
            if #item.items > 2 then
                weightOfStack = item.weight
            end
            item = item.items[1]
        end

        if getPlayerContextMenu(self.player):isAnyVisible() then
            item = nil
        end

        if item and self.toolRender and (item == self.toolRender.item) and
                (weightOfStack == self.toolRender.tooltip:getWeightOfStack()) and
                self.toolRender:isVisible() then
            return
        end

        if item and not DragAndDrop.getDraggedStack() then
            if self.toolRender then
                self.toolRender:setItem(item)
                self.toolRender:setVisible(true)
                self.toolRender:addToUIManager()
                self.toolRender:bringToTop()
            else
                self.toolRender = ISToolTipInv:new(item)
                self.toolRender:initialise()
                self.toolRender:addToUIManager()
                self.toolRender:setVisible(true)
                self.toolRender:setOwner(self)
                self.toolRender:setCharacter(getSpecificPlayer(self.player))
                self.toolRender.anchorBottomLeft = { x = self:getAbsoluteX() + self.column2, y = self:getParent():getAbsoluteY() }
            end
            self.toolRender.followMouse = not self.doController
            self.toolRender.tooltip:setWeightOfStack(weightOfStack)
        elseif self.toolRender then
            self.toolRender:removeFromUIManager()
            self.toolRender:setVisible(false)
        end

        -- Hack for highlighting doors when a Key tooltip is displayed.
        if self.parent.onCharacter then
            if not self.toolRender or not self.toolRender:getIsVisible() then
                item = nil
            end
            Key.setHighlightDoors(self.player, item)
        end

        local inventoryPage = getPlayerInventory(self.player)
        local inventoryTooltip = inventoryPage and inventoryPage.inventoryPane.toolRender
        local lootPage = getPlayerLoot(self.player)
        local lootTooltip = lootPage and lootPage.inventoryPane.toolRender
        UIManager.setPlayerInventoryTooltip(self.player,
            inventoryTooltip and inventoryTooltip.javaObject,
            lootTooltip and lootTooltip.javaObject)
    end

    local og_onMouseDown = ISInventoryPane.onMouseDown
    function ISInventoryPane:onMouseDown(x, y)
        if self.mode ~= "grid" then
            if self.tetrisVanillaPane then
                -- Smangsty: Resolve the key row on mouse-down so first-drag works without marquee selection.
                local row = math.floor((y - self.headerHgt) / self.itemHgt) + 1
                if x >= 0 and y >= self.headerHgt and x < self.column3 and self.items[row] then
                    self.mouseOverOption = row
                else
                    self.mouseOverOption = 0
                end
            end

            local result = og_onMouseDown(self, x, y)
            if self.tetrisVanillaPane and self.mouseOverOption == 0 then
                self.draggingMarquis = false
            end
            return result
        end
        return true;
    end

    local og_mouseUp = ISInventoryPane.onMouseUp
    local tetrisVanillaDragFocus = { onMouseUp = function() end }
    function ISInventoryPane:onMouseUp(x, y)
        if self.mode ~= "grid" then
            local externalKeyRingDrag = self.tetrisVanillaPane and ISMouseDrag.dragging and ISMouseDrag.draggingFocus ~= self
            local savedMouseOverOption = externalKeyRingDrag and self.mouseOverOption or nil
            if externalKeyRingDrag then
                -- Smangsty: External drops target the key-ring container, not the hovered key row.
                self.mouseOverOption = 0
            end

            local bridgeTetrisDrag = self.tetrisVanillaPane and ISMouseDrag.dragging and not ISMouseDrag.draggingFocus and ISMouseDrag.dragOwner
            if bridgeTetrisDrag then
                ISMouseDrag.draggingFocus = tetrisVanillaDragFocus
            end

            local result = og_mouseUp(self, x, y)
            if externalKeyRingDrag then
                self.mouseOverOption = savedMouseOverOption or 0
            end
            if bridgeTetrisDrag then
                DragAndDrop.endDrag()
            end
            return result
        end
        return true;
    end

    local og_onRightMouseUp = ISInventoryPane.onRightMouseUp
    function ISInventoryPane:onRightMouseUp(x, y)
        if self.mode ~= "grid" then
            return og_onRightMouseUp(self, x, y)
        end
        return false;
    end

    local og_onMouseDoubleClick = ISInventoryPane.onMouseDoubleClick
    function ISInventoryPane:onMouseDoubleClick(x, y)
        if self.mode ~= "grid" then
            return og_onMouseDoubleClick(self, x, y)
        end

        for _, gridContainerUi in ipairs(self.gridContainerUis) do
            local containerUi = self:findContainerGridUiUnderMouse()
            if containerUi then
                return containerUi:onMouseDoubleClick(containerUi:getMouseX(), containerUi:getMouseY())
            end
        end
    end

    local og_onMouseWheel = ISInventoryPane.onMouseWheel
    function ISInventoryPane:onMouseWheel(del)
        if self.tetrisVanillaPane then
            return og_onMouseWheel(self, del)
        end

        if self.inventoryPage.isCollapsed then return false; end
        if self.inventoryPage:isCycleContainerKeyDown() then return false; end

        local sideScrollKeyDown = false

        -- TODO: Make this a customizable key
        local keyName = getCore():getOptionCycleContainerKey()
        if keyName == "control" then
            sideScrollKeyDown = isKeyDown(Keyboard.KEY_LSHIFT) or isKeyDown(Keyboard.KEY_RSHIFT)
        else
            sideScrollKeyDown = isKeyDown(Keyboard.KEY_LCONTROL) or isKeyDown(Keyboard.KEY_RCONTROL)
        end

        if sideScrollKeyDown then
            self:setXScroll(self:getXScroll() - (del*25));
        else
            self:setYScroll(self:getYScroll() - (del*25));
        end
        return true
    end

    local og_transferItemsByWeight = ISInventoryPane.transferItemsByWeight
    function ISInventoryPane:transferItemsByWeight(items, container)
        if self.tetrisVanillaPane then
            -- Smangsty: Key-ring transfers stay on vanilla acceptance and transfer rules.
            return og_transferItemsByWeight(self, items, container)
        end

        ISInventoryTransferAction.globalTetrisRules = true
        og_transferItemsByWeight(self, items, container)
        ISInventoryTransferAction.globalTetrisRules = false
    end

    function ISInventoryPane:getChildWindows()
        if self.tetrisWindowManager then
            return self.tetrisWindowManager.childWindows
        end
        return {}
    end



    local og_canPutIn = ISInventoryPane.canPutIn
    function ISInventoryPane:canPutIn()
        ControllerDragAndDrop.currentPlayer = self.player
        local retVal = og_canPutIn(self)
        ControllerDragAndDrop.currentPlayer = nil
        return retVal
    end

    local og_getActualItems = ISInventoryPane.getActualItems
    function ISInventoryPane.getActualItems(items)
        if not items then
            items = ControllerDragAndDrop.getDraggedStack(ControllerDragAndDrop.currentPlayer)
        end
        if not items then return {} end
        if items.items then
            return og_getActualItems(items.items)
        end
        return og_getActualItems(items)
    end

    function ISInventoryPane:scrollToPositionX(screenXPos)
        local xPos = screenXPos - self:getAbsoluteX()

        local scrollX = self:getXScroll()
        local newScroll = scrollX - xPos
        if newScroll > 0 then
            newScroll = 0
        end
        self:setXScroll(newScroll)
    end

    function ISInventoryPane:scrollToPositionY(screenYPos)
        local yPos = screenYPos - self:getAbsoluteY()

        local scrollY = self:getYScroll()
        local newScroll = scrollY - yPos
        if newScroll > 0 then
            newScroll = 0
        end
        self:setYScroll(newScroll)
    end

    function ISInventoryPane:scrollToContainer(inventory)
        for _, gridContainerUi in ipairs(self.gridContainerUis) do
            if gridContainerUi.inventory == inventory then
                self:scrollToPositionY(gridContainerUi:getAbsoluteY())
                return
            end
        end
    end


    function ISInventoryPane:findSelectedControllerItem()
        local inv = self.parent
        if not inv.joyfocus then return nil end

        local selection = inv.controllerNode:getLeafChild()
        if selection and selection.uiElement.Type == "ItemGridUI" then
            return selection.uiElement:getControllerSelectedItem() 
        end
        return nil
    end

    Events.OnClothingUpdated.Add(function(playerObj)
        if not instanceof(playerObj, "IsoPlayer") then
            return
        end

        ---@cast playerObj IsoPlayer
        local playerNum = playerObj:getPlayerNum()
        local inventoryPage = getPlayerInventory(playerNum)

        if inventoryPage then
            local containerUis = inventoryPage.inventoryPane.gridContainerUis or {}
            for _, containerUi in ipairs(containerUis) do
                if containerUi.containerGrid and containerUi.containerGrid.onClothingUpdated then
                    containerUi.containerGrid:onClothingUpdated()
                end
            end
        end
    end)
end)
