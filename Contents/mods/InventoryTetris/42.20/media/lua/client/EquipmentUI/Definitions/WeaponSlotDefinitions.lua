---@class WeaponSlotDefinition
---@field public name string
---@field public position table

---@class WeaponSlotDefinitions
---@field public primary WeaponSlotDefinition
---@field public secondary WeaponSlotDefinition
local WeaponSlotDefinitions = {
    primary = {
        name = "Primary",
        position = { x = -18, y = 142 }
    },
    secondary = {
        name = "Secondary",
        position = { x = 96, y = 150 }
    }
}

return WeaponSlotDefinitions
