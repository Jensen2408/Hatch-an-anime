--[[ ReplicatedStorage.BossEvent.VoxelBossBuilder  (ModuleScript, shared; used by BossEventClient)
Builds the Voxel Oni: a ~38-stud stone river guardian with an oni mask, shimenawa rope and a small shrine cage on its
back, carried above its head, that holds the rare egg. Plain Parts only. BOXES are whole-stud boxes on whole-stud
corners (rest pose) using the "Incubator One Stud Cavity" MaterialVariant so every stud reads as a voxel; DETAIL is
fine trim on a 0.25-stud grid (0.25 minimum) in SmoothPlastic, since the stud variant would be cut off on it.

Model space: feet on y = 0, centred on x = 0, facing -Z (CFrame.lookAt forward).
Build() -> model, rig
  rig.Groups[name] = { Pivot = Vector3 (rest joint position), Parts = { { Part, Offset = CFrame from the pivot } } }
  groups: Body (hips at y 9), Head (neck y 20), ArmL / ArmR (shoulders y 19), LegL / LegR (hips y 9)
  rig.EggOffset = CFrame of the egg centre relative to the Body pivot
The client poses the groups every frame (BulkMoveTo); the parts are anchored and only exist on the client.
]]
local Builder = {}

local VOXEL = "Incubator One Stud Cavity"
local COLORS = {
    stone = Color3.fromRGB(128, 124, 116),
    stoneLight = Color3.fromRGB(150, 144, 134),
    stoneDark = Color3.fromRGB(98, 94, 90),
    moss = Color3.fromRGB(96, 142, 74),
    mossDark = Color3.fromRGB(70, 112, 58),
    red = Color3.fromRGB(186, 52, 44),
    redDark = Color3.fromRGB(146, 38, 34),
    cream = Color3.fromRGB(222, 198, 156),
    gold = Color3.fromRGB(196, 160, 86),
    rope = Color3.fromRGB(190, 160, 100),
    ropeDark = Color3.fromRGB(150, 122, 74),
    paper = Color3.fromRGB(240, 236, 224),
    ink = Color3.fromRGB(30, 26, 24),
    wood = Color3.fromRGB(86, 60, 46),
    woodDark = Color3.fromRGB(74, 54, 44),
    glow = Color3.fromRGB(90, 240, 255),
    eye = Color3.fromRGB(255, 206, 90),
    lantern = Color3.fromRGB(226, 88, 52),
    crystal = Color3.fromRGB(120, 210, 255),
}
-- colours that glow (Neon) instead of using the voxel material
local NEON = { glow = true, eye = true, crystal = true }

