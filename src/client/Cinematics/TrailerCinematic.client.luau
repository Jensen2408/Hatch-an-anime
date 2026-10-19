--[[ StarterPlayerScripts.TrailerCinematic  (LocalScript)
Recording-only trailer for "Hatch an Anime". Runs entirely on YOUR client:
no currency, inventory, saves, hatch timers or server state are touched. Everything it creates is local
and removed on finish / cancel / death / error. Start: /trailer or F7. Cancel: /trailerstop or F7 again.
Delete this script + TrailerConfig + Workspace.TrailerMarkers to remove it completely.

Who can run it: only Config.OwnerIds (or anyone in Studio when Config.AllowInStudio); for everybody else
the script returns right after requiring ReplicatedStorage.TrailerConfig.

Triggers (section 18)
  TextChatCommand "TrailerStart" (alias Config.Command)     stops a running take, then calls _G.TrailerPicker
                                                            if a picker script defined it, else start()
  TextChatCommand "TrailerStop"  (alias Config.StopCommand) stop()
  Config.Key (InputBegan, not gameProcessed)                toggles start / stop
  player attribute "TrailerGo"                              true -> start(), false -> stop() (test hook)

_G contracts (keep exactly)
  _G.TrailerStartV1 = start   exported; the pickers in TrailerDuoV2 / TrailerDuoV3 call it for this trailer
  _G.TrailerPicker            read only; defined by TrailerDuoV3 (shows the trailer picker instead of starting)

How a take runs
  start() -> prepare(run) in task.spawn: find markers / your plot / incubator / slot, build a local avatar clone
  ("TrailerActor") and the egg + reward props, plan Pathfinding routes, preload assets, count down
  Config.StartDelay seconds, hide UI / players / controls (hideForRecording), then bind updateFrame to
  RenderStep "TrailerCinematic" (Camera priority + 2). cleanup() undoes everything (restore callbacks run in
  reverse order) and is reached on finish, cancel, character death / respawn and on any error.

Shot list (SCENES, played in this order; base durations in seconds, Config.Durations[name] overrides)
  Intro        7  drone flyover of the map, letterbox bars, title + tagline, white flash into the rift
  RiftArrival  9  rift cracks open in the sky, the avatar falls through it, lands, looks around; rift closes
  SpotEgg      7  the pirate egg floats down the river; close-up + glint; the avatar gets excited
  Chase       10  run along the river, trip and recover, run again, grab the egg
  BringHome    9  carry the egg through the temple entrance to the incubator (glass doors open)
  Hatch        9  slam the egg into the incubator, rumble, reveal the reward character, lift it
  Place        9  walk to the free slot, place the reward, step back, celebrate; outro title on the final hold
Every scene update receives t / dt in BASE seconds (rescaled when Config.Durations stretches a scene), so all
cue times below are base seconds. once(run, key) fires a cue a single time per scene (run.cues is reset on
every scene change).

Naming: `run` is the per-take state table (A = actor, egg / reward = props, M = markers, FX = folder of
everything spawned, camCF / fov = camera target, cues, restore, conns, routes, socket, ...). Poses are
procedural Motor6D offsets (POSE.*) unless Config.Animations supplies an animation track for that pose name.
]]

-- ===== 1. Services, config and owner gate =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local ContentProvider = game:GetService("ContentProvider")
local CollectionService = game:GetService("CollectionService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local PathfindingService = game:GetService("PathfindingService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("TrailerConfig"))

local player = Players.LocalPlayer
if not (Config.OwnerIds[player.UserId] or (Config.AllowInStudio and RunService:IsStudio())) then
    return
end

-- ===== 2. Math and geometry helpers =====
-- segment(t, a, b): 0..1 progress of t through [a, b]. ease = smoothstep; accelCurve / decelCurve = run-up /
-- slow-down curves. Yaw 0 faces -Z (Roblox LookVector); yawOf returns nil for (near) vertical directions.
local clamp, sin, cos, abs, max, pi = math.clamp, math.sin, math.cos, math.abs, math.max, math.pi
local UP = Vector3.yAxis
local function segment(t, startT, endT)
    return clamp((t - startT) / (endT - startT), 0, 1)
end
local function ease(alpha)
    alpha = clamp(alpha, 0, 1)
    return alpha * alpha * (3 - 2 * alpha)
end
local function easeIn(alpha)
    alpha = clamp(alpha, 0, 1)
    return alpha * alpha
end
local function easeOut(alpha)
    alpha = clamp(alpha, 0, 1)
    return 1 - (1 - alpha) * (1 - alpha)
end
local function accelCurve(alpha)
    return alpha < 0.15 and (alpha * alpha / 0.3) or ((alpha - 0.075) / 0.925)
end
local function decelCurve(alpha)
    return 1 - (1 - clamp(alpha, 0, 1)) ^ 1.6
end
local function lerp(from, to, alpha)
    return from + (to - from) * alpha
end
local function flatten(vec)
    return Vector3.new(vec.X, 0, vec.Z)
end
local function unitOrDefault(vec, default)
    return vec.Magnitude > 1e-3 and vec.Unit or default
end
local function yawOf(dir)
    dir = flatten(dir)
    if dir.Magnitude < 1e-3 then
        return nil
    end
    return math.atan2(-dir.X, -dir.Z)
end
local function forwardFromYaw(yawAngle)
    return Vector3.new(-sin(yawAngle), 0, -cos(yawAngle))
end
local function wrapAngle(angle)
    return (angle + pi) % (2 * pi) - pi
end
local function lerpAngle(angle, target, alpha)
    return angle + wrapAngle(target - angle) * alpha
end
local function pivotOf(instance)
    return instance:IsA("Model") and instance:GetPivot() or instance.CFrame
end
local function setPivot(instance, targetCF)
    if instance:IsA("Model") then
        instance:PivotTo(targetCF)
    else
        instance.CFrame = targetCF
    end
end
-- "Workspace/Folder/Child" (or an Instance) -> Instance or nil; the first segment is a service name.
local function resolvePath(path)
    if typeof(path) == "Instance" then
        return path
    end
    if type(path) ~= "string" or path == "" then
        return nil
    end
    local parts = string.split(path, "/")
    local current = (parts[1]:lower() == "workspace") and workspace or game:FindFirstChild(parts[1])
    for i = 2, #parts do
        current = current and current:FindFirstChild(parts[i])
    end
    return current
end

-- ===== 3. Status toast (owner-only on-screen messages) =====
-- statusGeneration turns a delayed hide into a no-op once a newer message has been shown.
local statusGui, statusGeneration = nil, 0
local function showStatus(text, hideAfter)
    if not statusGui then
        statusGui = Instance.new("ScreenGui")
        statusGui.Name = "TrailerStatus"
        statusGui.ResetOnSpawn = false
        statusGui.DisplayOrder = 1000
        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.AnchorPoint = Vector2.new(0.5, 0)
        label.Position = UDim2.new(0.5, 0, 0, 70)
        label.AutomaticSize = Enum.AutomaticSize.XY
        label.BackgroundColor3 = Color3.fromRGB(29, 20, 32)
        label.BackgroundTransparency = 0.1
        label.TextColor3 = Color3.fromRGB(255, 243, 220)
        label.Font = Enum.Font.FredokaOne
        label.TextSize = 20
        label.Parent = statusGui
        local padding = Instance.new("UIPadding")
        padding.PaddingLeft, padding.PaddingRight, padding.PaddingTop, padding.PaddingBottom =
            UDim.new(0, 14), UDim.new(0, 14), UDim.new(0, 8), UDim.new(0, 8)
        padding.Parent = label
        Instance.new("UICorner", label).CornerRadius = UDim.new(0, 10)
        statusGui.Parent = player:WaitForChild("PlayerGui")
    end
    statusGeneration += 1
    local generation = statusGeneration
    statusGui.Label.Text = text
    statusGui.Enabled = true
    if hideAfter then
        task.delay(hideAfter, function()
            if generation == statusGeneration then
                statusGui.Enabled = false
            end
        end)
    end
end

-- ===== 4. Procedural poses =====
-- Key -> R15 Motor6D name. Each POSE.<name>(time, params) returns { key = euler(x, y, z) joint offsets,
-- rootY = root height offset, pitch = forward lean }; params is actor.P (look, k = per-pose 0..1 progress,
-- phase, gait, moving, carryR).
local JOINT_NAMES = {
    neck = "Neck",
    waist = "Waist",
    ls = "LeftShoulder",
    rs = "RightShoulder",
    le = "LeftElbow",
    re = "RightElbow",
    lh = "LeftHip",
    rh = "RightHip",
    lk = "LeftKnee",
    rk = "RightKnee",
}
local function euler(x, y, z)
    return { x or 0, y or 0, z or 0 }
end
local function runLegs(pose, phase, amount)
    local swing = sin(phase)
    pose.lh = euler(-swing * 0.9 * amount)
    pose.rh = euler(swing * 0.9 * amount)
    pose.lk = euler((-0.25 - 0.95 * max(0, swing)) * amount)
    pose.rk = euler((-0.25 - 0.95 * max(0, -swing)) * amount)
    pose.rootY = (0.14 * abs(cos(phase)) - 0.05) * amount
end
local POSE = {}
POSE.idle = function(t)
    return {
        waist = euler(-0.02 + 0.02 * sin(t * 2)),
        neck = euler(0.02 * sin(t * 1.3)),
        ls = euler(0.05, 0, -0.1),
        rs = euler(0.05, 0, 0.1),
        le = euler(0.15),
        re = euler(0.15),
    }
end
POSE.look = function(t, params)
    local pose = POSE.idle(t)
    pose.neck = euler(0.05, params.look, 0)
    pose.waist = euler(-0.02, params.look * 0.25, 0)
    return pose
end
POSE.fall = function(t)
    return {
        ls = euler(0.3, 0, -1.25 - 0.1 * sin(t * 9)),
        rs = euler(0.3, 0, 1.25 + 0.1 * sin(t * 9)),
        le = euler(0.5),
        re = euler(0.5),
        lh = euler(0.45),
        lk = euler(-0.7),
        rh = euler(-0.15),
        rk = euler(-0.45),
        neck = euler(-0.35),
    }
end
POSE.land = function()
    return {
        rootY = -0.7,
        waist = euler(-0.55),
        neck = euler(0.45),
        lh = euler(1.2),
        lk = euler(-1.7),
        rh = euler(1.0, 0, 0.12),
        rk = euler(-1.6),
        rs = euler(0.6, 0, 0.25),
        re = euler(0.35),
        ls = euler(-0.35, 0, -0.6),
        le = euler(0.5),
    }
end
POSE.excited = function(t)
    local hop = max(0, sin(t * 9))
    return {
        rootY = 0.45 * hop,
        ls = euler(2.5 + 0.25 * sin(t * 18), 0, 0.15),
        rs = euler(2.5 + 0.25 * sin(t * 18 + 1), 0, -0.15),
        le = euler(0.4),
        re = euler(0.4),
        neck = euler(0.25),
        lh = euler(0.3 * hop),
        rh = euler(0.3 * hop),
        lk = euler(-0.5 * hop),
        rk = euler(-0.5 * hop),
    }
end
POSE.ready = function()
    return {
        rootY = -0.2,
        waist = euler(-0.35),
        neck = euler(0.2),
        lh = euler(0.55),
        lk = euler(-0.8),
        rh = euler(-0.25),
        rk = euler(-0.35),
        ls = euler(-0.5, 0, -0.1),
        rs = euler(0.6, 0, 0.1),
        le = euler(0.9),
        re = euler(0.9),
    }
end
POSE.run = function(_t, params)
    local swing = sin(params.phase)
    local pose = {
        waist = euler(-0.18),
        neck = euler(0.12),
        ls = euler(swing * 1.05, 0, -0.08),
        rs = euler(-swing * 1.05, 0, 0.08),
        le = euler(1.25),
        re = euler(1.25),
    }
    runLegs(pose, params.phase, 1)
    return pose
end
POSE.carry = function(_t, params)
    local armSpread = clamp(0.42 - 0.27 * (params.carryR or 1), 0, 0.35)
    local gait = params.gait or 1
    local pose = {
        waist = euler(-0.06 * gait),
        neck = euler(-0.05),
        ls = euler(1.15, 0, armSpread),
        rs = euler(1.15, 0, -armSpread),
        le = euler(0.35),
        re = euler(0.35),
    }
    if params.moving then
        runLegs(pose, params.phase, 0.85 * gait)
    end
    return pose
end
POSE.walk = function(_t, params)
    local swing = sin(params.phase)
    local pose = {
        waist = euler(-0.04),
        neck = euler(0.04),
        ls = euler(swing * 0.5, 0, -0.08),
        rs = euler(-swing * 0.5, 0, 0.08),
        le = euler(0.35),
        re = euler(0.35),
    }
    runLegs(pose, params.phase, 0.55)
    return pose
end
POSE.stumble = function(_t, params)
    local k = params.k
    return {
        pitch = 1.42 * k,
        rootY = -0.12 * k,
        waist = euler(-0.1 * k),
        neck = euler(0.65 * k),
        ls = euler(0.4 + 2.3 * k, 0, -0.15),
        rs = euler(0.4 + 2.3 * k, 0, 0.15),
        le = euler(0.2),
        re = euler(0.2),
        lh = euler(-0.2 - 0.45 * k),
        lk = euler(-0.6 * k),
        rh = euler(0.35 * k),
        rk = euler(-0.25),
    }
