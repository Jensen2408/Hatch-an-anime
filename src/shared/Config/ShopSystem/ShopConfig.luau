--[[ ReplicatedStorage.ShopSystem.ShopConfig — everything you tune for the Shop + Daily Rewards.
PASTE YOUR IDS HERE: create the Game Passes / Developer Products on the Creator Hub, then put their numbers below.
Anything with id 0 shows "SOON" and can't be bought yet.
]]
local Config = {}

Config.GamePasses = {
    VIP = 2026700958, -- Game Pass: crown over head, gold [VIP] chat tag, +10% cash, 2× daily cash rewards
    StarterPack = 2026160959, -- Game Pass (one-time): $25K cash + 30 min 2× Money + 30 min 2× Hatch
}
Config.Products = {
    Money2x = 3718004641, -- Developer Product: 2× money for 30 minutes (stacks time)
    Hatch2x = 3718004750, -- Developer Product: 2× hatch speed for 30 minutes (stacks time)
    CashSmall = 3718004801, -- Developer Product: cash pack
    CashMedium = 3718004872,
    CashLarge = 3718004966,
    UnknownEgg = 3718415531, -- Developer Product: LIMITED DEAL Unknown Egg (199 R$). Paste the id here.
    Offline2x = 3719548128 --[[ 19 R$ "2× Offline Earnings" developer product ]],
}
Config.Prices = {
    VIP = 360,
    StarterPack = 90,
    Money2x = 49,
    Hatch2x = 49,
    CashSmall = 15,
    CashMedium = 59,
    CashLarge = 149,
    UnknownEgg = 199,
    Offline2x = 19,
} -- shown on buttons only; real price is set on Roblox
Config.BoostMinutes = 30
Config.CashPacks = { CashSmall = 10000, CashMedium = 75000, CashLarge = 400000 }
Config.StarterPack = { cash = 25000, boostMinutes = 30 }
Config.VIPCashBonus = 1.1

-- Money multiplier: bought with ROBUX, one level at a time, each level costs more. Permanent.
-- Make ONE Developer Product per level (price = robux below) and paste its id.
Config.MoneyLevels = {
    { mult = 2, robux = 14, productId = 3718005028 },
    { mult = 3, robux = 27, productId = 3718005064 },
    { mult = 5, robux = 54, productId = 3718005137 },
    { mult = 10, robux = 108, productId = 3718005192 },
    { mult = 25, robux = 207, productId = 3718005228 },
    { mult = 50, robux = 405, productId = 3718005308 },
    { mult = 100, robux = 720, productId = 3718005385 },
    { mult = 250, robux = 1350, productId = 3718005454 },
    { mult = 500, robux = 2250, productId = 3718005500 },
    { mult = 1000, robux = 4500, productId = 3718005571 },
}

-- Hatch speed: bought with in-game CASH (coins), one level at a time. Permanent, saved with the shop data.
-- `mult` is the hatch speed at that level (stacks with the 2× Hatch boost and the night bonus); `cash` is its price.
Config.HatchLevels = {
    { mult = 1.5, cash = 1e6 },
    { mult = 2, cash = 25e6 },
    { mult = 2.5, cash = 500e6 },
    { mult = 3, cash = 10e9 },
    { mult = 4, cash = 250e9 },
    { mult = 5, cash = 5e12 },
    { mult = 6, cash = 100e12 },
    { mult = 7, cash = 2.5e15 },
    { mult = 8, cash = 50e15 },
    { mult = 9, cash = 1e18 },
    { mult = 10, cash = 25e18 },
}

