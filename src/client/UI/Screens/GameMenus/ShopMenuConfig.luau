-- GameMenus.ShopMenuConfig  (ModuleScript, client)
-- Every number for the Shop menu (ShopMenuComponent). The FEATURED page is the Figma frame "01 Shop"
-- (Hatch an Anime • Screens & Components), measured from the Panel's top-left corner, in Figma pixels, on
-- the StudTheme canvas (1160x730). The other tabs have no frame of their own: they reuse the same cards,
-- buttons and badges on the same grid (22 px margin, 1114x518 content area below the tabs). DAILY uses
-- the day cards of the Figma frame "07 Daily".
--
-- Where "01 Shop" overlaps, pieces are sized to their slot: the green buttons (200 px faces inside 486 /
-- 370 / 240 / 180 px instances) fill their instance width, the boost-card buttons sit 8 px above the card
-- edge instead of touching it, and the Badge / live timer are drawn over the art's own (static) tag and timer.
local ShopMenuConfig = {}

ShopMenuConfig.Titles = { Default = "SHOP", Halloween = "HALLOWEEN SHOP" } -- Header/orange

-- Figma icon artwork (Icon/Shop crown, Icon/coin, Icon/Index egg book) and the limited-deal art, kept at
-- assets/ui/shop/*.png. TODO: upload them and put the ids here; until then (nil) the shop uses the matching
-- ShopSystem.ShopConfig.Icons and shows the spinning egg model instead of the art.
ShopMenuConfig.Assets = {
    LimitedArt = nil, -- assets/ui/shop/limited_unknown_egg.png (400x225)
    Crown = nil, -- assets/ui/shop/icon_crown.png
    Coin = nil, -- assets/ui/shop/icon_coin.png
    Hatch = nil, -- assets/ui/shop/icon_hatch.png
}

ShopMenuConfig.Tabs = {
    Keys = { "FEATURED", "BOOSTS", "PASSES", "CASH", "DAILY" },
    Y = 104,
    Height = 58,
    X = 22,
    Width = 214,
    Gap = 11,
    Alert = { Size = 26, Inset = 8 }, -- red "!" on DAILY while a reward is ready
}

-- Rect = { x, y, w, h } in canvas pixels (inner rects are relative to their card)
ShopMenuConfig.Featured = {
    Limited = {
        Rect = { 22, 180, 530, 518 },
        Radius = 12,
        ArtRect = { 12, 12, 506, 290 },
        BadgeRect = { 22, 24, 132, 32 },
        BadgeText = "LIMITED",
        TimerRect = { 334, 12, 184, 42 }, -- covers the art's own (static) timer pill
        TimerRadius = 8,
        TimerSize = 24,
        TitleRect = { 22, 308, 486, 58 },
        TitleSize = 40,
        TextRect = { 22, 368, 486, 34 },
        TextSize = 24,
        ButtonRect = { 22, 442, 486, 56 },
    },
    Vip = {
        Rect = { 568, 180, 568, 190 },
        Radius = 12,
        IconRect = { 24, 29, 110, 110 },
        TitleRect = { 162, 17, 370, 64 },
        TitleSize = 54,
        TextRect = { 162, 79, 370, 30 },
        TextSize = 24,
        ButtonRect = { 162, 123, 370, 56 },
    },
    -- 2× MONEY / 2× HATCH (276x194 cards)
    Boost = {
        Rects = { { 568, 386, 276, 194 }, { 860, 386, 276, 194 } },
        Radius = 10,
        IconRect = { 14, 22, 68, 68 },
        TitleRect = { 94, 22, 168, 35 },
        TitleSize = 25,
        TextRect = { 16, 94, 244, 30 },
        TextSize = 22,
        ButtonRect = { 18, 130, 240, 56 },
    },
    Starter = {
        Rect = { 568, 596, 568, 102 },
        Radius = 10,
        TitleRect = { 22, 15, 310, 36 },
        TitleSize = 30,
        TextRect = { 22, 54, 310, 28 },
        TextSize = 20,
        ButtonRect = { 366, 28, 180, 56 },
    },
}

-- BOOSTS: two big boost cards + the starter pack row (same row as FEATURED)
ShopMenuConfig.Boosts = {
    Rects = { { 22, 180, 551, 400 }, { 585, 180, 551, 400 } },
    Radius = 12,
    IconRect = { 205, 22, 140, 140 },
    TitleRect = { 20, 172, 511, 44 },
    TitleSize = 34,
    TextRect = { 20, 218, 511, 30 },
    TextSize = 22,
    TimerBarRect = { 60, 262, 431, 20 },
    TimerTextRect = { 20, 288, 511, 28 },
    TimerTextSize = 20,
    ButtonRect = { 120, 328, 311, 56 },
    StarterRect = { 22, 596, 1114, 102 },
    StarterButtonRect = { 912, 28, 180, 56 },
}

-- PASSES: VIP + money multiplier
ShopMenuConfig.Passes = {
    Rects = { { 22, 180, 551, 518 }, { 585, 180, 551, 518 } },
    Radius = 12,
    IconRect = { 195, 24, 160, 160 },
    TitleRect = { 20, 196, 511, 64 },
    TitleSize = 54,
    TextRect = { 40, 266, 471, 76 },
    TextSize = 24,
    -- money multiplier card
    MultTitleRect = { 20, 196, 511, 44 },
    MultTitleSize = 34,
    ValueRect = { 20, 244, 511, 56 },
    ValueSize = 46,
    Pips = { Y = 316, Size = 32, Gap = 8, Radius = 6 },
    LevelRect = { 20, 360, 511, 30 },
    LevelSize = 22,
    ButtonRect = { 120, 438, 311, 56 },
}

-- CASH: three packs
ShopMenuConfig.Cash = {
    Y = 180,
    Height = 518,
    X = 22,
    Width = 363,
    Gap = 12,
    Colors = { "Blue", "Gold", "Blue" },
    Radius = 12,
    BadgeRect = { 18, 18, 190, 34 },
    IconSizes = { 120, 150, 180 }, -- bigger coin for bigger packs, centered in IconArea
    IconArea = { 20, 60, 323, 200 },
    AmountRect = { 20, 276, 323, 64 },
    AmountSize = 50,
    TextRect = { 20, 344, 323, 30 },
    TextSize = 22,
    ButtonRect = { 20, 438, 323, 56 },
}

-- DAILY: Figma "07 Daily" day cards at the frame's exact size and x positions (258x202, 278 px apart from
-- x 30) with the frame's card insides. Vertically the rows sit 12 px apart and the intro / footer move up so
-- the page fits under the shop tabs (the frame's footer button, y 670..726, also stuck out of the panel).
ShopMenuConfig.Daily = {
    IntroRect = { 30, 170, 1100, 36 },
    IntroSize = 30,
    Intro = "Come back each day for a new reward!",
    Columns = 4,
    X = 30,
    Y = 214,
    CardSize = Vector2.new(258, 202),
    Gap = Vector2.new(20, 12),
    Radius = 10,
    DayRect = { 10, 10, 238, 30 },
    DaySize = 26,
    IconRect = { 88, 50, 78, 78 },
    ValueRect = { 10, 143, 238, 36 },
    ValueSize = 28,
    MarkRect = { 210, 8, 40, 32 },
    MarkSize = 26,
    NextRect = { 30, 654, 700, 35 },
    NextSize = 26,
    ButtonRect = { 810, 644, 310, 56 },
}

return ShopMenuConfig