end
POSE.recover = function(_t, params)
    local k = params.k
    local armLift = 0.1 + 1.5 * clamp(k / 0.6, 0, 1)
    local tuck = 4 * k * (1 - k)
    return {
        pitch = 1.42 * k,
        waist = euler(-0.3 * k),
        neck = euler(0.5 * k),
        ls = euler(armLift, 0, -0.1),
        rs = euler(armLift, 0, 0.1),
        le = euler(0.15),
        re = euler(0.15),
        lh = euler(tuck),
        lk = euler(-1.5 * tuck),
        rh = euler(0.6 * tuck),
        rk = euler(-tuck),
    }
end
POSE.grab = function(_t, params)
    local k = params.k
    return {
        rootY = -0.1 * k,
        waist = euler(-0.45 * k),
        neck = euler(-0.3 * k),
        ls = euler(0.4 + k, 0, 0.25 * k),
        rs = euler(0.4 + k, 0, -0.25 * k),
        le = euler(0.3),
        re = euler(0.3),
        lh = euler(0.3 * k),
        lk = euler(-0.5 * k),
        rh = euler(0.1),
        rk = euler(-0.3 * k),
    }
end
POSE.push = function(_t, params)
    local k = params.k
    return {
        rootY = -0.07 * k,
        waist = euler(-0.15 - 0.25 * k),
        neck = euler(-0.05),
        ls = euler(0.9 + 0.75 * k, 0, 0.3),
        rs = euler(0.9 + 0.75 * k, 0, -0.3),
        le = euler(0.1 + 1.6 * (1 - k)),
        re = euler(0.1 + 1.6 * (1 - k)),
        lh = euler(0.4 * k),
        lk = euler(-0.5 * k),
        rh = euler(-0.3 * k),
    }
end
POSE.lean = function(t)
    return {
        rootY = -0.05,
        waist = euler(-0.42),
        neck = euler(0.35),
        ls = euler(0.35, 0, -0.05),
        rs = euler(0.35, 0, 0.05),
        le = euler(0.6),
        re = euler(0.6),
        rh = euler(0.2),
        rk = euler(-0.25 - 0.15 * max(0, sin(t * 7))),
    }
end
POSE.place = function(_t, params)
    local k = params.k
    return {
        rootY = -0.16 * k,
        waist = euler(-0.55 * k),
        neck = euler(-0.3 * k),
        ls = euler(0.9 + 0.3 * k, 0, 0.3),
        rs = euler(0.9 + 0.3 * k, 0, -0.3),
        le = euler(0.3),
        re = euler(0.3),
        lh = euler(0.4 * k),
        rh = euler(0.4 * k),
        lk = euler(-0.8 * k),
        rk = euler(-0.8 * k),
    }
end
POSE.celebrate = function(t)
    local hop = max(0, sin(t * 7.5))
    return {
        rootY = 0.6 * hop,
        ls = euler(0, 0, -(2.55 + 0.2 * sin(t * 15))),
        rs = euler(0, 0, 2.55 + 0.2 * sin(t * 15 + 1)),
        le = euler(0.3),
        re = euler(0.3),
        neck = euler(0.3),
        lh = euler(0.25 * hop),
        rh = euler(0.25 * hop),
        lk = euler(-0.45 * hop),
        rk = euler(-0.45 * hop),
    }
end

-- Blend two pose tables (missing entries count as zero) for cross-fades between procedural poses.
local function mix(fromPose, toPose, weight)
    local out = {}
    for key, value in fromPose do
        local other = toPose[key]
        if type(value) == "table" then
            other = other or euler()
            out[key] = euler(
                lerp(value[1], other[1], weight),
                lerp(value[2], other[2], weight),
                lerp(value[3], other[3], weight)
            )
        else
            out[key] = lerp(value, other or 0, weight)
        end
    end
    for key, value in toPose do
        if out[key] == nil then
            if type(value) == "table" then
                out[key] = euler(value[1] * weight, value[2] * weight, value[3] * weight)
            else
                out[key] = value * weight
            end
        end
    end
    return out
end

-- ===== 5. Run state, markers and actor posing =====
-- activeRun: the take in progress (nil when idle). Closures compare against it to stop acting after cleanup.
local activeRun = nil
local function once(run, key)
    if run.cues[key] then
        return false
    end
    run.cues[key] = true
    return true
end
local function actorBaseCF(run)
    return CFrame.new(run.A.pos) * CFrame.Angles(0, run.A.yaw, 0)
end
local function markerPos(run, markerName)
    return run.M[markerName] and run.M[markerName].Position
end

local function setPose(run, actor, poseName, fadeTime)
    if actor.pose == poseName then
        return
    end
    actor.prev, actor.pose, actor.blend0, actor.blendDur = actor.pose, poseName, run.now, fadeTime or 0.2
    for trackName, track in actor.tracks do
        if trackName ~= poseName and track.IsPlaying then
            track:Stop(fadeTime or 0.2)
        end
    end
    if actor.tracks[poseName] then
        actor.tracks[poseName]:Play(fadeTime or 0.2)
    end
end
-- Every frame: place the root, drive the Motor6Ds (skipped while an animation track plays this pose),
-- cache the hand midpoint for carried props and apply actor visibility.
local function actorApply(run)
    local actor = run.A
    local useTrack = actor.tracks[actor.pose] ~= nil
    local pose = {}
    if not useTrack then
        pose = (POSE[actor.pose] or POSE.idle)(run.now, actor.P)
        local blendWeight = actor.blendDur > 0 and clamp((run.now - actor.blend0) / actor.blendDur, 0, 1) or 1
        if blendWeight < 1 and actor.prev and POSE[actor.prev] and not actor.tracks[actor.prev] then
            pose = mix(POSE[actor.prev](run.now, actor.P), pose, ease(blendWeight))
        end
    end
    actor.root.CFrame = actorBaseCF(run)
        * CFrame.new(0, pose.rootY or 0, 0)
        * CFrame.Angles(-(pose.pitch or 0), 0, 0)
        * CFrame.new(0, actor.offset, 0)
    for key, joint in actor.joints do
        local jointAngles = (not useTrack) and pose[key]
        joint.C0 = jointAngles and (actor.c0[key] * CFrame.Angles(jointAngles[1], jointAngles[2], jointAngles[3]))
            or actor.c0[key]
    end
    local leftHand, rightHand = actor.model:FindFirstChild("LeftHand"), actor.model:FindFirstChild("RightHand")
    if leftHand and rightHand then
        actor.handsLocal = actor.root.CFrame:PointToObjectSpace((leftHand.Position + rightHand.Position) / 2)
    end
    local transparency = actor.visible and 0 or 1
    for _, bodyPart in actor.parts do
        bodyPart.LocalTransparencyModifier = transparency
    end
end

-- ===== 6. Movement and routing =====
local function groundHit(run, pos)
    return workspace:Raycast(pos + UP * 3, Vector3.new(0, -40, 0), run.ray)
end
local function stand(run, pos)
    local hit = groundHit(run, pos)
    return Vector3.new(pos.X, hit and hit.Position.Y or pos.Y, pos.Z)
end
-- Unused (kept as-is).
local function _runTo(run, from, to, alpha, rate, dt)
    local actor = run.A
    actor.pos = stand(run, from:Lerp(to, clamp(alpha, 0, 1)))
    local targetYaw = yawOf(to - from)
    if targetYaw then
        actor.yaw = lerpAngle(actor.yaw, targetYaw, 1 - math.exp(-12 * dt))
    end
    actor.P.phase += dt * max(rate, 4) * 0.55
end

-- Pathfinding route from -> to (yields in ComputeAsync). Falls back to a straight line on failure / error.
local function route(_run, from, to)
    local points = { from }
    pcall(function()
        local path = PathfindingService:CreatePath({
            AgentRadius = 1.8,
            AgentHeight = 5.5,
            AgentCanJump = false,
            WaypointSpacing = 3,
        })
        path:ComputeAsync(from, to)
        if path.Status == Enum.PathStatus.Success then
            local waypoints = path:GetWaypoints()
            for i = 2, #waypoints - 1 do
                table.insert(points, waypoints[i].Position)
            end
        end
    end)
    table.insert(points, to)
    return points
end
local function withStart(run, points)
    local copy = table.clone(points)
    copy[1] = run.A.pos
    return copy
end
-- Move the actor to polyline position alpha, advance the gait phase by distance and turn toward travel.
local function walkAlong(run, path, alpha, dt)
    local actor = run.A
    local point, direction = path(alpha)
    local newPos = stand(run, point)
    actor.P.phase += flatten(newPos - actor.pos).Magnitude * ((actor.P.gait or 1) >= 0.9 and 1.15 or 1.8)
    actor.pos = newPos
    local targetYaw = yawOf(direction)
    if targetYaw then
        actor.yaw = lerpAngle(actor.yaw, targetYaw, 1 - math.exp(-10 * dt))
    end
end

-- ===== 7. Camera targets and shake =====
-- Scenes only set run.camCF / run.fov; updateFrame applies them (plus handheld noise and shake) to the camera.
local function camCut(run, targetCF)
    run.camCF = targetCF
end
local function camFollow(run, targetCF, speed, dt)
    run.camCF = run.camCF and run.camCF:Lerp(targetCF, 1 - math.exp(-speed * dt)) or targetCF
end
local function camLook(run, target, speed, dt)
    camFollow(run, CFrame.lookAt(run.camCF.Position, target), speed, dt)
end
local function shake(run, amplitude, duration)
    if Config.Shake <= 0 or player:GetAttribute("ReducedMotion") then
        return
    end
    table.insert(
        run.shakes,
        { t0 = run.now, amp = amplitude * Config.Shake, dur = duration, seed = math.random() * 100 }
    )
end

-- ===== 8. Sound =====
-- Config.Sounds[slot] -> local Sound in run.FX (respects the SFXMuted attribute). One-shots self-destroy.
local function playSound(run, slot, opts)
    local soundId = Config.Sounds[slot]
    if not soundId or soundId == "" or player:GetAttribute("SFXMuted") then
        return nil
    end
    opts = opts or {}
    local snd = Instance.new("Sound")
    snd.SoundId = soundId
    snd.Volume = (opts.volume or 1) * Config.Volume
    snd.Looped = opts.loop == true
    local soundGroup = SoundService:FindFirstChild(Config.SoundGroup or "")
    if soundGroup and soundGroup:IsA("SoundGroup") then
        snd.SoundGroup = soundGroup
    end
    snd.Parent = run.FX
    snd:Play()
    if not snd.Looped then
        snd.Ended:Once(function()
            snd:Destroy()
        end)
    end
    return snd
end
local function startLoop(run, slot, volume)
    if not run.loops[slot] then
        run.loops[slot] = playSound(run, slot, { loop = true, volume = volume })
    end
end
local function stopLoop(run, slot)
    local snd = run.loops[slot]
    run.loops[slot] = nil
    if snd then
        TweenService:Create(snd, TweenInfo.new(0.2), { Volume = 0 }):Play()
        Debris:AddItem(snd, 0.3)
    end
end

-- ===== 9. FX: helper parts, particles, lights, shock rings =====
local SMOKE_TEXTURE, SPARK_TEXTURE =
    "rbxasset://textures/particles/smoke_main.dds", "rbxasset://textures/particles/sparkles_main.dds"
local function makePart(run, props)
    local newPart = Instance.new("Part")
    newPart.Anchored, newPart.CanCollide, newPart.CanQuery, newPart.CanTouch, newPart.CastShadow =
        true, false, false, false, false
    newPart.TopSurface, newPart.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    for prop, value in props do
        newPart[prop] = value
    end
    newPart.Parent = run.FX
    return newPart
end
local function emitAt(run, pos, opts)
    local anchorPart = makePart(run, { Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(pos) })
    local attachment = Instance.new("Attachment")
    attachment.Parent = anchorPart
    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = opts.texture or SMOKE_TEXTURE
    emitter.Rate = 0
    emitter.Color = ColorSequence.new(opts.color or Color3.new(1, 1, 1))
    emitter.LightEmission = opts.light or 0
    emitter.LightInfluence = opts.light and 0 or 1
    emitter.Size = NumberSequence.new(opts.size0 or 1, opts.size1 or 3)
    emitter.Transparency = NumberSequence.new(opts.tr0 or 0.35, 1)
    emitter.Lifetime = NumberRange.new(opts.life or 0.8, (opts.life or 0.8) * 1.4)
    emitter.Speed = NumberRange.new(opts.speed or 4, (opts.speed or 4) * 1.6)
    emitter.SpreadAngle = Vector2.new(opts.spread or 80, opts.spread or 80)
    emitter.EmissionDirection = Enum.NormalId.Top
    emitter.Acceleration = opts.accel or Vector3.new(0, -2, 0)
    emitter.Drag = opts.drag or 2
    emitter.Rotation = NumberRange.new(0, 360)
    emitter.RotSpeed = NumberRange.new(-40, 40)
    emitter.Parent = attachment
    emitter:Emit(math.max(1, math.floor((opts.count or 10) * Config.EffectDensity + 0.5)))
    Debris:AddItem(anchorPart, 4)
end
local function dust(run, pos, count)
    local hit = groundHit(run, pos)
    local color = Color3.fromRGB(196, 178, 150)
    if hit then
        color = (hit.Instance:IsA("Terrain") and workspace.Terrain:GetMaterialColor(hit.Material) or hit.Instance.Color):Lerp(
            Color3.fromRGB(220, 208, 188),
            0.35
        )
    end
    emitAt(run, (hit and hit.Position or pos) + UP * 0.3, {
        color = color,
        count = count,
        speed = 6,
        life = 0.9,
        size0 = 1,
        size1 = 3.5,
        spread = 85,
        accel = Vector3.new(0, -3, 0),
        drag = 3,
    })
