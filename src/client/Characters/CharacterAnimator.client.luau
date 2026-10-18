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
]]
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "AnimatedCharacter"
local MAX_DIST = 120
local LIMBS = { "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
-- joint positions in character space (studs), origin = between the feet
local J = {
    Torso = Vector3.new(0, 2, 0),
    Head = Vector3.new(0, 4, 0),
    ["Left Arm"] = Vector3.new(1.5, 3.6, 0),
    ["Right Arm"] = Vector3.new(-1.5, 3.6, 0),
    ["Left Leg"] = Vector3.new(0.5, 2, 0),
    ["Right Leg"] = Vector3.new(-0.5, 2, 0),
}

local function pivotOf(x)
    return x:IsA("Model") and x:GetPivot() or x.CFrame
end
local function setPivot(x, cf)
    if x:IsA("Model") then
        x:PivotTo(cf)
    else
        x.CFrame = cf
    end
end

local function pose(t, name)
    local P = {
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
    local S = math.sin
    if name == "Idle" then
        P.by = 0.04 * S(t * 2)
        P.head = { 0.03 * S(t * 2), 0.18 * S(t * 0.5), 0 }
        P.la = { 0.03 * S(t * 2), 0, 0.05 + 0.02 * S(t * 2) }
        P.ra = { 0.03 * S(t * 2 + 0.4), 0, -0.05 - 0.02 * S(t * 2) }
    elseif name == "Hero" then
        P.by = 0.03 * S(t * 1.6)
        P.bpitch = -0.05
        P.head = { -0.08, 0.1 * S(t * 0.4), 0 }
        P.la = { 0.12, 0, 0.5 + 0.02 * S(t * 1.6) }
        P.ra = { 0.12, 0, -0.5 - 0.02 * S(t * 1.6) }
        P.ll = { 0, 0, 0.12 }
        P.rl = { 0, 0, -0.12 }
    elseif name == "Cross" then
        P.by = 0.03 * S(t * 1.8)
        P.head = { 0.04, 0.22 * S(t * 0.35), 0.04 }
        P.la = { -0.95, 0, -0.5 }
        P.ra = { -1.05, 0, 0.5 }
        P.byaw = 0.05 * S(t * 0.35)
    elseif name == "Look" then
        local c = (t % 6) / 6
        local look = c < 0.15 and 0
            or c < 0.3 and (c - 0.15) / 0.15
            or c < 0.5 and 1
            or c < 0.65 and 1 - 2 * (c - 0.5) / 0.15
            or c < 0.85 and -1
            or -1 + (c - 0.85) / 0.15
        local a = math.abs(look)
        local e = look * look * (3 - 2 * a) * (look < 0 and -1 or 1)
        P.by = 0.03 * S(t * 2)
        P.head = { 0.02, 0.7 * e, 0 }
        P.byaw = 0.12 * e
        P.la = { 0.03, 0, 0.06 }
        P.ra = { 0.03, 0, -0.06 }
    elseif name == "Point" then
        local m = t % 5
        local e = math.min(1, m / 0.4)
        local hold = m < 3.6 and e or math.max(0, 1 - (m - 3.6) / 0.5)
        P.by = 0.03 * S(t * 2)
        P.ra = { -1.5 * hold, 0.25 * hold, -0.15 }
        P.la = { 0.1, 0, 0.45 * hold + 0.05 }
        P.head = { 0, -0.2 * hold, 0 }
        P.byaw = -0.12 * hold
    elseif name == "Bow" then
        local c = (t % 3.4) / 3.4
        local b = c < 0.3 and S(c / 0.3 * math.pi / 2)
            or c < 0.55 and 1
            or c < 0.8 and math.cos((c - 0.55) / 0.25 * math.pi / 2)
            or 0
        P.bpitch = 0.55 * b
        P.by = -0.05 * b
        P.head = { 0.2 * b, 0, 0 }
        P.la = { 0.15 * b, 0, 0.04 }
        P.ra = { 0.15 * b, 0, -0.04 }
    elseif name == "Power" then
        local j = 0.012 * S(t * 41)
        P.by = -0.18 + j
        P.bpitch = 0.08
        P.head = { 0.12, 0, 0 }
        P.la = { -0.35, 0, 0.38 + j * 2 }
        P.ra = { -0.35, 0, -0.38 - j * 2 }
        P.ll = { 0, 0, 0.16 }
        P.rl = { 0, 0, -0.16 }
    elseif name == "Wave" then
        P.by = 0.03 * S(t * 2)
        P.broll = 0.04
        P.head = { 0, -0.12, 0.1 }
        P.ra = { 0, 0, -2.55 + 0.32 * S(t * 9) }
        P.la = { 0, 0, 0.08 }
    elseif name == "Walk" then
        local w = t * 6.5
        local sw = S(w)
        P.by = 0.1 * math.abs(math.cos(w))
        P.byaw = 0.06 * sw
        P.ll = { -0.6 * sw, 0, 0 }
        P.rl = { 0.6 * sw, 0, 0 }
        P.la = { 0.55 * sw, 0, 0.04 }
        P.ra = { -0.55 * sw, 0, -0.04 }
        P.head = { 0.04, -0.04 * sw, 0 }
    elseif name == "Dance" then
        local b = t * 7.5
        P.by = 0.12 * math.abs(S(b))
        P.byaw = 0.3 * S(b * 0.5)
        P.broll = 0.08 * S(b * 0.5)
        P.la = { -0.2, 0, 2.3 + 0.45 * S(b) }
        P.ra = { -0.2, 0, -2.3 + 0.45 * S(b) }
        P.ll = { -0.25 * math.max(0, S(b * 0.5)), 0, 0.05 }
        P.rl = { -0.25 * math.max(0, -S(b * 0.5)), 0, -0.05 }
        P.head = { 0.08 * S(b), 0, -0.1 * S(b * 0.5) }
    elseif name == "Victory" then
        local c = (t % 2.2) / 2.2
        local crouch, up = 0, 0
        if c < 0.2 then
            crouch = S(c / 0.2 * math.pi / 2)
        elseif c < 0.62 then
            local u = (c - 0.2) / 0.42
            up = 4 * u * (1 - u) * 1.6
            crouch = math.max(0, 1 - u * 4)
        elseif c < 0.75 then
            crouch = S((c - 0.62) / 0.13 * math.pi) * 0.6
        end
        local air = up > 0.05 and 1 or 0
        P.by = up - crouch * 0.35
        P.bpitch = crouch * 0.12
        P.ll = { -crouch * 0.5 - air * 0.25, 0, 0.05 }
        P.rl = { -crouch * 0.5 + air * 0.15, 0, -0.05 }
        P.la = { -0.3 * (air == 1 and 1 or math.min(1, crouch)), 0, 0.2 + 2.6 * (air == 1 and 1 or 0.15) }
        P.ra = { -2.9 * (air == 1 and 1 or 0.1), 0, -0.15 }
        P.head = { -0.15 * air, 0, 0 }
    end
    return P
end

local active = {}

local function add(model)
    if active[model] or not model:IsA("Model") then
        return
    end
    local rig = {}
    for _, n in LIMBS do
        rig[n] = model:FindFirstChild(n, true)
    end
    if not rig.Torso then
        warn("[CharacterAnimator] " .. model.Name .. " has no Torso group")
        return
    end
    for _, d in model:GetDescendants() do
        if d:IsA("BasePart") then
            d.Anchored = true
        end
    end
    -- character space: origin between the feet, facing the model's front
    local cf, size = model:GetBoundingBox()
    local scale = model:GetAttribute("Scale") or (size.Y / 6.2)
    local origin = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0)) * cf.Rotation
    local base, acc = {}, {}
    for _, n in LIMBS do
        if rig[n] then
            base[n] = origin:ToObjectSpace(pivotOf(rig[n]))
        end
    end
    for _, c in model:GetChildren() do
        if c.Name:match("^Acc_") then
            local accName = c.Name:gsub("_Glow$", "")
            local p = pivotOf(c).Position
            local lp = origin:PointToObjectSpace(p) / scale
            local follow = accName:find("Hat") and "Head"
                or accName:find("Book") and "Left Arm"
                or (accName:find("Katana") and lp.X < -1.2 and lp.Y < 3) and "Right Arm"
                or "Torso"
            table.insert(acc, { inst = c, follow = follow, base = origin:ToObjectSpace(pivotOf(c)) })
        end
    end
    for _, n in LIMBS do
        local g = model:FindFirstChild(n .. "_Glow", true)
        if g then
            table.insert(acc, { inst = g, follow = n, base = origin:ToObjectSpace(pivotOf(g)) })
        end
    end
    active[model] = {
        rig = rig,
        base = base,
        acc = acc,
        origin = origin,
        scale = scale,
        seed = math.random() * 10,
        offset = origin:ToObjectSpace(model:GetPivot()),
    }
