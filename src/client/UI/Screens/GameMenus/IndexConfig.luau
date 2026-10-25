-- GameMenus.IndexConfig  (ModuleScript, client)
-- Every number for the Index menu (IndexComponent). Layout values come from the Figma frame "02 Index"
-- (Hatch an Anime • Screens & Components), measured from the Panel's top-left corner, in Figma pixels, on
-- the StudTheme canvas (1160x730). Colors, fonts and the kit pieces: StudTheme / StudUI.
--
-- Tidied overlaps: the bottom tab row of the frame (y 688..746) sticks out of the 721 px panel and repeats
-- the season tabs, so it is left out; the Input (54 tall) and the filter tabs (58) share one 56 px row; six
-- rarity filters share the 636 px the frame gives five; the 4x2 card grid scrolls for more characters.
local IndexConfig = {}

IndexConfig.Titles = { Default = "INDEX", Halloween = "HALLOWEEN INDEX" } -- Header/orange

-- Rect = { x, y, w, h } in canvas pixels (inner rects are relative to their card)
IndexConfig.SeasonTabs = { Y = 104, Height = 58, Xs = { 22, 398, 774 }, Width = 362, LiveBadge = { 252, -12, 100, 30 } }

IndexConfig.Collection = {
    TextRect = { 30, 172, 700, 32 },
    TextSize = 24,
    TimerRect = { 730, 172, 398, 32 },
    TimerSize = 22,
    ProgressRect = { 30, 212, 1098, 20 },
}

IndexConfig.Search = { Rect = { 22, 250, 465, 56 }, Placeholder = "Search characters…", MaxLength = 30 }

-- widths follow the label length (All .. Legendary) so every label keeps the same text size; 500..1136
IndexConfig.Filters = { X = 500, Y = 250, Widths = { 70, 104, 126, 80, 76, 140 }, Height = 56, Gap = 8, LabelSize = 20 }

IndexConfig.Grid = {
    Rect = { 22, 320, 748, 349 },
    Columns = 4,
    CellSize = Vector2.new(178, 168),
    Gap = Vector2.new(12, 13),
    Radius = 10,
    SelectedBorder = 4,
    -- CharacterCard / LockedCard
    ImageRect = { 8, 8, 162, 104 },
    StripRect = { 5, 117, 168, 46 },
    StripRadius = 6,
    NameRect = { 9, 118, 160, 24 },
    NameSize = 20,
    RarityRect = { 9, 141, 160, 21 },
    RaritySize = 17,
    EmptyRect = { 0, 140, 748, 40 },
    EmptySize = 24,
}

IndexConfig.Detail = {
    Rect = { 794, 320, 342, 350 },
    Radius = 12,
    ImageRect = { 12, 12, 318, 220 },
    BadgeRect = { 22, 22, 130, 30 },
    NameRect = { 16, 239, 310, 35 },
    NameSize = 28,
    StatusRect = { 16, 277, 310, 27 },
    StatusSize = 20,
    ObtainRect = { 16, 310, 310, 28 },
    ObtainSize = 18,
    EmptyRect = { 24, 120, 294, 110 },
    EmptySize = 26,
}

return IndexConfig
