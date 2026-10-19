--[[ ReplicatedFirst.LoadingScreen  (LocalScript) — Hatch An Anime × Velm Studios
1. Velm Studios intro (logo art, push-in, light sweep)
2. Cinematic loading: drifting art, glowing title, live percentage, tips, Skip
Real progress comes from ReplicatedFirst.StartupLoader. Keeps the JoinArrival handshake
(LoadingScreenFinishing → waits for JoinArrivalCameraSet → LoadingScreenDone). Cosmetic only.
Settings: Config (child ModuleScript). Old version: ServerStorage._ARCHIVE.OldLoadingScreen_*.

Runs before the game has loaded, so the order of yields below is load-bearing:
  WaitForChild(Config) -> WaitForChild(PlayerGui) -> RemoveDefaultLoadingScreen -> build GUI ->
  PreloadAsync(logo art) -> intro + StartupLoader.Run in parallel -> close().
close() finishes the loading screen exactly once: by StartupLoader completion (after MinSeconds),
by Skip, or by the MaxSeconds safety timer. Player attributes:
  reads   HoldLoading (Studio only, keeps the screen up), JoinArrivalCameraSet,
          JoinArrivalStarted / JoinArrivalFinished (who restores the CoreGui)
  writes  LoadingScreenFinishing, LoadingScreenDone
VelmLogo / VelmLeft / VelmRight attributes on this script hold the intro art.
]]

-- ===== 1. Services and setup =====
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
-- Restore Roblox UI without enabling its hotbar; GameHUD owns inventory.
local function restoreCoreGui()
    for _, coreType in Enum.CoreGuiType:GetEnumItems() do
        if coreType ~= Enum.CoreGuiType.All then
            pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, coreType ~= Enum.CoreGuiType.Backpack)
        end
    end
end

local Config = require(script:WaitForChild("Config"))
local _COLORS = Config.Colors
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("HatchLoading") then
    return
end
ReplicatedFirst:RemoveDefaultLoadingScreen()
local reducedMotion = player:GetAttribute(Config.ReducedMotionAttribute) == true
pcall(function()
    reducedMotion = reducedMotion or GuiService.ReducedMotionEnabled
end)
local _TITLE_FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local BOLD_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local startedAt = os.clock()
-- Everything tracked here is disconnected / cancelled when the screen closes.
local connections, tweens = {}, {}

-- ===== 2. Helpers =====
local function create(className, props, parent)
    local instance = Instance.new(className)
    for key, value in props do
        instance[key] = value
    end
    if parent then
        instance.Parent = parent
    end
    return instance
end
local function tween(instance, duration, goals, style, direction, delayTime)
    local createdTween = TweenService:Create(
        instance,
        TweenInfo.new(
            duration,
            style or Enum.EasingStyle.Quad,
            direction or Enum.EasingDirection.Out,
            0,
            false,
            delayTime or 0
        ),
        goals
    )
    createdTween:Play()
    table.insert(tweens, createdTween)
    return createdTween
end
local function _loopTween(instance, duration, goals, style)
    local createdTween = TweenService:Create(
        instance,
        TweenInfo.new(duration, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        goals
    )
    createdTween:Play()
    table.insert(tweens, createdTween)
    return createdTween
end
local function numberSequence(points)
    local keypoints = {}
    for _, point in points do
        table.insert(keypoints, NumberSequenceKeypoint.new(point[1], point[2]))
    end
    return NumberSequence.new(keypoints)
end

-- ===== 3. Hide the Roblox HUD and controls while loading =====
local didHideCoreGui = false
if Config.HideCoreGui then
    didHideCoreGui = pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
    end)
end
local controls
if Config.DisableControls then
    task.spawn(function()
        local playerScripts = player:WaitForChild("PlayerScripts", 10)
        local playerModule = playerScripts and playerScripts:WaitForChild("PlayerModule", 10)
        if playerModule then
            pcall(function()
                controls = require(playerModule):GetControls()
                controls:Disable()
            end)
        end
    end)
end

