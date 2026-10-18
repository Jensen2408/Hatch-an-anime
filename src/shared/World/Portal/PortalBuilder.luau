--[[ ReplicatedStorage.Portal.PortalBuilder  (ModuleScript, shared: server builds live gates, the trailer builds local ones)
Builds the static Summon Gate: red-lacquer torii, stone slab, rope + paper streamers, two stone lanterns
and an invisible "Surface" part across the opening. The vortex, particles and lights are created per client
by PortalClient (so they can animate smoothly without replication).
  Builder.Build(baseCFrame, parent) -> Model   -- baseCFrame = ground centre, LookVector = where characters walk
All offsets below are in baseCFrame space (studs); parts are anchored. Near-copy of
ServerScriptService.Portal.PortalBuilder (server/World/Portal/PortalBuilder.luau).
]]
local CollectionService = game:GetService("CollectionService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Portal"):WaitForChild("PortalConfig"))
local PALETTE = Config.Palette
local CYL = Enum.PartType.Cylinder
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis X -> Y

local Builder = {}

-- Anchored part helper. opts: shape, material, collide (default true), shadow (default true), transparency.
local function makePart(parent, name, size, cframe, color, opts)
    opts = opts or {}
    local part = Instance.new("Part")
    part.Name = name
    part.Shape = opts.shape or Enum.PartType.Block
    part.Size = size
    part.CFrame = cframe
    part.Color = color
    part.Material = opts.material or Enum.Material.SmoothPlastic
    part.Anchored = true
    part.CanCollide = opts.collide ~= false
    part.CastShadow = opts.shadow ~= false
    part.Transparency = opts.transparency or 0
    part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end

-- Stone lantern at sideways offset `x` (default 4.2 studs in front of the gate), with a real PointLight.
local function buildLantern(gate, base, x)
    local lanternModel = Instance.new("Model")
    lanternModel.Name = "Lantern"
    lanternModel.Parent = gate
    local at = function(y, z)
        return base * CFrame.new(x, y, z or -4.2)
    end
    makePart(
        lanternModel,
        "Foot",
        Vector3.new(1.8, 0.4, 1.8),
        at(Config.GroundY + 0.2),
        PALETTE.StoneDark,
        { material = Enum.Material.Slate }
    )
    makePart(
        lanternModel,
        "Post",
        Vector3.new(1.6, 0.7, 0.7),
        at(Config.GroundY + 1.2) * UPRIGHT,
        PALETTE.Stone,
        { shape = CYL, material = Enum.Material.Slate }
    )
    makePart(
        lanternModel,
        "Plate",
        Vector3.new(1.7, 0.25, 1.7),
        at(Config.GroundY + 2.15),
        PALETTE.StoneDark,
        { material = Enum.Material.Slate }
    )
    local firebox = makePart(
        lanternModel,
        "Firebox",
        Vector3.new(1.1, 1.0, 1.1),
        at(Config.GroundY + 2.8),
        PALETTE.LanternGlow,
        { material = Enum.Material.Neon, shadow = false }
    )
    local light = Instance.new("PointLight")
    light.Color = PALETTE.LanternGlow
    light.Range = 12
    light.Brightness = 1.4
    light.Shadows = true
    light.Parent = firebox
    makePart(
        lanternModel,
        "Roof",
        Vector3.new(2.0, 0.35, 2.0),
        at(Config.GroundY + 3.45),
        PALETTE.StoneDark,
        { material = Enum.Material.Slate }
    )
    makePart(
        lanternModel,
        "RoofTop",
        Vector3.new(1.2, 0.3, 1.2),
        at(Config.GroundY + 3.75),
        PALETTE.StoneDark,
        { material = Enum.Material.Slate }
    )
    makePart(
        lanternModel,
        "Jewel",
        Vector3.new(0.5, 0.5, 0.5),
        at(Config.GroundY + 4.1),
        PALETTE.Gold,
        { shape = Enum.PartType.Ball, material = Enum.Material.Metal }
    )
end

