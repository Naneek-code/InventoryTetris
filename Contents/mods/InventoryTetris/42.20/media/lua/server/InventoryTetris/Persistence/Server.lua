-- Smangsty: Keeps nested-grid persistence server-authoritative in multiplayer.
local OwnerResolver = require("InventoryTetris/Persistence/OwnerResolver")

local serverWarned = {}
-- Smangsty: Prevent repeated persistence warnings from flooding the server log.
local function warnOnce(key, message)
    if serverWarned[key] then
        return
    end
    serverWarned[key] = true
    print("[InventoryTetris] " .. message)
end

local okTetrisServer, TetrisServer = pcall(require, "InventoryTetris/Networking/TetrisServer")
if not okTetrisServer or type(TetrisServer) ~= "table" or type(TetrisServer.getOrCreateUuid) ~= "function" then
    warnOnce("TetrisServer", "Expected Build 42.20 Inventory Tetris server networking was not found; server hooks were not installed.")
    return
end
if TetrisServer.persistenceHooksInstalled then
    return
end
TetrisServer.persistenceHooksInstalled = true

-- Smangsty: Reject stale nested-grid writes using server timestamps.
local function validateTimestamps(existingGrid, incomingGrid)
    if type(existingGrid) ~= "table" or existingGrid.lastServerTime == nil then
        return true
    end
    if incomingGrid.lastServerTime == nil then
        return false
    end
    return incomingGrid.lastServerTime == existingGrid.lastServerTime
end

-- Smangsty: Return authoritative grid state when a client submits stale data.
local function sendCorrection(player, locator, itemID, existingGrid)
    if not player or not existingGrid then
        return
    end
    sendServerCommand(player, OwnerResolver.MODULE, OwnerResolver.SYNC_NESTED_ITEM_GRID, {
        owner = locator,
        targetItemID = itemID,
        gridContainers = existingGrid,
        sender = player:getUsername(),
        isCorrection = true,
    })
end

-- Smangsty: Preserve the server-authoritative character UUID across reconnects.
local function handleCharacterUUID(player, args)
    if type(args) ~= "table" or not player then
        return
    end

    local incomingUUID = OwnerResolver.normalizeCharacterUUID(args.characterUUID)
    if not incomingUUID then
        warnOnce("badCharacterUuid", "Rejected a malformed character UUID.")
        return
    end

    local modData = player:getModData()
    local authoritativeUUID = OwnerResolver.normalizeCharacterUUID(modData.TetrisUUID)
    if not authoritativeUUID then
        authoritativeUUID = incomingUUID
        modData.TetrisUUID = authoritativeUUID
    end

    -- Echo the authoritative value so a stale client cannot replace an existing identity.
    sendServerCommand(player, OwnerResolver.MODULE, OwnerResolver.SYNC_CHARACTER_UUID, {
        characterUUID = authoritativeUUID,
    })
end

-- Smangsty: Validate, persist, and broadcast nested-container grid updates in MP.
local function handleNestedItemGrid(player, args)
    if type(args) ~= "table" or not player then
        return
    end

    local locator = OwnerResolver.normalizeLocator(args.owner)
    local itemID = tonumber(args.targetItemID)
    if not locator or not itemID or itemID ~= math.floor(itemID) then
        return
    end

    local item, _, owner = OwnerResolver.resolveTargetItem(locator, itemID, player)
    if not item or not owner or not OwnerResolver.isPlayerNearOwner(player, owner) then
        return
    end
    if not item:getInventory() then
        return
    end

    local incomingGrid, payloadError = OwnerResolver.sanitizeGridContainers(args.gridContainers)
    if not incomingGrid then
        warnOnce("badNestedPayload", "Rejected malformed nested-grid data: " .. tostring(payloadError))
        return
    end

    local existingGrid = item:getModData().gridContainers
    if not validateTimestamps(existingGrid, incomingGrid) then
        sendCorrection(player, locator, itemID, existingGrid)
        return
    end

    incomingGrid.lastServerTime = getTimestampMs()
    item:getModData().gridContainers = incomingGrid

    if owner.flagForHotSave then
        owner:flagForHotSave()
    end

    sendServerCommand(OwnerResolver.MODULE, OwnerResolver.SYNC_NESTED_ITEM_GRID, {
        owner = locator,
        targetItemID = itemID,
        gridContainers = incomingGrid,
        sender = player:getUsername(),
    })
end

-- Smangsty: Dirty furniture save owners after existing IsoObject grid syncs.
local function flagInventoryTetrisObjectForSave(player, args)
    if type(args) ~= "table" then
        return
    end

    local object = OwnerResolver.findIsoObject({
        kind = "isoObject",
        x = args.x,
        y = args.y,
        z = args.z,
        objectIndex = args.objIndex,
        spriteName = args.spriteName,
        collection = "objects",
    })
    if object and OwnerResolver.isPlayerNearOwner(player, object) and object.flagForHotSave then
        object:flagForHotSave()
    end
end

-- Smangsty: Handle persistence commands on the core Inventory Tetris channel.
local function onClientCommand(module, command, player, args)
    local isPersistenceCommand = module == OwnerResolver.MODULE
        and (command == OwnerResolver.SYNC_CHARACTER_UUID or command == OwnerResolver.SYNC_NESTED_ITEM_GRID)
    local isFurnitureGridCommand = module == OwnerResolver.MODULE and command == "syncIsoObjectGrid"
    if not isPersistenceCommand and not isFurnitureGridCommand then
        return
    end

    if not isServer() then
        return
    end

    if isPersistenceCommand then
        if command == OwnerResolver.SYNC_CHARACTER_UUID then
            handleCharacterUUID(player, args)
            return
        end
        if command == OwnerResolver.SYNC_NESTED_ITEM_GRID then
            handleNestedItemGrid(player, args)
            return
        end
    end

    -- Inventory Tetris updates the table but does not dirty the chunk in this B42.20 fork.
    if isFurnitureGridCommand then
        flagInventoryTetrisObjectForSave(player, args)
    end
end

if Events and Events.OnClientCommand and Events.OnClientCommand.Add then
    Events.OnClientCommand.Add(onClientCommand)
else
    warnOnce("clientCommandEvent", "OnClientCommand is missing; multiplayer server hooks were not installed.")
    return
end

print("[InventoryTetris] Server persistence hooks installed.")
