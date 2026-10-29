-- ReplicatedStorage.SettingsMenu.SettingsComponent  (ModuleScript, client)
-- Draws the Settings window from the MenuArt art into a pixel-sized panel Frame: the window background (header,
-- Close X, five rows), slider rows (track / fill / knob pieces, a % value) and toggle rows (switch pieces, a
-- description), and the save hint. MusicSettings owns the values and passes them in / gets them back through
-- callbacks.
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
local UserInputService = game:GetService("UserInputService")

local StudUI = require(ReplicatedStorage:WaitForChild("StudKit"):WaitForChild("StudUI"))
local MenuArt = require(ReplicatedStorage:WaitForChild("MenuArt"):WaitForChild("MenuArt"))
local Config = require(script.Parent:WaitForChild("SettingsConfig"))

local Rows = Config.Rows
local Colors = MenuArt.Colors
local Z = 10 -- above the StudCanvas frame itself (StudTheme.ZIndex 8), so the hit-boxes get the clicks

local SettingsComponent = {}

local function percent(value)
    return value == 0 and "OFF" or (math.floor(value * 100 + 0.5) .. "%")
end

-- track + fill (clipped to the value) + knob; drag anywhere on the row's bar area. Returns set(value, silent).
local function slider(parent, r, value, onChange)
    MenuArt.piece(parent, "Track", "SliderTrack", r, Z + 1, 7)
    local clip = MenuArt.new("Frame", "FillClip", parent, Z + 2)
    clip.ClipsDescendants = true
    local fill = MenuArt.piece(clip, "Fill", "SliderFill", { 0, 0, r[3], r[4] }, Z + 2, 7)
    fill.Position = UDim2.fromOffset(0, 0)
    local knobSize = MenuArt.size("SliderKnob")
    local knob = MenuArt.piece(parent, "Knob", "SliderKnob", { 0, 0 }, Z + 3)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    local pad = Rows.SliderHitPadding
    local hit = MenuArt.hitBox(
        parent,
        "SliderHit",
        { r[1] - knobSize.X / 2, r[2] - pad, r[3] + knobSize.X, r[4] + pad * 2 },
        nil,
        Z + 4
    )
    local current = value
    local function set(newValue, silent)
        current = math.clamp(newValue, 0, 1)
        MenuArt.rect(clip, { r[1], r[2], r[3] * current, r[4] })
        knob.Position = UDim2.fromOffset(r[1] + r[3] * current, r[2] + r[4] / 2)
        if not silent then
            onChange(current)
        end
    end
    local dragging = false
    local function fromScreen(x)
        local left, width = hit.AbsolutePosition.X, hit.AbsoluteSize.X
        local inset = width * (knobSize.X / 2) / (r[3] + knobSize.X)
        set((x - left - inset) / math.max(width - inset * 2, 1))
    end
    hit.InputBegan:Connect(function(input)
        if
            input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            dragging = true
            fromScreen(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if
            dragging
            and (
                input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch
            )
        then
            fromScreen(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if
            input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            dragging = false
        end
    end)
    set(value, true)
    return set
end

-- the switch piece (on / off) + hit-box. Returns set(isOn, silent).
local function toggle(parent, r, value, onChange)
    local art = MenuArt.piece(parent, "Toggle", value and "ToggleOn" or "ToggleOff", r, Z + 1)
    local current = value
    local function set(isOn, silent)
        current = isOn
        MenuArt.setPiece(art, isOn and "ToggleOn" or "ToggleOff")
        if not silent then
            onChange(isOn)
        end
    end
    MenuArt.hitBox(parent, "ToggleHit", r, function()
        set(not current)
    end, Z + 2)
    return set
end

function SettingsComponent.new(panel, model)
    local canvas = StudUI.newCanvas(panel, panel)
    MenuArt.background(canvas, "Settings", nil, Z)
    MenuArt.hitBox(canvas, "Close", Config.Close, model.onClose, Z + 4)
    local setters = {}
    for i, row in model.rows do
        local top = Rows.Tops[i]
        if top then
            local card = MenuArt.new("Frame", "Row" .. i, canvas, Z)
            MenuArt.rect(card, { 0, top, 1160, Rows.Heights[i] })
            if row.kind == "slider" then
                MenuArt.label(card, "Title", row.title, Rows.SliderTitle, Rows.TitleSize, Colors.White, Z + 1)
                local value =
                    MenuArt.label(card, "Value", percent(row.value), Rows.Value, Rows.ValueSize, Colors.White, Z + 1, {
                        alignX = Enum.TextXAlignment.Right,
                    })
                local setSlider = slider(card, Rows.Slider, row.value, function(newValue)
                    value.Text = percent(newValue)
                    row.onChange(newValue)
                end)
                setters[i] = function(newValue, silent)
                    value.Text = percent(newValue)
                    setSlider(newValue, silent)
                end
            else
                MenuArt.label(card, "Title", row.title, Rows.ToggleTitle, Rows.TitleSize, Colors.White, Z + 1)
                MenuArt.label(
                    card,
                    "Text",
                    row.text or "",
                    Rows.Text,
                    Rows.TextSize,
                    Colors.Muted,
                    Z + 1,
                    { stroke = 2 }
                )
                setters[i] = toggle(card, Rows.Toggle, row.value, row.onChange)
            end
        end
    end
    local note = Config.Note
    MenuArt.label(canvas, "Note", note.Text, note.Rect, note.Size, Colors.Muted, Z + 1, { stroke = 2 })
    return { canvas = canvas, setters = setters }
end

return SettingsComponent
