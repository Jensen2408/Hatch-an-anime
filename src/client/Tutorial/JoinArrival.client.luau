--[[ JoinArrival (LocalScript, StarterPlayerScripts)
	Arrival cinematic that plays once per join. Originally sky -> plot -> behind the character; the current
	path (buildPath, "Hero" arrival) starts close on YOUR character's face and orbits round to the normal
	camera behind you, then blends into the default camera (handoff).
	The server (PlotManager) already assigns the plot and spawns the character at plot.PlotSpawn;
	this script only waits for that, then animates the camera locally.
	While it plays: controls are sunk (ContextActionService "JoinArrivalLock"), ProximityPrompts and the
	CoreGui are off, other ScreenGuis are disabled and BillboardGuis hidden via MaxDistance; restore()
	puts all of it back on every exit path (end, skip, death, timeout, error).

	Handshake with the loading screen, ReplicatedFirst.LoadingScreen (gui "HatchLoading"; the older
	name LaunchLoadingScreen is still checked) via player attributes:
	  LoadingScreenFinishing  set by the loading screen when it is about to fade out
	  JoinArrivalCameraSet    set here once the sky shot is in place (the loading screen waits for it)
	  LoadingScreenDone       set by the loading screen after its fade
	  JoinArrivalStarted / JoinArrivalFinished  so the loading screen knows who restores the HUD
	Settings: ReplicatedStorage.JoinArrival.Config (attributes on the folder: Enabled, ForceReducedMotion,
	PreviewTime). The Sky* settings are not used by the current Hero path.
]]

-- ===== 1. Services, config and math helpers =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
-- Restore Roblox UI without enabling its hotbar; GameHUD owns inventory.
-- Unused here (restore() re-enables CoreGuiType.All); same helper as in LoadingScreen.
local function _restoreCoreGui()
    for _, coreType in Enum.CoreGuiType:GetEnumItems() do
        if coreType ~= Enum.CoreGuiType.All then
            pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, coreType ~= Enum.CoreGuiType.Backpack)
        end
    end
end

local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local arrivalFolder = ReplicatedStorage:WaitForChild("JoinArrival")
local Config = require(arrivalFolder:WaitForChild("Config"))
local UP = Vector3.yAxis

local function clamp01(alpha)
    return math.clamp(alpha, 0, 1)
end
local function smoothstep(alpha)
    alpha = clamp01(alpha)
    return alpha * alpha * (3 - 2 * alpha)
end
local function smootherstep(alpha)
    alpha = clamp01(alpha)
    return alpha * alpha * alpha * (alpha * (alpha * 6 - 15) + 10)
end
local function flatDirection(vector)
    vector = Vector3.new(vector.X, 0, vector.Z)
    return vector.Magnitude > 1e-3 and vector.Unit or Vector3.new(0, 0, -1)
end

-- ===== 2. UI: cover + skip button =====
local _WOOD = Color3.fromRGB(74, 44, 30)
local _CREAM_TOP = Color3.fromRGB(255, 248, 232)
local _CREAM_BOTTOM = Color3.fromRGB(243, 215, 166)
local SKY_COLOR = Color3.fromRGB(214, 236, 255)

local arrivalGui = Instance.new("ScreenGui")
arrivalGui.Name = "JoinArrivalUI"
arrivalGui.IgnoreGuiInset = true
arrivalGui.ResetOnSpawn = false
arrivalGui.DisplayOrder = 900
arrivalGui.Enabled = false
arrivalGui.Parent = playerGui

local coverFrame = Instance.new("Frame")
coverFrame.Name = "AtmosphereCover"
coverFrame.Size = UDim2.fromScale(1, 1)
coverFrame.BorderSizePixel = 0
coverFrame.BackgroundColor3 = SKY_COLOR
coverFrame.BackgroundTransparency = 1
coverFrame.Parent = arrivalGui

