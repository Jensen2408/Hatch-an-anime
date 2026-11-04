--[[ ReplicatedStorage.ArenaEvent.ArenaConfig  (ModuleScript, shared)
Arena Brawl: a bat-only, last-one-standing PvP event on a floating voxel platform high above the map.
Shared by ServerScriptService.ArenaEventService (authority) and StarterPlayerScripts.ArenaEventClient (HUD).

Round (server time): LOBBY (a portal opens outside each player's own plot, visible only to them; walking in teleports
them onto the platform at once, where they wait, safe from bat hits) -> COUNTDOWN (fighters moved to the spawn ring and
frozen) -> FIGHT (outer tile rings crumble away from ShrinkStart, one ring every ShrinkEvery) -> ENDED. A fighter is
out when they leave the platform volume (fall off), die, quit, or leave the server, and cannot rejoin that round. The last
fighter standing wins; at the time limit the fighter with the most knockouts wins.
Every fighter uses the bat they have equipped in the shop, so higher bat tiers (knockback / reach / swing speed)
matter here.
]]
local Config = {}

-- ===== Schedule =====
Config.CycleSeconds = 3600 -- one scheduled brawl per hour...
Config.OffsetSeconds = 0 -- ...on the hour (the river boss is at :30)
Config.LobbySeconds = 60 -- the portal is open this long; joining is instant (walk in), the fight starts when it ends
Config.CountdownSeconds = 5
Config.FightSeconds = 150
Config.MinPlayers = 2 -- a scheduled / admin round with fewer fighters is cancelled when the lobby closes
Config.MaxPlayers = 16

