--[[ River boss authority: one downstream trip, bat-swing hits, damaging slam and podium theft on escape.
Clients render the shared route; no client Hit remote can damage the boss.
BatHit is a server-only BindableFunction called by WoodenBat's authoritative hit window.
Admin Stop cancels the event without taking a character. ]]
-- ===== 1. Services, modules, remotes =====
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")

local folder = ReplicatedStorage:WaitForChild("BossEvent")
local Config = require(folder:WaitForChild("BossConfig"))
local Catalog = require(ReplicatedStorage:WaitForChild("CharacterCatalog"))
local Timing = require(ReplicatedStorage:WaitForChild("EggHatchTiming"))
local AdminRoles = require(script.Parent:WaitForChild("AdminRoles"))
local Mutations = require(script.Parent:WaitForChild("Mutations"))
local RiverCarry = require(script.Parent:WaitForChild("RiverEggCarryService"))
local Inventory = require(script.Parent:WaitForChild("CharacterInventory"):WaitForChild("InventoryService"))
local Breakables = require(script.Parent:WaitForChild("BossBreakables")) -- props tagged "BossBreakable" break when touched

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
local legacyHit = folder:FindFirstChild("Hit")
if legacyHit then legacyHit:Destroy() end
local batHit = script:FindFirstChild("BatHit") or Instance.new("BindableFunction")
batHit.Name = "BatHit"
batHit.Parent = script
local fxEvent = remote("RemoteEvent", "Fx")
local control = script:FindFirstChild("Control") or Instance.new("BindableFunction")
control.Name = "Control"
control.Parent = script

local function announce(payload)
    local announcement = ReplicatedStorage:FindFirstChild("OwnerPanel")
        and ReplicatedStorage.OwnerPanel:FindFirstChild("Announcement")
    if announcement then
        payload.by = payload.by or "Server"
        announcement:FireAllClients(payload)
    end
end

-- ===== 2. Reward egg =====
local function rewardSource()
    local pack = ServerStorage:FindFirstChild("UpdatePack_Mutations")
    return pack and pack:FindFirstChild(Config.RewardEggModel, true)
end
-- Display copy for the clients (no scripts, nothing physical).
do
    local source = rewardSource()
    local old = folder:FindFirstChild("RareEgg")
    if old then
        old:Destroy()
    end
    if source then
        local display = source:Clone()
        display.Name = "RareEgg"
        for _, descendant in display:GetDescendants() do
            if descendant:IsA("BaseScript") then
                descendant:Destroy()
            elseif descendant:IsA("BasePart") then
                descendant.Anchored = true
                descendant.CanCollide = false
                descendant.CanTouch = false
                descendant.CanQuery = false
            end
        end
        display.Parent = folder
    else
        warn("[BossEvent] reward egg model missing: " .. Config.RewardEggModel)
    end
end

-- Builds the reward Tool the same way the river does (PirateEggFreeConveyor), mutated egg visual + aura.
local function rewardTool()
    local entry = Catalog.ById[Config.RewardEggType]
    local base = ServerStorage.AuxEggTemplates:FindFirstChild(Config.RewardEggType)
    local source = rewardSource() or base
    assert(entry and source, "Boss reward egg unavailable.")
    local tool = Instance.new("Tool")
    tool.Name = Config.RewardMutation .. " " .. entry.Id .. " Egg"
    tool.CanBeDropped = false
    Catalog.Stamp(tool, entry)
    tool:SetAttribute("EggType", entry.Id)
    tool:SetAttribute("Mutation", Config.RewardMutation)
    tool:SetAttribute("Price", entry.Price)
    tool:SetAttribute("HatchSeconds", Timing.Seconds(entry.Id))
    tool:SetAttribute("BossReward", true)
    tool.ToolTip = entry.Rarity .. " • Boss reward"
    local visual = source:Clone()
    visual.Name = "Egg"
    if base then
        local _, baseSize = base:GetBoundingBox()
        local _, size = visual:GetBoundingBox()
        visual:ScaleTo(visual:GetScale() * baseSize.Y / math.max(size.Y, 0.01))
    end
    visual:ScaleTo(visual:GetScale() * 0.5)
    visual:PivotTo(CFrame.new())
    visual.Parent = tool
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.one
    handle.Transparency = 1
    handle.CanCollide = false
    handle.Massless = true
    handle.Parent = tool
    for _, part in visual:GetDescendants() do
        if part:IsA("BasePart") then
            part.Anchored = false
            part.CanCollide = false
            part.CanTouch = false
            part.Massless = true
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = handle
            weld.Part1 = part
            weld.Parent = handle
        elseif part:IsA("BaseScript") then
            part:Destroy()
        end
    end
    pcall(Mutations.AddAura, visual, Config.RewardMutation)
    return tool
