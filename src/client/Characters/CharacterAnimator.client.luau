--[[ StarterPlayerScripts.CharacterAnimator  (LocalScript)
Procedural R6 animations for the imported anime characters (the GLBs from the CHARACTERS page).
Same moves as the page: Idle, Wave, Walk, Dance, Victory. Cosmetic and client-only.

Setup (server):
  CollectionService:AddTag(characterModel, "AnimatedCharacter")
  characterModel:SetAttribute("Animation", "Idle")   -- Idle | Hero | Cross | Look | Point | Bow | Power | Wave | Walk | Dance | Victory | Off
The model must contain the R6 groups exported by the page: "Torso", "Head", "Left Arm", "Right Arm",
"Left Leg", "Right Leg" (Models or parts), plus optional "Acc_*" accessories.
Works alongside FloatingCharacters: this script animates the limbs, that one moves the whole model.
Import the GLB with 1 unit = 1 stud (character is 6 studs tall). Other scales are handled via the Scale attribute.
Models farther than MAX_DISTANCE from the camera are not updated.
]]
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "AnimatedCharacter"
local MAX_DISTANCE = 120
local LIMBS = { "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
-- joint positions in character space (studs), origin = between the feet
local JOINT_POSITIONS = {
    Torso = Vector3.new(0, 2, 0),
    Head = Vector3.new(0, 4, 0),
    ["Left Arm"] = Vector3.new(1.5, 3.6, 0),
    ["Right Arm"] = Vector3.new(-1.5, 3.6, 0),
    ["Left Leg"] = Vector3.new(0.5, 2, 0),
    ["Right Leg"] = Vector3.new(-0.5, 2, 0),
}

-- Limbs and accessories may be Models or BaseParts.
local function pivotOf(target)
    return target:IsA("Model") and target:GetPivot() or target.CFrame
end
local function setPivot(target, cframe)
    if target:IsA("Model") then
        target:PivotTo(cframe)
    else
        target.CFrame = cframe
    end
end

-- Pose at `poseTime` for animation `name`. Fields (radians / studs before scaling):
--   by = body Y offset, byaw/bpitch/broll = torso rotation,
--   head/la/ra/ll/rl = { x, y, z } Euler angles for head, left/right arm, left/right leg.
local function computePose(poseTime, name)
    local pose = {
        by = 0,
        byaw = 0,
        bpitch = 0,
        broll = 0,
        head = { 0, 0, 0 },
        la = { 0, 0, 0 },
        ra = { 0, 0, 0 },
        ll = { 0, 0, 0 },
        rl = { 0, 0, 0 },
    }
    local sin = math.sin
    if name == "Idle" then
        pose.by = 0.04 * sin(poseTime * 2)
        pose.head = { 0.03 * sin(poseTime * 2), 0.18 * sin(poseTime * 0.5), 0 }
        pose.la = { 0.03 * sin(poseTime * 2), 0, 0.05 + 0.02 * sin(poseTime * 2) }
        pose.ra = { 0.03 * sin(poseTime * 2 + 0.4), 0, -0.05 - 0.02 * sin(poseTime * 2) }
    elseif name == "Hero" then
        pose.by = 0.03 * sin(poseTime * 1.6)
        pose.bpitch = -0.05
        pose.head = { -0.08, 0.1 * sin(poseTime * 0.4), 0 }
        pose.la = { 0.12, 0, 0.5 + 0.02 * sin(poseTime * 1.6) }
        pose.ra = { 0.12, 0, -0.5 - 0.02 * sin(poseTime * 1.6) }
        pose.ll = { 0, 0, 0.12 }
        pose.rl = { 0, 0, -0.12 }
    elseif name == "Cross" then
        pose.by = 0.03 * sin(poseTime * 1.8)
        pose.head = { 0.04, 0.22 * sin(poseTime * 0.35), 0.04 }
        pose.la = { -0.95, 0, -0.5 }
        pose.ra = { -1.05, 0, 0.5 }
        pose.byaw = 0.05 * sin(poseTime * 0.35)
    elseif name == "Look" then
        -- 6 s cycle: hold centre, turn to one side, hold, sweep to the other side, hold, return
        local cycle = (poseTime % 6) / 6
        local look = cycle < 0.15 and 0
            or cycle < 0.3 and (cycle - 0.15) / 0.15
            or cycle < 0.5 and 1
            or cycle < 0.65 and 1 - 2 * (cycle - 0.5) / 0.15
            or cycle < 0.85 and -1
            or -1 + (cycle - 0.85) / 0.15
        local lookMagnitude = math.abs(look)
        local eased = look * look * (3 - 2 * lookMagnitude) * (look < 0 and -1 or 1) -- signed smoothstep
        pose.by = 0.03 * sin(poseTime * 2)
        pose.head = { 0.02, 0.7 * eased, 0 }
        pose.byaw = 0.12 * eased
        pose.la = { 0.03, 0, 0.06 }
        pose.ra = { 0.03, 0, -0.06 }
    elseif name == "Point" then
        local cycleTime = poseTime % 5
        local raise = math.min(1, cycleTime / 0.4)
        local hold = cycleTime < 3.6 and raise or math.max(0, 1 - (cycleTime - 3.6) / 0.5)
        pose.by = 0.03 * sin(poseTime * 2)
        pose.ra = { -1.5 * hold, 0.25 * hold, -0.15 }
        pose.la = { 0.1, 0, 0.45 * hold + 0.05 }
        pose.head = { 0, -0.2 * hold, 0 }
        pose.byaw = -0.12 * hold
    elseif name == "Bow" then
        local cycle = (poseTime % 3.4) / 3.4
        local bowAmount = cycle < 0.3 and sin(cycle / 0.3 * math.pi / 2)
            or cycle < 0.55 and 1
            or cycle < 0.8 and math.cos((cycle - 0.55) / 0.25 * math.pi / 2)
            or 0
        pose.bpitch = 0.55 * bowAmount
        pose.by = -0.05 * bowAmount
        pose.head = { 0.2 * bowAmount, 0, 0 }
        pose.la = { 0.15 * bowAmount, 0, 0.04 }
        pose.ra = { 0.15 * bowAmount, 0, -0.04 }
    elseif name == "Power" then
        local jitter = 0.012 * sin(poseTime * 41)
        pose.by = -0.18 + jitter
        pose.bpitch = 0.08
        pose.head = { 0.12, 0, 0 }
        pose.la = { -0.35, 0, 0.38 + jitter * 2 }
        pose.ra = { -0.35, 0, -0.38 - jitter * 2 }
        pose.ll = { 0, 0, 0.16 }
        pose.rl = { 0, 0, -0.16 }
    elseif name == "Wave" then
        pose.by = 0.03 * sin(poseTime * 2)
        pose.broll = 0.04
        pose.head = { 0, -0.12, 0.1 }
        pose.ra = { 0, 0, -2.55 + 0.32 * sin(poseTime * 9) }
        pose.la = { 0, 0, 0.08 }
    elseif name == "Walk" then
        local stridePhase = poseTime * 6.5
        local swing = sin(stridePhase)
        pose.by = 0.1 * math.abs(math.cos(stridePhase))
        pose.byaw = 0.06 * swing
        pose.ll = { -0.6 * swing, 0, 0 }
        pose.rl = { 0.6 * swing, 0, 0 }
        pose.la = { 0.55 * swing, 0, 0.04 }
        pose.ra = { -0.55 * swing, 0, -0.04 }
        pose.head = { 0.04, -0.04 * swing, 0 }
    elseif name == "Dance" then
        local beat = poseTime * 7.5
        pose.by = 0.12 * math.abs(sin(beat))
        pose.byaw = 0.3 * sin(beat * 0.5)
        pose.broll = 0.08 * sin(beat * 0.5)
        pose.la = { -0.2, 0, 2.3 + 0.45 * sin(beat) }
        pose.ra = { -0.2, 0, -2.3 + 0.45 * sin(beat) }
        pose.ll = { -0.25 * math.max(0, sin(beat * 0.5)), 0, 0.05 }
        pose.rl = { -0.25 * math.max(0, -sin(beat * 0.5)), 0, -0.05 }
        pose.head = { 0.08 * sin(beat), 0, -0.1 * sin(beat * 0.5) }
    elseif name == "Victory" then
        -- 2.2 s cycle: crouch, jump (parabola), landing dip, rest
        local cycle = (poseTime % 2.2) / 2.2
        local crouch, up = 0, 0
        if cycle < 0.2 then
            crouch = sin(cycle / 0.2 * math.pi / 2)
        elseif cycle < 0.62 then
            local jumpProgress = (cycle - 0.2) / 0.42
            up = 4 * jumpProgress * (1 - jumpProgress) * 1.6
            crouch = math.max(0, 1 - jumpProgress * 4)
        elseif cycle < 0.75 then
            crouch = sin((cycle - 0.62) / 0.13 * math.pi) * 0.6
        end
        local air = up > 0.05 and 1 or 0
        pose.by = up - crouch * 0.35
        pose.bpitch = crouch * 0.12
        pose.ll = { -crouch * 0.5 - air * 0.25, 0, 0.05 }
        pose.rl = { -crouch * 0.5 + air * 0.15, 0, -0.05 }
        pose.la = { -0.3 * (air == 1 and 1 or math.min(1, crouch)), 0, 0.2 + 2.6 * (air == 1 and 1 or 0.15) }
        pose.ra = { -2.9 * (air == 1 and 1 or 0.1), 0, -0.15 }
        pose.head = { -0.15 * air, 0, 0 }
    end
    return pose
end

local active = {} -- [Model] = rig state (see `add`)

local function add(model)
    if active[model] or not model:IsA("Model") then
        return
    end
    local rig = {}
    for _, limbName in LIMBS do
        rig[limbName] = model:FindFirstChild(limbName, true)
    end
    if not rig.Torso then
        warn("[CharacterAnimator] " .. model.Name .. " has no Torso group")
        return
    end
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.Anchored = true
        end
    end
    -- character space: origin between the feet, facing the model's front
    local boxCFrame, size = model:GetBoundingBox()
    local scale = model:GetAttribute("Scale") or (size.Y / 6.2)
    local origin = CFrame.new(boxCFrame.Position - Vector3.new(0, size.Y / 2, 0)) * boxCFrame.Rotation
    local basePivots, accessories = {}, {}
    for _, limbName in LIMBS do
        if rig[limbName] then
            basePivots[limbName] = origin:ToObjectSpace(pivotOf(rig[limbName]))
        end
    end
    -- accessories follow the limb they sit on (guessed from name and position)
    for _, child in model:GetChildren() do
        if child.Name:match("^Acc_") then
            local accessoryName = child.Name:gsub("_Glow$", "")
            local worldPosition = pivotOf(child).Position
            local localPosition = origin:PointToObjectSpace(worldPosition) / scale
            local follow = accessoryName:find("Hat") and "Head"
                or accessoryName:find("Book") and "Left Arm"
                or (accessoryName:find("Katana") and localPosition.X < -1.2 and localPosition.Y < 3) and "Right Arm"
                or "Torso"
            table.insert(accessories, { inst = child, follow = follow, base = origin:ToObjectSpace(pivotOf(child)) })
        end
    end
    for _, limbName in LIMBS do
        local glow = model:FindFirstChild(limbName .. "_Glow", true)
        if glow then
            table.insert(accessories, { inst = glow, follow = limbName, base = origin:ToObjectSpace(pivotOf(glow)) })
        end
    end
    active[model] = {
        rig = rig,
        base = basePivots,
        acc = accessories,
        origin = origin,
        scale = scale,
        seed = math.random() * 10,
        offset = origin:ToObjectSpace(model:GetPivot()),
    }
end

-- Put every limb and accessory back in its rest pose relative to the model's current pivot.
local function reset(model, state)
    local origin = model:GetPivot() * state.offset:Inverse()
    for limbName, basePivot in state.base do
        if state.rig[limbName] and state.rig[limbName].Parent then
            setPivot(state.rig[limbName], origin * basePivot)
        end
    end
    for _, accessory in state.acc do
        if accessory.inst.Parent then
            setPivot(accessory.inst, origin * accessory.base)
        end
    end
end
local function remove(model)
    local state = active[model]
    if state then
        active[model] = nil
        if model.Parent then
            reset(model, state)
        end
    end
end

for _, model in CollectionService:GetTagged(TAG) do
    task.spawn(add, model)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)

