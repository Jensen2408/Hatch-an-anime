--[[ ReplicatedStorage.StolenEggBanner  (ModuleScript, client) - premium steal screen (2026-11-08)
While the local player carries a stolen egg home:
  * red heartbeat on every screen edge, pumping "lub-dub" (faster when you're far from home)
  * a dark glass alert at the top: pulsing red "!" , "EGG STOLEN" + the egg's name, "RETURN TO YOUR BASE",
    and a compass arrow with the distance home (turns green when close)
  * every other UI is hidden (clean screen) until the egg is secured, dropped or the steal ends; Roblox's backpack bar
    and player list hide too. Tutorial, hatch cinematic and loading screens are left alone.
Same API as before (EggStealClient and RiverEggCarryClient drive it):
  Start(), Show(basePosition, eggData?), Resolve("Secured" | "Dropped" | "Cancelled"), Hide()
  eggData: { name, rarity, price, eggType }
Cosmetic only; the server keeps all steal validation and rewards. The old version is in git history.
Every Show / Resolve / Hide bumps `token`, so a late callback never touches a newer state.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")

local Banner = {}
local player = Players.LocalPlayer

local Config = {
    AlertSound = "rbxassetid://9126047777", -- Synth Air Whoosh
    SuccessSound = "rbxassetid://112485797063762", -- UI Accomplishment Ding
    FailSound = "",
    Volume = 0.35,
    SoundGroupName = "SFX",
    MuteAttribute = "SFXMuted",
    ReducedMotionAttribute = "ReducedMotion",
    DismissAfter = { Secured = 2.2, Dropped = 2, Cancelled = 1.8 },
    -- ScreenGuis that stay visible during a steal (everything else is hidden)
    KeepVisible = { StolenEggBanner = true, FirstHatchTutorial = true, CinematicHatchUI = true, HatchLoading = true },
    HideCoreGui = { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.EmotesMenu },
}
Banner.Config = Config

local RED = Color3.fromRGB(255, 42, 52)
local DEEP_RED = Color3.fromRGB(150, 0, 12)
local GREEN = Color3.fromRGB(60, 235, 120)
local GREY = Color3.fromRGB(150, 150, 160)
local GLASS = Color3.fromRGB(14, 9, 12)
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local FONT_BODY = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local COPY = {
    Stolen = { "EGG STOLEN", "RETURN TO YOUR BASE", RED },
    Secured = { "SUCCESS", "EGG SECURED!", GREEN },
    Dropped = { "FAILED", "EGG DROPPED", GREY },
    Cancelled = { "ENDED", "STEAL ENDED", GREY },
}
local ALERT_W, ALERT_H = 560, 84

local function make(className, props, parent)
    local instance = Instance.new(className)
    for key, value in props do
        instance[key] = value
    end
    instance.Parent = parent
    return instance
end
local function tween(instance, duration, goal, style, direction)
    local t = TweenService:Create(
        instance,
        TweenInfo.new(duration, style or Enum.EasingStyle.Quart, direction or Enum.EasingDirection.Out),
        goal
    )
    t:Play()
    return t
end
local function isReducedMotion()
    return GuiService.ReducedMotionEnabled or player:GetAttribute(Config.ReducedMotionAttribute) == true
end

local gui, ui
local function build()
    gui = make("ScreenGui", {
        Name = "StolenEggBanner",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 1000,
        Enabled = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, player:WaitForChild("PlayerGui"))
    ui = {}
    -- heartbeat edges: four red bands that fade toward the middle of the screen
    local edges = make("Frame", { Name = "Heartbeat", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
    ui.edges = {}
    for _, side in { "Top", "Bottom", "Left", "Right" } do
        local vertical = side == "Top" or side == "Bottom"
        local band = make("Frame", {
            Name = side,
            BorderSizePixel = 0,
            BackgroundColor3 = RED,
            AnchorPoint = Vector2.new(side == "Right" and 1 or 0, side == "Bottom" and 1 or 0),
            Position = UDim2.fromScale(side == "Right" and 1 or 0, side == "Bottom" and 1 or 0),
            Size = vertical and UDim2.fromScale(1, 0.2) or UDim2.fromScale(0.16, 1),
        }, edges)
        make("UIGradient", {
            Rotation = ({ Top = 90, Bottom = 270, Left = 0, Right = 180 })[side],
            Color = ColorSequence.new(DEEP_RED, RED),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.45, 0.65),
                NumberSequenceKeypoint.new(1, 1),
            }),
        }, band)
        ui.edges[side] = band
    end
    -- the alert at the top (named Frame: the tutorial looks for StolenEggBanner.Frame to stay below it)
    local holder = make("Frame", {
        Name = "Frame",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, -ALERT_H - 40),
        Size = UDim2.fromOffset(ALERT_W, ALERT_H),
        BackgroundTransparency = 1,
    }, gui)
    ui.holder = holder
    ui.fit = make("UIScale", { Name = "Fit" }, holder)
    local plate = make("Frame", {
        Name = "Plate",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = GLASS,
        BackgroundTransparency = 0.12,
    }, holder)
    ui.pop = make("UIScale", { Name = "Pop" }, plate)
    make("UICorner", { CornerRadius = UDim.new(0, 18) }, plate)
    ui.stroke = make("UIStroke", { Color = RED, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, plate)
    make("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(Color3.fromRGB(70, 18, 24), Color3.fromRGB(255, 255, 255)),
    }, plate)
    -- red glow under the plate
    ui.glow = make("Frame", {
        Name = "Glow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 24, 1, 24),
        BackgroundColor3 = RED,
        BackgroundTransparency = 0.8,
        ZIndex = 0,
    }, holder)
    make("UICorner", { CornerRadius = UDim.new(0, 28) }, ui.glow)
    -- left: pulsing alarm "!"
    local alarm = make("Frame", {
        Name = "Alarm",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(46, ALERT_H / 2),
        Size = UDim2.fromOffset(54, 54),
        BackgroundColor3 = RED,
        ZIndex = 3,
    }, plate)
    make("UICorner", { CornerRadius = UDim.new(1, 0) }, alarm)
    make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 120, 120), Color3.fromRGB(190, 0, 20)) }, alarm)
    ui.alarmRing = make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2.5, Transparency = 0.2 }, alarm)
    ui.alarm = alarm
    ui.alarmScale = make("UIScale", {}, alarm)
    ui.mark = make("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        FontFace = FONT,
        Text = "!",
        TextScaled = true,
        TextColor3 = Color3.new(1, 1, 1),
        ZIndex = 4,
    }, alarm)
    make("UIPadding", { PaddingTop = UDim.new(0.14, 0), PaddingBottom = UDim.new(0.14, 0) }, ui.mark)
    -- middle: two lines
    ui.kicker = make("TextLabel", {
        Name = "Kicker",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(88, 12),
        Size = UDim2.new(1, -196, 0, 22),
        FontFace = FONT_BODY,
        Text = "EGG STOLEN",
        TextSize = 18,
        TextColor3 = RED,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
    }, plate)
    ui.title = make("TextLabel", {
        Name = "Title",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(88, 34),
        Size = UDim2.new(1, -196, 0, 40),
        FontFace = FONT,
        Text = "RETURN TO YOUR BASE",
        TextSize = 34,
        TextColor3 = Color3.new(1, 1, 1),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextScaled = true,
        ZIndex = 3,
    }, plate)
    make("UITextSizeConstraint", { MaxTextSize = 34 }, ui.title)
    make("UIStroke", { Color = Color3.fromRGB(60, 0, 8), Thickness = 2.5, LineJoinMode = Enum.LineJoinMode.Bevel }, ui.title)
    -- right: compass arrow + distance home
    local compass = make("Frame", {
        Name = "Compass",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(86, 62),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.92,
        ZIndex = 3,
    }, plate)
    make("UICorner", { CornerRadius = UDim.new(0, 12) }, compass)
    ui.compass = compass
    ui.arrow = make("TextLabel", {
        Name = "Arrow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.33),
        Size = UDim2.fromOffset(28, 28),
        BackgroundTransparency = 1,
        FontFace = FONT,
        Text = "▲",
        TextScaled = true,
        TextColor3 = Color3.new(1, 1, 1),
        ZIndex = 4,
    }, compass)
    ui.dist = make("TextLabel", {
        Name = "Distance",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -4),
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        FontFace = FONT,
        Text = "",
        TextSize = 20,
        TextColor3 = Color3.new(1, 1, 1),
        ZIndex = 4,
    }, compass)
