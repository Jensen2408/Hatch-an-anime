--[[ ServerScriptService.Portal.PortalBuilder  (ModuleScript, server)
Builds the static Summon Gate: red-lacquer torii, stone slab, rope + paper streamers, two stone lanterns
and an invisible "Surface" part across the opening. The vortex, particles and lights are created per client
by PortalClient (so they can animate smoothly without replication).
  Builder.Build(baseCFrame, parent) -> Model   -- baseCFrame = ground centre, LookVector = where characters walk
]]
local CollectionService = game:GetService("CollectionService")
local C = require(game:GetService("ReplicatedStorage"):WaitForChild("Portal"):WaitForChild("PortalConfig"))
local P = C.Palette
local CYL = Enum.PartType.Cylinder
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis X -> Y

local Builder = {}

local function part(model, name, size, cf, color, opts)
    opts = opts or {}
    local p = Instance.new("Part")
    p.Name = name
    p.Shape = opts.shape or Enum.PartType.Block
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Material = opts.material or Enum.Material.SmoothPlastic
    p.Anchored = true
    p.CanCollide = opts.collide ~= false
    p.CastShadow = opts.shadow ~= false
    p.Transparency = opts.transparency or 0
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p.Parent = model
    return p
end

local function lantern(model, base, x)
    local g = Instance.new("Model")
    g.Name = "Lantern"
    g.Parent = model
    local at = function(y, z)
        return base * CFrame.new(x, y, z or -4.2)
    end
    part(g, "Foot", Vector3.new(1.8, 0.4, 1.8), at(C.GroundY + 0.2), P.StoneDark, { material = Enum.Material.Slate })
    part(
        g,
        "Post",
        Vector3.new(1.6, 0.7, 0.7),
        at(C.GroundY + 1.2) * UPRIGHT,
        P.Stone,
        { shape = CYL, material = Enum.Material.Slate }
    )
    part(g, "Plate", Vector3.new(1.7, 0.25, 1.7), at(C.GroundY + 2.15), P.StoneDark, { material = Enum.Material.Slate })
    local box = part(
        g,
        "Firebox",
        Vector3.new(1.1, 1.0, 1.1),
        at(C.GroundY + 2.8),
        P.LanternGlow,
        { material = Enum.Material.Neon, shadow = false }
    )
    local l = Instance.new("PointLight")
    l.Color = P.LanternGlow
    l.Range = 12
    l.Brightness = 1.4
    l.Shadows = true
    l.Parent = box
    part(g, "Roof", Vector3.new(2.0, 0.35, 2.0), at(C.GroundY + 3.45), P.StoneDark, { material = Enum.Material.Slate })
    part(
        g,
        "RoofTop",
        Vector3.new(1.2, 0.3, 1.2),
        at(C.GroundY + 3.75),
        P.StoneDark,
        { material = Enum.Material.Slate }
    )
    part(
        g,
        "Jewel",
        Vector3.new(0.5, 0.5, 0.5),
        at(C.GroundY + 4.1),
        P.Gold,
        { shape = Enum.PartType.Ball, material = Enum.Material.Metal }
    )
end

function Builder.Build(base, parent)
    local m = Instance.new("Model")
    m.Name = "SummonGate"
    local g = C.GroundY
    local at = function(x, y, z)
        return base * CFrame.new(x, y, z or 0)
    end

    -- stone platform (extends forward so characters land on it)
    part(m, "Slab", Vector3.new(17, g, 9.5), at(0, g / 2, -2.2), P.Stone, { material = Enum.Material.Slate })
    part(
        m,
        "SlabTrim",
        Vector3.new(17.4, 0.12, 9.9),
        at(0, g - 0.06, -2.2),
        P.StoneDark,
        { material = Enum.Material.Slate }
    )
    part(m, "Step", Vector3.new(11, 0.3, 1.4), at(0, 0.15, -7.6), P.Stone, { material = Enum.Material.Slate })

    -- pillars
    local H = 12.4
    for _, s in { -1, 1 } do
        local x = 4.9 * s
        part(m, "Pillar", Vector3.new(H, 1.4, 1.4), at(x, g + H / 2) * UPRIGHT, P.Lacquer, { shape = CYL })
        part(m, "PillarFoot", Vector3.new(1.3, 1.9, 1.9), at(x, g + 0.65) * UPRIGHT, P.Ink, { shape = CYL })
        for _, y in { 2.3, 10.0 } do
            part(
                m,
                "GoldBand",
                Vector3.new(0.25, 1.55, 1.55),
                at(x, g + y) * UPRIGHT,
                P.Gold,
                { shape = CYL, material = Enum.Material.Metal }
            )
        end
    end

    -- beams: nuki (lower), plaque, shimaki + kasagi (top) with upturned tips
    part(m, "Nuki", Vector3.new(13.6, 0.75, 0.9), at(0, 10.85 + g - 0.6), P.Lacquer)
    part(m, "PlaqueFrame", Vector3.new(2.0, 2.3, 0.35), at(0, 12.35, 0.05), P.Gold, { material = Enum.Material.Metal })
    local plaque = part(m, "Plaque", Vector3.new(1.6, 1.9, 0.45), at(0, 12.35), P.Ink)
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Front
    sg.PixelsPerStud = 60
    sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.LightInfluence = 0.3
    sg.Parent = plaque
    local t = Instance.new("TextLabel")
    t.Size = UDim2.fromScale(1, 1)
    t.BackgroundTransparency = 1
    t.Text = "召\n喚"
    t.TextColor3 = P.Gold
    t.TextScaled = true
    t.Font = Enum.Font.GothamBlack
    t.Parent = sg
    part(m, "Shimaki", Vector3.new(15, 0.7, 1.1), at(0, 13.4), P.Lacquer)
    part(m, "Kasagi", Vector3.new(16.4, 0.8, 1.5), at(0, 14.15), P.Ink)
    for _, s in { -1, 1 } do
        local tip = at(9.15 * s, 14.38) * CFrame.Angles(0, 0, math.rad(12) * s)
        part(m, "KasagiTip", Vector3.new(2.2, 0.8, 1.5), tip, P.Ink)
        part(
            m,
            "TipCap",
            Vector3.new(0.3, 0.86, 1.56),
            tip * CFrame.new(1.05 * s, 0, 0),
            P.Gold,
            { material = Enum.Material.Metal }
        )
    end

    -- shimenawa rope + shide streamers
    part(
        m,
        "Rope",
        Vector3.new(8.4, 0.5, 0.5),
        at(0, g + 9.55, -0.7),
        P.Rope,
        { shape = CYL, material = Enum.Material.Fabric, collide = false }
    )
    for _, x in { -2.6, 0, 2.6 } do
        for i = 0, 2 do
            part(
                m,
                "Shide",
                Vector3.new(0.34, 0.42, 0.04),
                at(x + (i % 2 == 0 and -0.06 or 0.06), g + 9.05 - i * 0.4, -0.72),
                P.Paper,
                { collide = false, shadow = false }
            )
        end
    end

    lantern(m, base, -7)
    lantern(m, base, 7)

    -- the portal plane (invisible; PortalClient draws the vortex on it)
    local surface = part(
        m,
        "Surface",
        Vector3.new(C.Opening.X, C.Opening.Y, 0.1),
        at(0, g + C.Opening.Y / 2),
        P.Ink,
        { collide = false, shadow = false, transparency = 1 }
    )
    surface.CanQuery = false
    surface.CanTouch = false

    m.WorldPivot = base
    m.Parent = parent or workspace
    CollectionService:AddTag(m, C.Tag)
    return m
end

return Builder