-- Rotation `angles` (YXZ Euler) around the named joint, in character space scaled by `scale`.
local function joint(name, angles, scale)
    local jointPosition = JOINT_POSITIONS[name] * scale
    return CFrame.new(jointPosition)
        * CFrame.fromEulerAnglesYXZ(angles[1], angles[2], angles[3])
        * CFrame.new(-jointPosition)
end

RunService.RenderStepped:Connect(function()
    local camera = workspace.CurrentCamera
    local cameraPosition = camera and camera.CFrame.Position or Vector3.zero
    local now = os.clock()
    for model, state in active do
        if not model.Parent then
            active[model] = nil
            continue
        end
        local animation = model:GetAttribute("Animation") or "Idle"
        if animation == "Off" then
            if not state.wasOff then
                reset(model, state)
                state.wasOff = true
            end
            continue
        end
        state.wasOff = false
        -- FloatingCharacters may move the whole model: follow its current pivot
        local origin = model:GetPivot() * state.offset:Inverse()
        if (origin.Position - cameraPosition).Magnitude > MAX_DISTANCE then
            continue
        end
        local scale = state.scale
        local pose = computePose(now + state.seed, animation)
        local body = CFrame.new(0, pose.by * scale, 0) * joint("Torso", { pose.bpitch, pose.byaw, pose.broll }, scale)
        local lift = CFrame.new(0, math.max(0, pose.by) * scale, 0) -- legs only follow the body upwards
        local limbOffsets = {
            Torso = body,
            Head = body * joint("Head", pose.head, scale),
            ["Left Arm"] = body * joint("Left Arm", pose.la, scale),
            ["Right Arm"] = body * joint("Right Arm", pose.ra, scale),
            ["Left Leg"] = lift * joint("Left Leg", pose.ll, scale),
            ["Right Leg"] = lift * joint("Right Leg", pose.rl, scale),
        }
        for limbName, basePivot in state.base do
            local limb = state.rig[limbName]
            if limb and limb.Parent then
                setPivot(limb, origin * limbOffsets[limbName] * basePivot)
            end
        end
        for _, accessory in state.acc do
            if accessory.inst.Parent then
                setPivot(accessory.inst, origin * limbOffsets[accessory.follow] * accessory.base)
            end
        end
    end
end)
