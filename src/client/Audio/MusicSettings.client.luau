--[[ StarterPlayerScripts.MusicSettings  — Settings button + panel
Music volume, sound-effects volume, reduced motion, night sky effects and floating labels.
Music = sounds under workspace.Music. Sound effects = everything else (routed into SoundService.SFX).
Values are kept on the player as attributes for this session (MusicVolume, SFXVolume, SFXMuted, ReducedMotion, ...).
]]
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UISound = require(game:GetService("ReplicatedStorage"):WaitForChild("UISound"))
local player = Players.LocalPlayer
do
    local t = os.clock()
    while not player:GetAttribute("DataLoaded") and os.clock() - t < 8 do
        task.wait(0.1)
    end
end -- saved settings arrive with the save
local pg = player:WaitForChild("PlayerGui")

local CREAM, CARD, INK, RED, GOLD, GREEN, MUTED =
    Color3.fromRGB(255, 243, 217),
    Color3.fromRGB(246, 226, 192),
    Color3.fromRGB(56, 34, 24),
    Color3.fromRGB(204, 68, 54),
    Color3.fromRGB(242, 190, 85),
    Color3.fromRGB(85, 163, 78),
    Color3.fromRGB(150, 120, 96)
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local function make(c, p, parent)
    local o = Instance.new(c)
    for k, v in p do
        o[k] = v
    end
    if parent then
        o.Parent = parent
    end
    return o
end
local function round(o, r)
    make("UICorner", { CornerRadius = UDim.new(0, r) }, o)
end
local function text(parent, t, size, color, props)
    local l = make(
        "TextLabel",
        { BackgroundTransparency = 1, FontFace = FONT, Text = t, TextSize = size, TextColor3 = color or INK },
        parent
    )
    for k, v in props or {} do
        l[k] = v
    end
    return l
end
-- chunky button: dark base + face
local function chunky(parent, w, h, color, label, props)
    local hold = make("Frame", { Size = UDim2.fromOffset(w, h + 4), BackgroundTransparency = 1 }, parent)
    for k, v in props or {} do
        hold[k] = v
    end
    local base = make("Frame", {
        Position = UDim2.fromOffset(0, 4),
        Size = UDim2.new(1, 0, 1, -4),
        BackgroundColor3 = INK,
        BorderSizePixel = 0,
    }, hold)
    round(base, 10)
    local face = make("TextButton", {
        Size = UDim2.new(1, 0, 1, -4),
        BackgroundColor3 = color,
        AutoButtonColor = false,
        Text = "",
        BorderSizePixel = 0,
    }, hold)
    round(face, 10)
    make("UIStroke", { Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, face)
    local l = text(face, label, 16, Color3.new(1, 1, 1), { Size = UDim2.fromScale(1, 1) })
    local function y(v)
        TweenService:Create(face, TweenInfo.new(0.08), { Position = UDim2.fromOffset(0, v) }):Play()
    end
    face.MouseEnter:Connect(function()
        y(-2)
    end)
    face.MouseLeave:Connect(function()
        y(0)
    end)
    face.MouseButton1Down:Connect(function()
        y(4)
    end)
    face.MouseButton1Up:Connect(function()
        y(0)
    end)
    return face, l, hold
end

local gui = make("ScreenGui", { Name = "MusicSettingsUI", ResetOnSpawn = false, DisplayOrder = 45 }, pg)
local toggle, toggleLabel =
    chunky(gui, 52, 52, RED, "⚙", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -22, 0, 190) })
toggleLabel.Text = ""
require(game:GetService("ReplicatedStorage"):WaitForChild("PixelIcon")).build(toggle, "gear", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(1, -14, 1, -14),
    ZIndex = toggle.ZIndex + 1,
})