end

local function playSound(id)
    if not id or id == "" or player:GetAttribute(Config.MuteAttribute) then
        return
    end
    local sound = Instance.new("Sound")
    sound.SoundId = id
    sound.Volume = Config.Volume
    sound.SoundGroup = SoundService:FindFirstChild(Config.SoundGroupName)
    sound.Parent = SoundService
    sound:Play()
    sound.Ended:Once(function()
        sound:Destroy()
    end)
    task.delay(6, function()
        if sound.Parent then
            sound:Destroy()
        end
    end)
end

local function fitToScreen()
    local size = gui.AbsoluteSize
    if size.X > 10 then
        ui.fit.Scale = math.clamp((size.X - 24) / ALERT_W, 0.55, 1.1)
    end
end

local token = 0
local currentState = nil
local eggInfo = nil
local basePos = nil
local distanceHome = nil

local function setState(state)
    local copy = COPY[state]
    local color = copy[3]
    local kicker = copy[1]
    if state == "Stolen" and eggInfo and (eggInfo.name or eggInfo.eggType) then
        local name = eggInfo.name or (tostring(eggInfo.eggType) .. " Egg")
        kicker = "EGG STOLEN  ·  " .. string.upper(name)
    end
    ui.kicker.Text = kicker
    ui.kicker.TextColor3 = color
    ui.title.Text = copy[2]
    ui.stroke.Color = color
    ui.glow.BackgroundColor3 = color
    ui.alarm.BackgroundColor3 = color
    ui.mark.Text = state == "Secured" and "✓" or "!"
    ui.compass.Visible = state == "Stolen"
    for _, band in ui.edges do
        band.BackgroundColor3 = color
    end
