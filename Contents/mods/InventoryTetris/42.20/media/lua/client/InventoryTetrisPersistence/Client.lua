local OwnerResolver = require("InventoryTetrisPersistence/OwnerResolver")

InventoryTetrisPersistence = InventoryTetrisPersistence or {}
if InventoryTetrisPersistence.clientPatched then
    return
end
InventoryTetrisPersistence.clientPatched = true

local warned = {}
local function warnOnce(key, message)
    if warned[key] then
        return
    end
    warned[key] = true
    print("[InventoryTetrisPersistence] " .. message)
end

local okItemGrid, ItemGrid = pcall(require, "InventoryTetris/Model/ItemGrid")
pcall(require, "InventoryTetris/Networking/TetrisClient")

if not okItemGrid or type(ItemGrid) ~= "table" then
    warnOnce("ItemGrid", "Inventory Tetris ItemGrid was not found; persistence hooks were not installed.")
    return
end
if type(TetrisClient) ~= "table" then
    warnOnce("TetrisClient", "Inventory Tetris networking was not found; persistence hooks were not installed.")
    return
end

local lastTransmittedByOwner = setmetatable({}, { __mode = "k" })
local lastTransmittedCharacterUUID = setmetatable({}, { __mode = "k" })

local function compareKeys(left, right)
    local leftType = type(left)
    local rightType = type(right)
    if leftType ~= rightType then
        return leftType < rightType
    end
    if leftType == "number" then
        return left < right
    end
    return tostring(left) < tostring(right)
end

