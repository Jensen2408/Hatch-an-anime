--[[ ReplicatedStorage.CharacterInventory.InventoryConfig  (ModuleScript)
Shared by the inventory server, the inventory screen and the hatch reveal.
Nothing here decides an outcome: Power, income and roll quality always come from the server
(CharacterEconomy). The client only chooses how to show them.
]]
local Config = {}

Config.RemoteName = "InventoryRequest" -- RemoteFunction (client asks, server answers)
Config.EventName = "InventoryEvent" -- RemoteEvent (server pushes snapshots and hatch reveals)
Config.PortraitFolder = "Portraits" -- display-only copies of the character models, made by the server

Config.Server = {
    -- true: placed characters can be taken back to the backpack ("STORE"), and PLACE BEST may swap a
    -- weaker placed character for a stronger one. false: PLACE BEST only fills empty unlocked slots.
    AllowStore = true,
    RequestsPerSecond = 4, -- per-player RemoteFunction rate limit
    RequestBurst = 8,
    PushInterval = 0.2, -- changes are batched into one snapshot per player per interval
}

-- Roll quality comes from the server (CharacterEconomy.Bands). These are the band *ranks* that get
-- the subtle "unusual roll" treatment. Rank 1 = Ordinary, 2 = Strong, 3 = Exceptional, 4 = Jackpot,
-- 5 = Ultra, 6 = Cosmic. If you add or reorder bands, only these two numbers need checking.
Config.NotableRank = 3
Config.TopRank = 5

Config.Rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Limited" }

Config.Sorts = {
    { Id = "Power", Label = "POWER" },
    { Id = "Income", Label = "INCOME/S" },
    { Id = "Rarity", Label = "RARITY" },
    { Id = "Newest", Label = "NEWEST" },
}

Config.Input = {
    ToggleKey = Enum.KeyCode.Unknown,
    ToggleGamepad = Enum.KeyCode.DPadLeft,
}

Config.Layout = {
    PanelMaxWidth = 1000,
    PanelMaxHeight = 600,
    CompactBelowWidth = 760, -- phones and small windows get the compact layout
    CompactBelowHeight = 520,
    Margin = 24, -- px kept free around the panel (compact: 8, plus the safe area)
    DetailsWidth = 288,
    Wide = { CardW = 148, CardH = 200, Gap = 8, Portrait = 102 },
    Compact = { CardW = 124, CardH = 172, Gap = 6, Portrait = 82 },
    BufferRows = 1, -- pooled rows kept above and below the visible area
}

Config.Reveal = {
    Delay = 0.9, -- after the server's reveal: the character is shown first, then its Power
    CountOrdinary = 0.75, -- number roll duration by roll quality
    CountNotable = 1.25,
    CountTop = 1.6,
    Hold = 3.4, -- seconds the final number stays on screen
    ParticlesNotable = 8,
    ParticlesTop = 14,
}

-- The shrine redesign in the plot temples' colours, same as the leaderboard (LeaderboardConfig.Theme):
-- a brown wood frame under a tile roof, gold bevel and studs, an embossed gold title, a dark-brown
-- wood page, cream cards with dark-brown ink, lacquer-brown buttons that turn taupe + gold.
local rgb = Color3.fromRGB
Config.Theme = {
    -- shell
    Panel = rgb(98, 70, 56), -- lacquer-brown frame
    PanelEdge = rgb(58, 40, 31),
    Bevel = rgb(232, 204, 140), -- gold top bevel
    Stud = rgb(196, 160, 86), -- gold studs
    Roof = rgb(86, 60, 46), -- tile roof over the panel
    RoofEdge = rgb(58, 40, 31),
    ShellTransparency = 0.04,

    -- dark-brown wood page (the temple posts) and the text that sits straight on it
    Screen = rgb(62, 44, 35),
    ScreenTop = rgb(78, 57, 46),
    PageTransparency = 0.06, -- barely see-through; cards stay solid
    PageText = rgb(244, 231, 204),
    PageMuted = rgb(222, 198, 156),
    PageFaint = rgb(196, 172, 136),
    PageWarn = rgb(240, 182, 100),
    PageUp = rgb(150, 228, 172),
    PageDown = rgb(242, 146, 126),

    -- cream cards (the temple walls)
    Card = rgb(244, 232, 210),
    CardHover = rgb(250, 242, 226),
    CardEdge = rgb(196, 168, 126),
    CardHi = rgb(255, 250, 238), -- 1 px top light on cards
    Inset = rgb(234, 220, 194), -- recessed wells inside cards
    Portrait = rgb(222, 198, 156),
    Locked = rgb(110, 84, 68), -- locked slot pips (on the dark page)

    -- dark-brown ink on cream
    Text = rgb(62, 42, 30),
    Muted = rgb(116, 88, 66),
    Faint = rgb(146, 118, 92),
    Ink = rgb(62, 42, 30), -- text on coloured chips, background of roll-quality chips
    Accent = rgb(226, 184, 96), -- selection (bright temple gold)

    -- buttons: lacquer brown at rest, taupe rafter + gold text when on, on a dark lip
    Chip = rgb(98, 70, 56),
    ChipOn = rgb(166, 120, 92),
    ButtonLip = rgb(40, 28, 22),
    ButtonText = rgb(255, 234, 178),
    ButtonTextDim = rgb(232, 214, 186),
    ButtonOff = rgb(84, 64, 52),

    -- primary (PLACE BEST / PLACE): the temples' gold trim
    Gold = rgb(214, 176, 96),
    GoldHi = rgb(240, 214, 150),
    GoldLo = rgb(146, 110, 48),
    GoldOff = rgb(122, 102, 72),

    -- states, darkened so they read on cream
    Income = rgb(38, 132, 76),
    IncomeTile = rgb(44, 92, 62), -- details panel income tile
    IncomeLight = rgb(176, 240, 196),
    Up = rgb(38, 132, 76),
    Down = rgb(184, 62, 48),
    Placed = rgb(132, 206, 150),
    Held = rgb(146, 186, 236),
    Warn = rgb(176, 104, 18),
    Rarity = {
        Common = rgb(190, 195, 205),
        Uncommon = rgb(109, 225, 132),
        Rare = rgb(98, 172, 255),
        Epic = rgb(197, 126, 255),
        Legendary = rgb(255, 207, 92),
        Limited = rgb(255, 60, 90),
    },
}

Config.Fonts = {
    Head = Font.new("rbxasset://fonts/families/FredokaOne.json"),
    Body = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
    Bold = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
    Heavy = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
}

return Config
