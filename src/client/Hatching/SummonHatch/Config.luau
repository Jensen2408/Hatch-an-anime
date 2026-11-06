-- SummonHatch.Config: tiers, pages and tuning for the summon-room hatch animation (ported from the HatchDemo RollFx).
-- Tier = the egg's rarity rank (CharacterCatalog): Common 1 .. Legendary 5, Limited 6. Every character of an egg has
-- the egg's rarity, so the extra drama comes from the bonus rules below, not from the rarity.
local Config = {}

Config.Tiers = {
    { name = "COMMON", logo = "common", color = Color3.fromRGB(190, 195, 205) },
    { name = "UNCOMMON", logo = "uncommon", color = Color3.fromRGB(109, 225, 132) },
    { name = "RARE", logo = "rare", color = Color3.fromRGB(98, 172, 255) },
    { name = "EPIC", logo = "epic", color = Color3.fromRGB(197, 126, 255) },
    { name = "LEGENDARY", logo = "legendary", color = Color3.fromRGB(255, 207, 92) },
    { name = "LIMITED", logo = "limited", color = Color3.fromRGB(255, 60, 90) }, -- no rendered logo: text fallback
}

-- Splash page per tier: flat colour, sunburst one step away from it, huge kanji. No gradients.
Config.Pages = {
    {
        bg = Color3.fromRGB(255, 248, 232),
        burst = Color3.fromRGB(232, 224, 206),
        word = Color3.fromRGB(206, 196, 176),
        floor = Color3.fromRGB(150, 142, 128),
    },
    {
        bg = Color3.fromRGB(226, 255, 226),
        burst = Color3.fromRGB(150, 240, 164),
        word = Color3.fromRGB(70, 196, 110),
        floor = Color3.fromRGB(28, 150, 70),
    },
    {
        bg = Color3.fromRGB(26, 92, 224),
        burst = Color3.fromRGB(20, 66, 186),
        word = Color3.fromRGB(62, 134, 255),
        floor = Color3.fromRGB(160, 214, 255),
    },
    {
        bg = Color3.fromRGB(56, 18, 112),
        burst = Color3.fromRGB(34, 10, 78),
        word = Color3.fromRGB(150, 62, 240),
        floor = Color3.fromRGB(226, 170, 255),
    },
    {
        bg = Color3.fromRGB(255, 188, 26),
        burst = Color3.fromRGB(255, 150, 8),
        word = Color3.fromRGB(226, 56, 28),
        floor = Color3.fromRGB(255, 246, 190),
    },
    {
        bg = Color3.fromRGB(13, 10, 16),
        burst = Color3.fromRGB(70, 6, 26),
        word = Color3.fromRGB(226, 22, 60),
        floor = Color3.fromRGB(255, 70, 110),
    },
}

Config.Mutations = {
    Silver = { name = "SILVER", color = Color3.fromRGB(214, 226, 240) },
    Gold = { name = "GOLD", color = Color3.fromRGB(255, 205, 50) },
    Diamond = { name = "DIAMOND", color = Color3.fromRGB(110, 235, 255) },
    Rainbow = { name = "RAINBOW", color = Color3.fromRGB(255, 80, 200) },
}

-- Bonus: one step more drama (fake-out at tier 4+, more impact frames, longer slow motion) when the hatched character
-- is the rarest pick of its egg (the 10% one) or the Power roll is at least this quality rank (Economy.Bands: 4 = Jackpot).
Config.BonusQualityRank = 4

Config.CharacterHeight = 15 -- studs, the hero in the summon room
Config.SilhouetteHeight = 14 -- studs, the figures on the reel cards
Config.EggWorldHeight = 7 -- studs, the egg rising in front of the incubator
Config.EggRoomHeight = 8.6 -- studs, the egg in the summon room
Config.CircleSize = 30 -- studs, the summon circle on the floor in front of the incubator
Config.Reel = 3.4 -- seconds the cards circle the egg
Config.Turns = 3
Config.HoldSeconds = 14 -- the result stays until COLLECT, at most this long
Config.Volume = 0.8 -- multiplies every summon sound
Config.SkipAfter = 1.4 -- seconds into the summon room before SKIP shows

return Config
