--[[ ServerScriptService.PirateEggFreeConveyor  (Script, SERVER)
The river: spawns paid eggs that roll along workspace.PirateEggConveyor (path/pose from its RollingMotion module)
into workspace.WaterfallEggs, on a steady cadence (conveyor attribute SpawnInterval, default 4 s, clamped 1.5..30).
Which egg: RiverEggSpawnScheduler (weighted rarity) + natural Halloween mutation roll (Mutations.Roll), or the
owner queue fed by the RequestOwnerRiverEgg BindableEvent (owner panel).

Collecting (both paths call the same collectEgg):
  - the egg's own ProximityPrompt (CollectAnchor), or
  - ReplicatedStorage.CollectRiverEgg:FireServer(eggModel)  (place-owned RemoteEvent, client -> server)
Network authority: the client only names the egg model. The server looks it up in its own collectByEgg table,
recomputes the egg position from the shared Epoch (must be in the "travel" phase), checks distance <= 17 studs,
alive humanoid, Backpack, no egg still being carried home (RiverCarry.IsCarrying), then charges the server-side catalog price (RiverEggPayment) before granting the Tool.
Feedback on a failed charge: ReplicatedStorage.RiverEggPurchaseFeedback:FireClient(player, reason, priceText),
throttled to 1 per second per player. After the grant RiverEggCarryService.Begin starts the "carry it home" phase.
Testing / owner hooks (workspace attributes): ForceRiverMutation, PendingMutationDrop (one-shot), NightRiverLuckMultiplier.
]]
local _RunService = game:GetService("RunService")
local Catalog = require(game.ReplicatedStorage.CharacterCatalog)
local Economy = require(game.ReplicatedStorage.CharacterEconomy)
local Timing = require(game.ReplicatedStorage.EggHatchTiming)
local Payment = require(script.Parent.RiverEggPayment)
local RiverCarry = require(script.Parent.RiverEggCarryService)
local purchaseFeedbackEvent = game.ReplicatedStorage.RiverEggPurchaseFeedback
local lastFeedbackAt = setmetatable({}, { __mode = "k" }) -- [Player] = os.clock() of the last feedback message
local function sendPurchaseFeedback(player, reason, priceText)
    local now = os.clock()
    if now - (lastFeedbackAt[player] or -math.huge) > 1 then
        lastFeedbackAt[player] = now
        purchaseFeedbackEvent:FireClient(player, reason, priceText)
    end
end
local conveyor = workspace:WaitForChild("PirateEggConveyor")
local templates = {}
for _, template in ipairs(game.ServerStorage:WaitForChild("AuxEggTemplates"):GetChildren()) do
    if template:GetAttribute("ReleaseEnabled") ~= false then
        table.insert(templates, template)
    end
end
table.sort(templates, function(a, b)
    return a:GetAttribute("Order") < b:GetAttribute("Order")
end)
local riverEggFolder = workspace:WaitForChild("WaterfallEggs")
local rollingMotion = require(conveyor:WaitForChild("RollingMotion"))
local collectByEgg = {} -- [egg Model] = collectEgg(player) while the egg can still be collected
local spawnSerial = 0
local random = Random.new()
local scheduler = require(script.Parent.RiverEggSpawnScheduler).new(templates, random)
local serverStart = os.clock()
-- Owner panel only: Halloween mutation eggs (Silver/Gold/Diamond/Rainbow) from UpdatePack_Mutations_Halloween
local MUTATION_TIERS = { Silver = true, Gold = true, Diamond = true, Rainbow = true }
local ownerQueue -- { { template, tier }, ... }; each entry takes the next normal river slot
-- Builds a river-ready mutated copy of `template` from the Halloween update pack, or nil if the pack lacks it.
local function mutatedTemplate(template, tier)
    local pack = game.ServerStorage:FindFirstChild("UpdatePack_Mutations_Halloween")
    local eggs = pack and pack:FindFirstChild("Update_Eggs_Halloween", true)
    local sourceEgg = eggs
        and (
            eggs:FindFirstChild(template.Name .. "_Halloween_" .. tier .. "_Egg")
            or eggs:FindFirstChild(template.Name .. "_" .. tier .. "_Egg")
        )
    if not sourceEgg then
        return nil
    end
    local mutatedEgg = sourceEgg:Clone()
    mutatedEgg.Name = template.Name
    for name, value in template:GetAttributes() do
        mutatedEgg:SetAttribute(name, value)
    end
    -- match the river template's height
    local _, templateSize = template:GetBoundingBox()
    local _, mutatedSize = mutatedEgg:GetBoundingBox()
    mutatedEgg:ScaleTo(mutatedEgg:GetScale() * templateSize.Y / math.max(mutatedSize.Y, 0.01))
    for _, part in mutatedEgg:GetDescendants() do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = false
            part.CanTouch = false
        end
    end
    -- same pivot-to-centre offset as the river template, so it sits on the river path like a normal egg
    local templateBox = template:GetBoundingBox()
    local offset = template:GetPivot():ToObjectSpace(templateBox)
    local mutatedBox = mutatedEgg:GetBoundingBox()
    mutatedEgg.WorldPivot = mutatedBox * offset:Inverse()
    -- the mutation aura VFX rides along with the egg
    pcall(function()
        require(game.ServerScriptService.Mutations).AddAura(mutatedEgg, tier)
    end)
    return mutatedEgg