-- ===== 4. Root GUI =====
local gui = create("ScreenGui", {
    Name = "HatchLoading",
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    DisplayOrder = 100000,
    ScreenInsets = Enum.ScreenInsets.None,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local root = create(
    "CanvasGroup",
    { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 },
    gui
)

-- ===== 5. Scene: Velm chrome stage =====
local LOGO_IMAGE = script:GetAttribute("VelmLogo") or ""
local HALF_LEFT_IMAGE, HALF_RIGHT_IMAGE = script:GetAttribute("VelmLeft") or "", script:GetAttribute("VelmRight") or ""
local LOGO_ASPECT = 2000 / 754
-- A CanvasGroup holding the logo art: two half images when both are set (sharper on big screens),
-- otherwise the single logo image. Sized by coverScreen.
local function createStage(parent, zIndex)
    local stageGroup = create("CanvasGroup", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundTransparency = 1,
        ZIndex = zIndex,
    }, parent)
    if HALF_LEFT_IMAGE ~= "" and HALF_RIGHT_IMAGE ~= "" then
        create("ImageLabel", {
            Size = UDim2.fromScale(0.5, 1),
            BackgroundTransparency = 1,
            Image = HALF_LEFT_IMAGE,
            ScaleType = Enum.ScaleType.Stretch,
            ResampleMode = Enum.ResamplerMode.Default,
            ZIndex = zIndex,
        }, stageGroup)
        create("ImageLabel", {
            Position = UDim2.fromScale(0.5, 0),
            Size = UDim2.fromScale(0.5, 1),
            BackgroundTransparency = 1,
            Image = HALF_RIGHT_IMAGE,
            ScaleType = Enum.ScaleType.Stretch,
            ZIndex = zIndex,
        }, stageGroup)
    else
        create("ImageLabel", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Image = LOGO_IMAGE,
            ScaleType = Enum.ScaleType.Stretch,
            ZIndex = zIndex,
        }, stageGroup)
    end
    return stageGroup
end
-- "Cover" fit: scale the stage so it fills the screen at the art's aspect ratio, times `zoom`.
local function coverScreen(stageGroup, zoom, offsetX, offsetY)
    local screenSize = gui.AbsoluteSize
    if screenSize.X <= 0 then
        return
    end
    local width = math.max(screenSize.X, screenSize.Y * LOGO_ASPECT) * zoom
    stageGroup.Size = UDim2.fromOffset(width, width / LOGO_ASPECT)
    stageGroup.Position = UDim2.new(0.5, offsetX or 0, 0.5, offsetY or 0)
end
local scene = create(
    "Frame",
    { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 1 },
    root
)
-- the logo art is the stage: spotlight, chrome logo, reflective floor
local art = createStage(scene, 1)
local _artZoom = 1.0
-- moving spotlight beam across the wall
local beam = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.1, 0.3),
    Size = UDim2.fromScale(0.35, 1.6),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BackgroundTransparency = 0.88,
    BorderSizePixel = 0,
    Rotation = -28,
    ZIndex = 2,
}, scene)
create("UIGradient", { Transparency = numberSequence({ { 0, 1 }, { 0.5, 0 }, { 1, 1 } }) }, beam)
-- vignette + floor fade so the UI reads
local vignette = create(
    "Frame",
    { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 3 },
    scene
)
create("UIGradient", { Transparency = numberSequence({ { 0, 0.25 }, { 0.2, 1 }, { 0.8, 1 }, { 1, 0.25 } }) }, vignette)
local floorFade = create(
    "Frame",
    { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 3 },
    scene
)
create(
    "UIGradient",
    { Rotation = 90, Transparency = numberSequence({ { 0, 1 }, { 0.62, 1 }, { 1, 0.05 } }) },
    floorFade
)
-- silver dust drifting up
local petalLayer = create(
    "Frame",
    { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4, ClipsDescendants = true },
    scene
)
local rng = Random.new()
local function spawnPetal()
    local dotSize = rng:NextInteger(2, 5)
    local dot = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(dotSize, dotSize),
        Position = UDim2.new(rng:NextNumber(0, 1), 0, 1.02, 0),
        BackgroundColor3 = Color3.fromRGB(235, 240, 255),
        BackgroundTransparency = rng:NextNumber(0.2, 0.6),
        BorderSizePixel = 0,
        ZIndex = 4,
    }, petalLayer)
    create("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
    local lifetime = rng:NextNumber(5, 9)
    tween(dot, lifetime, {
        Position = UDim2.new(dot.Position.X.Scale + rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(0.1, 0.6), 0),
        BackgroundTransparency = 1,
    }, Enum.EasingStyle.Sine)
    task.delay(lifetime, function()
        dot:Destroy()
    end)
end
-- twinkle star (matches the star on the logo)
local star = create("ImageLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.68, 0.295),
    Size = UDim2.fromOffset(90, 90),
    BackgroundTransparency = 1,
    Image = "rbxasset://textures/particles/sparkles_main.dds",
    ImageTransparency = 0.3,
    ZIndex = 5,
}, scene)
-- Leftover from a removed rays effect; kept as-is (no visual effect).
local _rays = {}
_rays.Rotation = 0