-- raised square-stud button: dark base underneath, cream face on top, square studs on the surface
local skipButton = Instance.new("TextButton")
skipButton.Name = "Skip"
skipButton.AnchorPoint = Vector2.new(1, 1)
skipButton.Position = UDim2.new(1, -24, 1, -24)
skipButton.Size = UDim2.fromOffset(150, 60)
skipButton.BackgroundColor3 = Color3.new(0, 0, 0)
skipButton.BorderSizePixel = 0
do
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = skipButton
end
skipButton.Text = ""
skipButton.AutoButtonColor = false
skipButton.Parent = arrivalGui
local skipScale = Instance.new("UIScale")
skipScale.Parent = skipButton
local skipFace = Instance.new("Frame")
skipFace.Name = "Face"
skipFace.Size = UDim2.new(1, 0, 1, -5)
skipFace.BackgroundColor3 = Color3.new(1, 1, 1)
skipFace.BorderSizePixel = 0
skipFace.Parent = skipButton
skipFace.BackgroundColor3 = Color3.new(1, 1, 1)
do
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = skipFace
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 90
    gradient.Color = ColorSequence.new(Color3.fromRGB(90, 170, 255), Color3.fromRGB(20, 70, 200))
    gradient.Parent = skipFace
end
local faceStroke = Instance.new("UIStroke")
faceStroke.Thickness = 3
faceStroke.Color = Color3.new(1, 1, 1)
faceStroke.LineJoinMode = Enum.LineJoinMode.Round
faceStroke.Parent = skipFace
local skipStrip = Instance.new("Frame")
skipStrip.Size = UDim2.new(1, 0, 0, 5)
skipStrip.BackgroundColor3 = Color3.fromRGB(255, 150, 30)
skipStrip.BorderSizePixel = 0
skipStrip.Visible = false
skipStrip.Parent = skipFace
local studTex = Instance.new("ImageLabel")
studTex.Name = "StudTex"
studTex.BackgroundTransparency = 1
studTex.Size = UDim2.fromScale(1, 1)
studTex.Image = "rbxassetid://132561191216691"
studTex.ImageTransparency = 0.45
studTex.ScaleType = Enum.ScaleType.Tile
studTex.TileSize = UDim2.fromOffset(18, 18)
studTex.Parent = skipFace
local skipLabel = Instance.new("TextLabel")
skipLabel.BackgroundTransparency = 1
skipLabel.Size = UDim2.fromScale(1, 1)
skipLabel.Font = Enum.Font.FredokaOne
skipLabel.Text = "SKIP ▶▶"
skipLabel.TextSize = 26
skipLabel.TextColor3 = Color3.new(1, 1, 1)
skipLabel.Parent = skipFace
do
    local labelStroke = Instance.new("UIStroke")
    labelStroke.Color = Color3.new(0, 0, 0)
    labelStroke.Thickness = 2.5
    labelStroke.Parent = skipLabel
end
local function rescale()
    local screenSize = arrivalGui.AbsoluteSize
    skipScale.Scale = math.clamp(math.min(screenSize.X, screenSize.Y) / 720, screenSize.Y < 500 and 0.6 or 0.8, 1.15) -- smaller skip button on phones
end
arrivalGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
rescale()
skipButton.MouseButton1Down:Connect(function()
    skipFace.Position = UDim2.fromOffset(0, 3)
end)
skipButton.MouseButton1Up:Connect(function()
    skipFace.Position = UDim2.fromOffset(0, 0)
end)
skipButton.MouseLeave:Connect(function()
    skipFace.Position = UDim2.fromOffset(0, 0)
end)

-- ===== 3. Sounds (optional) =====
local function makeSound(slot)
    local soundConfig = Config.Sounds and Config.Sounds[slot]
    if not soundConfig or not soundConfig.Id or soundConfig.Id == "" then
        return nil
    end
    local sound = Instance.new("Sound")
    sound.Name = "JoinArrival" .. slot
    sound.SoundId = soundConfig.Id
    sound.Volume = soundConfig.Volume or 0.5
    sound.Parent = arrivalGui
    return sound, soundConfig.Volume or 0.5
end

-- ===== 4. Helpers =====
-- The player's own plot (PlotId attribute + OwnerUserId), or nil while not assigned yet.
local function findPlot()
    local plotId = player:GetAttribute("PlotId")
    local plots = workspace:FindFirstChild("Plots")
    if not plotId or not plots then
        return nil
    end
    for _, plot in plots:GetChildren() do
        if plot:GetAttribute("PlotId") == plotId and plot:GetAttribute("OwnerUserId") == player.UserId then
            return plot
        end
    end
end

-- Polls `check` every 0.1 s until it returns a truthy value or `timeout` seconds pass.
local function waitFor(check, timeout)
    local startedAt = os.clock()
    while os.clock() - startedAt < timeout do
        local result = check()
        if result then
            return result
        end
        task.wait(0.1)
    end