end
local function spawnEgg(forcedTemplate, mutation)
    spawnSerial += 1
    local template = forcedTemplate or scheduler:Next(os.clock() - serverStart)
    local egg = template:Clone()
    egg.Name = "RiverEgg_" .. spawnSerial
    if mutation then
        egg:SetAttribute("Mutation", mutation)
    end
    egg:SetAttribute("Sequence", spawnSerial)
    egg:PivotTo(CFrame.new(conveyor:GetAttribute("FallStart")))
    for _, name in { "LabelAnchor", "CollectAnchor" } do
        local anchorPart = conveyor[name]:Clone()
        anchorPart.CFrame = egg:GetPivot()
        anchorPart.Parent = egg
    end
    local label = egg.LabelAnchor
    for _, gui in label:GetChildren() do
        if gui:IsA("BillboardGui") then
            gui:Destroy()
        end
    end
    local entry = Catalog.ById[template.Name]
    if entry then
        Catalog.Stamp(egg, entry)
    end
    egg:SetAttribute("EggType", template.Name)
    local roll = Economy.Roll(template.Name)
    Economy.Apply(egg, template.Name, roll)
    egg:SetAttribute("HatchSeconds", Timing.Seconds(template.Name, roll))
    local prompt = egg.CollectAnchor:FindFirstChildOfClass("ProximityPrompt")
    if prompt then
        prompt.ObjectText = (mutation and mutation .. " " or "") .. template.Name .. " Egg"
        prompt.ActionText = "Collect"
    end
    -- Epoch = shared start time; clients and server derive the egg's position from it via pose(t).
    egg:SetAttribute("Epoch", workspace:GetServerTimeNow())
    egg.Parent = riverEggFolder
    game:GetService("CollectionService"):AddTag(egg, "RiverEgg")
    local _update, pose = rollingMotion(conveyor, egg)
    local _, _, _, duration = pose(0)

    local collectPrompt = egg.CollectAnchor:FindFirstChildOfClass("ProximityPrompt")
    local collected = false
    local function collectEgg(player)
        if collected or not egg.Parent then
            return
        end
        -- egg position recomputed from the shared clock, never taken from the client
        local eggCFrame, phase = pose(workspace:GetServerTimeNow() - egg:GetAttribute("Epoch"))
        if phase ~= "travel" then
            return
        end
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local backpack = player:FindFirstChildOfClass("Backpack")
        if not root or not backpack or (root.Position - eggCFrame.Position).Magnitude > 17 then
            return
        end
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 or not entry then
            return
        end
        -- one stolen egg at a time: the previous one must be secured at home first
        if RiverCarry.IsCarrying(player) then
            sendPurchaseFeedback(player, "Secure your egg first", Catalog.FormatPrice(entry.Price))
            return
        end
        -- Build the owned Tool first (no yields), destroy it again if the charge fails.
        local tool = Instance.new("Tool")
        tool.Name = (mutation and mutation .. " " or "") .. template.Name .. " Egg"
        tool.ToolTip = ""
        tool:SetAttribute("EggType", template.Name)
        tool.CanBeDropped = false
        tool:SetAttribute("Price", entry.Price)
        if mutation then
            tool:SetAttribute("Mutation", mutation)
        end
        if entry then
            Catalog.Stamp(tool, entry)
            tool.ToolTip = entry.Rarity .. " • " .. Catalog.FormatPrice(entry.Price)
        end
        Economy.Apply(tool, template.Name, roll)
        tool:SetAttribute("HatchSeconds", egg:GetAttribute("HatchSeconds"))
        local visual = template:Clone()
        visual.Name = "Egg"
        visual:ScaleTo(template:GetScale() * 0.5)
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
            end
        end
        -- No yields between charging, claiming and granting: one egg, one charge.
        local paid, reason = Payment.TryCharge(player, entry.Price)
        if not paid then
            tool:Destroy()
            sendPurchaseFeedback(player, reason, Catalog.FormatPrice(entry.Price))
            return
        end
        collected = true
        egg:SetAttribute("Collected", true)
        if collectPrompt then
            collectPrompt.Enabled = false
        end
        tool.Parent = backpack
        collectByEgg[egg] = nil
        egg:Destroy()
        require(game.ServerScriptService.GameMenu.QuestService).Increment(player, "CollectRiverEgg", 1)
        local ok, err = pcall(RiverCarry.Begin, player, tool)
        if not ok then
            tool.Enabled = true
            tool:SetAttribute("ReturningToBase", nil)
            warn("River carry: " .. tostring(err))
        end
    end
    collectByEgg[egg] = collectEgg
    if collectPrompt then
        collectPrompt.Triggered:Connect(collectEgg)
    end
    -- despawn just before the path ends
    task.delay(duration - 0.05, function()
        collectByEgg[egg] = nil
        if egg.Parent then
            egg:Destroy()
        end
    end)
