local TetrisItemData = require("InventoryTetris/Data/TetrisItemData")
local TetrisContainerData = require("InventoryTetris/Data/TetrisContainerData")
local ItemContainerGrid = require("InventoryTetris/Model/ItemContainerGrid")
local KeyRingSupport = require("InventoryTetris/KeyRingSupport")
local TetrisModCompatibility = require("InventoryTetris/TetrisModCompatibility")

-- Adjustments to the InventoryTransferAction to support the new rules for item transfers under the grid system and avoid illegal item placements.
---@diagnostic disable: duplicate-set-field

require("TimedActions/ISInventoryTransferAction")

local ItemUtil = require("Notloc/ItemUtil")
local ModScope = require("Notloc/ModScope/ModScope")

local function getOutermostContainer(container)
    if not container or not container:getContainingItem() then
        return container
    end
    return container:getContainingItem():getOutermostContainer()
end

local function withVanillaContainerItemRulesDisabled(container, callback)
    local acceptItemFunction = container:getAcceptItemFunction()
    local onlyAcceptCategory = container:getOnlyAcceptCategory()
    if not acceptItemFunction and not onlyAcceptCategory then
        return callback()
    end

    -- Smangsty: Keep vanilla transfer validation intact; only suspend rules explicitly replaced by Tetris data.
    container:setAcceptItemFunction(nil)
    container:setOnlyAcceptCategory(nil)
    local ok, value = pcall(callback)
    container:setAcceptItemFunction(acceptItemFunction)
    container:setOnlyAcceptCategory(onlyAcceptCategory)

    if not ok then
        error(value)
    end
    return value
end

