--[[ ReplicatedStorage.CharacterInventory.InventoryStyle  (ModuleScript)
Small building blocks shared by the inventory screen, the HUD button and the hatch reveal, in the
shrine redesign with the temples' colours (same as the leaderboard): a lacquer-brown shell under a
tile roof, a gold bevel and gold studs, an embossed gold title, a dark-brown wood page, cream cards
and wells, and brown buttons that sit on a darker lip.
Every surface is plain Frames: no images to upload or moderate.
]]
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent.InventoryConfig)
local T = Config.Theme
local F = Config.Fonts

local Style = {}
local QUICK = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function Style.Make(class, props, parent)
    local inst = Instance.new(class)
    for k, v in props do
        inst[k] = v
    end
    if parent then
        inst.Parent = parent
    end
    return inst
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

function Style.Pad(parent, l, t, r, b)
    return make("UIPadding", {
        PaddingLeft = UDim.new(0, l),
        PaddingTop = UDim.new(0, t or l),
        PaddingRight = UDim.new(0, r or l),
        PaddingBottom = UDim.new(0, b or t or l),
    }, parent)
end

function Style.Text(parent, props)
    local base = {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextColor3 = T.Text,
        FontFace = F.Body,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Size = UDim2.new(1, 0, 0, 18),
    }
    for k, v in props do
        base[k] = v
    end
    return make("TextLabel", base, parent)
end

-- Server colours for roll quality are pastel (made for dark billboards). On cream they are
-- darkened toward the ink so numbers stay readable; chips keep the pastel on a dark-brown chip.
function Style.Deep(color)
    return color:Lerp(T.Ink, 0.45)
end

-- Lacquer-brown shell with the gold bevel along the top, like the leaderboard's expanded view.
function Style.Shell(parent, props, radius)
    local f = make("Frame", {
        BackgroundColor3 = T.Panel,
        BackgroundTransparency = T.ShellTransparency,
        BorderSizePixel = 0,
    }, parent)
    for k, v in props or {} do
        f[k] = v
    end
    Style.Corner(f, radius or 12)
    Style.Stroke(f, T.PanelEdge, 1, 0.2)
    make("Frame", {
        Name = "Bevel",
        BorderSizePixel = 0,
        BackgroundColor3 = T.Bevel,
        BackgroundTransparency = 0.45,
        Position = UDim2.fromOffset((radius or 12), 2),
        Size = UDim2.new(1, -(radius or 12) * 2, 0, 2),
        ZIndex = f.ZIndex,
    }, f)
    return f
end
Style.Raised = Style.Shell

-- The dark-wood page inside a shell (soft vertical gradient, barely see-through), with a gold hairline.
function Style.Page(shell, left, top, right, bottom, radius)
    local page = make("Frame", {
        Name = "Page",
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = T.PageTransparency,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(left, top),
        Size = UDim2.new(1, -(left + right), 1, -(top + bottom)),
        ZIndex = shell.ZIndex,
    }, shell)
    Style.Corner(page, radius or 8)
    make("UIGradient", { Rotation = 90, Color = ColorSequence.new(T.ScreenTop, T.Screen) }, page)
    Style.Stroke(page, T.Gold, 1, 0.45)
    return page
end

-- Embossed gold title: white text tinted by a gold gradient, with a dark outline so it reads on wood.
function Style.GoldText(label, outline)
    label.TextColor3 = Color3.new(1, 1, 1)
    make("UIGradient", { Rotation = 90, Color = ColorSequence.new(T.GoldHi, T.Gold) }, label)
    make("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
        Color = T.RoofEdge,
        Thickness = outline or 2,
        LineJoinMode = Enum.LineJoinMode.Round,
    }, label)
    return label
end