end

local function reset(model, s)
    local origin = model:GetPivot() * s.offset:Inverse()
    for n, b in s.base do
        if s.rig[n] and s.rig[n].Parent then
            setPivot(s.rig[n], origin * b)
        end
    end
    for _, a in s.acc do
        if a.inst.Parent then
            setPivot(a.inst, origin * a.base)
        end
    end
end
local function remove(model)
    local s = active[model]
    if s then
        active[model] = nil
        if model.Parent then
            reset(model, s)
        end
    end
end

for _, m in CollectionService:GetTagged(TAG) do
    task.spawn(add, m)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)

local function joint(name, ang, scale)
    local j = J[name] * scale
    return CFrame.new(j) * CFrame.fromEulerAnglesYXZ(ang[1], ang[2], ang[3]) * CFrame.new(-j)
end

RunService.RenderStepped:Connect(function()
    local cam = workspace.CurrentCamera
    local camPos = cam and cam.CFrame.Position or Vector3.zero
    local now = os.clock()
    for model, s in active do
        if not model.Parent then
            active[model] = nil
            continue
        end
        local anim = model:GetAttribute("Animation") or "Idle"
        if anim == "Off" then
            if not s.wasOff then
                reset(model, s)
                s.wasOff = true
            end
            continue
        end
        s.wasOff = false
        -- FloatingCharacters may move the whole model: follow its current pivot
        local origin = model:GetPivot() * s.offset:Inverse()
        if (origin.Position - camPos).Magnitude > MAX_DIST then
            continue
        end
        local sc = s.scale
        local P = pose(now + s.seed, anim)
        local body = CFrame.new(0, P.by * sc, 0) * joint("Torso", { P.bpitch, P.byaw, P.broll }, sc)
        local lift = CFrame.new(0, math.max(0, P.by) * sc, 0)
        local W = {
            Torso = body,
            Head = body * joint("Head", P.head, sc),
            ["Left Arm"] = body * joint("Left Arm", P.la, sc),
            ["Right Arm"] = body * joint("Right Arm", P.ra, sc),
            ["Left Leg"] = lift * joint("Left Leg", P.ll, sc),
            ["Right Leg"] = lift * joint("Right Leg", P.rl, sc),
        }
        for n, b in s.base do
            local inst = s.rig[n]
            if inst and inst.Parent then
                setPivot(inst, origin * W[n] * b)
            end
        end
        for _, a in s.acc do
            if a.inst.Parent then
                setPivot(a.inst, origin * W[a.follow] * a.base)
            end
        end
    end
end)