end

-- Unused by the current Hero path (was used to frame the sky shot).
local function _mapBounds(plotsFolder)
    local minCorner, maxCorner = Vector3.one * math.huge, -Vector3.one * math.huge
    local function expand(cframe, size)
        local halfSize = size / 2
        minCorner = minCorner:Min(cframe.Position - halfSize)
        maxCorner = maxCorner:Max(cframe.Position + halfSize)
    end
    for _, plot in plotsFolder:GetChildren() do
        local anchor = plot:FindFirstChild("TempleAnchor")
        if anchor then
            expand(anchor.CFrame, Vector3.new(84, 50, 74))
        end -- plot footprint (works even if the plot is not streamed in)
    end
    local river = workspace:FindFirstChild("WaterfallRiver")
    if river and river:IsA("Model") then
        expand(river:GetBoundingBox())
    end
    return (minCorner + maxCorner) / 2, maxCorner - minCorner, maxCorner
end

-- blocking geometry between two points (characters ignored)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local function findBlockingHit(fromPosition, toPosition)
    local characters = {}
    for _, otherPlayer in Players:GetPlayers() do
        if otherPlayer.Character then
            table.insert(characters, otherPlayer.Character)
        end
    end
    rayParams.FilterDescendantsInstances = characters
    local hit = workspace:Raycast(fromPosition, toPosition - fromPosition, rayParams)
    return hit
end

-- cubic bezier (unused by the current Hero path)
local function _bezier(p0, p1, p2, p3, t)
    local u = 1 - t
    return p0 * u * u * u + p1 * 3 * u * u * t + p2 * 3 * u * t * t + p3 * t * t * t
end

-- ===== 5. The run =====
local activeRun -- current arrival state (nil when idle)

-- gameplay UI hidden while the arrival plays, faded back in at the handoff
local function isExemptGui(screenGui)
    return screenGui == arrivalGui
        or screenGui.Name == "LaunchLoadingScreen"
        or screenGui.Name == "HatchLoading"
        or screenGui.Name == "CinematicHatchUI"
end
local function hideGui(runState, screenGui)
    if
        screenGui:IsA("ScreenGui")
        and not isExemptGui(screenGui)
        and (screenGui.Enabled or screenGui.Name == "HUD")
        and not runState.guis[screenGui]
    then
        runState.guis[screenGui] = true
        screenGui.Enabled = false
    end
end

local FADE_PROPS = {
    GuiObject = { "BackgroundTransparency" },
    TextLabel = { "TextTransparency", "TextStrokeTransparency" },
    TextButton = { "TextTransparency", "TextStrokeTransparency" },
    TextBox = { "TextTransparency", "TextStrokeTransparency" },
    ImageLabel = { "ImageTransparency" },
    ImageButton = { "ImageTransparency" },
    UIStroke = { "Transparency" },
}
local function fadeInGuis(guis, duration)
    local saved = {}
    for screenGui in guis do
        if screenGui.Parent then
            if duration > 0 then
                for _, descendant in screenGui:GetDescendants() do
                    for className, props in FADE_PROPS do
                        if descendant:IsA(className) then
                            for _, prop in props do
                                local originalValue = descendant[prop]
                                if originalValue < 1 then
                                    table.insert(saved, { descendant, prop, originalValue })
                                    descendant[prop] = 1
                                    TweenService
                                        :Create(
                                            descendant,
                                            TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                                            { [prop] = originalValue }
                                        )
                                        :Play()
                                end
                            end
                        end
                    end
                end
            end
            screenGui.Enabled = true
        end
    end
    -- make sure every value lands exactly where it was
    task.delay(duration + 0.05, function()
        for _, entry in saved do
            if entry[1].Parent then
                entry[1][entry[2]] = entry[3]
            end
        end
    end)
end

-- floating labels (player role tags, owner banners, egg names, price tags) stay hidden until
-- the character has landed. MaxDistance is used instead of Enabled because other scripts
-- toggle Enabled themselves.
local function hideLabel(runState, billboard)
    if billboard:IsA("BillboardGui") and runState.labels[billboard] == nil then
        runState.labels[billboard] = billboard.MaxDistance
        billboard.MaxDistance = 0.001
    end
