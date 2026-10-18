--[[ ReplicatedStorage.EggSteal.EggStealConfig  (ModuleScript, shared by server + client)
All tuning lives here. The server reads `Rules`; the client reads everything else.
Nothing in this file is trusted by the server for anything the client could change:
the client never sends a steal-related message, so there is nothing to spoof.
]]
local C = {}

-- ═══════════════════════════ SERVER RULES ═══════════════════════════
C.Rules = {
 Enabled = false, -- paused until Robux purchase flow is configured
	-- Prompt shown on another player's incubating egg
	PromptKey = Enum.KeyCode.F,          -- not E, so it never fights the Insert / Hatch / Collect prompts
	PromptHold = 0.7,
	PromptDistance = 11,
	MaxStealDistance = 18,               -- server re-checks the thief's distance when the prompt fires

	StealCooldown = 4,                   -- seconds a player must wait after any steal of theirs ended
	ChamberCooldown = 8,                 -- seconds a chamber is protected after a steal on it ended
	MaxCarrySeconds = 240,               -- failsafe: a steal that lasts longer is cancelled and returned

	-- Securing: the SERVER samples the thief every TickRate seconds (one shared loop for all steals)
	TickRate = 0.2,
	MinCarrySeconds = 1.5,               -- cannot be secured sooner than this, however close the base is
	MaxSpeed = 60,                       -- studs/s (horizontal) you consider legitimate, INCLUDING speed boosts
	SpeedSlack = 20,                     -- studs of burst allowance (lag spikes, launch pads)
	MaxViolations = 3,                   -- speed violations tolerated before the steal is cancelled
	HardTeleportDistance = 100,          -- one sample jumping further than this cancels the steal at once
	TravelFraction = 0.75,               -- thief must have legitimately walked 75% of the straight-line way to the base

	VictimUpdateRate = 0.5,              -- how often the egg's owner is sent the thief's position (seconds)
	VictimLeaves = "Continue",           -- owner leaves mid-steal: "Continue" (thief may still secure) or "Cancel"
	MirrorToStarterGear = true,          -- your conveyor also copies eggs into StarterGear; keep that behaviour for stolen eggs

	-- The base counts as "entered" inside this box, in the plot's TempleAnchor space (studs).
	-- Covers the temple, fence, chamber yard and spawn pad of a plot. Plots are 130+ studs apart.
	BaseMin = Vector3.new(-58, -15, -32),
	BaseMax = Vector3.new(32, 60, 48),

	StealableStatuses = { Incubating = true, Loaded = true }, -- chamber Status values that can be stolen from

	CarryOffset = CFrame.new(0, -0.15, -1.65), -- where the stolen egg rides on the thief's torso (back)
	CarryHeight = 2.4,                      -- studs tall
}

-- ═══════════════════════════ LOOK ═══════════════════════════
C.Colors = {
	Outline = Color3.fromRGB(20, 20, 25),    -- same dark outline as EggUIStyle
	Alert = Color3.fromRGB(255, 92, 62),     -- "EGG STOLEN!"
	Carry = Color3.fromRGB(216, 42, 66),     -- run-back state
	Victim = Color3.fromRGB(255, 150, 40),   -- "YOUR EGG IS BEING STOLEN!"
	Success = Color3.fromRGB(70, 195, 90),   -- same green as the pickup card
	Gold = Color3.fromRGB(255, 205, 70),
	Danger = Color3.fromRGB(255, 45, 65),    -- screen-edge pulse
	Base = Color3.fromRGB(86, 236, 152),     -- base waypoint
	Dark = Color3.fromRGB(24, 25, 36),
}

-- Same colours as EggCatalog. Unknown rarities fall back to Common.
C.RarityColors = {
	Common = Color3.fromRGB(205, 215, 225),
	Uncommon = Color3.fromRGB(110, 230, 135),
	Rare = Color3.fromRGB(90, 180, 255),
	Epic = Color3.fromRGB(195, 115, 255),
	Legendary = Color3.fromRGB(255, 200, 75),
	Mythic = Color3.fromRGB(255, 95, 150),
}
function C.RarityColor(rarity)
	return C.RarityColors[rarity] or C.RarityColors.Common
end

C.UI = {
	CardWidth = 372,
	CardHeight = 80,
	TopOffset = 12,
	DropTime = 0.42,            -- card drops in (Back easing = overshoot)
	EntranceHold = 1.45,        -- "EGG STOLEN!" stays this long, then becomes the run-back state
	SecureHold = 1.15,          -- "EGG SECURED!" stays this long before the egg flies to the backpack
	ShowValue = true,           -- show the egg's value on the card
	VignetteOpacityLow = 0.10,  -- danger edge pulse, 0 = invisible, 1 = solid. Kept subtle on purpose.
	VignetteOpacityHigh = 0.36,
	PulseSlow = 1.5,            -- seconds per pulse right after the steal ...
	PulseFast = 0.8,            -- ... easing to this over PulseRampSeconds
	PulseRampSeconds = 25,
	MetersPerStud = 1,          -- distance shown = studs * this. 0.28 would be "real" Roblox metres.
	Sparks = 14,
}

-- Built-in client sounds (verified to load). Replace with your own rbxassetid:// ids any time; "" = silent.
C.Sounds = {
	Beep = "rbxasset://sounds/electronicpingshort.wav",
	Thud = "rbxasset://sounds/bass.wav",
	Whoosh = "rbxasset://sounds/swordslash.wav",
	Success = "rbxasset://sounds/victory.wav",
	Chime = "rbxasset://sounds/button.wav",
}
C.Alarm = {
	Volume = 1,                 -- master multiplier for every steal sound
	InitialBeeps = 3,           -- BEEP — BEEP — BEEP
	BeepGap = 0.24,
	BeepVolume = 0.4,
	BeepSpeed = 1.3,
	PulseInterval = 3.6,        -- quiet reminder beep while carrying ...
	PulseMinInterval = 2.0,     -- ... easing to this the longer the run takes
	PulseVolume = 0.16,
	VictimVolume = 0.35,
	VictimRepeat = 5,           -- owner is reminded every few seconds while their egg is out
}

C.ClientFailsafeSeconds = 270   -- client removes everything if the server never says the steal ended

return C