local function appendSignature(value, output, seen)
    local valueType = type(value)
    if valueType ~= "table" then
        if valueType == "string" then
            output[#output + 1] = valueType .. ":" .. tostring(#value) .. ":" .. value .. ";"
        else
            output[#output + 1] = valueType .. ":" .. tostring(value) .. ";"
        end
        return
    end

    if seen[value] then
        output[#output + 1] = "<cycle>"
        return
    end
    seen[value] = true

    local keys = {}
    for key, _ in pairs(value) do
        if key ~= "lastServerTime" and key ~= "TetrisUUID"
            and not (type(key) == "string" and string.sub(key, 1, 1) == "_") then
            keys[#keys + 1] = key
        end
    end
    if #keys > 1 then
        table.sort(keys, compareKeys)
    end

    output[#output + 1] = "{"
    for _, key in ipairs(keys) do
        appendSignature(key, output, seen)
        output[#output + 1] = "="
        appendSignature(value[key], output, seen)
    end
    output[#output + 1] = "}"
    seen[value] = nil
end

local function getGridSignature(data)
    local output = {}
    appendSignature(data, output, {})
    return table.concat(output)
end

local function rememberSnapshot(owner, data)
    if owner and type(data) == "table" then
        lastTransmittedByOwner[owner] = getGridSignature(data)
    end
end

local function shouldTransmit(owner, data)
    if not owner or type(data) ~= "table" then
        return false
    end

    local signature = getGridSignature(data)
    if lastTransmittedByOwner[owner] == signature then
        return false
    end
    lastTransmittedByOwner[owner] = signature
    return true
end

local function createItemTransmissionSnapshot(locator, gridContainers)
    return {
        owner = locator or { kind = "unknown" },
        gridContainers = gridContainers,
    }
end

local function rememberItemSnapshot(item, locator, gridContainers)
    rememberSnapshot(item, createItemTransmissionSnapshot(locator, gridContainers))
end

local function flagInventoryOwnerForSave(inventory)
    local owner = OwnerResolver.getSaveOwnerForInventory(inventory)
    if owner and owner.flagForHotSave then
        owner:flagForHotSave()
    end
end

if type(ItemGrid._sendModData) == "function" then
    local originalSendModData = ItemGrid._sendModData
    function ItemGrid:_sendModData(...)
        originalSendModData(self, ...)

        -- In solo, changing Lua modData alone does not dirty the owning chunk.
        if not isClient() then
            flagInventoryOwnerForSave(self.inventory)
        end
    end
else
    warnOnce("sendModData", "ItemGrid._sendModData is missing; solo hot-save support is disabled.")
end

if type(TetrisClient.transmitWorldInventoryObjectData) == "function" then
    local originalTransmitWorldInventoryObjectData = TetrisClient.transmitWorldInventoryObjectData
    function TetrisClient.transmitWorldInventoryObjectData(worldObject)
        local item = worldObject and worldObject:getItem() or nil
        local gridContainers = item and item:getModData().gridContainers or nil
        if not shouldTransmit(worldObject, gridContainers) then
            return
        end
        return originalTransmitWorldInventoryObjectData(worldObject)
    end
else
    warnOnce("worldItemSync", "TetrisClient.transmitWorldInventoryObjectData is missing; ground-container sync is disabled.")
end

if type(TetrisClient.transmitVehicleInventoryData) == "function" then
    local originalTransmitVehicleInventoryData = TetrisClient.transmitVehicleInventoryData
    function TetrisClient.transmitVehicleInventoryData(vehicle)
        local gridContainers = vehicle and vehicle:getModData().gridContainers or nil
        if not shouldTransmit(vehicle, gridContainers) then
            return
        end
        return originalTransmitVehicleInventoryData(vehicle)
    end
else
    warnOnce("vehicleSync", "TetrisClient.transmitVehicleInventoryData is missing; vehicle-container sync is disabled.")
end

if type(TetrisClient.getInventoryContainerModData) == "function" then
    local originalGetInventoryContainerModData = TetrisClient.getInventoryContainerModData
    function TetrisClient.getInventoryContainerModData(item)
        local modData = originalGetInventoryContainerModData(item)
        local worldObject = item and item:getWorldItem() or nil
        return modData, worldObject or item
    end
else
    warnOnce("containerModData", "TetrisClient.getInventoryContainerModData is missing; carried-container sync is disabled.")
end

if type(TetrisClient.transmitPlayerGridData) == "function" then
    local originalTransmitPlayerGridData = TetrisClient.transmitPlayerGridData
    function TetrisClient.transmitPlayerGridData(playerObject)
        if not playerObject then
            return
        end

        local characterUUID = OwnerResolver.normalizeCharacterUUID(playerObject:getModData().TetrisUUID)
        if characterUUID and lastTransmittedCharacterUUID[playerObject] ~= characterUUID then
            lastTransmittedCharacterUUID[playerObject] = characterUUID
            sendClientCommand(playerObject, OwnerResolver.MODULE, OwnerResolver.SYNC_CHARACTER_UUID, {
                characterUUID = characterUUID,
            })
        end

        -- Preserve Inventory Tetris's timestamped player-grid command and stale correction path.
        return originalTransmitPlayerGridData(playerObject)
    end
else
    warnOnce("characterUuidSync", "TetrisClient.transmitPlayerGridData is missing; character UUID sync is disabled.")
end

if type(TetrisClient.transmitIsoObjectGridData) == "function" then
    local originalTransmitIsoObjectGridData = TetrisClient.transmitIsoObjectGridData
    function TetrisClient.transmitIsoObjectGridData(object)
        local gridContainers = object and object:getModData().gridContainers or nil
        if not shouldTransmit(object, gridContainers) then
            return
        end
        return originalTransmitIsoObjectGridData(object)
    end
else
    warnOnce("isoObjectSync", "TetrisClient.transmitIsoObjectGridData is missing; IsoObject grid sync is disabled.")
end

if type(TetrisClient.transmitInventoryItemGridData) == "function" then
    local originalTransmitInventoryItemGridData = TetrisClient.transmitInventoryItemGridData
    function TetrisClient.transmitInventoryItemGridData(item)
        if not item then
            return
        end

        local worldObject = item:getWorldItem()
        if worldObject then
            if type(TetrisClient.transmitWorldInventoryObjectData) == "function" then
                TetrisClient.transmitWorldInventoryObjectData(worldObject)
            end
            return
        end

        local gridContainers = item:getModData().gridContainers
        local locator = OwnerResolver.describeItemOwner(item)
        if not locator or locator.kind == "player" then
            local playerLocator = locator or { kind = "unknown" }
            if not shouldTransmit(item, createItemTransmissionSnapshot(playerLocator, gridContainers)) then
                return
            end
            return originalTransmitInventoryItemGridData(item)
        end

        local player = getPlayer()
        if not gridContainers or not player then
            return
        end

        local sanitizedGrid, err = OwnerResolver.sanitizeGridContainers(gridContainers)
        if not sanitizedGrid then
            warnOnce("badClientPayload", "Refused to send malformed nested-grid data: " .. tostring(err))
            return
        end
        if not shouldTransmit(item, createItemTransmissionSnapshot(locator, sanitizedGrid)) then
            return
        end

        sendClientCommand(player, OwnerResolver.MODULE, OwnerResolver.SYNC_NESTED_ITEM_GRID, {
            owner = locator,
            targetItemID = item:getID(),
            gridContainers = sanitizedGrid,
            sender = player:getUsername(),
        })
    end
else
    warnOnce("itemSync", "TetrisClient.transmitInventoryItemGridData is missing; nested-container sync is disabled.")
end

local function markRecentlySyncedItemIDs(value, now, seen)
    if type(value) ~= "table" or seen[value] then
        return
    end
    seen[value] = true

    if type(value.itemIDs) == "table" and TetrisClient.recentlySyncedItems then
        for itemID, present in pairs(value.itemIDs) do
            if present then
                TetrisClient.recentlySyncedItems[tonumber(itemID) or itemID] = now
            end
        end
    end

    for _, child in pairs(value) do
        if type(child) == "table" then
            markRecentlySyncedItemIDs(child, now, seen)
        end
    end
    seen[value] = nil
end

local function refreshTargetInventory(item)
    local inventory = item and item:getInventory() or nil
    local player = getPlayer()
    if not inventory or not player then
        return
    end

    local ok, ItemContainerGrid = pcall(require, "InventoryTetris/Model/ItemContainerGrid")
    if not ok or type(ItemContainerGrid) ~= "table" or type(ItemContainerGrid.FindInstance) ~= "function" then
        warnOnce("containerGridModel", "Inventory Tetris ItemContainerGrid.FindInstance is missing; remote grid refresh is disabled.")
        return
    end

    local containerGrid = ItemContainerGrid.FindInstance(inventory, player:getPlayerNum())
    if not containerGrid then
        return
    end

    local previousSuppressSync = TetrisClient.suppressSync
    InventoryTetrisPersistence.applyingRemoteSync = true
    TetrisClient.suppressSync = true
    local refreshed, refreshError = pcall(containerGrid.refresh, containerGrid)
    TetrisClient.suppressSync = previousSuppressSync
    InventoryTetrisPersistence.applyingRemoteSync = false
    if not refreshed then
        warnOnce("remoteRefresh", "Could not refresh a remotely updated grid: " .. tostring(refreshError))
    end
end

local function forEachCachedContainerGrid(callback)
    local ok, ItemContainerGrid = pcall(require, "InventoryTetris/Model/ItemContainerGrid")
    if not ok or type(ItemContainerGrid) ~= "table" or type(ItemContainerGrid._gridCache) ~= "table" then
        return
    end

    for _, grids in pairs(ItemContainerGrid._gridCache) do
        if type(grids) == "table" then
            for _, containerGrid in ipairs(grids) do
                local callbackOk, callbackError = pcall(callback, containerGrid)
                if not callbackOk then
                    warnOnce("gridCacheShape", "Inventory Tetris grid cache is incompatible: " .. tostring(callbackError))
                end
            end
        end
    end
end

local rememberedInventoryTetrisCommands = {
    syncItemGrid = true,
    syncWorldItemGrid = true,
    syncVehicleGrid = true,
    syncIsoObjectGrid = true,
}

local function rememberInventoryTetrisCommand(command, args, player)
    if not rememberedInventoryTetrisCommands[command] then
        return
    end
    if type(args) ~= "table" or type(args.gridContainers) ~= "table" then
        return
    end

    local sanitizedGrid = OwnerResolver.sanitizeGridContainers(args.gridContainers)
    if not sanitizedGrid then
        return
    end

    if command == "syncItemGrid" then
        local item = OwnerResolver.findItemInContainer(player:getInventory(), tonumber(args.itemID))
        rememberItemSnapshot(item, { kind = "player" }, sanitizedGrid)
    elseif command == "syncWorldItemGrid" then
        forEachCachedContainerGrid(function(containerGrid)
            local containingItem = containerGrid.inventory and containerGrid.inventory:getContainingItem() or nil
            local worldObject = containingItem and containingItem:getWorldItem() or nil
            if worldObject and containingItem:getID() == tonumber(args.itemID) then
                rememberSnapshot(worldObject, sanitizedGrid)
            end
        end)
    elseif command == "syncVehicleGrid" then
        forEachCachedContainerGrid(function(containerGrid)
            local owner = OwnerResolver.getSaveOwnerForInventory(containerGrid.inventory)
            if owner and instanceof(owner, "BaseVehicle") and owner:getKeyId() == args.vehicleKeyId then
                rememberSnapshot(owner, sanitizedGrid)
            end
        end)
    elseif command == "syncIsoObjectGrid" then
        local object = OwnerResolver.findIsoObject({
            kind = "isoObject",
            x = args.x,
            y = args.y,
            z = args.z,
            objectIndex = args.objIndex,
            spriteName = args.spriteName,
            collection = "objects",
        })
        rememberSnapshot(object, sanitizedGrid)
    end
end

local function onServerCommand(module, command, args)
    local isInventoryTetrisCommand = module == "InventoryTetris"
    local isPersistenceCommand = module == OwnerResolver.MODULE
    if not isInventoryTetrisCommand and not isPersistenceCommand then
        return
    end
    if type(args) ~= "table" then
        return
    end

    if isInventoryTetrisCommand then
        if not rememberedInventoryTetrisCommands[command] then
            return
        end
        local inventoryTetrisPlayer = getPlayer()
        if inventoryTetrisPlayer then
            rememberInventoryTetrisCommand(command, args, inventoryTetrisPlayer)
        end
        return
    end

    if command ~= OwnerResolver.SYNC_CHARACTER_UUID and command ~= OwnerResolver.SYNC_NESTED_ITEM_GRID then
        return
    end

    local player = getPlayer()
    if not player then
        return
    end

    if command == OwnerResolver.SYNC_CHARACTER_UUID then
        local characterUUID = OwnerResolver.normalizeCharacterUUID(args.characterUUID)
        if not characterUUID then
            warnOnce("badCharacterUuidResponse", "Ignored a malformed character UUID response.")
            return
        end

        player:getModData().TetrisUUID = characterUUID
        lastTransmittedCharacterUUID[player] = characterUUID
        return
    end

    if command ~= OwnerResolver.SYNC_NESTED_ITEM_GRID then
        return
    end

    local itemID = tonumber(args.targetItemID)
    if not itemID then
        return
    end

    local item = OwnerResolver.resolveTargetItem(args.owner, itemID, player)
    if not item then
        return
    end

    local sanitizedGrid, err = OwnerResolver.sanitizeGridContainers(args.gridContainers)
    if not sanitizedGrid then
        warnOnce("badServerPayload", "Ignored a malformed nested-grid response: " .. tostring(err))
        return
    end

    local currentGrid = item:getModData().gridContainers
    local isOwnAcceptedUpdate = args.sender == player:getUsername() and not args.isCorrection
    if isOwnAcceptedUpdate then
        if type(currentGrid) == "table" then
            currentGrid.lastServerTime = sanitizedGrid.lastServerTime
        else
            item:getModData().gridContainers = sanitizedGrid
        end
        rememberItemSnapshot(item, args.owner, item:getModData().gridContainers)
        return
    end

    markRecentlySyncedItemIDs(sanitizedGrid, getTimestampMs(), {})
    item:getModData().gridContainers = sanitizedGrid
    rememberItemSnapshot(item, args.owner, sanitizedGrid)
    refreshTargetInventory(item)
end

if Events and Events.OnServerCommand and Events.OnServerCommand.Add then
    Events.OnServerCommand.Add(onServerCommand)
else
    warnOnce("serverCommandEvent", "OnServerCommand is missing; multiplayer persistence sync is disabled.")
end

local globalDataTags = {
    [OwnerResolver.WORLD_ITEM_DATA] = true,
    [OwnerResolver.VEHICLE_ITEM_DATA] = true,
}

local function onReceiveGlobalModData(tag, data)
    if not globalDataTags[tag] or type(data) ~= "table" or not isClient() then
        return
    end

    if type(ModData) ~= "table" or type(ModData.add) ~= "function" then
        warnOnce("globalModDataApi", "ModData.add is missing; persisted ground and vehicle tables cannot be restored.")
        return
    end
    ModData.add(tag, data)

    forEachCachedContainerGrid(function(containerGrid)
        if type(containerGrid.refresh) == "function" then
            containerGrid:refresh()
        end
        local inventory = containerGrid.inventory
        local containingItem = inventory and inventory:getContainingItem() or nil
        local worldObject = containingItem and containingItem:getWorldItem() or nil
        local owner = OwnerResolver.getSaveOwnerForInventory(inventory)
        if tag == OwnerResolver.WORLD_ITEM_DATA and worldObject then
            rememberSnapshot(worldObject, containingItem:getModData().gridContainers)
        elseif tag == OwnerResolver.VEHICLE_ITEM_DATA and owner and instanceof(owner, "BaseVehicle") then
            rememberSnapshot(owner, owner:getModData().gridContainers)
        end
    end)
end

if Events and Events.OnReceiveGlobalModData and Events.OnReceiveGlobalModData.Add then
    Events.OnReceiveGlobalModData.Add(onReceiveGlobalModData)
else
    warnOnce("globalModDataEvent", "OnReceiveGlobalModData is missing; persisted ground and vehicle tables cannot be restored.")
end

local TETRIS_UUID = "TetrisUUID"
local function ensureCharacterUUID(playerNum, player)
    local playerObject = player or getSpecificPlayer(playerNum)
    if not playerObject or not playerObject.getModData then
        return
    end

    local modData = playerObject:getModData()
    if not modData[TETRIS_UUID] then
        if type(getRandomUUID) ~= "function" then
            warnOnce("uuidApi", "getRandomUUID is missing; character search UUID persistence is disabled.")
            return
        end
        modData[TETRIS_UUID] = getRandomUUID()
    end

    if isClient() and type(TetrisClient.queueModDataSync) == "function" then
        TetrisClient.queueModDataSync(playerObject)
    elseif isClient() then
        warnOnce("uuidSync", "TetrisClient.queueModDataSync is missing; character search UUID sync is disabled.")
    end
end

if Events and Events.OnCreatePlayer and Events.OnCreatePlayer.Add then
    Events.OnCreatePlayer.Add(ensureCharacterUUID)
else
    warnOnce("createPlayerEvent", "OnCreatePlayer is missing; character search UUID creation is delayed until game start.")
end

local function onGameStart()
    local player = getPlayer()
    if player then
        ensureCharacterUUID(player:getPlayerNum(), player)
    end
end

if Events and Events.OnGameStart and Events.OnGameStart.Add then
    Events.OnGameStart.Add(onGameStart)
else
    warnOnce("gameStartEvent", "OnGameStart is missing; character search UUID persistence is disabled.")
end

print("[InventoryTetrisPersistence] Client persistence hooks installed.")
