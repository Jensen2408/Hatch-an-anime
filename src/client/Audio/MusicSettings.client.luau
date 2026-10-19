--[[ StarterPlayerScripts.MusicSettings  — Settings button + panel
Music volume, sound-effects volume, reduced motion, night sky effects and floating labels.
Music = sounds under workspace.Music. Sound effects = everything else (routed into SoundService.SFX).
Values are kept on the player as attributes for this session (MusicVolume, SFXVolume, SFXMuted, ReducedMotion, ...).
Persistence: PlayerDataService restores saved values onto those attributes; this script first waits up to 8 s for
the DataLoaded attribute. Changes are sent back via ReplicatedStorage.SaveSettings:FireServer({ <key> = value, ... })
for the keys in savedKeys, debounced to one send per 1.5 s.
Other scripts read the attributes (ReducedMotion, NightFX, HideLabels) and the gear button's holder frame
(FigmaSkin re-parents it into its side-button row; layoutSettings only positions it while it is still in gui).
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UISound = require(game:GetService("ReplicatedStorage"):WaitForChild("UISound"))
local player = Players.LocalPlayer
do
    local waitStart = os.clock()
    while not player:GetAttribute("DataLoaded") and os.clock() - waitStart < 8 do
        task.wait(0.1)
    end
end -- saved settings arrive with the save
local playerGui = player:WaitForChild("PlayerGui")

-- ===== 1. Palette and UI helpers =====
local CREAM, CARD, INK, RED, GOLD, GREEN, MUTED =
    Color3.fromRGB(255, 243, 217),
    Color3.fromRGB(246, 226, 192),
    Color3.fromRGB(56, 34, 24),
    Color3.fromRGB(204, 68, 54),
    Color3.fromRGB(242, 190, 85),
    Color3.fromRGB(85, 163, 78),
    Color3.fromRGB(150, 120, 96)
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local function make(className, props, parent)
    local instance = Instance.new(className)
    for key, value in props do
        instance[key] = value
    end
    if parent then
        instance.Parent = parent
    end
    return instance
end
local function round(guiObject, radius)
    make("UICorner", { CornerRadius = UDim.new(0, radius) }, guiObject)
end
local function makeText(parent, content, textSize, color, props)
    local label = make(
        "TextLabel",
        { BackgroundTransparency = 1, FontFace = FONT, Text = content, TextSize = textSize, TextColor3 = color or INK },
        parent
    )
    for key, value in props or {} do
        label[key] = value
    end
    return label
end
-- chunky button: dark base + face
local function chunky(parent, width, height, color, labelText, props)
    local holder = make("Frame", { Size = UDim2.fromOffset(width, height + 4), BackgroundTransparency = 1 }, parent)
    for key, value in props or {} do
        holder[key] = value
    end
    local shadow = make("Frame", {
        Position = UDim2.fromOffset(0, 4),
        Size = UDim2.new(1, 0, 1, -4),
        BackgroundColor3 = INK,
        BorderSizePixel = 0,
    }, holder)
    round(shadow, 10)
    local face = make("TextButton", {
        Size = UDim2.new(1, 0, 1, -4),
        BackgroundColor3 = color,
        AutoButtonColor = false,
        Text = "",
        BorderSizePixel = 0,
    }, holder)
    round(face, 10)
    make("UIStroke", { Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, face)
    local textLabel = makeText(face, labelText, 16, Color3.new(1, 1, 1), { Size = UDim2.fromScale(1, 1) })
    local function nudgeFace(offsetY)
        TweenService:Create(face, TweenInfo.new(0.08), { Position = UDim2.fromOffset(0, offsetY) }):Play()
    end
    face.MouseEnter:Connect(function()
        nudgeFace(-2)
    end)
    face.MouseLeave:Connect(function()
        nudgeFace(0)
    end)
    face.MouseButton1Down:Connect(function()
        nudgeFace(4)
    end)
    face.MouseButton1Up:Connect(function()
        nudgeFace(0)
    end)
    return face, textLabel, holder
end

-- ===== 2. Gear button and panel shell =====
local gui = make("ScreenGui", { Name = "MusicSettingsUI", ResetOnSpawn = false, DisplayOrder = 45 }, playerGui)
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
local panelScale = make("UIScale", {}, panel)
local panelBase = make(
    "Frame",
    { Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 1, -6), BackgroundColor3 = INK, BorderSizePixel = 0 },
    panel
)
round(panelBase, 18)
local body = make("Frame", { Size = UDim2.new(1, 0, 1, -6), BackgroundColor3 = CREAM, BorderSizePixel = 0 }, panel)
round(body, 18)
make("UIStroke", { Color = INK, Thickness = 3 }, body)
local header = make("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = RED, BorderSizePixel = 0 }, body)
round(header, 18)
make(
    "Frame",
    { Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 18), BackgroundColor3 = RED, BorderSizePixel = 0 },
    header
)
make(
    "Frame",
    { Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = INK, BorderSizePixel = 0 },
    header
)
make(
    "UIStroke",
    { Color = Color3.new(0, 0, 0), Thickness = 2.5 },
    makeText(header, "SETTINGS", 26, Color3.new(1, 1, 1), { Size = UDim2.fromScale(1, 1) })
)
local closeButton = make("TextButton", {
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
round(closeButton, 16)
make("UIStroke", { Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, closeButton)
local rowList = make(
    "Frame",
    { Position = UDim2.fromOffset(14, 64), Size = UDim2.new(1, -28, 1, -76), BackgroundTransparency = 1 },
    body
)
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, rowList)

-- ===== 3. Row widgets (slider, switch) =====
local function makeRow(order, height)
    local rowFrame = make(
        "Frame",
        { LayoutOrder = order, Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = CARD, BorderSizePixel = 0 },
        rowList
    )
    round(rowFrame, 12)
    make("UIStroke", { Color = Color3.fromRGB(205, 170, 120), Thickness = 1.5 }, rowFrame)
    return rowFrame
end

-- slider row. Only one slider drags at a time: activeDrag = { s = setFromScreenX, input = InputObject }.
local activeDrag
local function makeSlider(order, title, initial, onChange)
    local rowFrame = makeRow(order, 64)
    makeText(rowFrame, title, 17, INK, {
        Position = UDim2.fromOffset(12, 6),
        Size = UDim2.new(1, -80, 0, 22),
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local valueLabel = makeText(rowFrame, "", 16, MUTED, {
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
    }, rowFrame)
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
    local hitArea = make(
        "TextButton",
        { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Text = "" },
        rowFrame
    )
    hitArea:SetAttribute("UISoundMuted", true)
    local sliderApi = {}
    function sliderApi.set(value, silent)
        value = math.clamp(value, 0, 1)
        fill.Size = UDim2.fromScale(value, 1)
        knob.Position = UDim2.fromScale(value, 0.5)
        valueLabel.Text = value == 0 and "OFF" or (math.floor(value * 100 + 0.5) .. "%")
        if not silent then
            onChange(value)
        end
    end
    local function setFromScreenX(screenX)
        sliderApi.set((screenX - track.AbsolutePosition.X) / track.AbsoluteSize.X)
    end
    hitArea.InputBegan:Connect(function(input)
        if
            input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            activeDrag = { s = setFromScreenX, input = input }
            setFromScreenX(input.Position.X)
        end
    end)
    sliderApi.set(initial)
    return sliderApi
end
UserInputService.InputChanged:Connect(function(input)
    if
        activeDrag
        and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch)
    then
        activeDrag.s(input.Position.X)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        activeDrag = nil
    end
end)

-- toggle row
local function makeSwitch(order, title, description, initial, onChange)
    local rowFrame = makeRow(order, 50)
    makeText(rowFrame, title, 16, INK, {
        Position = UDim2.fromOffset(12, 5),
        Size = UDim2.new(1, -90, 0, 22),
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    makeText(rowFrame, description, 12, MUTED, {
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
    }, rowFrame)
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
    local isOn = initial
    local function paint()
        TweenService
            :Create(pill, TweenInfo.new(0.15), { BackgroundColor3 = isOn and GREEN or Color3.fromRGB(190, 170, 145) })
            :Play()
        TweenService:Create(
            dot,
            TweenInfo.new(0.15, Enum.EasingStyle.Back),
            { Position = UDim2.fromScale(isOn and 0.72 or 0.28, 0.5) }
        ):Play()
    end
    pill.Activated:Connect(function()
        isOn = not isOn
        paint()
        onChange(isOn)
    end)
    paint()
    onChange(isOn)
end

-- ===== 4. Music / sound-effect routing =====
-- Music sounds keep their authored volume in originalVolumes and are scaled by musicVolume; every other
-- Sound without a SoundGroup is routed into SoundService.SFX so the SFX slider can scale it.
local musicVolume, originalVolumes = player:GetAttribute("MusicVolume") or 1, {}
local function isMusic(sound)
    local musicFolder = workspace:FindFirstChild("Music")
    return musicFolder and sound:IsDescendantOf(musicFolder)
end
---------------------------------------------------------------- sound effects (everything that isn't music)
local sfxGroup = SoundService:FindFirstChild("SFX")
if not (sfxGroup and sfxGroup:IsA("SoundGroup")) then
    sfxGroup = make("SoundGroup", { Name = "SFX", Volume = 1 }, SoundService)
end
local function registerSound(sound)
    if not sound:IsA("Sound") then
        return
    end
    if isMusic(sound) then
        if not originalVolumes[sound] then
            originalVolumes[sound] = sound.Volume
            sound.Volume = originalVolumes[sound] * musicVolume
        end
    elseif not sound.SoundGroup then
        sound.SoundGroup = sfxGroup
    end
end
task.spawn(function()
    for _, container in { workspace, playerGui, SoundService } do
        for index, descendant in container:GetDescendants() do
            if descendant:IsA("Sound") then
                pcall(registerSound, descendant)
            end
            if index % 2000 == 0 then
                task.wait()
            end
        end
        container.DescendantAdded:Connect(function(descendant)
            if descendant:IsA("Sound") then
                task.defer(pcall, registerSound, descendant)
            end
        end)
    end
end)

-- ===== 5. Settings rows =====
local _musicSlider = makeSlider(1, "Music", musicVolume, function(volume)
    musicVolume = volume
    player:SetAttribute("MusicVolume", volume)
    for sound, baseVolume in originalVolumes do
        if sound.Parent then
            sound.Volume = baseVolume * volume
        else
            originalVolumes[sound] = nil
        end
    end
end)
makeSlider(2, "Sound effects", player:GetAttribute("SFXVolume") or 1, function(volume)
    sfxGroup.Volume = volume
    player:SetAttribute("SFXVolume", volume)
    player:SetAttribute("SFXMuted", volume == 0)
end)
makeSwitch(
    3,
    "Animations",
    "Turn off for simpler, calmer effects",
    player:GetAttribute("ReducedMotion") ~= true,
    function(isOn)
        player:SetAttribute("ReducedMotion", not isOn)
    end
)
makeSwitch(
    4,
    "Night sky effects",
    "Aurora and floating stars at night",
    player:GetAttribute("NightFX") ~= false,
    function(isOn)
        player:SetAttribute("NightFX", isOn)
        local nightFx = workspace:FindFirstChild("NighttimeLocalFX")
        if nightFx then
            for _, descendant in nightFx:GetDescendants() do
                if descendant:IsA("Beam") or descendant:IsA("ParticleEmitter") then
                    descendant:SetAttribute("UserOff", not isOn)
                    if not isOn then
                        descendant.Enabled = false
                    end
                end
            end
        end
    end
)
makeSwitch(
    5,
    "Floating labels",
    "Names and stats above characters",
    player:GetAttribute("HideLabels") ~= true,
    function(isOn)
        player:SetAttribute("HideLabels", not isOn)
        for _, billboard in playerGui:GetChildren() do
            if billboard:IsA("BillboardGui") and billboard.Name == "CharacterInfoLabel" then
                billboard.Enabled = isOn
            end
        end
    end
)
-- ===== 6. Persistence =====
do -- apply saved values + save changes
    sfxGroup.Volume = player:GetAttribute("SFXVolume") or 1
    local savedKeys = { "MusicVolume", "SFXVolume", "SFXMuted", "ReducedMotion", "NightFX", "HideLabels" }
    local saveQueued = false
    local saveRemote = game:GetService("ReplicatedStorage"):WaitForChild("SaveSettings", 10)
    player.AttributeChanged:Connect(function(name)
        if not saveRemote or saveQueued or not table.find(savedKeys, name) then
            return
        end
        saveQueued = true
        task.delay(1.5, function()
            saveQueued = false
            local payload = {}
            for _, key in savedKeys do
                payload[key] = player:GetAttribute(key)
            end
            saveRemote:FireServer(payload)
        end)
    end)
end
playerGui.ChildAdded:Connect(function(child)
    if child.Name == "CharacterInfoLabel" and player:GetAttribute("HideLabels") then
        task.defer(function()
            child.Enabled = false
        end)
    end
end)

-- ===== 7. Open / close =====
local isOpen = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
local BASE_DISPLAY = gui.DisplayOrder -- 45

local function panelFit()
    local viewport = gui.AbsoluteSize
    return math.max(0.01, math.min(1, (viewport.X - 32) / 340, (viewport.Y - 32) / 408))
end
local function layoutSettings()
    local viewport = gui.AbsoluteSize
    if viewport.X <= 0 or viewport.Y <= 0 then
        return
    end
    local hudScale = math.min(1, viewport.X / 600, viewport.Y / 560)
    if toggle.Parent.Parent == gui then
        toggle.Parent.Position = UDim2.new(1, -10, 0, 20 + 104 * hudScale)
    end
    -- phones: smaller gear (GameHUD stacks the EGGS button right under it, clear of the jump button)
    local phoneScale = toggle.Parent:FindFirstChild("PhoneScale")
        or make("UIScale", { Name = "PhoneScale" }, toggle.Parent)
    phoneScale.Scale = toggle.Parent.Parent ~= gui and 1
        or (viewport.Y < 600 and math.clamp(viewport.Y / 720, 0.6, 1) or 1)
    panelScale.Scale = panelFit()
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutSettings)
layoutSettings()
local function setOpen(shouldOpen)
    if isOpen ~= shouldOpen then
        UISound.Play(shouldOpen and "Open" or "Close")
    end
    isOpen = shouldOpen
    -- When Settings panel is open, render above GameMenus' boosted DisplayOrder (60)
    gui.DisplayOrder = shouldOpen and math.max(BASE_DISPLAY, 65) or BASE_DISPLAY
    if shouldOpen then
        panel.Visible = true
        panelScale.Scale = panelFit() * 0.85
        TweenService:Create(panelScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = panelFit() }):Play()
    else
        local closeTween = TweenService:Create(panelScale, TweenInfo.new(0.12), { Scale = panelFit() * 0.85 })
        closeTween:Play()
        closeTween.Completed:Once(function()
            if not isOpen then
                panel.Visible = false
            end
        end)
    end
end
toggle.Activated:Connect(function()
    setOpen(not isOpen)
end)
closeButton.Activated:Connect(function()
    setOpen(false)
end)

-- Hide Settings toggle when a GameMenu panel is open so it can't cover
-- the panel's Close button on compact screens.
local gameMenusGui = playerGui:WaitForChild("GameMenus", 10)
if gameMenusGui then
    local dim = gameMenusGui:WaitForChild("Dim", 5)
    if dim then
        local function onMenuOverlay()
            local menuOpen = dim.Visible
            -- Hide the settings toggle when a menu panel is covering the screen
            -- the Settings button now sits in the small row under the side buttons (FigmaSkin), so it never covers a panel: keep it visible
            toggle.Parent.Visible = true
            -- If the settings panel was open, close it so it doesn't fight the menu
            if menuOpen and isOpen then
                setOpen(false)
            end
        end
        dim:GetPropertyChangedSignal("Visible"):Connect(onMenuOverlay)
        onMenuOverlay()
    end
end
