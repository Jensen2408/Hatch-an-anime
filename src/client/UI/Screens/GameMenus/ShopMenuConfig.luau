-- GameMenus.ShopMenuConfig  (ModuleScript, client)
-- Every number for the Shop menu (ShopMenuComponent). The art comes from the "Halloween Shop" mockup
-- (assets/ui/shop_art/shop_reference.png; the LIMITED egg painted out with one GPT Image edit, then cut by
-- build_shop_atlas.py): a background (panel, header, tab row), the FEATURED page with its changing texts painted
-- out, and an atlas of pieces (ShopAtlas, generated) the other tabs are built from. Layout is in mockup pixels
-- (the canvas is 1092 x 679); ShopMenuComponent shrinks the canvas to the panel with one UIScale.
local ShopMenuConfig = {}

ShopMenuConfig.Background = "rbxassetid://128787042530520" -- shop_background.png (1024 x 637, the canvas at 0.938)
ShopMenuConfig.Featured = "rbxassetid://91365008569326" -- shop_featured.png (the FEATURED page, full size)
ShopMenuConfig.Pieces = "rbxassetid://100625909530365" -- shop_pieces.png (full size)

ShopMenuConfig.Font = Font.new("rbxasset://fonts/families/FredokaOne.json")
ShopMenuConfig.Stroke = Color3.fromRGB(14, 8, 28)
ShopMenuConfig.White = Color3.fromRGB(255, 255, 255)
ShopMenuConfig.Muted = Color3.fromRGB(205, 205, 228)
ShopMenuConfig.Gold = Color3.fromRGB(255, 214, 48)
ShopMenuConfig.Green = Color3.fromRGB(96, 236, 96)

