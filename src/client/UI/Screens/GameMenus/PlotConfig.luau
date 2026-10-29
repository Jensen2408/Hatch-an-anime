-- GameMenus.PlotConfig  (ModuleScript, client)
-- Every number for the Plot menu (PlotComponent). The art comes straight from the mockup
-- (assets/ui/plot/plot_reference.png, cut by build_plot_atlas.py): one background with the changing parts painted
-- out, plus an atlas of pieces (PlotAtlas, generated). Layout is in mockup pixels (the canvas is 1382 x 822);
-- PlotComponent shrinks the canvas to the panel with one UIScale.
local PlotConfig = {}

PlotConfig.Background = "rbxassetid://76940150800225" -- plot_background.png (1024 x 609, the canvas at 0.741)
PlotConfig.Pieces = "rbxassetid://95061462580842" -- plot_pieces.png

PlotConfig.Font = Font.new("rbxasset://fonts/families/FredokaOne.json")
PlotConfig.Stroke = Color3.fromRGB(12, 8, 26) -- dark outline of every label

-- Rect = { x, y, w, h }, mockup pixels
PlotConfig.Stats = {
    TextSize = 59, -- cap height 36 px in the mockup (FredokaOne caps = 0.607 x TextSize)
    StrokeThickness = 4,
    Values = { -- left-aligned, vertically centred in the rect
        { Rect = { 236, 168, 236, 60 }, Color = Color3.fromRGB(72, 234, 82) },
        { Rect = { 632, 168, 226, 60 }, Color = Color3.fromRGB(255, 206, 46) },
        { Rect = { 1012, 168, 216, 60 }, Color = Color3.fromRGB(244, 112, 206) },
    },
}

PlotConfig.Tabs = {
    Slots = { 86, 238, 420, 55 },
    Upgrades = { 505, 238, 298, 55 },
}

-- the slot grid / incubator rows scroll inside this clip
PlotConfig.Viewport = { 49, 300, 749, 417 }

-- the mockup's 8 slot cards (canvas pixels): their x / width give the grid's columns
PlotConfig.Cells = {
    { 64, 305, 182, 243 },
    { 253, 304, 176, 220 },
    { 437, 306, 172, 219 },
    { 621, 306, 171, 219 },
    { 51, 555, 189, 160 },
    { 248, 536, 178, 179 },
    { 435, 536, 172, 177 },
    { 621, 536, 171, 177 },
}
PlotConfig.Columns = 4
-- every card the same height: two rows fill the viewport, later rows scroll in
PlotConfig.Grid = { Top = 305, Height = 196, Pitch = 210 }
PlotConfig.ScrollBottomPad = 8

PlotConfig.Card = {
    SliceCenter = Rect.new(35, 35, 120, 156), -- atlas pixels of the Card piece (the number badge stays whole)
    GlowSliceCenter = Rect.new(16, 16, 120, 152),
    GlowOutset = { 3, 3, 4, 4 }, -- left, top, right, bottom: the glow frame reaches past the card
    Number = { Centre = Vector2.new(28, 25), TextSize = 33, Stroke = 3 },
    -- locked: lock + price; price row at TallPriceY (cards >= 200 tall) or ShortPriceRatio * height
    Locked = {
        TallPriceY = 154,
        ShortPriceRatio = 0.82,
        LockAbovePrice = 110, -- lock piece top = price row - this (tall); ShortLockAbovePrice for short cards
        ShortLockAbovePrice = 104,
    },
    -- next slot and placed: laid out on a template card, shrunk to fit shorter cards
    Next = {
        Height = 220,
        Lock = { 53, 32 },
        Label = { 31, 109 },
        PriceY = 153,
        Button = { 8, 172 },
    },
    Placed = {
        Height = 243,
        Portrait = { 40, 18, 102, 125 },
        NameY = 163,
        NameSize = 30,
        IncomeY = 184,
        IncomeSize = 26,
        Button = { 10, 198 },
    },
    EmptySize = 28,
    PriceSize = 31,
    PriceStroke = 3,
    CoinGap = 10, -- between the coin and the price text
    Colors = {
        Locked = Color3.fromRGB(196, 196, 228),
        Green = Color3.fromRGB(96, 236, 96),
        White = Color3.fromRGB(255, 255, 255),
    },
}

PlotConfig.Footer = {
    Text = { 68, 734, 236, 32 },
    TextSize = 28,
    Bar = { 313, 739, 474, 23 }, -- inside of the track
    BarSlice = Rect.new(8, 4, 39, 15), -- atlas pixels of BarFill
    MinFill = 59, -- the mockup's first step (1 of 12)
}

-- right column, top to bottom (names used by FirstHatchTutorial)
PlotConfig.UpgradeRows = {
    {
        Name = "TempleUpgrades",
        Row = { 822, 275, 464, 113 },
        Price = Vector2.new(1205, 307),
        Button = { 1139, 324, 144, 57 },
    },
    {
        Name = "IncubatorSpeed",
        Row = { 822, 400, 468, 112 },
        Price = Vector2.new(1208, 430),
        Button = { 1139, 447, 151, 57 },
    },
    {
        Name = "IncubatorUpgrades",
        Row = { 822, 525, 476, 113 },
        Price = Vector2.new(1216, 553),
        Button = { 1144, 572, 153, 58 },
    },
}
PlotConfig.UpgradePrice = { TextSize = 35, Stroke = 3, Off = Color3.fromRGB(214, 214, 228) }
PlotConfig.GreyButtonText = { TextSize = 21, Color = Color3.fromRGB(58, 58, 70), Inset = { 10, 6 } }

PlotConfig.Milestone = {
    Rect = { 823, 648, 485, 122 },
    Dots = { First = Vector2.new(1020, 740), Step = 38, Count = 5 },
}

-- Upgrades tab: one row per incubator (the blank upgrade row art), inside the viewport
PlotConfig.IncubatorRows = {
    Height = 113,
    Gap = 14,
    Width = 735,
    RowSlice = Rect.new(16, 16, 337, 68), -- atlas pixels of RowBlank
    Egg = { 16, 8 },
    Title = { 118, 14, 360, 40 },
    TitleSize = 30,
    Subtitle = { 118, 52, 380, 28 },
    SubtitleSize = 22,
    SubtitleColor = Color3.fromRGB(204, 208, 224),
    Dots = { First = Vector2.new(132, 92), Step = 34, Count = 3 },
    PriceRight = 92, -- price row centre, from the row's right edge
    PriceY = 30,
    Button = { 160, 52, 151, 57 }, -- x from the row's right edge
}

return PlotConfig