-- Tile roof that sits on top of a shell: wider than it, a darker eave strip, a gold line,
-- upturned tips, a ridge and a gold sun crest. `height` px of it stands above the shell.
function Style.Roof(shell, height)
    local z = shell.ZIndex
    local function plain(name, parent, color, size, position)
        return make("Frame", {
            Name = name,
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Size = size,
            Position = position,
            ZIndex = z,
        }, parent)
    end
    local roof = plain("Roof", shell, T.Roof, UDim2.new(1, 28, 0, height), UDim2.fromOffset(-14, -height + 2))
    roof.Active = true -- clicks on the roof stay on the panel
    Style.Corner(roof, 5)
    plain("Eave", roof, T.RoofEdge, UDim2.new(1, -8, 0, 4), UDim2.new(0, 4, 1, -4))
    plain("Gold", roof, T.Gold, UDim2.new(1, -40, 0, 2), UDim2.fromOffset(20, 4)).BackgroundTransparency = 0.25
    for _, side in { 0, 1 } do
        local tip =
            plain("EaveTip", roof, T.Roof, UDim2.fromOffset(22, 8), UDim2.new(side, side == 0 and -6 or -16, 0, -2))
        tip.Rotation = side == 0 and -16 or 16
        Style.Corner(tip, 3)
    end
    Style.Corner(plain("Ridge", roof, T.RoofEdge, UDim2.new(0.56, 0, 0, 7), UDim2.new(0.22, 0, 0, -6)), 3)
    local crest = plain("Crest", roof, T.PanelEdge, UDim2.fromOffset(20, 20), UDim2.new(0.5, -10, 0, 1))
    crest.Rotation = 45
    crest.ZIndex = z + 1
    Style.Stroke(crest, T.Gold, 2)
    local sun = plain("Sun", crest, T.Gold, UDim2.fromOffset(8, 8), UDim2.fromOffset(6, 6))
    sun.ZIndex = z + 2
    Style.Corner(sun, 4)
    return roof
end

-- Recessed cream well (search box, Power block, comparison, portraits).
function Style.Inset(parent, props, radius)
    local f = make("Frame", { BackgroundColor3 = T.Inset, BorderSizePixel = 0, ClipsDescendants = true }, parent)
    for k, v in props or {} do
        f[k] = v
    end
    Style.Corner(f, radius or 6)
    Style.Stroke(f, T.CardEdge, 1)
    return f
end

-- One square gold stud, the same as on the leaderboard frame.
function Style.Stud(parent, x, y, size, zindex)
    local s = make("Frame", {
        Name = "Stud",
        BorderSizePixel = 0,
        BackgroundColor3 = T.Stud,
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(size, size),
        ZIndex = zindex or 1,
    }, parent)
    Style.Corner(s, 1)
    return s
end

-- A row of evenly spaced studs along the top of a shell. Rebuilds itself when the width changes,
-- so the studs always sit on the same pitch and never get cut at the edges.
function Style.StudBand(parent, height, pitch, stud, zindex)
    pitch = pitch or 28
    stud = stud or 6
    local band = make("Frame", {
        Name = "StudBand",
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, height),
        ZIndex = zindex or 1,
        ClipsDescendants = true,
    }, parent)
    local built = -1
    local function rebuild()
        local w = math.floor(band.AbsoluteSize.X)
        if w == built or w <= 0 then
            return
        end
        built = w
        for _, c in band:GetChildren() do
            if c.Name == "Stud" then
                c:Destroy()
            end
        end
        local count = math.max(1, math.floor((w - stud) / pitch) + 1)
        local start = math.floor((w - ((count - 1) * pitch + stud)) / 2)
        local y = math.floor((height - stud) / 2)
        for i = 0, count - 1 do
            Style.Stud(band, start + i * pitch, y, stud, band.ZIndex + 1)
        end
    end
    band:GetPropertyChangedSignal("AbsoluteSize"):Connect(rebuild)
    task.defer(rebuild)
    return band
end

function Style.Chip(parent, text, color, props)
    local chip = make("TextLabel", {
        Name = "Chip",
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = T.Ink,
        FontFace = F.Bold,
        TextSize = 10,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 16),
        TextXAlignment = Enum.TextXAlignment.Center,
    }, parent)
    for k, v in props or {} do
        chip[k] = v
    end
    Style.Corner(chip, 4)
    Style.Pad(chip, 5, 0, 5, 0)
    return chip
end

