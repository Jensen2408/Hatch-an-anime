-- GameMenus.PlotConfig  (ModuleScript, client)
-- Every number for the Plot menu (PlotComponent). Layout values come from the Figma frame "03 Plot"
-- (Hatch an Anime • Screens & Components), measured from the Panel's top-left corner, in Figma pixels.
-- PlotComponent builds the menu on the StudTheme canvas (1160x730) and shrinks it with a UIScale to the
-- panel's size, so these numbers are used as-is. Colors, fonts, panel / header / button art: StudTheme.
--
-- Where the Figma frame overlaps (Stat tiles 350 wide in 362 slots, UpgradeRow buttons 200 wide sticking
-- out of the 362 rows, a 235-tall CharacterCard in a 164 cell, Tab faces 210 wide in 374 / 338 slots),
-- every piece is sized to its slot instead, on the frame's own grid (22 px margin, 12 px gaps).
local PlotConfig = {}

PlotConfig.Title = "MY PLOT" -- Header/red

-- Rect = { x, y, w, h } in canvas pixels
PlotConfig.Stats = {
    Y = 104,
    Height = 88,
    Width = 362,
    Xs = { 22, 398, 774 },
    Radius = 10,
    LabelSize = 18,
    LabelRect = { 18, 10, 326, 25 }, -- inside the tile
    ValueSize = 34,
    ValueRect = { 18, 34, 326, 46 },
}

PlotConfig.Tabs = {
    Y = 210,
    Height = 58,
    Slots = { X = 22, Width = 250, Label = "CHARACTER SLOTS" },
    Upgrades = { X = 284, Width = 230, Label = "UPGRADES" },
    EquipBest = { X = 526, Width = 220, Label = "EQUIP BEST" }, -- Button/blue
}

-- Left column content area (below the tabs, above the footer); the slot grid scrolls inside it
PlotConfig.Content = { Rect = { 22, 284, 724, 341 } }

PlotConfig.SlotGrid = {
    Columns = 4,
    CellSize = Vector2.new(172, 164),
    Gap = Vector2.new(12, 13),
    Radius = 10,
    NumberSize = 22,
    NumberRect = { 10, 6, 44, 28 },
    LockSize = 42,
    LockRect = { 48, 40, 76, 60 },
    PriceSize = 23,
    PriceRect = { 10, 123, 152, 30 },
    EmptySize = 20,
    EmptyRect = { 10, 62, 152, 40 },
    -- placed character (CharacterCard)
    ImageRect = { 8, 8, 156, 100 },
    StripRect = { 5, 113, 162, 46 },
    StripRadius = 6,
    NameSize = 19,
    NameRect = { 9, 114, 154, 24 },
    IncomeSize = 17,
    IncomeRect = { 9, 137, 154, 21 },
}

-- Upgrades tab: one row per incubator, same art as the right column's UpgradeRow
PlotConfig.IncubatorRows = { Height = 104, Gap = 14 }

-- Right column (UpgradeRow x3)
PlotConfig.UpgradeRows = {
    X = 774,
    Ys = { 210, 360, 510 },
    Width = 362,
    Height = 134,
    Radius = 10,
    TitleSize = 24,
    TitleRect = { 18, 15, 326, 34 },
    SubtitleSize = 20,
    SubtitleRect = { 18, 52, 172, 64 },
    Button = { Width = 145, Height = 50, Right = 18, Bottom = 18 },
}

-- UpgradeRow in the Upgrades tab (wider row: subtitle + progress bar on the left, button on the right)
PlotConfig.IncubatorRow = {
    Radius = 10,
    TitleSize = 24,
    TitleRect = { 18, 10, 420, 34 },
    SubtitleSize = 20,
    SubtitleRect = { 18, 44, 420, 26 },
    ProgressRect = { 18, 76, 420, 18 },
    Button = { Width = 190, Height = 56, Right = 18 },
}

PlotConfig.Footer = {
    TextSize = 25,
    TextRect = { 22, 669, 340, 32 },
    ProgressRect = { 372, 675, 374, 20 },
    Milestone = { Rect = { 774, 670, 362, 48 }, Radius = 10, TextSize = 22 },
}

return PlotConfig
