--[[ ReplicatedStorage.Leaderboard.LeaderboardConfig  (ModuleScript)
Shared by the server, the physical board and the expanded screen.
]]
local Config = {}

Config.Tag = "LeaderboardBoard"          -- CollectionService tag on every board Model
Config.RemoteName = "LeaderboardRequest" -- RemoteFunction, created by the server inside this folder
Config.MaxRows = 50

-- Order = tab order. Kind picks the number format (see LeaderboardFormat).
Config.Stats = {
	{
		Id = "Cash", Tab = "CASH", Column = "CASH", Kind = "money",
		Empty = "Collect cash from your money stands to appear here.",
	},
	{
		Id = "Income", Tab = "INCOME / SEC", Column = "PER SEC", Kind = "rate",
		Empty = "Place characters on your temple to start earning.",
	},
	{
		Id = "Hatches", Tab = "EGGS HATCHED", Column = "HATCHES", Kind = "count",
		Empty = "Hatch an egg to claim the first spot.",
	},
}
Config.StatById = {}
for _, stat in Config.Stats do Config.StatById[stat.Id] = stat end

Config.Server = {
	ServerRefresh = 3,          -- seconds between THIS SERVER ranking rebuilds
	GlobalRead = 120,           -- seconds between OrderedDataStore reads per stat
	GlobalRetry = 45,           -- seconds before retrying a failed global read
	GlobalIdleAfter = 300,      -- stop reading a global stat nobody has looked at for this long
	GlobalFetchSize = 100,      -- how deep YOUR RANK can see on GLOBAL (one request, max 100)
	GlobalWrite = 90,           -- seconds between a player's score writes (only when changed)
	FirstWriteDelay = 30,       -- first write after joining (lets Cash/plots settle)
	WritesPerTick = 8,          -- max players flushed per 5 s tick
	WriteReserve = 12,          -- keep this much write budget for players leaving / shutdown
	StoreVersion = "v1",
	SeparateStudioStores = true, -- Studio play-tests write to "*_Studio" stores, never the live ones
	IncludeIncomeMultiplier = false, -- true = multiply by workspace.OwnerIncomeMultiplier (owner events)
	RequestsPerSecond = 3,      -- per-player RemoteFunction rate limit
	RequestBurst = 6,
}

Config.Client = {
	PollServer = 4,             -- seconds between THIS SERVER refreshes while a board is in view
	PollGlobal = 30,            -- the server only re-reads global every GlobalRead seconds anyway
	RetryAfterError = 6,
	ActiveDistance = 80,        -- studs from the camera; farther boards do not poll
	CloseDistance = 40,         -- the expanded view closes when you walk this far from the board
	PanelMaxWidth = 780,        -- same proportions as the wider board
	PanelMaxHeight = 760,
	CompactBelowHeight = 520,   -- phones in landscape get the compact layout
	CompactBelowWidth = 430,
	CompactCornerReserve = 110, -- px kept free at each side on phones (Roblox menu / chat buttons)
	PixelsPerStud = 100,         -- board canvas: a 16 x 14 stud screen = 800 x 700 px
}

local rgb = Color3.fromRGB
-- The shrine redesign (frame with gold studs and a tile roof, embossed gold title, lip tabs,
-- cream rows, medals, a pinned YOUR RANK card) in the plot temples' colours: dark-brown wood,
-- cream walls, taupe rafters, a brown roof and the temples' gold trim. Tokens keep the shrine
-- names (Crimson = the selected / highlight wood, Charcoal = the resting wood).
Config.Theme = {
	-- game style: cream panels, gold frame, red/white buttons, chunky outlined text (matches the HUD)
	Frame = rgb(232, 168, 60),
	FrameDark = rgb(176, 112, 34),
	Stud = rgb(255, 214, 96),
	Bevel = rgb(255, 232, 160),
	Trim = rgb(255, 196, 64),
	Roof = rgb(214, 62, 54),
	RoofEdge = rgb(138, 32, 30),
	Screen = rgb(250, 230, 188),

	WoodTop = rgb(255, 240, 206), Wood = rgb(250, 228, 184),
	PageText = rgb(82, 46, 18), PageSoft = rgb(128, 84, 42), PageFaint = rgb(156, 112, 66),
	Well = rgb(240, 208, 150), WellEdge = rgb(206, 156, 82),
	Scroll = rgb(226, 164, 64),

	Charcoal = rgb(255, 244, 220), CharcoalLow = rgb(240, 216, 170), CharcoalLip = rgb(186, 132, 64),
	Crimson = rgb(236, 74, 62), CrimsonLow = rgb(204, 52, 46), CrimsonLip = rgb(128, 26, 24),
	TabText = rgb(116, 72, 30), TabTextOn = rgb(255, 255, 255),

	Cream = rgb(255, 251, 240), CreamAlt = rgb(255, 241, 214), CreamEdge = rgb(230, 186, 112), CreamLip = rgb(196, 140, 66),
	Ink = rgb(64, 36, 14), InkSoft = rgb(124, 82, 42), InkFaint = rgb(158, 116, 70),
	Paper = rgb(255, 246, 226),
	Avatar = rgb(255, 226, 170),

	Gold = rgb(250, 184, 40), GoldLight = rgb(255, 228, 120), GoldDeep = rgb(206, 132, 18), GoldInk = rgb(96, 52, 8),
	Accent = rgb(250, 184, 40),

	YouText = rgb(255, 255, 255), YouSub = rgb(255, 232, 200),

	Medal = {
		{ rgb(255, 222, 92), rgb(222, 150, 20), rgb(110, 62, 0), rgb(255, 244, 196) },
		{ rgb(240, 246, 255), rgb(150, 170, 196), rgb(54, 66, 86), rgb(240, 244, 250) },
		{ rgb(255, 196, 140), rgb(208, 120, 60), rgb(110, 54, 16), rgb(255, 230, 206) },
	},
}

return Config
