-- Smangsty: Resolves and validates persistence owners for SP/MP grid saves.
local OwnerResolver = {}

OwnerResolver.MODULE = "InventoryTetris"
OwnerResolver.SYNC_NESTED_ITEM_GRID = "syncNestedItemGrid"
OwnerResolver.SYNC_CHARACTER_UUID = "syncCharacterUUID"
OwnerResolver.WORLD_ITEM_DATA = "INVENTORYTETRIS_WorldItemData"
OwnerResolver.VEHICLE_ITEM_DATA = "INVENTORYTETRIS_VehicleItemData"

local MAX_TABLE_DEPTH = 12
local MAX_TABLE_ENTRIES = 20000
local MAX_STRING_LENGTH = 1024
local MAX_CHARACTER_UUID_LENGTH = 128
local MAX_SYNC_DISTANCE_SQ = 10 * 10

-- Smangsty: Reject NaN and infinite values before persistence/network serialization.
local function isFiniteNumber(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Smangsty: Deep-copy persistence payloads while enforcing safe value limits.
local function sanitizeValue(value, depth, budget, seen)
    local valueType = type(value)

    if valueType == "nil" or valueType == "boolean" then
        return value
    end

    if valueType == "number" then
        if not isFiniteNumber(value) then
            return nil, "non-finite number"
        end
        return value
    end

    if valueType == "string" then
        if #value > MAX_STRING_LENGTH then
            return nil, "string is too long"
        end
        return value
    end

    if valueType ~= "table" then
        return nil, "unsupported value type"
    end

    if depth > MAX_TABLE_DEPTH then
        return nil, "table is too deep"
    end

    if seen[value] then
        return nil, "cyclic table"
    end
    seen[value] = true

    local copy = {}
    for key, childValue in pairs(value) do
        local keyType = type(key)
        -- ItemStack caches Java InventoryItem references in underscore-prefixed fields.
        -- They are runtime-only and must never enter a network snapshot.
        if keyType == "string" and string.sub(key, 1, 1) == "_" then
            -- Deliberately omitted.
        else
            budget.count = budget.count + 1
            if budget.count > MAX_TABLE_ENTRIES then
                seen[value] = nil
                return nil, "table has too many entries"
            end

            if keyType ~= "number" and keyType ~= "string" then
                seen[value] = nil
                return nil, "unsupported key type"
            end

            if keyType == "number" and not isFiniteNumber(key) then
                seen[value] = nil
                return nil, "non-finite numeric key"
            end

            if keyType == "string" and #key > MAX_STRING_LENGTH then
                seen[value] = nil
                return nil, "key is too long"
            end

            local normalizedKey = key
            if keyType == "string" then
                local numericKey = tonumber(key)
                if numericKey then
                    normalizedKey = numericKey
                end
            end

            local sanitizedChild, err = sanitizeValue(childValue, depth + 1, budget, seen)
            if err then
                seen[value] = nil
                return nil, err
            end
            copy[normalizedKey] = sanitizedChild
        end
    end

    seen[value] = nil
    return copy
end

-- Smangsty: Validate persisted Tetris stack coordinates and item-ID maps.
local function validateStackList(stacks)
    for stackIndex, stack in pairs(stacks) do
        if type(stackIndex) ~= "number" or stackIndex < 1 or stackIndex ~= math.floor(stackIndex) then
            return nil, "stacks must use positive integer indexes"
        end
        if type(stack) ~= "table" or type(stack.itemIDs) ~= "table" then
            return nil, "each stack must contain an itemIDs table"
        end
        if not isFiniteNumber(stack.x) or not isFiniteNumber(stack.y) then
            return nil, "each stack must contain finite coordinates"
        end
        if stack.x ~= math.floor(stack.x) or stack.y ~= math.floor(stack.y)
            or math.abs(stack.x) > 10000 or math.abs(stack.y) > 10000 then
            return nil, "stack coordinates are out of range"
        end
        if stack.isRotated ~= nil and type(stack.isRotated) ~= "boolean" then
            return nil, "stack rotation must be boolean"
        end
        if stack.count ~= nil and (not isFiniteNumber(stack.count) or stack.count < 0) then
            return nil, "stack count is invalid"
        end
        if stack.itemType ~= nil and type(stack.itemType) ~= "string" then
            return nil, "stack itemType must be a string"
        end
        if stack.category ~= nil and type(stack.category) ~= "string" then
            return nil, "stack category must be a string"
        end
        for itemID, present in pairs(stack.itemIDs) do
            if not isFiniteNumber(itemID) or itemID ~= math.floor(itemID) or type(present) ~= "boolean" then
                return nil, "stack itemIDs are invalid"
            end
        end
    end
    return true
end

-- Smangsty: Validate persisted search-state data before accepting it.
local function validateSearchLog(searchLog)
    for characterUUID, searched in pairs(searchLog) do
        if type(characterUUID) ~= "string" or type(searched) ~= "boolean" then
            return nil, "searchLog entries are invalid"
        end
    end
    return true
end

-- Smangsty: Recursively validate known grid structures after sanitization.
local function validateKnownGridFields(value, seen)
    if seen[value] then
        return true
    end
    seen[value] = true

    for key, child in pairs(value) do
        if key == "lastServerTime" then
            if not isFiniteNumber(child) then
                return nil, "lastServerTime must be finite"
            end
        elseif key == "stacks" then
            if type(child) ~= "table" then
                return nil, "stacks must be a table"
            end
            local ok, err = validateStackList(child)
            if not ok then
                return nil, err
            end
        elseif key == "searchLog" then
            if type(child) ~= "table" then
                return nil, "searchLog must be a table"
            end
            local ok, err = validateSearchLog(child)
            if not ok then
                return nil, err
            end
        elseif type(child) == "table" then
            local ok, err = validateKnownGridFields(child, seen)
            if not ok then
                return nil, err
            end
        end
    end
    return true
end

-- Smangsty: Sanitize and validate gridContainers before save or network use.
function OwnerResolver.sanitizeGridContainers(gridContainers)
    if type(gridContainers) ~= "table" then
        return nil, "gridContainers must be a table"
    end

    local copy, err = sanitizeValue(gridContainers, 1, { count = 0 }, {})
    if not copy then
        return nil, err
    end

    for key, value in pairs(copy) do
        if key == "lastServerTime" then
            if not isFiniteNumber(value) then
                return nil, "lastServerTime must be finite"
            end
        elseif key == "TetrisUUID" then
            if type(value) ~= "number" and type(value) ~= "string" then
                return nil, "TetrisUUID is invalid"
            end
        elseif type(value) ~= "table" then
            return nil, "gridContainers roots must be tables"
        end
    end

    local valid, shapeError = validateKnownGridFields(copy, {})
    if not valid then
        return nil, shapeError
    end
    return copy
end

-- Smangsty: Normalize persistent character UUIDs to a bounded safe string.
function OwnerResolver.normalizeCharacterUUID(value)
    if type(value) ~= "string" or #value < 1 or #value > MAX_CHARACTER_UUID_LENGTH then
        return nil
    end
    return value
end

-- Smangsty: Normalize locator coordinates and indexes to exact integers.
local function normalizeInteger(value)
    if not isFiniteNumber(value) or value ~= math.floor(value) then
        return nil
    end
    return value
end

-- Smangsty: Validate and normalize supported persistence-owner locator shapes.
function OwnerResolver.normalizeLocator(locator)
    if type(locator) ~= "table" or type(locator.kind) ~= "string" then
        return nil
    end

    if locator.kind == "player" then
        return { kind = "player" }
    end

    if locator.kind == "vehicle" then
        local vehicleId = normalizeInteger(locator.vehicleId)
        if not vehicleId or vehicleId < 0 or type(locator.partId) ~= "string" or #locator.partId > 128 then
            return nil
        end
        return {
            kind = "vehicle",
            vehicleId = vehicleId,
            partId = locator.partId,
        }
    end

    if locator.kind == "ground" then
        local x = normalizeInteger(locator.x)
        local y = normalizeInteger(locator.y)
        local z = normalizeInteger(locator.z)
        local rootItemID = normalizeInteger(locator.rootItemID)
        if not x or not y or not z or not rootItemID or rootItemID < 0 then
            return nil
        end
        return {
            kind = "ground",
            x = x,
            y = y,
            z = z,
            rootItemID = rootItemID,
        }
    end

    if locator.kind == "isoObject" then
        local x = normalizeInteger(locator.x)
        local y = normalizeInteger(locator.y)
        local z = normalizeInteger(locator.z)
        local objectIndex = normalizeInteger(locator.objectIndex)
        local containerIndex = locator.containerIndex ~= nil and normalizeInteger(locator.containerIndex) or nil
        local collection = locator.collection == "staticMovingObjects" and "staticMovingObjects" or "objects"

        if not x or not y or not z or objectIndex == nil or objectIndex < 0
            or (containerIndex ~= nil and containerIndex < 0) then
            return nil
        end
        if locator.spriteName ~= nil and (type(locator.spriteName) ~= "string" or #locator.spriteName > 256) then
            return nil
        end

        return {
            kind = "isoObject",
            x = x,
            y = y,
            z = z,
            objectIndex = objectIndex,
            containerIndex = containerIndex,
            collection = collection,
            spriteName = locator.spriteName,
        }
    end

    return nil
end

-- Smangsty: Resolve the requested IsoGridSquare object collection safely.
local function getCollection(square, collectionName)
    if not square then
        return nil
    end
    if collectionName == "staticMovingObjects" and square.getStaticMovingObjects then
        return square:getStaticMovingObjects()
    end
    return square:getObjects()
end

-- Smangsty: Read a stable sprite discriminator for IsoObject resolution.
local function getObjectSpriteName(object)
    local sprite = object and object:getSprite() or nil
    return sprite and sprite:getName() or nil
end

-- Smangsty: Verify a resolved IsoObject still matches its persistent locator.
local function objectMatchesLocator(object, locator)
    if not object then
        return false
    end

    if locator.spriteName and getObjectSpriteName(object) ~= locator.spriteName then
        return false
    end

    if locator.containerIndex ~= nil then
        if not object.getContainerByIndex or not object:getContainerByIndex(locator.containerIndex) then
            return false
        end
    elseif not object:getContainer() and (not object.getContainerCount or object:getContainerCount() <= 0) then
        return false
    end

    return true
end

-- Smangsty: Resolve persisted furniture/IsoObject owners from world coordinates.
function OwnerResolver.findIsoObject(locator)
    locator = OwnerResolver.normalizeLocator(locator)
    if not locator or locator.kind ~= "isoObject" then
        return nil
    end

    local square = getCell():getGridSquare(locator.x, locator.y, locator.z)
    local objects = getCollection(square, locator.collection)
    if not objects then
        return nil
    end

    if locator.objectIndex >= 0 and locator.objectIndex < objects:size() then
        local indexedObject = objects:get(locator.objectIndex)
        if objectMatchesLocator(indexedObject, locator) then
            return indexedObject
        end
    end

    if not locator.spriteName then
        return nil
    end

    local match = nil
    for index = 0, objects:size() - 1 do
        local candidate = objects:get(index)
        if objectMatchesLocator(candidate, locator) then
            if match then
                return nil -- Ambiguous fallback; never update an arbitrary object.
            end
            match = candidate
        end
    end
    return match
end

-- Smangsty: Resolve persisted ground-item owners from world coordinates.
function OwnerResolver.findWorldInventoryObject(locator)
    locator = OwnerResolver.normalizeLocator(locator)
    if not locator or locator.kind ~= "ground" then
        return nil
    end

    local square = getCell():getGridSquare(locator.x, locator.y, locator.z)
    local worldObjects = square and square:getWorldObjects() or nil
    if not worldObjects then
        return nil
    end

    for index = 0, worldObjects:size() - 1 do
        local worldObject = worldObjects:get(index)
        local item = worldObject and worldObject:getItem() or nil
        if item and item:getID() == locator.rootItemID then
            return worldObject
        end
    end
    return nil
end

-- Smangsty: Capture a stable object index for persistence locators when available.
local function getObjectIndex(object, collection)
    local index = collection:indexOf(object)
    if index ~= -1 then
        return index
    end

    for candidateIndex = 0, collection:size() - 1 do
        if collection:get(candidateIndex) == object then
            return candidateIndex
        end
    end
    return -1
end

-- Smangsty: Identify the exact container slot owned by an IsoObject.
local function getContainerIndex(object, container)
    if not object or not object.getContainerCount or not object.getContainerByIndex then
        return nil
    end

    for index = 0, object:getContainerCount() - 1 do
        if object:getContainerByIndex(index) == container then
            return index
        end
    end
    return nil
end

-- Smangsty: Build a bounded locator for furniture-owned nested containers.
local function createIsoObjectLocator(object, container)
    local square = object and object:getSquare() or nil
    if not square then
        return nil
    end

    local collectionName = "objects"
    local collection = square:getObjects()
    local objectIndex = getObjectIndex(object, collection)

    if objectIndex == -1 and square.getStaticMovingObjects then
        collectionName = "staticMovingObjects"
        collection = square:getStaticMovingObjects()
        objectIndex = getObjectIndex(object, collection)
    end

    if objectIndex == -1 then
        return nil
    end

    return OwnerResolver.normalizeLocator({
        kind = "isoObject",
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        objectIndex = objectIndex,
        containerIndex = getContainerIndex(object, container),
        collection = collectionName,
        spriteName = getObjectSpriteName(object),
    })
end

-- Smangsty: Match vehicle containers to their owning vehicle part.
local function findVehiclePartForContainer(vehicle, container)
    if not vehicle or not vehicle.getPartCount then
        return nil
    end
    for index = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(index)
        if part and part:getItemContainer() == container then
            return part
        end
    end
    return nil
end

-- Smangsty: Describe the authoritative persistent owner of a nested inventory item.
function OwnerResolver.describeItemOwner(item)
    if not item or not item.getOutermostContainer then
        return nil
    end

    local rootContainer = item:getOutermostContainer()
    if not rootContainer then
        return nil
    end

    local vehiclePart = rootContainer.getVehiclePart and rootContainer:getVehiclePart() or nil
    local parent = rootContainer:getParent()
    if not vehiclePart and parent and instanceof(parent, "BaseVehicle") then
        vehiclePart = findVehiclePartForContainer(parent, rootContainer)
    end

    if vehiclePart then
        local vehicle = vehiclePart:getVehicle()
        if vehicle then
            return OwnerResolver.normalizeLocator({
                kind = "vehicle",
                vehicleId = vehicle:getId(),
                partId = vehiclePart:getId(),
            }), rootContainer, vehicle
        end
    end

    if parent and instanceof(parent, "IsoPlayer") then
        return { kind = "player" }, rootContainer, parent
    end

    local rootItem = rootContainer.getContainingItem and rootContainer:getContainingItem() or nil
    local worldObject = rootItem and rootItem:getWorldItem() or nil
    if worldObject then
        local square = worldObject:getSquare()
        if rootItem and worldObject:getItem() == rootItem and square then
            return OwnerResolver.normalizeLocator({
                kind = "ground",
                x = square:getX(),
                y = square:getY(),
                z = square:getZ(),
                rootItemID = rootItem:getID(),
            }), rootContainer, worldObject
        end
    end

    if parent and instanceof(parent, "IsoObject") then
        return createIsoObjectLocator(parent, rootContainer), rootContainer, parent
    end

    return nil
end

-- Smangsty: Resolve a normalized owner locator against current world/player state.
function OwnerResolver.resolveLocator(locator, player)
    locator = OwnerResolver.normalizeLocator(locator)
    if not locator then
        return nil
    end

    if locator.kind == "player" then
        if not player then
            return nil
        end
        return player:getInventory(), player
    end

    if locator.kind == "vehicle" then
        local vehicle = getVehicleById(locator.vehicleId)
        local part = vehicle and vehicle:getPartById(locator.partId) or nil
        local container = part and part:getItemContainer() or nil
        if container then
            return container, vehicle
        end
        return nil
    end

    if locator.kind == "ground" then
        local worldObject = OwnerResolver.findWorldInventoryObject(locator)
        local rootItem = worldObject and worldObject:getItem() or nil
        local container = rootItem and rootItem:getInventory() or nil
        if container then
            return container, worldObject, rootItem
        end
        return nil
    end

    if locator.kind == "isoObject" then
        local object = OwnerResolver.findIsoObject(locator)
        if not object then
            return nil
        end

        local container = nil
        if locator.containerIndex ~= nil and object.getContainerByIndex then
            container = object:getContainerByIndex(locator.containerIndex)
        else
            container = object:getContainer()
        end

        if container then
            return container, object
        end
    end

    return nil
end

-- Smangsty: Recursively find a real inventory item by persistent item ID.
function OwnerResolver.findItemInContainer(container, itemID)
    if not container or not itemID then
        return nil
    end

    local item = container:getItemWithID(itemID)
    if item then
        return item
    end

    if container.getItemWithIDRecursiv then
        return container:getItemWithIDRecursiv(itemID)
    end
    return nil
end

-- Smangsty: Resolve a nested target item only through its authoritative owner.
function OwnerResolver.resolveTargetItem(locator, itemID, player)
    local rootContainer, owner = OwnerResolver.resolveLocator(locator, player)
    if not rootContainer then
        return nil
    end
    return OwnerResolver.findItemInContainer(rootContainer, itemID), rootContainer, owner
end

-- Smangsty: Find the world object that must be dirtied for an inventory to persist in SP.
function OwnerResolver.getSaveOwnerForInventory(inventory)
    if not inventory then
        return nil
    end

    local containingItem = inventory:getContainingItem()
    if containingItem then
        local _, _, owner = OwnerResolver.describeItemOwner(containingItem)
        if owner and not instanceof(owner, "IsoPlayer") then
            return owner
        end

        local worldObject = containingItem:getWorldItem()
        if worldObject then
            return worldObject
        end
    end

    local parent = inventory:getParent()
    if parent and instanceof(parent, "VehiclePart") then
        return parent:getVehicle()
    end
    if parent and instanceof(parent, "IsoPlayer") then
        return nil
    end
    if parent and instanceof(parent, "IsoObject") then
        return parent
    end
    return nil
end

-- Smangsty: Require MP clients to be near world owners before accepting writes.
function OwnerResolver.isPlayerNearOwner(player, owner)
    if not player or not owner then
        return false
    end
    if owner == player then
        return true
    end

    local square = owner.getSquare and owner:getSquare() or nil
    if not square then
        return false
    end

    if math.floor(player:getZ()) ~= square:getZ() then
        return false
    end
    return player:DistToSquared(square:getX() + 0.5, square:getY() + 0.5) <= MAX_SYNC_DISTANCE_SQ
end

return OwnerResolver