end
local function sparks(run, pos, color, count)
    emitAt(run, pos, {
        texture = SPARK_TEXTURE,
        color = color,
        light = 1,
        count = count,
        speed = 10,
        life = 0.6,
        size0 = 0.6,
        size1 = 0,
        tr0 = 0,
        spread = 180,
        accel = Vector3.new(0, -8, 0),
        drag = 4,
    })
end
local function flash(run, pos, color, peak, duration, range)
    local anchorPart = makePart(run, { Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(pos) })
    local light = Instance.new("PointLight")
    light.Color = color
    light.Range = range or 18
    light.Brightness = peak
    light.Shadows = false
    light.Parent = anchorPart
    TweenService
        :Create(light, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 })
        :Play()
    Debris:AddItem(anchorPart, duration + 0.2)
end
local function shockRing(run, pos, color, size, duration)
    local ring = makePart(run, {
        Shape = Enum.PartType.Cylinder,
        Material = Enum.Material.ForceField,
        Color = color,
        Size = Vector3.new(0.12, 1, 1),
        CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, pi / 2),
    })
    TweenService:Create(
        ring,
        TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { Size = Vector3.new(0.12, size, size), Transparency = 1 }
    ):Play()
    Debris:AddItem(ring, duration + 0.1)
end

-- ===== 10. Props (egg / reward), incubator doors, polylines =====
-- Clone a model as an inert, anchored prop with its pivot at the bottom centre. Fields: m = model,
-- h / r = current height / radius, h0 / r0 / s0 = unscaled values, rel = relative scale,
-- mode = "hidden" | "river" | "pick" | "carried" | "socket" | "slot" | "manual" | "gone" (see propApply).
local function prepProp(source, scale, height)
    local model = source:Clone()
    if model:IsA("BasePart") then
        local wrapper = Instance.new("Model")
        model.Parent = wrapper
        model = wrapper
    end
    for _, desc in model:GetDescendants() do
        if desc:IsA("BasePart") then
            desc.Anchored, desc.CanCollide, desc.CanQuery, desc.CanTouch = true, false, false, false
        elseif desc:IsA("Humanoid") then
            desc.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        elseif
            desc:IsA("BaseScript")
            or desc:IsA("BillboardGui")
            or desc:IsA("ProximityPrompt")
            or desc:IsA("ClickDetector")
        then
            desc:Destroy()
        end
    end
    if scale and scale ~= 1 then
        model:ScaleTo(model:GetScale() * scale)
    end
    if height then
        local _, initialSize = model:GetBoundingBox()
        if initialSize.Y > 0 then
            model:ScaleTo(model:GetScale() * height / initialSize.Y)
        end
    end
    local boxCF, boxSize = model:GetBoundingBox()
    model.WorldPivot = CFrame.new(boxCF.Position - UP * boxSize.Y / 2) * model:GetPivot().Rotation
    local radius0 = max(boxSize.X, boxSize.Z) / 2
    return { m = model, h0 = boxSize.Y, h = boxSize.Y, r0 = radius0, r = radius0, s0 = model:GetScale(), rel = 1 }
end
local function setScale(prop, rel)
    if prop.rel == rel then
        return
    end
    prop.rel = rel
    prop.m:ScaleTo(prop.s0 * rel)
    prop.h = prop.h0 * rel
    prop.r = prop.r0 * rel
end
local function carriedCF(run, prop)
    run.A.P.carryR = prop.r
    local holdPos = run.A.root.CFrame * run.A.handsLocal + forwardFromYaw(run.A.yaw) * (prop.r * 0.55 + 0.1)
    return CFrame.new(holdPos - UP * prop.h * 0.5) * CFrame.Angles(0, run.A.yaw, 0)
end
local function propApply(run, prop)
    if not prop.m.Parent then
        return
    end
    if prop.mode == "river" then
        local k = clamp((run.now - prop.t0) / prop.travel, 0, 1)
        local riverPos = markerPos(run, "EggStart"):Lerp(markerPos(run, "EggEnd"), k)
        prop.cf = CFrame.new(riverPos + UP * (0.15 * sin(run.now * 2.2) - prop.h * 0.15))
            * CFrame.Angles(0.06 * sin(run.now * 1.7), run.now * 0.25, 0.06 * sin(run.now * 1.3))
    elseif prop.mode == "pick" then
        local k = clamp((run.now - prop.pickT) / 0.2, 0, 1)
        prop.cf = prop.pick0:Lerp(carriedCF(run, prop), ease(k))
        if k >= 1 then
            prop.mode = "carried"
        end
    elseif prop.mode == "carried" then
        prop.cf = carriedCF(run, prop)
    elseif prop.mode == "socket" then
        prop.cf = CFrame.new(run.socket.Position)
            * CFrame.Angles(0, run.socketYaw, 0)
            * CFrame.Angles(prop.rx or 0, 0, prop.rz or 0)
    elseif prop.mode == "slot" then
        prop.cf = CFrame.new(run.slotTop) * CFrame.Angles(0, prop.spin or 0, 0)
    end
    if prop.cf then
        prop.m:PivotTo(prop.cf)
    end
end
local function eggCenter(run)
    local egg = run.egg
    return egg.cf and (egg.cf.Position + UP * egg.h * 0.5) or markerPos(run, "EggStart")
end

local function setDoors(run, openAmount)
    openAmount = clamp(openAmount, 0, 1)
    if run.doorK == openAmount then
        return
    end
    run.doorK = openAmount
    local rightVector = run.inc:GetPivot().RightVector
    for _, door in run.doors do
        setPivot(door.obj, door.closed + rightVector * (door.dir * Config.DoorSlide * openAmount))
    end
end
-- points -> (function(alpha) -> position, segment direction), total length.
local function polyline(points)
    local segLengths, totalLength = {}, 0
    for i = 1, #points - 1 do
        segLengths[i] = (points[i + 1] - points[i]).Magnitude
        totalLength += segLengths[i]
    end
    return function(alpha)
        local distance = clamp(alpha, 0, 1) * totalLength
        for i = 1, #points - 1 do
            if distance <= segLengths[i] or i == #points - 1 then
                return points[i]:Lerp(points[i + 1], segLengths[i] > 0 and clamp(distance / segLengths[i], 0, 1) or 1),
                    points[i + 1] - points[i]
            end
            distance -= segLengths[i]
        end
    end,
        totalLength
end

-- ===== 11. Scenes (shot by shot) =====
-- scene(name, baseDuration, startFn(run), updateFn(run, t, dt)). Declared in story order; Intro is defined
-- later (section 12) and moved to the front of SCENES.
local SCENES = {}
local function scene(name, baseDur, startFn, updateFn)
    table.insert(
        SCENES,
        { name = name, base = baseDur, dur = Config.Durations[name] or baseDur, start = startFn, update = updateFn }
    )
end
-- RiftArrival: the crack, glowing discs (core / ring / force-field shimmer), light and spark emitter.
-- Everything starts invisible; animateRift drives it.
local function createRiftParts(run)
    local riftParts = {}
    riftParts.crack = makePart(
        run,
        { Material = Enum.Material.Neon, Color = run.riftColor, Size = Vector3.new(0.35, 0.05, 0.35), Transparency = 1 }
    )
    riftParts.core = makePart(run, {
        Shape = Enum.PartType.Cylinder,
        Material = Enum.Material.Neon,
        Color = Color3.fromRGB(255, 248, 220),
        Size = Vector3.new(0.2, 0.05, 0.05),
        Transparency = 1,
    })
    riftParts.ring = makePart(run, {
        Shape = Enum.PartType.Cylinder,
        Material = Enum.Material.Neon,
        Color = run.riftColor,
        Size = Vector3.new(0.15, 0.05, 0.05),
        Transparency = 1,
    })
    riftParts.shimmer = makePart(run, {
        Shape = Enum.PartType.Cylinder,
        Material = Enum.Material.ForceField,
        Color = run.riftColor,
        Size = Vector3.new(0.1, 0.05, 0.05),
        Transparency = 1,
    })
    riftParts.light = Instance.new("PointLight")
    riftParts.light.Color = run.riftColor
    riftParts.light.Range = 50
    riftParts.light.Brightness = 0
    riftParts.light.Parent = riftParts.core
    local sparkAttachment = Instance.new("Attachment")
    sparkAttachment.Parent = riftParts.ring
    riftParts.emitter = Instance.new("ParticleEmitter")
    riftParts.emitter.Texture = SPARK_TEXTURE
    riftParts.emitter.Rate = 0
    riftParts.emitter.LightEmission = 1
    riftParts.emitter.Color = ColorSequence.new(run.riftColor)
    riftParts.emitter.Size = NumberSequence.new(0.6, 0)
    riftParts.emitter.Speed = NumberRange.new(6, 10)
    riftParts.emitter.SpreadAngle = Vector2.new(180, 180)
    riftParts.emitter.Lifetime = NumberRange.new(0.5, 0.9)
    riftParts.emitter.Drag = 3
    riftParts.emitter.Parent = sparkAttachment
    return riftParts
end
-- RiftArrival: light trail on the actor's root, enabled during the fall.
local function createFallTrail(run, actor)
    local trailTop, trailBottom = Instance.new("Attachment"), Instance.new("Attachment")
    trailTop.Position, trailBottom.Position = Vector3.new(0, 1.1, 0), Vector3.new(0, -1.1, 0)
    trailTop.Parent, trailBottom.Parent = actor.root, actor.root
    local trail = Instance.new("Trail")
    trail.Attachment0, trail.Attachment1 = trailTop, trailBottom
    trail.Lifetime = 0.35
    trail.LightEmission = 1
    trail.Color = ColorSequence.new(run.riftColor)
    trail.Transparency = NumberSequence.new(0.15, 1)
    trail.Enabled = false
    trail.Parent = actor.root
    return trail
end
-- RiftArrival: per-frame crack / disc / light animation, open + close cues; destroys the parts at 8.4.
local function animateRift(run, t, riftPos)
    local riftParts, camPos = run.rift, run.camCF.Position
    local toCam = unitOrDefault(camPos - riftPos, Vector3.zAxis)
    local faceCF = CFrame.lookAt(riftPos, camPos)
    riftParts.crack.Size = Vector3.new(0.35, max(0.05, 22 * ease(segment(t, 0.3, 1.4))), 0.35)
    riftParts.crack.CFrame = faceCF * CFrame.Angles(0, 0, 0.35)
    riftParts.crack.Transparency = t < 0.3 and 1 or segment(t, 1.6, 2.0)
    if t >= 0.3 and once(run, "riftOpen") then
        playSound(run, "RiftOpen")
    end
    local openAmount = easeOut(segment(t, 1.4, 2.3)) * (1 - ease(segment(t, 7.6, 8.2)))
    local flare = 1 + 0.6 * (ease(segment(t, 7.55, 7.75)) - ease(segment(t, 7.75, 8.1)))
    local spin = t * 1.6
    local function disc(discPart, diameter, depth)
        discPart.Size = Vector3.new(discPart.Size.X, max(0.05, diameter), max(0.05, diameter))
        discPart.CFrame = CFrame.new(riftPos - toCam * depth)
            * faceCF.Rotation
            * CFrame.Angles(0, pi / 2, 0)
            * CFrame.Angles(spin, 0, 0)
        discPart.Transparency = diameter < 0.1 and 1 or 0
    end
    disc(riftParts.core, 15 * openAmount * flare, 0)
    disc(riftParts.ring, 21 * openAmount, 0.25)
    disc(riftParts.shimmer, 26 * openAmount, 0.5)
    if openAmount > 0.01 then
        riftParts.shimmer.Transparency = 0.35
    end
    riftParts.light.Brightness = 4 * openAmount + 6 * (flare - 1)
    riftParts.emitter.Rate = openAmount > 0.2 and 25 * Config.EffectDensity or 0
    if t >= 7.6 and once(run, "riftClose") then
        playSound(run, "RiftClose")
        flash(run, riftPos, run.riftColor, 8, 0.5, 60)
    end
    if t >= 8.4 and once(run, "riftGone") then
        for _, riftPart in { riftParts.crack, riftParts.core, riftParts.ring, riftParts.shimmer } do
            riftPart:Destroy()
        end
    end
