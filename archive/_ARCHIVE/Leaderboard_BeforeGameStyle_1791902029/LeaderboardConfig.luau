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
	-- expanded-view shell (LeaderboardClient): brown frame, gold bevel + studs, brown roof
	Frame = rgb(98, 70, 56),
	FrameDark = rgb(74, 54, 44),
	Stud = rgb(196, 160, 86),
	Bevel = rgb(232, 204, 140),
	Trim = rgb(196, 160, 86),
	Roof = rgb(86, 60, 46),
	RoofEdge = rgb(58, 40, 31),
	Screen = rgb(62, 44, 35),

	-- page (dark-brown wood, the temple posts) and its text
	WoodTop = rgb(78, 57, 46), Wood = rgb(62, 44, 35),
	PageText = rgb(244, 231, 204), PageSoft = rgb(222, 198, 156), PageFaint = rgb(196, 172, 136),
	Well = rgb(46, 32, 25), WellEdge = rgb(32, 22, 17),
	Scroll = rgb(146, 104, 80),

	-- tabs and buttons: resting = lacquer brown, selected = taupe rafter with gold text
	Charcoal = rgb(98, 70, 56), CharcoalLow = rgb(80, 57, 45), CharcoalLip = rgb(40, 28, 22),
	Crimson = rgb(166, 120, 92), CrimsonLow = rgb(132, 92, 70), CrimsonLip = rgb(74, 52, 40),
	TabText = rgb(232, 214, 186), TabTextOn = rgb(255, 234, 178),

	-- cream rows (the temple walls) and their ink
	Cream = rgb(244, 232, 210), CreamAlt = rgb(232, 214, 182), CreamEdge = rgb(196, 168, 126), CreamLip = rgb(146, 104, 80),
	Ink = rgb(62, 42, 30), InkSoft = rgb(116, 88, 66), InkFaint = rgb(146, 118, 92),
	Paper = rgb(244, 231, 204),
	Avatar = rgb(222, 198, 156),

	-- the temples' gold trim
	Gold = rgb(196, 160, 86), GoldLight = rgb(238, 212, 148), GoldDeep = rgb(146, 110, 48), GoldInk = rgb(70, 48, 22),
	Accent = rgb(196, 160, 86),

	-- YOUR RANK card text
	YouText = rgb(255, 246, 228), YouSub = rgb(240, 220, 186),

	-- { badge top, badge edge, number ink, row background }
	Medal = {
		{ rgb(255, 230, 160), rgb(206, 160, 70), rgb(112, 76, 20), rgb(252, 240, 204) },
		{ rgb(255, 255, 255), rgb(169, 179, 193), rgb(62, 70, 82), rgb(240, 238, 234) },
		{ rgb(255, 217, 181), rgb(196, 136, 90), rgb(116, 66, 32), rgb(248, 228, 208) },
	},
}

return Config