-- { group, minCorner, maxCorner, colour }  (left side only for mirrored limbs; see MIRROR)
local BOXES = {
    -- legs (left), pivot (-3, 9, 0)
    { "LegL", { -5, 5, -2 }, { -1, 9, 2 }, "stone" },
    { "LegL", { -5, 2, -2 }, { -1, 5, 2 }, "stoneDark" },
    { "LegL", { -6, 0, -4 }, { 0, 2, 2 }, "stoneDark" },
    { "LegL", { -6, 0, -5 }, { -5, 1, -4 }, "cream" },
    { "LegL", { -4, 0, -5 }, { -2, 1, -4 }, "cream" },
    { "LegL", { -1, 0, -5 }, { 0, 1, -4 }, "cream" },
    -- body, pivot (0, 9, 0)
    { "Body", { -5, 9, -3 }, { 5, 11, 3 }, "stoneDark" },
    { "Body", { -6, 11, -4 }, { 6, 15, 4 }, "stone" },
    { "Body", { -6, 15, -4 }, { 6, 18, 4 }, "stoneLight" },
    { "Body", { -6, 18, -4 }, { 6, 20, 4 }, "stone" },
    { "Body", { -7, 11, -5 }, { 7, 13, 5 }, "rope" },
    { "Body", { -2, 10, -6 }, { 2, 13, -5 }, "ropeDark" },
    { "Body", { -2, 15, -5 }, { 2, 18, -4 }, "glow" },
    { "Body", { -6, 18, -5 }, { -2, 20, -4 }, "moss" },
    { "Body", { -6, 17, 4 }, { 6, 20, 5 }, "mossDark" },
    -- shrine cage carried above the shoulders on two struts (egg inside, visible over the head)
    { "Body", { -4, 20, 4 }, { -3, 27, 5 }, "gold" },
    { "Body", { 3, 20, 4 }, { 4, 27, 5 }, "gold" },
    { "Body", { -4, 27, 3 }, { 4, 28, 10 }, "wood" },
    { "Body", { -4, 28, 3 }, { -3, 35, 4 }, "gold" },
    { "Body", { 3, 28, 3 }, { 4, 35, 4 }, "gold" },
    { "Body", { -4, 28, 9 }, { -3, 35, 10 }, "gold" },
    { "Body", { 3, 28, 9 }, { 4, 35, 10 }, "gold" },
    { "Body", { -5, 35, 2 }, { 5, 36, 11 }, "wood" },
    { "Body", { -3, 36, 4 }, { 3, 37, 9 }, "woodDark" },
    { "Body", { -1, 37, 4 }, { 1, 38, 9 }, "gold" },
    { "Body", { -6, 35, 1 }, { -5, 36, 3 }, "gold" },
    { "Body", { 5, 35, 1 }, { 6, 36, 3 }, "gold" },
    -- head, pivot (0, 20, 0)
    { "Head", { -4, 20, -4 }, { 4, 27, 3 }, "stone" },
    { "Head", { -4, 21, -5 }, { 4, 25, -4 }, "red" },
    { "Head", { -4, 25, -6 }, { 4, 26, -4 }, "redDark" },
    { "Head", { -3, 23, -6 }, { -1, 24, -5 }, "eye" },
    { "Head", { 1, 23, -6 }, { 3, 24, -5 }, "eye" },
    { "Head", { -3, 24, -6 }, { 3, 25, -5 }, "red" },
    { "Head", { -1, 22, -6 }, { 1, 23, -5 }, "redDark" },
    { "Head", { -3, 21, -6 }, { 3, 22, -5 }, "ink" },
    { "Head", { -3, 21, -7 }, { -2, 23, -6 }, "cream" },
    { "Head", { 2, 21, -7 }, { 3, 23, -6 }, "cream" },
    { "Head", { -2, 27, -1 }, { 2, 28, 2 }, "mossDark" },
    { "Head", { -4, 27, -2 }, { -2, 29, 0 }, "cream" },
    { "Head", { -5, 29, -2 }, { -3, 31, 0 }, "cream" },
    { "Head", { -6, 31, -2 }, { -5, 33, -1 }, "gold" },
    { "Head", { 2, 27, -2 }, { 4, 29, 0 }, "cream" },
    { "Head", { 3, 29, -2 }, { 5, 31, 0 }, "cream" },
    { "Head", { 5, 31, -2 }, { 6, 33, -1 }, "gold" },
    -- arms (left), pivot (-8, 19, 0)
    { "ArmL", { -10, 18, -3 }, { -6, 22, 3 }, "moss" },
    { "ArmL", { -9, 22, -2 }, { -6, 23, 2 }, "mossDark" },
    { "ArmL", { -10, 13, -2 }, { -6, 18, 2 }, "stone" },
    { "ArmL", { -11, 11, -3 }, { -5, 13, 3 }, "gold" },
    { "ArmL", { -11, 6, -3 }, { -5, 11, 3 }, "stoneDark" },
    { "ArmL", { -10, 6, -4 }, { -6, 8, -3 }, "cream" },
}
-- Fine detail on a 0.25-stud grid: { group, minCorner, maxCorner, colour, mirrorInGroup? }. mirrorInGroup adds the
-- x-mirrored copy to the same group (symmetric Body / Head details); LegL / ArmL details mirror to LegR / ArmR anyway.
local DETAIL = {
    -- legs: knee plate, shin crack, ankle rope, claw tips, thigh moss
    { "LegL", { -5.25, 5, -2.5 }, { -0.75, 6.5, -2 }, "stoneLight" },
    { "LegL", { -3.25, 2.75, -2.25 }, { -3, 4.5, -2 }, "ink" },
    { "LegL", { -5.25, 2, -2.25 }, { -0.75, 2.75, 2.25 }, "rope" },
    { "LegL", { -6, 0, -5.5 }, { -5, 0.75, -5 }, "gold" },
    { "LegL", { -3.5, 0, -5.5 }, { -2.5, 0.75, -5 }, "gold" },
    { "LegL", { -1, 0, -5.5 }, { 0, 0.75, -5 }, "gold" },
    { "LegL", { -5.25, 7, -1 }, { -5, 8.5, 1 }, "moss" },
    { "LegL", { -5.5, 8.5, -1.5 }, { -5, 9, 1.5 }, "mossDark" },
    -- torso: ab grooves, chest plate, gold frame around the glowing core, back spine, moss drips
    { "Body", { -5, 13.5, -4.25 }, { 5, 13.75, -4 }, "ink" },
    { "Body", { -0.25, 13.75, -4.25 }, { 0.25, 14.5, -4 }, "ink" },
    { "Body", { -5.5, 15.5, -4.5 }, { -2.5, 17.5, -4 }, "stoneLight", true },
    { "Body", { -2.5, 18, -5.25 }, { 2.5, 18.5, -4 }, "gold" },
    { "Body", { -2.5, 14.5, -5.25 }, { 2.5, 15, -4 }, "gold" },
    { "Body", { -2.5, 15, -5.25 }, { -2, 18, -4 }, "gold", true },
    { "Body", { -1, 11, 4 }, { 1, 17, 4.75 }, "stoneDark" },
    { "Body", { -2, 13, 4 }, { -1, 14, 4.5 }, "stoneDark", true },
    { "Body", { -6.25, 16.5, 3 }, { -6, 18, 4 }, "moss", true },
    { "Body", { -4, 16.25, 5 }, { -3, 17, 5.25 }, "moss", true },
    { "Body", { -6.25, 12.75, -2 }, { -6, 14.5, -1.75 }, "ink", true },
    -- shimenawa rope twists (front and back) and the zig-zag paper charms
    { "Body", { -6.5, 11, -5.25 }, { -6, 13, -5 }, "ropeDark", true },
    { "Body", { -5, 11, -5.25 }, { -4.5, 13, -5 }, "ropeDark", true },
    { "Body", { -3.5, 11, -5.25 }, { -3, 13, -5 }, "ropeDark", true },
    { "Body", { -6.5, 11, 5 }, { -6, 13, 5.25 }, "ropeDark", true },
    { "Body", { -5, 11, 5 }, { -4.5, 13, 5.25 }, "ropeDark", true },
    { "Body", { -3.5, 11, 5 }, { -3, 13, 5.25 }, "ropeDark", true },
    { "Body", { -2, 11, 5 }, { -1.5, 13, 5.25 }, "ropeDark", true },
    { "Body", { -0.25, 11, 5 }, { 0.25, 13, 5.25 }, "ropeDark" },
    { "Body", { -1.25, 11.25, -6.25 }, { 1.25, 12.75, -6 }, "rope" },
    { "Body", { -5, 10, -5.75 }, { -4, 11, -5.25 }, "paper", true },
    { "Body", { -4.5, 9, -5.75 }, { -3.5, 10, -5.25 }, "paper", true },
    { "Body", { -5, 8, -5.75 }, { -4, 9, -5.25 }, "paper", true },
    { "Body", { -4.5, 7, -5.75 }, { -3.5, 8, -5.25 }, "paper", true },
    { "Body", { -0.5, 9, -6.25 }, { 0.5, 10, -5.75 }, "paper" },
    { "Body", { 0, 8, -6.25 }, { 1, 9, -5.75 }, "paper" },
    { "Body", { -0.5, 7, -6.25 }, { 0.5, 8, -5.75 }, "paper" },
    -- shrine: rails, roof ribs, hanging lanterns
    { "Body", { -4, 34.25, 4 }, { -3, 34.75, 9 }, "gold", true },
    { "Body", { -4, 28.25, 4 }, { -3, 28.75, 9 }, "gold", true },
    { "Body", { -3, 34.25, 3 }, { 3, 34.75, 4 }, "gold" },
    { "Body", { -3, 34.25, 9 }, { 3, 34.75, 10 }, "gold" },
    { "Body", { -5, 36, 2.5 }, { -3, 36.25, 3 }, "woodDark", true },
    { "Body", { -5, 36, 4 }, { -3, 36.25, 4.5 }, "woodDark", true },
    { "Body", { -5, 36, 5.5 }, { -3, 36.25, 6 }, "woodDark", true },
    { "Body", { -5, 36, 7 }, { -3, 36.25, 7.5 }, "woodDark", true },
    { "Body", { -5, 36, 8.5 }, { -3, 36.25, 9 }, "woodDark", true },
    { "Body", { -5, 36, 10 }, { -3, 36.25, 10.5 }, "woodDark", true },
    { "Body", { -5.75, 33.5, 1.5 }, { -5.25, 35, 2.5 }, "lantern", true },
    { "Body", { -5.75, 33.25, 1.75 }, { -5.25, 33.5, 2.25 }, "gold", true },
    { "Body", { -5, 27.75, 10 }, { 5, 28, 10.5 }, "gold" },
    -- head: pupils, angry brows, forehead gem, cheek marks, teeth, nostrils, ears, horn rings, hair spikes
    { "Head", { -2.25, 23, -6.25 }, { -1.75, 24, -6 }, "ink" },
    { "Head", { 1.75, 23, -6.25 }, { 2.25, 24, -6 }, "ink" },
    { "Head", { -3.5, 24.5, -6.25 }, { -1, 25, -6 }, "ink", true },
    { "Head", { -1, 24.75, -6.25 }, { -0.5, 25.25, -6 }, "ink", true },
    { "Head", { -0.5, 25.25, -6.25 }, { 0.5, 26, -6 }, "glow" },
    { "Head", { -4, 22, -5.25 }, { -3.5, 23.5, -5 }, "gold", true },
    { "Head", { -1.75, 21.5, -6.25 }, { -1.25, 22, -6 }, "cream", true },
    { "Head", { -0.75, 21.5, -6.25 }, { -0.25, 22, -6 }, "cream", true },
    { "Head", { -0.75, 22.25, -6.25 }, { -0.25, 22.75, -6 }, "ink", true },
    { "Head", { -4.75, 22, -1 }, { -4, 24.5, 1 }, "stone", true },
    { "Head", { -5, 22.5, -0.5 }, { -4.75, 24, 0.5 }, "redDark", true },
    { "Head", { -4.25, 28.5, -2.25 }, { -1.75, 29, 0.25 }, "gold", true },
    { "Head", { -1.5, 28, -0.5 }, { -0.5, 29, 0.5 }, "moss" },
    { "Head", { 0.5, 28, 0 }, { 1.5, 28.75, 1 }, "moss" },
    { "Head", { -0.5, 28, 1 }, { 0.5, 28.5, 2 }, "mossDark" },
    -- arms: pauldron trim and spikes, bracer groove, knuckles, arm crack
    { "ArmL", { -10.25, 17.75, -3.25 }, { -5.75, 18.25, 3.25 }, "gold" },
    { "ArmL", { -9, 23, -0.5 }, { -8, 24.5, 0.5 }, "cream" },
    { "ArmL", { -7.5, 23, -1.5 }, { -6.75, 24, -0.75 }, "cream" },
    { "ArmL", { -11.25, 11.75, -3.25 }, { -4.75, 12.25, 3.25 }, "ink" },
    { "ArmL", { -10.75, 8.5, -3.5 }, { -9.75, 10, -3 }, "stoneLight" },
    { "ArmL", { -9.25, 8.5, -3.5 }, { -8.25, 10, -3 }, "stoneLight" },
    { "ArmL", { -7.75, 8.5, -3.5 }, { -6.75, 10, -3 }, "stoneLight" },
    { "ArmL", { -6.25, 8.5, -3.5 }, { -5.25, 10, -3 }, "stoneLight" },
    { "ArmL", { -11.25, 6.5, -1 }, { -11, 9.5, 1 }, "stoneLight" },
    { "ArmL", { -6.5, 16.5, -2 }, { -4.5, 20, 2 }, "stoneDark" },
    { "ArmL", { -6.25, 17.5, -2.25 }, { -4.75, 19, 2.25 }, "rope" },
}
local MIRROR = { LegL = "LegR", ArmL = "ArmR" }
local ARM_OUT = 2 -- the arm boxes above are shifted outward by this much (keep in step with the Blender build script)
local PIVOTS = {
    Body = Vector3.new(0, 9, 0),
    Head = Vector3.new(0, 20, 0),
    ArmL = Vector3.new(-8 - ARM_OUT, 19, 0),
    ArmR = Vector3.new(8 + ARM_OUT, 19, 0),
    LegL = Vector3.new(-3, 9, 0),
    LegR = Vector3.new(3, 9, 0),
}