-- Brown button on a darker lip (the leaderboard's button), as one TextButton so it can auto-size
-- and take padding. kind = "Primary" (gold), "Secondary" (brown) or "Ghost" (cream).
-- button:SetAttribute("Disabled", true) dims it; Activated handlers check Style.Enabled(button).
function Style.Button(parent, text, kind, props)
    local primary, ghost = kind == "Primary", kind == "Ghost"
    local fill = primary and T.Gold or (ghost and T.Card or T.Chip)
    local lipColor = primary and T.GoldLo or (ghost and T.CardEdge or T.ButtonLip)
    local textColor = (primary or ghost) and T.Ink or T.ButtonText
    local b = make("TextButton", {
        Name = "Button",
        AutoButtonColor = false,
        BackgroundColor3 = fill,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = textColor,
        FontFace = primary and F.Head or F.Bold,
        TextSize = primary and 17 or 12,
        Size = UDim2.fromOffset(120, 34),
        Selectable = true,
    }, parent)
    for k, v in props or {} do
        b[k] = v
    end
    b:SetAttribute("BaseText", textColor)
    Style.Corner(b, 7)
    local edge = Style.Stroke(b, lipColor, 1)
    edge.Name = "Edge"
    make("UIGradient", { -- soft top light, same as the leaderboard buttons
        Rotation = 90,
        Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(226, 220, 214)),
    }, b)
    local lip = make("Frame", {
        Name = "Lip",
        BorderSizePixel = 0,
        BackgroundColor3 = lipColor,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 4, 1, 0),
        Size = UDim2.new(1, -8, 0, 2),
        ZIndex = b.ZIndex,
    }, b)
    local scale = make("UIScale", { Scale = 1 }, b)
    local function refresh(hover)
        local disabled = b:GetAttribute("Disabled") == true
        local target = b:GetAttribute("Fill") or fill
        if disabled then
            target = primary and T.GoldOff or (ghost and T.Inset or T.ButtonOff)
        elseif hover then
            target = target:Lerp(Color3.new(1, 1, 1), 0.1)
        end
        TweenService:Create(b, QUICK, { BackgroundColor3 = target }):Play()
        b.TextTransparency = disabled and 0.35 or 0
        lip.Visible = not disabled
    end
    b.MouseEnter:Connect(function()
        refresh(true)
    end)
    b.MouseLeave:Connect(function()
        refresh(false)
    end)
    b.SelectionGained:Connect(function()
        refresh(true)
    end)
    b.SelectionLost:Connect(function()
        refresh(false)
    end)
    b.MouseButton1Down:Connect(function()
        if b:GetAttribute("Disabled") then
            return
        end
        TweenService:Create(scale, QUICK, { Scale = 0.96 }):Play()
    end)
    local function release()
        TweenService:Create(scale, QUICK, { Scale = 1 }):Play()
    end
    b.MouseButton1Up:Connect(release)
    b.MouseLeave:Connect(release)
    b:GetAttributeChangedSignal("Disabled"):Connect(function()
        refresh(false)
    end)
    b:GetAttributeChangedSignal("Fill"):Connect(function()
        refresh(false)
    end)
    return b
end

-- Toggle look for filter / sort buttons: the active one turns taupe with gold text, like leaderboard tabs.
function Style.SetOn(button, on)
    button:SetAttribute("Fill", on and T.ChipOn or T.Chip)
    button.TextColor3 = on and T.ButtonText or T.ButtonTextDim
end

function Style.Enabled(button)
    return button:GetAttribute("Disabled") ~= true
end

-- Frames a model inside a ViewportFrame once (static camera). Returns the camera.
function Style.FrameModel(viewport, model, yaw, tightness)
    local cam = viewport.CurrentCamera
    if not cam then
        cam = make("Camera", { FieldOfView = 30 }, viewport)
        viewport.CurrentCamera = cam
    end
    local cf, size = model:GetBoundingBox()
    local radius = math.max(size.X, size.Y * 1.05, size.Z) * 0.5
    local dist = radius / math.tan(math.rad(cam.FieldOfView * 0.5)) * (tightness or 1.15)
    -- view from the model's own front, turned by `yaw` degrees for a three-quarter angle
    local facing = (model:GetPivot().Rotation * CFrame.Angles(0, math.rad(yaw or 20), 0)).LookVector
    facing = Vector3.new(facing.X, 0, facing.Z).Unit
    cam.CFrame = CFrame.lookAt(cf.Position + facing * dist + Vector3.new(0, size.Y * 0.08, 0), cf.Position)
    return cam
end

return Style