-- ===== Join portal (one per player, built only on that player's own client) =====
Config.PortalDistance = 14 -- studs out from the plot's spawn, away from the temple (open ground, checked for every plot)
Config.PortalJoinRange = 18 -- the server accepts a join when the player is this close to their portal

-- ===== Platform =====
Config.Center = Vector3.new(6000, 300, 6000) -- top surface of the platform; thousands of studs from the map (the map spans about +-1100)
-- The volcano zone around it (ServerScriptService.ArenaZoneBuilder): a basalt cavern under a lava lake, over a lava pit.
Config.CavernRadius = 100 -- inner radius of the basalt wall
Config.LavaDepth = 50 -- the lava pit surface this far below the platform top
Config.CavernHeight = 95 -- the lava lake (ceiling) this far above the platform top
Config.LavaRadius = 240 -- the animated lava sea (ArenaLava client script) reaches this far, under the walls
Config.ZoneRadius = 270 -- the client volcano lighting applies within this flat distance of Center
Config.TileSize = 6 -- whole studs, so the stud material lines up
Config.Grid = 16 -- 16 x 16 grid trimmed to a circular disc of diameter 96 studs
Config.PlatformRadius = 48 -- outer radius of the circular voxel platform
Config.TileHeight = 2
Config.FallDepth = 14 -- out when this far below the platform top
Config.OutsideRadius = 130 -- out when this far from the centre horizontally (e.g. teleported home)
Config.SpawnRadius = 30
Config.ShrinkStart = 25 -- seconds into the fight
Config.ShrinkEvery = 16
Config.ShrinkWarn = 3 -- tiles flash red this long before they drop
Config.ShrinkRings = 4 -- outer circular rings that crumble (rings 4 and 5 in the centre never do)
Config.RingRadii = { 40, 32, 24, 16, 10 } -- inner radial thresholds for rings 0..4 (<= 10 is the circular gold centre)

-- ===== Rewards (cash; paid only when 2+ players fought) =====
Config.ParticipationCash = 2500
Config.KnockoutCash = 5000
Config.WinnerCash = 50000
Config.KnockoutCreditSeconds = 8 -- a fall counts as the last bat hit if it came this recently

-- ===== Podium Character Loadout (equip up to 3 characters from your plot podiums) =====
Config.MaxEquippedCharacters = 3

Config.StatOrder = { "Knockback", "SwingSpeed", "Reach", "MoveSpeed", "Steady", "Recovery" }

Config.StatDefs = {
    Knockback = {
        Label = "Knockback",
        Short = "KNOCKBACK",
        Color = Color3.fromRGB(255, 136, 88),
        Cap = 75,
        Format = "+%d%% Knockback",
        ShortFormat = "+%d%% KB",
    },
    SwingSpeed = {
        Label = "Swing Speed",
        Short = "SWING SPD",
        Color = Color3.fromRGB(255, 214, 96),
        Cap = 65,
        Format = "+%d%% Swing Speed",
        ShortFormat = "+%d%% SWING",
    },
    Reach = {
        Label = "Bat Reach",
        Short = "REACH",
        Color = Color3.fromRGB(116, 212, 255),
        Cap = 60,
        Format = "+%d%% Bat Reach",
        ShortFormat = "+%d%% REACH",
    },
    MoveSpeed = {
        Label = "Move Speed",
        Short = "SPEED",
        Color = Color3.fromRGB(132, 236, 164),
        Cap = 45,
        Format = "+%d%% Move Speed",
        ShortFormat = "+%d%% SPD",
    },
    Steady = {
        Label = "Stability",
        Short = "STABILITY",
        Color = Color3.fromRGB(198, 160, 255),
        Cap = 55,
        Format = "-%d%% Knockback Taken",
        ShortFormat = "+%d%% POISE",
    },
    Recovery = {
        Label = "Recovery",
        Short = "RECOVERY",
        Color = Color3.fromRGB(255, 164, 210),
        Cap = 70,
        Format = "+%d%% Stand-Up Speed",
        ShortFormat = "+%d%% RECOV",
    },
}

Config.MutationBonus = {
    Silver = 1.10,
    Gold = 1.20,
    Diamond = 1.35,
    Rainbow = 1.50,
}

-- Per-character Arena passive title + base stat percentages for all 46 characters in CharacterCatalog.
Config.CharacterBuffs = {
    -- Tier 1: Common (Pirate, Shinobi, Power)
    Luffy = { Title = "Gum-Gum Whip", Stats = { Reach = 10, Steady = 8 } },
    Zoro = { Title = "Three-Sword Strike", Stats = { Knockback = 10, SwingSpeed = 7 } },
    Nami = { Title = "Tailwind Tempo", Stats = { MoveSpeed = 8, Recovery = 10 } },
    Naruto = { Title = "Shadow Clone Rush", Stats = { MoveSpeed = 7, Knockback = 9 } },
    Sasuke = { Title = "Chidori Blitz", Stats = { SwingSpeed = 10, MoveSpeed = 7 } },
    Kakashi = { Title = "Sharingan Reflex", Stats = { Reach = 8, Recovery = 10 } },
    Goku = { Title = "Kamehameha Impact", Stats = { Knockback = 11, SwingSpeed = 7 } },
    Vegeta = { Title = "Galick Barrage", Stats = { SwingSpeed = 10, Knockback = 8 } },
    Piccolo = { Title = "Namekian Guard", Stats = { Steady = 10, Reach = 9 } },

    -- Tier 2: Uncommon (Hero, Slayer, Curse)
    Deku = { Title = "Full Cowling Dash", Stats = { MoveSpeed = 10, Knockback = 11 } },
    Bakugo = { Title = "Howitzer Blast", Stats = { Knockback = 14, SwingSpeed = 8 } },
    Todoroki = { Title = "Glacier Wall", Stats = { Steady = 13, Reach = 9 } },
    Tanjiro = { Title = "Hinokami Dance", Stats = { SwingSpeed = 11, Knockback = 11 } },
    Nezuko = { Title = "Demon Resilience", Stats = { Recovery = 15, Steady = 10 } },
    Zenitsu = { Title = "Thunderclap Flash", Stats = { MoveSpeed = 13, SwingSpeed = 10 } },
    Itadori = { Title = "Black Flash", Stats = { Knockback = 13, Recovery = 11 } },
    Gojo = { Title = "Infinity Barrier", Stats = { Steady = 14, Reach = 11 } },
    Sukuna = { Title = "Malevolent Cleave", Stats = { Reach = 12, SwingSpeed = 11 } },

    -- Tier 3: Rare (Soul, Titan, Magic)
    Ichigo = { Title = "Getsuga Slash", Stats = { Knockback = 15, SwingSpeed = 12 } },
    Rukia = { Title = "Absolute Zero", Stats = { Steady = 14, Recovery = 14 } },
    Byakuya = { Title = "Senbonzakura Petal", Stats = { Reach = 15, SwingSpeed = 11 } },
    Eren = { Title = "Titan Momentum", Stats = { Knockback = 16, Steady = 13 } },
    Mikasa = { Title = "Ackerman Instinct", Stats = { MoveSpeed = 13, SwingSpeed = 13 } },
    Levi = { Title = "Spinning Blades", Stats = { SwingSpeed = 16, MoveSpeed = 12 } },
    Asta = { Title = "Demon-Slayer Smash", Stats = { Knockback = 16, Recovery = 13 } },
    Yuno = { Title = "Spirit Dive Gale", Stats = { MoveSpeed = 14, Reach = 13 } },
    Noelle = { Title = "Valkyrie Dress", Stats = { Steady = 15, MoveSpeed = 11 } },

    -- Tier 4: Epic (Academy, Devil, Guild)
    Saitama = { Title = "Serious Punch", Stats = { Knockback = 20, Steady = 14 } },
    Genos = { Title = "Incinerate Jet", Stats = { SwingSpeed = 16, MoveSpeed = 14 } },
    Tatsumaki = { Title = "Psychic Tornado", Stats = { Reach = 18, Knockback = 14 } },
    Denji = { Title = "Chainsaw Frenzy", Stats = { SwingSpeed = 17, Recovery = 16 } },
    Power = { Title = "Blood Hammer", Stats = { Knockback = 18, SwingSpeed = 13 } },
    Makima = { Title = "Force Control", Stats = { Reach = 16, Steady = 16 } },
    Natsu = { Title = "Fire Dragon Fist", Stats = { Knockback = 19, Recovery = 14 } },
    Lucy = { Title = "Celestial Ward", Stats = { Steady = 17, MoveSpeed = 13 } },
    Erza = { Title = "Titania Blade", Stats = { Reach = 16, SwingSpeed = 16 } },

    -- Tier 5: Legendary (Sports, Mecha, God)
    HinataCourt = { Title = "Freak Quick Step", Stats = { MoveSpeed = 18, Recovery = 18 } },
    Isagi = { Title = "Direct Shot Vision", Stats = { Reach = 17, Knockback = 18 } },
    Kuroko = { Title = "Phantom Misdirection", Stats = { MoveSpeed = 17, SwingSpeed = 18 } },
    Shinji = { Title = "AT-Field Sync", Stats = { Steady = 20, Recovery = 17 } },
    Asuka = { Title = "Unit-02 Blitz", Stats = { SwingSpeed = 19, Knockback = 17 } },
    Lelouch = { Title = "Absolute Geass", Stats = { Reach = 19, Steady = 17 } },
    SunGod = { Title = "Drums of Liberation", Stats = { Knockback = 22, Reach = 18, MoveSpeed = 10 } },
    MoonGoddess = { Title = "Lunar Gravity", Stats = { Steady = 22, Reach = 18, Recovery = 12 } },
    CosmicOracle = { Title = "Astral Overdrive", Stats = { SwingSpeed = 20, MoveSpeed = 16, Knockback = 14 } },

    -- Tier 6: Limited (Unknown)
    HinataHyuga = { Title = "Twin Lion Fists", Stats = { SwingSpeed = 22, Knockback = 20, Steady = 15 } },
}

-- Returns the resolved buff info for a single character instance (accounting for Mutation / Golden).
function Config.GetCharacterBuff(characterId, mutation, golden)
    local raw = Config.CharacterBuffs[characterId] or {
        Title = "Fighter Spirit",
        Stats = { Knockback = 8, MoveSpeed = 6 },
    }
    local mult = (mutation and Config.MutationBonus[mutation]) or (golden and 1.20) or 1
    local stats = {}
    local lines = {}
    local shortLines = {}
    for _, key in ipairs(Config.StatOrder) do
        local baseVal = raw.Stats[key]
        if baseVal and baseVal > 0 then
            local scaled = math.floor(baseVal * mult + 0.5)
            stats[key] = scaled
            local def = Config.StatDefs[key]
            table.insert(lines, string.format(def.Format, scaled))
            table.insert(shortLines, {
                stat = key,
                text = string.format(def.ShortFormat, scaled),
                fullText = string.format(def.Format, scaled),
                color = def.Color,
                value = scaled,
            })
        end
    end
    return {
        title = raw.Title,
        stats = stats,
        lines = lines,
        shortLines = shortLines,
        mutationMultiplier = mult,
    }
end

-- Combines up to Config.MaxEquippedCharacters podium items into total percentages and gameplay multipliers.
function Config.CombineBuffs(items)
    local totals = {}
    for _, key in ipairs(Config.StatOrder) do
        totals[key] = 0
    end
    for i, item in ipairs(items or {}) do
        if i > Config.MaxEquippedCharacters then
            break
        end
        local buff = Config.GetCharacterBuff(item.characterId, item.mutation, item.golden)
        for key, val in pairs(buff.stats) do
            local cap = Config.StatDefs[key] and Config.StatDefs[key].Cap or 100
            totals[key] = math.min(cap, (totals[key] or 0) + val)
        end
    end

    local summary = {}
    for _, key in ipairs(Config.StatOrder) do
        local val = totals[key] or 0
        if val > 0 then
            local def = Config.StatDefs[key]
            table.insert(summary, {
                stat = key,
                label = def.Label,
                short = def.Short,
                value = val,
                text = string.format(def.Format, val),
                shortText = string.format(def.ShortFormat, val),
                color = def.Color,
            })
        end
    end

    return {
        totals = totals,
        summary = summary,
        multipliers = {
            KnockbackMult = 1 + (totals.Knockback or 0) / 100,
            SwingSpeedMult = 1 + (totals.SwingSpeed or 0) / 100,
            ReachBonus = 8 * ((totals.Reach or 0) / 100),
            WalkSpeedMult = 1 + (totals.MoveSpeed or 0) / 100,
            KnockbackResist = (totals.Steady or 0) / 100,
            RecoveryMult = 1 + (totals.Recovery or 0) / 100,
        },
    }
end

-- ===== Helpers =====
-- Server time of the next scheduled brawl after `now`.
function Config.NextScheduled(now)
    return (math.floor((now - Config.OffsetSeconds) / Config.CycleSeconds) + 1) * Config.CycleSeconds
        + Config.OffsetSeconds
end

-- Tile centre (world) for a 1-based grid cell.
function Config.TileCenter(row, col)
    local half = Config.Grid * Config.TileSize / 2
    return Vector3.new(
        Config.Center.X - half + (col - 0.5) * Config.TileSize,
        Config.Center.Y - Config.TileHeight / 2,
        Config.Center.Z - half + (row - 0.5) * Config.TileSize
    )
end

-- Tile ring (0 = outer circular edge .. 5 = gold centre) for a 1-based grid cell, or nil if outside the circular platform.
function Config.RingOf(row, col)
    local half = Config.Grid * Config.TileSize / 2
    local dx = (col - 0.5) * Config.TileSize - half
    local dz = (row - 0.5) * Config.TileSize - half
    local dist = math.sqrt(dx * dx + dz * dz)
    if dist > Config.PlatformRadius then
        return nil
    end
    for index, threshold in Config.RingRadii do
        if dist > threshold then
            return index - 1
        end
    end
    return #Config.RingRadii
end

-- The player's portal: PortalDistance studs in front of their plot's spawn (the spawn faces the temple, so "in front" is
-- the opposite way), standing on `groundY`, its opening facing the plot (LookVector points at the plot).
function Config.PortalCFrame(spawnCFrame, groundY)
    local look = spawnCFrame.LookVector
    local away = Vector3.new(-look.X, 0, -look.Z)
    away = away.Magnitude > 0.01 and away.Unit or Vector3.zAxis
    local position = Vector3.new(spawnCFrame.Position.X, groundY, spawnCFrame.Position.Z) + away * Config.PortalDistance
    return CFrame.lookAt(position, position - away)
end

-- Where the k-th player to join stands on the platform while waiting for the fight (spread around the middle).
function Config.LobbyCFrame(k)
    local angle = k * 2.399963
    local radius = 4 + (k % 4) * 3
    local position = Config.Center + Vector3.new(math.cos(angle) * radius, 4, math.sin(angle) * radius)
    return CFrame.lookAt(position, Vector3.new(Config.Center.X, position.Y, Config.Center.Z))
end

-- Fighter spawn k of n: on a circle, facing the middle, a little above the tiles.
function Config.SpawnCFrame(k, n)
    local angle = (k - 1) / math.max(n, 1) * math.pi * 2
    local position = Config.Center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * Config.SpawnRadius + Vector3.yAxis * 4
    return CFrame.lookAt(position, Vector3.new(Config.Center.X, position.Y, Config.Center.Z))
end

return Config