end
local function hideLabels(runState)
    for _, searchRoot in { workspace, playerGui } do
        for _, descendant in searchRoot:GetDescendants() do
            hideLabel(runState, descendant)
        end
        table.insert(
            runState.conns,
            searchRoot.DescendantAdded:Connect(function(descendant)
                if not runState.labelsShown then
                    hideLabel(runState, descendant)
                end
            end)
        )
    end
end
local function showLabels(runState)
    if runState.labelsShown then
        return
    end
    runState.labelsShown = true
    for billboard, maxDistance in runState.labels do
        if billboard.Parent then
            billboard.MaxDistance = maxDistance
        end
    end
    runState.labels = {}
end

local function setCharacterAlpha(character, transparency)
    if not character then
        return
    end
    for _, descendant in character:GetDescendants() do
        if descendant:IsA("BasePart") or descendant:IsA("Decal") then
            descendant.LocalTransparencyModifier = transparency
        end
    end
end

local function lockControls(locked)
    if locked then
        ContextActionService:BindActionAtPriority("JoinArrivalLock", function()
            return Enum.ContextActionResult.Sink
        end, false, 3500, table.unpack(Enum.PlayerActions:GetEnumItems()))
    else
        ContextActionService:UnbindAction("JoinArrivalLock")
    end
end