-- panel
local panel = make("Frame", {
    Name = "Panel",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(340, 408),
    BackgroundTransparency = 1,
    Visible = false,
}, gui)
local pscale = make("UIScale", {}, panel)
local pbase = make(
    "Frame",
    { Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 1, -6), BackgroundColor3 = INK, BorderSizePixel = 0 },
    panel
)
round(pbase, 18)
local body = make("Frame", { Size = UDim2.new(1, 0, 1, -6), BackgroundColor3 = CREAM, BorderSizePixel = 0 }, panel)
round(body, 18)
make("UIStroke", { Color = INK, Thickness = 3 }, body)
local head = make("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = RED, BorderSizePixel = 0 }, body)
round(head, 18)
make(
    "Frame",
    { Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 18), BackgroundColor3 = RED, BorderSizePixel = 0 },
    head
)
make(
    "Frame",
    { Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = INK, BorderSizePixel = 0 },
    head
)
make(
    "UIStroke",
    { Color = Color3.new(0, 0, 0), Thickness = 2.5 },
    text(head, "SETTINGS", 26, Color3.new(1, 1, 1), { Size = UDim2.fromScale(1, 1) })
)
local close = make("TextButton", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(1, -26, 0, 25),
    Size = UDim2.fromOffset(32, 32),
    BackgroundColor3 = CREAM,
    Text = "X",
    FontFace = FONT,
    TextSize = 18,
    TextColor3 = RED,
    AutoButtonColor = true,
}, body)
round(close, 16)
make("UIStroke", { Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, close)
local list = make(
    "Frame",
    { Position = UDim2.fromOffset(14, 64), Size = UDim2.new(1, -28, 1, -76), BackgroundTransparency = 1 },
    body
)
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)

local function row(order, h)
    local r = make(
        "Frame",
        { LayoutOrder = order, Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = CARD, BorderSizePixel = 0 },
        list
    )
    round(r, 12)
    make("UIStroke", { Color = Color3.fromRGB(205, 170, 120), Thickness = 1.5 }, r)
    return r
end

-- slider row
local dragging
local function slider(order, title, initial, onChange)
    local r = row(order, 64)
    text(r, title, 17, INK, {
        Position = UDim2.fromOffset(12, 6),
        Size = UDim2.new(1, -80, 0, 22),
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local val = text(r, "", 16, MUTED, {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 6),
        Size = UDim2.fromOffset(60, 22),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local track = make("Frame", {
        Position = UDim2.fromOffset(14, 40),
        Size = UDim2.new(1, -28, 0, 10),
        BackgroundColor3 = Color3.fromRGB(214, 190, 150),
        BorderSizePixel = 0,
    }, r)
    round(track, 5)
    local fill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = GOLD, BorderSizePixel = 0 }, track)
    round(fill, 5)
    local knob = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(1, 0.5),
        Size = UDim2.fromOffset(22, 22),
        BackgroundColor3 = CREAM,
        BorderSizePixel = 0,
    }, track)
    round(knob, 11)
    make("UIStroke", { Color = INK, Thickness = 2 }, knob)
    local hit = make(
        "TextButton",
        { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Text = "" },
        r
    )
    hit:SetAttribute("UISoundMuted", true)
    local s = {}
    function s.set(v, silent)
        v = math.clamp(v, 0, 1)
        fill.Size = UDim2.fromScale(v, 1)
        knob.Position = UDim2.fromScale(v, 0.5)
        val.Text = v == 0 and "OFF" or (math.floor(v * 100 + 0.5) .. "%")
        if not silent then
            onChange(v)
        end
    end
    local function at(x)
        s.set((x - track.AbsolutePosition.X) / track.AbsoluteSize.X)
    end
    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = { s = at, input = i }
            at(i.Position.X)
        end
    end)
    s.set(initial)
    return s
end
UIS.InputChanged:Connect(function(i)
    if
        dragging
        and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch)
    then
        dragging.s(i.Position.X)
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = nil
    end
end)