-- game title under the logo, chrome style
local titleBox = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.73),
    Size = UDim2.fromScale(0.6, 0.09),
    BackgroundTransparency = 1,
    ZIndex = 10,
}, scene)
create("UISizeConstraint", { MaxSize = Vector2.new(720, 70) }, titleBox)
local titleScale = create("UIScale", { Scale = 1 }, titleBox)
local titleLabel = create("TextLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Text = "HATCH  AN  ANIME",
    FontFace = BOLD_FONT,
    TextScaled = true,
    TextColor3 = Color3.new(1, 1, 1),
    ZIndex = 12,
}, titleBox)
create("UIGradient", {
    Rotation = 90,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(190, 195, 205)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 125, 135)),
    }),
}, titleLabel)
local _anime = titleLabel
local shineLabel = titleLabel:Clone()
shineLabel.Name = "Shine"
for _, child in shineLabel:GetChildren() do
    child:Destroy()
end
shineLabel.ZIndex = 13
shineLabel.Parent = titleBox
local shineGradient = create("UIGradient", {
    Rotation = 10,
    Transparency = numberSequence({ { 0, 1 }, { 0.44, 1 }, { 0.5, 0 }, { 0.56, 1 }, { 1, 1 } }),
    Offset = Vector2.new(-1.2, 0),
}, shineLabel)
local titleUnderline = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 1, 8),
    Size = UDim2.new(0.5, 0, 0, 1),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
    ZIndex = 12,
}, titleBox)
create("UIGradient", { Transparency = numberSequence({ { 0, 1 }, { 0.5, 0.2 }, { 1, 1 } }) }, titleUnderline)

-- bottom: thin chrome progress
local bottomBar = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -36),
    Size = UDim2.new(0.5, 0, 0, 70),
    BackgroundTransparency = 1,
    ZIndex = 20,
}, scene)
create("UISizeConstraint", { MaxSize = Vector2.new(620, 70), MinSize = Vector2.new(280, 0) }, bottomBar)
local stageLabel = create("TextLabel", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(0.75, 0, 0, 18),
    BackgroundTransparency = 1,
    Text = "Preparing your temple…",
    FontFace = BODY_FONT,
    TextSize = 14,
    TextColor3 = Color3.fromRGB(200, 205, 215),
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 21,
}, bottomBar)
local percentLabel = create("TextLabel", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, 0, 0, 0),
    Size = UDim2.new(0.25, 0, 0, 18),
    BackgroundTransparency = 1,
    Text = "0%",
    FontFace = BOLD_FONT,
    TextSize = 16,
    TextColor3 = Color3.new(1, 1, 1),
    TextXAlignment = Enum.TextXAlignment.Right,
    ZIndex = 21,
}, bottomBar)
local progressTrack = create("Frame", {
    Position = UDim2.new(0, 0, 0, 26),
    Size = UDim2.new(1, 0, 0, 3),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BackgroundTransparency = 0.85,
    BorderSizePixel = 0,
    ZIndex = 21,
}, bottomBar)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, progressTrack)
local progressFill = create(
    "Frame",
    { Size = UDim2.fromScale(0.02, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 22 },
    progressTrack
)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, progressFill)
create("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(150, 155, 165), Color3.new(1, 1, 1)) }, progressFill)
local fillGlow = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(1, 0.5),
    Size = UDim2.fromOffset(16, 16),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BackgroundTransparency = 0.1,
    BorderSizePixel = 0,
    ZIndex = 23,
}, progressFill)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, fillGlow)
create("UIGradient", { Transparency = numberSequence({ { 0, 1 }, { 0.5, 0 }, { 1, 1 } }) }, fillGlow)
local _fillShine = create(
    "UIGradient",
    { Transparency = numberSequence({ { 0, 1 }, { 1, 1 } }) },
    create("Frame", { Size = UDim2.fromScale(0, 0), BackgroundTransparency = 1 }, progressFill)
)
local tipLabel = create("TextLabel", {
    Position = UDim2.new(0, 0, 0, 42),
    Size = UDim2.new(1, 0, 0, 18),
    BackgroundTransparency = 1,
    Text = "",
    FontFace = BODY_FONT,
    TextSize = 14,
    TextColor3 = Color3.fromRGB(165, 170, 182),
    ZIndex = 21,
}, bottomBar)