local function makePart(minCorner, maxCorner, colorName)
    local part = Instance.new("Part")
    part.Name = colorName
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = true -- clicks raycast against the boss
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Size = maxCorner - minCorner
    part.Color = COLORS[colorName]
    local size, wholeStuds = part.Size, true
    for _, value in { size.X, size.Y, size.Z, minCorner.X, minCorner.Y, minCorner.Z } do
        wholeStuds = wholeStuds and value % 1 == 0
    end
    if NEON[colorName] then
        part.Material = Enum.Material.Neon
    elseif not wholeStuds then
        -- sub-stud trim: the stud variant would cut its studs off at the edges
        part.Material = Enum.Material.SmoothPlastic
    else
        part.Material = Enum.Material.Plastic
        part.MaterialVariant = VOXEL
    end
    return part
end

-- Imported Oni (Blender: tools/boss, Studio 3D Importer -> ReplicatedStorage.BossEvent.OniModel). Its MeshParts are
-- named "<Group>__<colour>"; the model's WorldPivot is the feet at the origin facing -Z (set once after import).
-- Each piece is coloured here from COLORS, with the stud MaterialVariant (Neon for the glowing colours).
local function buildFromTemplate(template)
    local model = Instance.new("Model")
    model.Name = "VoxelOni"
    local rig = { Groups = {} }
    for name, pivot in PIVOTS do
        rig.Groups[name] = { Pivot = pivot, Parts = {} }
    end
    local origin = template:GetPivot()
    for _, source in template:GetDescendants() do
        local groupName, colorName = source.Name:match("^(%a+)__(%a+)")
        local group = groupName and rig.Groups[groupName]
        if source:IsA("BasePart") and group and COLORS[colorName] then
            local part = source:Clone()
            part:ClearAllChildren()
            part.Anchored = true
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = true
            part.Color = COLORS[colorName]
            if NEON[colorName] then
                part.Material = Enum.Material.Neon
            else
                part.Material = Enum.Material.Plastic
                part.MaterialVariant = VOXEL
            end
            local rest = origin:ToObjectSpace(source.CFrame)
            part.CFrame = rest
            part.Parent = model
            table.insert(group.Parts, { Part = part, Offset = CFrame.new(-group.Pivot) * rest })
        end
    end
    local core = model:FindFirstChild("Body__glow")
    if core then
        local light = Instance.new("PointLight")
        light.Color = COLORS.glow
        light.Range = 18
        light.Brightness = 2
        light.Parent = core
    end
    rig.EggOffset = CFrame.new(Vector3.new(0, 31.5, 6.5) - PIVOTS.Body)
    model.WorldPivot = CFrame.new()
    return model, rig
