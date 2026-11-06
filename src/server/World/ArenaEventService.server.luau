--[[ ServerScriptService.ArenaEventService  (Script, server)
2: Arena Brawl: hourly (on the hour) bat-only PvP on a floating voxel platform (ReplicatedStorage.ArenaEvent.ArenaConfig).
Round: LOBBY -> COUNTDOWN -> FIGHT -> ENDED.
  * LOBBY: a portal opens outside every player's own plot. It exists only on that player's client (the server just
    publishes where it goes, in the Player attribute ArenaPortalCFrame). Walking into it fires ArenaEvent.Join; the
    server checks the player really is at their portal, registers them and teleports them onto the platform at once
    (after streaming it in). While they wait they are ArenaSafe (BatServer ignores hits on them), and their Podium
    Loadout UI opens so they can equip up to 3 characters from their plot podiums for character-based combat attributes.
  * COUNTDOWN: fighters are moved to the spawn ring and frozen. FIGHT: the outer tile rings crumble; knocked off = out.
  * Once a fighter is out (knocked off, died, left the arena, quit) they cannot rejoin that round: the portal is gone
    and Join is refused (Player attribute ArenaLocked).
Winner and knockouts earn cash.

The zone: a volcano cavern (platform, basalt wall, lava lake overhead, lava pit) thousands of studs from the map
(ArenaConfig.Center), built in Studio edit mode by ArenaZoneBuilder so it is visible in the editor. In the running game
this script moves it to ServerStorage at start-up, so it is not in the world at all, and clones a copy in for each brawl.

Authority: everything here. The client sends Join and EquipLoadout, and renders the attributes below.
Staff: script.Control (BindableFunction, server only) Invoke("Start" | "Stop", player) -> (ok, message), used by
OwnerPanelServer (panel actions StartArena / StopArena, AdminRoles.AdminActions) and the "/arena" chat command here
("/arena" opens a lobby, "/arena stop" cancels). Both check AdminRoles.Can(player, "StartArena" | "StopArena").
An admin round may run with a single fighter (testing); it pays no cash.

Replication (workspace attributes): ArenaPhase ("Idle" | "Lobby" | "Countdown" | "Fight" | "Ended"), ArenaEndsAt
(server time the phase ends), ArenaRegistered (joined), ArenaFighters (still standing), ArenaTotal (fighters that
started), ArenaShrinkAt (next ring drop, nil when none), ArenaWinner (display name), ArenaNextAt (next scheduled
brawl). Player attributes: ArenaPortalCFrame (where this player's portal stands; nil once they joined / are locked /
the lobby is over), ArenaIn (taking part and still in), ArenaKOs, ArenaSafe (waiting, cannot be hit), ArenaLocked
(out for this round), plus ArenaKnockbackMult, ArenaSwingSpeedMult, ArenaReachBonus, ArenaWalkSpeedMult,
ArenaKnockbackResist, ArenaRecoveryMult.
Knockout credit: BatServer stamps the victim's Player attributes LastBatHitBy (UserId) / LastBatHitAt (server time).
Remotes in ReplicatedStorage.ArenaEvent: Join (client -> server, no arguments), EquipLoadout (client -> server, {uid...}),
Fx (server -> client: "Notice" {text}, "Out" {place, total}, "Knockout" {name}, "Result" {place, kos, cash, won},
"LoadoutState" {available, equipped, combined, openUI}).
]]
-- ===== 1. Services, config, remotes =====
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")
local Debris = game:GetService("Debris")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local HttpService = game:GetService("HttpService")

local folder = ReplicatedStorage:WaitForChild("ArenaEvent")
local Config = require(folder:WaitForChild("ArenaConfig"))
local Catalog = require(ReplicatedStorage:WaitForChild("CharacterCatalog"))
local AdminRoles = require(script.Parent:WaitForChild("AdminRoles"))

local function remote(className, name)
    local existing = folder:FindFirstChild(name)
    if existing then
        return existing
    end
    local created = Instance.new(className)
    created.Name = name
    created.Parent = folder
    return created
end
local joinEvent = remote("RemoteEvent", "Join")
local equipEvent = remote("RemoteEvent", "EquipLoadout")
local fxEvent = remote("RemoteEvent", "Fx")
local oldLeave = folder:FindFirstChild("Leave") -- the HUD JOIN / LEAVE buttons are gone
if oldLeave then
    oldLeave:Destroy()
end
local control = script:FindFirstChild("Control") or Instance.new("BindableFunction")
control.Name = "Control"
control.Parent = script

-- Keep staff calls responsive while this release has Arena disabled.
if not Config.Enabled then
    workspace:SetAttribute("ArenaPhase", "Idle")
    workspace:SetAttribute("ArenaNextAt", nil)
    control.OnInvoke = function()
        return false, "Arena Brawl is disabled for this update."
    end
    return