-- one place that puts everything back, used by the normal end, skip, death and failures
local function restore(runState, guiFade)
    if runState.restored then
        return
    end
    runState.restored = true
    for _, connection in runState.conns do
        connection:Disconnect()
    end
    showLabels(runState)
    RunService:UnbindFromRenderStep("JoinArrivalCamera")
    lockControls(false)
    ProximityPromptService.Enabled = runState.promptsWere ~= false
    local camera = workspace.CurrentCamera
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if camera.CameraType == Enum.CameraType.Scriptable then
        camera.CameraType = Enum.CameraType.Custom
        if humanoid then
            camera.CameraSubject = humanoid
        end
    end
    camera.FieldOfView = runState.fov
    setCharacterAlpha(player.Character, 0)
    if runState.ambience then
        local ambienceSound = runState.ambience
        TweenService:Create(ambienceSound, TweenInfo.new(0.6), { Volume = 0 }):Play()
        task.delay(0.7, function()
            ambienceSound:Destroy()
        end)
    end
    if runState.whoosh then
        runState.whoosh:Destroy()
    end
    pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, true)
    fadeInGuis(runState.guis, guiFade or 0)
    skipButton.Visible = false
    TweenService:Create(coverFrame, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
    task.delay(0.4, function()
        if activeRun == nil or activeRun == runState then
            arrivalGui.Enabled = false
        end
    end)
    player:SetAttribute("JoinArrivalFinished", true)
    if activeRun == runState then
        activeRun = nil
    end
end

-- builds the camera journey for this plot; returns nil if it cannot be framed
local function buildPath(plot, character)
    -- "Hero" arrival: close-up on YOUR character's face, then orbit round to the normal camera behind you.
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local plotSpawn = plot:FindFirstChild("PlotSpawn")
    if not rootPart or not plotSpawn then
        return nil
    end
    local head = character:FindFirstChild("Head")
    local headPos = head and head.Position or (rootPart.Position + Vector3.new(0, 2, 0))
    local focus = rootPart.Position + Vector3.new(0, 1.5, 0) -- where the default camera looks
    local forward = flatDirection(plotSpawn.CFrame.LookVector)
    local right = forward:Cross(UP)
    local pitch = math.rad(Config.EndPitch)
    local distance = Config.EndDistance
    local endPos = focus
        - forward * math.cos(pitch) * distance
        + UP * math.sin(pitch) * distance
        + right * Config.ShoulderOffset
    local hit = findBlockingHit(focus, endPos)
    if hit then
        endPos = focus + (hit.Position - focus).Unit * math.max(2, (hit.Position - focus).Magnitude - 0.6)
    end
    local endCF = CFrame.lookAt(endPos, focus)
    local faceDirection = flatDirection(rootPart.CFrame.LookVector)
    local startAngle = math.atan2(faceDirection.X, faceDirection.Z) -- camera starts in front of the face
    local endOffset = endPos - focus
    local endAngle = math.atan2(endOffset.X, endOffset.Z)
    local angleDelta = (endAngle - startAngle + math.pi) % (2 * math.pi) - math.pi
    if math.abs(angleDelta) < 0.6 then
        angleDelta = math.pi
    end -- always a proper swing round
    -- a0/da: orbit start angle and sweep (radians); d0/d1 and h0/h1: horizontal distance and height
    -- (studs) at the start and end of the orbit, relative to the look target.
    return {
        head = headPos,
        focus = focus,
        endCF = endCF,
        finish = endPos,
        a0 = startAngle,
        da = angleDelta,
        d0 = 5.5,
        d1 = Vector3.new(endOffset.X, 0, endOffset.Z).Magnitude,
        h0 = 0.25,
        h1 = endOffset.Y,
    }
end

-- Camera pose at `progress` (0..1) along the orbit from the face close-up to the landing shot.
local function poseAt(path, progress)
    if progress >= 1 then
        return path.endCF
    end
    local angle = path.a0 + path.da * progress
    local distance = path.d0 + (path.d1 - path.d0) * progress
    local height = path.h0 + (path.h1 - path.h0) * progress
    local lookTarget = path.head:Lerp(path.focus, progress)
    local position = lookTarget + Vector3.new(math.sin(angle), 0, math.cos(angle)) * distance + UP * height
    return CFrame.lookAt(position, lookTarget)
end

local function streamAround(position)
    if not workspace.StreamingEnabled then
        return
    end
    pcall(function()
        player:RequestStreamAroundAsync(position, Config.StreamTimeout)
    end)
end

-- Welcome card with your avatar and display name; pops in now and shrinks away just before the landing.
local function showWelcomeCard(travelTime)
    local card = Instance.new("Frame")
    card.Name = "WelcomeCard"
    card.AnchorPoint = Vector2.new(0.5, 1)
    card.Position = UDim2.new(0.5, 0, 1, -70)
    card.Size = UDim2.fromOffset(0, 104)
    card.AutomaticSize = Enum.AutomaticSize.X
    card.BackgroundColor3 = Color3.new(1, 1, 1)
    card.BorderSizePixel = 0
    card.ZIndex = 50
    do
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 14)
        corner.Parent = card
        local gradient = Instance.new("UIGradient")
        gradient.Rotation = 90
        gradient.Color = ColorSequence.new(Color3.fromRGB(255, 92, 168), Color3.fromRGB(150, 10, 84))
        gradient.Parent = card
        local cardStroke = Instance.new("UIStroke")
        cardStroke.Color = Color3.new(1, 1, 1)
        cardStroke.Thickness = 4
        cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        cardStroke.Parent = card
        local studTexture = Instance.new("ImageLabel")
        studTexture.Name = "Studs"
        studTexture.BackgroundTransparency = 1
        studTexture.Size = UDim2.fromScale(1, 1)
        studTexture.Image = "rbxassetid://132561191216691"
        studTexture.ImageTransparency = 0.4
        studTexture.ScaleType = Enum.ScaleType.Tile
        studTexture.TileSize = UDim2.fromOffset(18, 18)
        studTexture.ZIndex = 50
        studTexture.Parent = card
        local studCorner = Instance.new("UICorner")
        studCorner.CornerRadius = UDim.new(0, 14)
        studCorner.Parent = studTexture
    end
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 20)
    padding.PaddingRight = UDim.new(0, 20)
    padding.Parent = card
    -- content row (the stud texture must not be part of the list layout, or it pushes the avatar and name off the card)
    local contentRow = Instance.new("Frame")
    contentRow.Name = "Content"
    contentRow.BackgroundTransparency = 1
    contentRow.AutomaticSize = Enum.AutomaticSize.X
    contentRow.Size = UDim2.fromScale(0, 1)
    contentRow.ZIndex = 52
    contentRow.Parent = card
    local rowLayout = Instance.new("UIListLayout")
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    rowLayout.Padding = UDim.new(0, 16)
    rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rowLayout.Parent = contentRow
    local avatar = Instance.new("ImageLabel")
    avatar.Name = "Avatar"
    avatar.Size = UDim2.fromOffset(80, 80)
    avatar.BackgroundColor3 = Color3.fromRGB(59, 120, 255)
    avatar.ZIndex = 52
    avatar.LayoutOrder = 1
    avatar.Parent = contentRow
    do
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = avatar
        local avatarStroke = Instance.new("UIStroke")
        avatarStroke.Color = Color3.new(1, 1, 1)
        avatarStroke.Thickness = 3
        avatarStroke.Parent = avatar
        task.spawn(function()
            local thumbnailOk, thumbnailUrl = pcall(function()
                return Players:GetUserThumbnailAsync(
                    player.UserId,
                    Enum.ThumbnailType.HeadShot,
                    Enum.ThumbnailSize.Size150x150
                )
            end)
            if thumbnailOk then
                avatar.Image = thumbnailUrl
            end
        end)
    end
    local textColumn = Instance.new("Frame")
    textColumn.BackgroundTransparency = 1
    textColumn.Size = UDim2.fromOffset(0, 80)
    textColumn.AutomaticSize = Enum.AutomaticSize.X
    textColumn.LayoutOrder = 2
    textColumn.ZIndex = 52
    textColumn.Parent = contentRow
    local columnLayout = Instance.new("UIListLayout")
    columnLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    columnLayout.Padding = UDim.new(0, 0)
    columnLayout.Parent = textColumn
    local greetingLabel = Instance.new("TextLabel")
    greetingLabel.BackgroundTransparency = 1
    greetingLabel.Size = UDim2.fromOffset(0, 26)
    greetingLabel.AutomaticSize = Enum.AutomaticSize.X
    greetingLabel.TextXAlignment = Enum.TextXAlignment.Left
    greetingLabel.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
    greetingLabel.TextSize = 22
    greetingLabel.TextColor3 = Color3.fromRGB(255, 226, 240)
    greetingLabel.ZIndex = 52
    greetingLabel.Text = "WELCOME BACK,"
    do
        local greetingStroke = Instance.new("UIStroke")
        greetingStroke.Color = Color3.fromRGB(13, 10, 20)
        greetingStroke.Thickness = 2
        greetingStroke.Parent = greetingLabel
    end
    greetingLabel.Parent = textColumn
    local nameLabel = Instance.new("TextLabel")
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.fromOffset(0, 50)
    nameLabel.AutomaticSize = Enum.AutomaticSize.X
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
    nameLabel.TextSize = 44
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.ZIndex = 52
    nameLabel.Text = string.upper(player.DisplayName) .. "!"
    local nameStroke = Instance.new("UIStroke")
    nameStroke.Color = Color3.fromRGB(13, 10, 20)
    nameStroke.Thickness = 4
    nameStroke.Parent = nameLabel
    nameLabel.Parent = textColumn
    local screenSize = arrivalGui.AbsoluteSize
    local fullScale = math.clamp(math.min(screenSize.X, screenSize.Y) / 1100, 0.42, 0.72) -- smaller, scales with screen
    card.Position = UDim2.new(0.5, 0, 1, -40)
    local cardScale = Instance.new("UIScale")
    cardScale.Scale = 0.6 * fullScale
    cardScale.Parent = card
    card.Parent = arrivalGui
    TweenService:Create(cardScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = fullScale }):Play()
    task.delay(travelTime - 0.3, function()
        if card.Parent then
            TweenService:Create(cardScale, TweenInfo.new(0.2), { Scale = 0 }):Play()
            task.delay(0.25, function()
                card:Destroy()
            end)
        end
    end)
