-- ReplicatedStorage.QuestsHUD.QuestsConfig  (ModuleScript, client)
-- Every number for the collapsible quest tracker (QuestsComponent). The art is one atlas built straight from the
-- mockup (assets/ui/quests/quest_atlas.png, text removed); layout is in its pixels (the panel is 252 px wide) and
-- the whole HUD is resized on screen with one UIScale.
local QuestsConfig = {}

QuestsConfig.Atlas = "rbxassetid://113548933851404" -- quest_atlas.png
-- pieces of the atlas: { X, Y, W, H }
QuestsConfig.Pieces = {
    Header = { 0, 0, 252, 52 }, -- top border + header (title area empty, chevron included)
    Card = { 0, 52, 252, 70 }, -- side borders + a card + the gap under it
    LastCard = { 0, 122, 252, 74 }, -- side borders + the last card + the bottom border
    Footer = { 0, 189, 252, 7 }, -- the bottom border alone (shown under the header when collapsed)
    Track = { 0, 196, 170, 22 }, -- empty progress bar
    Fill = { 0, 218, 170, 22 }, -- full progress bar (clipped to the progress)
    Chevron = { 172, 196, 31, 31 }, -- round button, drawn over the header's own copy so it can rotate
}

QuestsConfig.Font = Font.new("rbxasset://fonts/families/FredokaOne.json")

QuestsConfig.Width = 252

-- { X, Y, W, H }, atlas pixels
QuestsConfig.Header = {
    Title = { 31, 8, 160, 38 },
    TitleSize = 33,
    Chevron = { 209, 12, 31, 31 },
}
QuestsConfig.Rows = {
    -- inside a card piece
    Description = { 18, 4, 215, 27 },
    DescriptionSize = 20,
    Track = { 16, 35, 170, 22 },
    Count = { 183, 32, 48, 26 }, -- right-aligned
    CountSize = 21,
}
QuestsConfig.MaxRows = 3 -- the tracker shows the 3 open quests closest to done (as before)

-- On-screen width of the whole HUD (screen pixels), right side of the screen
QuestsConfig.Desktop = { Width = 246, Margin = 16, TopFromCentre = -121 } -- top edge, from the screen centre
QuestsConfig.Compact = { Width = 165, Margin = 10, Top = 62 } -- phones: top-right, under the top bar
QuestsConfig.CompactBreakpoint = 600

QuestsConfig.Colors = {
    Text = Color3.fromRGB(255, 255, 255),
    TextStroke = Color3.fromRGB(12, 4, 22),
}
QuestsConfig.Stroke = { Title = 3, Description = 2, Count = 2 } -- text outline thickness, atlas pixels

QuestsConfig.CollapseTime = 0.22 -- seconds
QuestsConfig.FillTime = 0.3 -- progress fill animation, seconds

return QuestsConfig
