--[[ ReplicatedStorage.CharacterInventory.InventoryStyle  (ModuleScript)
Small building blocks shared by the inventory screen, the HUD button and the hatch reveal, in the
shrine redesign with the temples' colours (same as the leaderboard): a lacquer-brown shell under a
tile roof, a gold bevel and gold studs, an embossed gold title, a dark-brown wood page, cream cards
and wells, and brown buttons that sit on a darker lip.
Every surface is plain Frames: no images to upload or moderate.
]]
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent.InventoryConfig)
local Theme = Config.Theme
local Fonts = Config.Fonts

local Style = {}
local QUICK_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- button hover / press

-- Instance.new + property table; Parent is set last so the instance is fully configured first.
function Style.Make(class, props, parent)
    local instance = Instance.new(class)
    for key, value in props do
        instance[key] = value
    end
    if parent then
        instance.Parent = parent
    end
    return instance
end
local make = Style.Make

function Style.Corner(parent, px)
    return make("UICorner", { CornerRadius = UDim.new(0, px) }, parent)
end

function Style.Stroke(parent, color, thickness, transparency)
    return make("UIStroke", {
        Color = color,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        LineJoinMode = Enum.LineJoinMode.Round,
    }, parent)
end

-- CSS-like padding: Pad(p, all), Pad(p, horizontal, vertical) or Pad(p, left, top, right, bottom).
function Style.Pad(parent, left, top, right, bottom)
    return make("UIPadding", {
        PaddingLeft = UDim.new(0, left),
        PaddingTop = UDim.new(0, top or left),
        PaddingRight = UDim.new(0, right or left),
        PaddingBottom = UDim.new(0, bottom or top or left),
    }, parent)
end

-- TextLabel with the inventory's defaults (transparent, body font, left-aligned, truncated); props override.
function Style.Text(parent, props)
    local base = {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextColor3 = Theme.Text,
        FontFace = Fonts.Body,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Size = UDim2.new(1, 0, 0, 18),
    }
    for key, value in props do
        base[key] = value
    end
    return make("TextLabel", base, parent)
end

-- Server colours for roll quality are pastel (made for dark billboards). On cream they are
-- darkened toward the ink so numbers stay readable; chips keep the pastel on a dark-brown chip.
function Style.Deep(color)
    return color:Lerp(Theme.Ink, 0.45)
end

-- Lacquer-brown shell with the gold bevel along the top, like the leaderboard's expanded view.
function Style.Shell(parent, props, radius)
    local shell = make("Frame", {
        BackgroundColor3 = Theme.Panel,
        BackgroundTransparency = Theme.ShellTransparency,
        BorderSizePixel = 0,
    }, parent)
    for key, value in props or {} do
        shell[key] = value
    end
    Style.Corner(shell, radius or 12)
    Style.Stroke(shell, Theme.PanelEdge, 1, 0.2)
    make("Frame", {
        Name = "Bevel",
        BorderSizePixel = 0,
        BackgroundColor3 = Theme.Bevel,
        BackgroundTransparency = 0.45,
        Position = UDim2.fromOffset((radius or 12), 2),
        Size = UDim2.new(1, -(radius or 12) * 2, 0, 2),
        ZIndex = shell.ZIndex,
    }, shell)
    return shell
end
Style.Raised = Style.Shell -- alias kept for callers

-- The dark-wood page inside a shell (soft vertical gradient, barely see-through), with a gold hairline.
function Style.Page(shell, left, top, right, bottom, radius)
    local page = make("Frame", {
        Name = "Page",
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = Theme.PageTransparency,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(left, top),
        Size = UDim2.new(1, -(left + right), 1, -(top + bottom)),
        ZIndex = shell.ZIndex,
    }, shell)
    Style.Corner(page, radius or 8)
    make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Theme.ScreenTop, Theme.Screen) }, page)
    Style.Stroke(page, Theme.Gold, 1, 0.45)
    return page
end

-- Embossed gold title: white text tinted by a gold gradient, with a dark outline so it reads on wood.
function Style.GoldText(label, outline)
    label.TextColor3 = Color3.new(1, 1, 1)
    make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Theme.GoldHi, Theme.Gold) }, label)
    make("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
        Color = Theme.RoofEdge,
        Thickness = outline or 2,
        LineJoinMode = Enum.LineJoinMode.Round,
    }, label)
    return label
end