end

local function announce(payload)
    local announcement = ReplicatedStorage:FindFirstChild("OwnerPanel")
        and ReplicatedStorage.OwnerPanel:FindFirstChild("Announcement")
    if announcement then
        payload.by = payload.by or "Server"
        announcement:FireAllClients(payload)
    end
end

local function setAttr(name, value)
    if workspace:GetAttribute(name) ~= value then
        workspace:SetAttribute(name, value)
    end
end

-- ===== 2. State =====
local state = {
    running = false,
    cancel = false,
    phase = "Idle",
    fighters = {}, -- [Player] = { alive, kos, joinedAt, returnCF, inArena, place, index, equippedUids, autoEquipped }
    locked = {}, -- [Player] = true: out for this round, cannot join again
    joinCounter = 0,
}
local savedLoadouts = {} -- [Player] = { uid1, uid2, uid3 } remembered across rounds
local arena -- { model, rings = { [ring] = { tile, ... } }, baseColors = { [tile] = Color3 } }

local COLOR_WARN = Color3.fromRGB(230, 60, 50)

local function count(predicate)
    local n = 0
    for player, info in state.fighters do
        if predicate == nil or predicate(player, info) then
            n += 1
        end
    end
    return n
end
local function aliveList()
    local list = {}
    for player, info in state.fighters do
        if info.alive then
            table.insert(list, player)
        end
    end
    return list
end

local function formatCash(amount)
    local text = tostring(math.floor(amount))
    while true do
        local replaced, n = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        text = replaced
        if n == 0 then
            break
        end
    end
    return text
end

local function setPhase(phase, seconds)
    state.phase = phase
    setAttr("ArenaPhase", phase)
    setAttr("ArenaEndsAt", seconds and (workspace:GetServerTimeNow() + seconds) or nil)
end

-- ===== 3. The platform and its volcano zone =====
local Builder = require(script.Parent:WaitForChild("ArenaZoneBuilder"))
local zoneTemplate = ServerStorage:FindFirstChild("PvPArenaTemplate")
local studioZone = workspace:FindFirstChild("PvPArena")
if studioZone then
    if zoneTemplate then
        zoneTemplate:Destroy()
    end
    studioZone.Name = "PvPArenaTemplate"
    studioZone.Parent = ServerStorage
    zoneTemplate = studioZone
end

local function buildArena()
    local old = workspace:FindFirstChild("PvPArena")
    if old then
        old:Destroy()
    end
    local model
    if zoneTemplate then
        model = zoneTemplate:Clone()
        model.Name = "PvPArena"
        model.Parent = workspace
    else
        model = Builder.Build(workspace)
    end
    local result = { model = model, rings = {}, baseColors = {} }
    for _, tile in model:WaitForChild("Tiles"):GetChildren() do
        local ring = tile:GetAttribute("Ring")
        if ring then
            result.baseColors[tile] = tile.Color
            result.rings[ring] = result.rings[ring] or {}
            table.insert(result.rings[ring], tile)
        end
    end
    arena = result
    return result
end

local function playArenaSfx(soundId, volume, speed)
    if not arena or not arena.model or not arena.model.Parent then
        return
    end
    local anchor = Instance.new("Part")
    anchor.Name = "ArenaRingSfx"
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.CanQuery = false
    anchor.CanTouch = false
    anchor.Transparency = 1
    anchor.Size = Vector3.one
    anchor.Position = Config.Center
    anchor.Parent = arena.model
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = volume or 0.8
    sound.PlaybackSpeed = speed or 1
    sound.RollOffMode = Enum.RollOffMode.InverseTapered
    sound.RollOffMinDistance = 30
    sound.RollOffMaxDistance = 260
    sound.Parent = anchor
    sound:Play()
    Debris:AddItem(anchor, 5)
end

-- Flashes a ring red for ShrinkWarn seconds, then lets it fall.
local function dropRing(ring)
    if not arena then
        return
    end
    local tiles = arena.rings[ring]
    local baseColors = arena.baseColors
    if not tiles then
        return
    end
    arena.rings[ring] = nil
    task.spawn(function()
        playArenaSfx("rbxassetid://9114463219", 0.55, 0.65)
        local started = os.clock()
        while os.clock() - started < Config.ShrinkWarn do
            local on = math.floor((os.clock() - started) * 4) % 2 == 0
            for _, tile in tiles do
                if tile.Parent then
                    tile.Color = on and COLOR_WARN or baseColors[tile]
                end
            end
            task.wait(0.1)
        end
        playArenaSfx("rbxassetid://9113220677", 0.85, 0.85)
        for _, tile in tiles do
            if tile.Parent then
                tile.Color = COLOR_WARN
                tile.Anchored = false
                TweenService:Create(
                    tile,
                    TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                    { Transparency = 1 }
                ):Play()
                Debris:AddItem(tile, 2.2)
            end
        end
    end)
