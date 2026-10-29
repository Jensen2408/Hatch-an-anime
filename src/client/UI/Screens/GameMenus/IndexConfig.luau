-- GameMenus.IndexConfig  (ModuleScript, client)
-- Every number for the Index menu (IndexComponent). The art comes straight from the mockup
-- (assets/ui/index/index_reference.png, cut by build_index_atlas.py): one background with the changing parts
-- painted out, plus an atlas of pieces (IndexAtlas, generated). Layout is in mockup pixels (the canvas is
-- 1270 x 840); IndexComponent shrinks the canvas to the panel with one UIScale.
local IndexConfig = {}

IndexConfig.Background = "rbxassetid://133189439403487" -- index_background.png (1024 x 677, the canvas at 0.806)
IndexConfig.Pieces = "rbxassetid://116933929995381" -- index_pieces.png

IndexConfig.Font = Font.new("rbxasset://fonts/families/FredokaOne.json")
IndexConfig.Stroke = Color3.fromRGB(12, 8, 26) -- dark outline of every label
IndexConfig.White = Color3.fromRGB(255, 255, 255)

-- Rect = { x, y, w, h }, mockup pixels. Text sizes: FredokaOne caps are 0.607 x TextSize.
IndexConfig.Close = { 1163, 44, 77, 76 }

IndexConfig.Seasons = {
    Original = {
        Rect = { 77, 124, 356, 56 },
        Selected = { 73, 120, 364, 64 },
        Icon = { "IconGlobe", 165, 128 },
        Label = { "LabelOriginal", 228, 134 },
    },
    Halloween = {
        Rect = { 447, 124, 383, 56 },
        Selected = { 443, 120, 391, 62 },
        Icon = { "IconPumpkin", 536, 126 },
        Label = { "LabelHalloween", 604, 134 },
    },
    Winter = { Rect = { 843, 124, 349, 56 } }, -- drawn locked in the background
    Slice = 14,
}

IndexConfig.Collection = {
    Bar = { 61, 188, 1146, 28 },
    MinFill = 30,
    Slice = 10,
    TextSize = 26,
    TextColor = Color3.fromRGB(255, 214, 48),
}

IndexConfig.Search = {
    Rect = { 43, 234, 275, 50 },
    Slice = 14,
    Icon = { 54, 242 },
    Box = { 96, 240, 214, 38 },
    TextSize = 22,
    Placeholder = { Characters = "Search characters...", Eggs = "Search eggs..." },
    PlaceholderColor = Color3.fromRGB(128, 128, 160),
    MaxLength = 30,
}

-- left to right; Piece = the button when not selected (selected: FilterAll, yellow)
IndexConfig.Filters = {
    X = 326,
    Y = 236,
    Height = 46,
    Gap = 10,
    Slice = 10,
    TextSize = 21,
    List = {
        { Key = "All", Width = 62, Piece = "FilterCommon" },
        { Key = "Common", Width = 86, Piece = "FilterCommon" },
        { Key = "Uncommon", Width = 104, Piece = "FilterUncommon" },
        { Key = "Rare", Width = 64, Piece = "FilterRare" },
        { Key = "Epic", Width = 60, Piece = "FilterEpic" },
        { Key = "Legendary", Width = 100, Piece = "FilterLegendary" },
    },
}

-- the card grid scrolls inside Viewport; every card the same size
IndexConfig.Grid = {
    Viewport = { 40, 290, 818, 462 },
    Columns = { 44, 249, 454, 659 },
    Top = 296,
    Pitch = 231,
    CardSize = Vector2.new(193, 220),
    CardSlice = { 14, 14, 14, 48 }, -- left, top, right, bottom (the name strip stays whole)
    GlowOutset = 4,
    GlowSlice = 16,
    Portrait = { 8, 8, 177, 176 }, -- inside the card
    Name = { 8, 186, 177, 28 },
    NameSize = 24,
    Badge = { Right = 6, Top = 6, Height = 30, Padding = 12, TextSize = 20 },
    BottomPad = 6,
    Empty = { 0, 180, 818, 40 },
}

IndexConfig.RarityPieces = {
    Common = { Card = "CardCommon", Badge = "BadgeGrey" },
    Uncommon = { Card = "CardUncommon", Badge = "BadgeGreen" },
    Rare = { Card = "CardRare", Badge = "BadgeBlue" },
    Epic = { Card = "CardEpic", Badge = "BadgePurple" },
    Legendary = { Card = "CardLegendary", Badge = "BadgeOrange" },
    Limited = { Card = "CardLimited", Badge = "BadgeGold" },
    Locked = { Card = "CardLocked", Badge = "BadgeDark" },
}

-- mutation tiers: card art + text colour (MUTATIONS page)
IndexConfig.Mutations = {
    Silver = { Card = "CardCommon", Badge = "BadgeGrey", Color = Color3.fromRGB(222, 226, 240) },
    Gold = { Card = "CardLimited", Badge = "BadgeGold", Color = Color3.fromRGB(255, 210, 60) },
    Diamond = { Card = "CardRare", Badge = "BadgeBlue", Color = Color3.fromRGB(120, 220, 255) },
    Rainbow = { Card = "CardEpic", Badge = "BadgePurple", Color = Color3.fromRGB(255, 120, 230) },
}

IndexConfig.Detail = {
    Portrait = { 905, 246, 296, 254 },
    Badge = { Right = 1222, Top = 239, Height = 33, Padding = 14, TextSize = 22 },
    Name = { 890, 506, 320, 34 },
    NameSize = 36,
    Status = { 975, 536, 152, 29 }, -- the DISCOVERED pill (covered on the MUTATIONS page)
    StatusCover = Color3.fromRGB(36, 27, 26),
    StatusSize = 22,
    StatusColor = Color3.fromRGB(96, 236, 96),
    ObtainIcon = { 884, 578, 56, 52 },
    Obtain = { 957, 598, 262, 26 },
    ObtainSize = 25,
    Empty = { 885, 250, 330, 240 },
    EmptyText = "Hatch eggs to discover characters!",
}

-- the three chests left to right (Position = the chest piece's top-left)
IndexConfig.Rewards = {
    List = {
        { Chest = "Chest1", Position = Vector2.new(898, 683), Pill = { 905, 740, 50, 22 } },
        { Chest = "Chest2", Position = Vector2.new(1018, 680), Pill = { 1028, 740, 41, 22 } },
        { Chest = "Chest3", Position = Vector2.new(1132, 678), Pill = { 1150, 740, 43, 22 } },
    },
    PillSlice = 8,
    PillText = 15,
    ClaimedTransparency = 0.55,
    Pulse = 1.08, -- a ready chest breathes between 1 and this scale
}

IndexConfig.Pages = {
    Characters = {
        Rect = { 189, 769, 308, 59 },
        Off = "BottomOff",
        Icon = { "IconCharacters", 250, 776 },
        Label = { "LabelCharacters", 305, 784 },
    },
    Eggs = {
        Rect = { 511, 774, 243, 54 },
        Off = "BottomEggs",
        Icon = { "IconEgg", 574, 776 },
        Label = { "LabelEggs", 630, 784 },
    },
    Mutations = {
        Rect = { 767, 774, 312, 54 },
        Off = "BottomMutations",
        Icon = { "IconDna", 832, 778 },
        Label = { "LabelMutations", 893, 784 },
    },
    On = "BottomCharacters", -- the selected page (orange)
    Slice = 14,
}

return IndexConfig