end

function Builder.Build()
    local template = script.Parent:FindFirstChild("OniModel")
    if template then
        return buildFromTemplate(template)
    end
    local model = Instance.new("Model")
    model.Name = "VoxelOni"
    local rig = { Groups = {} }
    for name, pivot in PIVOTS do
        rig.Groups[name] = { Pivot = pivot, Parts = {} }
    end
    local function add(groupName, minCorner, maxCorner, colorName)
        local part = makePart(minCorner, maxCorner, colorName)
        local center = (minCorner + maxCorner) / 2
        local group = rig.Groups[groupName]
        part.CFrame = CFrame.new(center)
        part.Parent = model
        table.insert(group.Parts, { Part = part, Offset = CFrame.new(center - group.Pivot) })
    end
    local function addBox(box)
        local minCorner = Vector3.new(table.unpack(box[2]))
        local maxCorner = Vector3.new(table.unpack(box[3]))
        if box[1] == "ArmL" then -- arms stand ARM_OUT studs clear of the torso
            minCorner -= Vector3.xAxis * ARM_OUT
            maxCorner -= Vector3.xAxis * ARM_OUT
        end
        add(box[1], minCorner, maxCorner, box[4])
        local mirrored = MIRROR[box[1]] or (box[5] and box[1])
        if mirrored then
            add(
                mirrored,
                Vector3.new(-maxCorner.X, minCorner.Y, minCorner.Z),
                Vector3.new(-minCorner.X, maxCorner.Y, maxCorner.Z),
                box[4]
            )
        end
    end
    for _, box in BOXES do
        addBox(box)
    end
    for _, box in DETAIL do
        addBox(box)
    end
    -- glowing eyes / core light up the water at night
    local core = model:FindFirstChild("glow")
    local light = Instance.new("PointLight")
    light.Color = COLORS.glow
    light.Range = 18
    light.Brightness = 2
    light.Parent = core
    rig.EggOffset = CFrame.new(Vector3.new(0, 31.5, 6.5) - PIVOTS.Body)
    model.WorldPivot = CFrame.new()
    return model, rig
end

Builder.Colors = COLORS
return Builder