end

-- ===== 3. Event state =====
local active = nil -- { epoch, endsAt, hp, maxHp, damage = {[userId] = n}, names = {}, lastSlam }
local lastHitAt, stunnedUntil = {}, {}
local hitSwings = setmetatable({}, { __mode = "k" })
local topDirty = false

local function setAttr(name, value)
    if workspace:GetAttribute(name) ~= value then
        workspace:SetAttribute(name, value)
    end
end

local function topList(limit)
    local list = {}
    for userId, damage in active.damage do
        table.insert(list, { userId = userId, name = active.names[userId], damage = damage })
    end
    table.sort(list, function(a, b)
        return a.damage > b.damage
    end)
    local top = {}
    for i = 1, math.min(limit, #list) do
        top[i] = list[i]
    end
    return top, list
end

local function finish(state)
    if not active or workspace:GetAttribute("BossState") ~= "Walking" then
        return
    end
    local event = active
    setAttr("BossState", state)
    setAttr("BossEndedAt", workspace:GetServerTimeNow())
    task.delay(state == "Defeated" and 8 or Config.SinkSeconds + 1, function()
        if active == event then
            active = nil
            setAttr("BossActive", false)
            setAttr("BossState", nil)
            Breakables.RestoreAll(Config.BreakRespawnSeconds) -- the boss is gone: the broken bridges come back
        end
    end)
end

local function defeat()
    local _, ranked = topList(3)
    local winner
    for _, row in ranked do
        local player = Players:GetPlayerByUserId(row.userId)
        if player and player:FindFirstChildOfClass("Backpack") then
            winner = player
            break
        end
    end
    finish("Defeated")
    fxEvent:FireAllClients("Defeated", { winnerId = winner and winner.UserId, winnerName = winner and winner.DisplayName })
    if not winner then
        announce({ title = "RIVER BOSS DEFEATED!", text = "The rare egg washed away...", color = "gold" })
        return
    end
    local ok, err = pcall(function()
        local tool = rewardTool()
        tool.Parent = winner:FindFirstChildOfClass("Backpack")
        local carried, carryErr = pcall(RiverCarry.Begin, winner, tool)
        if not carried then
            tool.Enabled = true
            tool:SetAttribute("ReturningToBase", nil)
            warn("[BossEvent] carry: " .. tostring(carryErr))
        end
    end)
    if not ok then
        warn("[BossEvent] reward failed: " .. tostring(err))
    end
    announce({
        title = "RIVER BOSS DEFEATED!",
        text = winner.DisplayName
            .. " dealt the most damage and wins the "
            .. Config.RewardMutation
            .. " "
            .. Config.RewardEggType
            .. " Egg!",
        color = "gold",
    })
end

local function start(byName)
    if active then
        return false, "The river boss is already out."
    end
    local now = workspace:GetServerTimeNow()
    local maxHp = Config.MaxHealth(#Players:GetPlayers())
    active = { epoch = now, endsAt = now + math.min(Config.EventSeconds, Config.RouteSeconds), hp = maxHp, maxHp = maxHp, damage = {}, names = {} }
    table.clear(lastHitAt)
    table.clear(stunnedUntil)
    table.clear(hitSwings)
    setAttr("BossEpoch", now)
    setAttr("BossEndsAt", active.endsAt)
    setAttr("BossEndedAt", nil)
    setAttr("BossStolenCharacter", nil)
    setAttr("BossStolenFrom", nil)
    setAttr("BossMaxHP", maxHp)
    setAttr("BossHP", maxHp)
    setAttr("BossTop", "[]")
    setAttr("BossState", "Walking")
    setAttr("BossActive", true)
    announce({
        title = "RIVER BOSS APPEARS!",
        text = "A giant guardian is wading down the river with a "
            .. Config.RewardMutation
            .. " "
            .. Config.RewardEggType
            .. " Egg! Swing your bat to attack! Stop it before it steals a podium character!",
        color = "red",
        by = byName,
    })
    return true, "River boss started (" .. maxHp .. " HP, " .. math.ceil(active.endsAt - now) .. " seconds to escape)."
end

local function stop()
    if not active or workspace:GetAttribute("BossState") ~= "Walking" then
        return false, "No boss is walking right now."
    end
    finish("Cancelled")
    return true, "River boss cancelled; no character taken."
end

-- ===== 4. Authoritative bat hit window (no client damage remote) =====
batHit.OnInvoke = function(player, tool, swingTick)
    if not active or workspace:GetAttribute("BossState") ~= "Walking" then return false end
    local now = workspace:GetServerTimeNow()
    local t = now - active.epoch
    if t < Config.EmergeSeconds or now >= active.endsAt then return false end
    if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then return false end
    local character = player.Character
    -- any bat tier (WeaponGiver stamps BatWeapon / BossDamage / SwingCooldown on the server-side templates)
    if typeof(tool) ~= "Instance" or not tool:IsA("Tool")
        or (tool.Name ~= "WoodenBat" and tool:GetAttribute("BatWeapon") ~= true)
        or tool.Parent ~= character or not tool:FindFirstChild("BatServer") then return false end
    if type(swingTick) ~= "number" or tool:GetAttribute("SwingTick") ~= swingTick
        or now - swingTick < 0.1 or now - swingTick > 0.55 or hitSwings[tool] == swingTick then return false end
    local hitCooldown = math.min(Config.HitCooldown, tonumber(tool:GetAttribute("SwingCooldown")) or Config.HitCooldown)
    if now - (lastHitAt[player] or -1e9) < hitCooldown - 0.03
        or now < (stunnedUntil[player] or 0) then return false end
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then return false end
    local feet, phase, _, progress = Config.Pose(t)
    if phase == "exited" then return false end
    local half = Config.HitHalfSize
    local center = feet * CFrame.new(0, half.Y, 0)
    if phase == "crawl" then
        half = Vector3.new(13.5, 7, 19)
        center = feet * CFrame.new(0, 6 - Config.CrawlDrop * math.clamp(progress * 4, 0, 1), -7)
    end
    local localPoint = center:PointToObjectSpace(root.Position)
    local closest = center:PointToWorldSpace(Vector3.new(
        math.clamp(localPoint.X, -half.X, half.X),
        math.clamp(localPoint.Y, -half.Y, half.Y),
        math.clamp(localPoint.Z, -half.Z, half.Z)))
    if (root.Position - closest).Magnitude > Config.HitRange then return false end
    local toward = feet.Position - root.Position
    local flat = Vector3.new(toward.X, 0, toward.Z)
    local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
    if flat.Magnitude > 1 and (look.Magnitude < 0.01 or look.Unit:Dot(flat.Unit) < Config.HitArcCos) then return false end
    hitSwings[tool] = swingTick
    lastHitAt[player] = now
    local damage = math.min(active.hp, tonumber(tool:GetAttribute("BossDamage")) or Config.HitDamage)
    active.hp -= damage
    active.damage[player.UserId] = (active.damage[player.UserId] or 0) + damage
    active.names[player.UserId] = player.DisplayName
    topDirty = true
    setAttr("BossHP", active.hp)
    fxEvent:FireClient(player, "Hit", { position = closest, damage = damage })
    if active.hp <= 0 then defeat() end
    return true
end
Players.PlayerRemoving:Connect(function(player)
    lastHitAt[player] = nil
    stunnedUntil[player] = nil
end)

-- ===== 5. Staff controls =====
control.OnInvoke = function(action, player)
    if action == "Start" then
        return start(player and player.DisplayName or nil)
    elseif action == "Stop" then
        return stop()
    end
    return false, "Unknown boss action."
end
local command = TextChatService:FindFirstChild("BossEventCommand") or Instance.new("TextChatCommand")
command.Name = "BossEventCommand"
command.PrimaryAlias = "/boss"
command.Parent = TextChatService
command.Triggered:Connect(function(source, text)
    local player = source and Players:GetPlayerByUserId(source.UserId)
    if not player then
        return
    end
    local stopping = tostring(text):lower():find("stop") ~= nil
    if not AdminRoles.Can(player, stopping and "StopBoss" or "StartBoss") then
        return
    end
    local _, message = (stopping and stop or start)(player.DisplayName)
    local announcement = ReplicatedStorage:FindFirstChild("OwnerPanel")
        and ReplicatedStorage.OwnerPanel:FindFirstChild("Announcement")
    if announcement and message then
        announcement:FireClient(player, { title = "BOSS", text = message, color = "blue", by = "Server" })
    end
end)

-- ===== 6. Clock: schedule, warning, slam stuns, escape, damage board =====
local warnedFor, startedFor = nil, nil
local lastTopAt = 0
while true do
    local now = workspace:GetServerTimeNow()
    local nextAt = Config.NextScheduled(now)
    local previousAt = nextAt - Config.CycleSeconds
    setAttr("BossNextAt", nextAt)
    if warnedFor ~= nextAt and nextAt - now <= Config.WarnSeconds and #Players:GetPlayers() > 0 and not active then
        warnedFor = nextAt
        announce({
            title = "THE RIVER STIRS...",
            text = "The river boss rises in " .. math.ceil(nextAt - now) .. " seconds! Gather at the river!",
            color = "tide",
        })
    end
    -- a scheduled slot that started in the last few seconds (servers that boot mid-slot skip it)
    if startedFor == nil then
        startedFor = previousAt
    end
    if startedFor ~= previousAt and now - previousAt < 10 then
        startedFor = previousAt
        if #Players:GetPlayers() > 0 then
            start(nil)
        end
    end
    if active and workspace:GetAttribute("BossState") == "Walking" then
        local t = now - active.epoch
        local feet, phase, _, slamTime = Config.Pose(t)
        -- the boss's body smashes any BossBreakable prop (the river bridges) it walks into
        if phase ~= "exited" and t >= Config.EmergeSeconds then
            Breakables.Touch(
                feet * CFrame.new(0, Config.BreakHalfSize.Y, 0),
                Config.BreakHalfSize * 2,
                feet.Position
            )
        end
        if phase == "slam" and slamTime >= Config.SlamImpactAt then
            local slamIndex = math.floor((t - Config.EmergeSeconds) / Config.StepSeconds)
            if active.lastSlam ~= slamIndex then
                active.lastSlam = slamIndex
                for _, player in Players:GetPlayers() do
                    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                    if root and humanoid and humanoid.Health > 0 then
                        local offset = root.Position - feet.Position
                        if Vector2.new(offset.X, offset.Z).Magnitude <= Config.SlamRadius
                            and math.abs(offset.Y) <= Config.SlamVerticalRange
                            and not player.Character:FindFirstChildOfClass("ForceField") then
                            stunnedUntil[player] = now + Config.StunSeconds
                            humanoid:TakeDamage(Config.SlamDamage)
                            local flat = Vector3.new(offset.X, 0, offset.Z)
                            local away = flat.Magnitude > 0.1 and flat.Unit or -feet.LookVector
                            pcall(function() root:SetNetworkOwner(nil) end)
                            humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
                            root.AssemblyLinearVelocity = away * Config.SlamLaunchOut + Vector3.yAxis * Config.SlamLaunchUp
                            fxEvent:FireClient(player, "SlamHit")
                            task.delay(0.5, function()
                                if root.Parent then pcall(function() root:SetNetworkOwnershipAuto() end) end
                            end)
                        end
                    end
                end
            end
        end
        if phase == "exited" or now >= active.endsAt then
            -- Mark finished before the penalty; repeated ticks cannot take another character.
            finish("Escaped")
            local ok, stolen = pcall(Inventory.TakeRandomPlacedCharacter)
            if not ok then
                warn("[BossEvent] escape penalty failed: " .. tostring(stolen))
                stolen = nil
            end
            if stolen then
                setAttr("BossStolenCharacter", stolen.characterName)
                setAttr("BossStolenFrom", stolen.userId)
            end
            announce({
                title = "THE RIVER BOSS ESCAPED!",
                text = stolen and ("It stole " .. stolen.playerName .. "'s " .. stolen.characterName .. " from their podium!")
                    or "It escaped through the river outlet. No occupied podium character was available.",
                color = "purple",
            })
        end
    end
    if active and topDirty and os.clock() - lastTopAt > 0.5 then
        topDirty = false
        lastTopAt = os.clock()
        local top = topList(3)
        local rows = {}
        for i, row in top do
            rows[i] = { name = row.name, damage = row.damage }
        end
        setAttr("BossTop", HttpService:JSONEncode(rows))
    end
    task.wait(0.1)
end

