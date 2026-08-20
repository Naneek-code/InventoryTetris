# Inventory Tetris Versioning

The authoritative mod version is defined in:

`Contents/mods/InventoryTetris/42.20/media/lua/client/InventoryTetris/Version.lua`

## Rule

Every externally distributed build gets a new Inventory Tetris version before it is handed to testers or published.

- Patch: fixes and follow-up builds.
- Minor: feature releases.
- Major: reserved for a major compatibility/versioning break.

Equipment UI is bundled with Inventory Tetris and does not have a separate release version.

Users can find the version in the lower-left corner of the character inventory. The same version is printed to the console at startup.