end
-- RiftArrival. 0.3 crack appears | 1.4-2.3 rift discs open | 2.6-4.2 fall from the rift to Land (trail)
-- | 4.2 land (dust, shake) | 5.4 stand up | 6.2-8.4 look left / right | 7.6 rift closes with a flash
-- | 8.4 rift parts destroyed. Camera: opening wide push-in -> fall follow -> landing shot -> pan to the rift.
scene("RiftArrival", 9, function(run)
    local actor = run.A
    run.landPos = stand(run, markerPos(run, "Land"))
    run.fwd = unitOrDefault(flatten(run.M.Land.CFrame.LookVector), Vector3.new(0, 0, -1))
    actor.yaw = yawOf(run.fwd) or 0
    actor.pos = markerPos(run, "Rift")
    actor.visible = false
    setPose(run, actor, "fall", 0)
    run.rift = createRiftParts(run)
    run.trail = createFallTrail(run, actor)
    local backDir, sideDir = -run.fwd, run.fwd:Cross(UP)
    run.openCF = run.M.OpeningCam and run.M.OpeningCam.CFrame
        or CFrame.lookAt(
            run.landPos + backDir * 70 + sideDir * 20 + UP * 50,
            run.landPos:Lerp(markerPos(run, "Rift"), 0.35)
        )
    camCut(run, run.openCF)
    run.fov = 60
    run.music = playSound(run, "Music", { volume = 0.6 })
end, function(run, t, dt)
    local actor = run.A
    local riftPos = markerPos(run, "Rift")
    if not run.cues.riftGone then
        animateRift(run, t, riftPos)
    end
    if t < 2.6 then
        actor.pos = riftPos
    elseif t < 4.2 then
        if once(run, "drop") then
            actor.visible = true
            run.trail.Enabled = true
            playSound(run, "Whoosh")
        end
        local k = segment(t, 2.6, 4.2)
        local flatPos = riftPos:Lerp(run.landPos, ease(k))
        actor.pos = Vector3.new(flatPos.X, lerp(riftPos.Y, run.landPos.Y, easeIn(k)), flatPos.Z)
    else
        actor.pos = run.landPos
        if once(run, "land") then
            run.trail.Enabled = false
            setPose(run, actor, "land", 0.06)
            dust(run, run.landPos, 14)
            shake(run, 1, 0.32)
            playSound(run, "Land")
        end
    end
    if t >= 5.4 and once(run, "standUp") then
        setPose(run, actor, "idle", 0.6)
    end
    if t >= 6.2 and once(run, "lookAround") then
        setPose(run, actor, "look", 0.3)
    end
    if t >= 6.2 then
        actor.P.look = 0.9 * ease(segment(t, 6.3, 6.8))
            - 1.8 * ease(segment(t, 7.0, 7.6))
            + 0.9 * ease(segment(t, 7.9, 8.4))
    end
    local forward, sideDir = run.fwd, run.fwd:Cross(UP)
    local torsoPos = actor.pos + UP * 2
    local landShot = CFrame.lookAt(run.landPos + forward * 8 + sideDir * 5 + UP * 2.8, run.landPos + UP * 3.6)
    if t < 2.6 then
        camFollow(run, run.openCF * CFrame.new(0, 0, -6 * ease(segment(t, 0, 2.6))), 3, dt)
    elseif t < 3.7 then
        local k = segment(t, 2.6, 4.2)
        camFollow(
            run,
            CFrame.lookAt(torsoPos - forward * (24 - 12 * k) + UP * (9 - 5 * k) + sideDir * 4 * k, torsoPos),
            9,
            dt
        )
    elseif t < 7.2 then
        camFollow(run, landShot, 6, dt)
    else
        local lookBack = ease(segment(t, 7.2, 7.7)) - ease(segment(t, 8.2, 8.8))
        camFollow(run, CFrame.lookAt(landShot.Position, (run.landPos + UP * 3.4):Lerp(riftPos, 0.4 * lookBack)), 6, dt)
    end
end)

-- SpotEgg. The egg starts drifting EggStart -> EggEnd (the drift spans SpotEgg + 94% of Chase).
-- 0.4-2.4 glance, then turn to the egg | 2.6-4.6 egg close-up (glint at 3.3) | 4.6 excited | 6.1 ready.
scene("SpotEgg", 7, function(run)
    local egg = run.egg
    egg.m.Parent = run.FX
    egg.mode = "river"
    egg.t0 = run.now
    egg.travel = run.durOf.SpotEgg + run.durOf.Chase * (9.4 / 10)
    run.yaw0 = run.A.yaw
    setPose(run, run.A, "look", 0.3)
    local baseCF = actorBaseCF(run)
    camCut(
        run,
        CFrame.lookAt((baseCF * CFrame.new(1.8, 3.4, 5.2)).Position, (baseCF * CFrame.new(0, 3.0, -12)).Position)
    )
    run.fov = 58
end, function(run, t, dt)
    local actor = run.A
    local eggPos = eggCenter(run)
    local yawToEgg = yawOf(eggPos - actor.pos) or actor.yaw
    local relativeYaw = clamp(wrapAngle(yawToEgg - run.yaw0), -1.1, 1.1)
    local turn = ease(segment(t, 1.2, 2.4))
    actor.yaw = lerpAngle(run.yaw0, yawToEgg, turn)
    if t < 4.6 then
        actor.P.look = relativeYaw * ease(segment(t, 0.4, 1.1)) * (1 - turn)
    end
    if t >= 4.6 and once(run, "excited") then
        setPose(run, actor, "excited", 0.2)
    end
    if t >= 6.1 and once(run, "ready") then
        setPose(run, actor, "ready", 0.3)
    end
    local baseCF = actorBaseCF(run)
    if t < 2.6 then
        camFollow(
            run,
            CFrame.lookAt(
                (baseCF * CFrame.new(1.8, 3.4, 5.2)).Position,
                (baseCF * CFrame.new(0, 3.0, -12)).Position:Lerp(eggPos, ease(segment(t, 1.0, 2.4)))
            ),
            8,
            dt
        )
    elseif t < 4.6 then
        local awayDir = unitOrDefault(flatten(actor.pos - eggPos), Vector3.zAxis)
        local sideDir = awayDir:Cross(UP)
        run.noSafe = true
        local shot = CFrame.lookAt(eggPos + awayDir * 7 + sideDir * 1.5 + UP * 1.6, eggPos)
        if once(run, "eggClose") then
            camCut(run, shot)
            run.fov = 45
        end
        camFollow(run, shot, 10, dt)
        if t >= 3.3 and once(run, "glint") then
            sparks(run, eggPos + UP * run.egg.h * 0.3 + sideDir * run.egg.h * 0.2, Color3.new(1, 1, 1), 3)
            flash(run, eggPos + UP, Color3.fromRGB(255, 244, 210), 3, 0.35, 8)
            playSound(run, "Glint")
        end
    else
        local shot =
            CFrame.lookAt((baseCF * CFrame.new(1.6, 3.2, -6.5)).Position, (baseCF * CFrame.new(0, 3.2, 0)).Position)
        if once(run, "react") then
            camCut(run, shot)
            run.fov = 55
        end
        camFollow(run, shot, 8, dt)
    end
end)

-- Chase. 0-3.8 run route chase1 | 3.8-4.4 trip (impact at 4.32) | 4.4-5.2 down | 5.2-6.0 recover
-- | 6.0-6.4 glance at the egg | 6.4-9.0 run route chase2 | 9.0 reach, 9.4 grab (egg -> pick), 9.55 carry.
scene("Chase", 10, function(run)
    run.A.P.gait = 1
    run.q1 = polyline(withStart(run, run.routes.chase1))
    setPose(run, run.A, "run", 0.25)
    startLoop(run, "Footsteps")
    local baseCF = actorBaseCF(run)
    camCut(run, CFrame.lookAt((baseCF * CFrame.new(6, 3.2, 1)).Position, (baseCF * CFrame.new(0, 3.0, -4)).Position))
    run.fov = 60
end, function(run, t, dt)
    local actor = run.A
    if t < 3.8 then
        walkAlong(run, run.q1, accelCurve(segment(t, 0, 3.8)), dt)
    elseif t < 4.4 then
        if once(run, "trip") then
            setPose(run, actor, "stumble", 0.08)
            stopLoop(run, "Footsteps")
            run.trip0 = actor.pos
        end
        actor.pos = stand(run, run.trip0 + forwardFromYaw(actor.yaw) * 1.4 * easeOut(segment(t, 3.8, 4.4)))
        actor.P.k = easeIn(segment(t, 3.8, 4.33))
        if t >= 4.32 and once(run, "hit") then
            dust(run, actor.pos + forwardFromYaw(actor.yaw) * 1.8, 10)
            shake(run, 0.55, 0.25)
            playSound(run, "Stumble")
        end
    elseif t < 5.2 then
        actor.P.k = 1
    elseif t < 6.0 then
        if once(run, "recover") then
            setPose(run, actor, "recover", 0.15)
        end
        actor.P.k = 1 - ease(segment(t, 5.2, 6.0))
    elseif t < 6.4 then
        if once(run, "glance") then
            setPose(run, actor, "look", 0.15)
        end
        actor.P.look = clamp(wrapAngle((yawOf(eggCenter(run) - actor.pos) or actor.yaw) - actor.yaw), -1, 1)
            * sin(pi * segment(t, 6.0, 6.4))
    elseif t < 9.0 then
        if once(run, "run2") then
            setPose(run, actor, "run", 0.15)
            startLoop(run, "Footsteps")
            run.q2 = polyline(withStart(run, run.routes.chase2))
        end
        walkAlong(run, run.q2, accelCurve(segment(t, 6.4, 9.0)), dt)
    else
        if once(run, "reach") then
            setPose(run, actor, "grab", 0.12)
            stopLoop(run, "Footsteps")
        end
        local targetYaw = yawOf(eggCenter(run) - actor.pos)
        if targetYaw then
            actor.yaw = lerpAngle(actor.yaw, targetYaw, 1 - math.exp(-14 * dt))
        end
        actor.P.k = ease(segment(t, 9.0, 9.35))
        if t >= 9.4 and once(run, "grab") then
            run.egg.mode = "pick"
            run.egg.pick0 = run.egg.cf
            run.egg.pickT = run.now
            playSound(run, "Grab")
        end
        if t >= 9.55 and once(run, "carry") then
            setPose(run, actor, "carry", 0.25)
        end
    end
    local baseCF = actorBaseCF(run)
    local torsoPos = actor.pos + UP * 1.8
    if t < 2.4 then
        camFollow(
            run,
            CFrame.lookAt((baseCF * CFrame.new(6, 3.2, 1)).Position, (baseCF * CFrame.new(0, 3.0, -4)).Position),
            8,
            dt
        )
    elseif t < 3.8 then
        camFollow(run, CFrame.lookAt((baseCF * CFrame.new(2.5, 3.4, -9)).Position, torsoPos + UP * 1.2), 4, dt)
    elseif t < 6.4 then
        camLook(run, torsoPos - UP * 0.6 * actor.P.k, 6, dt)
    elseif t < 9.0 then
        camFollow(
            run,
            CFrame.lookAt((baseCF * CFrame.new(6, 3.4, 0.5)).Position, (baseCF * CFrame.new(0, 3.0, -4)).Position),
            5,
            dt
        )
    else
        local shot = CFrame.lookAt((baseCF * CFrame.new(2.6, 2.4, -3.8)).Position, eggCenter(run):Lerp(torsoPos, 0.3))
        if once(run, "grabCam") then
            camCut(run, shot)
            run.fov = 50
        end
        camFollow(run, shot, 8, dt)
    end
end)

-- BringHome. 0-5.2 carry along home1 (to the temple entrance) | 5.2-8.6 slower walk-in along home2
-- | 6.4-7.9 incubator doors open | 8.6 arrive and face the socket. Camera: follow -> entrance side shot
-- (4.2-6.2) -> dolly into the incubator shot.
scene("BringHome", 9, function(run)
    run.A.P.moving = true
    run.A.P.gait = 1
    run.h1, run.h2 = polyline(withStart(run, run.routes.home1)), polyline(run.routes.home2)
    setPose(run, run.A, "carry", 0.2)
    startLoop(run, "Footsteps")
    local baseCF = actorBaseCF(run)
    camCut(run, CFrame.lookAt((baseCF * CFrame.new(0, 4.2, 10)).Position, (baseCF * CFrame.new(0, 2, -6)).Position))
    run.fov = 60
end, function(run, t, dt)
    local actor = run.A
    if t < 5.2 then
        walkAlong(run, run.h1, accelCurve(segment(t, 0, 5.2)), dt)
    elseif t < 8.6 then
        if once(run, "walkIn") then
            actor.P.gait = 0.6
        end
        walkAlong(run, run.h2, decelCurve(segment(t, 5.2, 8.6)), dt)
    else
        if once(run, "arrive") then
            actor.P.moving = false
            stopLoop(run, "Footsteps")
        end
        local targetYaw = yawOf(run.socket.Position - actor.pos)
        if targetYaw then
            actor.yaw = lerpAngle(actor.yaw, targetYaw, 1 - math.exp(-10 * dt))
        end
    end
    setDoors(run, ease(segment(t, 6.4, 7.9)))
    local baseCF = actorBaseCF(run)
    local torsoPos = actor.pos + UP * 1.8
    if t < 4.2 then
        camFollow(
            run,
            CFrame.lookAt((baseCF * CFrame.new(0, 4.2, 10)).Position, (baseCF * CFrame.new(0, 2, -6)).Position),
            6,
            dt
        )
    elseif t < 6.2 then
        if once(run, "sideShot") then
            camCut(run, CFrame.lookAt((run.entCF * CFrame.new(8, 3.5, 4)).Position, torsoPos))
        end
        camLook(run, torsoPos, 7, dt)
    else
        local k = ease(segment(t, 6.6, 9.0))
        camFollow(
            run,
            CFrame.lookAt(
                (baseCF * CFrame.new(0, 5, 11)).Position:Lerp(run.incShot.Position, k),
                torsoPos:Lerp(run.socket.Position + UP * 1.6, k)
            ),
            5,
            dt
        )
    end
end)

-- Egg wobble keys for the Hatch scene: { start time, duration, amplitude (radians) }.
local EGG_ROCK_KEYS = {
    { 1.35, 0.24, 0.07 },
    { 1.75, 0.24, 0.09 },
    { 2.12, 0.22, 0.11 },
    { 2.42, 0.2, 0.13 },
    { 2.68, 0.18, 0.15 },
    { 2.88, 0.16, 0.17 },
    { 3.02, 0.13, 0.26 },
    { 3.17, 0.13, 0.28 },
}
-- Hatch: sum the EGG_ROCK_KEYS wobbles active at t into the socketed egg's tilt (egg.rx / egg.rz).
local function applyEggWobble(egg, t)
    local rz, rx = 0, 0
    for _, rock in EGG_ROCK_KEYS do
        local k = (t - rock[1]) / rock[2]
        if k >= 0 and k <= 1 then
            local envelope = sin(k * pi)
            rz += rock[3] * envelope * sin(k * pi * 4)
            rx += rock[3] * 0.35 * envelope * sin(k * pi * 4 + 1.2)
        end
    end
    egg.rz, egg.rx = rz, rx
