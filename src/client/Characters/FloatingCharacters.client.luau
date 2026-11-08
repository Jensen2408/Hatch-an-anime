--[[ StarterPlayerScripts.FloatingCharacters  (LocalScript)
Showcase float for placed characters. No particles. Cosmetic and client-only. The server's model never moves.

What the code currently does (each frame, within Config.MaxDistance of the camera):
  • holds the character at DisplayHome raised by FloatHeight (no bob)
  • turns it continuously, one full turn every 10 s (time-synced via server time)
  • a contact shadow that shrinks/fades as the float height grows
  • a thin ring that ripples out once per Config.Period
NOTE: the original design (bob, breathe, a 6.6 s eased showcase spin with a lift) is described by the
unused Config fields Bob / Cycle / SpinStart / SpinTime / SpinLift / SwayYaw / SwayTilt and `_easeInOutCubic`.

Tag each placed character Model with "FloatingCharacter" (server, after placing).
Attributes read: DisplayHome (CFrame), DisplayPartCount, DisplayHeight, SlotSurfaceY (set by BrainrotPlacement);
optional FloatHeight (default 0.65), FloatFacing (extra yaw in degrees).
FX parts live in a workspace Folder "FloatFX" with an ObjectValue "Character" pointing at the model.
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
    OutlineDistance = 220, -- black outline only within this many studs of the camera
    MaxOutlines = 24, -- Roblox draws about 31 highlights; keep room for other effects
    Cream = Color3.fromRGB(255, 243, 207),
}

local active = {} -- [Model] = float state (see end of `add`)
local pending = {} -- [Model] = true while `add` waits for geometry
local function _easeInOutCubic(x)
    if x < 0.5 then
        return 4 * x * x * x
    end
    return 1 - ((-2 * x + 2) ^ 3) / 2
end

local function fxPart(name, size, color, shape)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
    part.Size, part.Color, part.Material = size, color, Enum.Material.SmoothPlastic
    if shape then
        part.Shape = shape
    end
    return part
end

-- Yields (WaitForChild + per-frame wait for streamed parts); always started with task.spawn or a signal.
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
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.Anchored = true
        end
    end
    local home = model:GetAttribute("DisplayHome") or model:GetPivot()
    -- Rebuild the center pivot from the complete geometry before the first hover.
    local bounds = model:GetBoundingBox()
    model.PrimaryPart = nil
    model.WorldPivot = CFrame.new(bounds.Position) * model:GetPivot().Rotation
    local surfaceWidth = support and math.min(support.Size.X, support.Size.Z) or 5
    local size = Vector3.new(surfaceWidth * 0.75, model:GetAttribute("DisplayHeight") or 6, surfaceWidth * 0.75)
    local groundY = (support and (support.Position.Y + support.Size.Y / 2))
        or model:GetAttribute("SlotSurfaceY")
        or (home.Position.Y - size.Y / 2)
    local ground = Vector3.new(home.Position.X, groundY, home.Position.Z)
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
    local ringOutline = Instance.new("SelectionBox")
    ringOutline.Adornee, ringOutline.Color3, ringOutline.LineThickness, ringOutline.SurfaceTransparency, ringOutline.Transparency =
        ring, Config.Cream, 0.06, 1, 1
    ringOutline.Parent = ring
    -- black outline (house style for characters and bosses): outline only, no fill; lives in the FX folder, so it goes with it
    local outline = Instance.new("Highlight")
    outline.Name = "BlackOutline"
    outline.Adornee = model
    outline.FillTransparency = 1
    outline.OutlineColor = Color3.new(0, 0, 0)
    outline.OutlineTransparency = 0
    outline.DepthMode = Enum.HighlightDepthMode.Occluded
    outline.Enabled = false
    outline.Parent = folder
    active[model] = {
        outline = outline,
        base = home,
        size = size,
        ground = ground,
        shadow = shadow,
        ring = ring,
        sel = ringOutline,
        folder = folder,
        seed = 0,
        lastLow = -10,
    }
end

local function remove(model)
    local state = active[model]
    if not state then
        return
    end
    active[model] = nil
    state.folder:Destroy()
    if model.Parent then
        model:PivotTo(state.base)
    end
end

for _, model in CollectionService:GetTagged(Config.Tag) do
    task.spawn(add, model)
end
CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(add)
CollectionService:GetInstanceRemovedSignal(Config.Tag):Connect(remove)

RunService.RenderStepped:Connect(function()
    local camera = workspace.CurrentCamera
    local cameraPosition = camera and camera.CFrame.Position or Vector3.zero
    local now = workspace:GetServerTimeNow()
    local outlined = 0
    for model, state in active do
        if not model.Parent then
            remove(model)
            continue
        end
        local distance = (state.base.Position - cameraPosition).Magnitude
        -- Roblox only draws about 31 highlights at once: outline just the characters near the camera
        local wantOutline = distance <= Config.OutlineDistance and outlined < Config.MaxOutlines
        if wantOutline then
            outlined += 1
        end
        if state.outline.Enabled ~= wantOutline then
            state.outline.Enabled = wantOutline
        end
        if distance > Config.MaxDistance then
            continue
        end
        local floatTime = now + state.seed
        local floatHeight = model:GetAttribute("FloatHeight") or Config.Height
        local yaw = math.rad(model:GetAttribute("FloatFacing") or 0) + (floatTime % 10) / 10 * math.pi * 2
        model:PivotTo(state.base * CFrame.new(0, floatHeight, 0) * CFrame.Angles(0, yaw, 0))
        -- shadow: full size up to 0.85 studs of float, 25% smaller and fainter at 2 studs
        local riseFactor = math.clamp((floatHeight - 0.85) / 1.15, 0, 1)
        local shadowDiameter = state.size.X * (1 - 0.25 * riseFactor)
        state.shadow.Size = Vector3.new(0.05, shadowDiameter, shadowDiameter)
        state.shadow.Transparency = 0.7 + 0.2 * riseFactor
        -- ring: restarts once per Period (in the 0.74–0.8 window), expands over 1.1 s and fades
        local phase = (floatTime / Config.Period) % 1
        if phase > 0.74 and phase < 0.8 and floatTime - state.lastLow > 1 then
            state.lastLow = floatTime
        end
        local rippleProgress = math.min(1, (floatTime - state.lastLow) / 1.1)
        local ringWidth = state.size.X * (1.1 + rippleProgress * 1.1)
        state.ring.Size = Vector3.new(ringWidth, 0.05, ringWidth)
        state.sel.Transparency = 1 - 0.6 * (1 - rippleProgress) * math.min(1, rippleProgress * 8)
    end
end)

-- Black outlines on eggs too (house style: eggs, characters and bosses). Outline-only Highlights on the nearest river and incubator
-- eggs; the characters above use up to Config.MaxOutlines of Roblox's ~31 highlights, so eggs get a small share.
local EGG_TAGS = { "RiverEgg", "IncubatorEgg" }
local EGG_OUTLINE_DISTANCE = 150
local MAX_EGG_OUTLINES = 6
local eggOutlines = {} -- [Instance] = Highlight
task.spawn(function()
    while true do
        task.wait(0.4)
        local camera = workspace.CurrentCamera
        local cameraPosition = camera and camera.CFrame.Position or Vector3.zero
        local near = {}
        for _, tag in EGG_TAGS do
            for _, egg in CollectionService:GetTagged(tag) do
                if egg:IsDescendantOf(workspace) then
                    local ok, pivot = pcall(function()
                        return egg:IsA("Model") and egg:GetPivot().Position or egg.Position
                    end)
                    local distance = ok and (pivot - cameraPosition).Magnitude or math.huge
                    if distance <= EGG_OUTLINE_DISTANCE then
                        table.insert(near, { egg = egg, distance = distance })
                    end
                end
            end
        end
        table.sort(near, function(a, b)
            return a.distance < b.distance
        end)
        local keep = {}
        for i = 1, math.min(#near, MAX_EGG_OUTLINES) do
            local egg = near[i].egg
            keep[egg] = true
            if not eggOutlines[egg] then
                local outline = Instance.new("Highlight")
                outline.Name = "BlackOutline"
                outline.Adornee = egg
                outline.FillTransparency = 1
                outline.OutlineColor = Color3.new(0, 0, 0)
                outline.OutlineTransparency = 0
                outline.DepthMode = Enum.HighlightDepthMode.Occluded
                outline.Parent = egg
                eggOutlines[egg] = outline
            end
        end
        for egg, outline in eggOutlines do
            if not keep[egg] or not egg.Parent then
                outline:Destroy()
                eggOutlines[egg] = nil
            end
        end
    end
end)