function Builder.Build(base, parent)
    local gate = Instance.new("Model")
    gate.Name = "SummonGate"
    local groundY = Config.GroundY
    local at = function(x, y, z)
        return base * CFrame.new(x, y, z or 0)
    end

    -- stone platform (extends forward so characters land on it)
    makePart(
        gate,
        "Slab",
        Vector3.new(17, groundY, 9.5),
        at(0, groundY / 2, -2.2),
        PALETTE.Stone,
        { material = Enum.Material.Slate }
    )
    makePart(
        gate,
        "SlabTrim",
        Vector3.new(17.4, 0.12, 9.9),
        at(0, groundY - 0.06, -2.2),
        PALETTE.StoneDark,
        { material = Enum.Material.Slate }
    )
    makePart(
        gate,
        "Step",
        Vector3.new(11, 0.3, 1.4),
        at(0, 0.15, -7.6),
        PALETTE.Stone,
        { material = Enum.Material.Slate }
    )

    -- pillars
    local pillarHeight = 12.4
    for _, side in { -1, 1 } do
        local x = 4.9 * side
        makePart(
            gate,
            "Pillar",
            Vector3.new(pillarHeight, 1.4, 1.4),
            at(x, groundY + pillarHeight / 2) * UPRIGHT,
            PALETTE.Lacquer,
            { shape = CYL }
        )
        makePart(
            gate,
            "PillarFoot",
            Vector3.new(1.3, 1.9, 1.9),
            at(x, groundY + 0.65) * UPRIGHT,
            PALETTE.Ink,
            { shape = CYL }
        )
        for _, bandY in { 2.3, 10.0 } do
            makePart(
                gate,
                "GoldBand",
                Vector3.new(0.25, 1.55, 1.55),
                at(x, groundY + bandY) * UPRIGHT,
                PALETTE.Gold,
                { shape = CYL, material = Enum.Material.Metal }
            )
        end
    end

    -- beams: nuki (lower), plaque, shimaki + kasagi (top) with upturned tips
    makePart(gate, "Nuki", Vector3.new(13.6, 0.75, 0.9), at(0, 10.85 + groundY - 0.6), PALETTE.Lacquer)
    makePart(
        gate,
        "PlaqueFrame",
        Vector3.new(2.0, 2.3, 0.35),
        at(0, 12.35, 0.05),
        PALETTE.Gold,
        { material = Enum.Material.Metal }
    )
    local plaque = makePart(gate, "Plaque", Vector3.new(1.6, 1.9, 0.45), at(0, 12.35), PALETTE.Ink)
    local surfaceGui = Instance.new("SurfaceGui")
    surfaceGui.Face = Enum.NormalId.Front
    surfaceGui.PixelsPerStud = 60
    surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    surfaceGui.LightInfluence = 0.3
    surfaceGui.Parent = plaque
    local plaqueText = Instance.new("TextLabel")
    plaqueText.Size = UDim2.fromScale(1, 1)
    plaqueText.BackgroundTransparency = 1
    plaqueText.Text = "召\n喚" -- "summon", written vertically
    plaqueText.TextColor3 = PALETTE.Gold
    plaqueText.TextScaled = true
    plaqueText.Font = Enum.Font.GothamBlack
    plaqueText.Parent = surfaceGui
    makePart(gate, "Shimaki", Vector3.new(15, 0.7, 1.1), at(0, 13.4), PALETTE.Lacquer)
    makePart(gate, "Kasagi", Vector3.new(16.4, 0.8, 1.5), at(0, 14.15), PALETTE.Ink)
    for _, side in { -1, 1 } do
        local tip = at(9.15 * side, 14.38) * CFrame.Angles(0, 0, math.rad(12) * side)
        makePart(gate, "KasagiTip", Vector3.new(2.2, 0.8, 1.5), tip, PALETTE.Ink)
        makePart(
            gate,
            "TipCap",
            Vector3.new(0.3, 0.86, 1.56),
            tip * CFrame.new(1.05 * side, 0, 0),
            PALETTE.Gold,
            { material = Enum.Material.Metal }
        )
    end

    -- shimenawa rope + shide streamers
    makePart(
        gate,
        "Rope",
        Vector3.new(8.4, 0.5, 0.5),
        at(0, groundY + 9.55, -0.7),
        PALETTE.Rope,
        { shape = CYL, material = Enum.Material.Fabric, collide = false }
    )
    -- three streamers of 3 zig-zag paper pieces each
    for _, x in { -2.6, 0, 2.6 } do
        for i = 0, 2 do
            makePart(
                gate,
                "Shide",
                Vector3.new(0.34, 0.42, 0.04),
                at(x + (i % 2 == 0 and -0.06 or 0.06), groundY + 9.05 - i * 0.4, -0.72),
                PALETTE.Paper,
                { collide = false, shadow = false }
            )
        end
    end

    buildLantern(gate, base, -7)
    buildLantern(gate, base, 7)

    -- the portal plane (invisible; PortalClient draws the vortex on it)
    local surface = makePart(
        gate,
        "Surface",
        Vector3.new(Config.Opening.X, Config.Opening.Y, 0.1),
        at(0, groundY + Config.Opening.Y / 2),
        PALETTE.Ink,
        { collide = false, shadow = false, transparency = 1 }
    )
    surface.CanQuery = false
    surface.CanTouch = false

    gate.WorldPivot = base
    gate.Parent = parent or workspace
    CollectionService:AddTag(gate, Config.Tag)
    return gate
end

return Builder
