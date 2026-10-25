-- GameMenus.QuestMenuConfig  (ModuleScript, client)
-- Every number for the Quests menu (QuestMenuComponent). Layout values come from the Figma frame
-- "04 Quests" (Hatch an Anime • Screens & Components), measured from the Panel's top-left corner, in Figma
-- pixels, on the StudTheme canvas (1160x730). Colors, fonts and the kit pieces: StudTheme / StudUI.
--
-- The QuestRow component's inside could not be read from Figma (MCP quota); its 1114x126 size and the
-- three rows 150 px apart are from the frame, the inside follows the kit's UpgradeRow. More than three
-- quests scroll.
local QuestMenuConfig = {}

QuestMenuConfig.Title = "QUESTS" -- Header/green

-- Rect = { x, y, w, h } in canvas pixels (inner rects are relative to their row)
QuestMenuConfig.Tabs = {
    Keys = { "Daily", "Weekly", "Monthly" },
    Labels = { Daily = "DAILY", Weekly = "WEEKLY", Monthly = "MILESTONES" },
    Y = 104,
    Height = 58,
    Xs = { 22, 398, 774 },
    Width = 362,
    Badge = { 322, -10, 48, 32 }, -- red count of claimable quests
}

QuestMenuConfig.List = { Rect = { 22, 184, 1114, 426 }, RowStep = 150 }

QuestMenuConfig.Row = {
    Size = Vector2.new(1114, 126),
    Radius = 10,
    IconRect = { 18, 18, 90, 90 },
    IconRadius = 10,
    TitleRect = { 126, 14, 540, 36 },
    TitleSize = 26,
    TextRect = { 126, 52, 540, 28 },
    TextSize = 21,
    ProgressRect = { 126, 90, 440, 20 },
    CountRect = { 578, 84, 100, 32 },
    CountSize = 22,
    RewardRect = { 690, 30, 190, 66 },
    RewardIconRect = { 10, 11, 44, 44 },
    RewardTextRect = { 60, 8, 122, 50 },
    RewardSize = 26,
    ButtonRect = { 896, 35, 200, 56 },
    ClaimableBorder = 3,
}

QuestMenuConfig.Footer = {
    TextRect = { 30, 661, 580, 38 },
    TextSize = 26,
    ButtonRect = { 810, 656, 310, 56 },
}

QuestMenuConfig.EmptyRect = { 22, 360, 1114, 50 }

return QuestMenuConfig
