--[[ ReplicatedFirst.LoadingScreen  (LocalScript)
Dimmed world behind the Hatch an Anime logo, a green progress bar with a runner carrying an egg to the egg at its end,
a tip and "Click to skip!" (a click anywhere). Art: assets/ui/loading, ids in Config.Images.
Real progress comes from ReplicatedFirst.StartupLoader. Keeps the JoinArrival handshake
(LoadingScreenFinishing → waits for JoinArrivalCameraSet → LoadingScreenDone). Cosmetic only.
Settings: Config (child ModuleScript). Old version: ServerStorage._ARCHIVE.OldLoadingScreen_*.

Runs before the game has loaded, so the order of yields below is load-bearing:
  WaitForChild(Config) -> WaitForChild(PlayerGui) -> RemoveDefaultLoadingScreen -> build GUI ->
  PreloadAsync(logo art) -> StartupLoader.Run -> close().
close() finishes the loading screen exactly once: by StartupLoader completion (after MinSeconds),
by a skip click, or by the MaxSeconds safety timer. Player attributes:
  reads   HoldLoading (Studio only, keeps the screen up), JoinArrivalCameraSet,
          JoinArrivalStarted / JoinArrivalFinished (who restores the CoreGui)
  writes  LoadingScreenFinishing, LoadingScreenDone
]]

-- ===== 1. Services and setup =====
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
-- Restore Roblox UI, its backpack included (the game uses Roblox's default backpack since 2026-11-08).
local function restoreCoreGui()
    for _, coreType in Enum.CoreGuiType:GetEnumItems() do
        if coreType ~= Enum.CoreGuiType.All then
            pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, true)
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
local TITLE_FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local OUTLINE = Color3.fromRGB(14, 8, 28) -- the menus' text outline
local GREEN = Color3.fromRGB(96, 236, 96)
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
local function loopTween(instance, duration, goals)
    local createdTween = TweenService:Create(
        instance,
        TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        goals
    )
    createdTween:Play()
    table.insert(tweens, createdTween)
    return createdTween
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
local root = create("CanvasGroup", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(8, 12, 22),
    BackgroundTransparency = 0.08, -- the world only shows through faintly once it has loaded
    BorderSizePixel = 0,
}, gui)

-- ===== 5. Layout: a fixed stage, scaled as one piece to fit any screen =====
local STAGE_SIZE = Vector2.new(900, 720)
local LOGO_ASPECT = 873 / 800
local stage = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(STAGE_SIZE.X, STAGE_SIZE.Y),
    BackgroundTransparency = 1,
}, root)
local stageScale = create("UIScale", {}, stage)
local function fitStage()
    local screenSize = gui.AbsoluteSize
    stageScale.Scale = math.max(math.min(screenSize.X / STAGE_SIZE.X, screenSize.Y / STAGE_SIZE.Y), 0.1)
end
table.insert(connections, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitStage))

local function addTextStroke(label, thickness)
    create("UIStroke", {
        Color = OUTLINE,
        Thickness = thickness,
        LineJoinMode = Enum.LineJoinMode.Round,
    }, label)
end
local function textRow(y, height, text, color, zIndex)
    local label = create("TextLabel", {
        Position = UDim2.fromOffset(0, y),
        Size = UDim2.fromOffset(STAGE_SIZE.X, height),
        BackgroundTransparency = 1,
        Text = text,
        FontFace = TITLE_FONT,
        TextSize = height,
        TextColor3 = color,
        ZIndex = zIndex,
    }, stage)
    addTextStroke(label, 3)
    return label
end

-- logo; the title in text stands in until the image has loaded (a fresh upload takes minutes)
local logoHeight = 420
local logoHolder = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 16),
    Size = UDim2.fromOffset(logoHeight * LOGO_ASPECT, logoHeight),
    BackgroundTransparency = 1,
    ZIndex = 2,
}, stage)
local logoScale = create("UIScale", { Scale = 0.8 }, logoHolder)
local logo = create("ImageLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Image = Config.Images.Logo,
    ZIndex = 2,
}, logoHolder)
local logoFallback = create("TextLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Text = "HATCH AN ANIME",
    FontFace = TITLE_FONT,
    TextSize = 96,
    TextWrapped = true,
    TextColor3 = Color3.fromRGB(255, 214, 48),
    Visible = false,
    ZIndex = 3,
}, logoHolder)
addTextStroke(logoFallback, 5)