end

---------------------------------------------------------------- clean screen: hide every other UI while stealing
local hidden = {} -- [ScreenGui] = true (only the ones this module turned off)
local hiddenCore = {} -- [CoreGuiType] = was enabled
local hideConnection
local function hideGui(screenGui)
    if screenGui:IsA("ScreenGui") and not Config.KeepVisible[screenGui.Name] and screenGui.Enabled then
        hidden[screenGui] = true
        screenGui.Enabled = false
    end
end
local function cleanScreen()
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if not playerGui or hideConnection then
        return
    end
    for _, screenGui in playerGui:GetChildren() do
        hideGui(screenGui)
    end
    for _, coreType in Config.HideCoreGui do
        local ok, enabled = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, coreType)
        if ok and enabled then
            hiddenCore[coreType] = true
            pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, false)
        end
    end
    -- keep it clean: UI that opens (or re-enables itself) during the steal is hidden too
    local elapsed = 0
    hideConnection = RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < 0.2 then
            return
        end
        elapsed = 0
        for _, screenGui in playerGui:GetChildren() do
            hideGui(screenGui)
        end
    end)
end
local function restoreScreen()
    if hideConnection then
        hideConnection:Disconnect()
        hideConnection = nil
    end
    for screenGui in hidden do
        if screenGui.Parent then
            screenGui.Enabled = true
        end
    end
    table.clear(hidden)
    for coreType in hiddenCore do
        pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, true)
    end
    table.clear(hiddenCore)
end

---------------------------------------------------------------- heartbeat + tracking loop
local loopConnection
local function stopLoop()
    if loopConnection then
        loopConnection:Disconnect()
        loopConnection = nil
    end
end
-- lub-dub: two quick beats then a rest. Returns 0..1
local function beat(phase)
    local function pulse(center, width)
        local d = math.abs(phase - center) / width
        return d < 1 and (1 - d) ^ 2 or 0
    end
    return math.max(pulse(0.06, 0.09), pulse(0.3, 0.09) * 0.75)
end
local function startLoop(myToken)
    stopLoop()
    local clock = 0
    local trackTimer = 0
    loopConnection = RunService.RenderStepped:Connect(function(dt)
        if myToken ~= token then
            return
        end
        local calm = isReducedMotion()
        -- heart rate: 70 bpm near home, up to 120 bpm far away
        local far = distanceHome and math.clamp(distanceHome / 150, 0, 1) or 0.6
        local period = 60 / (70 + far * 50)
        if currentState ~= "Stolen" then
            period = 0.9
        end
        clock = (clock + dt / period) % 1
        local strength = calm and 0.35 or beat(clock)
        local base = currentState == "Stolen" and 0.55 or 0.75
        for side, band in ui.edges do
            local vertical = side == "Top" or side == "Bottom"
            band.BackgroundTransparency = math.clamp(base - strength * 0.45, 0, 1)
            local thick = (vertical and 0.16 or 0.12) + strength * 0.06
            band.Size = vertical and UDim2.fromScale(1, thick) or UDim2.fromScale(thick, 1)
        end
        ui.alarmScale.Scale = 1 + strength * 0.16
        ui.alarmRing.Transparency = 0.2 + (1 - strength) * 0.6
        ui.glow.BackgroundTransparency = 0.85 - strength * 0.35
        ui.stroke.Thickness = 3 + strength * 2
        -- compass + distance, 20 times a second
        trackTimer += dt
        if trackTimer >= 0.05 and currentState == "Stolen" then
            trackTimer = 0
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            local camera = workspace.CurrentCamera
            if root and camera and typeof(basePos) == "Vector3" then
                local toBase = basePos - root.Position
                local flat = Vector3.new(toBase.X, 0, toBase.Z)
                local look = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
                if flat.Magnitude > 0.1 and look.Magnitude > 0.01 then
                    ui.arrow.Rotation = -math.deg(math.atan2(look.Unit:Cross(flat.Unit).Y, look.Unit:Dot(flat.Unit)))
                end
                distanceHome = flat.Magnitude
                local meters = math.floor(distanceHome + 0.5)
                ui.dist.Text = meters .. "m"
                local near = meters < 25
                ui.dist.TextColor3 = near and GREEN or Color3.new(1, 1, 1)
                ui.arrow.TextColor3 = near and GREEN or Color3.new(1, 1, 1)
            end
        end
    end)
