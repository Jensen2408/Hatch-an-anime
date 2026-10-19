--[[ StarterPlayerScripts.TrailerDuoV3  (LocalScript)
Trailer v3 "Summon gates + egg drop": Jen1sen + Jacobo6I9 (ACTORS) step out of two local Summon Gates by the temple,
look around, peek at the temple, an egg falls from the sky into the river with a splash, both sprint to it and
tug-of-war until it bursts in a flash; end card "HATCH AN ANIME / OUT NOW".
Recording only: everything is client-side (folder Workspace.TrailerDuoFX + local ScreenGuis), nothing is replicated
or saved. Sibling of TrailerCinematic (v1) and TrailerDuoV2; see TrailerCinematic's header for the shared conventions.

Who can run it: only Config.OwnerIds (ReplicatedStorage.TrailerConfig); everyone else returns right after the
requires (TrailerConfig, Portal.PortalBuilder, Portal.PortalConfig - these WaitForChild calls run for every player).

_G contracts (keep exactly)
  _G.TrailerPicker = togglePicker   defined here; TrailerCinematic's start command calls it to show the picker
  _G.TrailerDuoStartV3              defined here; picker entry v3 + TrailerGo3 test hook
  _G.TrailerStartV1, _G.TrailerDuoStartV2   read only (picker entries, guarded)
  _G.PortalRipple                   read only, optional (guarded); nothing in src defines it at the moment

Test hook: setting player attribute "TrailerGo3" to a truthy value starts the take.
Attributes written (debug / one-shot flags): fxFolder "T" (elapsed time), "splash", "burst"; each actor model
"Anim"; each gate "SurgeLevel" (no script in src reads it today; the vortex is drawn by PortalClient via the tag).

How a take runs
  _G.TrailerDuoStartV3(): builds the gates (PortalBuilder.Build), rigs, egg and FX parts, counts down 3 s (task.wait,
  yields the caller), hides UI / billboards / players, then drives everything from one RenderStepped connection keyed
  on t = seconds since the countdown ended. There is no cancel: the take always runs to t > 18, then cleans up
  (restore callbacks in reverse order, camera type + FOV reset, running = false).

Timeline (t in seconds; all values are contracts)
  gates         surge up 0 - 0.8, down 2.6 - 3.6
  actors        behind the gate < 0.8, walk out 0.8 - 2.6 (fade through the gate surface), look around 2.6 - 3.6,
                turn to temple 3.6 - 4.3, peek 4.3 - 5.0, turn back 5.0 - 5.9, shocked 5.9 - 6.5,
                sprint to egg 6.5 - 9.0, dive 9.0 - 9.4, tug-of-war 9.4 - 13.4, blown back 13.4+
  egg           hidden < 5.3, falls 5.3 - 6.3 with spark trail, splash at 6.3, bobs 6.3 - 13.4,
                shakes + glows 9.4 - 13.4, burst + flash ball at 13.4 (egg moved away)
  camera        shots 0-7 (see the if-chain), 9.0 - 13.4 cuts every 1.1 s between egg / Jen / Jac, final 99
  end card      white flash 13.5 - 13.9, title 14.2 - 14.7, tagline 14.6 - 15.1, cleanup at t > 18
]]
-- ===== 1. Services, dependencies and owner gate =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Config = require(game.ReplicatedStorage:WaitForChild("TrailerConfig"))
local PortalBuilder = require(game.ReplicatedStorage:WaitForChild("Portal"):WaitForChild("PortalBuilder"))
local PortalConfig = require(game.ReplicatedStorage.Portal.PortalConfig)
local player = Players.LocalPlayer
if not Config.OwnerIds[player.UserId] then
    return
end
local playerGui = player:WaitForChild("PlayerGui")

