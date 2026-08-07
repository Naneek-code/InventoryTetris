local TetrisContainerData = require("InventoryTetris/Data/TetrisContainerData")

-- This patch disables the carry weight capacity check for all containers except for the player's main inventory.
-- This implementation avoids lasting changes to the container's capacity by temporarily setting it to a very high value during the check.
---@diagnostic disable: duplicate-set-field

local function isPlayerInv(container)
    local player1 = getSpecificPlayer(0)
    local player2 = getSpecificPlayer(1)
    local player3 = getSpecificPlayer(2)
    local player4 = getSpecificPlayer(3)

    local inv1 = player1 and player1:getInventory() or nil
    local inv2 = player2 and player2:getInventory() or nil
    local inv3 = player3 and player3:getInventory() or nil
    local inv4 = player4 and player4:getInventory() or nil

    return container == inv1 or container == inv2 or container == inv3 or container == inv4
end

-- Spoofs the game's capacity check by pretending the target container is empty/infinite capacity.
local function disableCarryWeightOnContainer(container, callback, ...)
    if instanceof(container, "InventoryContainer") then
        container = container:getInventory()
    end

    if not container then
        return callback(...)
    end

    local originalCapacity = container:getCapacity()
    local originalType = container:getType()

    -- Skip player's main inventory or fragile containers or if the option is disabled
    -- In multiplayer, the Java server enforces weight validation server-side and there is no Lua-accessible
    -- bypass. We gracefully fall back to vanilla weight limits in MP to avoid broken transfer animations.
    if originalType == "floor" or SandboxVars.InventoryTetris.EnforceCarryWeight or isClient() then --[[or isPlayerInv(container)]] -- Disabling capacity for the player inv due to vanilla fluid bugs
        return callback(...)
    end

    local containerDef = TetrisContainerData.getContainerDefinition(container)
    if containerDef.isFragile then
        return callback(...)
    end

    if originalCapacity == 50 then
        container:setCapacity(49) -- 49 so we don't match the real floor's key of floor_50
    end
    container:setType("floor") -- Pretend we're the floor
    TetrisContainerData.setContainerDefinition(container, containerDef)

    local results = {pcall(callback, ...)}

    TetrisContainerData.setContainerDefinition(container, nil)
    container:setType(originalType)
    if originalCapacity == 50 then
        container:setCapacity(originalCapacity)
    end

    if results[1] then
        return unpack(results, 2)
    else
        error(results[2])
    end
end

-- All vanilla functions that I found that check the container's capacity
Events.OnGameStart.Add(function()
    require("ISUI/ISInventoryPane")
    local og_canPutIn_pane = ISInventoryPane.canPutIn
    function ISInventoryPane:canPutIn()
        local container = self.inventory
        return disableCarryWeightOnContainer(container, og_canPutIn_pane, self)
    end

    local og_update_draggedItems = ISInventoryPaneDraggedItems and ISInventoryPaneDraggedItems.update
    if og_update_draggedItems then
        function ISInventoryPaneDraggedItems:update()
            self.playerNum = self.inventoryPane.player
            local container, what = self:getDropContainer()
            local ret = disableCarryWeightOnContainer(container, og_update_draggedItems, self)

            -- Fix: disableCarryWeightOnContainer spoofs the target container's type as "floor".
            -- Vanilla ISInventoryPane:update() (line 1384-1393) has a special block for floor containers
            -- that flags any item with getWorldItem() as itemNotOK when what ~= "loot" (e.g. "button").
            -- This is wrong when the real target is a normal container (backpack, crate, etc.)
            -- that was only temporarily spoofed. We un-flag those items here using the real checks.
            if container and self.itemNotOK and self.items and container:getType() ~= "floor" then
                local playerObj = getSpecificPlayer(self.playerNum)
                local containerInInventory = container:isInCharacterInventory(playerObj)
                local containerSq = container:hasWorldItem() and container:getWorldItem():getSquare() or nil
                local totalWeight = 0
                local weightAddedToFloor = 0
                for _, item in ipairs(self.items) do
                    if item:getWorldItem() and self.itemNotOK[item] then
                        -- Re-apply the real (non-floor) checks from vanilla lines 1405-1440
                        local itemOK = true
                        if container:isInside(item) then itemOK = false end
                        if item:isFavorite() and not containerInInventory then itemOK = false end
                        if item:getContainer() == container then itemOK = false end
                        if not container:isItemAllowed(item) then itemOK = false end
                        if itemOK then
                            local newTotalWeight = totalWeight + item:getUnequippedWeight()
                            local newWeightAddedToFloor = weightAddedToFloor
                            if containerSq == nil or not item:isOnGroundOrInsideBagOnSquare(containerSq) then
                                newWeightAddedToFloor = weightAddedToFloor + item:getUnequippedWeight()
                            end
                            if container:hasRoomFor(playerObj, newTotalWeight, newWeightAddedToFloor) then
                                totalWeight = newTotalWeight
                                weightAddedToFloor = newWeightAddedToFloor
                                self.itemNotOK[item] = false
                            end
                        end
                    end
                end
            end

            return ret
        end
    end

    require("ISUI/ISInventoryPage")
    local og_canPutIn_page = ISInventoryPage.canPutIn
    function ISInventoryPage:canPutIn()
        local container = self.mouseOverButton and self.mouseOverButton.inventory or nil
        return disableCarryWeightOnContainer(container, og_canPutIn_page, self)
    end

    require("TimedActions/ISInventoryTransferAction")
    local og_isValid = ISInventoryTransferAction.isValid
    function ISInventoryTransferAction:isValid()
        local container = self.destContainer
        return disableCarryWeightOnContainer(container, og_isValid, self)
    end

    require("ISUI/ISInventoryPaneContextMenu")
    local og_hasRoomForAny = ISInventoryPaneContextMenu.hasRoomForAny
    function ISInventoryPaneContextMenu.hasRoomForAny(playerObj, container, items)
        return disableCarryWeightOnContainer(container, og_hasRoomForAny, playerObj, container, items)
    end

    require("Foraging/ISBaseIcon")
    local og_doContextMenu = ISBaseIcon.doContextMenu
    function ISBaseIcon:doContextMenu(_context)
        local plInventory = self.character:getInventory();
        return disableCarryWeightOnContainer(plInventory, og_doContextMenu, self, _context)
    end
end)
