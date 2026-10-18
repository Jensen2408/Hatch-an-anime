local RunService = game:GetService("RunService")
local Catalog = require(game.ReplicatedStorage.CharacterCatalog)
local Economy = require(game.ReplicatedStorage.CharacterEconomy)
local Timing = require(game.ReplicatedStorage.EggHatchTiming)
local Payment = require(script.Parent.RiverEggPayment)
local RiverCarry = require(script.Parent.RiverEggCarryService)
local feedback = game.ReplicatedStorage.RiverEggPurchaseFeedback
local feedbackAt = setmetatable({}, { __mode = "k" })
local m = workspace:WaitForChild("PirateEggConveyor")
local templates = {}
for _, template in ipairs(game.ServerStorage:WaitForChild("AuxEggTemplates"):GetChildren()) do
    if template:GetAttribute("ReleaseEnabled") ~= false then
        table.insert(templates, template)
    end
end
table.sort(templates, function(a, b)
    return a:GetAttribute("Order") < b:GetAttribute("Order")
end)
local folder = workspace:WaitForChild("WaterfallEggs")
local motion = require(m:WaitForChild("RollingMotion"))
local active = {}
local serial = 0
local random = Random.new()
local scheduler = require(script.Parent.RiverEggSpawnScheduler).new(templates, random)
local serverStart = os.clock()
-- Owner panel only: Halloween mutation eggs (Silver/Gold/Diamond/Rainbow) from UpdatePack_Mutations_Halloween
local MUT = { Silver = true, Gold = true, Diamond = true, Rainbow = true }
local ownerQueue
local function mutatedTemplate(template, tier)
    local pack = game.ServerStorage:FindFirstChild("UpdatePack_Mutations_Halloween")
    local eggs = pack and pack:FindFirstChild("Update_Eggs_Halloween", true)
    local src = eggs
        and (
            eggs:FindFirstChild(template.Name .. "_Halloween_" .. tier .. "_Egg")
            or eggs:FindFirstChild(template.Name .. "_" .. tier .. "_Egg")
        )
    if not src then
        return nil
    end
    local m = src:Clone()
    m.Name = template.Name
    for k, v in template:GetAttributes() do
        m:SetAttribute(k, v)
    end
    local _, a = template:GetBoundingBox()
    local _, b = m:GetBoundingBox()
    m:ScaleTo(m:GetScale() * a.Y / math.max(b.Y, 0.01))
    for _, p in m:GetDescendants() do
        if p:IsA("BasePart") then
            p.Anchored = true
            p.CanCollide = false
            p.CanTouch = false
        end
    end
    -- same pivot-to-centre offset as the river template, so it sits on the river path like a normal egg
    local tcf = template:GetBoundingBox()
    local offset = template:GetPivot():ToObjectSpace(tcf)
    local mcf = m:GetBoundingBox()
    m.WorldPivot = mcf * offset:Inverse()
    -- the mutation aura VFX rides along with the egg
    pcall(function()
        require(game.ServerScriptService.Mutations).AddAura(m, tier)
    end)
    return m