-- Tile roof that sits on top of a shell: wider than it, a darker eave strip, a gold line,
-- upturned tips, a ridge and a gold sun crest. `height` px of it stands above the shell.
function Style.Roof(shell, height)
    local zIndex = shell.ZIndex
    local function plain(name, parent, color, size, position)
        return make("Frame", {
            Name = name,
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Size = size,
            Position = position,
            ZIndex = zIndex,
        }, parent)
    end
    local roof = plain("Roof", shell, Theme.Roof, UDim2.new(1, 28, 0, height), UDim2.fromOffset(-14, -height + 2))
    roof.Active = true -- clicks on the roof stay on the panel
    Style.Corner(roof, 5)
    plain("Eave", roof, Theme.RoofEdge, UDim2.new(1, -8, 0, 4), UDim2.new(0, 4, 1, -4))
    plain("Gold", roof, Theme.Gold, UDim2.new(1, -40, 0, 2), UDim2.fromOffset(20, 4)).BackgroundTransparency = 0.25
    for _, side in { 0, 1 } do
        local tip =
            plain("EaveTip", roof, Theme.Roof, UDim2.fromOffset(22, 8), UDim2.new(side, side == 0 and -6 or -16, 0, -2))
        tip.Rotation = side == 0 and -16 or 16
        Style.Corner(tip, 3)
    end
    Style.Corner(plain("Ridge", roof, Theme.RoofEdge, UDim2.new(0.56, 0, 0, 7), UDim2.new(0.22, 0, 0, -6)), 3)
    local crest = plain("Crest", roof, Theme.PanelEdge, UDim2.fromOffset(20, 20), UDim2.new(0.5, -10, 0, 1))
    crest.Rotation = 45
    crest.ZIndex = zIndex + 1
    Style.Stroke(crest, Theme.Gold, 2)
    local sun = plain("Sun", crest, Theme.Gold, UDim2.fromOffset(8, 8), UDim2.fromOffset(6, 6))
    sun.ZIndex = zIndex + 2
    Style.Corner(sun, 4)
    return roof
end

-- Recessed cream well (search box, Power block, comparison, portraits).
function Style.Inset(parent, props, radius)
    local well = make("Frame", { BackgroundColor3 = Theme.Inset, BorderSizePixel = 0, ClipsDescendants = true }, parent)
    for key, value in props or {} do
        well[key] = value
    end
    Style.Corner(well, radius or 6)
    Style.Stroke(well, Theme.CardEdge, 1)
    return well
end

-- One square gold stud, the same as on the leaderboard frame.
function Style.Stud(parent, x, y, size, zindex)
    local stud = make("Frame", {
        Name = "Stud",
        BorderSizePixel = 0,
        BackgroundColor3 = Theme.Stud,
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(size, size),
        ZIndex = zindex or 1,
    }, parent)
    Style.Corner(stud, 1)
    return stud
end

-- A row of evenly spaced studs along the top of a shell. Rebuilds itself when the width changes,
-- so the studs always sit on the same pitch and never get cut at the edges.
function Style.StudBand(parent, height, pitch, studSize, zindex)
    pitch = pitch or 28
    studSize = studSize or 6
    local band = make("Frame", {
        Name = "StudBand",
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, height),
        ZIndex = zindex or 1,
        ClipsDescendants = true,
    }, parent)
    local builtWidth = -1 -- width the current studs were laid out for
    local function rebuild()
        local width = math.floor(band.AbsoluteSize.X)
        if width == builtWidth or width <= 0 then
            return
        end
        builtWidth = width
        for _, child in band:GetChildren() do
            if child.Name == "Stud" then
                child:Destroy()
            end
        end
        local count = math.max(1, math.floor((width - studSize) / pitch) + 1)
        local startX = math.floor((width - ((count - 1) * pitch + studSize)) / 2) -- centre the row
        local y = math.floor((height - studSize) / 2)
        for i = 0, count - 1 do
            Style.Stud(band, startX + i * pitch, y, studSize, band.ZIndex + 1)
        end
    end
    band:GetPropertyChangedSignal("AbsoluteSize"):Connect(rebuild)
    task.defer(rebuild)
    return band
end

-- Small rounded label (rarity, roll quality, state, key hint) that auto-sizes to its text.
function Style.Chip(parent, text, color, props)
    local chip = make("TextLabel", {
        Name = "Chip",
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = Theme.Ink,
        FontFace = Fonts.Bold,
        TextSize = 10,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 16),
        TextXAlignment = Enum.TextXAlignment.Center,
    }, parent)
    for key, value in props or {} do
        chip[key] = value
    end
    Style.Corner(chip, 4)
    Style.Pad(chip, 5, 0, 5, 0)
    return chip
end

