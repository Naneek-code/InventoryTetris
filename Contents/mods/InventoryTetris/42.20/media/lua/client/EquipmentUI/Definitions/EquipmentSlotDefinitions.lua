-- Order is important here, the first slot appears on top of the others in the ui
-- It looks nicer to have the outermost layer of clothing on top

---@class SlotDefinition
---@field public name string
---@field public position table
---@field public bodyLocations ItemBodyLocation[]

---@type SlotDefinition[]
local SlotDefinitions = {
    {
        name = "UI_equipment_head",
        position = { x = 44, y = 4 },
        bodyLocations = { ItemBodyLocation.HAT, ItemBodyLocation.FULL_HAT, ItemBodyLocation.SCARF, ItemBodyLocation.NECK, ItemBodyLocation.NECK_TEXTURE, }
    },
    {
        name = "UI_equipment_face",
        position = { x = 100, y = 16 },
        bodyLocations = { ItemBodyLocation.SCBA, ItemBodyLocation.SCBANOTANK, ItemBodyLocation.MASK, ItemBodyLocation.MASK_EYES, ItemBodyLocation.MASK_FULL, ItemBodyLocation.EYES, ItemBodyLocation.LEFT_EYE, ItemBodyLocation.RIGHT_EYE, }
    },
    {
        name = "UI_equipment_torso",
        position = { x = 44, y = 58 },
        bodyLocations = { ItemBodyLocation.FULL_ROBE, ItemBodyLocation.BOILERSUIT, ItemBodyLocation.FULL_SUIT, ItemBodyLocation.FULL_SUIT_HEAD, ItemBodyLocation.FULL_SUIT_HEAD_SCBA, ItemBodyLocation.FULL_TOP, ItemBodyLocation.BATH_ROBE, ItemBodyLocation.JACKET, ItemBodyLocation.JACKET_BULKY, ItemBodyLocation.JACKET_DOWN, ItemBodyLocation.JACKET_HAT, ItemBodyLocation.JACKET_HAT_BULKY, ItemBodyLocation.JACKET_SUIT, ItemBodyLocation.JERSEY, ItemBodyLocation.SWEATER, ItemBodyLocation.SWEATER_HAT, ItemBodyLocation.DRESS, ItemBodyLocation.LONG_DRESS, ItemBodyLocation.VEST_TEXTURE, ItemBodyLocation.TORSO1LEGS1, ItemBodyLocation.TORSO1, ItemBodyLocation.SHIRT, ItemBodyLocation.SHORT_SLEEVE_SHIRT, ItemBodyLocation.TSHIRT, ItemBodyLocation.TANK_TOP, ItemBodyLocation.UNDERWEAR_TOP, }
    },
    {
        name = "UI_equipment_vest",
        position = { x = 106, y = 72 },
        bodyLocations = { ItemBodyLocation.SATCHEL, ItemBodyLocation.WEBBING, ItemBodyLocation.SHOULDER_HOLSTER, ItemBodyLocation.AMMO_STRAP, ItemBodyLocation.TORSO_EXTRA_VEST_BULLET, ItemBodyLocation.TORSO_EXTRA_VEST, ItemBodyLocation.TORSO_EXTRA, }
    },
    {
        name = "UI_equipment_back",
        position = { x = -14, y = 16 },
        bodyLocations = { ItemBodyLocation.BACK, ItemBodyLocation.TAIL },
    },
    {
        name = "UI_equipment_waist",
        position = { x = 44, y = 128 },
        bodyLocations = { ItemBodyLocation.FANNY_PACK_FRONT, ItemBodyLocation.FANNY_PACK_BACK, ItemBodyLocation.BELT, ItemBodyLocation.BELT_EXTRA, }
    },
    {
        name = "UI_equipment_left_hand",
        position = { x = 100, y = 206 },
        bodyLocations = { ItemBodyLocation.HANDS, ItemBodyLocation.HANDS_LEFT, ItemBodyLocation.LEFT_WRIST, ItemBodyLocation.LEFT_MIDDLE_FINGER, ItemBodyLocation.LEFT_RING_FINGER, }
    },
    {
        name = "UI_equipment_right_hand",
        position = { x = -14, y = 206 },
        bodyLocations = { ItemBodyLocation.HANDS, ItemBodyLocation.HANDS_RIGHT, ItemBodyLocation.RIGHT_WRIST, ItemBodyLocation.RIGHT_RING_FINGER, ItemBodyLocation.RIGHT_MIDDLE_FINGER }
    },
    {
        name = "UI_equipment_jewelry",
        position = { x = -20, y = 72 },
        bodyLocations = { ItemBodyLocation.NECKLACE, ItemBodyLocation.NECKLACE_LONG, ItemBodyLocation.EARS, ItemBodyLocation.EAR_TOP, ItemBodyLocation.NOSE, ItemBodyLocation.BELLY_BUTTON, }
    },
    {
        name = "UI_equipment_legs",
        position = { x = 44, y = 202 },
        bodyLocations = { ItemBodyLocation.LONG_SKIRT, ItemBodyLocation.SKIRT, ItemBodyLocation.PANTS, ItemBodyLocation.PANTS_EXTRA, ItemBodyLocation.PANTS_SKINNY, ItemBodyLocation.SHORT_PANTS, ItemBodyLocation.SHORTS_SHORT, ItemBodyLocation.LEGS5, ItemBodyLocation.LEGS1, ItemBodyLocation.UNDERWEAR, ItemBodyLocation.UNDERWEAR_BOTTOM, ItemBodyLocation.UNDERWEAR_EXTRA1, ItemBodyLocation.UNDERWEAR_EXTRA2, }
    },
    {
        name = "UI_equipment_feet",
        position = { x = 44, y = 272 },
        bodyLocations = { ItemBodyLocation.ANKLE_HOLSTER, ItemBodyLocation.SHOES, ItemBodyLocation.SOCKS, }
    }
}

return SlotDefinitions