local skipButton = create("TextButton", {
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -24, 1, -24),
    Size = UDim2.fromOffset(96, 34),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.4,
    Text = "SKIP",
    FontFace = BOLD_FONT,
    TextSize = 13,
    TextColor3 = Color3.fromRGB(220, 225, 235),
    AutoButtonColor = true,
    ZIndex = 30,
}, scene)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, skipButton)
create(
    "UIStroke",
    { Color = Color3.new(1, 1, 1), Thickness = 1, Transparency = 0.7, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
    skipButton
)

-- ===== 6. Velm intro (on top): same art, so it flows straight into the stage =====
local intro = create(
    "CanvasGroup",
    { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 50 },
    root
)
local introLogo = createStage(intro, 51)
introLogo.GroupTransparency = 1
local logoZoom = Instance.new("NumberValue")
logoZoom.Value = 1.06
local lightSweep = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(-0.3, 0.4),
    Size = UDim2.fromScale(0.12, 0.5),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
    Rotation = 18,
    BackgroundTransparency = 1,
    ZIndex = 52,
}, intro)
create("UIGradient", { Transparency = numberSequence({ { 0, 1 }, { 0.5, 0.75 }, { 1, 1 } }) }, lightSweep)
gui.Parent = playerGui
-- Yields until the intro art is downloaded so the first frame is not blank.
pcall(function()
    ContentProvider:PreloadAsync({ introLogo, art })
end)
for _, stageGroup in { art, introLogo } do
    coverScreen(stageGroup, 1)
end

-- ===== 7. Live motion =====
local tipIndex = 0
local function nextTip()
    tipIndex = tipIndex % #Config.Tips + 1
    tipLabel.TextTransparency = 1
    tipLabel.Text = Config.Tips[tipIndex]
    tween(tipLabel, 0.5, { TextTransparency = 0 })
end
table.insert(
    connections,
    RunService.RenderStepped:Connect(function(_dt)
        local elapsed = os.clock() - startedAt
        if introLogo.Parent then
            coverScreen(introLogo, logoZoom.Value)
        end
        if reducedMotion then
            coverScreen(art, 1)
        end
        if not reducedMotion then
            coverScreen(art, 1.0 + (math.sin(elapsed * 0.25) + 1) * 0.008, math.sin(elapsed * 0.15) * 8, 0)
            beam.Position = UDim2.fromScale(0.1 + math.sin(elapsed * 0.35) * 0.18, 0.3)
            beam.BackgroundTransparency = 0.86 + math.sin(elapsed * 0.7) * 0.04
            local twinkle = (math.sin(elapsed * 2.2) + 1) / 2
            star.ImageTransparency = 0.15 + twinkle * 0.6
            star.Size = UDim2.fromOffset(60 + twinkle * 50, 60 + twinkle * 50)
            star.Rotation = elapsed * 20
        end
    end)
)

-- ===== 8. Sequence: intro, real loading, close =====
-- `progress` only ever increases. `close` is assigned below; it is forward-declared so the loader
-- thread can call it.
local progress, closing, close = 0, false, nil
local function setProgress(value, message)
    progress = math.max(progress, math.clamp(value, 0, 1))
    if message then
        stageLabel.Text = message
    end
    tween(progressFill, 0.35, { Size = UDim2.fromScale(math.max(0.03, progress), 1) })
    percentLabel.Text = math.floor(progress * 100 + 0.5) .. "%"