end
-- Client-initiated collect: only eggs present in collectByEgg can be collected; collectEgg re-validates everything.
game.ReplicatedStorage.CollectRiverEgg.OnServerEvent:Connect(function(player, egg)
    if typeof(egg) ~= "Instance" then
        return
    end
    local collect = collectByEgg[egg]
    if collect then
        collect(player)
    end
end)
-- Owner panel hook (server-only BindableEvent): fire(ownerPlayer, eggId, mutationTier?)
local ownerRequest = conveyor:FindFirstChild("RequestOwnerRiverEgg") or Instance.new("BindableEvent")
ownerRequest.Name = "RequestOwnerRiverEgg"
ownerRequest.Parent = conveyor
ownerQueue = {}
ownerRequest.Event:Connect(function(owner, id, mutation)
    if
        typeof(owner) ~= "Instance"
        or not owner:IsA("Player")
        or require(game.ServerScriptService.AdminRoles).Role(owner) == nil
        or owner.Parent ~= game.Players
    then
        return
    end
    local entry = type(id) == "string" and Catalog.ById[id]
    local template = entry and game.ServerStorage.AuxEggTemplates:FindFirstChild(id)
    -- preview: a mutation egg with no river template yet borrows Pirate's for size/motion
    if not template and entry and MUTATION_TIERS[mutation] then
        local borrowed = game.ServerStorage.AuxEggTemplates.Pirate:Clone()
        borrowed.Name = id
        borrowed:SetAttribute("ReleaseEnabled", nil)
        template = borrowed
    end
    if template and (template:GetAttribute("ReleaseEnabled") ~= false or MUTATION_TIERS[mutation]) then
        local tier = MUTATION_TIERS[mutation] and mutation or nil
        local mutated = tier and mutatedTemplate(template, tier)
        if mutated then
            table.insert(ownerQueue, { template = mutated, tier = tier }) -- takes the next normal river slot
        else
            spawnEgg(template)
        end
    end
end)
-- Keep a steady cadence, with no catch-up burst if the server stalls.
local nextSpawn = os.clock() + 2
while true do
    local now = os.clock()
    if now >= nextSpawn then
        local queued = table.remove(ownerQueue, 1)
        if queued then
            spawnEgg(queued.template, queued.tier)
        else
            -- natural mutation eggs: Silver 1/100, Gold 1/500, Diamond 1/2000, Rainbow 1/5000 (night river luck multiplies the odds)
            local ok, tier = pcall(function()
                return require(game.ServerScriptService.Mutations).Roll(
                    workspace:GetAttribute("NightRiverLuckMultiplier") or 1
                )
            end)
            tier = ok and tier or nil
            tier = workspace:GetAttribute("ForceRiverMutation") or tier
            local pendingDrop = workspace:GetAttribute("PendingMutationDrop")
            if pendingDrop then
                tier = pendingDrop
                workspace:SetAttribute("PendingMutationDrop", nil)
            end -- testing: set this attribute to Silver/Gold/Diamond/Rainbow
            local baseTemplate = tier and scheduler:Next(os.clock() - serverStart)
            local mutated = baseTemplate and mutatedTemplate(baseTemplate, tier)
            if mutated then
                spawnEgg(mutated, tier)
            elseif baseTemplate then
                spawnEgg(baseTemplate)
            else
                spawnEgg()
            end
        end
        local interval = math.clamp(tonumber(conveyor:GetAttribute("SpawnInterval")) or 4, 1.5, 30)
        nextSpawn = nextSpawn + interval
        if nextSpawn <= os.clock() then
            nextSpawn = os.clock() + interval
        end
    end
    task.wait(math.clamp(nextSpawn - os.clock(), 0.03, 0.2))
end
