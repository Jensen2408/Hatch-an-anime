-- ReplicatedStorage.WaterfallRiver.RiverConfig
-- Edit values here, then rebuild with:  require(game.ServerStorage.WaterfallRiverBuilder:Clone())()
-- NOTE: fitted to the Hatch A Anime arena (cliff backs onto the west wall, river ends at the east wall).
-- After a rebuild, also run the ground recolor step (see ServerStorage.WaterfallRiverBuilder notes) or keep BuildGround colors.
local Config = {}

Config.Origin = Vector3.new(-283, 25.96, 20) -- ground level at the foot of the waterfall (cliff face is at Origin.X)
Config.Seed = 7 -- change for a different natural arrangement

Config.Length = 527 -- river length (runs along +X)
Config.RiverWidth = 14 -- narrow river
Config.RiverDepth = 1.6 -- water surface sits this far below the ground
Config.WaterDepth = 2.4 -- bed sits this far below the water surface (shallow look)
Config.Meander = 9 -- gentle sideways sway of the river
Config.PoolLength = 26 -- wider plunge pool at the base
Config.PoolExtraWidth = 10

Config.FallHeight = 32
Config.FallWidth = 16
Config.CliffHalfWidth = 48
Config.CliffDepth = 30

Config.BuildGround = true -- grass ground on both banks
Config.PlayWidth = 182 -- open playable ground on each side (reaches the arena walls)

Config.Colors = {
    Water = Color3.fromRGB(70, 214, 214),
    WaterDeep = Color3.fromRGB(34, 168, 184),
    WaterLight = Color3.fromRGB(150, 238, 230),
    Foam = Color3.fromRGB(246, 253, 253),
    Bed = Color3.fromRGB(64, 150, 150),
    BedLight = Color3.fromRGB(120, 196, 178),
    Sand = Color3.fromRGB(214, 206, 168),
    Stone = Color3.fromRGB(134, 138, 146),
    StoneLight = Color3.fromRGB(168, 170, 176),
    StoneDark = Color3.fromRGB(92, 98, 110),
    Moss = Color3.fromRGB(98, 170, 72),
    Grass = Color3.fromRGB(112, 196, 86),
    GrassDark = Color3.fromRGB(78, 156, 70),
    Reed = Color3.fromRGB(70, 140, 70),
    Iris = Color3.fromRGB(136, 96, 214),
    Bamboo = Color3.fromRGB(122, 178, 82),
    BambooNode = Color3.fromRGB(170, 204, 112),
    Blossom = Color3.fromRGB(255, 178, 204),
    Maple = Color3.fromRGB(232, 92, 58),
    Bark = Color3.fromRGB(98, 70, 56),
    Wood = Color3.fromRGB(150, 98, 64),
    Vermilion = Color3.fromRGB(206, 58, 44),
    Paper = Color3.fromRGB(255, 232, 178),
}

Config.Terrain = {
    WaterColor = Color3.fromRGB(58, 206, 210),
    WaterTransparency = 0.55,
    WaterReflectance = 0.2,
    WaterWaveSize = 0.04,
    WaterWaveSpeed = 6,
}

Config.Egg = {
    SpawnInterval = 5,
    MaxEggs = 14,
    FallTime = 2.4, -- slide over the lip + fall
    DipTime = 1.6, -- dip under the surface and pop back up
    DipDepth = 1.7,
    FloatSpeed = 14, -- studs per second downstream (matches the old river speed)
    FloatHeight = 0.5,
    Size = Vector3.new(2.4, 3, 2.4),
    CollectRange = 12,
    CreateLeaderstat = false,
    LeaderstatName = "Eggs",
    RarityColors = {},
    Types = {},
}

return Config