end


---------------------------------------------------------------- capture zone: white box rising from the ground
-- Drawn on the player's own PlotSpawn pad while they carry a stolen egg (only they see it). The server secures the
-- egg inside the same square (EggStealConfig.Rules.CaptureHalfSize / CaptureHeight).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local zoneModel, zoneConnection
local function captureRules()
    local ok, config = pcall(function()
        return require(ReplicatedStorage:WaitForChild("EggSteal", 5):WaitForChild("EggStealConfig", 5))
    end)
    local rules = ok and config and config.Rules or {}
    return rules.CaptureHalfSize or 6, rules.CaptureHeight or 14
end
local function myPad()
    local plots = workspace:FindFirstChild("Plots")
    for _, plot in plots and plots:GetChildren() or {} do
        if plot:GetAttribute("OwnerUserId") == player.UserId then
            return plot:FindFirstChild("PlotSpawn")
        end
    end
end
local function clearZone()
    if zoneConnection then
        zoneConnection:Disconnect()
        zoneConnection = nil
    end
    if zoneModel then
        zoneModel:Destroy()
        zoneModel = nil
    end
end
local function zonePart(props)
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Material = Enum.Material.Neon
    part.Color = Color3.new(1, 1, 1)
    for key, value in props do
        part[key] = value
    end
    part.Parent = zoneModel
    return part
end
-- a see-through wall that is bright at the ground and fades out upward
local function fadeWall(cf, width, height)
    local wall = zonePart({ Name = "Wall", Material = Enum.Material.SmoothPlastic, Transparency = 1, Size = Vector3.new(width, height, 0.05), CFrame = cf })
    for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
        local surface = Instance.new("SurfaceGui")
        surface.Face = face
        surface.LightInfluence = 0
        surface.Brightness = 2.5
        surface.CanvasSize = Vector2.new(100, 100)
        surface.Parent = wall
        local fill = Instance.new("Frame")
        fill.Size = UDim2.fromScale(1, 1)
        fill.BorderSizePixel = 0
        fill.BackgroundColor3 = Color3.new(1, 1, 1)
        fill.Parent = surface
        local gradient = Instance.new("UIGradient")
        gradient.Rotation = 90
        gradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.6, 0.85),
            NumberSequenceKeypoint.new(1, 0.35),
        })
        gradient.Parent = fill
    end
    return wall
