--[[ ReplicatedStorage.GameMenu.Config  (ModuleScript, shared)
Everything you tune lives here. Quest and shop entries below are SAMPLE DATA; replace them with your real balance.
]]
local Config = {}

Config.MaxViewports = 16 -- live 3D previews at once; the rest show a flat colour tile

-- Quests. period = "Daily" | "Weekly" | "Monthly". objective must match a QuestService.Increment(...) call.
-- reward = { cash = number } (add your own reward types in GameMenuServer → HOOKS.GrantReward)
Config.Quests = {
    {
        id = "d_hatch5",
        period = "Daily",
        order = 1,
        title = "Hatch 5 eggs",
        description = "Finish hatches in any incubator.",
        objective = "HatchEgg",
        target = 5,
        reward = { cash = 500 },
    },
    {
        id = "d_river10",
        period = "Daily",
        order = 2,
        title = "Collect 10 river eggs",
        description = "Grab eggs as they float by.",
        objective = "CollectRiverEgg",
        target = 10,
        reward = { cash = 1000 },
    },
    {
        id = "d_income3",
        period = "Daily",
        order = 3,
        title = "Collect income 3 times",
        description = "Step on your money plates.",
        objective = "CollectIncome",
        target = 3,
        reward = { cash = 250 },
    },
    {
        id = "d_place2",
        period = "Daily",
        order = 4,
        title = "Place 2 characters",
        description = "Put characters on stands.",
        objective = "PlaceCharacter",
        target = 2,
        reward = { cash = 500 },
    },
    {
        id = "w_discover3",
        period = "Weekly",
        order = 1,
        title = "Discover 3 new characters",
        description = "Hatch characters you've never had.",
        objective = "DiscoverCharacter",
        target = 3,
        reward = { cash = 2500 },
    },
    {
        id = "w_upgrade1",
        period = "Weekly",
        order = 2,
        title = "Upgrade your temple",
        description = "Buy one temple or incubator upgrade.",
        objective = "Upgrade",
        target = 1,
        reward = { cash = 5000 },
    },
    {
        id = "m_hatch250",
        period = "Monthly",
        order = 1,
        title = "Hatch 250 eggs",
        description = "Any egg counts.",
        objective = "HatchEgg",
        target = 250,
        reward = { cash = 25000 },
    },
}

-- Shop. kind = "cash" (server checks + spends cash) or "robux" (developer product / gamepass).
-- Leave productId / gamePassId nil to show "Coming soon" with purchasing disabled.
-- endsAt = os.time() value; a countdown only shows when this is set.
Config.Shop = {
    -- VIP items go here, e.g.
    -- { id = "pass_2x", name = "2x Income", description = "Double income", kind = "robux", gamePassId = 123 },
}
Config.Banner = { title = "Hatch an Anime", subtitle = "Find your next character", image = nil } -- SAMPLE; image = "rbxassetid://..."
Config.ShopTabs = { "Featured", "Eggs & Characters", "Passes & Extras" }

-- Optional sounds. Uses official Roblox created and ProSoundEffects licensed audio.
Config.Sounds = {
    Open = "rbxassetid://9126047777", -- Synth Air Whoosh (ProSoundEffects)
    Press = "rbxassetid://126436524243242", -- PaperPick (smghte) - crisp paper card tap
    Hover = "rbxassetid://82896519916504", -- paper-turnpage0 (D_9173)
    Success = "rbxassetid://112485797063762", -- UI - Level Up (SodaBreadle)
    Claim = "rbxassetid://90531793028786", -- Cash Register (Kaching) (HMP STUDIO'S) - satisfying coin gain ching
    CoinRustle = "rbxassetid://107132538017055", -- coins-sound-effect-1-full-pack (Akin_TR) - natural acoustic coins rustling
    Shine = "rbxassetid://9119447936", -- Sparkle Bell Tree Wind Chimes (ProSoundEffects)
    EggCrack = "rbxassetid://9113959343", -- Crack Egg Crunchy (ProSoundEffects)
}
Config.Volume = 0.5

-- Unused leftover of the old local formatter (Short now delegates to InventoryFormat); kept as-is.
local _LEGACY_UNITS = { { 1e18, "Qi" }, { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
-- Shared number style; InventoryFormat is required on first call, not at module load.
function Config.Short(n)
    return require(game:GetService("ReplicatedStorage").CharacterInventory.InventoryFormat).Short(n)
end
-- 1234567.6 -> "1,234,568" (rounded; non-numbers count as 0).
function Config.Full(n)
    local digits = tostring(math.floor((tonumber(n) or 0) + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (digits:gsub("^,", ""))
end

-- Quest periods use server UTC time.
-- Key that identifies the current Daily / Weekly / Monthly period for a timestamp (progress resets when it changes).
function Config.PeriodKey(period, timestamp)
    local date = os.date("!*t", timestamp)
    if period == "Daily" then
        return ("%d-%d"):format(date.year, date.yday)
    end
    if period == "Weekly" then
        -- Unix day 0 was a Thursday; +3 shifts week boundaries to Monday.
        return ("%d-W%d"):format(date.year, math.floor((timestamp / 86400 + 3) / 7))
    end -- weeks start Monday 00:00 UTC
    return ("%d-%d"):format(date.year, date.month)
end
-- Unix time at which the period containing `timestamp` ends.
function Config.PeriodEnds(period, timestamp)
    if period == "Daily" then
        return (math.floor(timestamp / 86400) + 1) * 86400
    end
    if period == "Weekly" then
        local weekIndex = math.floor((timestamp / 86400 + 3) / 7)
        return math.floor(((weekIndex + 1) * 7 - 3) * 86400)
    end
    local date = os.date("!*t", timestamp)
    local year, month = date.year, date.month + 1
    if month > 12 then
        year, month = year + 1, 1
    end
    -- Roblox game servers run on UTC, so os.time() of a date table is a UTC timestamp
    return os.time({ year = year, month = month, day = 1, hour = 0, min = 0, sec = 0 })
end

return Config
