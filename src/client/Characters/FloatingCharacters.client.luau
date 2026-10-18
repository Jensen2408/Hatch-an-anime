--[[ StarterPlayerScripts.FloatingCharacters  (LocalScript)
Showcase float for placed characters. No particles.
  • slow hover with a slight breathe
  • every 6.6 s: an eased 360° showcase spin with a small lift
  • a contact shadow that shrinks as the character rises
  • a thin ring that ripples out each time it reaches the bottom of its bob
Cosmetic and client-only. The server's model never moves.

Tag each placed character Model with "FloatingCharacter" (server, after placing).
Optional attributes: FloatHeight (default 0.65), FloatFacing (extra yaw in degrees).
]]
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Config = {
    Tag = "FloatingCharacter",
    Height = 0.65,
    Bob = 0.3,
    Period = 2.8,
    Cycle = 6.6,
    SpinStart = 5,
    SpinTime = 1.6,
    SpinLift = 0.55,
    SwayYaw = 8,
    SwayTilt = 0,
    MaxDistance = 140,
    Cream = Color3.fromRGB(255, 243, 207),
}

local active = {}
local pending = {}
local function easeIO(x)
    if x < 0.5 then
        return 4 * x * x * x
    end
    return 1 - ((-2 * x + 2) ^ 3) / 2
end

local function fxPart(name, size, color, shape)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
    p.Size, p.Color, p.Material = size, color, Enum.Material.SmoothPlastic
    if shape then
        p.Shape = shape
    end
    return p
end

local function add(model)
    if active[model] or pending[model] or not model:IsA("Model") then
        return
    end
    pending[model] = true
    -- Tags can arrive before the character geometry; use the podium for FX sizing.
    local plot = model.Parent and model.Parent.Parent
    local slots = plot and plot:FindFirstChild("Slots")
    local slot = slots and slots:FindFirstChild(model.Name:gsub("_Brainrot$", ""))
    local stand = slot and slot:WaitForChild("MoneyStand", 10)
    local support = stand and stand:WaitForChild("CharacterSlot", 10)
    -- Do not cache a pivot offset while replicated body parts are still arriving.
    while model:IsDescendantOf(workspace) and CollectionService:HasTag(model, Config.Tag) do
        local count = 0
        for _, part in model:GetDescendants() do
            if part:IsA("BasePart") then
                count += 1
            end
        end
        local expected = model:GetAttribute("DisplayPartCount")
        if model:GetAttribute("DisplayHome") and expected and count >= expected and count > 0 then
            break
        end
        task.wait()
    end
    pending[model] = nil
    if not model:IsDescendantOf(workspace) or not CollectionService:HasTag(model, Config.Tag) then
        return
    end
    for _, d in model:GetDescendants() do
        if d:IsA("BasePart") then
            d.Anchored = true
        end
    end
    local base = model:GetAttribute("DisplayHome") or model:GetPivot()
    -- Rebuild the center pivot from the complete geometry before the first hover.
    local bounds = model:GetBoundingBox()
    model.PrimaryPart = nil
    model.WorldPivot = CFrame.new(bounds.Position) * model:GetPivot().Rotation
    local surfaceWidth = support and math.min(support.Size.X, support.Size.Z) or 5
    local size = Vector3.new(surfaceWidth * 0.75, model:GetAttribute("DisplayHeight") or 6, surfaceWidth * 0.75)
    local groundY = (support and (support.Position.Y + support.Size.Y / 2))
        or model:GetAttribute("SlotSurfaceY")
        or (base.Position.Y - size.Y / 2)
    local ground = Vector3.new(base.Position.X, groundY, base.Position.Z)
    local folder = Instance.new("Folder")
    folder.Name = "FloatFX"
    folder.Parent = workspace
    local shadow =
        fxPart("Shadow", Vector3.new(0.05, size.X, size.X), Color3.fromRGB(30, 20, 12), Enum.PartType.Cylinder)
    shadow.CFrame = CFrame.new(ground + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, 0, math.rad(90))
    shadow.Transparency = 0.7
    shadow.Parent = folder
    local owner = Instance.new("ObjectValue")
    owner.Name = "Character"
    owner.Value = model
    owner.Parent = folder
    local ring = fxPart("Ring", Vector3.new(1, 0.05, 1), Config.Cream)
    ring.Transparency = 1
    ring.CFrame = CFrame.new(ground + Vector3.new(0, 0.03, 0))
    ring.Parent = folder
    local sel = Instance.new("SelectionBox")
    sel.Adornee, sel.Color3, sel.LineThickness, sel.SurfaceTransparency, sel.Transparency =
        ring, Config.Cream, 0.06, 1, 1
    sel.Parent = ring
    active[model] = {
        base = base,
        size = size,
        ground = ground,
        shadow = shadow,
        ring = ring,
        sel = sel,
        folder = folder,
        seed = 0,
        lastLow = -10,
    }
end

local function remove(model)
    local s = active[model]
    if not s then
        return
    end
    active[model] = nil
    s.folder:Destroy()
    if model.Parent then
        model:PivotTo(s.base)
    end
end

for _, m in CollectionService:GetTagged(Config.Tag) do
    task.spawn(add, m)
end
CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(add)
CollectionService:GetInstanceRemovedSignal(Config.Tag):Connect(remove)

RunService.RenderStepped:Connect(function()
    local cam = workspace.CurrentCamera
    local camPos = cam and cam.CFrame.Position or Vector3.zero
    local now = workspace:GetServerTimeNow()
    for model, s in active do
        if not model.Parent then
            remove(model)
            continue
        end
        if (s.base.Position - camPos).Magnitude > Config.MaxDistance then
            continue
        end
        local t = now + s.seed
        local h = model:GetAttribute("FloatHeight") or Config.Height
        local yaw = math.rad(model:GetAttribute("FloatFacing") or 0) + (t % 10) / 10 * math.pi * 2
        model:PivotTo(s.base * CFrame.new(0, h, 0) * CFrame.Angles(0, yaw, 0))
        local k = math.clamp((h - 0.85) / 1.15, 0, 1)
        local d = s.size.X * (1 - 0.25 * k)
        s.shadow.Size = Vector3.new(0.05, d, d)
        s.shadow.Transparency = 0.7 + 0.2 * k
        local phase = (t / Config.Period) % 1
        if phase > 0.74 and phase < 0.8 and t - s.lastLow > 1 then
            s.lastLow = t
        end
        local r = math.min(1, (t - s.lastLow) / 1.1)
        local w = s.size.X * (1.1 + r * 1.1)
        s.ring.Size = Vector3.new(w, 0.05, w)
        s.sel.Transparency = 1 - 0.6 * (1 - r) * math.min(1, r * 8)
    end
end)