-- ===== 2. Trailer picker (_G.TrailerPicker) =====
-- Entries call the per-version _G start functions; v1 / v2 are optional (guarded).
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
            if _G.TrailerDuoStartV2 then
                _G.TrailerDuoStartV2()
            end
        end,
    },
    {
        name = "v3 · Summon gates + egg drop",
        date = "13 Oct 2026",
        run = function()
            _G.TrailerDuoStartV3()
        end,
    },
}
-- Toggles the picker: destroys an open one, otherwise builds it. The last (newest) entry is highlighted red.
local function togglePicker()
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
    frame.Size = UDim2.fromOffset(420, 70 + #VERSIONS * 62)
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
        versionButton.BackgroundColor3 = i == #VERSIONS and Color3.fromRGB(200, 60, 60) or Color3.fromRGB(70, 52, 80)
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
_G.TrailerPicker = togglePicker

-- ===== 3. Scene constants =====
local ACTORS = { { id = 168774222, gateX = -232 }, { id = 353101613, gateX = -200 } }
local GATE_Z, GROUND = -48, 25.9
local EGG_POS = Vector3.new(-216, 24.3, 24)
local TEMPLE_LOOK = Vector3.new(-206, 42, -82)
local ANIM_IDS = { walk = "rbxassetid://913402848", run = "rbxassetid://913376220", idle = "rbxassetid://507766388" }

-- ===== 4. Math helpers =====
local angles = CFrame.Angles
local vec3 = Vector3.new
local lookAt = CFrame.lookAt
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
-- Y rotation that makes a rig's LookVector point along `direction`.
local function yawFacing(direction)
    return math.atan2(-direction.X, -direction.Z)
end

-- ===== 5. Actor rigs and poses =====
-- Builds an anchored, non-colliding R15 clone of a user's avatar. AnimationConstraints are swapped for Motor6Ds so
-- applyPose can drive C0 directly. Returns nil when the avatar cannot be fetched.
-- Actor table: m = model, tr = animation tracks, mot / base = Motor6Ds and their rest C0, parts = BaseParts +
-- Decals (gate fade), off = root height above the ground, cur = current animation name.
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
    local motors, baseC0, parts = {}, {}, {}
    for _, child in model:GetDescendants() do
        if child:IsA("Motor6D") then
            motors[child.Name] = child
            baseC0[child.Name] = child.C0
        elseif child:IsA("BasePart") or child:IsA("Decal") then
            table.insert(parts, child)
        end
    end
    return {
        m = model,
        tr = tracks,
        mot = motors,
        base = baseC0,
        parts = parts,
        off = humanoid.HipHeight + model.HumanoidRootPart.Size.Y / 2,
        cur = nil,
    }
end
-- Cross-fades to animation `name` (nil = stop all) and sets its speed every call.
local function playAnim(actor, name, speed)
    if actor.cur ~= name then
        for trackName, track in actor.tr do
            if trackName ~= name and track.IsPlaying then
                track:Stop(0.12)
            end
        end
        if name and actor.tr[name] then
            actor.tr[name]:Play(0.12)
        end
        actor.cur = name
    end
    if name and actor.tr[name] then
        actor.tr[name]:AdjustSpeed(speed or 1)
    end
end
-- Sets every Motor6D to rest C0 * poseOffsets[joint] (rest pose when the table / entry is nil).
local function applyPose(actor, poseOffsets)
    for jointName, restC0 in actor.base do
        local offset = poseOffsets and poseOffsets[jointName]
        actor.mot[jointName].C0 = offset and restC0 * offset or restC0
    end
end
-- Tug-of-war pose; pull (-1..1) leans the waist / neck back and forth.
local function tugPose(pull)
    return {
        Waist = angles(0.35 * pull, 0, 0),
        Neck = angles(0.15 + 0.12 * pull, 0, 0),
        LeftShoulder = angles(1.45, 0, 0.3),
        RightShoulder = angles(1.45, 0, -0.3),
        LeftElbow = angles(0.25, 0, 0),
        RightElbow = angles(0.25, 0, 0),
        LeftHip = angles(0.65, 0, 0),
        LeftKnee = angles(-0.9, 0, 0),
        RightHip = angles(-0.45, 0, 0),
        RightKnee = angles(-0.3, 0, 0),
    }
end
local SHOCK_POSE = {
    Neck = angles(0.2, 0, 0),
    LeftShoulder = angles(2.3, 0, 0.25),
    RightShoulder = angles(2.3, 0, -0.25),
    LeftElbow = angles(0.5, 0, 0),
    RightElbow = angles(0.5, 0, 0),
    Waist = angles(0.12, 0, 0),
}
local DIVE_POSE = {
    Waist = angles(-0.7, 0, 0),
    LeftShoulder = angles(2.7, 0, 0),
    RightShoulder = angles(2.7, 0, 0),
    LeftHip = angles(-0.5, 0, 0),
    RightHip = angles(-0.9, 0, 0),
}
local BLOWN_POSE = {
    Waist = angles(0.6, 0, 0),
    Neck = angles(0.5, 0, 0),
    LeftShoulder = angles(0.6, 0, -1.7),
    RightShoulder = angles(0.6, 0, 1.7),
    LeftHip = angles(0.7, 0, 0),
    RightHip = angles(0.7, 0, 0),
    LeftKnee = angles(-0.9, 0, 0),
    RightKnee = angles(-0.9, 0, 0),
}

-- ===== 6. Trailer take (_G.TrailerDuoStartV3) =====
local running = false
function _G.TrailerDuoStartV3()
    if running then
        return
    end
    running = true
    local restore = {}
    local fxFolder = Instance.new("Folder")
    fxFolder.Name = "TrailerDuoFX"
    fxFolder.Parent = workspace
    local statusGui = Instance.new("ScreenGui")
    statusGui.Name = "TrailerDuoStatus"
    statusGui.DisplayOrder = 1000
    statusGui.ResetOnSpawn = false
    local statusLabel = Instance.new("TextLabel", statusGui)
    statusLabel.AnchorPoint = Vector2.new(0.5, 0)
    statusLabel.Position = UDim2.new(0.5, 0, 0, 70)
    statusLabel.Size = UDim2.fromOffset(460, 40)
    statusLabel.BackgroundColor3 = Color3.fromRGB(29, 20, 32)
    statusLabel.TextColor3 = Color3.new(1, 1, 1)
    statusLabel.Font = Enum.Font.FredokaOne
    statusLabel.TextSize = 20
    statusLabel.Text = "Loading actors…"
    statusGui.Parent = playerGui
    -- gates (local only; PortalClient draws the vortex because of the tag)
    local gates = {}
    for i, info in ACTORS do
        local gateCF = lookAt(vec3(info.gateX, GROUND, GATE_Z), vec3(info.gateX, GROUND, GATE_Z + 10))
        gates[i] = PortalBuilder.Build(gateCF, fxFolder)
        gates[i]:SetAttribute("SurgeLevel", 0)
    end
    -- Actor 1 (Jen) uses the gate at x = -232 (side -1), actor 2 (Jac) the gate at x = -200 (side 1).
    local actors = {}
    for i, info in ACTORS do
        local actor = buildActor(info.id, fxFolder)
        if actor then
            actor.info = info
            actor.side = i == 1 and -1 or 1
            actor.gate = gates[i]
            actor.m.Parent = fxFolder
            actors[i] = actor
        end
    end
    -- egg
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
    egg.WorldPivot = CFrame.new(eggBoxCF.Position - vec3(0, eggBoxSize.Y / 2, 0))
    egg.Parent = fxFolder
    local glow = Instance.new("Highlight", egg)
    glow.FillColor = Color3.fromRGB(255, 240, 180)
    glow.FillTransparency = 1
    glow.OutlineTransparency = 1
    -- Invisible anchor at the egg's landing point: splash spray + burst sparks (emitted on cue).
    local eggFxPart = Instance.new("Part", fxFolder)
    eggFxPart.Size = vec3(1, 1, 1)
    eggFxPart.Transparency = 1
    eggFxPart.Anchored = true
    eggFxPart.CanCollide = false
    eggFxPart.CFrame = CFrame.new(EGG_POS)
    local splashAttachment = Instance.new("Attachment", eggFxPart)
    local spray = Instance.new("ParticleEmitter", splashAttachment)
    spray.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    spray.Rate = 0
    spray.Speed = NumberRange.new(14, 24)
    spray.Lifetime = NumberRange.new(0.5, 0.9)
    spray.SpreadAngle = Vector2.new(70, 70)
    spray.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255))
    spray.LightEmission = 0.6
    spray.Size = NumberSequence.new(0.8, 0)
    spray.Acceleration = vec3(0, -30, 0)
    local sparks = Instance.new("ParticleEmitter", splashAttachment)
    sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    sparks.Rate = 0
    sparks.Speed = NumberRange.new(10, 22)
    sparks.Lifetime = NumberRange.new(0.6, 1.1)
    sparks.SpreadAngle = Vector2.new(180, 180)
    sparks.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120))
    sparks.LightEmission = 1
    sparks.Size = NumberSequence.new(0.9, 0)
    -- Spark trail that follows the falling egg.
    local trailPart = Instance.new("Part", fxFolder)
    trailPart.Size = vec3(0.5, 0.5, 0.5)
    trailPart.Transparency = 1
    trailPart.Anchored = true
    trailPart.CanCollide = false
    local trailAttachment = Instance.new("Attachment", trailPart)
    local trailEmitter = Instance.new("ParticleEmitter", trailAttachment)
    trailEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    trailEmitter.Rate = 0
    trailEmitter.Speed = NumberRange.new(1, 3)
    trailEmitter.Lifetime = NumberRange.new(0.4, 0.8)
    trailEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90))
    trailEmitter.LightEmission = 1
    trailEmitter.Size = NumberSequence.new(0.7, 0)
    trailEmitter.SpreadAngle = Vector2.new(180, 180)
    -- Neon ball tweened open at the burst.
    local flashPart = Instance.new("Part", fxFolder)
    flashPart.Shape = Enum.PartType.Ball
    flashPart.Material = Enum.Material.Neon
    flashPart.Color = Color3.new(1, 1, 1)
    flashPart.Anchored = true
    flashPart.CanCollide = false
    flashPart.Transparency = 1
    flashPart.Size = vec3(1, 1, 1)
    flashPart.CFrame = CFrame.new(EGG_POS + vec3(0, 2, 0))
    -- Countdown: yields 3 s so the recorder can be started.
    for i = 3, 1, -1 do
        statusLabel.Text = "Trailer v3 starts in " .. i .. " — start recording"
        task.wait(1)
    end
    statusGui:Destroy()
    -- End card, then hide UI + players for recording (each change registers a restore callback).
    local cardGui = Instance.new("ScreenGui")
    cardGui.Name = "TrailerDuoCard"
    cardGui.IgnoreGuiInset = true
    cardGui.DisplayOrder = 1002
    local flashFrame = Instance.new("Frame", cardGui)
    flashFrame.Size = UDim2.fromScale(1, 1)
    flashFrame.BackgroundColor3 = Color3.new(1, 1, 1)
    flashFrame.BackgroundTransparency = 1
    flashFrame.BorderSizePixel = 0
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
    for _, screenGui in playerGui:GetChildren() do
        if screenGui:IsA("ScreenGui") and screenGui ~= cardGui and screenGui.Enabled then
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
    for _, desc in workspace:GetDescendants() do
        if desc:IsA("BillboardGui") and desc.Enabled and not desc:IsDescendantOf(fxFolder) then
            desc.Enabled = false
            table.insert(restore, function()
                desc.Enabled = true
            end)
        end
    end
    local hidden = {}
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
    -- Ground height under a point (ignores the FX folder, hits water); inside a gate footprint the gate floor
    -- height is used instead; GROUND when nothing is hit.
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { fxFolder }
    rayParams.IgnoreWater = false
    local function groundY(pos, gateX)
        if pos.Z < -40.5 and gateX and math.abs(pos.X - gateX) < 8.5 then
            return GROUND + PortalConfig.GroundY
        end
        local hit = workspace:Raycast(vec3(pos.X, 60, pos.Z), vec3(0, -100, 0), rayParams)
        return hit and hit.Position.Y or GROUND
    end
    for _i, actor in actors do
        actor.walkOut = vec3(actor.info.gateX, GROUND + PortalConfig.GroundY, GATE_Z + PortalConfig.WalkOut)
        actor.startPos = vec3(actor.info.gateX, GROUND + PortalConfig.GroundY, GATE_Z - PortalConfig.StartBehind)
        actor.grab = vec3(EGG_POS.X + actor.side * 3.6, EGG_POS.Y, EGG_POS.Z - 2)
        actor.surf = actor.gate:FindFirstChild("Surface")
        actor.crossed = false
    end
    local yawRiver = yawFacing(vec3(0, 0, 1))
    local yawTemple = yawFacing(vec3(0, 0, -1))
    -- PlayerGui BillboardGuis already given a restore callback (they are re-disabled every frame).
    local disabledBillboards = {}
    local lastShot, camCF = -1, lookAt(vec3(-216, 30, -22), vec3(-216, 31, -48))
    local startTime = os.clock()
    local impactShake = 0
    local renderConn
    -- Per-frame driver. Re-hides streamed-in river eggs, newly enabled ScreenGuis and PlayerGui billboards.
    renderConn = RunService.RenderStepped:Connect(function(dt)
        local t = os.clock() - startTime
        fxFolder:SetAttribute("T", t)
        for _, hiddenPart in hidden do
            hiddenPart.LocalTransparencyModifier = 1
        end
        camera.CameraType = Enum.CameraType.Scriptable
        for _, folderName in { "WaterfallEggs", "LocalRiverEggs" } do
            local eggFolder = workspace:FindFirstChild(folderName)
            if eggFolder then
                for _, desc in eggFolder:GetDescendants() do
                    if desc:IsA("BasePart") or desc:IsA("Decal") then
                        desc.LocalTransparencyModifier = 1
                    elseif desc:IsA("BillboardGui") then
                        desc.Enabled = false
                    end
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
        for _, billboard in playerGui:GetDescendants() do
            if billboard:IsA("BillboardGui") and billboard.Enabled then
                billboard.Enabled = false
                if not disabledBillboards[billboard] then
                    disabledBillboards[billboard] = true
                    table.insert(restore, function()
                        if billboard.Parent then
                            billboard.Enabled = true
                        end
                    end)
                end
            end
        end
        -- gates surge
        local surge = ease(segment(t, 0, 0.8)) * (1 - ease(segment(t, 2.6, 3.6)))
        for _, gate in gates do
            gate:SetAttribute("SurgeLevel", surge)
        end
        -- egg
        local eggHeight
        local eggVisible = t >= 5.3
        if t < 5.3 then
            eggHeight = 80
        elseif t < 6.3 then
            eggHeight = lerp(60, 0, segment(t, 5.3, 6.3) ^ 2)
        else
            eggHeight = 0
        end
        local tugProgress = segment(t, 9.4, 13.3)
        local shake = t > 9.4 and t < 13.4 and (0.03 + 0.15 * tugProgress) or 0
        local nudge = t > 9.4 and t < 13.4 and math.sin(t * 7) * 0.45 or 0
        local bob = t > 6.3 and t < 13.4 and -0.6 + 0.15 * math.sin(t * 3) or 0
        -- The last two branches are identical (selene if_same_then_else, pre-existing; harmless, kept as-is).
        if eggVisible and t < 13.4 then
            egg:PivotTo(
                CFrame.new(EGG_POS + vec3(nudge, eggHeight + bob, 0))
                    * angles(math.sin(t * 37) * shake, t < 6.3 and t * 4 or 0, math.cos(t * 31) * shake)
            )
        elseif t >= 13.4 then
            egg:PivotTo(CFrame.new(0, -500, 0))
        else
            egg:PivotTo(CFrame.new(0, -500, 0))
        end
        if t >= 5.3 and t < 6.3 then
            trailPart.CFrame = CFrame.new(EGG_POS + vec3(0, eggHeight + 2, 0))
            trailEmitter:Emit(3)
        end
        if t >= 6.3 and not fxFolder:GetAttribute("splash") then
            fxFolder:SetAttribute("splash", true)
            spray:Emit(60)
            impactShake = 0.6
            local splashRing = Instance.new("Part", fxFolder)
            splashRing.Shape = Enum.PartType.Cylinder
            splashRing.Material = Enum.Material.Neon
            splashRing.Color = Color3.fromRGB(220, 245, 255)
            splashRing.Anchored = true
            splashRing.CanCollide = false
            splashRing.Size = vec3(0.2, 2, 2)
            splashRing.CFrame = CFrame.new(EGG_POS + vec3(0, 0.1, 0)) * angles(0, 0, math.pi / 2)
            splashRing.Transparency = 0.2
            TweenService:Create(
                splashRing,
                TweenInfo.new(0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                { Size = vec3(0.2, 16, 16), Transparency = 1 }
            ):Play()
        end
        glow.FillTransparency = 1 - 0.35 * tugProgress
        glow.OutlineTransparency = 1 - 0.9 * tugProgress
        glow.OutlineColor = Color3.fromRGB(255, 220, 120)
        if t >= 13.4 and not fxFolder:GetAttribute("burst") then
            fxFolder:SetAttribute("burst", true)
            sparks:Emit(80)
            impactShake = 0.9
            flashPart.Transparency = 0
            TweenService:Create(
                flashPart,
                TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Size = vec3(18, 18, 18), Transparency = 0.4 }
            ):Play()
        end
        -- actors (timeline in the header)
        for i, actor in actors do
            local gateX = actor.info.gateX
            local pos, yaw, anim, animSpeed, poseOffsets = actor.walkOut, yawRiver, "idle", 1, nil
            local visible = true
            if t < 0.8 then
                pos = actor.startPos
                visible = false
            elseif t < 2.6 then
                local walkAlpha = segment(t, 0.8, 2.6)
                local walkProgress = walkAlpha < 0.85 and walkAlpha
                    or 0.85 + (1 - (1 - (walkAlpha - 0.85) / 0.15) ^ 2) * 0.15
                pos = actor.startPos:Lerp(actor.walkOut, walkProgress)
                anim = "walk"
                animSpeed = 1.15
            elseif t < 3.6 then
                poseOffsets = {
                    Neck = angles(0.02, math.sin((t - 2.6) * 5.5 + i * 1.3) * 0.75, 0),
                    Waist = angles(0, math.sin((t - 2.6) * 5.5 + i * 1.3) * 0.2, 0),
                }
            elseif t < 4.3 then
                yaw = lerp(yawRiver, yawTemple, ease(segment(t, 3.6, 4.1)))
                poseOffsets = { Neck = angles(0.35 * segment(t, 4.0, 4.3), 0, 0) }
            elseif t < 5.0 then
                yaw = yawTemple
                poseOffsets = { Neck = angles(0.4, 0.15 * math.sin((t - 4.3) * 4), 0) }
            elseif t < 5.9 then
                yaw = lerp(yawTemple, yawRiver, ease(segment(t, 5.0, 5.45)))
            elseif t < 6.5 then
                poseOffsets = SHOCK_POSE
            elseif t < 9.0 then
                local alpha = segment(t, 6.5, 9.0)
                pos = actor.walkOut:Lerp(actor.grab, alpha ^ 1.15)
                pos = vec3(pos.X, groundY(pos, gateX), pos.Z)
                yaw = yawFacing(actor.grab - actor.walkOut)
                anim = "run"
                animSpeed = 1.5
            elseif t < 9.4 then
                pos = actor.grab + vec3(0, 0.35, 0)
                yaw = yawFacing(vec3(-actor.side, 0, 0))
                poseOffsets = DIVE_POSE
                anim = nil
            elseif t < 13.4 then
                local pull = math.sin(t * 7 + i * math.pi)
                pos = actor.grab + vec3(actor.side * 0.45 * pull, 0, 0)
                yaw = yawFacing(vec3(-actor.side, 0, 0))
                poseOffsets = tugPose(pull)
                anim = nil
            else
                local alpha = segment(t, 13.4, 14.0)
                pos = actor.grab + vec3(actor.side * 5 * alpha, 1.4 * math.sin(alpha * math.pi), 0)
                yaw = yawFacing(vec3(-actor.side, 0, 0))
                poseOffsets = BLOWN_POSE
                anim = nil
            end
            playAnim(actor, anim, animSpeed)
            applyPose(actor, poseOffsets)
            actor.m:SetAttribute("Anim", anim or "pose")
            actor.m.HumanoidRootPart.CFrame = CFrame.new(pos + vec3(0, actor.off, 0)) * angles(0, yaw, 0)
            -- gate crossing fade
            if not visible then
                for _, part in actor.parts do
                    part.LocalTransparencyModifier = 1
                end
            elseif t < 3.6 then
                local surfaceNormal, surfaceOrigin = actor.surf.CFrame.LookVector, actor.surf.Position
                for _, part in actor.parts do
                    if part:IsA("BasePart") then
                        local depth = (part.Position - surfaceOrigin):Dot(surfaceNormal)
                        part.LocalTransparencyModifier = clamp(0.5 - depth / PortalConfig.FadeBand, 0, 1)
                    else
                        part.LocalTransparencyModifier = 0
                    end
                end
                local chest = actor.m:FindFirstChild("UpperTorso")
                if chest and not actor.crossed and (chest.Position - surfaceOrigin):Dot(surfaceNormal) > 0 then
                    actor.crossed = true
                    if _G.PortalRipple then
                        _G.PortalRipple(actor.gate, chest.Position)
                    end
                end
            else
                for _, part in actor.parts do
                    part.LocalTransparencyModifier = 0
                end
            end
            actor.head = actor.m.Head.Position
        end
        -- camera: pick this frame's target shot (cut ids below)
        -- Known issue (not fixed): errors every frame if either rig failed to build (no nil fallback as in v2).
        local jenHead, jacHead = actors[1].head, actors[2].head
        local mid = (jenHead + jacHead) / 2
        local _eggFocus = EGG_POS + vec3(0, eggHeight + 2, 0)
        local target, targetFov, shotId
        if t < 0.8 then
            shotId = 0
            target = lookAt(vec3(-216, 31, -14 + 3 * segment(t, 0, 0.8)), vec3(-216, 34, -50))
            targetFov = 66
        elseif t < 2.6 then
            shotId = 1
            target = lookAt(vec3(-216, 29, -24 + 2 * segment(t, 0.8, 2.6)), mid)
            targetFov = 64
        elseif t < 3.1 then
            shotId = 2
            target = lookAt(jenHead + vec3(0, 0.3, 5.5), jenHead)
            targetFov = 40
        elseif t < 3.6 then
            shotId = 3
            target = lookAt(jacHead + vec3(0, 0.3, 5.5), jacHead)
            targetFov = 40
        elseif t < 5.0 then
            shotId = 4
            local k = ease(segment(t, 3.75, 4.35))
            target = lookAt(vec3(-216, 29 + 4 * k, -30), mid:Lerp(TEMPLE_LOOK, k))
            targetFov = 62
        elseif t < 5.9 then
            shotId = 5
            target = lookAt(vec3(-216, 29, -26), mid + vec3(0, 0.5, 0))
            targetFov = 60
        elseif t < 6.6 then
            shotId = 6
            target = lookAt(vec3(-236, 30, 6), EGG_POS + vec3(0, eggHeight * 0.6 + 2, 0))
            targetFov = 50
        elseif t < 9.0 then
            shotId = 7
            target = lookAt(vec3(mid.X, 28.5, mid.Z + 16), mid + vec3(0, 1, 0))
            targetFov = 62
        elseif t < 13.4 then
            local cut = math.floor((t - 9.0) / 1.1) % 3
            shotId = 8 + math.floor((t - 9.0) / 1.1)
            if cut == 0 then
                target = lookAt(EGG_POS + vec3(0, 4.5, -11), EGG_POS + vec3(0, 2, 0))
                targetFov = 50
            elseif cut == 1 then
                target = lookAt(jenHead + vec3(4, 0.3, -2.5), jenHead)
                targetFov = 42
            else
                target = lookAt(jacHead + vec3(-4, 0.3, -2.5), jacHead)
                targetFov = 42
            end
        else
            shotId = 99
            target = lookAt(EGG_POS + vec3(0, 2.5, -9), EGG_POS + vec3(0, 1.5, 0))
            targetFov = 52
        end
        -- Hard cut when the shot id changes, otherwise ease towards the shot's target.
        if shotId ~= lastShot then
            lastShot = shotId
            camCF = target
        else
            camCF = camCF:Lerp(target, 0.14)
        end
        impactShake = math.max(0, impactShake - dt * 1.6)
        local shakeStrength = impactShake + shake * 2.2
        camera.CFrame = camCF
            * CFrame.new(math.noise(t * 22, 1) * shakeStrength, math.noise(t * 22, 5) * shakeStrength, 0)
            * angles(0, 0, math.noise(t * 18, 9) * shakeStrength * 0.05)
        camera.FieldOfView = lerp(camera.FieldOfView, targetFov, 0.2)
        -- white card / end titles
        flashFrame.BackgroundTransparency = 1 - segment(t, 13.5, 13.9)
        local titleTransparency = 1 - segment(t, 14.2, 14.7)
        titleLabel.TextTransparency = titleTransparency
        titleStroke.Transparency = titleTransparency
        local taglineTransparency = 1 - segment(t, 14.6, 15.1)
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
            for _, folderName in { "WaterfallEggs", "LocalRiverEggs" } do
                local eggFolder = workspace:FindFirstChild(folderName)
                if eggFolder then
                    for _, desc in eggFolder:GetDescendants() do
                        if desc:IsA("BasePart") or desc:IsA("Decal") then
                            desc.LocalTransparencyModifier = 0
                        elseif desc:IsA("BillboardGui") then
                            desc.Enabled = true
                        end
                    end
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

-- ===== 7. Test hook =====
player:GetAttributeChangedSignal("TrailerGo3"):Connect(function()
    if player:GetAttribute("TrailerGo3") then
        _G.TrailerDuoStartV3()
    end
end)
