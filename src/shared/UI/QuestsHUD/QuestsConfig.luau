-- ReplicatedStorage.QuestsHUD.QuestsConfig  (ModuleScript, client)
-- Every number for the collapsible quest tracker (QuestsComponent). Layout is in pixels of the reference mockup
-- (cropped to its content: 1383 px wide); the whole HUD is shrunk on screen with one UIScale.
local QuestsConfig = {}

-- Uploaded art (cropped to the artwork, transparent background). ImageSize = the uploaded image's pixels.
QuestsConfig.Assets = {
    Header = { Image = "rbxassetid://131587872728534", ImageSize = Vector2.new(1024, 225) },
    Row = { Image = "rbxassetid://100208411887972", ImageSize = Vector2.new(1024, 247) },
    Track = { Image = "rbxassetid://89596950192285", ImageSize = Vector2.new(1024, 144) },
    Fill = { Image = "rbxassetid://134609505073579", ImageSize = Vector2.new(1024, 131) },
    Chevron = "rbxassetid://104096368063169",
}
-- 9-slice centres (image pixels): borders and pixel corners keep their size, only the flat middle stretches
QuestsConfig.SliceCenter = {
    Header = Rect.new(40, 40, 984, 185),
    Row = Rect.new(40, 40, 984, 207),
    Track = Rect.new(40, 36, 984, 108),
    Fill = Rect.new(40, 40, 984, 91), -- needs real top / bottom edges, a 1 px edge renders washed out
}

-- Press Start 2P ships with Roblox (built-in font family, no upload needed)
QuestsConfig.Font = Font.new("rbxasset://fonts/families/PressStart2P.json")

-- Layout, reference pixels. Unit converts them to the root's own pixels (TextSize is capped at 100 by Roblox;
-- the 128 px title would not fit at Unit 1). The on-screen size is set separately (Desktop / Compact Width).
QuestsConfig.Unit = 0.5
QuestsConfig.Width = 1383
QuestsConfig.Header = {
    Height = 280,
    -- { X, Y, W, H }. Press Start 2P draws its glyphs at ~55 % of the box height and 0.57 em wide, so text boxes
    -- are sized for the reference text WIDTH ("QUESTS" = 608 px)
    Title = { 198, 55, 640, 178 }, -- the glyphs sit low in their box: nudged up to the reference line
    Chevron = { 1158, 67, 155, 150 },
}
QuestsConfig.Rows = {
    Top = 240, -- the first row's top border covers the header's bottom border
    Pitch = 360, -- row to row (neighbouring borders overlap)
    Height = 400,
    Description = { 100, 84, 900, 84 },
    Track = { 68, 184, 977, 149 },
    Fill = { 35, 40, 902, 82 }, -- inside the track
    Count = { 1090, 212, 188, 92 }, -- right-aligned
}
QuestsConfig.MaxRows = 3 -- the tracker shows the 3 open quests closest to done (as before)

-- On-screen width of the whole HUD (screen pixels), right side of the screen
QuestsConfig.Desktop = { Width = 246, Margin = 16, TopFromCentre = -121 } -- top edge, from the screen centre
QuestsConfig.Compact = { Width = 165, Margin = 10, Top = 62 } -- phones: top-right, under the top bar
QuestsConfig.CompactBreakpoint = 600

QuestsConfig.Colors = {
    Text = Color3.fromRGB(255, 255, 255),
    Outline = Color3.fromRGB(0, 0, 0),
}
-- Pixel outline = black copies of the label at integer offsets (8 directions), reference pixels
QuestsConfig.Outline = { Title = 10, Description = 8, Count = 8 } -- x Unit = 5 / 4 / 4 root px

QuestsConfig.CollapseTime = 0.22 -- seconds
QuestsConfig.FillTime = 0.3 -- progress fill animation, seconds

return QuestsConfig
