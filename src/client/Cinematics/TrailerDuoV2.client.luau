--[[ StarterPlayerScripts.TrailerDuoV2  (LocalScript)
Trailer v2 "Duo river fight": two avatars (ACTORS: Jen1sen + Jacobo6I9) drop out of a purple portal ring above the
river, land on opposite banks, look around, turn towards their temples, spot the pirate egg dropping into the river,
sprint to it and play tug-of-war until it bursts in a white flash; end card "HATCH AN ANIME / OUT NOW".
Recording only: everything is client-side (folder Workspace.TrailerDuoFX + local ScreenGuis), nothing is replicated
or saved. Sibling of TrailerCinematic (v1) and TrailerDuoV3; see TrailerCinematic's header for the shared conventions.

Who can run it: only Config.OwnerIds (ReplicatedStorage.TrailerConfig); everyone else returns right after the require.
Unlike v1 there is no Config.AllowInStudio bypass.

_G contracts (keep exactly)
  _G.TrailerDuoStartV2   defined here; called by the picker in TrailerDuoV3 and by the TrailerGo2 test hook
  _G.TrailerStartV1      read only (VERSIONS[1]); exported by TrailerCinematic
The picker in this file (_togglePicker) is never called or exported - TrailerDuoV3 owns _G.TrailerPicker.

Test hook: setting player attribute "TrailerGo2" to a truthy value starts the take.

How a take runs
  _G.TrailerDuoStartV2(): builds the rigs, egg and portal ring, counts down 3 s (task.wait, yields the caller),
  hides UI / billboards / players, then drives everything from one RenderStepped connection keyed on
  t = seconds since the countdown ended. There is no cancel: the take always runs to t > 18, then cleans up
  (restore callbacks in reverse order, camera type + FOV reset, running = false).

Timeline (t in seconds; all values are contracts)
  portal ring   opens 0 - 0.8, closes 2.4 - 3.0
  actors        hidden < 1.4, fall 1.4 - 2.4, landing squat 2.4 - 2.7, look around 2.7 - 5.0,
                turn to temple 5.0 - 6.3, turn back + hands up 6.3 - 7.0, run to egg 7.0 - 8.9, dive 8.9 - 9.2,
                tug-of-war 9.2 - 13.6, blown back 13.6+
  egg           hidden (60 studs up) < 6, drops 6 - 6.6, shakes 9.2 - 13.6, glows 11.5 - 13.6, removed > 13.6
  camera        shots 0-7 (see the if-chain), 9.2 - 13.6 cuts every 1.1 s between egg / Jen / Jac, final 99
  end card      white flash 13.4 - 13.8, title 14.1 - 14.6, tagline 14.5 - 15.0, cleanup at t > 18
]]
-- ===== 1. Services, config and owner gate =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Config = require(game.ReplicatedStorage:WaitForChild("TrailerConfig"))
local player = Players.LocalPlayer
if not Config.OwnerIds[player.UserId] then
    return
end

-- ===== 2. Trailer versions (picker entries) =====
-- Entries call the per-version _G start functions; v1 is optional (TrailerCinematic may be absent).
local VERSIONS = {
    {
        name = "v1 · Rift trailer (solo)",
        date = "12 Oct 2026",
        run = function()
            if _G.TrailerStartV1 then
                _G.TrailerStartV1()
            end
        end,
    },
    {
        name = "v2 · Duo river fight",
        date = "13 Oct 2026",
        run = function()
            _G.TrailerDuoStartV2()
        end,
    },
}

-- ===== 3. Scene constants =====
-- bank = where each actor lands (world space, river bank); EGG_POS = egg resting point in the river.
local ACTORS =
    { { id = 168774222, bank = Vector3.new(-215, 25.9, 10) }, { id = 353101613, bank = Vector3.new(-215, 25.9, 38) } }
local EGG_POS = Vector3.new(-215, 24.3, 25)
local PORTAL_POS = Vector3.new(-215, 54, 24)
local ANIM_IDS = { fall = "rbxassetid://507767968", idle = "rbxassetid://507766388", run = "rbxassetid://913376220" }