end
-- Hatch 3.8: the egg vanishes in a burst (sparks, puff, shock ring, flash) and the reward appears in
-- the socket at 55% scale; updateRewardPop then scales it up.
local function revealReward(run, egg, reward)
    egg.m.Parent = nil
    egg.mode = "gone"
    local center = run.socket.Position + UP * egg.h * 0.5
    sparks(run, center, Config.RevealColor, 26)
    emitAt(run, center, {
        color = Color3.new(1, 1, 1),
        count = 6,
        speed = 5,
        life = 0.5,
        size0 = 1.5,
        size1 = 4,
        tr0 = 0.4,
        spread = 180,
        accel = Vector3.zero,
    })
    shockRing(run, run.socket.Position + UP * 0.2, Config.RevealColor, 12, 0.45)
    flash(run, center, Config.RevealColor, 9, 0.7, 24)
    playSound(run, "Reveal")
    shake(run, 0.45, 0.3)
    run.mlight.Brightness = 0
    reward.m.Parent = run.FX
    reward.mode = "socket"
    setScale(reward, 0.55)
    reward.popT = run.now
end
-- Hatch: reward pop-in scale 0.55 -> 1.08 -> 1 over 0.33 s.
local function updateRewardPop(run, reward)
    local k = run.now - reward.popT
    setScale(
        reward,
        k < 0.18 and lerp(0.55, 1.08, easeOut(k / 0.18)) or k < 0.33 and lerp(1.08, 1, ease((k - 0.18) / 0.15)) or 1
    )
    if k >= 0.33 then
        reward.popT = nil
    end
end
-- Hatch: lift the reward from the socket into the actor's hands over 0.5 s (scaling to RewardCarryScale).
local function updateRewardLift(run, reward)
    local k = clamp((run.now - reward.liftT) / 0.5, 0, 1)
    setScale(reward, lerp(1, Config.RewardCarryScale, ease(k)))
    reward.cf = reward.from:Lerp(carriedCF(run, reward), ease(k))
    if k >= 1 then
        reward.mode = "carried"
        reward.liftT = nil
    end
end
-- Hatch. 0.3-0.55 slam the egg into the socket | 0.7-1.3 doors close | 1.3-3.3 machine hum, pulsing light,
-- egg wobble (spark pulses 1.6 / 2.3 / 2.9, vibration 2.95) | 3.3 doors open | 3.8 reveal: egg vanishes,
-- reward pops in | 4.0-6.0 hero close-up | 6.2 reach, 7.0 lift reward, 7.4 carry, 7.6+ turn to the place
-- route.
scene("Hatch", 9, function(run)
    setPose(run, run.A, "push", 0.15)
    run.A.P.k = 0
    run.fov = 55
    run.mlight = Instance.new("PointLight")
    run.mlight.Color = Config.MachineColor
    run.mlight.Range = 12
    run.mlight.Brightness = 0
    run.mlight.Shadows = false
    run.mlight.Parent =
        makePart(run, { Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(run.socket.Position + UP * 3) })
end, function(run, t, dt)
    local actor, egg, reward = run.A, run.egg, run.reward
    if t < 0.9 then
        actor.P.k = ease(segment(t, 0.3, 0.55))
    end
    if t >= 0.3 and t < 0.55 then
        if once(run, "slamStart") then
            egg.mode = "manual"
            egg.from = egg.cf
        end
        egg.cf = egg.from:Lerp(
            CFrame.new(run.socket.Position) * CFrame.Angles(0, run.socketYaw, 0),
            easeIn(segment(t, 0.3, 0.55))
        )
    end
    if t >= 0.55 and once(run, "socketed") then
        egg.mode = "socket"
        egg.rx, egg.rz = 0, 0
        sparks(run, run.socket.Position + UP * 0.3, Config.MachineColor, 14)
        shake(run, 0.7, 0.25)
        playSound(run, "Slam")
        run.mlight.Brightness = 4
    end
    if t >= 0.7 and t < 3.3 then
        setDoors(run, 1 - ease(segment(t, 0.7, 1.3)))
    elseif t >= 3.3 then
        setDoors(run, ease(segment(t, 3.3, 3.75)))
    end
    if t >= 0.9 and once(run, "settle") then
        setPose(run, actor, "idle", 0.35)
    end
    if t >= 1.8 and once(run, "lean") then
        setPose(run, actor, "lean", 0.5)
    end
    if t >= 1.3 and once(run, "hum") then
        startLoop(run, "Hum", 0.7)
    end
    if t >= 3.3 and once(run, "pause") then
        stopLoop(run, "Hum")
    end
    local ramp = segment(t, 1.3, 3.3)
    if t >= 0.55 and t < 3.3 then
        run.mlight.Brightness = lerp(
            run.mlight.Brightness,
            1.2 + 2.2 * ramp * (0.5 + 0.5 * sin(t * (8 + 10 * ramp))),
            1 - math.exp(-12 * dt)
        )
    elseif t >= 3.3 and t < 3.8 then
        run.mlight.Brightness = lerp(run.mlight.Brightness, 0.3, 1 - math.exp(-10 * dt))
    end
    if egg.mode == "socket" then
        applyEggWobble(egg, t)
    end
    if (t >= 1.6 and once(run, "p1")) or (t >= 2.3 and once(run, "p2")) or (t >= 2.9 and once(run, "p3")) then
        sparks(run, run.socket.Position + UP * egg.h * 0.5, Config.MachineColor, 3)
    end
    if t >= 2.95 and once(run, "vib") then
        shake(run, 0.18, 0.5)
    end
    if t >= 3.8 and once(run, "reveal") then
        revealReward(run, egg, reward)
    end
    if reward.popT then
        updateRewardPop(run, reward)
    end
    if t >= 6.2 and once(run, "reachReward") then
        setPose(run, actor, "grab", 0.2)
    end
    if t >= 6.2 and t < 7.4 then
        actor.P.k = ease(segment(t, 6.2, 6.8))
    end
    if t >= 7.0 and once(run, "lift") then
        reward.mode = "manual"
        reward.from = reward.cf
        reward.liftT = run.now
        playSound(run, "Grab")
    end
    if reward.liftT then
        updateRewardLift(run, reward)
    end
    if t >= 7.4 and once(run, "carry2") then
        setPose(run, actor, "carry", 0.3)
    end
    if t >= 7.6 then
        local targetYaw = yawOf((run.routes.place[2] or markerPos(run, "SlotFront")) - actor.pos)
        if targetYaw then
            actor.yaw = lerpAngle(actor.yaw, targetYaw, 1 - math.exp(-6 * dt))
        end
    end
    if t < 4.0 then
        camFollow(run, run.incShot * CFrame.new(0, 0, -1.2 * ease(segment(t, 1.3, 3.8))), 8, dt)
    elseif t < 6.0 then
        run.noSafe = true
        local center = run.socket.Position + UP * reward.h * 0.55
        local shot = CFrame.lookAt(center + run.incFront * 6.5 + UP * 0.4, center + UP * reward.h * 0.1)
        if once(run, "hero") then
            camCut(run, shot)
            run.fov = 42
        end
        camFollow(run, shot * CFrame.new(0, 0, -1.2 * ease(segment(t, 4.0, 6.0))), 6, dt)
    else
        if once(run, "medium") then
            camCut(run, run.incShot)
            run.fov = 55
        end
        camFollow(run, run.incShot, 6, dt)
    end
end)

-- Place 4.3: glowing disc + light under the placed reward (lives in run.FX until cleanup).
local function spawnSlotGlow(run)
    local glowDisc = makePart(run, {
        Shape = Enum.PartType.Cylinder,
        Material = Enum.Material.Neon,
        Color = Config.RevealColor,
        Size = Vector3.new(0.08, 4, 4),
        CFrame = CFrame.new(run.slotTop + UP * 0.04) * CFrame.Angles(0, 0, pi / 2),
        Transparency = 1,
    })
    TweenService:Create(glowDisc, TweenInfo.new(0.6), { Transparency = 0.45 }):Play()
    local glowLight = Instance.new("PointLight")
    glowLight.Color = Config.RevealColor
    glowLight.Range = 8
    glowLight.Brightness = 1.4
    glowLight.Shadows = false
    glowLight.Parent = glowDisc
end
-- Place. 0-3.4 walk to SlotFront | 3.5-4.9 place pose, 4.3 reward snaps onto the slot (glow disc)
-- | 4.6-5.4 step back | 5.5 celebrate | 7.2 music fades. Camera: follow -> placeShot (3.4) -> finalCF
-- (5.0-7.0). The outro title is layered on in section 12.
scene("Place", 9, function(run)
    run.path = polyline(withStart(run, run.routes.place))
    run.A.P.moving = true
    run.A.P.gait = 0.6
    setPose(run, run.A, "carry", 0.2)
    startLoop(run, "Footsteps", 0.6)
    local baseCF = actorBaseCF(run)
    camCut(run, CFrame.lookAt((baseCF * CFrame.new(4, 4.2, 9)).Position, (baseCF * CFrame.new(0, 2, -5)).Position))
    run.fov = 60
end, function(run, t, dt)
    local actor, reward = run.A, run.reward
    if t < 3.4 then
        walkAlong(run, run.path, ease(segment(t, 0, 3.4)), dt)
    else
        if once(run, "stopP") then
            actor.P.moving = false
            stopLoop(run, "Footsteps")
        end
        if t < 4.6 then
            local targetYaw = yawOf(markerPos(run, "Slot") - actor.pos)
            if targetYaw then
                actor.yaw = lerpAngle(actor.yaw, targetYaw, 1 - math.exp(-10 * dt))
            end
        end
    end
    if t >= 3.5 and once(run, "placePose") then
        setPose(run, actor, "place", 0.15)
    end
    if t >= 3.5 and t < 4.9 then
        actor.P.k = ease(segment(t, 3.5, 4.2)) * (1 - ease(segment(t, 4.4, 4.9)))
    end
    if t >= 4.3 and once(run, "placed") then
        reward.mode = "slot"
        setScale(reward, Config.SlotScale)
        reward.spin = run.slotYaw
        sparks(run, run.slotTop + UP, Config.RevealColor, 10)
        flash(run, run.slotTop + UP, Config.RevealColor, 3, 0.5, 12)
        playSound(run, "Place")
        spawnSlotGlow(run)
    end
    if reward.mode == "slot" then
        reward.spin += dt * 0.6
    end
    if t >= 4.6 and once(run, "stepBack") then
        setPose(run, actor, "walk", 0.3)
        run.sb0 = actor.pos
    end
    if t >= 4.6 and t < 5.5 then
        local newPos = stand(run, run.sb0 - forwardFromYaw(actor.yaw) * 3 * ease(segment(t, 4.6, 5.4)))
        actor.P.phase -= flatten(newPos - actor.pos).Magnitude * 1.8
        actor.pos = newPos
    end
    if t >= 5.5 and once(run, "celebrate") then
        setPose(run, actor, "celebrate", 0.25)
        playSound(run, "Cheer")
    end
    if t >= 7.2 and once(run, "musicOut") and run.music then
        TweenService:Create(run.music, TweenInfo.new(1.8), { Volume = 0 }):Play()
    end
    local baseCF = actorBaseCF(run)
    if t < 3.4 then
        camFollow(
            run,
            CFrame.lookAt((baseCF * CFrame.new(4, 4.2, 9)).Position, (baseCF * CFrame.new(0, 2, -5)).Position),
            5,
            dt
        )
    elseif t < 5.0 then
        if once(run, "placeCam") then
            camCut(run, run.placeShot)
            run.fov = 55
        end
        camFollow(run, run.placeShot, 6, dt)
    else
        camFollow(run, run.placeShot:Lerp(run.finalCF, ease(segment(t, 5.0, 7.0))), 8, dt)
    end
end)

-- ===== 12. Title card, Intro scene and scene-list wiring =====
-- intro: drone flyover of the map, letterbox bars and a title card, then flash into the rift
local function titleGui(run)
    if run.title then
        return run.title
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "TrailerTitle"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999
    local function makeBar(posY, anchorY)
        local frame = Instance.new("Frame")
        frame.BorderSizePixel = 0
        frame.BackgroundColor3 = Color3.new(0, 0, 0)
        frame.AnchorPoint = Vector2.new(0, anchorY)
        frame.Position = UDim2.fromScale(0, posY)
        frame.Size = UDim2.fromScale(1, 0)
        frame.Parent = gui
        return frame
    end
    local topBar, bottomBar = makeBar(0, 0), makeBar(1, 1)
    local flashFrame = Instance.new("Frame")
    flashFrame.BorderSizePixel = 0
    flashFrame.BackgroundColor3 = Color3.fromRGB(255, 244, 214)
    flashFrame.Size = UDim2.fromScale(1, 1)
    flashFrame.BackgroundTransparency = 1
    flashFrame.Parent = gui
    local function makeLabel(text, heightScale, posY, font)
        local textLabel = Instance.new("TextLabel")
        textLabel.BackgroundTransparency = 1
        textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
        textLabel.Position = UDim2.fromScale(0.5, posY)
        textLabel.Size = UDim2.fromScale(0.9, heightScale)
        textLabel.TextScaled = true
        textLabel.Font = font or Enum.Font.FredokaOne
        textLabel.Text = text
        textLabel.TextColor3 = Color3.new(1, 1, 1)
        textLabel.TextTransparency = 1
        textLabel.Parent = gui
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 3
        stroke.Color = Color3.fromRGB(60, 25, 10)
        stroke.Transparency = 1
        stroke.Parent = textLabel
        return textLabel, stroke
    end
    local titleLabel, titleStroke = makeLabel(Config.TitleText or "HATCH AN ANIME", 0.16, 0.45)
    local titleGradient = Instance.new("UIGradient")
    titleGradient.Rotation = 90
    titleGradient.Color = ColorSequence.new(Color3.fromRGB(255, 240, 170), Color3.fromRGB(255, 160, 60))
    titleGradient.Parent = titleLabel
    local taglineLabel, taglineStroke =
        makeLabel(Config.TaglineText or "Catch it. Hatch it. Collect them all.", 0.055, 0.58, Enum.Font.GothamBold)
    local outroLabel, outroStroke = makeLabel(Config.OutroText or "PLAY NOW ON ROBLOX", 0.09, 0.82)
    local outroGradient = titleGradient:Clone()
    outroGradient.Parent = outroLabel
    gui.Parent = player:WaitForChild("PlayerGui")
    run.title = {
        g = gui,
        top = topBar,
        bot = bottomBar,
        flash = flashFrame,
        t1 = titleLabel,
        s1 = titleStroke,
        t2 = taglineLabel,
        s2 = taglineStroke,
        t3 = outroLabel,
        s3 = outroStroke,
    }
    table.insert(run.restore, function()
        gui:Destroy()
    end)
    return run.title
