--[[ ReplicatedStorage.ShopSystem.ShopConfig — everything you tune for the Shop + Daily Rewards.
PASTE YOUR IDS HERE: create the Game Passes / Developer Products on the Creator Hub, then put their numbers below.
Anything with id 0 shows "SOON" and can't be bought yet.
]]
local C = {}

C.GamePasses = {
    VIP = 2026700958, -- Game Pass: crown over head, gold [VIP] chat tag, +10% cash, 2× daily cash rewards
    StarterPack = 2026160959, -- Game Pass (one-time): $25K cash + 30 min 2× Money + 30 min 2× Hatch
}
C.Products = {
    Money2x = 3718004641, -- Developer Product: 2× money for 30 minutes (stacks time)
    Hatch2x = 3718004750, -- Developer Product: 2× hatch speed for 30 minutes (stacks time)
    CashSmall = 3718004801, -- Developer Product: cash pack
    CashMedium = 3718004872,
    CashLarge = 3718004966,
    UnknownEgg = 3718415531, -- Developer Product: LIMITED DEAL Unknown Egg (199 R$). Paste the id here.
    Offline2x = 3719548128 --[[ 19 R$ "2× Offline Earnings" developer product ]],
}
C.Prices = {
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
C.BoostMinutes = 30
C.CashPacks = { CashSmall = 10000, CashMedium = 75000, CashLarge = 400000 }
C.StarterPack = { cash = 25000, boostMinutes = 30 }
C.VIPCashBonus = 1.1

-- Money multiplier: bought with ROBUX, one level at a time, each level costs more. Permanent.
-- Make ONE Developer Product per level (price = robux below) and paste its id.
C.MoneyLevels = {
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

-- Daily rewards (7-day streak, resets if you miss a day)
C.Daily = {
    { kind = "cash", amount = 500 },
    { kind = "cash", amount = 1000 },
    { kind = "boost", boost = "Hatch2x", minutes = 10, label = "2× HATCH 10m" },
    { kind = "cash", amount = 2500 },
    { kind = "boost", boost = "Money2x", minutes = 10, label = "2× MONEY 10m" },
    { kind = "cash", amount = 5000 },
    { kind = "mystery", amount = 25000, minutes = 15, label = "MYSTERY GIFT" },
}
C.Icons = {
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
C.LimitedDeal = {
    key = "UnknownEgg",
    name = "UNKNOWN EGG",
    text = "A secret Halloween egg. Only for a limited time!",
    endsAt = 1793491200,
} -- ends 1 Nov 2026 00:00 UTC
C.ComingSoonEgg = { name = "Celestial Egg", text = "A really special egg is on its way…" }
return C