-- toggle row
local function switch(order, title, desc, initial, onChange)
    local r = row(order, 50)
    text(r, title, 16, INK, {
        Position = UDim2.fromOffset(12, 5),
        Size = UDim2.new(1, -90, 0, 22),
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    text(r, desc, 12, MUTED, {
        Position = UDim2.fromOffset(12, 26),
        Size = UDim2.new(1, -90, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local pill = make("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(56, 28),
        BackgroundColor3 = GREEN,
        Text = "",
        AutoButtonColor = false,
    }, r)
    round(pill, 14)
    make("UIStroke", { Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, pill)
    local dot = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.75, 0.5),
        Size = UDim2.fromOffset(20, 20),
        BackgroundColor3 = CREAM,
    }, pill)
    round(dot, 10)
    make("UIStroke", { Color = INK, Thickness = 1.5 }, dot)
    local on = initial
    local function paint()
        TweenService
            :Create(pill, TweenInfo.new(0.15), { BackgroundColor3 = on and GREEN or Color3.fromRGB(190, 170, 145) })
            :Play()
        TweenService:Create(
            dot,
            TweenInfo.new(0.15, Enum.EasingStyle.Back),
            { Position = UDim2.fromScale(on and 0.72 or 0.28, 0.5) }
        ):Play()
    end
    pill.Activated:Connect(function()
        on = not on
        paint()
        onChange(on)
    end)
    paint()
    onChange(on)
end

---------------------------------------------------------------- music
local musicVol, originals = player:GetAttribute("MusicVolume") or 1, {}
local function isMusic(sound)
    local m = workspace:FindFirstChild("Music")
    return m and sound:IsDescendantOf(m)
end
---------------------------------------------------------------- sound effects (everything that isn't music)
local sfx = SoundService:FindFirstChild("SFX")
if not (sfx and sfx:IsA("SoundGroup")) then
    sfx = make("SoundGroup", { Name = "SFX", Volume = 1 }, SoundService)
end
local function register(sound)
    if not sound:IsA("Sound") then
        return
    end
    if isMusic(sound) then
        if not originals[sound] then
            originals[sound] = sound.Volume
            sound.Volume = originals[sound] * musicVol
        end
    elseif not sound.SoundGroup then
        sound.SoundGroup = sfx
    end
end
task.spawn(function()
    for _, root in { workspace, pg, SoundService } do
        for n, d in root:GetDescendants() do
            if d:IsA("Sound") then
                pcall(register, d)
            end
            if n % 2000 == 0 then
                task.wait()
            end
        end
        root.DescendantAdded:Connect(function(d)
            if d:IsA("Sound") then
                task.defer(pcall, register, d)
            end
        end)
    end
end)

local musicSlider = slider(1, "Music", musicVol, function(v)
    musicVol = v
    player:SetAttribute("MusicVolume", v)
    for snd, b in originals do
        if snd.Parent then
            snd.Volume = b * v
        else
            originals[snd] = nil
        end
    end
end)
slider(2, "Sound effects", player:GetAttribute("SFXVolume") or 1, function(v)
    sfx.Volume = v
    player:SetAttribute("SFXVolume", v)
    player:SetAttribute("SFXMuted", v == 0)
end)
switch(
    3,
    "Animations",
    "Turn off for simpler, calmer effects",
    player:GetAttribute("ReducedMotion") ~= true,
    function(on)
        player:SetAttribute("ReducedMotion", not on)
    end
)
switch(
    4,
    "Night sky effects",
    "Aurora and floating stars at night",
    player:GetAttribute("NightFX") ~= false,
    function(on)
        player:SetAttribute("NightFX", on)
        local fx = workspace:FindFirstChild("NighttimeLocalFX")
        if fx then
            for _, d in fx:GetDescendants() do
                if d:IsA("Beam") or d:IsA("ParticleEmitter") then
                    d:SetAttribute("UserOff", not on)
                    if not on then
                        d.Enabled = false
                    end
                end
            end
        end
    end
)
switch(5, "Floating labels", "Names and stats above characters", player:GetAttribute("HideLabels") ~= true, function(on)
    player:SetAttribute("HideLabels", not on)
    for _, b in pg:GetChildren() do
        if b:IsA("BillboardGui") and b.Name == "CharacterInfoLabel" then
            b.Enabled = on
        end
    end
end)
do -- apply saved values + save changes
    sfx.Volume = player:GetAttribute("SFXVolume") or 1
    local keys = { "MusicVolume", "SFXVolume", "SFXMuted", "ReducedMotion", "NightFX", "HideLabels" }
    local pending = false
    local remote = game:GetService("ReplicatedStorage"):WaitForChild("SaveSettings", 10)
    player.AttributeChanged:Connect(function(name)
        if not remote or pending or not table.find(keys, name) then
            return
        end
        pending = true
        task.delay(1.5, function()
            pending = false
            local t = {}
            for _, k in keys do
                t[k] = player:GetAttribute(k)
            end
            remote:FireServer(t)
        end)
    end)
end
pg.ChildAdded:Connect(function(b)
    if b.Name == "CharacterInfoLabel" and player:GetAttribute("HideLabels") then
        task.defer(function()
            b.Enabled = false
        end)
    end
end)

---------------------------------------------------------------- open / close
local open = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
local BASE_DISPLAY = gui.DisplayOrder -- 45

local function panelFit()
    local v = gui.AbsoluteSize
    return math.max(0.01, math.min(1, (v.X - 32) / 340, (v.Y - 32) / 408))
end
local function layoutSettings()
    local v = gui.AbsoluteSize
    if v.X <= 0 or v.Y <= 0 then
        return
    end
    local s = math.min(1, v.X / 600, v.Y / 560)
    if toggle.Parent.Parent == gui then
        toggle.Parent.Position = UDim2.new(1, -10, 0, 20 + 104 * s)
    end
    -- phones: smaller gear (GameHUD stacks the EGGS button right under it, clear of the jump button)
    local ts = toggle.Parent:FindFirstChild("PhoneScale") or make("UIScale", { Name = "PhoneScale" }, toggle.Parent)
    ts.Scale = toggle.Parent.Parent ~= gui and 1 or (v.Y < 600 and math.clamp(v.Y / 720, 0.6, 1) or 1)
    pscale.Scale = panelFit()
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutSettings)
layoutSettings()
local function setOpen(v)
    if open ~= v then
        UISound.Play(v and "Open" or "Close")
    end
    open = v
    -- When Settings panel is open, render above GameMenus' boosted DisplayOrder (60)
    gui.DisplayOrder = v and math.max(BASE_DISPLAY, 65) or BASE_DISPLAY
    if v then
        panel.Visible = true
        pscale.Scale = panelFit() * 0.85
        TweenService:Create(pscale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = panelFit() }):Play()
    else
        local t = TweenService:Create(pscale, TweenInfo.new(0.12), { Scale = panelFit() * 0.85 })
        t:Play()
        t.Completed:Once(function()
            if not open then
                panel.Visible = false
            end
        end)
    end
end
toggle.Activated:Connect(function()
    setOpen(not open)
end)
close.Activated:Connect(function()
    setOpen(false)
end)

-- Hide Settings toggle when a GameMenu panel is open so it can't cover
-- the panel's Close button on compact screens.
local gameMenusGui = pg:WaitForChild("GameMenus", 10)
if gameMenusGui then
    local dim = gameMenusGui:WaitForChild("Dim", 5)
    if dim then
        local function onMenuOverlay()
            local menuOpen = dim.Visible
            -- Hide the settings toggle when a menu panel is covering the screen
            -- the Settings button now sits in the small row under the side buttons (FigmaSkin), so it never covers a panel: keep it visible
            toggle.Parent.Visible = true
            -- If the settings panel was open, close it so it doesn't fight the menu
            if menuOpen and open then
                setOpen(false)
            end
        end
        dim:GetPropertyChangedSignal("Visible"):Connect(onMenuOverlay)
        onMenuOverlay()
    end
end