end
local function setLetterbox(title, amount)
    title.top.Size = UDim2.fromScale(1, 0.11 * amount)
    title.bot.Size = UDim2.fromScale(1, 0.11 * amount)
end
local function fadeText(label, stroke, alpha)
    label.TextTransparency = 1 - alpha
    stroke.Transparency = 1 - alpha
end

-- Intro. Drone CFrame introA -> introB over 7 s | 0-1 letterbox in | 1.0-2.0 title | 2.0-2.8 tagline
-- | 5.0-5.8 both fade | 6.3-6.85 white flash (cut to RiftArrival).
scene("Intro", 7, function(run)
    local _title = titleGui(run)
    local landPos = markerPos(run, "Land")
    local forward = unitOrDefault(flatten(run.M.Land.CFrame.LookVector), Vector3.new(0, 0, -1))
    local sideDir = forward:Cross(UP)
    local focus = markerPos(run, "EggStart"):Lerp(markerPos(run, "EggEnd"), 0.5)
    run.introA = CFrame.lookAt(landPos - forward * 150 + sideDir * 90 + UP * 95, focus)
    run.introB = CFrame.lookAt(landPos - forward * 55 - sideDir * 35 + UP * 38, focus + UP * 8)
    camCut(run, run.introA)
    run.fov = 50
    run.A.visible = false
end, function(run, t, dt)
    local title = run.title
    local k = ease(segment(t, 0, 7))
    local droneCF = run.introA:Lerp(run.introB, k)
    camFollow(run, droneCF * CFrame.Angles(0, 0, 0.04 * sin(t * 0.6)), 4, dt)
    run.fov = 50 - 6 * k
    setLetterbox(title, ease(segment(t, 0, 1)))
    fadeText(title.t1, title.s1, ease(segment(t, 1.0, 2.0)) * (1 - ease(segment(t, 5.0, 5.8))))
    title.t1.Size = UDim2.fromScale(0.8 + 0.1 * k, 0.15 + 0.02 * k)
    fadeText(title.t2, title.s2, ease(segment(t, 2.0, 2.8)) * (1 - ease(segment(t, 5.0, 5.8))))
    title.flash.BackgroundTransparency = 1 - 0.9 * (ease(segment(t, 6.3, 6.8)) * (1 - ease(segment(t, 6.85, 7.0))))
    if t >= 6.85 and once(run, "introOut") then
        title.flash.BackgroundTransparency = 1
    end
end)
-- outro title on the final hold, bars stay for the whole video
-- Runs once at load: wrap Place (outro title), wrap every other non-Intro scene (bars at full),
-- then move Intro to the front of SCENES.
local placeScene
for _, sceneDef in SCENES do
    if sceneDef.name == "Place" then
        placeScene = sceneDef
    end
end
local placeUpdate = placeScene.update
placeScene.update = function(run, t, dt)
    placeUpdate(run, t, dt)
    local title = run.title
    if not title then
        return
    end
    setLetterbox(title, 1)
    fadeText(title.t1, title.s1, ease(segment(t, 6.6, 7.3)))
    fadeText(title.t3, title.s3, ease(segment(t, 7.0, 7.7)))
end
for _, sceneDef in SCENES do
    if sceneDef.name ~= "Intro" and sceneDef.name ~= "Place" then
        local baseUpdate = sceneDef.update
        sceneDef.update = function(run, t, dt)
            baseUpdate(run, t, dt)
            if run.title then
                setLetterbox(run.title, 1)
            end
        end
    end
end
for i, sceneDef in SCENES do
    if sceneDef.name == "Intro" then
        table.remove(SCENES, i)
        table.insert(SCENES, 1, sceneDef)
        break
    end
end

-- ===== 13. Recording mode =====
-- CoreGui (except All), topbar, TextChatService chat windows / bubbles and the mouse icon.
local function hideCoreUi(remember)
    for _, coreGuiType in Enum.CoreGuiType:GetEnumItems() do
        if coreGuiType ~= Enum.CoreGuiType.All then
            local ok, enabled = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, coreGuiType)
            if ok and enabled then
                pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreGuiType, false)
                remember(function()
                    pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreGuiType, true)
                end)
            end
        end
    end
    local okTopbar, topbarEnabled = pcall(StarterGui.GetCore, StarterGui, "TopbarEnabled")
    if okTopbar and topbarEnabled ~= false then
        pcall(StarterGui.SetCore, StarterGui, "TopbarEnabled", false)
        remember(function()
            pcall(StarterGui.SetCore, StarterGui, "TopbarEnabled", true)
        end)
    end
    for _, configName in { "ChatWindowConfiguration", "ChatInputBarConfiguration", "BubbleChatConfiguration" } do
        local chatConfig = TextChatService:FindFirstChild(configName)
        if chatConfig and chatConfig.Enabled then
            chatConfig.Enabled = false
            remember(function()
                chatConfig.Enabled = true
            end)
        end
    end
    if UserInputService.MouseIconEnabled then
        UserInputService.MouseIconEnabled = false
        remember(function()
            UserInputService.MouseIconEnabled = true
        end)
    end
end
-- Every enabled LayerCollector in PlayerGui / workspace (except the status toast and title card; SurfaceGuis
-- only with Config.HideSurfaceGuis) plus nameplates, prompts and highlights; also catches later additions.
local function hideGuisAndPrompts(run, remember)
    local function addGui(gui)
        if gui == statusGui or gui.Name == "TrailerTitle" or not gui:IsA("LayerCollector") or run.offSet[gui] then
            return
        end
        if gui:IsA("SurfaceGui") and not Config.HideSurfaceGuis then
            return
        end
        if gui.Enabled then
            run.offSet[gui] = true
            table.insert(run.off, gui)
            gui.Enabled = false
        end
    end
    for _, root in { player:WaitForChild("PlayerGui"), workspace } do
        for _, desc in root:GetDescendants() do
            addGui(desc)
            if desc:IsA("Humanoid") and desc.DisplayDistanceType ~= Enum.HumanoidDisplayDistanceType.None then
                local oldDistanceType = desc.DisplayDistanceType
                desc.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                remember(function()
                    if desc.Parent then
                        desc.DisplayDistanceType = oldDistanceType
                    end
                end)
            elseif desc:IsA("ProximityPrompt") and desc.Enabled then
                -- Same body as the Highlight branch below (selene if_same_then_else, pre-existing; left as-is).
                desc.Enabled = false
                remember(function()
                    if desc.Parent then
                        desc.Enabled = true
                    end
                end)
            elseif desc:IsA("Highlight") and desc.Enabled then
                desc.Enabled = false
                remember(function()
                    if desc.Parent then
                        desc.Enabled = true
                    end
                end)
            end
        end
        table.insert(
            run.conns,
            root.DescendantAdded:Connect(function(desc)
                task.defer(function()
                    if activeRun == run and desc.Parent then
                        addGui(desc)
                        if desc:IsA("ProximityPrompt") then
                            -- Prompts added mid-take are disabled without a restore callback (they stay off).
                            desc.Enabled = false
                        end
                    end
                end)
            end)
        )
    end
end
-- Queue every player character (and Config.HideTags instances) for per-frame hiding, now and on spawn.
local function hideCharacters(run)
    local function hideModel(model)
        for _, desc in model:GetDescendants() do
            if desc:IsA("BasePart") or desc:IsA("Decal") then
                table.insert(run.hidden, desc)
            end
        end
    end
    for _, plr in Players:GetPlayers() do
        if plr.Character then
            hideModel(plr.Character)
        end
    end
    table.insert(
        run.conns,
        Players.PlayerAdded:Connect(function(newPlayer)
            -- Not stored in run.conns: survives cleanup (guarded by the activeRun check).
            newPlayer.CharacterAdded:Connect(function(character)
                if activeRun == run then
                    task.wait()
                    hideModel(character)
                end
            end)
        end)
    )
    for _, otherPlayer in Players:GetPlayers() do
        if otherPlayer ~= player then
            table.insert(
                run.conns,
                otherPlayer.CharacterAdded:Connect(function(character)
                    if activeRun == run then
                        task.wait()
                        hideModel(character)
                    end
                end)
            )
        end
    end
    for _, tag in Config.HideTags do
        for _, tagged in CollectionService:GetTagged(tag) do
            hideModel(tagged)
        end
        table.insert(
            run.conns,
            CollectionService:GetInstanceAddedSignal(tag):Connect(function(tagged)
                if activeRun == run then
                    task.wait()
                    hideModel(tagged)
                end
            end)
        )
    end
end
-- Disable the default PlayerModule movement controls (if the module loads).
local function disablePlayerControls(remember)
    local playerModule = player:FindFirstChild("PlayerScripts") and player.PlayerScripts:FindFirstChild("PlayerModule")
    if playerModule then
        local ok, controls = pcall(function()
            return require(playerModule):GetControls()
        end)
        if ok and controls then
            controls:Disable()
            remember(function()
                controls:Enable()
            end)
        end
    end
end
-- Optional trailer colour grade (colour correction, bloom, sun rays, depth of field) and a fixed ClockTime.
local function applyColorGrade(run, remember)
    if Config.ColorGrade then
        local colorGrade = Instance.new("ColorCorrectionEffect")
        colorGrade.Name = "TrailerGrade"
        colorGrade.Saturation = 0.22
        colorGrade.Contrast = 0.12
        colorGrade.Brightness = 0.02
        colorGrade.TintColor = Color3.fromRGB(255, 248, 238)
        colorGrade.Parent = Lighting
        local bloom = Instance.new("BloomEffect")
        bloom.Name = "TrailerBloom"
        bloom.Intensity = 0.7
        bloom.Size = 28
        bloom.Threshold = 0.9
        bloom.Parent = Lighting
        local sunRays = Instance.new("SunRaysEffect")
        sunRays.Name = "TrailerRays"
        sunRays.Intensity = 0.06
        sunRays.Spread = 0.6
        sunRays.Parent = Lighting
        local dof = Instance.new("DepthOfFieldEffect")
        dof.Name = "TrailerDOF"
        dof.FarIntensity = 0.35
        dof.FocusDistance = 14
        dof.InFocusRadius = 18
        dof.NearIntensity = 0
        dof.Parent = Lighting
        run.dof = dof
        if Config.ClockTime then
            local oldClockTime = Lighting.ClockTime
            run.clock = Config.ClockTime
            remember(function()
                run.clock = nil
                Lighting.ClockTime = oldClockTime
            end)
        end
        remember(function()
            colorGrade:Destroy()
            bloom:Destroy()
            sunRays:Destroy()
            dof:Destroy()
        end)
    end
end
-- Scriptable camera; the original type / subject / FOV come back on cleanup.
local function takeOverCamera(remember)
    local camera = workspace.CurrentCamera
    local oldCameraType, oldCameraSubject, oldFieldOfView = camera.CameraType, camera.CameraSubject, camera.FieldOfView
    camera.CameraType = Enum.CameraType.Scriptable
    remember(function()
        camera.CameraType = oldCameraType
        camera.CameraSubject = oldCameraSubject
        camera.FieldOfView = oldFieldOfView
    end)
end
-- Hide CoreGui / topbar / chat / mouse, every enabled LayerCollector, nameplates, prompts and highlights,
-- all player characters and Config.HideTags instances; disable controls, add the colour grade and take
-- the camera. Each change pushes an undo callback onto run.restore (run.off / run.hidden are re-applied
-- every frame and undone by cleanup).
local function hideForRecording(run)
    local function remember(restoreFn)
        table.insert(run.restore, restoreFn)
    end
    hideCoreUi(remember)
    hideGuisAndPrompts(run, remember)
    hideCharacters(run)
    disablePlayerControls(remember)
    applyColorGrade(run, remember)
    takeOverCamera(remember)
end

-- ===== 14. Cleanup =====
-- Idempotent. Restores doors, GUIs and hidden parts, runs run.restore in reverse order, destroys actor + FX.
local function cleanup(run, message)
    if run.cleaned then
        return
    end
    run.cleaned = true
    pcall(RunService.UnbindFromRenderStep, RunService, "TrailerCinematic")
    for _, conn in run.conns do
        conn:Disconnect()
    end
    if run.doors then
        for _, door in run.doors do
            if door.obj.Parent then
                setPivot(door.obj, door.closed)
            end
        end
    end
    for _, gui in run.off do
        if gui.Parent then
            gui.Enabled = true
        end
    end
    for _, hiddenPart in run.hidden do
        if hiddenPart.Parent then
            hiddenPart.LocalTransparencyModifier = 0
        end
    end
    for i = #run.restore, 1, -1 do
        pcall(run.restore[i])
    end
    if run.A then
        run.A.model:Destroy()
    end
    if run.FX then
        run.FX:Destroy()
    end
    if activeRun == run then
        activeRun = nil
    end
    if message then
        showStatus(message, 4)
    end
