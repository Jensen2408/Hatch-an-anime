-- ReplicatedStorage.SettingsMenu.SettingsConfig  (ModuleScript, client)
-- Every number for the Settings window (SettingsComponent). Layout values come from the Figma frame
-- "06 Settings" (Hatch an Anime • Screens & Components), measured from the Panel's top-left corner, in Figma
-- pixels, on the StudTheme canvas (1160x730). Colors, fonts and the kit pieces: StudKit.
--
-- The frame has four toggle rows (1100x94, 112 px apart) and a UI SCALE slider. The game has two volume
-- sliders and three switches, so all five use the frame's row: volume rows lay the UI SCALE slider
-- (label, 600 px bar, value) inside the row, toggle rows keep the Toggle at the frame's spot. Five rows fit
-- at 106 px apart; the frame's placeholder note becomes the save hint.
local SettingsConfig = {}

SettingsConfig.Title = "SETTINGS" -- Header/purple

-- Rect = { x, y, w, h } in canvas pixels (inner rects are relative to their row)
SettingsConfig.Rows = {
    X = 30,
    Y = 108,
    Width = 1100,
    Height = 94,
    Step = 106,
    Radius = 12,
    TitleSize = 32,
    -- toggle row
    TitleRect = { 24, 10, 720, 42 },
    TextRect = { 24, 52, 720, 30 },
    TextSize = 20,
    ToggleRect = { 984, 25, 86, 44 },
    -- slider row (UI SCALE layout)
    SliderTitleRect = { 24, 25, 290, 45 },
    SliderRect = { 330, 37, 600, 20 },
    ValueRect = { 960, 25, 116, 45 },
    ValueSize = 30,
}

SettingsConfig.Note = { Rect = { 54, 650, 1052, 32 }, Size = 22, Text = "Settings are saved automatically." }

return SettingsConfig