-- ===== 4. Math helpers =====
local angles = CFrame.Angles
local function lerp(from, to, alpha)
    return from + (to - from) * alpha
end
local clamp = math.clamp
-- 0..1 progress of t through [startT, endT], clamped.
local function segment(t, startT, endT)
    return clamp((t - startT) / (endT - startT), 0, 1)
end
-- Smoothstep.
local function ease(alpha)
    alpha = clamp(alpha, 0, 1)
    return alpha * alpha * (3 - 2 * alpha)
end

-- ===== 5. State and trailer picker =====
local playerGui = player:WaitForChild("PlayerGui")
local running = false
-- Dead code: never called or exported here (TrailerDuoV3 defines the live _G.TrailerPicker). Kept as-is.
local function _togglePicker()
    local oldPicker = playerGui:FindFirstChild("TrailerPicker")
    if oldPicker then
        oldPicker:Destroy()
        return
    end
    local pickerGui = Instance.new("ScreenGui")
    pickerGui.Name = "TrailerPicker"
    pickerGui.ResetOnSpawn = false
    pickerGui.DisplayOrder = 1001
    local frame = Instance.new("Frame", pickerGui)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.Size = UDim2.fromOffset(380, 70 + #VERSIONS * 62)
    frame.BackgroundColor3 = Color3.fromRGB(29, 20, 32)
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
    local titleLabel = Instance.new("TextLabel", frame)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, 0, 0, 46)
    titleLabel.Font = Enum.Font.FredokaOne
    titleLabel.TextSize = 24
    titleLabel.TextColor3 = Color3.fromRGB(255, 211, 107)
    titleLabel.Text = "Pick a trailer"
    for i, version in VERSIONS do
        local versionButton = Instance.new("TextButton", frame)
        versionButton.Size = UDim2.new(1, -24, 0, 52)
        versionButton.Position = UDim2.fromOffset(12, 46 + (i - 1) * 62)
        versionButton.BackgroundColor3 = Color3.fromRGB(70, 52, 80)
        versionButton.Font = Enum.Font.FredokaOne
        versionButton.TextSize = 19
        versionButton.TextColor3 = Color3.new(1, 1, 1)
        versionButton.Text = version.name .. "   ·   " .. version.date
        Instance.new("UICorner", versionButton).CornerRadius = UDim.new(0, 8)
        versionButton.Activated:Connect(function()
            pickerGui:Destroy()
            version.run()
        end)
    end
    pickerGui.Parent = playerGui
end

-- ===== 6. Actor rigs =====
-- Builds an anchored, non-colliding R15 clone of a user's avatar. AnimationConstraints are swapped for Motor6Ds so
-- applyPose can drive C0 directly. Returns nil when the avatar cannot be fetched.
-- Actor table: m = model, tr = animation tracks, mot / base = Motor6Ds and their rest C0, off = root height
-- above the ground, cur = current animation name (info / side / grab / head are added by the take).
local function buildActor(userId, parent)
    local model
    local _ok = pcall(function()
        model = Players:CreateHumanoidModelFromDescription(
            Players:GetHumanoidDescriptionFromUserId(userId),
            Enum.HumanoidRigType.R15
        )
    end)
    if not model then
        return nil
    end
    for _, desc in model:GetDescendants() do
        if desc:IsA("AnimationConstraint") and desc.Attachment0 and desc.Attachment1 then
            local motor = Instance.new("Motor6D")
            motor.Name = desc.Name
            motor.Part0 = desc.Attachment0.Parent
            motor.Part1 = desc.Attachment1.Parent
            motor.C0 = desc.Attachment0.CFrame
            motor.C1 = desc.Attachment1.CFrame
            motor.Parent = desc.Parent
            desc:Destroy()
        elseif desc:IsA("BallSocketConstraint") or desc:IsA("HingeConstraint") or desc:IsA("BaseScript") then
            desc:Destroy()
        elseif desc:IsA("BasePart") then
            desc.CanCollide = false
            desc.CanQuery = false
            desc.CanTouch = false
        end
    end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.PlatformStand = true
    model.HumanoidRootPart.Anchored = true
    model.Parent = parent
    local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
    local tracks = {}
    for animName, animId in ANIM_IDS do
        local animation = Instance.new("Animation")
        animation.AnimationId = animId
        tracks[animName] = animator:LoadAnimation(animation)
        tracks[animName].Priority = Enum.AnimationPriority.Action
    end
    local motors, baseC0 = {}, {}
    for _, joint in model:GetDescendants() do
        if joint:IsA("Motor6D") then
            motors[joint.Name] = joint
            baseC0[joint.Name] = joint.C0
        end
    end
    return {
        m = model,
        tr = tracks,
        mot = motors,
        base = baseC0,
        off = humanoid.HipHeight + model.HumanoidRootPart.Size.Y / 2,
        cur = nil,
    }