end
task.spawn(function()
    -- intro
    tween(introLogo, 0.9, { GroupTransparency = 0 }, Enum.EasingStyle.Sine)
    if not reducedMotion then
        tween(logoZoom, 2.9, { Value = 1.0 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    end
    task.wait(0.8)
    if not reducedMotion then
        lightSweep.BackgroundTransparency = 0
        tween(
            lightSweep,
            0.9,
            { Position = UDim2.fromScale(1.3, 0.47) },
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.InOut
        )
    end
    task.wait(1.3)
    tween(intro, 0.7, { GroupTransparency = 1 }, Enum.EasingStyle.Sine)
    -- title pops in as the intro clears
    titleLabel.TextTransparency = 1
    shineLabel.TextTransparency = 1
    tween(titleLabel, 0.8, { TextTransparency = 0 }, nil, nil, 0.2)
    tween(shineLabel, 0.8, { TextTransparency = 0 }, nil, nil, 0.2)
    task.wait(0.75)
    intro:Destroy()
    nextTip()
    task.spawn(function()
        while not closing do
            task.wait(Config.TipSeconds or 3.2)
            if closing then
                break
            end
            nextTip()
        end
    end)
    task.spawn(function()
        while not closing do
            shineGradient.Offset = Vector2.new(-1.2, 0)
            tween(
                shineGradient,
                1.1,
                { Offset = Vector2.new(1.2, 0) },
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.InOut
            )
            task.wait(3.2)
        end
    end)
    task.spawn(function()
        while not closing do
            if not reducedMotion then
                spawnPetal()
            end
            task.wait(0.09)
        end
    end)
end)
-- Real loading runs alongside the intro. A loader error is only logged; the screen still closes.
task.spawn(function()
    setProgress(0.02, "Preparing your temple…")
    local loaderModule = ReplicatedFirst:WaitForChild("StartupLoader", 10)
    local ok, err = pcall(function()
        require(loaderModule).Run(player, gui, function(loadProgress, message)
            if closing then
                return
            end
            setProgress(loadProgress, message and (message:sub(-1) == "!" and message or message .. "…") or nil)
        end)
    end)
    if not ok then
        warn("[LoadingScreen] " .. tostring(err))
    end
    local remainingWait = (Config.MinSeconds or 3.4) - (os.clock() - startedAt)
    if remainingWait > 0 then
        task.wait(remainingWait)
    end
    close(true)
end)

-- `finished` is true only for normal completion (Skip and the MaxSeconds timer pass false).
-- Handshake: set LoadingScreenFinishing, wait up to 6 s for JoinArrival's sky shot
-- (JoinArrivalCameraSet), fade out, then set LoadingScreenDone.
close = function(finished)
    if closing then
        return
    end
    while RunService:IsStudio() and player:GetAttribute("HoldLoading") and finished do
        task.wait(0.1)
    end
    closing = true
    player:SetAttribute("LoadingScreenFinishing", true)
    local joinArrivalFolder = game:GetService("ReplicatedStorage"):FindFirstChild("JoinArrival")
    if joinArrivalFolder and joinArrivalFolder:GetAttribute("Enabled") ~= false then
        local deadline = os.clock() + 6
        while not player:GetAttribute("JoinArrivalCameraSet") and os.clock() < deadline do
            RunService.RenderStepped:Wait()
        end
    end
    setProgress(1, "Ready!")
    if not reducedMotion then
        tween(titleScale, 0.35, { Scale = 1.12 }, Enum.EasingStyle.Back)
        local flash = create("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 60,
        }, root)
        tween(flash, 0.18, { BackgroundTransparency = 0.25 })
        task.wait(0.2)
    end
    tween(root, 0.45, { GroupTransparency = 1 }, Enum.EasingStyle.Sine)
    task.wait(0.47)
    for _, connection in connections do
        connection:Disconnect()
    end
    for _, activeTween in tweens do
        activeTween:Cancel()
    end
    if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
        GuiService.SelectedObject = nil
    end
    gui:Destroy()
    player:SetAttribute("LoadingScreenDone", true)
    -- While JoinArrival is still playing it restores the CoreGui itself at its handoff.
    if
        didHideCoreGui and (not player:GetAttribute("JoinArrivalStarted") or player:GetAttribute("JoinArrivalFinished"))
    then
        for _ = 1, 5 do
            if pcall(restoreCoreGui) then
                break
            end
            task.wait(0.2)
        end
    end
    if controls then
        pcall(function()
            controls:Enable()
        end)
    end
end
table.insert(
    connections,
    skipButton.Activated:Connect(function()
        task.spawn(close, false)
    end)
)
-- Safety net: never keep the player behind the loading screen longer than MaxSeconds.
task.delay(Config.MaxSeconds or 180, function()
    task.spawn(close, false)
end)
