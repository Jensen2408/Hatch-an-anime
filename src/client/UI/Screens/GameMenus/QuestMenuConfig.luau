-- GameMenus.QuestMenuConfig  (ModuleScript, client)
-- Every number for the Quests menu (QuestMenuComponent). The art is ReplicatedStorage.MenuArt (the window
-- background with the footer, tab / row / button pieces); rects are measured on it, in pixels of the StudTheme
-- canvas (1160 x 730) the menu is drawn on. More than three quests scroll.
local QuestMenuConfig = {}

-- Rect = { x, y, w, h } in canvas pixels (inner rects are relative to their row)
QuestMenuConfig.Close = { 1040, 30, 68, 68 } -- the drawn X

QuestMenuConfig.Tabs = {
    Keys = { "Daily", "Weekly", "Monthly" },
    Labels = { Daily = "DAILY", Weekly = "WEEKLY", Monthly = "MILESTONES" },
    Rects = { { 66, 133, 331, 64 }, { 410, 133, 342, 64 }, { 768, 133, 322, 64 } },
    LabelSize = 32,
    Badge = { Right = 45, Top = -7, Width = 50, Height = 34, TextSize = 24 }, -- red count, from the tab's top-right
}

QuestMenuConfig.List = { Rect = { 52, 206, 1056, 402 }, Top = 10, X = 10, RowStep = 130, BottomPad = 8 }

QuestMenuConfig.Row = {
    Size = Vector2.new(1036, 113),
    GlowOutset = Vector2.new(10, 11), -- the claimable row's glowing frame reaches past the card
    IconRect = { 16, 13, 87, 83 },
    IconInset = 10,
    TitleRect = { 123, 10, 510, 34 },
    TitleSize = 30,
    TextRect = { 123, 43, 510, 24 },
    TextSize = 21,
    TrackRect = { 121, 75, 414, 20 },
    CountRect = { 545, 70, 95, 30 },
    CountSize = 24,
    RewardRect = { 644, 16, 184, 70 },
    RewardIconRect = { 12, 13, 44, 44 },
    RewardTextRect = { 60, 10, 116, 50 },
    RewardSize = 30,
    ButtonRect = { 844, 21, 174, 60 },
    ButtonSize = 30,
    ClaimedTint = Color3.fromRGB(170, 170, 185),
}

QuestMenuConfig.Footer = {
    TextRect = { 80, 630, 700, 50 },
    TextSize = 30,
    ButtonRect = { 822, 622, 278, 66 },
    ButtonSize = 30,
}

QuestMenuConfig.EmptyRect = { 52, 380, 1056, 50 }

return QuestMenuConfig
