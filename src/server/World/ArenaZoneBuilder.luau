--[[ ServerScriptService.ArenaZoneBuilder  (ModuleScript, server only)
Builds the Arena Brawl zone: a voxel basalt cavern inside a volcano, far from the map (ArenaConfig.Center). The player
platform floats in the middle; a lava lake covers the cavern overhead, a lava pit glows below, the basalt wall surrounds it all.

  Builder.Build(parent) -> Model "PvPArena"
      the 144 platform tiles (each carries the attribute Ring: 0 = outer edge ... 5 = centre), the stepped underside
      pillar, floating lanterns, the 32-segment basalt wall with lava cracks and ledges, the lava lake ceiling with
      stalactites and lavafalls, the lava pit, embers and lights. Whole-stud sizes, "Incubator One Stud Cavity" on the
      basalt and tiles; lava is Neon / CrackedLava.

How it is used: the zone is built ONCE in Studio edit mode so it is visible and editable in the editor:
    require(game.ServerScriptService.ArenaZoneBuilder).Build(workspace)      -- creates Workspace.PvPArena
In the running game ArenaEventService moves that model to ServerStorage at start-up (so it is not in the world, and
nobody can see or find it), and clones a fresh copy into the workspace for each brawl, then destroys it. If the
Studio copy is missing, the service falls back to calling Build itself.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("ArenaEvent"):WaitForChild("ArenaConfig"))

local Builder = {}

local STUD_VARIANT = "Incubator One Stud Cavity"
local COLOR_A = Color3.fromRGB(222, 198, 156) -- cream
local COLOR_B = Color3.fromRGB(176, 140, 104) -- taupe
local COLOR_GOLD = Color3.fromRGB(196, 160, 86)
local COLOR_LACQUER = Color3.fromRGB(98, 70, 56)
local COLOR_DARK = Color3.fromRGB(74, 54, 44)
local BASALT_A = Color3.fromRGB(46, 40, 46)
local BASALT_B = Color3.fromRGB(58, 50, 56)
local LAVA = Color3.fromRGB(255, 108, 28)
local LAVA_BRIGHT = Color3.fromRGB(255, 150, 50)

local function block(parent, name, size, cframe, color, material)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.CFrame = cframe
    part.Color = color
    part.Anchored = true
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    if material == nil then
        part.Material = Enum.Material.Plastic
        part.MaterialVariant = STUD_VARIANT
    else
        part.Material = material
    end
    part.Parent = parent
    return part
end

local function glow(part, range, brightness)
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 140, 60)
    light.Range = range
    light.Brightness = brightness
    light.Parent = part
    return light
end

function Builder.BuildPlatform(model)
    local center = Config.Center
    local oldTiles = model:FindFirstChild("Tiles")
    if oldTiles then
        oldTiles:Destroy()
    end
    for _, child in model:GetChildren() do
        if child.Name == "Underside" or child.Name == "Lantern" then
            child:Destroy()
        end
    end

    -- ===== the circular platform: voxel disc with concentric radial rings =====
    local tilesFolder = Instance.new("Folder")
    tilesFolder.Name = "Tiles"
    tilesFolder.Parent = model
    local n, size = Config.Grid, Config.TileSize
    for row = 1, n do
        for col = 1, n do
            local ring = Config.RingOf(row, col)
            if ring ~= nil then
                local color = (row + col) % 2 == 0 and COLOR_A or COLOR_B
                if ring >= Config.ShrinkRings + 1 then
                    color = COLOR_GOLD -- the final centre medallion
                end
                local tile = block(
                    tilesFolder,
                    "Tile",
                    Vector3.new(size, Config.TileHeight, size),
                    CFrame.new(Config.TileCenter(row, col)),
                    color
                )
                tile:SetAttribute("Ring", ring)
            end
        end
    end
    -- floating-island underside: a stepped cylindrical pillar that stays inside the permanent inner core, so nobody can land on it
    local y = center.Y - Config.TileHeight
    for i, width in { 28, 22, 16, 10, 6 } do
        y -= 4
        local pillar = block(
            model,
            "Underside",
            Vector3.new(4, width, width),
            CFrame.new(center.X, y + 2, center.Z) * CFrame.Angles(0, 0, math.pi / 2),
            i % 2 == 0 and COLOR_LACQUER or COLOR_DARK
        )
        pillar.Shape = Enum.PartType.Cylinder
    end
    -- hovering spirit lanterns (not solid)
    for i = 1, 8 do
        local angle = (i - 1) / 8 * math.pi * 2
        local position = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 66 + Vector3.yAxis * 9
        local lantern = block(model, "Lantern", Vector3.new(2, 2, 2), CFrame.new(position), Color3.fromRGB(255, 160, 70), Enum.Material.Neon)
        lantern.CanCollide = false
        lantern.CanQuery = false
        lantern.CanTouch = false
        glow(lantern, 30, 2)
    end
