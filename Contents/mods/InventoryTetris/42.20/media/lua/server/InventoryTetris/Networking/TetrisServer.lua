-- Keep these synced with the ones in TetrisClient.lua
local TETRIS_UUID = "TetrisUUID"

local WORLD_ITEM_DATA = "INVENTORYTETRIS_WorldItemData"
local VEHICLE_ITEM_DATA = "INVENTORYTETRIS_VehicleItemData"

local TetrisServer = {}

function TetrisServer.getOrCreateUuid(tableObj)
    local uuid = tableObj[TETRIS_UUID]
    if not uuid then
        uuid = getRandomUUID()
        tableObj[TETRIS_UUID] = uuid
    end
    return uuid
end

local function validateTimestamps(existingData, incomingData)
    if not existingData.lastServerTime then
        return true
    end

    if not incomingData.lastServerTime then
        return false
    end

    return incomingData.lastServerTime == existingData.lastServerTime
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

local function onClientCommand(module, command, player, args)
    if not isServer() then return end
    if module ~= "InventoryTetris" then return end
    
    if command == "syncItemGrid" then
        local item = findItemByID(player:getInventory(), args.itemID)
        if item then
            local sanitizedGrid = sanitizeGridContainers(args.gridContainers)
            local existingGrid = item:getModData().gridContainers
            
            if not existingGrid or validateTimestamps(existingGrid, sanitizedGrid) then
                sanitizedGrid.lastServerTime = getTimestampMs()
                item:getModData().gridContainers = sanitizedGrid
                
                args.gridContainers = sanitizedGrid
                sendServerCommand("InventoryTetris", "syncItemGrid", args)
            else
                -- Stale update: reject and send correction back to sender
                sendServerCommand(player, "InventoryTetris", "syncItemGrid", {
                    itemID = args.itemID,
                    gridContainers = existingGrid,
                    isCorrection = true,
                    sender = args.sender
                })
            end
        end

    elseif command == "syncWorldItemGrid" then
        -- World inventory object (bag on the floor) grid sync — replaces OnReceiveGlobalModData in B42
        if not args.itemID or not args.gridContainers then return end

        local sanitizedGrid = sanitizeGridContainers(args.gridContainers)
        local worldData = ModData.getOrCreate(WORLD_ITEM_DATA)
        local existingGrid = worldData[args.itemID]

        if not existingGrid or validateTimestamps(existingGrid, sanitizedGrid) then
            sanitizedGrid.lastServerTime = getTimestampMs()
            worldData[args.itemID] = sanitizedGrid
            ModData.add(WORLD_ITEM_DATA, worldData)

            -- Broadcast to all other clients
            sendServerCommand("InventoryTetris", "syncWorldItemGrid", {
                itemID = args.itemID,
                gridContainers = sanitizedGrid,
                sender = args.sender
            })
        else
            -- Stale: send correction back to sender
            sendServerCommand(player, "InventoryTetris", "syncWorldItemGrid", {
                itemID = args.itemID,
                gridContainers = existingGrid,
                isCorrection = true,
                sender = args.sender
            })
        end

    elseif command == "syncVehicleGrid" then
        -- Vehicle grid sync — replaces OnReceiveGlobalModData in B42
        if not args.vehicleKeyId or not args.gridContainers then return end

        local sanitizedGrid = sanitizeGridContainers(args.gridContainers)
        local vehicleData = ModData.getOrCreate(VEHICLE_ITEM_DATA)
        local existingGrid = vehicleData[args.vehicleKeyId]

        if not existingGrid or validateTimestamps(existingGrid, sanitizedGrid) then
            sanitizedGrid.lastServerTime = getTimestampMs()
            vehicleData[args.vehicleKeyId] = sanitizedGrid
            ModData.add(VEHICLE_ITEM_DATA, vehicleData)

            -- Broadcast to all other clients
            sendServerCommand("InventoryTetris", "syncVehicleGrid", {
                vehicleKeyId = args.vehicleKeyId,
                gridContainers = sanitizedGrid,
                sender = args.sender
            })
        else
            -- Stale: send correction back to sender
            sendServerCommand(player, "InventoryTetris", "syncVehicleGrid", {
                vehicleKeyId = args.vehicleKeyId,
                gridContainers = existingGrid,
                isCorrection = true,
                sender = args.sender
            })
        end

    elseif command == "syncPlayerGrid" then
        if not args.gridContainers then return end

        local sanitizedGrid = sanitizeGridContainers(args.gridContainers)
        local existingGrid = player:getModData().gridContainers
        
        if not existingGrid or validateTimestamps(existingGrid, sanitizedGrid) then
            sanitizedGrid.lastServerTime = getTimestampMs()
            player:getModData().gridContainers = sanitizedGrid
            
            args.gridContainers = sanitizedGrid
            sendServerCommand("InventoryTetris", "syncPlayerGrid", args)
        else
            -- Stale update: reject and send correction back to sender
            sendServerCommand(player, "InventoryTetris", "syncPlayerGrid", {
                gridContainers = existingGrid,
                isCorrection = true,
                sender = args.sender
            })
        end

    elseif command == "syncIsoObjectGrid" then
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
                local existingGrid = obj:getModData().gridContainers
                
                if not existingGrid or validateTimestamps(existingGrid, sanitizedGrid) then
                    sanitizedGrid.lastServerTime = getTimestampMs()
                    obj:getModData().gridContainers = sanitizedGrid
                    
                    args.gridContainers = sanitizedGrid
                    sendServerCommand("InventoryTetris", "syncIsoObjectGrid", args)
                else
                    -- Stale update: reject and send correction back to sender
                    sendServerCommand(player, "InventoryTetris", "syncIsoObjectGrid", {
                        x = args.x,
                        y = args.y,
                        z = args.z,
                        objIndex = args.objIndex,
                        spriteName = args.spriteName,
                        gridContainers = existingGrid,
                        isCorrection = true,
                        sender = args.sender
                    })
                end
            end
        end

    elseif command == "forceCapacity" then
        if SandboxVars.InventoryTetris.EnforceCarryWeight then return end
        
        local targetContainer = nil
        
        -- Legacy forceCapacity support, no-op in B42 (server-side capacity bypass not possible via Lua)
    end
end

Events.OnClientCommand.Add(onClientCommand)

-- Note: OnReceiveGlobalModData was removed in B42.
-- World item and vehicle grid data is now synced via syncWorldItemGrid / syncVehicleGrid client commands above.
-- The server still stores data in ModData.getOrCreate(WORLD_ITEM_DATA) / ModData.getOrCreate(VEHICLE_ITEM_DATA)
-- so that ModData.request() on client join (in TetrisClient.lua OnLoad) can still pull the persisted tables.

return TetrisServer