end

-- Plays one arrival. Any failure before the camera is taken falls back to restore().
-- isReplay (Studio replay): does not wait for the loading screen and starts behind an opaque cover.
local function begin(isReplay)
    if activeRun then
        return
    end
    local runState = {
        guis = {},
        labels = {},
        conns = {},
        fov = workspace.CurrentCamera.FieldOfView,
        promptsWere = ProximityPromptService.Enabled,
    }
    activeRun = runState
    player:SetAttribute("JoinArrivalStarted", true)
    player:SetAttribute("JoinArrivalFinished", nil)
    arrivalGui.Enabled = true
    skipButton.Visible = false
    lockControls(true)
    ProximityPromptService.Enabled = false
    hideLabels(runState)
    for _, screenGui in playerGui:GetChildren() do
        hideGui(runState, screenGui)
    end
    table.insert(
        runState.conns,
        playerGui.ChildAdded:Connect(function(screenGui)
            task.defer(function()
                if not runState.restored then
                    hideGui(runState, screenGui)
                end
            end)
        end)
    )
    pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)

    local ok, err = pcall(function()
        -- 1. loading screen nearly done (it waits for our sky shot before fading)
        -- (sky shot is prepared immediately; the loading screen fades over it once it is in place)
        -- 2. plot assigned by the server, character spawned at that plot
        local plot = waitFor(findPlot, Config.PlotWaitTimeout)
        if not plot then
            error("no assigned plot")
        end
        local character = waitFor(function()
            local candidate = player.Character
            local rootPart = candidate and candidate:FindFirstChild("HumanoidRootPart")
            local plotSpawn = plot:FindFirstChild("PlotSpawn")
            return rootPart and plotSpawn and (rootPart.Position - plotSpawn.Position).Magnitude < 14 and candidate
        end, 4)
        if not character then
            error("character not at plot")
        end
        -- 3. make sure the destination exists on this client (StreamingEnabled)
        streamAround(plot.TempleAnchor.Position)
        local path = buildPath(plot, character)
        if not path then
            error("plot not streamed in")
        end
        runState.path = path
        runState.char = character
    end)
    if not ok then
        warn("JoinArrival skipped, starting normal gameplay: " .. tostring(err))
        player:SetAttribute("JoinArrivalCameraSet", true)
        restore(runState, 0.35)
        return
    end

    local camera = workspace.CurrentCamera
    local humanoid = runState.char:FindFirstChildOfClass("Humanoid")
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = poseAt(runState.path, 0)
    camera.FieldOfView = Config.StartFov
    setCharacterAlpha(runState.char, 1)
    player:SetAttribute("JoinArrivalCameraSet", true)

    -- abort cleanly on death / reset / respawn
    if humanoid then
        table.insert(
            runState.conns,
            humanoid.Died:Connect(function()
                restore(runState, 0.2)
            end)
        )
    end
    table.insert(
        runState.conns,
        player.CharacterRemoving:Connect(function()
            restore(runState, 0.2)
        end)
    )

    -- if the loading screen is still up, give it a moment to fade over our sky shot
    if not isReplay then
        waitFor(function()
            return player:GetAttribute("LoadingScreenDone")
                or not (playerGui:FindFirstChild("LaunchLoadingScreen") or playerGui:FindFirstChild("HatchLoading"))
        end, Config.LoadingScreenWait)
    else
        coverFrame.BackgroundTransparency = 0
    end

    local reducedMotion = GuiService.ReducedMotionEnabled
        or Config.ForceReducedMotion
        or arrivalFolder:GetAttribute("ForceReducedMotion") == true
    local travelTime = Config.SkyTime + Config.ApproachTime + Config.RevealTime
    local timelineStart = os.clock()
    local handoffAt, handoffCF
    local ambience, ambienceVolume = makeSound("Ambience")
    if ambience then
        runState.ambience = ambience
        ambience.Looped = true
        ambience.Volume = 0
        ambience:Play()
        TweenService:Create(ambience, TweenInfo.new(0.8), { Volume = ambienceVolume }):Play()
    end
    local whoosh = makeSound("Whoosh")
    runState.whoosh = whoosh
    local hasWhooshed = false

    -- the atmosphere cover starts slightly hazy and clears during the sky beat
    if coverFrame.BackgroundTransparency > 0.3 then
        coverFrame.BackgroundTransparency = 0.3
    end
    TweenService:Create(
        coverFrame,
        TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        { BackgroundTransparency = 1 }
    ):Play()
    skipButton.Visible = true
    showWelcomeCard(travelTime)

    local function startHandoff()
        if handoffAt then
            return
        end
        handoffAt = os.clock()
        handoffCF = camera.CFrame
        skipButton.Visible = false
        setCharacterAlpha(runState.char, 0)
        -- hand the camera back already pointing where the default camera will look
        camera.CFrame = runState.path.endCF
        camera.Focus = CFrame.new(runState.path.focus)
        camera.CameraType = Enum.CameraType.Custom
        if humanoid then
            camera.CameraSubject = humanoid
        end
        lockControls(false)
        ProximityPromptService.Enabled = runState.promptsWere ~= false
        pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, true)
        fadeInGuis(runState.guis, Config.HandoffTime)
        runState.guis = {}
        local arrival = makeSound("Arrival")
        if arrival then
            arrival:Play()
            task.delay(4, function()
                arrival:Destroy()
            end)
        end
    end

    -- skip / reduced motion: short fade straight to the landing shot
    local function jumpToEnd()
        if handoffAt or runState.jumping then
            return
        end
        runState.jumping = true
        skipButton.Visible = false
        TweenService:Create(coverFrame, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
        task.delay(0.22, function()
            if runState.restored then
                return
            end
            timelineStart = os.clock() - travelTime -- timeline at the landing
            camera.CFrame = runState.path.endCF
            camera.FieldOfView = runState.fov
            startHandoff()
            handoffCF = runState.path.endCF
            TweenService:Create(coverFrame, TweenInfo.new(0.45, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 })
                :Play()
        end)
    end
    table.insert(runState.conns, skipButton.Activated:Connect(jumpToEnd))
    -- safety: if frames stop (window minimised, Studio in the background) never leave the game locked
    task.delay(travelTime + Config.HandoffTime + 6, function()
        if not runState.restored then
            warn("JoinArrival timed out, restoring gameplay")
            restore(runState, 0.3)
        end
    end)
    if reducedMotion then
        jumpToEnd()
    end

    RunService:BindToRenderStep("JoinArrivalCamera", Enum.RenderPriority.Camera.Value + 1, function()
        if runState.restored then
            return
        end
        local elapsed = os.clock() - timelineStart
        -- Studio scrubber: set ReplicatedStorage.JoinArrival "PreviewTime" (seconds) during a replay to freeze there
        local previewTime = RunService:IsStudio() and arrivalFolder:GetAttribute("PreviewTime")
        if typeof(previewTime) == "number" and not handoffAt then
            elapsed = math.clamp(previewTime, 0, travelTime - 0.01)
            timelineStart = os.clock() - elapsed
        end
        if not handoffAt then
            if runState.jumping then
                return
            end
            local progress = smootherstep(elapsed / travelTime) -- slow sky beat, faster middle, soft landing
            camera.CameraType = Enum.CameraType.Scriptable
            camera.CFrame = poseAt(runState.path, progress)
            camera.FieldOfView = Config.StartFov + (runState.fov - Config.StartFov) * smoothstep(progress)
            -- character fades in during the reveal beat
            -- (currently forced visible every frame; _revealStart is unused)
            local _revealStart = (Config.SkyTime + Config.ApproachTime) / travelTime
            setCharacterAlpha(runState.char, 0)
            if whoosh and not hasWhooshed and elapsed > Config.SkyTime * 0.8 then
                hasWhooshed = true
                whoosh:Play()
            end
            if elapsed >= travelTime then
                startHandoff()
            end
        else
            -- handoff: the default camera is running again; ease from our last frame into its output
            local blend = smoothstep((os.clock() - handoffAt) / Config.HandoffTime)
            camera.CFrame = handoffCF:Lerp(camera.CFrame, blend)
            if blend >= 1 then
                restore(runState, 0)
            end
        end
    end)
end

-- ===== 6. Entry =====
task.spawn(function()
    if arrivalFolder:GetAttribute("Enabled") == false then
        player:SetAttribute("JoinArrivalCameraSet", true)
        return
    end
    -- The loading screen owns startup. Do not start its cinematic on an arbitrary timer.
    while not player:GetAttribute("LoadingScreenFinishing") and not player:GetAttribute("LoadingScreenDone") do
        if
            not (playerGui:FindFirstChild("LaunchLoadingScreen") or playerGui:FindFirstChild("HatchLoading"))
            and not game:GetService("ReplicatedFirst"):FindFirstChild("LaunchLoadingScreen")
        then
            break
        end
        task.wait(0.1)
    end
    local ok, err = pcall(begin, false)
    if not ok then
        warn("JoinArrival failed: " .. tostring(err))
        player:SetAttribute("JoinArrivalCameraSet", true)
        if activeRun then
            restore(activeRun, 0.3)
        end
    end
end)

-- Studio preview: replay the arrival with a key press (or ui.ReplayArrival:Fire()) during a play test
if RunService:IsStudio() then
    local replay = Instance.new("BindableEvent")
    replay.Name = "ReplayArrival"
    replay.Parent = arrivalGui
    replay.Event:Connect(function()
        if not activeRun then
            task.spawn(begin, true)
        end
    end)
end
if RunService:IsStudio() and Config.StudioReplayKey then
    UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Config.StudioReplayKey and not activeRun then
            task.spawn(begin, true)
        end
    end)
end
