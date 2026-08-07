-- Handles syncing of grid data between client and server for a few specific objects that do not support the normal modData syncing methods.

-- Keep these synced with the ones in TetrisServer.lua
local TETRIS_UUID = "TetrisUUID"

local WORLD_ITEM_DATA = "INVENTORYTETRIS_WorldItemData"
local VEHICLE_ITEM_DATA = "INVENTORYTETRIS_VehicleItemData"

TetrisClient = {}
TetrisClient._modDataSyncQueue = {}
TetrisClient._lastSyncQueueTime = 0

function TetrisClient.queueModDataSync(obj)
    TetrisClient._modDataSyncQueue[obj] = true
    TetrisClient._lastSyncQueueTime = getTimestampMs()
end


function TetrisClient.getMostRecentModData(isoModData, isoKey, worldModData, worldKey)
    local worldData = worldModData[worldKey]
    if not worldData then
        return isoModData
    end

    local isoData = isoModData[isoKey]
    if not isoData then
        isoModData[isoKey] = worldData
    else
        local isoTime = isoData.lastServerTime or 0
        local worldTime = worldData.lastServerTime or 0
        if worldTime > isoTime then
            isoModData[isoKey] = worldData
        end
    end

    return isoModData
end

function TetrisClient.getInventoryContainerModData(item)
    return TetrisClient.getMostRecentModData(item:getModData(), "gridContainers", ModData.getOrCreate(WORLD_ITEM_DATA), item:getID()), item:getWorldItem()
end

function TetrisClient.getVehicleModData(vehicle)
    return TetrisClient.getMostRecentModData(vehicle:getModData(), "gridContainers", ModData.getOrCreate(VEHICLE_ITEM_DATA), vehicle:getKeyId()), vehicle
end


-- Transmit world inventory object (bag on the floor) grid data via custom command (OnReceiveGlobalModData is gone in B42)
function TetrisClient.transmitWorldInventoryObjectData(worldInvObject)
    local item = worldInvObject:getItem()
    local gridData = item and item:getModData().gridContainers
    if not gridData then return end

    local player = getPlayer()
    if not player then return end

    gridData[TETRIS_UUID] = item:getID()

    sendClientCommand(player, "InventoryTetris", "syncWorldItemGrid", {
        itemID = item:getID(),
        gridContainers = gridData,
        sender = player:getUsername()
    })
end

-- Transmit vehicle grid data via custom command (OnReceiveGlobalModData is gone in B42)
function TetrisClient.transmitVehicleInventoryData(vehicleObj)
    local gridData = vehicleObj:getModData().gridContainers
    if not gridData then return end

    local player = getPlayer()
    if not player then return end

    gridData[TETRIS_UUID] = vehicleObj:getKeyId()

    sendClientCommand(player, "InventoryTetris", "syncVehicleGrid", {
        vehicleKeyId = vehicleObj:getKeyId(),
        gridContainers = gridData,
        sender = player:getUsername()
    })
end

function TetrisClient.transmitIsoObjectGridData(isoObj)
    local gridData = isoObj:getModData().gridContainers
    if not gridData then return end

    local square = isoObj:getSquare()
    if not square then return end

    local objects = square:getObjects()
    local objIndex = objects:indexOf(isoObj)
    
    -- Fallback Lua comparison loop if indexOf fails
    if objIndex == -1 then
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if obj == isoObj or (obj.equals and obj:equals(isoObj)) then
                objIndex = i
                break
            end
        end
    end

    if objIndex == -1 then return end

    local spriteName = isoObj:getSprite() and isoObj:getSprite():getName()

    local player = getPlayer()
    if player then
        sendClientCommand(player, "InventoryTetris", "syncIsoObjectGrid", {
            x = isoObj:getX(),
            y = isoObj:getY(),
            z = isoObj:getZ(),
            objIndex = objIndex,
            spriteName = spriteName,
            gridContainers = gridData,
            sender = player:getUsername()
        })
    end
end

function TetrisClient.transmitPlayerGridData(playerObj)
    local gridData = playerObj:getModData().gridContainers
    if not gridData then return end

    local localPlayer = getPlayer()
    if localPlayer then
        sendClientCommand(localPlayer, "InventoryTetris", "syncPlayerGrid", {
            gridContainers = gridData,
            sender = playerObj:getUsername()
        })
    end
