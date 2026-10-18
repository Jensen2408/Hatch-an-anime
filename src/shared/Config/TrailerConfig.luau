-- ReplicatedStorage.TrailerConfig: settings for the recording-only trailer (/trailer or F7)
local Config = {}
Config.OwnerIds = { [168774222] = true }
Config.AllowInStudio = false -- only the user IDs in OwnerIds can run the trailer, even in Studio
Config.Command, Config.StopCommand, Config.Key = "/trailer", "/trailerstop", Enum.KeyCode.F7
Config.StartDelay = 3

Config.MarkersFolder = "Workspace/TrailerMarkers"
Config.MarkerPlot = "Workspace/Plots/TemplePlot01" -- markers were placed around this plot; they move to the plot you own
Config.AutoPlot = true
Config.PlotsFolder = "Workspace/Plots"
Config.PlotOwnerAttributes = { "OwnerUserId", "Owner", "OwnerId", "UserId" }
Config.IncubatorNames = { "Chamber1" }
Config.SlotNames = { "Slot0", "Slot1", "Slot2", "Slot3", "Slot4" }
Config.EntranceNames = { "Entrance", "Gate" }
Config.Models = {
    PirateEgg = "ReplicatedStorage/GameMenu/EggPreviews/MenuEgg_Pirate",
    Reward = "ReplicatedStorage/CharacterInventory/Portraits/Pirate",
    Incubator = "auto", -- Chamber1 on the plot you own
}
Config.TitleText = "HATCH AN ANIME"
Config.TaglineText = "Catch it. Hatch it. Collect them all."
Config.OutroText = "PLAY NOW ON ROBLOX"
Config.Durations = { Intro = 7, RiftArrival = 9, SpotEgg = 7, Chase = 10, BringHome = 9, Hatch = 9, Place = 9 }

Config.EggScale = 1
Config.EggHeight = 3.4 -- egg is auto-sized to this many studs tall
Config.RewardHeight = 5 -- hatched character height
Config.ClockTime = 16.9 -- golden hour while recording (local only)
Config.RewardScale = 1
Config.RewardCarryScale = 0.55
Config.SlotScale = 1
Config.SlotLift = 0.4
Config.RewardYawOffset = 0
Config.DoorSlide = 2.5

Config.RiftColor = Color3.fromRGB(255, 205, 90)
Config.MachineColor = Color3.fromRGB(95, 224, 176)
Config.RevealColor = Color3.fromRGB(255, 211, 107)
Config.Shake = 1
Config.EffectDensity = 1.6
Config.ColorGrade = true

Config.Volume, Config.SoundGroup = 0.8, "SFX"
Config.HideTags = { "RiverEgg" }
Config.HideSurfaceGuis = true

Config.Animations = {
    Fall = "rbxassetid://507767968",
    Land = "",
    Idle = "rbxassetid://507766388",
    Look = "",
    Excited = "rbxassetid://507770677",
    Ready = "",
    Run = "rbxassetid://913376220",
    Stumble = "",
    Recover = "",
    Grab = "",
    Carry = "",
    Push = "",
    Lean = "",
    Place = "",
    Celebrate = "rbxassetid://507770677",
}
Config.Sounds = {
    Music = "",
    RiftOpen = "",
    Whoosh = "",
    Land = "",
    RiftClose = "",
    Glint = "",
    Footsteps = "",
    Stumble = "",
    Grab = "",
    Slam = "",
    Hum = "",
    Reveal = "",
    Place = "",
    Cheer = "",
}
return Config