end

-- ===== 15. Per-frame update (RenderStep) =====
-- Keep the actor visible: pull the camera in front of the first obstacle between it and the actor's torso
-- (not during Intro, not while run.noSafe, not while the actor is hidden).
local function pullCameraClear(run, camCF)
    if run.scene and run.scene > 1 and not run.noSafe and run.A.visible then
        local focus = run.A.pos + UP * 2
        local toCamera = camCF.Position - focus
        if toCamera.Magnitude > 1 then
            local hit = workspace:Raycast(focus, toCamera, run.ray)
            if hit then
                camCF = CFrame.new(hit.Position - toCamera.Unit * 0.6) * camCF.Rotation
            end
        end
    end
    return camCF
end
-- Sum the live shake impulses (quadratic fall-off, Perlin noise); expired ones are removed.
local function sumShakes(run)
    local shakeX, shakeY, shakeRoll = 0, 0, 0
    for i = #run.shakes, 1, -1 do
        local shakeEntry = run.shakes[i]
        local age = (run.now - shakeEntry.t0) / shakeEntry.dur
        if age >= 1 then
            table.remove(run.shakes, i)
        else
            local strength = (1 - age) ^ 2 * shakeEntry.amp
            shakeX += math.noise(shakeEntry.seed, run.now * 25) * strength
            shakeY += math.noise(shakeEntry.seed + 5, run.now * 25) * strength
            shakeRoll += math.noise(shakeEntry.seed + 9, run.now * 20) * strength
        end
    end
    return shakeX, shakeY, shakeRoll
end
-- Picks the scene for run.now (calls its start on entry), applies actor and props, keeps things hidden,
-- then builds the final camera: shake + collision pull-in (skipped when run.noSafe) + handheld noise.
local function updateFrame(run, dt)
    dt = math.min(dt, 1 / 20) -- frame hitches must not make the smoothing / phase steps jump
    run.now = os.clock() - run.t0
    local sceneStart = 0
    for i, sceneDef in SCENES do
        if run.now < sceneStart + sceneDef.dur or i == #SCENES then
            if run.scene ~= i then
                run.scene = i
                run.cues = {}
                sceneDef.start(run)
            end
            local timeScale = sceneDef.base / sceneDef.dur
            sceneDef.update(run, (run.now - sceneStart) * timeScale, dt * timeScale)
            break
        end
        sceneStart += sceneDef.dur
    end
    actorApply(run)
    propApply(run, run.egg)
    propApply(run, run.reward)
    for _, gui in run.off do
        if gui.Enabled then
            gui.Enabled = false
        end
    end
    for _, hiddenPart in run.hidden do
        hiddenPart.LocalTransparencyModifier = 1
    end
    local shakeX, shakeY, shakeRoll = sumShakes(run)
    local camCF = pullCameraClear(run, run.camCF)
    run.noSafe = false
    local camera = workspace.CurrentCamera
    camera.CameraType = Enum.CameraType.Scriptable
    local handheld = CFrame.new(math.noise(run.now * 0.35, 1) * 0.12, math.noise(run.now * 0.35, 7) * 0.1, 0)
        * CFrame.Angles(0, 0, math.noise(run.now * 0.3, 13) * 0.006)
    camera.CFrame = camCF
        * handheld
        * CFrame.new(shakeX * 0.25, shakeY * 0.25, 0)
        * CFrame.Angles(0, 0, shakeRoll * 0.03)
    camera.FieldOfView = lerp(camera.FieldOfView, run.fov or 60, 1 - math.exp(-6 * dt))
    if run.clock then
        Lighting.ClockTime = run.clock
    end
    if run.dof then
        run.dof.FocusDistance =
            lerp(run.dof.FocusDistance, (camCF.Position - (run.A.pos + UP * 2)).Magnitude, 1 - math.exp(-8 * dt))
    end
    if run.now >= run.total + 0.25 then
        cleanup(run, "Trailer finished")
    end
end

-- ===== 16. Plot, incubator and slot discovery =====
local REQUIRED_MARKERS =
    { "Rift", "Land", "EggStart", "EggEnd", "Stumble", "Grab", "IncubatorFront", "SlotFront", "Slot" }
local function nameMatch(name, patterns)
    name = name:lower()
    for _, pattern in patterns do
        if name:find(pattern:lower(), 1, true) then
            return true
        end
    end
    return false
end
-- First Model / Folder under Config.PlotsFolder owned by the local player (owner attribute or Owner value).
local function findMyPlot()
    local searchRoot = resolvePath(Config.PlotsFolder) or workspace
    for _, candidate in searchRoot:GetDescendants() do
        if (candidate:IsA("Model") or candidate:IsA("Folder")) and not candidate:FindFirstChildOfClass("Humanoid") then
            for _, attrName in Config.PlotOwnerAttributes do
                local value = candidate:GetAttribute(attrName)
                if
                    value ~= nil
                    and (value == player.UserId or tostring(value) == tostring(player.UserId) or value == player.Name)
                then
                    return candidate
                end
            end
            local ownerValue = candidate:FindFirstChild("Owner")
            if
                ownerValue
                and (
                    (ownerValue:IsA("ObjectValue") and ownerValue.Value == player)
                    or ((ownerValue:IsA("IntValue") or ownerValue:IsA("NumberValue")) and ownerValue.Value == player.UserId)
                    or (ownerValue:IsA("StringValue") and ownerValue.Value == player.Name)
                )
            then
                return candidate
            end
        end
    end
end
local function slotFree(slot)
    if slot:GetAttribute("Occupied") == true then
        return false
    end
    local characterId = slot:GetAttribute("CharacterId")
    if characterId ~= nil and characterId ~= "" and characterId ~= 0 then
        return false
    end
    for _, desc in slot:GetDescendants() do
        if desc:IsA("Humanoid") then
            return false
        end
    end
    return true
end
-- Ground point 2.5 studs in front of the incubator (front = towards the glass doors, else -LookVector).
local function incubatorFront(incubator)
    local boxCF, boxSize = incubator:GetBoundingBox()
    local glassLeft, glassRight =
        incubator:FindFirstChild("GlassLeft", true), incubator:FindFirstChild("GlassRight", true)
    local frontDir
    if glassLeft and glassRight then
        frontDir = flatten((pivotOf(glassLeft).Position + pivotOf(glassRight).Position) / 2 - boxCF.Position)
    end
    if not frontDir or frontDir.Magnitude < 0.5 then
        frontDir = flatten(-incubator:GetPivot().LookVector)
    end
    frontDir = unitOrDefault(frontDir, Vector3.zAxis)
    local extent = abs(frontDir:Dot(boxCF.RightVector)) * boxSize.X / 2
        + abs(frontDir:Dot(boxCF.LookVector)) * boxSize.Z / 2
    return Vector3.new(boxCF.Position.X, boxCF.Position.Y - boxSize.Y / 2, boxCF.Position.Z) + frontDir * (extent + 2.5)
end
local function virtualMarker(position, lookTarget)
    return {
        Position = position,
        CFrame = lookTarget and CFrame.lookAt(position, lookTarget) or CFrame.new(position),
        Size = Vector3.one,
    }
end

-- ===== 17. Take setup (prepare) =====
-- Fill run.M from the markers folder, moved from Config.MarkerPlot onto the player's own plot (via the two
-- plots' TempleAnchor parts) when both exist.
local function loadMarkers(run, markersFolder, myPlot)
    -- markers were placed around Config.MarkerPlot; they move with you to the plot you own
    local markerPlot, plotTransform = resolvePath(Config.MarkerPlot), CFrame.identity
    if
        myPlot
        and markerPlot
        and myPlot ~= markerPlot
        and myPlot:FindFirstChild("TempleAnchor")
        and markerPlot:FindFirstChild("TempleAnchor")
    then
        plotTransform = myPlot.TempleAnchor.CFrame * markerPlot.TempleAnchor.CFrame:Inverse()
    end
    if markersFolder then
        for _, markerPart in markersFolder:GetChildren() do
            if markerPart:IsA("BasePart") then
                local markerCF = plotTransform * markerPart.CFrame
                run.M[markerPart.Name] = { CFrame = markerCF, Position = markerCF.Position, Size = markerPart.Size }
            end
        end
    end
end
-- First incubator model in the player's plot (outermost name match), else Config.Models.Incubator.
local function findIncubator(myPlot)
    local incubator
    if myPlot then
        for _, desc in myPlot:GetDescendants() do
            if
                desc:IsA("Model")
                and nameMatch(desc.Name, Config.IncubatorNames)
                and not nameMatch(desc.Parent.Name, Config.IncubatorNames)
            then
                incubator = desc
                break
            end
        end
    end
    return incubator or resolvePath(Config.Models.Incubator)
end
-- Markers the folder did not provide, derived from the scene: IncubatorFront from the incubator, and from
-- the player's plot the nearest free slot (+ SlotFront) and the temple entrance.
local function addDerivedMarkers(run, myPlot, incubator)
    if incubator and not run.M.IncubatorFront then
        run.M.IncubatorFront = virtualMarker(incubatorFront(incubator))
    end
    if myPlot then
        local plotCenter = myPlot:IsA("Model") and myPlot:GetBoundingBox().Position
            or (incubator and incubator:GetPivot().Position)
            or Vector3.zero
        if not run.M.Slot then
            local searchOrigin, bestSlot, bestDist = incubator and incubator:GetPivot().Position or plotCenter, nil, nil
            for _, desc in myPlot:GetDescendants() do
                if
                    (desc:IsA("BasePart") or desc:IsA("Model"))
                    and nameMatch(desc.Name, Config.SlotNames)
                    and not nameMatch(desc.Parent.Name, Config.SlotNames)
                    and slotFree(desc)
                then
                    local dist = (pivotOf(desc).Position - searchOrigin).Magnitude
                    if not bestDist or dist < bestDist then
                        bestSlot, bestDist = desc, dist
                    end
                end
            end
            if bestSlot then
                local slotCF, slotSize
                if bestSlot:IsA("Model") then
                    slotCF, slotSize = bestSlot:GetBoundingBox()
                else
                    slotCF, slotSize = bestSlot.CFrame, bestSlot.Size
                end
                run.M.Slot = { Position = slotCF.Position, CFrame = slotCF, Size = slotSize }
                if not run.M.SlotFront then
                    local frontDir = unitOrDefault(flatten(plotCenter - slotCF.Position), Vector3.zAxis)
                    run.M.SlotFront = virtualMarker(
                        slotCF.Position + frontDir * (max(slotSize.X, slotSize.Z) / 2 + 2.5),
                        slotCF.Position
                    )
                end
            end
        end
        if not run.M.TempleEntrance then
            for _, desc in myPlot:GetDescendants() do
                if (desc:IsA("BasePart") or desc:IsA("Model")) and nameMatch(desc.Name, Config.EntranceNames) then
                    local entrancePos = pivotOf(desc).Position
                    run.M.TempleEntrance =
                        virtualMarker(entrancePos, Vector3.new(plotCenter.X, entrancePos.Y, plotCenter.Z))
                    break
                end
            end
        end
    end
end
-- error() (level 0, message shown to the owner) listing every missing marker / model.
local function assertSetupComplete(run, missing, eggSrc, rewardSrc, incubator)
    for _, markerName in REQUIRED_MARKERS do
        if not run.M[markerName] then
            table.insert(
                missing,
                (markerName == "Slot" or markerName == "SlotFront" or markerName == "IncubatorFront")
                        and (markerName .. " (no free slot/incubator found in your plot, and no marker)")
                    or ("marker " .. markerName)
            )
        end
    end
    if not eggSrc then
        table.insert(missing, "PirateEgg model")
    end
    if not rewardSrc then
        table.insert(missing, "Reward model")
    end
    if not incubator then
        table.insert(missing, "Incubator (none in your plot and Config path not found)")
    end
    if #missing > 0 then
        error("Missing: " .. table.concat(missing, ", "), 0)
    end