end

local function sanitizeGridContainers(gridContainers)
    if not gridContainers then return nil end
    local sanitized = {}
    for k, v in pairs(gridContainers) do
        local newK = k
        if type(k) == "string" and tonumber(k) then
            newK = tonumber(k)
        end
        if type(v) == "table" then
            sanitized[newK] = sanitizeGridContainers(v)
        else
            sanitized[newK] = v
        end
    end
    return sanitized
end

local function findItemByID(container, id)
    local item = container:getItemWithID(id)
    if item then return item end
    
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local child = items:get(i)
        if child:getInventory() then
            local found = findItemByID(child:getInventory(), id)
            if found then return found end
        end
    end
    return nil
end

function TetrisClient.transmitInventoryItemGridData(item)
    local gridData = item:getModData().gridContainers
    if not gridData then return end
    
    local player = getPlayer()
    if player then
        sendClientCommand(player, "InventoryTetris", "syncItemGrid", {
            itemID = item:getID(),
            gridContainers = gridData,
            sender = player:getUsername()
        })
    end
end

if isClient() then
    Events.OnTick.Add(function()
        if TetrisClient._lastSyncQueueTime and TetrisClient._lastSyncQueueTime > 0 then
            local now = getTimestampMs and getTimestampMs() or 0
            if now - TetrisClient._lastSyncQueueTime >= 100 then
                TetrisClient._lastSyncQueueTime = 0
                for obj,_ in pairs(TetrisClient._modDataSyncQueue) do  
                    if instanceof(obj, "IsoWorldInventoryObject") then
                        TetrisClient.transmitWorldInventoryObjectData(obj)

                    elseif instanceof(obj, "BaseVehicle") then
                        TetrisClient.transmitVehicleInventoryData(obj)

                    elseif instanceof(obj, "VehiclePart") then
                        local vehicle = obj:getVehicle()
                        if vehicle then
                            TetrisClient.transmitVehicleInventoryData(vehicle)
                        end

                    elseif instanceof(obj, "InventoryItem") then
                        TetrisClient.transmitInventoryItemGridData(obj)

                    elseif instanceof(obj, "IsoPlayer") then
                        TetrisClient.transmitPlayerGridData(obj)

                    elseif instanceof(obj, "IsoObject") then
                        -- IsoObjects should always go through syncIsoObjectGrid command, never direct transmitModData from client
                        TetrisClient.transmitIsoObjectGridData(obj)
                    end
                end
                table.wipe(TetrisClient._modDataSyncQueue)
            end
        end
    end)

    TetrisClient.recentlySyncedItems = {}

    Events.OnServerCommand.Add(function(module, command, args)
        if module ~= "InventoryTetris" then return end
        local player = getPlayer()
        if not player then return end

        if command == "syncItemGrid" then
            -- Ignore packets we sent ourselves, but update our lastServerTime!
            if args.sender == player:getUsername() and not args.isCorrection then
                local item = findItemByID(player:getInventory(), args.itemID)
                if item and item:getModData().gridContainers and args.gridContainers then
                    item:getModData().gridContainers.lastServerTime = args.gridContainers.lastServerTime
                end
                return
            end

            local item = findItemByID(player:getInventory(), args.itemID)
            if item then
                local sanitizedGrid = sanitizeGridContainers(args.gridContainers)
                
                -- Record sync time for incoming items
                if sanitizedGrid.stacks then
                    for _, stack in pairs(sanitizedGrid.stacks) do
                        for itemID, _ in pairs(stack.itemIDs) do
                            TetrisClient.recentlySyncedItems[itemID] = getTimestampMs()
                        end
                    end
                end
                
                item:getModData().gridContainers = sanitizedGrid
                
                -- If the container grid UI is open, refresh it to show the changes
                local container = item:getContainer()
                if container then
                    local ItemContainerGrid = require("InventoryTetris/Model/ItemContainerGrid")
                    local containerGrid = ItemContainerGrid.FindInstance(container, player:getPlayerNum())
                    if containerGrid then
                        containerGrid:refresh()
                    end
                end
            end

        elseif command == "syncWorldItemGrid" then
            -- Ignore echoes from ourselves unless it's a correction
            if args.sender == player:getUsername() and not args.isCorrection then
                local worldData = ModData.getOrCreate(WORLD_ITEM_DATA)
                if args.gridContainers and worldData[args.itemID] then
                    worldData[args.itemID].lastServerTime = args.gridContainers.lastServerTime
                else
                    worldData[args.itemID] = args.gridContainers
                end
                return
            end

            -- Apply incoming world item grid update from another player
            local worldData = ModData.getOrCreate(WORLD_ITEM_DATA)
            if args.itemID and args.gridContainers then
                local sanitizedGrid = sanitizeGridContainers(args.gridContainers)
                
                if sanitizedGrid.stacks then
                    for _, stack in pairs(sanitizedGrid.stacks) do
                        for itemID, _ in pairs(stack.itemIDs) do
                            TetrisClient.recentlySyncedItems[itemID] = getTimestampMs()
                        end
                    end
                end
                
                worldData[args.itemID] = sanitizedGrid
                
                local ItemContainerGrid = require("InventoryTetris/Model/ItemContainerGrid")
                if ItemContainerGrid._gridCache[player:getPlayerNum()] then
                    for _, grid in ipairs(ItemContainerGrid._gridCache[player:getPlayerNum()]) do
                        local inv = grid.inventory
                        if inv and inv:getParent() and instanceof(inv:getParent(), "IsoWorldInventoryObject") then
                            if inv:getParent():getItem() and inv:getParent():getItem():getID() == args.itemID then
                                grid:refresh()
                            end
                        end
                    end
                end
            end

        elseif command == "syncVehicleGrid" then
            -- Ignore echoes from ourselves unless it's a correction
            if args.sender == player:getUsername() and not args.isCorrection then
                local vehicleData = ModData.getOrCreate(VEHICLE_ITEM_DATA)
                if args.gridContainers and vehicleData[args.vehicleKeyId] then
                    vehicleData[args.vehicleKeyId].lastServerTime = args.gridContainers.lastServerTime
                else
                    vehicleData[args.vehicleKeyId] = args.gridContainers
                end
                return
            end

            -- Apply incoming vehicle grid update from another player
            local vehicleData = ModData.getOrCreate(VEHICLE_ITEM_DATA)
            if args.vehicleKeyId and args.gridContainers then
                local sanitizedGrid = sanitizeGridContainers(args.gridContainers)
                
                if sanitizedGrid.stacks then
                    for _, stack in pairs(sanitizedGrid.stacks) do
                        for itemID, _ in pairs(stack.itemIDs) do
                            TetrisClient.recentlySyncedItems[itemID] = getTimestampMs()
                        end
                    end
                end
                
                vehicleData[args.vehicleKeyId] = sanitizedGrid
                
                local ItemContainerGrid = require("InventoryTetris/Model/ItemContainerGrid")
                if ItemContainerGrid._gridCache[player:getPlayerNum()] then
                    for _, grid in ipairs(ItemContainerGrid._gridCache[player:getPlayerNum()]) do
                        local inv = grid.inventory
                        if inv and inv:getParent() and instanceof(inv:getParent(), "BaseVehicle") then
                            if inv:getParent():getKeyId() == args.vehicleKeyId then
                                grid:refresh()
                            end
                        end
                    end
                end
            end

        elseif command == "syncPlayerGrid" then
            if args.sender == player:getUsername() and not args.isCorrection then
                if player:getModData().gridContainers and args.gridContainers then
                    player:getModData().gridContainers.lastServerTime = args.gridContainers.lastServerTime
                end
                return
            end

            local targetPlayer = nil
            if args.sender == player:getUsername() then
                targetPlayer = player
            else
                local onlinePlayers = getOnlinePlayers()
                if onlinePlayers then
                    for i = 0, onlinePlayers:size() - 1 do
                        local p = onlinePlayers:get(i)
                        if p:getUsername() == args.sender then
                            targetPlayer = p
                            break
                        end
                    end
                end
            end

            if targetPlayer and args.gridContainers then
                local sanitizedGrid = sanitizeGridContainers(args.gridContainers)
                
                if sanitizedGrid.stacks then
                    for _, stack in pairs(sanitizedGrid.stacks) do
                        for itemID, _ in pairs(stack.itemIDs) do
                            TetrisClient.recentlySyncedItems[itemID] = getTimestampMs()
                        end
                    end
                end
                
                targetPlayer:getModData().gridContainers = sanitizedGrid
                
                local ItemContainerGrid = require("InventoryTetris/Model/ItemContainerGrid")
                local containerGrid = ItemContainerGrid.FindInstance(targetPlayer:getInventory(), player:getPlayerNum())
                if containerGrid then
                    containerGrid:refresh()
                end
            end

        elseif command == "syncIsoObjectGrid" then
            -- Ignore packets we sent ourselves, but update our lastServerTime!
            if args.sender == player:getUsername() and not args.isCorrection then
                local square = getCell():getGridSquare(args.x, args.y, args.z)
                if square then
                    local objects = square:getObjects()
                    local obj = nil
                    if args.objIndex and args.objIndex >= 0 and args.objIndex < objects:size() then
                        obj = objects:get(args.objIndex)
                    end
                    if not obj or (args.spriteName and (not obj:getSprite() or obj:getSprite():getName() ~= args.spriteName)) then
                        for i = 0, objects:size() - 1 do
                            local candidate = objects:get(i)
                            if candidate:getSprite() and candidate:getSprite():getName() == args.spriteName then
                                obj = candidate
                                break
                            end
                        end
                    end
                    if not obj then
                        for i = 0, objects:size() - 1 do
                            local candidate = objects:get(i)
                            if candidate:getModData() and (candidate:getContainer() or (candidate.getContainerCount and candidate:getContainerCount() > 0)) then
                                obj = candidate
                                break
                            end
                        end
                    end
                    if obj and obj:getModData() and obj:getModData().gridContainers and args.gridContainers then
                        obj:getModData().gridContainers.lastServerTime = args.gridContainers.lastServerTime
                    end
                end
                return
            end

            local square = getCell():getGridSquare(args.x, args.y, args.z)
            if square then
                local objects = square:getObjects()
                local obj = nil
                if args.objIndex and args.objIndex >= 0 and args.objIndex < objects:size() then
                    obj = objects:get(args.objIndex)
                end
                
                -- Fallback by sprite name search
                if not obj or (args.spriteName and (not obj:getSprite() or obj:getSprite():getName() ~= args.spriteName)) then
                    for i = 0, objects:size() - 1 do
                        local candidate = objects:get(i)
                        if candidate:getSprite() and candidate:getSprite():getName() == args.spriteName then
                            obj = candidate
                            break
                        end
                    end
                end
                
                -- Ultimate fallback: first object with a container
                if not obj then
                    for i = 0, objects:size() - 1 do
                        local candidate = objects:get(i)
                        if candidate:getModData() and (candidate:getContainer() or (candidate.getContainerCount and candidate:getContainerCount() > 0)) then
                            obj = candidate
                            break
                        end
                    end
                end

                if obj and obj:getModData() and (obj:getContainer() or (obj.getContainerCount and obj:getContainerCount() > 0)) then
                    local sanitizedGrid = sanitizeGridContainers(args.gridContainers)
                    
                    -- Record sync time for incoming items
                    if sanitizedGrid.stacks then
                        for _, stack in pairs(sanitizedGrid.stacks) do
                            for itemID, _ in pairs(stack.itemIDs) do
                                TetrisClient.recentlySyncedItems[itemID] = getTimestampMs()
                            end
                        end
                    end
                    
                    obj:getModData().gridContainers = sanitizedGrid
                    
                    -- Force refresh open grids for this object's containers
                    local containerCount = obj.getContainerCount and obj:getContainerCount() or 1
                    for cIdx = 0, containerCount - 1 do
                        local container = obj.getContainerByIndex and obj:getContainerByIndex(cIdx) or obj:getContainer()
                        if container then
                                local ItemContainerGrid = require("InventoryTetris/Model/ItemContainerGrid")
                                local containerGrid = ItemContainerGrid.FindInstance(container, player:getPlayerNum())
                                if containerGrid then
                                    containerGrid:refresh()
                                end
                        end
                    end
                end
            end
        end
    end)
end

-- Request full world/vehicle data on load (still works for initial server→client sync)
Events.OnLoad.Add(function()
    ModData.request(WORLD_ITEM_DATA)
    ModData.request(VEHICLE_ITEM_DATA)
end)

-- OnReceiveGlobalModData was removed in B42 — partial/full sync now handled via syncWorldItemGrid / syncVehicleGrid commands
-- The OnLoad ModData.request above still pulls the saved ModData table from the server on join (initial load only)