end

function Builder.Build(parent)
    local center = Config.Center
    local radius = Config.CavernRadius
    local floorY = center.Y - Config.LavaDepth
    local ceilingY = center.Y + Config.CavernHeight
    local rng = Random.new(2026)
    local model = Instance.new("Model")
    model.Name = "PvPArena"
    pcall(function()
        model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
    end)

    Builder.BuildPlatform(model)

    local cavern = Instance.new("Folder")
    cavern.Name = "Cavern"
    cavern.Parent = model

    -- ===== the basalt wall: 32 segments, lava cracks and ledges =====
    local segments = 32
    local wallHeight = ceilingY - floorY + 24
    local wallMidY = (floorY + ceilingY) / 2
    local width = math.ceil(2 * (radius + 5) * math.tan(math.pi / segments)) + 6
    for i = 1, segments do
        local angle = (i - 0.5) / segments * math.pi * 2
        local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
        local position = Vector3.new(center.X, wallMidY, center.Z) + direction * (radius + 5)
        local look = Vector3.new(center.X, wallMidY, center.Z)
        block(cavern, "Wall", Vector3.new(width, wallHeight, 10), CFrame.lookAt(position, look), i % 2 == 0 and BASALT_A or BASALT_B)
        -- lava cracks on the inner face
        if i % 2 == 1 then
            for _ = 1, rng:NextInteger(1, 2) do
                local crackY = rng:NextNumber(floorY + 10, ceilingY - 40)
                local length = rng:NextInteger(18, 60)
                local offset = rng:NextNumber(-width / 2 + 3, width / 2 - 3)
                local inner = Vector3.new(center.X, 0, center.Z) + direction * (radius - 0.3)
                local tangent = Vector3.new(-direction.Z, 0, direction.X)
                local crack = block(
                    cavern,
                    "Crack",
                    Vector3.new(1, length, 0.5),
                    CFrame.lookAt(Vector3.new(inner.X, crackY + length / 2, inner.Z) + tangent * offset, Vector3.new(center.X, crackY + length / 2, center.Z)),
                    LAVA,
                    Enum.Material.Neon
                )
                crack.CanCollide = false
            end
        end
        -- rock ledges jutting out of the wall
        if i % 3 == 0 then
            local ledgeY = rng:NextNumber(floorY + 15, ceilingY - 30)
            local inner = Vector3.new(center.X, ledgeY, center.Z) + direction * (radius - 4)
            local ledge = block(cavern, "Ledge", Vector3.new(10, 4, 8), CFrame.lookAt(inner, Vector3.new(center.X, ledgeY, center.Z)), BASALT_B)
            ledge.CanCollide = false
        end
    end

    -- ===== the lava lake overhead: the cavern is UNDER it =====
    local lake = block(
        cavern,
        "LavaLake",
        Vector3.new(8, (radius + 14) * 2, (radius + 14) * 2),
        CFrame.new(center.X, ceilingY, center.Z) * CFrame.Angles(0, 0, math.pi / 2),
        LAVA,
        Enum.Material.CrackedLava
    )
    lake.Shape = Enum.PartType.Cylinder
    lake.CanCollide = false
    glow(lake, 90, 3)
    -- the rock mass above the lake (never seen from inside)
    local cap = block(
        cavern,
        "Cap",
        Vector3.new(30, (radius + 14) * 2, (radius + 14) * 2),
        CFrame.new(center.X, ceilingY + 19, center.Z) * CFrame.Angles(0, 0, math.pi / 2),
        BASALT_A
    )
    cap.Shape = Enum.PartType.Cylinder
    -- basalt stalactites hanging from under the lake (stepped, voxel style)
    for _ = 1, 26 do
        local angle = rng:NextNumber(0, math.pi * 2)
        local distance = rng:NextNumber(10, radius - 8)
        local x = center.X + math.cos(angle) * distance
        local z = center.Z + math.sin(angle) * distance
        local top = ceilingY - 4
        for step, dimension in { 10, 6, 2 } do
            local t = block(
                cavern,
                "Stalactite",
                Vector3.new(dimension, 8, dimension),
                CFrame.new(x, top - 4 - (step - 1) * 8, z),
                step % 2 == 0 and BASALT_A or BASALT_B
            )
            t.CanCollide = false
        end
    end
    -- lavafalls pouring from the lake into the pit, along the wall
    for i = 1, 14 do
        local angle = (i - 0.5) / 14 * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
        local position = Vector3.new(center.X + math.cos(angle) * (radius - 3), (floorY + ceilingY) / 2, center.Z + math.sin(angle) * (radius - 3))
        local fall = block(cavern, "Lavafall", Vector3.new(3, ceilingY - floorY - 2, 3), CFrame.new(position), LAVA_BRIGHT, Enum.Material.Neon)
        fall.Transparency = 0.12
        fall.CanCollide = false
        fall.CanQuery = false
        glow(fall, 40, 2)
    end

    -- ===== the lava pit below =====
    local pit = block(
        cavern,
        "LavaPit",
        Vector3.new(6, (radius + 14) * 2, (radius + 14) * 2),
        CFrame.new(center.X, floorY, center.Z) * CFrame.Angles(0, 0, math.pi / 2),
        LAVA,
        Enum.Material.CrackedLava
    )
    pit.Shape = Enum.PartType.Cylinder
    for i = 1, 8 do
        local angle = (i - 1) / 8 * math.pi * 2
        local lightPart = block(
            cavern,
            "PitGlow",
            Vector3.new(2, 2, 2),
            CFrame.new(center.X + math.cos(angle) * 58, floorY + 8, center.Z + math.sin(angle) * 58),
            LAVA_BRIGHT,
            Enum.Material.Neon
        )
        lightPart.Transparency = 1
        lightPart.CanCollide = false
        lightPart.CanQuery = false
        glow(lightPart, 70, 3)
    end
    -- embers rising off the lava
    local embers = block(
        cavern,
        "Embers",
        Vector3.new(150, 1, 150),
        CFrame.new(center.X, floorY + 4, center.Z),
        LAVA,
        Enum.Material.SmoothPlastic
    )
    embers.Transparency = 1
    embers.CanCollide = false
    embers.CanQuery = false
    local emitter = Instance.new("ParticleEmitter")
    emitter.Rate = 70
    emitter.Lifetime = NumberRange.new(3, 5.5)
    emitter.Speed = NumberRange.new(8, 16)
    emitter.EmissionDirection = Enum.NormalId.Top
    emitter.SpreadAngle = Vector2.new(25, 25)
    emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
    emitter.Color = ColorSequence.new(Color3.fromRGB(255, 190, 70), Color3.fromRGB(255, 60, 20))
    emitter.LightEmission = 1
    emitter.Parent = embers

    model.Parent = parent
    return model
end

return Builder
