-- ReplicatedStorage.SettingsMenu.SettingsConfig  (ModuleScript, client)
-- Every number for the Settings window (SettingsComponent). The art is ReplicatedStorage.MenuArt (the window
-- background with five rows, slider and switch pieces); rects are measured on it, in pixels of the StudTheme
-- canvas (1160 x 730) the window is drawn on.
local SettingsConfig = {}

-- Rect = { x, y, w, h } in canvas pixels; row rects are relative to the row's top
SettingsConfig.Close = { 1046, 60, 62, 62 } -- the drawn X
SettingsConfig.Rows = {
    Tops = { 152, 272, 395, 493, 590 },
    Heights = { 106, 106, 83, 82, 82 },
    TitleSize = 36,
    -- slider row
    SliderTitle = { 92, 30, 270, 46 },
    Slider = { 378, 43, 538, 17 }, -- the track
    Value = { 950, 30, 125, 46 },
    ValueSize = 34,
    SliderHitPadding = 18, -- the drag area reaches this far above / below the track
    -- toggle row
    ToggleTitle = { 92, 10, 700, 40 },
    Text = { 92, 49, 700, 26 },
    TextSize = 22,
    Toggle = { 976, 13, 93, 45 },
}

SettingsConfig.Note = { Rect = { 80, 677, 1000, 24 }, Size = 22, Text = "Settings are saved automatically." }

return SettingsConfig