end
-- Cross-fades to animation `name` (nil = stop all); no-op when it is already the current one.
local function playAnim(actor, name)
    if actor.cur == name then
        return
    end
    for trackName, track in actor.tr do
        if trackName ~= name and track.IsPlaying then
            track:Stop(0.15)
        end
    end
    if name and actor.tr[name] then
        actor.tr[name]:Play(0.15)
    end
    actor.cur = name
end
-- Sets every Motor6D to rest C0 * poseOffsets[joint] (rest pose when the table / entry is nil).
local function applyPose(actor, poseOffsets)
    for jointName, restC0 in actor.base do
        local offset = poseOffsets and poseOffsets[jointName]
        actor.mot[jointName].C0 = offset and restC0 * offset or restC0
    end
end

-- ===== 7. Trailer take (_G.TrailerDuoStartV2) =====
function _G.TrailerDuoStartV2()
    if running then
        return
    end
    running = true
    local restore = {}
    local fxFolder = Instance.new("Folder", workspace)
    fxFolder.Name = "TrailerDuoFX"
    local statusGui = Instance.new("ScreenGui")
    statusGui.Name = "TrailerDuoStatus"
    statusGui.DisplayOrder = 1000
    statusGui.ResetOnSpawn = false
    local statusLabel = Instance.new("TextLabel", statusGui)
    statusLabel.AnchorPoint = Vector2.new(0.5, 0)
    statusLabel.Position = UDim2.new(0.5, 0, 0, 70)
    statusLabel.Size = UDim2.fromOffset(420, 40)
    statusLabel.BackgroundColor3 = Color3.fromRGB(29, 20, 32)
    statusLabel.TextColor3 = Color3.new(1, 1, 1)
    statusLabel.Font = Enum.Font.FredokaOne
    statusLabel.TextSize = 20
    statusLabel.Text = "Loading actors…"
    statusGui.Parent = playerGui
    -- Actor 1 (Jen) lands on the z = 10 bank (side 1), actor 2 (Jac) on the z = 38 bank (side -1).
    local actors = {}
    for i, info in ACTORS do
        local actor = buildActor(info.id, fxFolder)
        if actor then
            actor.info = info
            actor.side = i == 1 and 1 or -1
            actor.m.Parent = fxFolder
            actors[i] = actor
        end
    end
    -- Egg prop: menu preview clone scaled to 4 studs tall, pivot moved to its bottom centre.
    local egg = game.ReplicatedStorage.GameMenu.EggPreviews:FindFirstChild("MenuEgg_Pirate"):Clone()
    for _, part in egg:GetDescendants() do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = false
        end
    end
    local _, eggSize = egg:GetBoundingBox()
    egg:ScaleTo(egg:GetScale() * 4 / eggSize.Y)
    local eggBoxCF, eggBoxSize = egg:GetBoundingBox()
    egg.WorldPivot = CFrame.new(eggBoxCF.Position - Vector3.new(0, eggBoxSize.Y / 2, 0))
    egg.Parent = fxFolder
    local glow = Instance.new("Highlight", egg)
    glow.FillColor = Color3.fromRGB(255, 240, 180)
    glow.FillTransparency = 1
    glow.OutlineTransparency = 1
    -- Portal ring (cylinder) + light; sized / spun every frame.
    local ring = Instance.new("Part", fxFolder)
    ring.Shape = Enum.PartType.Cylinder
    ring.Material = Enum.Material.Neon
    ring.Color = Color3.fromRGB(170, 90, 255)
    ring.Anchored = true
    ring.CanCollide = false
    ring.Transparency = 1
    local portalLight = Instance.new("PointLight", ring)
    portalLight.Color = Color3.fromRGB(190, 120, 255)
    portalLight.Range = 40
    portalLight.Brightness = 0
    -- Countdown: yields 3 s so the recorder can be started.
    for i = 3, 1, -1 do
        statusLabel.Text = "Trailer v2 starts in " .. i .. " — start recording"
        task.wait(1)
    end
    statusGui:Destroy()
    -- Hide UI + players for recording (each change registers a restore callback).
    for _, screenGui in playerGui:GetChildren() do
        if screenGui:IsA("ScreenGui") and screenGui.Enabled then
            screenGui.Enabled = false
            table.insert(restore, function()
                screenGui.Enabled = true
            end)
        end
    end
    pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)
    table.insert(restore, function()
        pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, true)
    end)
    for _, desc in playerGui:GetDescendants() do
        if desc:IsA("BillboardGui") and desc.Enabled then
            desc.Enabled = false
            table.insert(restore, function()
                desc.Enabled = true
            end)
        end
    end
    -- WaterfallEggs (live river eggs) and every player's character are kept invisible via LocalTransparencyModifier.
    local waterfallEggs = workspace:FindFirstChild("WaterfallEggs")
    local hideFolders = { waterfallEggs }
    for _, desc in workspace:GetDescendants() do
        if desc:IsA("BillboardGui") and desc.Enabled then
            desc.Enabled = false
            table.insert(restore, function()
                desc.Enabled = true
            end)
        end
    end
    local hidden = {}
    for _, folder in hideFolders do
        if folder then
            for _, desc in folder:GetDescendants() do
                if desc:IsA("BasePart") or desc:IsA("Decal") then
                    table.insert(hidden, desc)
                end
            end
        end
    end
    for _, otherPlayer in Players:GetPlayers() do
        if otherPlayer.Character then
            for _, desc in otherPlayer.Character:GetDescendants() do
                if desc:IsA("BasePart") or desc:IsA("Decal") then
                    table.insert(hidden, desc)
                end
            end
        end
    end
    local camera = workspace.CurrentCamera
    local savedCameraType, savedFov = camera.CameraType, camera.FieldOfView
    camera.CameraType = Enum.CameraType.Scriptable
    -- End card: full-screen white flash frame with title + tagline (all start transparent).
    local cardGui = Instance.new("ScreenGui")
    cardGui.Name = "TrailerDuoCard"
    cardGui.IgnoreGuiInset = true
    cardGui.DisplayOrder = 1002
    local flashFrame = Instance.new("Frame", cardGui)
    flashFrame.Size = UDim2.fromScale(1, 1)
    flashFrame.BackgroundColor3 = Color3.new(1, 1, 1)
    flashFrame.BackgroundTransparency = 1
    local function makeCardText(text, posY, heightScale, color)
        local label = Instance.new("TextLabel", flashFrame)
        label.BackgroundTransparency = 1
        label.AnchorPoint = Vector2.new(0.5, 0.5)
        label.Position = UDim2.fromScale(0.5, posY)
        label.Size = UDim2.fromScale(0.9, heightScale)
        label.TextScaled = true
        label.Font = Enum.Font.FredokaOne
        label.Text = text
        label.TextColor3 = color
        label.TextTransparency = 1
        local stroke = Instance.new("UIStroke", label)
        stroke.Thickness = 4
        stroke.Color = Color3.fromRGB(40, 24, 18)
        stroke.Transparency = 1
        return label, stroke
    end
    local titleLabel, titleStroke = makeCardText("HATCH AN ANIME", 0.44, 0.12, Color3.fromRGB(255, 190, 40))
    local taglineLabel, taglineStroke = makeCardText("OUT NOW", 0.58, 0.09, Color3.fromRGB(235, 60, 50))
    cardGui.Parent = playerGui
    -- Ground height under a point (ignores the FX folder, hits water); 25.9 when nothing is hit.
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { fxFolder }
    rayParams.IgnoreWater = false
    local function groundY(pos)
        local hit = workspace:Raycast(Vector3.new(pos.X, 60, pos.Z), Vector3.new(0, -100, 0), rayParams)
        return hit and hit.Position.Y or 25.9
    end
    for _, actor in actors do
        actor.grab = Vector3.new(EGG_POS.X, 0, EGG_POS.Z - actor.side * 3.4)
        actor.grab = Vector3.new(actor.grab.X, groundY(actor.grab), actor.grab.Z)
    end
    -- Pre-existing duplicate declaration (unused); the next line is the live lastShot.
    local _lastShot = -1
    local lastShot = -1
    local camCF = CFrame.lookAt(PORTAL_POS + Vector3.new(30, -18, 0), PORTAL_POS)
    local startTime = os.clock()
    local lookAt = CFrame.lookAt
    local vec3 = Vector3.new
    -- Known issue (not fixed): UpperTorso / LeftUpperArm / ... are part names, not Motor6D names, so applyPose
    -- ignores them; only the hip / knee entries and the Waist / Neck set in tugPose take effect.
    local TUG_POSE = {
        UpperTorso = angles(0.35, 0, 0),
        LeftUpperArm = angles(1.45, 0, 0.3),
        RightUpperArm = angles(1.45, 0, -0.3),
        LeftLowerArm = angles(0.25, 0, 0),
        RightLowerArm = angles(0.25, 0, 0),
        LeftHip = angles(0.7, 0, 0),
        LeftKnee = angles(-0.9, 0, 0),
        RightHip = angles(-0.45, 0, 0),
        RightKnee = angles(-0.35, 0, 0),
    }
    local function tugPose(pull)
        local pose = {}
        for jointName, offset in TUG_POSE do
            pose[jointName] = offset
        end
        pose.Waist = angles(0.45 * pull, 0, 0)
        pose.Neck = angles(0.15 + 0.1 * pull, 0, 0)
        return pose
    end
    local renderConn
    -- Per-frame driver. Re-hides streamed-in WaterfallEggs and newly enabled ScreenGuis each frame.
    renderConn = RunService.RenderStepped:Connect(function()
        local t = os.clock() - startTime
        for _, hiddenPart in hidden do
            hiddenPart.LocalTransparencyModifier = 1
        end
        camera.CameraType = Enum.CameraType.Scriptable
        local liveWaterfallEggs = workspace:FindFirstChild("WaterfallEggs")
        if liveWaterfallEggs then
            for _, desc in liveWaterfallEggs:GetDescendants() do
                if desc:IsA("BasePart") or desc:IsA("Decal") then
                    desc.LocalTransparencyModifier = 1
                elseif desc:IsA("BillboardGui") then
                    desc.Enabled = false
                end
            end
        end
        for _, screenGui in playerGui:GetChildren() do
            if screenGui:IsA("ScreenGui") and screenGui ~= cardGui and screenGui.Enabled then
                screenGui.Enabled = false
                table.insert(restore, function()
                    screenGui.Enabled = true
                end)
            end
        end
        -- portal
        local portalOpen = ease(segment(t, 0, 0.8)) * (1 - ease(segment(t, 2.4, 3.0)))
        ring.Size = Vector3.new(0.6, 30 * portalOpen + 0.1, 30 * portalOpen + 0.1)
        ring.CFrame = CFrame.new(PORTAL_POS) * angles(0, 0, math.rad(90)) * angles(t * 2, 0, 0)
        ring.Transparency = portalOpen > 0.02 and 0.15 or 1
        portalLight.Brightness = 5 * portalOpen
        -- egg
        local eggHeight
        if t < 6 then
            eggHeight = 60
        elseif t < 6.6 then
            eggHeight = lerp(40, 0, segment(t, 6, 6.6) ^ 2)
        else
            eggHeight = 0
        end
        local shake = t > 9.2 and t < 13.6 and (0.04 + 0.14 * segment(t, 9.2, 13.4)) or 0
        local nudge = t > 9.2 and math.sin(t * 6) * 0.5 or 0
        egg:PivotTo(
            CFrame.new(EGG_POS + vec3(0, eggHeight, nudge))
                * angles(math.sin(t * 37) * shake, t < 6.6 and t * 3 or 0, math.cos(t * 31) * shake)
        )
        glow.FillTransparency = 1 - 0.85 * segment(t, 11.5, 13.6)
        glow.OutlineTransparency = glow.FillTransparency
        if t > 13.6 then
            egg:PivotTo(CFrame.new(0, -500, 0))
        end
        -- actors (timeline in the header)
        for i, actor in actors do
            local bank = actor.info.bank
            local groundHeight = groundY(bank)
            local faceRiver = vec3(0, 0, actor.side)
            local yawRiver = math.atan2(-faceRiver.X, -faceRiver.Z)
            local yawHome = yawRiver + math.pi
            local pos, yaw, anim, poseOffsets = vec3(bank.X, groundHeight, bank.Z), yawRiver, "idle", nil
            if t < 1.4 then
                pos = vec3(bank.X, PORTAL_POS.Y, bank.Z)
                actor.m.Parent = nil
            elseif t < 2.4 then
                actor.m.Parent = fxFolder
                local alpha = segment(t, 1.4, 2.4)
                pos = vec3(
                    lerp(PORTAL_POS.X, bank.X, alpha),
                    lerp(PORTAL_POS.Y, groundHeight, alpha * alpha),
                    lerp(PORTAL_POS.Z, bank.Z, alpha)
                )
                anim = "fall"
            elseif t < 2.7 then
                poseOffsets = {
                    Waist = angles(-0.5, 0, 0),
                    LeftHip = angles(1.2, 0, 0),
                    LeftKnee = angles(-1.7, 0, 0),
                    RightHip = angles(1, 0, 0),
                    RightKnee = angles(-1.6, 0, 0),
                }
                pos = pos - vec3(0, 1.1 * (1 - segment(t, 2.4, 2.7)), 0)
                anim = nil
            elseif t < 5.0 then
                local look = math.sin((t - 2.7) * 3.2 + i) * 0.8 * (1 - segment(t, 4.2, 4.6))
                poseOffsets = { Neck = angles(0, look, 0) }
            elseif t < 6.3 then
                yaw = lerp(yawRiver, yawHome, ease(segment(t, 5, 5.35)))
            elseif t < 7.0 then
                yaw = lerp(yawHome, yawRiver, ease(segment(t, 6.3, 6.6)))
                poseOffsets = { LeftShoulder = angles(2.3, 0, 0.2), RightShoulder = angles(2.3, 0, -0.2) }
            elseif t < 8.9 then
                local alpha = segment(t, 7, 8.9)
                pos = vec3(bank.X, 0, bank.Z):Lerp(actor.grab, alpha ^ 1.2)
                pos = vec3(pos.X, groundY(pos), pos.Z)
                anim = "run"
            elseif t < 9.2 then
                pos = actor.grab + vec3(0, 0.3, 0)
                poseOffsets =
                    { Waist = angles(-0.7, 0, 0), LeftShoulder = angles(2.7, 0, 0), RightShoulder = angles(2.7, 0, 0) }
                anim = nil
            elseif t < 13.6 then
                local pull = math.sin(t * 6 + i * math.pi)
                pos = actor.grab + vec3(0, 0, -actor.side * 0.5 * pull)
                poseOffsets = tugPose(pull)
                anim = nil
            else
                local alpha = segment(t, 13.6, 14.2)
                pos = actor.grab + vec3(0, 1.2 * math.sin(alpha * math.pi), -actor.side * 4 * alpha)
                poseOffsets = {
                    Waist = angles(0.6, 0, 0),
                    LeftShoulder = angles(0.6, 0, -1.7),
                    RightShoulder = angles(0.6, 0, 1.7),
                }
                anim = nil
            end
            playAnim(actor, anim)
            applyPose(actor, poseOffsets)
            actor.m.HumanoidRootPart.CFrame = CFrame.new(pos + vec3(0, actor.off, 0)) * angles(0, yaw, 0)
            actor.head = actor.m.Head.Position
        end
        -- camera: pick this frame's target shot (cut ids below)
        local jenHead, jacHead =
            actors[1] and actors[1].head or vec3(-215, 29, 10), actors[2] and actors[2].head or vec3(-215, 29, 38)
        local mid = (jenHead + jacHead) / 2
        local eggFocus = EGG_POS + vec3(0, 2, 0)
        local target, targetFov
        if t < 1.4 then
            target = lookAt(PORTAL_POS + vec3(26, -16, 6), PORTAL_POS)
            targetFov = 70
        elseif t < 2.7 then
            target = lookAt(vec3(-196, 34, 24), vec3(-215, 30, 24))
            targetFov = 60
        elseif t < 3.5 then
            target = lookAt(vec3(-207, 38, -6), mid - vec3(0, 1, 0))
            targetFov = 55
        elseif t < 4.25 then
            target = lookAt(jenHead + vec3(1.5, 0.4, 7), jenHead)
            targetFov = 40
        elseif t < 5.0 then
            target = lookAt(jacHead + vec3(1.5, 0.4, -7), jacHead)
            targetFov = 40
        elseif t < 6.0 then
            target = lookAt(vec3(-200, 40, 24), vec3(-215, 34, 24) + vec3(0, 0, 0))
            targetFov = 75
        elseif t < 6.8 then
            target = lookAt(eggFocus + vec3(9, 3, 0), eggFocus)
            targetFov = 50
        elseif t < 9.2 then
            target = lookAt(vec3(-202, 29, 24), mid)
            targetFov = 62
        elseif t < 13.6 then
            local cut = math.floor((t - 9.2) / 1.1) % 3
            if cut == 0 then
                target = lookAt(eggFocus + vec3(8, 1.5, 0), eggFocus)
                targetFov = 50
            elseif cut == 1 then
                target = lookAt(jenHead + vec3(4, 0.5, 3), jenHead)
                targetFov = 42
            else
                target = lookAt(jacHead + vec3(4, 0.5, -3), jacHead)
                targetFov = 42
            end
        else
            target = lookAt(eggFocus + vec3(6, 1, 0), eggFocus)
            targetFov = 45
        end
        local shotId = t < 1.4 and 0
            or t < 2.7 and 1
            or t < 3.5 and 2
            or t < 4.25 and 3
            or t < 5 and 4
            or t < 6 and 5
            or t < 6.8 and 6
            or t < 9.2 and 7
            or t < 13.6 and 8 + math.floor((t - 9.2) / 1.1)
            or 99
        -- Hard cut when the shot id changes, otherwise ease towards the shot's target.
        if shotId ~= lastShot then
            lastShot = shotId
            camCF = target
        else
            camCF = camCF:Lerp(target, 0.12)
        end
        local shakeStrength = (t > 2.4 and t < 2.7 and 0.4 or 0) + shake * 2
        camera.CFrame = camCF * CFrame.new(math.noise(t * 20) * shakeStrength, math.noise(t * 20, 3) * shakeStrength, 0)
        camera.FieldOfView = lerp(camera.FieldOfView, targetFov, 0.2)
        -- white card / end titles
        local flashAlpha = segment(t, 13.4, 13.8)
        flashFrame.BackgroundTransparency = 1 - flashAlpha
        local titleTransparency = 1 - segment(t, 14.1, 14.6)
        titleLabel.TextTransparency = titleTransparency
        titleStroke.Transparency = titleTransparency
        local taglineTransparency = 1 - segment(t, 14.5, 15)
        taglineLabel.TextTransparency = taglineTransparency
        taglineStroke.Transparency = taglineTransparency
        -- Cleanup (the only exit): runs once, then the connection is gone.
        if t > 18 then
            renderConn:Disconnect()
            fxFolder:Destroy()
            cardGui:Destroy()
            for _, hiddenPart in hidden do
                if hiddenPart.Parent then
                    hiddenPart.LocalTransparencyModifier = 0
                end
            end
            for i = #restore, 1, -1 do
                restore[i]()
            end
            camera.CameraType = savedCameraType
            camera.FieldOfView = savedFov
            running = false
        end
    end)
end

-- ===== 8. Test hook =====
player:GetAttributeChangedSignal("TrailerGo2"):Connect(function()
    if player:GetAttribute("TrailerGo2") then
        _G.TrailerDuoStartV2()
    end
end)
