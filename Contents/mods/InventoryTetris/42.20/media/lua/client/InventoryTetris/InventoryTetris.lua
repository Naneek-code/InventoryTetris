local Version = require("Notloc/Versioning/Version")
local InventoryTetrisVersion = require("InventoryTetris/Version")

-- Intentional global
InventoryTetris = {
    version = InventoryTetrisVersion,
}

print("InventoryTetris version: " .. Version.format(InventoryTetris.version))

return InventoryTetris