end

-- ===== 4. Players, portals, podium loadouts, fighters =====
local function charParts(player)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if root and humanoid and humanoid.Health > 0 then
        return character, root, humanoid
    end
    return nil
end

local function findOwnedPlot(player)
    local plots = workspace:FindFirstChild("Plots")
    if not plots then
        return nil
    end
    for _, plot in plots:GetChildren() do
        if plot:GetAttribute("OwnerUserId") == player.UserId then
            return plot
        end
    end
    return nil
end

local function buildCharacterEntry(instance, slotNumber, sourceLabel)
    local rawId = instance:GetAttribute("CharacterId") or instance:GetAttribute("BrainrotId")
    local characterId = Catalog.CharacterId(rawId)
    if not characterId and (instance:GetAttribute("GoldVariant") or instance:GetAttribute("Golden")) then
        characterId = Catalog.CharacterId("Pirate")
    end
    local entry = characterId and Catalog.ById[characterId]
    if not entry or entry.IsEgg then
        return nil
    end
    local uid = instance:GetAttribute("ItemId")
    if type(uid) ~= "string" or uid == "" then
        uid = HttpService:GenerateGUID(false)
        instance:SetAttribute("ItemId", uid)
    end
    local mutation = instance:GetAttribute("Mutation")
    local golden = instance:GetAttribute("GoldVariant") == true or instance:GetAttribute("Golden") == true
    local buff = Config.GetCharacterBuff(characterId, mutation, golden)
    return {
        uid = uid,
        characterId = characterId,
        name = (golden and "Golden " or "") .. entry.Name,
        rarity = entry.Rarity,
        rarityRank = entry.RarityRank or 1,
        eggType = entry.EggType,
        mutation = mutation,
        golden = golden,
        slot = slotNumber,
        source = sourceLabel,
        power = tonumber(instance:GetAttribute("Power")) or 0,
        title = buff.title,
        stats = buff.stats,
        lines = buff.lines,
        shortLines = buff.shortLines,
    }
end

-- Scans characters placed on the player's plot podiums (PlacedItems), falling back to plot backpack/held characters if no podiums are occupied.
local function getPodiumCharacters(player)
    local list = {}
    local seenUids = {}
    local plot = findOwnedPlot(player)
    local placedItems = plot and plot:FindFirstChild("PlacedItems")
    if placedItems then
        for _, display in placedItems:GetChildren() do
            if display:IsA("Model") then
                local slotNum = tonumber(display.Name:match("Slot(%d+)")) or 99
                local item = buildCharacterEntry(display, slotNum, "PODIUM #" .. tostring(slotNum))
                if item and not seenUids[item.uid] then
                    seenUids[item.uid] = true
                    table.insert(list, item)
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if (a.slot or 99) ~= (b.slot or 99) then
            return (a.slot or 99) < (b.slot or 99)
        end
        return (a.rarityRank or 1) > (b.rarityRank or 1)
    end)

    -- Fallback: if no characters are currently placed on podiums, also check character tools in the player's plot inventory (Backpack/Character)
    if #list == 0 then
        local invIdx = 0
        for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
            if container then
                for _, child in container:GetChildren() do
                    if child:IsA("Tool") and not child:GetAttribute("EggType") and not child:GetAttribute("BatWeapon") then
                        invIdx += 1
                        local item = buildCharacterEntry(child, 100 + invIdx, "PLOT BAG")
                        if item and not seenUids[item.uid] then
                            seenUids[item.uid] = true
                            table.insert(list, item)
                        end
                    end
                end
            end
        end
        table.sort(list, function(a, b)
            if (a.rarityRank or 1) ~= (b.rarityRank or 1) then
                return (a.rarityRank or 1) > (b.rarityRank or 1)
            end
            return (a.power or 0) > (b.power or 0)
        end)
    end
    return list
end

local function getBaseWalkSpeed(player, info)
    local starterSpeed = tonumber(StarterPlayer.CharacterWalkSpeed)
    local base = (starterSpeed and starterSpeed > 0) and starterSpeed or 26
    local char = player and player.Character
    local scale = char and char:GetScale() or 1
    if type(scale) == "number" and scale > 0 then
        base = base * scale
    end
    if info and type(info.baseWalkSpeed) == "number" and info.baseWalkSpeed > base then
        return info.baseWalkSpeed
    end
    return base
end

local function applyArenaWalkSpeed(player)
    local _, _, humanoid = charParts(player)
    if not humanoid then
        return
    end
    local info = state.fighters[player]
    local baseSpeed = getBaseWalkSpeed(player, info)
    local mult = (player:GetAttribute("ArenaIn") and tonumber(player:GetAttribute("ArenaWalkSpeedMult"))) or 1
    humanoid.WalkSpeed = baseSpeed * math.clamp(mult, 1, 1.6)