end
-- Local avatar clone (from the HumanoidDescription, else the live character) turned into an inert puppet:
-- anchored root, Motor6D joints the procedural poses drive, optional animation tracks. Parented to run.FX.
local function buildActor(run)
    local model
    pcall(function()
        model = Players:CreateHumanoidModelFromDescription(
            Players:GetHumanoidDescriptionFromUserId(player.UserId),
            Enum.HumanoidRigType.R15
        )
    end)
    if not model and player.Character then
        player.Character.Archivable = true
        model = player.Character:Clone()
    end
    if not model then
        error("Couldn't build your avatar", 0)
    end
    for _, desc in model:GetDescendants() do
        if desc:IsA("BaseScript") or desc:IsA("Tool") or desc:IsA("BillboardGui") or desc:IsA("ForceField") then
            desc:Destroy()
        elseif desc:IsA("BasePart") then
            desc.CanCollide, desc.CanQuery, desc.CanTouch = false, false, false
        end
    end
    model.Name = "TrailerActor"
    local hum = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")
    if not (hum and root) then
        error("Avatar model has no Humanoid/HumanoidRootPart", 0)
    end
    hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
    hum.PlatformStand = true
    root.Anchored = true
    model.Parent = run.FX
    local actor = {
        model = model,
        hum = hum,
        root = root,
        joints = {},
        tracks = {},
        parts = {},
        P = { look = 0, k = 0, phase = 0, moving = false },
        pose = "idle",
        blend0 = 0,
        blendDur = 0,
        visible = false,
        pos = root.Position,
        yaw = 0,
        handsLocal = Vector3.new(0, 0.3, -1.4),
    }
    -- new avatar joints (AnimationConstraint + BallSocket) -> rigid Motor6Ds the poses can drive
    for _, constraint in model:GetDescendants() do
        if constraint:IsA("AnimationConstraint") and constraint.Attachment0 and constraint.Attachment1 then
            local motor = Instance.new("Motor6D")
            motor.Name = constraint.Name
            motor.Part0, motor.Part1 = constraint.Attachment0.Parent, constraint.Attachment1.Parent
            motor.C0, motor.C1 = constraint.Attachment0.CFrame, constraint.Attachment1.CFrame
            motor.Parent = constraint.Parent
            constraint:Destroy()
        elseif constraint:IsA("BallSocketConstraint") or constraint:IsA("HingeConstraint") then
            constraint:Destroy()
        end
    end
    for key, jointName in JOINT_NAMES do
        local joint = model:FindFirstChild(jointName, true)
        if joint and joint:IsA("Motor6D") then
            actor.joints[key] = joint
        end
    end
    actor.c0 = {}
    for key, joint in actor.joints do
        actor.c0[key] = joint.C0
    end
    if hum.RigType == Enum.HumanoidRigType.R15 then
        actor.offset = hum.HipHeight + root.Size.Y / 2
    else
        local boxCF, boxSize = model:GetBoundingBox()
        actor.offset = root.Position.Y - (boxCF.Position.Y - boxSize.Y / 2)
    end
    -- Instance.new(class, parent) is deprecated (selene); kept as-is.
    local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
    for animName, animId in Config.Animations do
        if animId ~= "" then
            local animation = Instance.new("Animation")
            animation.AnimationId = animId
            local ok, track = pcall(animator.LoadAnimation, animator, animation)
            if ok then
                actor.tracks[animName:lower()] = track
            end
        end
    end
    for _, desc in model:GetDescendants() do
        if desc:IsA("BasePart") or desc:IsA("Decal") then
            table.insert(actor.parts, desc)
        end
    end
    return actor, model
end
-- Floor point of the incubator's egg socket: EggAnchor (Attachment / BasePart / Model), else the top of
-- EggPlatform, else a fixed offset from the incubator pivot.
local function findEggSocket(incubator)
    local anchor = incubator:FindFirstChild("EggAnchor", true)
    if anchor and anchor:IsA("Attachment") then
        return CFrame.new(anchor.WorldPosition)
    elseif anchor and anchor:IsA("BasePart") then
        return CFrame.new(anchor.Position - UP * anchor.Size.Y / 2)
    elseif anchor and anchor:IsA("Model") then
        local anchorCF, anchorSize = anchor:GetBoundingBox()
        return CFrame.new(anchorCF.Position - UP * anchorSize.Y / 2)
    else
        local platform = incubator:FindFirstChild("EggPlatform", true)
        if platform then
            local platformCF, platformSize =
                platform:IsA("Model") and platform:GetBoundingBox() or platform.CFrame,
                platform:IsA("Model") and select(2, platform:GetBoundingBox()) or platform.Size
            return CFrame.new(platformCF.Position + UP * platformSize.Y / 2)
        else
            return CFrame.new((incubator:GetPivot() * CFrame.new(0, 2.25, 1.5)).Position)
        end
    end
end
-- Fixed camera shots derived from the socket and the slot (IncubatorCam / FinalCam markers win).
local function computeShots(run)
    run.incFront = unitOrDefault(flatten(markerPos(run, "IncubatorFront") - run.socket.Position), Vector3.zAxis)
    run.socketYaw = (yawOf(run.incFront) or 0) + math.rad(Config.RewardYawOffset)
    local incSide = run.incFront:Cross(UP)
    run.incShot = run.M.IncubatorCam and run.M.IncubatorCam.CFrame
        or CFrame.lookAt(
            run.socket.Position + run.incFront * 11 + incSide * 4 + UP * 3.5,
            run.socket.Position + UP * 1.6
        )
    local slot = run.M.Slot
    run.slotTop = slot.Position + UP * (slot.Size.Y / 2 + Config.SlotLift)
    local slotFrontPos = markerPos(run, "SlotFront")
    run.slotYaw = (yawOf(slotFrontPos - slot.Position) or 0) + math.rad(Config.RewardYawOffset)
    local slotDir = unitOrDefault(flatten(slot.Position - slotFrontPos), Vector3.new(0, 0, -1))
    local slotSide = slotDir:Cross(UP)
    local midPoint = slotFrontPos:Lerp(slot.Position, 0.5)
    run.placeShot = CFrame.lookAt(midPoint + slotSide * 7.5 - slotDir * 1.5 + UP * 3, midPoint + UP * 2)
    run.finalCF = run.M.FinalCam and run.M.FinalCam.CFrame
        or CFrame.lookAt(
            slot.Position - slotDir * 20 + slotSide * 8 + UP * 11,
            slot.Position:Lerp(slotFrontPos, 0.4) + UP * 2.5
        )
end
-- Pathfinding routes for every walking leg (yields): chase1 / chase2, home1 / home2 (split at the temple
-- entrance, or at 65% of one route when there is none), place (via optional SlotPath1..3 markers).
local function planRoutes(run)
    showStatus("Planning routes…")
    local landPos, stumblePos, grabPos =
        stand(run, markerPos(run, "Land")), stand(run, markerPos(run, "Stumble")), stand(run, markerPos(run, "Grab"))
    local incubatorFrontPos, slotFrontStand =
        stand(run, markerPos(run, "IncubatorFront")), stand(run, markerPos(run, "SlotFront"))
    run.routes = { chase1 = route(run, landPos, stumblePos), chase2 = route(run, stumblePos, grabPos) }
    if run.M.TempleEntrance then
        local entrancePos = stand(run, markerPos(run, "TempleEntrance"))
        run.routes.home1, run.routes.home2 =
            route(run, grabPos, entrancePos), route(run, entrancePos, incubatorFrontPos)
        run.entCF = run.M.TempleEntrance.CFrame
    else
        local fullRoute = route(run, grabPos, incubatorFrontPos)
        local splitIndex = math.max(2, math.floor(#fullRoute * 0.65))
        run.routes.home1 = { table.unpack(fullRoute, 1, splitIndex) }
        run.routes.home2 = { table.unpack(fullRoute, splitIndex, #fullRoute) }
        if #run.routes.home2 < 2 then
            table.insert(run.routes.home2, incubatorFrontPos)
        end
        run.entCF = CFrame.lookAt(
            fullRoute[splitIndex],
            fullRoute[splitIndex] + unitOrDefault(flatten(incubatorFrontPos - fullRoute[splitIndex]), Vector3.zAxis)
        )
    end
    local placeWaypoints = { incubatorFrontPos }
    for i = 1, 3 do
        local pathMarker = run.M["SlotPath" .. i]
        if pathMarker then
            table.insert(placeWaypoints, stand(run, pathMarker.Position))
        end
    end
    table.insert(placeWaypoints, slotFrontStand)
    run.routes.place = { incubatorFrontPos }
    for i = 1, #placeWaypoints - 1 do
        local legPoints = route(run, placeWaypoints[i], placeWaypoints[i + 1])
        for j = 2, #legPoints do
            table.insert(run.routes.place, legPoints[j])
        end
    end
end
-- Preload the actor, props, sounds and animations; waits at most 8 s.
local function preloadAssets(run, model)
    local preloadList = { model, run.egg.m, run.reward.m }
    for _, assetId in Config.Sounds do
        if assetId ~= "" then
            table.insert(preloadList, assetId)
        end
    end
    for _, assetId in Config.Animations do
        if assetId ~= "" then
            table.insert(preloadList, assetId)
        end
    end
    local preloadDone = false
    task.spawn(function()
        pcall(ContentProvider.PreloadAsync, ContentProvider, preloadList)
        preloadDone = true
    end)
    local waitStart = os.clock()
    while not preloadDone and os.clock() - waitStart < 8 do
        showStatus("Loading trailer assets…")
        task.wait(0.2)
    end
end
-- Countdown finished: enter recording mode, stop on death / respawn, bind the per-frame update.
local function startPlayback(run)
    statusGui.Enabled = false
    hideForRecording(run)
    local liveHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if liveHumanoid then
        table.insert(
            run.conns,
            liveHumanoid.Died:Connect(function()
                cleanup(run, "Trailer stopped (character died)")
            end)
        )
    end
    table.insert(
        run.conns,
        player.CharacterAdded:Connect(function()
            cleanup(run, "Trailer stopped (respawn)")
        end)
    )
    run.t0 = os.clock()
    run.now = 0
    RunService:BindToRenderStep("TrailerCinematic", Enum.RenderPriority.Camera.Value + 2, function(dt)
        if activeRun ~= run then
            return
        end
        local ok, err = pcall(updateFrame, run, dt)
        if not ok then
            warn("[Trailer] stopped after an error:", err)
            cleanup(run, "Trailer stopped: " .. tostring(err))
        end
    end)
end
-- Runs in its own thread and yields (Pathfinding, preload, countdown). Errors abort via start()'s pcall;
-- if the take is cancelled during the countdown it returns without binding.
local function prepare(run)
    local missing = {}
    local markersFolder = resolvePath(Config.MarkersFolder)
    run.M = {}
    local eggSrc, rewardSrc = resolvePath(Config.Models.PirateEgg), resolvePath(Config.Models.Reward)
    local myPlot = Config.AutoPlot and findMyPlot() or nil
    loadMarkers(run, markersFolder, myPlot)
    local incubator = findIncubator(myPlot)
    addDerivedMarkers(run, myPlot, incubator)
    assertSetupComplete(run, missing, eggSrc, rewardSrc, incubator)
    if myPlot then
        showStatus("Using your plot: " .. myPlot.Name, 3)
    end
    run.FX = Instance.new("Folder")
    run.FX.Name = "TrailerFX"
    run.FX.Parent = workspace
    run.riftColor = Config.RiftColor
    run.durOf = {}
    run.total = 0
    for _, sceneDef in SCENES do
        sceneDef.dur = Config.Durations[sceneDef.name] or sceneDef.base
        run.durOf[sceneDef.name] = sceneDef.dur
        run.total += sceneDef.dur
    end
    local actor, model = buildActor(run)
    run.A = actor
    run.egg = prepProp(eggSrc, Config.EggScale, Config.EggHeight)
    run.egg.mode = "hidden"
    run.reward = prepProp(rewardSrc, 1, Config.RewardHeight)
    run.reward.mode = "hidden"
    run.inc = incubator
    run.doors = {}
    for _, doorName in { "GlassLeft", "GlassRight" } do
        local door = incubator:FindFirstChild(doorName, true)
        if door then
            table.insert(run.doors, { obj = door, closed = pivotOf(door), dir = doorName == "GlassLeft" and -1 or 1 })
        end
    end
    run.socket = findEggSocket(incubator)
    run.ray = RaycastParams.new()
    run.ray.FilterType = Enum.RaycastFilterType.Exclude
    run.ray.RespectCanCollide = true
    local ignoreList = { run.FX, markersFolder }
    for _, plr in Players:GetPlayers() do
        if plr.Character then
            table.insert(ignoreList, plr.Character)
        end
    end
    run.ray.FilterDescendantsInstances = ignoreList
    do -- sit the egg / character on the visible platform surface
        local hit = workspace:Raycast(run.socket.Position + UP * 4, Vector3.new(0, -8, 0), run.ray)
        if hit and hit.Position.Y > run.socket.Position.Y then
            run.socket = CFrame.new(hit.Position)
        end
    end
    computeShots(run)
    planRoutes(run)
    preloadAssets(run, model)
    for i = Config.StartDelay, 1, -1 do
        if activeRun ~= run then
            return
        end
        showStatus("Trailer starts in " .. i .. " — start recording")
        task.wait(1)
    end
    if activeRun ~= run then
        return
    end
    startPlayback(run)
end

-- ===== 18. Public start / stop and triggers =====
local function start()
    if activeRun then
        return
    end
    local run =
        { restore = {}, conns = {}, off = {}, offSet = {}, hidden = {}, shakes = {}, loops = {}, cues = {}, now = 0 }
    activeRun = run
    task.spawn(function()
        local ok, err = pcall(prepare, run)
        if not ok then
            warn("[Trailer]", err)
            cleanup(run, tostring(err))
        end
    end)
end
local function stop()
    if activeRun then
        cleanup(activeRun, "Trailer cancelled")
    end
end

local startCommand = Instance.new("TextChatCommand")
startCommand.Name = "TrailerStart"
startCommand.PrimaryAlias = Config.Command
startCommand.Parent = TextChatService
startCommand.Triggered:Connect(function(textSource)
    if textSource.UserId == player.UserId then
        if activeRun then
            stop()
            task.wait(0.1)
        end
        if _G.TrailerPicker then
            _G.TrailerPicker()
        else
            start()
        end
    end
end)
local stopCommand = Instance.new("TextChatCommand")
stopCommand.Name = "TrailerStop"
stopCommand.PrimaryAlias = Config.StopCommand
stopCommand.Parent = TextChatService
stopCommand.Triggered:Connect(function(textSource)
    if textSource.UserId == player.UserId then
        stop()
    end
end)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Config.Key then
        if activeRun then
            stop()
        else
            start()
        end
    end
end)
player:GetAttributeChangedSignal("TrailerGo"):Connect(function()
    if player:GetAttribute("TrailerGo") then
        start()
    else
        stop()
    end
end)

_G.TrailerStartV1 = start