-- Weapons (WEAPONS tab): bat tiers bought with in-game CASH, owned forever, one equipped at a time.
-- Ownership + the equipped bat are saved by PlayerDataService (fields `weapons` / `weapon`) through the Player
-- attributes OwnedWeapons / EquippedWeapon, so cash and bats are always written in the same save.
-- What bats do: knock players down (they drop a river egg they are carrying home) and damage the river boss.
--   knockback   horizontal fling strength (BatServer KNOCKBACK_FORCE)
--   range       forward reach in studs (BatServer HIT_RANGE)
--   cooldown    seconds between swings (BatServer SWING_COOLDOWN; the swing animation plays faster to match)
--   bossDamage  damage per hit on the river boss (BossEventService)
-- Every tier uses the WoodenBat mesh and keeps its SurfaceAppearance (normal map, stud detail). colorMap is the wood
-- colour map recoloured for the tier (tools/weapons/bat_texture_server.js: luminance mapped through a shadow / mid /
-- highlight gradient); roughnessMap / metalnessMap, when set, replace the wood ones (metal tiers). tint + material are
-- the flat fallback used only if a tier has no colorMap. A tier without a tint keeps the wood texture.
-- cash = 0 means every player owns it from the start.
Config.Weapons = {
    {
        key = "WoodenBat",
        name = "WOODEN BAT",
        cash = 0,
        knockback = 50,
        range = 6.5,
        cooldown = 1.1,
        bossDamage = 3,
    },
    {
        key = "IronBat",
        name = "IRON BAT",
        cash = 25000,
        knockback = 60,
        range = 7,
        cooldown = 1.0,
        bossDamage = 4,
        tint = Color3.fromRGB(165, 175, 190),
        material = Enum.Material.Metal,
        colorMap = "rbxassetid://72957821521051",
        roughnessMap = "rbxassetid://125695872041779",
        metalnessMap = "rbxassetid://107827331979590",
    },
    {
        key = "GoldenBat",
        name = "GOLD BAT",
        cash = 1e6,
        knockback = 70,
        range = 7.5,
        cooldown = 0.9,
        bossDamage = 6,
        tint = Color3.fromRGB(255, 196, 40),
        material = Enum.Material.Foil,
        colorMap = "rbxassetid://121153076879293",
        roughnessMap = "rbxassetid://125695872041779",
        metalnessMap = "rbxassetid://107827331979590",
    },
    {
        key = "DiamondBat",
        name = "DIAMOND BAT",
        cash = 1e8,
        knockback = 85,
        range = 8,
        cooldown = 0.8,
        bossDamage = 8,
        tint = Color3.fromRGB(110, 225, 245),
        material = Enum.Material.Foil,
        colorMap = "rbxassetid://97683963145498",
        roughnessMap = "rbxassetid://125695872041779",
        metalnessMap = "rbxassetid://107827331979590",
    },
    {
        key = "OniBat",
        name = "ONI BAT",
        cash = 1e10,
        special = true, -- gets a "SPECIAL" badge in the shop
        knockback = 100,
        range = 8.5,
        cooldown = 0.7,
        bossDamage = 12,
        tint = Color3.fromRGB(190, 28, 40),
        material = Enum.Material.SmoothPlastic,
        colorMap = "rbxassetid://75292626258952", -- plastic: keeps the wood bat's own roughness / metalness maps
    },
}
Config.DefaultWeapon = "WoodenBat"

-- Daily rewards (7-day streak, resets if you miss a day)
Config.Daily = {
    { kind = "cash", amount = 500 },
    { kind = "cash", amount = 1000 },
    { kind = "boost", boost = "Hatch2x", minutes = 10, label = "2× HATCH 10m" },
    { kind = "cash", amount = 2500 },
    { kind = "boost", boost = "Money2x", minutes = 10, label = "2× MONEY 10m" },
    { kind = "cash", amount = 5000 },
    { kind = "mystery", amount = 25000, minutes = 15, label = "MYSTERY GIFT" },
}
Config.Icons = {
    Fire = "rbxassetid://123121531396779",
    Chalice = "rbxassetid://101647680219886",
    CoinSmall = "rbxassetid://132917301116912",
    Glow = "rbxassetid://82918154679918",
    Crown = "rbxassetid://132384741215584",
    StarterPack = "rbxassetid://89561259739700",
    Money2x = "rbxassetid://91503030293166",
    Hatch2x = "rbxassetid://115300000098827",
    Coins = "rbxassetid://125162321561970",
    Chest = "rbxassetid://108828180161951",
}
-- Limited deal shown at the top of the shop
Config.LimitedDeal = {
    key = "UnknownEgg",
    name = "UNKNOWN EGG",
    text = "A secret Halloween egg. Only for a limited time!",
    endsAt = 1793491200,
} -- ends 1 Nov 2026 00:00 UTC
Config.ComingSoonEgg = { name = "Celestial Egg", text = "A really special egg is on its way…" }
return Config