end

local function clearArenaBuffs(player, info)
    if not player or not player.Parent then
        return
    end
    info = info or state.fighters[player]
    local hadArenaWalkSpeed = info ~= nil or player:GetAttribute("ArenaWalkSpeedMult") ~= nil
    player:SetAttribute("ArenaKnockbackMult", nil)
    player:SetAttribute("ArenaSwingSpeedMult", nil)
    player:SetAttribute("ArenaReachBonus", nil)
    player:SetAttribute("ArenaWalkSpeedMult", nil)
    player:SetAttribute("ArenaKnockbackResist", nil)
    player:SetAttribute("ArenaRecoveryMult", nil)
    if hadArenaWalkSpeed then
        local _, _, humanoid = charParts(player)
        if humanoid then
            humanoid.WalkSpeed = getBaseWalkSpeed(player, info)
        end
    end
end

local function syncPlayerLoadout(player, info, openUI)
    if not player or not player.Parent or not info then
        return
    end
    local available = getPodiumCharacters(player)
    local byUid = {}
    for _, item in ipairs(available) do
        byUid[item.uid] = item
    end

    local desired = info.equippedUids or savedLoadouts[player]
    local validUids = {}
    local equippedItems = {}
    local used = {}
    if type(desired) == "table" then
        for _, uid in ipairs(desired) do
            if
                type(uid) == "string"
                and byUid[uid]
                and not used[uid]
                and #validUids < Config.MaxEquippedCharacters
            then
                used[uid] = true
                table.insert(validUids, uid)
                table.insert(equippedItems, byUid[uid])
            end
        end
    end

    -- Auto-equip up to 3 best podium characters on initial portal entry if nothing valid was selected yet
    if #validUids == 0 and not info.autoEquipped and #available > 0 then
        local ranked = table.clone(available)
        table.sort(ranked, function(a, b)
            if (a.rarityRank or 1) ~= (b.rarityRank or 1) then
                return (a.rarityRank or 1) > (b.rarityRank or 1)
            end
            return (a.slot or 99) < (b.slot or 99)
        end)
        for i = 1, math.min(Config.MaxEquippedCharacters, #ranked) do
            local item = ranked[i]
            table.insert(validUids, item.uid)
            table.insert(equippedItems, item)
        end
    end
    info.autoEquipped = true
    info.equippedUids = validUids
    savedLoadouts[player] = validUids

    local combined = Config.CombineBuffs(equippedItems)
    local mults = combined.multipliers
    player:SetAttribute("ArenaKnockbackMult", mults.KnockbackMult)
    player:SetAttribute("ArenaSwingSpeedMult", mults.SwingSpeedMult)
    player:SetAttribute("ArenaReachBonus", mults.ReachBonus)
    player:SetAttribute("ArenaWalkSpeedMult", mults.WalkSpeedMult)
    player:SetAttribute("ArenaKnockbackResist", mults.KnockbackResist)
    player:SetAttribute("ArenaRecoveryMult", mults.RecoveryMult)
    applyArenaWalkSpeed(player)

    fxEvent:FireClient(player, "LoadoutState", {
        available = available,
        equipped = validUids,
        combined = combined,
        openUI = openUI == true,
    })
end

local function equipBat(player)
    local character, _, humanoid = charParts(player)
    if not character then
        return
    end
    for _, tool in character:GetChildren() do
        if tool:IsA("Tool") and tool:GetAttribute("BatWeapon") then
            return -- already holding a bat
        end
    end
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, tool in backpack:GetChildren() do
            if tool:IsA("Tool") and (tool:GetAttribute("BatWeapon") or tool.Name == "WoodenBat") then
                humanoid:EquipTool(tool)
                return
            end
        end
    end
end

local function sendHome(player, info)
    clearArenaBuffs(player, info)
    local _, root, humanoid = charParts(player)
    if not root or not info.returnCF then
        return -- dead players respawn at their plot on their own
    end
    humanoid.PlatformStand = false
    humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    root.Anchored = false
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.CFrame = info.returnCF + Vector3.new(0, 3, 0)
    pcall(function()
        root:SetNetworkOwnershipAuto()
    end)
end

-- Where this player's portal stands: in front of their own plot (nil if they have no plot yet).
local function portalFor(player)
    for _, plot in workspace.Plots:GetChildren() do
        local spawn = plot:FindFirstChild("PlotSpawn")
        if spawn and plot:GetAttribute("OwnerUserId") == player.UserId then
            local probe = Config.PortalCFrame(spawn.CFrame, spawn.Position.Y).Position
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            local ignore = {}
            for _, other in Players:GetPlayers() do
                if other.Character then
                    table.insert(ignore, other.Character)
                end
            end
            params.FilterDescendantsInstances = ignore
            local hit = workspace:Raycast(probe + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
            return Config.PortalCFrame(spawn.CFrame, hit and hit.Position.Y or spawn.Position.Y - 0.1)
        end
    end
    return nil
end

-- Publishes (or removes) each player's portal position. A portal exists only while the lobby is open and the player is
-- neither in the brawl nor locked out of it.
local function refreshPortals()
    for _, player in Players:GetPlayers() do
        local open = state.phase == "Lobby" and not state.fighters[player] and not state.locked[player]
        local current = player:GetAttribute("ArenaPortalCFrame")
        if open then
            if current == nil then
                local cframe = portalFor(player)
                if cframe then
                    player:SetAttribute("ArenaPortalCFrame", cframe)
                end
            end
        elseif current ~= nil then
            player:SetAttribute("ArenaPortalCFrame", nil)
        end
    end
end

-- Removes a player from the brawl. `lock` = they cannot join again this round. Players already on the platform are sent home.
local function dropFighter(player, notice, lock)
    local info = state.fighters[player]
    state.fighters[player] = nil
    if lock then
        state.locked[player] = true
    end
    if player.Parent then
        player:SetAttribute("ArenaIn", nil)
        player:SetAttribute("ArenaKOs", nil)
        player:SetAttribute("ArenaSafe", nil)
        clearArenaBuffs(player, info)
        if lock then
            player:SetAttribute("ArenaLocked", true)
        end
        if info and info.inArena then
            sendHome(player, info)
        end
        if notice then
            fxEvent:FireClient(player, "Notice", { text = notice })
        end
    end
    setAttr("ArenaRegistered", count())
end

local function eliminate(player, reason)
    local info = state.fighters[player]
    if not info or not info.alive then
        return
    end
    info.alive = false
    info.place = #aliveList() + 1
    state.locked[player] = true -- out for this round: no rejoining
    -- knockout credit for the last bat hit that landed recently
    if reason == "fell" then
        local by, at = player:GetAttribute("LastBatHitBy"), player:GetAttribute("LastBatHitAt")
        if by and at and workspace:GetServerTimeNow() - at <= Config.KnockoutCreditSeconds then
            local attacker = Players:GetPlayerByUserId(by)
            local attackerInfo = attacker and state.fighters[attacker]
            if attacker and attacker ~= player and attackerInfo and attackerInfo.alive then
                attackerInfo.kos += 1
                attacker:SetAttribute("ArenaKOs", attackerInfo.kos)
                fxEvent:FireClient(attacker, "Knockout", { name = player.DisplayName })
            end
        end
    end
    if player.Parent then
        player:SetAttribute("ArenaIn", false)
        player:SetAttribute("ArenaLocked", true)
        clearArenaBuffs(player, info)
        sendHome(player, info)
        fxEvent:FireClient(player, "Out", { place = info.place, total = state.total or 0, reason = reason })
    end
    setAttr("ArenaFighters", #aliveList())
end

local function givePayout(player, cash)
    local stats = player:FindFirstChild("leaderstats")
    local cashValue = stats and stats:FindFirstChild("Cash")
    if cashValue and cash > 0 then
        cashValue.Value += cash
    end
end

-- Teleports a freshly joined player onto the platform (streams it in around them first) and makes them safe from hits.
local function enterArena(player, info)
    syncPlayerLoadout(player, info, true)
    task.spawn(function()
        local deck = Config.LobbyCFrame(info.index)
        pcall(function()
            player:RequestStreamAroundAsync(deck.Position, 2.5)
        end)
        local _, root = charParts(player)
        if not (root and state.fighters[player] == info) then
            return
        end
        if state.phase ~= "Lobby" then
            return -- the countdown moves everyone to the spawn ring itself
        end
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = deck
        info.inArena = true
        player:SetAttribute("ArenaSafe", true)
        equipBat(player)
        applyArenaWalkSpeed(player)
        fxEvent:FireClient(player, "Notice", {
            text = "You're in the Arena Brawl! Equip up to 3 Podium Characters for battle attributes before the fight begins!",
        })
    end)
end

-- ===== 5. The round =====
local function cleanup(returnSurvivors)
    for player, info in state.fighters do
        if player.Parent and returnSurvivors and info.returnCF and info.alive and info.inArena then
            sendHome(player, info)
        end
    end
    for _, player in Players:GetPlayers() do
        player:SetAttribute("ArenaIn", nil)
        player:SetAttribute("ArenaKOs", nil)
        player:SetAttribute("ArenaSafe", nil)
        player:SetAttribute("ArenaLocked", nil)
        player:SetAttribute("ArenaPortalCFrame", nil)
        clearArenaBuffs(player)
    end
    state.fighters = {}
    state.locked = {}
    state.total = nil
    if arena then
        arena.model:Destroy()
        arena = nil
    end
    setPhase("Idle", nil)
    setAttr("ArenaShrinkAt", nil)
    setAttr("ArenaRegistered", 0)
    setAttr("ArenaFighters", 0)
    setAttr("ArenaTotal", 0)
end

local function runRound(starter, byAdmin)
    state.cancel = false
    state.fighters = {}
    state.locked = {}
    state.joinCounter = 0
    buildArena()
    setAttr("ArenaWinner", nil)
    setAttr("ArenaRegistered", 0)
    setAttr("ArenaFighters", 0)
    setAttr("ArenaTotal", 0)
    setPhase("Lobby", Config.LobbySeconds)
    refreshPortals()
    announce({
        title = "ARENA BRAWL PORTAL OPEN!",
        text = "A portal has opened outside your plot - walk in to join instantly! Bats only, last fighter standing wins, knockouts pay cash. Once you're knocked out there's no coming back. ("
            .. Config.LobbySeconds
            .. "s)",
        color = "red",
        by = starter and starter.DisplayName or nil,
    })

    -- lobby: portals stay open, joiners wait on the platform
    local lobbyEnds = workspace:GetServerTimeNow() + Config.LobbySeconds
    local lastRefresh = 0
    while workspace:GetServerTimeNow() < lobbyEnds and not state.cancel do
        for player, info in state.fighters do
            if not player.Parent then
                state.fighters[player] = nil
            elseif info.inArena then
                local _, root = charParts(player)
                if not root then
                    dropFighter(player, "You were knocked out before the fight, so you can't rejoin this brawl.", true)
                else
                    local offset = root.Position - Config.Center
                    local horizontal = Vector3.new(offset.X, 0, offset.Z).Magnitude
                    if horizontal > Config.OutsideRadius or offset.Y > 150 then
                        -- teleported away (e.g. the HOME button): out of this brawl for good
                        dropFighter(player, "You left the arena, so you can't rejoin this brawl.", true)
                    elseif offset.Y < -Config.FallDepth then
                        -- fell off the edge while waiting: put them back on the platform, no penalty
                        root.AssemblyLinearVelocity = Vector3.zero
                        root.CFrame = Config.LobbyCFrame(info.index)
                    end
                end
            end
        end
        if os.clock() - lastRefresh > 1 then
            lastRefresh = os.clock()
            refreshPortals()
        end
        setAttr("ArenaRegistered", count())
        task.wait(0.25)
    end
    if state.cancel then
        announce({ title = "ARENA BRAWL CANCELLED", text = "An admin cancelled the brawl.", color = "blue" })
        cleanup(true)
        return
    end

    -- who is still able to fight?
    local list = {}
    for player, _info in state.fighters do
        local character = charParts(player)
        if player.Parent and character then
            table.insert(list, player)
        else
            dropFighter(player, "You weren't ready when the fight began, so you're out of this brawl.", true)
        end
    end
    table.sort(list, function(a, b)
        return state.fighters[a].joinedAt < state.fighters[b].joinedAt
    end)
    if #list < (byAdmin and 1 or Config.MinPlayers) then
        announce({
            title = "ARENA BRAWL CANCELLED",
            text = "Not enough fighters joined. The next brawl is on the hour.",
            color = "blue",
        })
        cleanup(true)
        return
    end
    state.total = #list
    setAttr("ArenaTotal", #list)

    -- countdown: the portals close; everyone to the spawn ring, frozen
    setPhase("Countdown", Config.CountdownSeconds)
    refreshPortals()
    for k, player in list do
        local _, root = charParts(player)
        local info = state.fighters[player]
        if root and info then
            info.alive = true
            info.inArena = true
            root.Anchored = true
            root.AssemblyLinearVelocity = Vector3.zero
            root.CFrame = Config.SpawnCFrame(k, #list)
            player:SetAttribute("ArenaSafe", true)
            equipBat(player)
            player:SetAttribute("LastBatHitBy", nil)
            player:SetAttribute("LastBatHitAt", nil)
        elseif info then
            info.alive = false
            info.place = #list
        end
    end
    setAttr("ArenaFighters", #aliveList())
    local countdownEnds = workspace:GetServerTimeNow() + Config.CountdownSeconds
    while workspace:GetServerTimeNow() < countdownEnds and not state.cancel do
        task.wait(0.1)
    end
    for player in state.fighters do
        local _, root = charParts(player)
        if root then
            root.Anchored = false
        end
        player:SetAttribute("ArenaSafe", nil) -- the fight is on
        applyArenaWalkSpeed(player)
    end
    if state.cancel then
        announce({ title = "ARENA BRAWL CANCELLED", text = "An admin cancelled the brawl.", color = "blue" })
        cleanup(true)
        return
    end

    -- fight
    local fightStart = workspace:GetServerTimeNow()
    local fightEnds = fightStart + Config.FightSeconds
    setPhase("Fight", Config.FightSeconds)
    local nextRing, warned = 0, false
    local shrinkAt = fightStart + Config.ShrinkStart
    setAttr("ArenaShrinkAt", shrinkAt)
    local limit = state.total >= 2 and 1 or 0 -- a solo admin test runs until the fighter falls or time is up
    local timeUp = false
    while not state.cancel do
        local now = workspace:GetServerTimeNow()
        for player, info in state.fighters do
            if info.alive then
                local _, root = charParts(player)
                if not player.Parent then
                    state.fighters[player] = nil
                elseif not root then
                    eliminate(player, "died")
                else
                    local offset = root.Position - Config.Center
                    local horizontal = Vector3.new(offset.X, 0, offset.Z).Magnitude
                    if horizontal > Config.OutsideRadius or offset.Y > 150 then
                        eliminate(player, "left") -- e.g. teleported home with the HOME button (no knockout credit)
                    elseif offset.Y < -Config.FallDepth then
                        eliminate(player, "fell")
                    end
                end
            end
        end
        setAttr("ArenaFighters", #aliveList())
        if nextRing < Config.ShrinkRings then
            if not warned and now >= shrinkAt - Config.ShrinkWarn then
                warned = true
                dropRing(nextRing)
            end
            if now >= shrinkAt then
                nextRing += 1
                warned = false
                shrinkAt += Config.ShrinkEvery
                setAttr("ArenaShrinkAt", nextRing < Config.ShrinkRings and shrinkAt or nil)
            end
        end
        if #aliveList() <= limit then
            break
        end
        if now >= fightEnds then
            timeUp = true
            break
        end
        task.wait(0.1)
    end
    if state.cancel then
        announce({ title = "ARENA BRAWL CANCELLED", text = "An admin cancelled the brawl.", color = "blue" })
        cleanup(true)
        return
    end

    -- result
    local alive = aliveList()
    local winner
    if #alive >= 1 then
        table.sort(alive, function(a, b)
            return state.fighters[a].kos > state.fighters[b].kos
        end)
        winner = alive[1]
        state.fighters[winner].place = 1
        for i = 2, #alive do
            state.fighters[alive[i]].place = i
        end
    end
    local payouts = state.total >= 2
    for player, info in state.fighters do
        local won = player == winner
        local cash = 0
        if payouts then
            cash = Config.ParticipationCash + info.kos * Config.KnockoutCash + (won and Config.WinnerCash or 0)
            givePayout(player, cash)
        end
        if player.Parent then
            fxEvent:FireClient(
                player,
                "Result",
                { place = won and 1 or info.place or state.total, kos = info.kos, cash = cash, won = won }
            )
        end
    end
    setAttr("ArenaWinner", winner and winner.DisplayName or nil)
    setAttr("ArenaShrinkAt", nil)
    setPhase("Ended", 6)
    if winner then
        local kos = state.fighters[winner].kos
        announce({
            title = "ARENA BRAWL WINNER!",
            text = winner.DisplayName
                .. (timeUp and " wins on knockouts" or " is the last fighter standing")
                .. " with "
                .. kos
                .. (kos == 1 and " knockout" or " knockouts")
                .. (payouts and (" and takes $" .. formatCash(Config.WinnerCash) .. "!") or "!"),
            color = "gold",
        })
    else
        announce({ title = "ARENA BRAWL OVER", text = "Nobody was left standing.", color = "gold" })
    end
    local endedAt = workspace:GetServerTimeNow() + 6
    while workspace:GetServerTimeNow() < endedAt and not state.cancel do
        task.wait(0.25)
    end
    cleanup(true)
end

local function startRound(starter, byAdmin)
    if state.running then
        return false
    end
    state.running = true
    task.spawn(function()
        local ok, err = pcall(runRound, starter, byAdmin)
        if not ok then
            warn("[ArenaEvent] round failed: " .. tostring(err))
            pcall(cleanup, true)
        end
        state.running = false
        state.cancel = false
    end)
    return true
end

-- ===== 6. Player requests =====
local lastJoinTry = {}
local lastEquipTry = {}

equipEvent.OnServerEvent:Connect(function(player, requestedUids)
    local info = state.fighters[player]
    if not info or not info.alive then
        return
    end
    if os.clock() - (lastEquipTry[player] or -1) < 0.12 then
        return
    end
    lastEquipTry[player] = os.clock()
    if type(requestedUids) ~= "table" then
        return
    end
    local cleaned = {}
    for i = 1, math.min(#requestedUids, Config.MaxEquippedCharacters) do
        local uid = requestedUids[i]
        if type(uid) == "string" and #uid <= 64 then
            table.insert(cleaned, uid)
        end
    end
    info.equippedUids = cleaned
    info.autoEquipped = true
    syncPlayerLoadout(player, info, false)
end)

joinEvent.OnServerEvent:Connect(function(player)
    if state.phase ~= "Lobby" or state.fighters[player] or state.locked[player] then
        return
    end
    if os.clock() - (lastJoinTry[player] or -1) < 0.5 then
        return
    end
    lastJoinTry[player] = os.clock()
    local endsAt = workspace:GetAttribute("ArenaEndsAt")
    if endsAt and endsAt - workspace:GetServerTimeNow() < 1.5 then
        return -- too late: the countdown is about to start
    end
    local portal = player:GetAttribute("ArenaPortalCFrame")
    local _, root = charParts(player)
    if typeof(portal) ~= "CFrame" or not root then
        return
    end
    if (root.Position - portal.Position).Magnitude > Config.PortalJoinRange then
        return -- not actually at their portal
    end
    if count() >= Config.MaxPlayers then
        fxEvent:FireClient(player, "Notice", { text = "The arena is full." })
        return
    end
    if player:GetAttribute("RiverEggCarryId") then
        fxEvent:FireClient(player, "Notice", { text = "Secure your egg at home before you join!" })
        return
    end
    state.joinCounter += 1
    local _, _, joinHumanoid = charParts(player)
    local currentSpeed = joinHumanoid and tonumber(joinHumanoid.WalkSpeed)
    local baseWalkSpeed = (currentSpeed and currentSpeed >= 20 and currentSpeed)
        or tonumber(StarterPlayer.CharacterWalkSpeed)
        or 26
    local info = {
        alive = true,
        kos = 0,
        joinedAt = os.clock(),
        returnCF = root.CFrame,
        inArena = false,
        index = state.joinCounter,
        equippedUids = savedLoadouts[player],
        autoEquipped = false,
        baseWalkSpeed = baseWalkSpeed,
    }
    state.fighters[player] = info
    player:SetAttribute("ArenaIn", true)
    player:SetAttribute("ArenaKOs", 0)
    player:SetAttribute("ArenaPortalCFrame", nil)
    setAttr("ArenaRegistered", count())
    enterArena(player, info)
end)

Players.PlayerRemoving:Connect(function(player)
    lastJoinTry[player] = nil
    lastEquipTry[player] = nil
    savedLoadouts[player] = nil
    state.locked[player] = nil
    if state.phase == "Lobby" then
        state.fighters[player] = nil
        setAttr("ArenaRegistered", count())
    end
end)

-- ===== 7. Staff controls =====
local function controlAction(action, player)
    if action == "Start" then
        if state.running then
            return false, "An arena brawl is already running."
        end
        startRound(player, true)
        return true, "Arena Brawl portals opened (" .. Config.LobbySeconds .. " seconds to join)."
    elseif action == "Stop" then
        if not state.running then
            return false, "No arena brawl is running."
        end
        state.cancel = true
        return true, "Arena Brawl cancelled."
    end
    return false, "Unknown arena action."
end
control.OnInvoke = controlAction
local command = TextChatService:FindFirstChild("ArenaEventCommand") or Instance.new("TextChatCommand")
command.Name = "ArenaEventCommand"
command.PrimaryAlias = "/arena"
command.Parent = TextChatService
command.Triggered:Connect(function(source, text)
    local player = source and Players:GetPlayerByUserId(source.UserId)
    if not player then
        return
    end
    local stopping = tostring(text):lower():find("stop") ~= nil
    if not AdminRoles.Can(player, stopping and "StopArena" or "StartArena") then
        return
    end
    local _, message = controlAction(stopping and "Stop" or "Start", player)
    local announcement = ReplicatedStorage:FindFirstChild("OwnerPanel")
        and ReplicatedStorage.OwnerPanel:FindFirstChild("Announcement")
    if announcement and message then
        announcement:FireClient(player, { title = "ARENA", text = message, color = "blue", by = "Server" })
    end
end)

-- ===== 8. Schedule =====
local startedFor
while true do
    local now = workspace:GetServerTimeNow()
    local nextAt = Config.NextScheduled(now)
    local previousAt = nextAt - Config.CycleSeconds
    setAttr("ArenaNextAt", nextAt)
    if startedFor == nil then
        startedFor = previousAt -- a server that boots mid-slot skips it
    end
    if startedFor ~= previousAt and now - previousAt < 10 then
        startedFor = previousAt
        if #Players:GetPlayers() > 0 and not state.running then
            startRound(nil, false)
        end
    end
    task.wait(0.5)
end