-- Brown button on a darker lip (the leaderboard's button), as one TextButton so it can auto-size
-- and take padding. kind = "Primary" (gold), "Secondary" (brown) or "Ghost" (cream).
-- button:SetAttribute("Disabled", true) dims it; Activated handlers check Style.Enabled(button).
-- Attribute "Fill" (Color3) overrides the resting colour (see Style.SetOn); "BaseText" records the
-- original text colour.
function Style.Button(parent, text, kind, props)
    local primary, ghost = kind == "Primary", kind == "Ghost"
    local fill = primary and Theme.Gold or (ghost and Theme.Card or Theme.Chip)
    local lipColor = primary and Theme.GoldLo or (ghost and Theme.CardEdge or Theme.ButtonLip)
    local textColor = (primary or ghost) and Theme.Ink or Theme.ButtonText
    local button = make("TextButton", {
        Name = "Button",
        AutoButtonColor = false,
        BackgroundColor3 = fill,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = textColor,
        FontFace = primary and Fonts.Head or Fonts.Bold,
        TextSize = primary and 17 or 12,
        Size = UDim2.fromOffset(120, 34),
        Selectable = true,
    }, parent)
    for key, value in props or {} do
        button[key] = value
    end
    button:SetAttribute("BaseText", textColor)
    Style.Corner(button, 7)
    local edge = Style.Stroke(button, lipColor, 1)
    edge.Name = "Edge"
    make("UIGradient", { -- soft top light, same as the leaderboard buttons
        Rotation = 90,
        Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(226, 220, 214)),
    }, button)
    local lip = make("Frame", {
        Name = "Lip",
        BorderSizePixel = 0,
        BackgroundColor3 = lipColor,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 4, 1, 0),
        Size = UDim2.new(1, -8, 0, 2),
        ZIndex = button.ZIndex,
    }, button)
    local scale = make("UIScale", { Scale = 1 }, button)
    local function refresh(hover)
        local disabled = button:GetAttribute("Disabled") == true
        local target = button:GetAttribute("Fill") or fill
        if disabled then
            target = primary and Theme.GoldOff or (ghost and Theme.Inset or Theme.ButtonOff)
        elseif hover then
            target = target:Lerp(Color3.new(1, 1, 1), 0.1)
        end
        TweenService:Create(button, QUICK_TWEEN, { BackgroundColor3 = target }):Play()
        button.TextTransparency = disabled and 0.35 or 0
        lip.Visible = not disabled
    end
    button.MouseEnter:Connect(function()
        refresh(true)
    end)
    button.MouseLeave:Connect(function()
        refresh(false)
    end)
    button.SelectionGained:Connect(function()
        refresh(true)
    end)
    button.SelectionLost:Connect(function()
        refresh(false)
    end)
    button.MouseButton1Down:Connect(function()
        if button:GetAttribute("Disabled") then
            return
        end
        TweenService:Create(scale, QUICK_TWEEN, { Scale = 0.96 }):Play()
    end)
    local function release()
        TweenService:Create(scale, QUICK_TWEEN, { Scale = 1 }):Play()
    end
    button.MouseButton1Up:Connect(release)
    button.MouseLeave:Connect(release)
    button:GetAttributeChangedSignal("Disabled"):Connect(function()
        refresh(false)
    end)
    button:GetAttributeChangedSignal("Fill"):Connect(function()
        refresh(false)
    end)
    return button
end

-- Toggle look for filter / sort buttons: the active one turns taupe with gold text, like leaderboard tabs.
function Style.SetOn(button, on)
    button:SetAttribute("Fill", on and Theme.ChipOn or Theme.Chip)
    button.TextColor3 = on and Theme.ButtonText or Theme.ButtonTextDim
end

function Style.Enabled(button)
    return button:GetAttribute("Disabled") ~= true
end

-- Frames a model inside a ViewportFrame once (static camera). Returns the camera.
function Style.FrameModel(viewport, model, yaw, tightness)
    local camera = viewport.CurrentCamera
    if not camera then
        camera = make("Camera", { FieldOfView = 30 }, viewport)
        viewport.CurrentCamera = camera
    end
    local boxCFrame, size = model:GetBoundingBox()
    local radius = math.max(size.X, size.Y * 1.05, size.Z) * 0.5
    -- distance at which a sphere of `radius` fits the vertical FOV, times `tightness` (> 1 = more margin)
    local distance = radius / math.tan(math.rad(camera.FieldOfView * 0.5)) * (tightness or 1.15)
    -- view from the model's own front, turned by `yaw` degrees for a three-quarter angle
    local facing = (model:GetPivot().Rotation * CFrame.Angles(0, math.rad(yaw or 20), 0)).LookVector
    facing = Vector3.new(facing.X, 0, facing.Z).Unit
    camera.CFrame =
        CFrame.lookAt(boxCFrame.Position + facing * distance + Vector3.new(0, size.Y * 0.08, 0), boxCFrame.Position)
    return camera
end

return Style
