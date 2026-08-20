require("ISUI/ISInventoryPaneContextMenu")
require("TimedActions/ISInventoryTransferUtil")
local ItemContainerGrid = require("InventoryTetris/Model/ItemContainerGrid")
local ItemGridUI = require("InventoryTetris/UI/Grid/ItemGridUI")

-- Fixes some quirks with the right click grab options
---@diagnostic disable: duplicate-set-field

Events.OnGameBoot.Add(function()
    local function quickMoveItems(items, playerNum)
        if not items or #items == 0 then return false end

        local invPage = getPlayerInventory(playerNum)
        local playerObj = getSpecificPlayer(playerNum)
        if not invPage or not playerObj then return false end

        local targetContainers = ItemGridUI.getOrderedBackpacks(invPage)
        local transfers = {}

        -- Plan the whole move before queuing anything. A failed fit must not leave half a vanilla-style batch behind.
        for _, item in ipairs(items) do
            if not item or item:isHumanCorpse() then
                return false
            end

            local sourceContainer = item:getContainer()
            if not sourceContainer then return true end

            local targetContainer = nil
            for _, testContainer in ipairs(targetContainers) do
                if testContainer ~= sourceContainer then
                    local gridContainer = ItemContainerGrid.GetOrCreate(testContainer, playerNum)
                    if gridContainer:canAddItem(item) then
                        targetContainer = testContainer
                        break
                    end
                end
            end

            if not targetContainer then return true end
            transfers[#transfers + 1] = { item = item, source = sourceContainer, target = targetContainer }
        end

        if #transfers == 0 then return true end
        if not luautils.walkToContainer(transfers[1].source, playerNum) then return true end

        -- Smangsty: One grab means one transfer per item; queuing ours and vanilla's copy races B42 MP transactions.
        for _, planned in ipairs(transfers) do
            local transfer = ISInventoryTransferUtil.newInventoryTransferAction(playerObj, planned.item, planned.source, planned.target)
            transfer.enforceTetrisRules = true
            ISTimedActionQueue.add(transfer)
        end

        return true
    end

    local ogOnGrabItems = ISInventoryPaneContextMenu.onGrabItems
    function ISInventoryPaneContextMenu.onGrabItems(stacks, playerNum)
        local items = ISInventoryPane.getActualItems(stacks)
        if not quickMoveItems(items, playerNum) then
            ogOnGrabItems(stacks, playerNum)
        end
    end

    local ogOnGrabHalfItems = ISInventoryPaneContextMenu.onGrabHalfItems
    function ISInventoryPaneContextMenu.onGrabHalfItems(stacks, playerNum)
        local items = ISInventoryPane.getActualItems(stacks)
        local halfItems = {}
        for i = 1, math.floor(#items / 2) do
            halfItems[#halfItems + 1] = items[i]
        end

        if not quickMoveItems(halfItems, playerNum) then
            ogOnGrabHalfItems(stacks, playerNum)
        end
    end

    local ogOnGrabOneItems = ISInventoryPaneContextMenu.onGrabOneItems
    function ISInventoryPaneContextMenu.onGrabOneItems(stacks, playerNum)
        local items = ISInventoryPane.getActualItems(stacks)
        local item = items[1]
        if not item or not quickMoveItems({ item }, playerNum) then
            ogOnGrabOneItems(stacks, playerNum)
        end
    end
end)
