--==============================================================================
-- INVENTORY TETRIS CONFIG FILE
--==============================================================================

TetrisMPConfig = {}

TetrisMPConfig.USE_SANDBOX_OPTIONS = true
TetrisMPConfig.ITEM_WEIGHT_MULTIPLIER = 1.0

local SANDBOX_KEYS = {
    ITEM_WEIGHT_MULTIPLIER = "ItemWeightMultiplier",
}

function TetrisMPConfig.get(field)
    local fallback = TetrisMPConfig[field]
    if type(fallback) ~= "number" then
        fallback = 1.0
    end

    if not TetrisMPConfig.USE_SANDBOX_OPTIONS then
        return fallback
    end

    local sandboxKey = SANDBOX_KEYS[field]
    if not sandboxKey then
        return fallback
    end

    local sv = SandboxVars and SandboxVars.InventoryTetris
    if not sv then
        return fallback
    end

    local value = tonumber(sv[sandboxKey])
    if value == nil then
        return fallback
    end

    return value
end

function TetrisMPConfig.getItemWeightMultiplier()
    local value = TetrisMPConfig.get("ITEM_WEIGHT_MULTIPLIER")

    if type(value) ~= "number" or value ~= value then
        return 1.0
    end
    if value <= 0 then
        return 1.0
    end
    if value > 1.0 then
        return 1.0
    end

    return value
end

return TetrisMPConfig