-- progress bar: dark track, green fill with studs; the runner stands on the fill's front end
local BAR = { X = 70, Y = 552, Width = 760, Height = 40 }
local progressTrack = create("Frame", {
    Position = UDim2.fromOffset(BAR.X, BAR.Y),
    Size = UDim2.fromOffset(BAR.Width, BAR.Height),
    BackgroundColor3 = Color3.fromRGB(20, 26, 34),
    BorderSizePixel = 0,
    ZIndex = 4,
}, stage)
create("UICorner", { CornerRadius = UDim.new(0, 10) }, progressTrack)
create("UIStroke", { Color = OUTLINE, Thickness = 4 }, progressTrack)
local progressFill = create("Frame", {
    Size = UDim2.fromScale(0.03, 1),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
    ZIndex = 5,
}, progressTrack)
create("UICorner", { CornerRadius = UDim.new(0, 10) }, progressFill)
create("UIGradient", {
    Rotation = 90,
    Color = ColorSequence.new(GREEN, Color3.fromRGB(28, 150, 56)),
}, progressFill)
local fillStuds = create("ImageLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Image = "rbxassetid://132561191216691",
    ImageTransparency = 0.55,
    ScaleType = Enum.ScaleType.Tile,
    TileSize = UDim2.fromOffset(20, 20),
    ZIndex = 6,
}, progressFill)
create("UICorner", { CornerRadius = UDim.new(0, 10) }, fillStuds)
local goalEgg = create("ImageLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(1, 8, 0.5, -6),
    Size = UDim2.fromOffset(96, 96),
    BackgroundTransparency = 1,
    Image = Config.Images.GoalEgg,
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 7,
}, progressTrack)
local RUNNER_HEIGHT = 132
local RUNNER_FEET = 10 -- how far the feet sink into the bar
local runner = create("ImageLabel", {
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(1, 0, 0, RUNNER_FEET),
    Size = UDim2.fromOffset(RUNNER_HEIGHT * 381 / 512, RUNNER_HEIGHT),
    BackgroundTransparency = 1,
    Image = Config.Images.Runner,
    ZIndex = 8,
}, progressFill)

local tipLabel = textRow(616, 36, "", Color3.new(1, 1, 1), 4)
local skipLabel = textRow(662, 38, "Click to skip!", GREEN, 4)
if game:GetService("UserInputService").TouchEnabled then
    skipLabel.Text = "Tap to skip!"
end
-- a click anywhere skips
local skipButton = create("TextButton", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 30,
}, root)

gui.Parent = playerGui
fitStage()
-- Yields until the art is downloaded so the first frame is not blank.
pcall(function()
    ContentProvider:PreloadAsync({ logo, runner, goalEgg })
end)
logoFallback.Visible = not logo.IsLoaded
table.insert(
    connections,
    logo:GetPropertyChangedSignal("IsLoaded"):Connect(function()
        logoFallback.Visible = not logo.IsLoaded
    end)
)

-- ===== 6. Live motion =====
local tipIndex = 0
local function nextTip()
    tipIndex = tipIndex % #Config.Tips + 1
    tipLabel.TextTransparency = 1
    tipLabel.Text = Config.Tips[tipIndex]
    tween(tipLabel, 0.5, { TextTransparency = 0 })
end
tween(logoScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
if not reducedMotion then
    loopTween(logoHolder, 1.6, { Position = UDim2.new(0.5, 0, 0, 8) })
    loopTween(skipLabel, 0.7, { TextTransparency = 0.35 })
    table.insert(
        connections,
        RunService.RenderStepped:Connect(function()
            -- the runner bobs and leans in step
            local step = os.clock() * 11
            runner.Position = UDim2.new(1, 0, 0, RUNNER_FEET - math.abs(math.sin(step)) * 7)
            runner.Rotation = math.sin(step) * 3
        end)
    )
end

-- ===== 7. Sequence: real loading, close =====
-- `progress` only ever increases. `close` is assigned below; it is forward-declared so the loader
-- thread can call it.
local progress, closing, close = 0, false, nil
local function setProgress(value)
    progress = math.max(progress, math.clamp(value, 0, 1))
    tween(progressFill, 0.35, { Size = UDim2.fromScale(math.max(0.03, progress), 1) })
end
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
-- A loader error is only logged; the screen still closes.
task.spawn(function()
    setProgress(0.02)
    local loaderModule = ReplicatedFirst:WaitForChild("StartupLoader", 10)
    local ok, err = pcall(function()
        require(loaderModule).Run(player, gui, function(loadProgress)
            if closing then
                return
            end
            setProgress(loadProgress)
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

-- `finished` is true only for normal completion (a skip and the MaxSeconds timer pass false).
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
    setProgress(1)
    if not reducedMotion then
        tween(logoScale, 0.35, { Scale = 1.08 }, Enum.EasingStyle.Back)
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