end
local function showZone()
    clearZone()
    local pad = myPad()
    if not pad then
        return
    end
    local half, height = captureRules()
    local size = half * 2
    local wallHeight = math.min(height, 6)
    zoneModel = Instance.new("Model")
    zoneModel.Name = "CaptureZone"
    local ground = pad.CFrame * CFrame.new(0, pad.Size.Y / 2 + 0.06, 0)
    -- glowing floor + white border
    zonePart({ Name = "Floor", Size = Vector3.new(size, 0.1, size), CFrame = ground, Transparency = 0.82 })
    for i = 0, 3 do
        local side = ground * CFrame.Angles(0, math.rad(90 * i), 0)
        zonePart({ Name = "Edge", Size = Vector3.new(size + 0.5, 0.25, 0.5), CFrame = side * CFrame.new(0, 0.08, -half), Transparency = 0.05 })
        fadeWall(side * CFrame.new(0, wallHeight / 2, -half), size, wallHeight)
    end
    -- rings that rise up the walls and fade, like a scanner
    local rings = {}
    for r = 1, 2 do
        local ring = Instance.new("Model")
        ring.Name = "Ring"
        ring.Parent = zoneModel
        local bars = {}
        for i = 0, 3 do
            local bar = zonePart({ Name = "Bar", Size = Vector3.new(size, 0.18, 0.18) })
            bar.Parent = ring
            bars[i] = bar
        end
        rings[r] = { bars = bars, offset = (r - 1) * 0.5 }
    end
    -- sparkles floating up from the floor
    local emitterPart = zonePart({ Name = "Sparkles", Transparency = 1, Size = Vector3.new(size, 0.1, size), CFrame = ground })
    local sparkles = Instance.new("ParticleEmitter")
    sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    sparkles.Color = ColorSequence.new(Color3.new(1, 1, 1))
    sparkles.LightEmission = 1
    sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
    sparkles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
    sparkles.Lifetime = NumberRange.new(1, 1.8)
    sparkles.Speed = NumberRange.new(2, 4)
    sparkles.EmissionDirection = Enum.NormalId.Top
    sparkles.SpreadAngle = Vector2.new(8, 8)
    sparkles.Rate = 18
    sparkles.Parent = emitterPart
    local light = Instance.new("PointLight")
    light.Color = Color3.new(1, 1, 1)
    light.Range = size
    light.Brightness = 1.2
    light.Parent = emitterPart
    zoneModel.Parent = workspace
    local calm = isReducedMotion()
    zoneConnection = RunService.RenderStepped:Connect(function()
        local t = os.clock()
        for _, ring in rings do
            local progress = calm and 0.15 or ((t * 0.6 + ring.offset) % 1)
            local y = 0.1 + progress * wallHeight
            for i, bar in ring.bars do
                local side = ground * CFrame.Angles(0, math.rad(90 * i), 0)
                bar.CFrame = side * CFrame.new(0, y, -half)
                bar.Transparency = 0.1 + progress * 0.9
            end
        end
    end)
end

local function slideIn()
    fitToScreen()
    local top = math.max(GuiService.TopbarInset.Max.Y, 36) + 14
    gui.Enabled = true
    if isReducedMotion() then
        ui.holder.Position = UDim2.new(0.5, 0, 0, top)
        return
    end
    ui.holder.Position = UDim2.new(0.5, 0, 0, -ALERT_H - 40)
    tween(ui.holder, 0.45, { Position = UDim2.new(0.5, 0, 0, top) }, Enum.EasingStyle.Back)
end

function Banner.Show(basePosition, eggData)
    if type(eggData) == "table" then
        eggInfo = { name = eggData.name, rarity = eggData.rarity, price = tonumber(eggData.price), eggType = eggData.eggType }
    end
    if typeof(basePosition) == "Vector3" then
        basePos = basePosition
    end
    -- already showing this steal: just refresh the text / target
    if currentState == "Stolen" and gui.Enabled then
        setState("Stolen")
        return
    end
    token += 1
    currentState = "Stolen"
    distanceHome = nil
    ui.dist.Text = ""
    setState("Stolen")
    cleanScreen()
    showZone()
    slideIn()
    startLoop(token)
    playSound(Config.AlertSound)
end

function Banner.Resolve(state)
    if not COPY[state] or state == "Stolen" or not currentState then
        return
    end
    token += 1
    local myToken = token
    currentState = state
    setState(state)
    startLoop(myToken)
    if not isReducedMotion() then
        ui.pop.Scale = 1
        tween(ui.pop, 0.12, { Scale = 1.08 }).Completed:Once(function()
            tween(ui.pop, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
        end)
    end
    playSound(state == "Secured" and Config.SuccessSound or Config.FailSound)
    task.delay(Config.DismissAfter[state] or 1.8, function()
        if myToken == token then
            Banner.Hide()
        end
    end)
end

function Banner.Hide()
    token += 1
    local myToken = token
    currentState = nil
    eggInfo = nil
    restoreScreen()
    clearZone()
    if not gui or not gui.Enabled then
        stopLoop()
        return
    end
    if isReducedMotion() then
        stopLoop()
        gui.Enabled = false
        return
    end
    for _, band in ui.edges do
        tween(band, 0.35, { BackgroundTransparency = 1 })
    end
    tween(ui.holder, 0.3, { Position = UDim2.new(0.5, 0, 0, -ALERT_H - 40) }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Once(function()
        if myToken == token then
            stopLoop()
            gui.Enabled = false
        end
    end)
end

local started = false
-- Idempotent; builds the gui (yields on PlayerGui) and ends the steal screen when the character respawns mid-steal.
function Banner.Start()
    if started then
        return
    end
    started = true
    build()
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToScreen)
    player.CharacterRemoving:Connect(function()
        if currentState == "Stolen" then
            Banner.Hide()
        end
    end)
end

return Banner