-- We REALLY need to be the last one to load here
Events.OnGameBoot.Add(function()
    ISInventoryTransferAction.globalTetrisRules = false

    local og_new = ISInventoryTransferAction.new
    function ISInventoryTransferAction:new (character, item, srcContainer, destContainer, time, ...)
        local o = og_new(self, character, item, srcContainer, destContainer, time, ...)

        if not destContainer or not srcContainer then
            return o
        end

        if not SandboxVars.InventoryTetris.UseItemTransferTime then
            -- Smangsty: MP clients must keep vanilla's -1 wait sentinel until ItemTransactionPacket finishes the transfer.
            if not isClient() then
                o.maxTime = 0
            end
            o.stopOnRun = false
            o.stopOnWalk = false
        else
            if o.maxTime > 0 and not isClient() then
                o.maxTime = o.maxTime / SandboxVars.InventoryTetris.ItemTransferSpeedMultiplier
            end

            local inv = character:getInventory()
            local srcRoot = getOutermostContainer(srcContainer)
            local destRoot = getOutermostContainer(destContainer)

            -- Smangsty: Key-ring destinations never need a spatial Tetris definition.
            local destDef = KeyRingSupport.isContainer(destContainer) and nil or TetrisContainerData.getContainerDefinition(destContainer)

            local isInInventory = inv == srcRoot and inv == destRoot
            local isDroppingToFloor = inv == srcRoot and destDef and destDef.trueType == "floor"
            o.stopOnWalk = not (isInInventory or isDroppingToFloor)

            o.isDroppingToFloor = isDroppingToFloor
        end

        if ISInventoryTransferAction.globalTetrisRules then
            o.enforceTetrisRules = true
        end

        TetrisModCompatibility.KnoxEventExpanded_HandleNpcItemTransfer(item, srcContainer)

        return o
    end

    function ISInventoryTransferAction:setTetrisTarget(x, y, i, r, secondaryTarget)
        self.gridX = x
        self.gridY = y
        self.gridIndex = i
        self.isRotated = r
        self.tetrisSecondary = secondaryTarget
        self.enforceTetrisRules = true
    end

    local og_start = ISInventoryTransferAction.start
    function ISInventoryTransferAction:start()
        og_start(self)
        if not SandboxVars.InventoryTetris.UseItemTransferTime and not isClient() then
            self.maxTime = 0
            if self.action then self.action:setTime(0) end
        end
    end

    local og_canMergeAction = ISInventoryTransferAction.canMergeAction
    function ISInventoryTransferAction:canMergeAction(action)
        -- Smangsty: Vanilla wipes merged action tables, so an action must never be allowed to merge with itself.
        if not action or self == action then return false end
        if self.preventMerge or action.preventMerge then return false end

        local canMerge = og_canMergeAction(self, action)
        if not canMerge then return false end

        -- Cannot merge tetris actions without explicit grid targets
        if self.enforceTetrisRules and self.gridX == nil then
            return false
        end

        local tetrisCanMerge = self.gridX == action.gridX
        tetrisCanMerge = tetrisCanMerge and self.gridY == action.gridY
        tetrisCanMerge = tetrisCanMerge and self.gridIndex == action.gridIndex
        tetrisCanMerge = tetrisCanMerge and self.isRotated == action.isRotated
        return tetrisCanMerge
    end

    local og_isValid = ISInventoryTransferAction.isValid
    function ISInventoryTransferAction:isValid()
        if not self.destContainer or not self.srcContainer then
            return false
        end

        -- Smangsty: Key-ring destinations stay on vanilla validation and skip spatial grid checks.
        local isKeyRingDestination = KeyRingSupport.isContainer(self.destContainer)
        local destDef = isKeyRingDestination and nil or TetrisContainerData.getContainerDefinition(self.destContainer)
        local destType = destDef and destDef.trueType or nil

        -- If the target is not the player's inventory, we need to ensure the item fits somewhere
        local isPlayerInv = self.character:getInventory() == self.destContainer
        if not isPlayerInv and not isKeyRingDestination then
            local containerUi = ItemContainerGrid.GetOrCreate(self.destContainer, self.character:getPlayerNum())
            if not containerUi:canAddItem(self.item) then
                return false
            end
        end

        local valid;
        local overrideVanillaItemRules = destDef and destDef.overrideVanillaItemRules == true

        local function validateWithVanilla()
            -- If we are moving a Moveable to anywhere but the floor, ensure it does NOT appear to be a Moveable
            if destType ~= "floor" and instanceof(self.item, "Moveable") then
                ModScope.withInstanceofExclusion(function ()
                    valid = og_isValid(self)
                end, "Moveable")
            else
                valid = og_isValid(self)
            end
        end
        
        -- Spoof container availability for whatever we are transferring to/from
        -- Might introduce some edge cases, but I'd rather whack-a-mole them than vice versa
        ModScope.withContainersAvailable(function ()
                if overrideVanillaItemRules then
                    withVanillaContainerItemRulesDisabled(self.destContainer, validateWithVanilla)
                else
                    validateWithVanilla()
                end
            end,
            {self.destContainer, self.srcContainer}
        );

        if not valid or not self.enforceTetrisRules or isKeyRingDestination then
            return valid
        end
        return self:validateTetrisRules()
    end

    local og_doActionAnim = ISInventoryTransferAction.doActionAnim
    function ISInventoryTransferAction:doActionAnim(...)
        og_doActionAnim(self, ...)

        -- Player gets stuck crouched when dropping to the floor unless we force them to use the standing version
        if self.isDroppingToFloor then
            self:setActionAnim("DropWhileMoving");
        end
    end

    function ISInventoryTransferAction:validateTetrisRules()
        if not self:validateTetrisSquishable(self.destContainer, self.item) then
            return false
        end

        local containerGrid = ItemContainerGrid.GetOrCreate(self.destContainer, self.character:getPlayerNum())
        if self.gridX and self.gridY and self.gridIndex then
            local doesFit = containerGrid:doesItemFit(self.item, self.gridX, self.gridY, self.gridIndex, self.isRotated, self.tetrisSecondary) or containerGrid:canItemBeStacked(self.item, self.gridX, self.gridY, self.gridIndex, self.tetrisSecondary)
            if not doesFit then
                return false
            end
        elseif self.gridIndex then
            local doesFit = containerGrid:doesItemFitSpecificGrid(self.item, self.gridIndex, self.tetrisSecondary)
            if not doesFit then
                return false
            end
        end

        if containerGrid.isFloor then
            return true
        else
            return containerGrid:canAddItem(self.item)
        end
    end

    function ISInventoryTransferAction:validateTetrisSquishable(destContainer, item)
        local containerDef = TetrisContainerData.getContainerDefinition(destContainer)
        -- Container is not squishable, so the size will not change
        if containerDef.isRigid then
            return true
        end

        -- Container already contains items, so the size will not change
        if not destContainer:isEmpty() then return true end

        local itemContainer = self.destContainer:getContainingItem()

        -- No need to validate if the destContainer is equipped, it doesn't need space
        if itemContainer and itemContainer:isEquipped() then
            return true
        end

        if itemContainer then
            local parentInventory = itemContainer:getContainer()
            if parentInventory then
                if parentInventory:getType() == "floor" then
                    return true
                end

                local equippedContainers = ItemUtil.getAllEquippedContainers(self.character)
                for _, container in ipairs(equippedContainers) do
                    if container == destContainer then
                        --return true -- The container will self correct
                        -- DISABLED
                        -- The item gets dropped or repositioned in the inventory
                        -- But users keep thinking the item is getting deleted
                    end
                end

                local w, h = TetrisItemData.getItemSizeUnsquished(itemContainer)
                local parentContainerGrid = ItemContainerGrid.GetOrCreate(parentInventory, self.character:getPlayerNum())
                return parentContainerGrid:doesItemFitAnywhere(itemContainer, w, h, {itemContainer, item})
            end
        end
        return true
    end

    local og_transferItem = ISInventoryTransferAction.transferItem
    function ISInventoryTransferAction:transferItem(item)
        -- The vanilla UI handles this for all items
        -- For performance reasons, Inventory Tetris only handles this for the first item in visible stacks
        -- We add this update here to ensure items are always updated just before they are transferred.
        -- This ensure that the item is always up to date before they transfer and decouples this logic from the UI
        item:updateAge()
        if item:IsClothing() then
            ---@cast item Clothing
            item:updateWetness()
        end

        local originalItemCount = self.destContainer:getItems():size()
        local wasAlreadyTransferred = self:isAlreadyTransferred(item)

        og_transferItem(self, item)

        -- The Item has made it to the destination container, now we need to set its position in the grid
        -- If we fail to insert the item that is ok, the item will be shown in the overflowRenderer
        if not wasAlreadyTransferred and self:isAlreadyTransferred(item) then
            -- Only need to remove the item from the source grid if it's actively displayed in the UI
            local oldContainerGrid = ItemContainerGrid.FindInstance(self.srcContainer, self.character:getPlayerNum())
            if oldContainerGrid then
                oldContainerGrid:removeItem(item)
            end

            -- Smangsty: Key-ring contents remain vanilla semantic items without Tetris positions.
            if KeyRingSupport.isContainer(self.destContainer) then
                return
            end

            local destContainerGrid = self.destContainer and ItemContainerGrid.GetOrCreate(self.destContainer, self.character:getPlayerNum()) or nil
            if not destContainerGrid then return end
            if self.gridX and self.gridY and self.gridIndex then
                destContainerGrid:insertItem(item, self.gridX, self.gridY, self.gridIndex, self.isRotated, self.tetrisSecondary)
            elseif self.gridIndex then
                local grid = destContainerGrid:getSpecificGrid(self.gridIndex, self.tetrisSecondary)
                if grid then
                    local disorganized = self.character:hasTrait(CharacterTrait.DISORGANIZED)
                    grid:_attemptToInsertItem(item, self.isRotated, disorganized)
                end
            else
                local disorganized = self.character:hasTrait(CharacterTrait.DISORGANIZED)
                destContainerGrid:attemptToInsertItem(item, self.isRotated, disorganized)
            end

            -- Handle squishable items changing size
            local newItemCount = self.destContainer:getItems():size()
            if originalItemCount == 0 and newItemCount > 0 or newItemCount == 0 and originalItemCount > 0 then
                local itemContainer = self.destContainer:getContainingItem()
                if itemContainer then
                    local parentInventory = itemContainer:getContainer()
                    if parentInventory and TetrisItemData.isSquishable(itemContainer) then
                        local parentContainerGrid = ItemContainerGrid.GetOrCreate(parentInventory, self.character:getPlayerNum())
                        local stack, grid = parentContainerGrid:findStackByItem(itemContainer)
                        parentContainerGrid:removeItem(itemContainer)
                        if not stack or (grid and not parentContainerGrid:insertItem(itemContainer, stack.x, stack.y, grid.gridIndex, stack.isRotated, grid.secondaryTarget)) then
                            parentContainerGrid:attemptToInsertItem(itemContainer, self.isRotated, false)
                        end
                        parentInventory:setDrawDirty(true)
                    end
                end
            end
        end
    end

    local og_perform = ISInventoryTransferAction.perform
    function ISInventoryTransferAction:perform()
        self.queueList = self.queueList or {}
        if isClient() and self.gridX and self.gridY and self.gridIndex then
            TetrisClient = TetrisClient or {}
            TetrisClient.pendingPlacements = TetrisClient.pendingPlacements or {}
            -- Register the primary item of this action
            TetrisClient.pendingPlacements[self.item:getID()] = {
                container = self.destContainer,
                gridX = self.gridX,
                gridY = self.gridY,
                gridIndex = self.gridIndex,
                isRotated = self.isRotated,
                secondaryTarget = self.tetrisSecondary
            }
            -- Register merged queued items (each may come from a different source action)
            if self.queueList and #self.queueList > 0 then
                for _, queuedItem in ipairs(self.queueList) do
                    if queuedItem and queuedItem.items then
                        for _, item in ipairs(queuedItem.items) do
                            TetrisClient.pendingPlacements[item:getID()] = {
                                container = self.destContainer,
                                gridX = self.gridX,
                                gridY = self.gridY,
                                gridIndex = self.gridIndex,
                                isRotated = self.isRotated,
                                secondaryTarget = self.tetrisSecondary
                            }
                        end
                    end
                end
            end
        end
        og_perform(self)
    end

end)