ShopMenuConfig.Close = { 968, 36, 78, 76 } -- the X in the header (the panel's own Close button is laid over it)

-- Rect = { x, y, w, h }, mockup pixels. Text sizes: FredokaOne caps are 0.607 x TextSize.
ShopMenuConfig.Tabs = {
    Keys = { "FEATURED", "BOOSTS", "PASSES", "CASH", "DAILY" },
    Slice = 12,
    LabelColor = Color3.fromRGB(255, 255, 255),
    FEATURED = {
        Rect = { 42, 125, 208, 57 },
        Icon = { "TabIconFeatured", 63, 130 },
        Label = { "TabLabelFeatured", 107, 138 },
    },
    BOOSTS = {
        Rect = { 257, 125, 187, 57 },
        Icon = { "TabIconBoosts", 283, 130 },
        Label = { "TabLabelBoosts", 335, 138 },
    },
    PASSES = {
        Rect = { 450, 125, 193, 57 },
        Icon = { "TabIconPasses", 468, 136 },
        Label = { "TabLabelPasses", 528, 138 },
    },
    CASH = { Rect = { 647, 125, 198, 57 }, Icon = { "TabIconCash", 675, 131 }, Label = { "TabLabelCash", 743, 138 } },
    DAILY = { Rect = { 852, 125, 198, 57 }, Icon = { "TabIconDaily", 885, 128 }, Label = { "TabLabelDaily", 948, 138 } },
    Alert = { Size = 26, Inset = 8, Color = Color3.fromRGB(232, 40, 52) }, -- red "!" on DAILY while a reward is ready
}

-- FEATURED: the page image + the texts the game writes over it, and the buttons' hit-boxes
ShopMenuConfig.Page = {
    Timer = { Rect = { 404, 211, 138, 27 }, Size = 28 },
    Egg = { 160, 200, 275, 280 }, -- the spinning egg model, standing on the pedestal
    Title = { Rect = { 60, 460, 475, 60 }, Size = 66 },
    Subtitle = { Rect = { 112, 520, 370, 32 }, Size = 28, Pill = { 104, 517, 386, 38 } },
    Buy = { Text = { 140, 562, 312, 52 }, Size = 54, Hit = { 128, 555, 336, 66 } },
    Vip = { Text = { 812, 300, 198, 42 }, Size = 42, Hit = { 802, 296, 218, 50 } },
    Boosts = {
        {
            Text = { 689, 428, 108, 20 },
            TextSize = 21,
            Price = { 706, 479, 88, 33 },
            PriceSize = 33,
            Hit = { 698, 474, 104, 44 },
        },
        {
            Text = { 924, 428, 112, 20 },
            TextSize = 21,
            Price = { 937, 479, 97, 33 },
            PriceSize = 33,
            Hit = { 928, 474, 110, 44 },
        },
    },
    Starter = {
        Text = { 680, 591, 194, 26 },
        TextSize = 26,
        Price = { 914, 581, 120, 36 },
        PriceSize = 37,
        Hit = { 905, 576, 138, 46 },
    },
}

-- BOOSTS / PASSES / CASH / DAILY: one page image each (GPT Image art from a text-free layout sketch, cleaned by
-- build_shop_pages.py) drawn over the canvas below the tabs; the game writes the texts and level pips on top.
-- Every rect below is measured on those images, canvas pixels.
ShopMenuConfig.PageArt = {
    Rect = { 0, 183, 1092, 496 },
    BOOSTS = "rbxassetid://100869596723968", -- shop_page_boosts.png
    PASSES = "rbxassetid://95136168233113", -- shop_page_passes.png
    CASH = "rbxassetid://102671882825263", -- shop_page_cash.png
    DAILY = "rbxassetid://132103677796220", -- shop_page_daily.png
}
ShopMenuConfig.PillSlice = 8 -- the subtitle pill on FEATURED
ShopMenuConfig.DisabledShade = 0.45
ShopMenuConfig.PipTrack = { Color = Color3.fromRGB(20, 12, 38), Empty = Color3.fromRGB(64, 50, 104), Padding = 5 } -- a dark veil over a button that can't be pressed (transparency)

ShopMenuConfig.Boosts = {
    Cards = {
        {
            Title = { 285, 205, 245, 46 },
            Text = { 285, 252, 245, 48 },
            Timer = { 285, 305, 245, 28 },
            Button = { 287, 365, 230, 41 },
        },
        {
            Title = { 760, 205, 270, 46 },
            Text = { 760, 252, 270, 48 },
            Timer = { 760, 305, 270, 28 },
            Button = { 768, 365, 258, 41 },
        },
    },
    TitleSize = 50,
    TextSize = 24,
    TimerSize = 26,
    ButtonSize = 34,
    Hatch = {
        Title = { 130, 452, 380, 36 },
        TitleSize = 40,
        Value = { 130, 488, 380, 30 },
        ValueSize = 28,
        Pips = { X = 528, Y = 474, Size = 22, Gap = 4 },
        Button = { 837, 461, 192, 43 },
    },
    Starter = {
        Title = { 140, 552, 545, 40 },
        TitleSize = 44,
        Text = { 140, 592, 545, 28 },
        TextSize = 26,
        Button = { 837, 563, 192, 44 },
    },
}

ShopMenuConfig.Passes = {
    Vip = {
        Title = { 60, 408, 467, 72 },
        TitleSize = 96,
        Text = { 70, 480, 447, 54 },
        TextSize = 26,
        Button = { 114, 538, 360, 51 },
    },
    Money = {
        Title = { 575, 202, 450, 42 },
        TitleSize = 46,
        Value = { 575, 400, 450, 38 },
        ValueSize = 40,
        Pips = { CentreX = 799, Y = 448, Size = 34, Gap = 9 },
        Level = { 575, 492, 450, 30 },
        LevelSize = 26,
        Button = { 614, 538, 362, 52 },
    },
    ButtonSize = 40,
}

ShopMenuConfig.Cash = {
    Cards = {
        { Badge = nil, Amount = { 60, 428, 290, 60 }, Text = { 60, 490, 290, 28 }, Button = { 85, 566, 242, 38 } },
        {
            Badge = { 395, 200, 115, 35 },
            Amount = { 395, 428, 300, 60 },
            Text = { 395, 490, 300, 28 },
            Button = { 437, 566, 218, 38 },
        },
        {
            Badge = { 742, 200, 115, 35 },
            Amount = { 742, 428, 290, 60 },
            Text = { 742, 490, 290, 28 },
            Button = { 763, 566, 244, 38 },
        },
    },
    BadgeSize = 20,
    AmountSize = 70,
    TextSize = 26,
    ButtonSize = 36,
}

ShopMenuConfig.Daily = {
    Intro = { 60, 188, 970, 34 },
    IntroSize = 30,
    IntroText = "Come back each day for a new reward!",
    Cards = { -- the seven day cards on the page image
        { 62, 225, 228, 148 },
        { 305, 225, 235, 148 },
        { 555, 225, 232, 148 },
        { 803, 225, 232, 148 },
        { 62, 391, 228, 150 },
        { 305, 391, 235, 150 },
        { 555, 391, 232, 150 },
    },
    Day = { 12, 8, 150, 30 }, -- inside a card
    DaySize = 28,
    ValueBottom = 36, -- the value line, from the card's bottom
    ValueSize = 26,
    Mark = { 40, 6, 34, 34 }, -- x from the card's right edge
    MarkSize = 32,
    TodayStroke = { Color = Color3.fromRGB(255, 226, 80), Thickness = 4 },
    ClaimedShade = 0.55,
    Next = { 60, 602, 700, 40 },
    NextSize = 32,
    Button = { 797, 604, 246, 38 },
    ButtonSize = 32,
}

return ShopMenuConfig
