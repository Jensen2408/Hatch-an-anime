-- GameMenus.LeftMenuConfig  (ModuleScript, client)
-- Every number for the left menu (LeftMenuComponent). The layout is in pixels of the reference mockup
-- (cropped to its content: 886 x 1543); MenuLogic shrinks the whole menu with one UIScale.
local LeftMenuConfig = {}

-- Uploaded button art (cropped to the artwork, transparent background; text and icons are part of the image)
LeftMenuConfig.Assets = {
    Home = "rbxassetid://132226711675044", -- 1024 x 317
    Plot = "rbxassetid://83228541268119",
    Index = "rbxassetid://99661628959187",
    Quests = "rbxassetid://124697694426689",
    Shop = "rbxassetid://123855465931327",
    Daily = "rbxassetid://71838418384662",
    Settings = "rbxassetid://107119008031986",
}

-- Grid order, left to right then top to bottom. Panel = the GameMenus panel the button opens (MenuLogic).
LeftMenuConfig.Grid = {
    { Key = "Plot", Name = "PlotButton", Panel = "Plot" },
    { Key = "Index", Name = "IndexButton", Panel = "Index" },
    { Key = "Quests", Name = "QuestsButton", Panel = "Quests" },
    { Key = "Shop", Name = "ShopButton", Panel = "VipShop" },
    { Key = "Daily", Name = "DailyButton", Panel = "VipShop" }, -- daily rewards live in the shop
    { Key = "Settings", Name = "SettingsButton" }, -- MusicSettingsUI's panel
}

-- Layout, reference pixels
LeftMenuConfig.Size = Vector2.new(886, 1543) -- whole menu
LeftMenuConfig.Home = { Position = Vector2.new(19, 0), Size = Vector2.new(570, 182) } -- as placed in the mockup
LeftMenuConfig.GridTop = 193 -- 11 px under the Home bar
LeftMenuConfig.CellSize = Vector2.new(442, 446)
LeftMenuConfig.CellPadding = Vector2.new(2, 6) -- between columns, between rows

-- On-screen size: the menu is shrunk so one square button is this many screen pixels wide
LeftMenuConfig.Desktop = { ButtonPx = 98, Margin = 16 } -- left edge, vertically centred
-- phones (shortest screen side < CompactBreakpoint): top-left; button size follows the screen height
LeftMenuConfig.Compact = {
    ButtonPxPerScreenHeight = 0.15,
    MinButtonPx = 44,
    MaxButtonPx = 52,
    Margin = 10,
    Top = 48, -- landscape
    TopPortrait = 82,
}
LeftMenuConfig.CompactBreakpoint = 600

-- Light feedback only
LeftMenuConfig.HoverScale = 1.02
LeftMenuConfig.PressScale = 0.96

return LeftMenuConfig
