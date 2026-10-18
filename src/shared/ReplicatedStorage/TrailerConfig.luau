-- ReplicatedStorage.TrailerConfig: settings for the recording-only trailer (/trailer or F7)
local C = {}
C.OwnerIds = { [168774222] = true }
C.AllowInStudio = false -- only the user IDs in OwnerIds can run the trailer, even in Studio
C.Command, C.StopCommand, C.Key = "/trailer", "/trailerstop", Enum.KeyCode.F7
C.StartDelay = 3

C.MarkersFolder = "Workspace/TrailerMarkers"
C.MarkerPlot = "Workspace/Plots/TemplePlot01" -- markers were placed around this plot; they move to the plot you own
C.AutoPlot = true
C.PlotsFolder = "Workspace/Plots"
C.PlotOwnerAttributes = { "OwnerUserId", "Owner", "OwnerId", "UserId" }
C.IncubatorNames = { "Chamber1" }
C.SlotNames = { "Slot0", "Slot1", "Slot2", "Slot3", "Slot4" }
C.EntranceNames = { "Entrance", "Gate" }
C.Models = {
	PirateEgg = "ReplicatedStorage/GameMenu/EggPreviews/MenuEgg_Pirate",
	Reward = "ReplicatedStorage/CharacterInventory/Portraits/Pirate",
	Incubator = "auto", -- Chamber1 on the plot you own
}
C.TitleText = "HATCH AN ANIME"
C.TaglineText = "Catch it. Hatch it. Collect them all."
C.OutroText = "PLAY NOW ON ROBLOX"
C.Durations = { Intro = 7, RiftArrival = 9, SpotEgg = 7, Chase = 10, BringHome = 9, Hatch = 9, Place = 9 }

C.EggScale = 1
C.EggHeight = 3.4 -- egg is auto-sized to this many studs tall
C.RewardHeight = 5 -- hatched character height
C.ClockTime = 16.9 -- golden hour while recording (local only)
C.RewardScale = 1
C.RewardCarryScale = 0.55
C.SlotScale = 1
C.SlotLift = 0.4
C.RewardYawOffset = 0
C.DoorSlide = 2.5

C.RiftColor = Color3.fromRGB(255, 205, 90)
C.MachineColor = Color3.fromRGB(95, 224, 176)
C.RevealColor = Color3.fromRGB(255, 211, 107)
C.Shake = 1
C.EffectDensity = 1.6
C.ColorGrade = true

C.Volume, C.SoundGroup = 0.8, "SFX"
C.HideTags = { "RiverEgg" }
C.HideSurfaceGuis = true

C.Animations = { Fall = "rbxassetid://507767968", Land = "", Idle = "rbxassetid://507766388", Look = "", Excited = "rbxassetid://507770677", Ready = "", Run = "rbxassetid://913376220", Stumble = "", Recover = "",
	Grab = "", Carry = "", Push = "", Lean = "", Place = "", Celebrate = "rbxassetid://507770677" }
C.Sounds = { Music = "", RiftOpen = "", Whoosh = "", Land = "", RiftClose = "", Glint = "", Footsteps = "", Stumble = "",
	Grab = "", Slam = "", Hum = "", Reveal = "", Place = "", Cheer = "" }
return C