end
local function spawnEgg(forcedTemplate, mutation)
    serial += 1
    local template = forcedTemplate or scheduler:Next(os.clock() - serverStart)
    local egg = template:Clone()
    egg.Name = "RiverEgg_" .. serial
    if mutation then
        egg:SetAttribute("Mutation", mutation)
    end
    egg:SetAttribute("Sequence", serial)
    egg:PivotTo(CFrame.new(m:GetAttribute("FallStart")))
    for _, name in { "LabelAnchor", "CollectAnchor" } do
        local p = m[name]:Clone()
        p.CFrame = egg:GetPivot()
        p.Parent = egg
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
    egg:SetAttribute("Epoch", workspace:GetServerTimeNow())
    egg.Parent = folder
    game:GetService("CollectionService"):AddTag(egg, "RiverEgg")
    local update, pose = motion(m, egg)
    local _, _, _, duration = pose(0)

    local prompt = egg.CollectAnchor:FindFirstChildOfClass("ProximityPrompt")
    local collected = false
    local function collectEgg(player)
        if collected or not egg.Parent then
            return
        end
        local cf, phase = pose(workspace:GetServerTimeNow() - egg:GetAttribute("Epoch"))
        if phase ~= "travel" then
            return
        end
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local bag = player:FindFirstChildOfClass("Backpack")
        if not root or not bag or (root.Position - cf.Position).Magnitude > 17 then
            return
        end
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 or not entry then
            return
        end
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
        for _, p in visual:GetDescendants() do
            if p:IsA("BasePart") then
                p.Anchored = false
                p.CanCollide = false
                p.CanTouch = false
                p.Massless = true
                local weld = Instance.new("WeldConstraint")
                weld.Part0 = handle
                weld.Part1 = p
                weld.Parent = handle
            end
        end
        -- No yields between charging, claiming and granting: one egg, one charge.
        local paid, reason = Payment.TryCharge(player, entry.Price)
        if not paid then
            tool:Destroy()
            local now = os.clock()
            if now - (feedbackAt[player] or -math.huge) > 1 then
                feedbackAt[player] = now
                feedback:FireClient(player, reason, Catalog.FormatPrice(entry.Price))
            end
            return
        end
        collected = true
        egg:SetAttribute("Collected", true)
        if prompt then
            prompt.Enabled = false
        end
        tool.Parent = bag
        active[egg] = nil
        egg:Destroy()
        require(game.ServerScriptService.GameMenu.QuestService).Increment(player, "CollectRiverEgg", 1)
        local ok, err = pcall(RiverCarry.Begin, player, tool)
        if not ok then
            tool.Enabled = true
            tool:SetAttribute("ReturningToBase", nil)
            warn("River carry: " .. tostring(err))
        end
    end
    active[egg] = collectEgg
    if prompt then
        prompt.Triggered:Connect(collectEgg)
    end
    task.delay(duration - 0.05, function()
        active[egg] = nil
        if egg.Parent then
            egg:Destroy()
        end
    end)
end
game.ReplicatedStorage.CollectRiverEgg.OnServerEvent:Connect(function(player, egg)
    if typeof(egg) ~= "Instance" then
        return
    end
    local collect = active[egg]
    if collect then
        collect(player)
    end
end)
local ownerRequest = m:FindFirstChild("RequestOwnerRiverEgg") or Instance.new("BindableEvent")
ownerRequest.Name = "RequestOwnerRiverEgg"
ownerRequest.Parent = m
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
    if not template and entry and MUT[mutation] then
        local base = game.ServerStorage.AuxEggTemplates.Pirate:Clone()
        base.Name = id
        base:SetAttribute("ReleaseEnabled", nil)
        template = base
    end
    if template and (template:GetAttribute("ReleaseEnabled") ~= false or MUT[mutation]) then
        local tier = MUT[mutation] and mutation or nil
        local mt = tier and mutatedTemplate(template, tier)
        if mt then
            table.insert(ownerQueue, { template = mt, tier = tier }) -- takes the next normal river slot
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
        local q = table.remove(ownerQueue, 1)
        if q then
            spawnEgg(q.template, q.tier)
        else
            -- natural mutation eggs: Silver 1/100, Gold 1/500, Diamond 1/2000, Rainbow 1/5000 (night river luck multiplies the odds)
            local ok, tier = pcall(function()
                return require(game.ServerScriptService.Mutations).Roll(
                    workspace:GetAttribute("NightRiverLuckMultiplier") or 1
                )
            end)
            tier = ok and tier or nil
            tier = workspace:GetAttribute("ForceRiverMutation") or tier
            local drop = workspace:GetAttribute("PendingMutationDrop")
            if drop then
                tier = drop
                workspace:SetAttribute("PendingMutationDrop", nil)
            end -- testing: set this attribute to Silver/Gold/Diamond/Rainbow
            local base = tier and scheduler:Next(os.clock() - serverStart)
            local mt = base and mutatedTemplate(base, tier)
            if mt then
                spawnEgg(mt, tier)
            elseif base then
                spawnEgg(base)
            else
                spawnEgg()
            end
        end
        local interval = math.clamp(tonumber(m:GetAttribute("SpawnInterval")) or 4, 1.5, 30)
        nextSpawn = nextSpawn + interval
        if nextSpawn <= os.clock() then
            nextSpawn = os.clock() + interval
        end
    end
    task.wait(math.clamp(nextSpawn - os.clock(), 0.03, 0.2))
end
