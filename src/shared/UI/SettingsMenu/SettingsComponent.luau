-- ReplicatedStorage.SettingsMenu.SettingsComponent  (ModuleScript, client)
-- Draws the Settings window (Figma "06 Settings") into a pixel-sized panel Frame with the StudKit pieces:
-- header with Close, one row per setting (slider rows with a % value, toggle rows with a description) and
-- the save hint. MusicSettings owns the values and passes them in / gets them back through callbacks.
--
--   local view = SettingsComponent.new(panel, {
--       onClose = function() ... end,
--       rows = {
--           { kind = "slider", title = "Music", value = 0.8, onChange = function(value) end },
--           { kind = "toggle", title = "Animations", text = "…", value = true, onChange = function(isOn) end },
--       },
--   })
--   view.setters[i](value, silent)   -- move a row's control without (silent) or with its callback
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = ReplicatedStorage:WaitForChild("StudKit")
local StudUI = require(Kit:WaitForChild("StudUI"))
local Theme = require(Kit:WaitForChild("StudTheme"))
local Config = require(script.Parent:WaitForChild("SettingsConfig"))

local Colors = Theme.Colors
local Rows = Config.Rows
local label = StudUI.label

local SettingsComponent = {}

local function percent(value)
    return value == 0 and "OFF" or (math.floor(value * 100 + 0.5) .. "%")
end

function SettingsComponent.new(panel, model)
    local canvas = StudUI.newCanvas(panel, panel)
    local z = StudUI.shell(canvas, Colors.Purple, Config.Title, model.onClose)
    local setters = {}
    for i, row in model.rows do
        local r = { Rows.X, Rows.Y + (i - 1) * Rows.Step, Rows.Width, Rows.Height }
        local card = StudUI.card(canvas, "Row" .. i, r, Colors.Panel2, Rows.Radius, Colors.Ink, nil, z)
        if row.kind == "slider" then
            label(card, "Title", row.title, Rows.SliderTitleRect, Rows.TitleSize, Colors.White, { display = true })
            local value = label(card, "Value", percent(row.value), Rows.ValueRect, Rows.ValueSize, Colors.White, {
                display = true,
                align = Enum.TextXAlignment.Right,
            })
            local setSlider = StudUI.slider(card, "Slider", Rows.SliderRect, row.value, function(newValue)
                value.Text = percent(newValue)
                row.onChange(newValue)
            end)
            setters[i] = function(newValue, silent)
                value.Text = percent(newValue)
                setSlider(newValue, silent)
            end
        else
            label(card, "Title", row.title, Rows.TitleRect, Rows.TitleSize, Colors.White, { display = true })
            label(card, "Text", row.text or "", Rows.TextRect, Rows.TextSize, Colors.Muted)
            setters[i] = StudUI.toggle(card, "Toggle", Rows.ToggleRect, row.value, row.onChange)
        end
    end
    label(canvas, "Note", Config.Note.Text, Config.Note.Rect, Config.Note.Size, Colors.Muted, { zIndex = z })
    return { canvas = canvas, setters = setters }
end

return SettingsComponent
