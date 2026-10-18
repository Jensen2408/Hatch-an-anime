--[[ ServerScriptService.EggSteal.EggStealService  (ModuleScript, SERVER ONLY)

THE SERVER DECIDES EVERYTHING. There is no client → server message anywhere in this system.
A steal starts from a server-side ProximityPrompt, is verified here, and ends here.
The only RemoteEvent (ReplicatedStorage.EggSteal.Event) goes server → client and only says "show this".

Life of a steal
  1. Thief fires the "Steal Egg" prompt on another player's incubating egg.
     Server checks: alive, in range, not already carrying, off cooldown, has own base, egg really is
     incubating, chamber not already locked. The chamber is LOCKED in the same step (no yields), so two
     players can never take the same egg.
  2. NOTHING MOVES. The real egg stays in the owner's chamber. The thief only carries a visual copy plus a
     server-held clone that is handed over at the end.
  3. One shared loop (every Rules.TickRate s) watches each thief: alive, speed, teleports, distance walked.
  4. Thief inside their OWN base box, long enough, having really walked there  →  SECURED:
     clone goes to the thief, original is destroyed, chamber is told to abort (one atomic step).
  5. Anything else (death, reset, leaving, teleport, timeout, egg hatched…)  →  FAILED: unlock, show the
     egg again, destroy the clone. The original was never touched, so nothing is duplicated or lost.

Network authority: the server trusts nothing from clients (there is no client -> server remote). Server -> client
messages on the Event: "Start" {id,name,eggType,rarity,price,base} to the thief, "Alert" {id,name,eggType,rarity,
thiefName,thiefUserId,pos} and "Pos" (id, position) to the victim, "End" {id,result,reason,info} to both.
Thief attributes CarryingStolenEggBase / CarryingStolenEggType / CarryingStolenEggId mirror the state for late clients.
Status: the whole system is OFF (EggStealServer is Disabled in default.project.json).
Known issue (PROJECT_AUDIT, High latent): Rules.VictimLeaves = "Continue" + victim leaving mid-steal -> the victim's
save keeps the egg and the thief also gets the server-held clone (see onRemoving / unregister).

Optional hooks (set from any server script after require):
  Service.CanSteal  = function(thief, victim, chamber) return true end   -- extra rules (protection, tutorial…)
  Service.OnSecured = function(thief, info, victim) end                  -- rewards: coins, quests, stats…
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local StealFolder = ReplicatedStorage:WaitForChild("EggSteal")
local Config = require(StealFolder:WaitForChild("EggStealConfig"))
local Catalog = require(ReplicatedStorage:WaitForChild("EggCatalog"))
local Rules = Config.Rules

local Service = {}
Service.CanSteal = nil
Service.OnSecured = nil

local EGG_OFFSET = CFrame.new(0, 3.5, -1.5) -- where HatchGoo keeps the egg, in the chamber's space

local stealEvent -- ReplicatedStorage.EggSteal.Event (RemoteEvent, server -> client only); set in Init
local steals = {} -- [thief Player]  = steal
local byChamber = {} -- [chamber Model] = steal
local byEggId = {} -- [EggId string]  = steal   (belt and braces: one egg can only be in one steal)
local chambers = {} -- [chamber Model] = { prompt, anchor, conns }
local cooldownUntil = {} -- [Player]  = os.clock()
local chamberUntil = {} -- [chamber] = os.clock()
local loopRunning = false
local started = false
local nextId = 0

local catalogById = {} -- [egg Id] = EggCatalog entry
for _, entry in Catalog do
    catalogById[entry.Id] = entry
end

-- ─────────────────────────── helpers ───────────────────────────
local function fire(player, ...)
    if player and player.Parent == Players then
        stealEvent:FireClient(player, ...)
    end
end

local function aliveRoot(player)
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if hum and root and hum.Health > 0 then
        return char, hum, root
    end
end

local function homePlot(player)
    for _, plot in workspace.Plots:GetChildren() do
        if plot:GetAttribute("OwnerUserId") == player.UserId then
            return plot
        end
    end
end

-- horizontal distance from pos to the plot's base box (0 when inside), and whether pos is inside it
local function baseDistance(plot, pos)
    local rel = plot.TempleAnchor.CFrame:PointToObjectSpace(pos)
    local lo, hi = Rules.BaseMin, Rules.BaseMax
    local dx = math.max(lo.X - rel.X, 0, rel.X - hi.X)
    local dz = math.max(lo.Z - rel.Z, 0, rel.Z - hi.Z)
    local inside = dx == 0 and dz == 0 and rel.Y >= lo.Y and rel.Y <= hi.Y
    return math.sqrt(dx * dx + dz * dz), inside
end

local function eggInfo(tool)
    local eggType = tostring(tool:GetAttribute("EggType") or tool.Name)
    local entry = catalogById[eggType]
    return {
        eggId = tool:GetAttribute("EggId"),
        eggType = eggType,
        name = entry and entry.Name or (eggType:gsub("%s*[Ee]gg$", "")),
        rarity = tool:GetAttribute("Rarity") or (entry and entry.Rarity) or "Common",
        price = tonumber(tool:GetAttribute("Price")) or (entry and entry.Price) or 0,
    }
end

-- The egg tool of a chamber is parked in its owner's IncubatorHeldEggs folder by HatchGoo,
-- tagged with the chamber's full name (see the 4-line HatchGoo hook in the README).
local function findEggTool(chamber)
    local plot = chamber.Parent and chamber.Parent.Parent
    local ownerId = plot and plot:GetAttribute("OwnerUserId")
    local owner = ownerId and ownerId ~= 0 and Players:GetPlayerByUserId(ownerId)
    local held = owner and owner:FindFirstChild("IncubatorHeldEggs")
    if not held then
        return
    end
    local key = chamber:GetFullName()
    for _, tool in held:GetChildren() do
        if tool:IsA("Tool") and tool:GetAttribute("IncubatorChamber") == key then
            return tool, owner
        end
    end
end

-- Can this chamber be stolen from right now? (global switch, not locked, incubating status, off cooldown, egg found)
local function stealable(chamber)
    if Rules.Enabled == false then
        return false
    end
    if byChamber[chamber] or chamber:GetAttribute("StealLock") or chamber:GetAttribute("EggStolen") then
        return false
    end
    if chamber:GetAttribute("UnderConstruction") then
        return false
    end
    if not Rules.StealableStatuses[chamber:GetAttribute("Status")] then
        return false
    end
    if os.clock() < (chamberUntil[chamber] or 0) then
        return false
    end
    return findEggTool(chamber) ~= nil
end

local function hatchPrompt(chamber)
    local trim = chamber:FindFirstChild("LiquidSystemAndTrim")
    local button = trim and trim:FindFirstChild("HatchButton")
    return button and button:FindFirstChildOfClass("ProximityPrompt")
end

-- hide / show the egg that sits in the chamber while the thief is carrying it away
local function setEggHidden(chamber, hidden)
    local visual = chamber:FindFirstChild("IncubatingEgg")
    if not visual then
        return
    end
    local nodes = visual:GetDescendants()
    table.insert(nodes, visual) -- HatchGoo's visual is a Model, but a bare MeshPart works too
    for _, part in nodes do
        if part:IsA("BasePart") then
            if hidden then
                -- remember the original transparency once (the attribute survives repeated hides)
                if part:GetAttribute("StealOrigT") == nil then
                    part:SetAttribute("StealOrigT", part.Transparency)
                end
                part.Transparency = 1
            else
                local originalTransparency = part:GetAttribute("StealOrigT")
                if originalTransparency ~= nil then
                    part.Transparency = originalTransparency
                    part:SetAttribute("StealOrigT", nil)
                end
            end
        end
    end
end

-- ─────────────────────────── steal prompt (one per chamber) ───────────────────────────
local startSteal -- forward

local function refreshPrompt(chamber)
    local rec = chambers[chamber]
    if not rec or not rec.prompt then
        return
    end
    local ok = stealable(chamber)
    if ok then
        local tool = findEggTool(chamber)
        if tool then
            local info = eggInfo(tool)
            rec.prompt.ObjectText = info.name .. " • " .. info.rarity
        end
    end
    local plot = chamber.Parent and chamber.Parent.Parent
    rec.prompt:SetAttribute("OwnerUserId", plot and plot:GetAttribute("OwnerUserId") or 0)
    rec.prompt:SetAttribute("Stealable", ok) -- the client uses this to hide the prompt from the owner / a carrier
    rec.prompt.Enabled = ok
end

-- Create the StealAnchor part + StealPrompt for a chamber (skipped while it is UnderConstruction; retried when that changes).
local function attach(chamber, rec)
    if rec.dead or rec.anchor or chamber:GetAttribute("UnderConstruction") then
        return
    end
    local anchor = Instance.new("Part")
    anchor.Name = "StealAnchor"
    anchor.Size = Vector3.one
    anchor.Transparency = 1
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.CanTouch = false
    anchor.CanQuery = false
    anchor.CFrame = chamber:GetPivot() * EGG_OFFSET
    anchor.Parent = chamber

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "StealPrompt"
    prompt.ActionText = "Steal Egg"
    prompt.ObjectText = "Egg"
    prompt.KeyboardKeyCode = Rules.PromptKey
    prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    prompt.HoldDuration = Rules.PromptHold
    prompt.MaxActivationDistance = Rules.PromptDistance
    prompt.RequiresLineOfSight = false
    prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
    prompt.Enabled = false
    prompt:SetAttribute("Stealable", false)
    prompt.Parent = anchor
    CollectionService:AddTag(prompt, "EggStealPrompt")

    rec.anchor, rec.prompt = anchor, prompt
    table.insert(
        rec.conns,
        prompt.Triggered:Connect(function(player)
            startSteal(player, chamber)
        end)
    )
    refreshPrompt(chamber)
end

local finish -- forward

local function unregister(chamber)
    local rec = chambers[chamber]
    if not rec then
        return
    end
    rec.dead = true
    for _, conn in rec.conns do
        conn:Disconnect()
    end
    chambers[chamber] = nil
    local steal = byChamber[chamber]
    if steal then
        byChamber[chamber] = nil
        steal.victimGone = true
        steal.victim = nil
        if Rules.VictimLeaves == "Cancel" then
            finish(steal, "Failed", "VictimGone")
        end
    end
end

local function register(chamber)
    if chambers[chamber] or not chamber:IsA("Model") then
        return
    end
    local rec = { conns = {} }
    chambers[chamber] = rec
    local function refresh()
        refreshPrompt(chamber)
    end
    for _, attr in { "Status", "StealLock", "EggStolen" } do
        table.insert(rec.conns, chamber:GetAttributeChangedSignal(attr):Connect(refresh))
    end
    table.insert(
        rec.conns,
        chamber:GetAttributeChangedSignal("UnderConstruction"):Connect(function()
            attach(chamber, rec)
        end)
    )
    table.insert(
        rec.conns,
        chamber.Destroying:Connect(function()
            unregister(chamber)
        end)
    )
    attach(chamber, rec)
end

-- ─────────────────────────── carried egg (visible to everyone) ───────────────────────────
-- model to copy for the carry visual: the Tool's egg model, its Handle, or ReplicatedStorage.EggVisuals[eggType]
local function eggSource(tool, info)
    local visuals = ReplicatedStorage:FindFirstChild("EggVisuals")
    return tool:FindFirstChild("Egg")
        or tool:FindFirstChild("Handle")
        or (visuals and visuals:FindFirstChild(info.eggType))
end

-- Builds "StolenEggCarry" in the thief's character: a gold-tinted egg copy welded in front of the torso,
-- a Highlight + "STOLEN EGG" tag for everyone else, sparkles, and the arm pose / IK grip.
local function buildCarry(steal)
    local char, _, root = aliveRoot(steal.thief)
    if not char or not steal.carrySource then
        return
    end
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or root
    local carryColor = Color3.fromRGB(255, 205, 70)

    local model = Instance.new("Model")
    model.Name = "StolenEggCarry"
    local carrier = Instance.new("Part")
    carrier.Name = "Carrier"
    carrier.Size = Vector3.new(0.6, 0.6, 0.6)
    carrier.Transparency = 1
    carrier.CanCollide, carrier.CanTouch, carrier.CanQuery, carrier.Massless = false, false, false, true
    carrier.CFrame = torso.CFrame * Rules.CarryOffset
    carrier.Parent = model

    local egg = steal.carrySource:Clone()
    for _, descendant in egg:GetDescendants() do
        if
            descendant:IsA("LuaSourceContainer")
            or descendant:IsA("ProximityPrompt")
            or descendant:IsA("BillboardGui")
            or descendant:IsA("Sound")
        then
            descendant:Destroy()
        end
    end
    local parts = {}
    if egg:IsA("BasePart") then
        egg.Size *= Rules.CarryHeight / egg.Size.Y
        egg.CFrame = carrier.CFrame
        parts[1] = egg
    else
        local _, size = egg:GetBoundingBox()
        egg:ScaleTo(egg:GetScale() * Rules.CarryHeight / size.Y)
        local box = egg:GetBoundingBox()
        egg:PivotTo(carrier.CFrame * box:ToObjectSpace(egg:GetPivot()))
        for _, descendant in egg:GetDescendants() do
            if descendant:IsA("BasePart") then
                parts[#parts + 1] = descendant
            end
        end
    end
    egg.Parent = model
    for _, p in parts do
        p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, false, true
        local weld = Instance.new("WeldConstraint")
        weld.Part0, weld.Part1, weld.Parent = carrier, p, p
    end
    local hold = Instance.new("WeldConstraint")
    hold.Part0, hold.Part1, hold.Parent = torso, carrier, carrier

    -- others can see (and chase) the thief, even through walls
    local highlight = Instance.new("Highlight")
    highlight.Adornee = model
    highlight.FillColor, highlight.FillTransparency = carryColor, 0.8
    highlight.OutlineColor, highlight.OutlineTransparency = Config.Colors.Danger, 0.1
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = model

    local tag = Instance.new("BillboardGui")
    tag.Name = "StolenTag"
    tag.Adornee = carrier
    tag.Size = UDim2.fromOffset(132, 30)
    tag.StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
    tag.AlwaysOnTop = true
    tag.MaxDistance = 220
    tag.PlayerToHideFrom = steal.thief -- the thief doesn't need a label over their own head
    tag.Parent = model
    local background = Instance.new("Frame")
    background.Size = UDim2.fromScale(1, 1)
    background.BackgroundColor3 = Config.Colors.Dark
    background.BackgroundTransparency = 0.1
    background.Parent = tag
    Instance.new("UICorner", background).CornerRadius = UDim.new(0.5, 0)
    local stroke = Instance.new("UIStroke")
    stroke.Color, stroke.Thickness = Config.Colors.Danger, 2
    stroke.Parent = background
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Cartoon
    label.Text = "STOLEN EGG"
    label.TextSize = 18
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Parent = background

    local sparkAttachment = Instance.new("Attachment")
    sparkAttachment.Parent = carrier
    local sparks = Instance.new("ParticleEmitter")
    sparks.Name = "Sparks"
    sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    sparks.Rate = 9
    sparks.Lifetime = NumberRange.new(0.6, 1)
    sparks.Speed = NumberRange.new(1, 3)
    sparks.SpreadAngle = Vector2.new(180, 180)
    sparks.LightEmission, sparks.LightInfluence = 1, 0
    sparks.Color = ColorSequence.new(carryColor, Color3.new(1, 1, 1))
    sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0) })
    sparks.Parent = sparkAttachment

    -- Presentation only: original/reward egg colours stay intact.
    for _, p in parts do
        p.Material = Enum.Material.Metal
        p.MaterialVariant = "Incubator One Stud Cavity Metal"
        p.Color = Color3.fromRGB(255, 196, 47)
        if p:IsA("MeshPart") then
            p.TextureID = ""
        end
        for _, child in p:GetChildren() do
            if child:IsA("SurfaceAppearance") or child:IsA("Decal") or child:IsA("Texture") then
                child:Destroy()
            end
        end
    end
    -- Arms: R6 bends the shoulder Motor6Ds (restored by destroyCarry), R15 uses IKControls gripping the carrier.
    steal.armPose = {}
    steal.carryIK = {}
    if char:FindFirstChild("Torso") then
        for _, side in { "Left", "Right" } do
            local joint = torso:FindFirstChild(side .. " Shoulder")
            if joint and joint:IsA("Motor6D") then
                table.insert(steal.armPose, { joint = joint, c0 = joint.C0, c1 = joint.C1 })
                joint.C0 = CFrame.new(joint.C0.Position)
                    * CFrame.Angles(math.rad(68), 0, side == "Left" and -0.25 or 0.25)
                joint.C1 = CFrame.new(0, 0.5, 0)
            end
        end
    else
        local hum = char:FindFirstChildOfClass("Humanoid")
        for _, side in { "Left", "Right" } do
            local upper = char:FindFirstChild(side .. "UpperArm")
            local hand = char:FindFirstChild(side .. "Hand")
            if upper and hand and hum then
                local target = Instance.new("Attachment")
                target.Position = Vector3.new(side == "Left" and -0.75 or 0.75, -0.35, 0)
                target.Parent = carrier
                local ik = Instance.new("IKControl")
                ik.Name = "StolenEggGrip" .. side
                ik.Type = Enum.IKControlType.Position
                ik.ChainRoot = upper
                ik.EndEffector = hand
                ik.Target = target
                ik.Weight = 1
                ik.SmoothTime = 0.15
                ik.Parent = hum
                table.insert(steal.carryIK, ik)
            end
        end
    end
    model.Parent = char
    steal.carry = model
end

local function destroyCarry(steal, withBurst)
    if steal.carryIK then
        for _, ik in steal.carryIK do
            ik:Destroy()
        end
        steal.carryIK = nil
    end
    if steal.armPose then
        for _, saved in steal.armPose do
            if saved.joint.Parent then
                saved.joint.C0 = saved.c0
                saved.joint.C1 = saved.c1
            end
        end
        steal.armPose = nil
    end
    local model = steal.carry
    steal.carry = nil
    if not model then
        return
    end
    if withBurst then
        -- secured: hide the egg, turn the sparks into one golden burst, then let Debris clean up
        for _, descendant in model:GetDescendants() do
            if descendant:IsA("BasePart") and descendant.Name ~= "Carrier" then
                descendant.Transparency = 1
            elseif descendant:IsA("Highlight") or descendant:IsA("BillboardGui") then
                descendant:Destroy()
            elseif descendant:IsA("ParticleEmitter") then
                descendant.Rate = 0
                descendant.Color = ColorSequence.new(Config.Colors.Gold, Color3.new(1, 1, 1))
                descendant.Speed = NumberRange.new(8, 18)
                descendant.Size =
                    NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
                descendant:Emit(36)
            end
        end
        Debris:AddItem(model, 1.6)
    else
        model:Destroy()
    end
end

-- ─────────────────────────── ending a steal ───────────────────────────
-- chamber stays locked + flagged until HatchGoo has aborted and gone back to "Ready"
local function releaseStolenChamber(chamber)
    if not chamber or not chamber.Parent then
        return
    end
    local done = false
    local conn
    local function clear()
        if done then
            return
        end
        done = true
        if conn then
            conn:Disconnect()
        end
        if chamber.Parent then
            chamber:SetAttribute("EggStolen", nil)
            chamber:SetAttribute("StealLock", nil)
        end
    end
    conn = chamber:GetAttributeChangedSignal("Status"):Connect(function()
        if chamber:GetAttribute("Status") == "Ready" then
            clear()
        end
    end)
    task.delay(8, clear)
end

local function canSecure(steal)
    if steal.victimGone then
        return true
    end
    local tool, chamber = steal.tool, steal.chamber
    return tool ~= nil
        and tool.Parent ~= nil
        and chamber ~= nil
        and chamber.Parent ~= nil
        and Rules.StealableStatuses[chamber:GetAttribute("Status")] == true
end

-- hand the egg over. No yields in here: clone → thief, original → destroyed, chamber → abort.
local function secure(steal)
    local thief = steal.thief
    local bag = thief:FindFirstChildOfClass("Backpack")
    local egg = steal.eggClone
    if not bag or not egg then
        return false
    end
    steal.eggClone = nil
    egg.Enabled = true
    egg:SetAttribute("Incubating", nil)
    egg:SetAttribute("IncubatorChamber", nil)
    egg:SetAttribute("StolenFrom", steal.victimUserId)
    egg.Parent = bag

    local original = steal.tool
    steal.tool = nil
    if original and original.Parent then
        original:Destroy()
    end

    if Rules.MirrorToStarterGear then
        -- the conveyor keeps a StarterGear copy of every egg; remove the victim's, give the thief one
        local eggId = steal.info.eggId
        local victim = Players:GetPlayerByUserId(steal.victimUserId)
        local victimGear = victim and victim:FindFirstChild("StarterGear")
        if victimGear and eggId then
            for _, gearTool in victimGear:GetChildren() do
                if gearTool:GetAttribute("EggId") == eggId then
                    gearTool:Destroy()
                end
            end
        end
        local thiefGear = thief:FindFirstChild("StarterGear")
        if thiefGear then
            egg:Clone().Parent = thiefGear
        end
    end

    local chamber = steal.chamber
    if chamber and chamber.Parent then
        chamber:SetAttribute("EggStolen", true) -- HatchGoo's loops see this and abort cleanly
        releaseStolenChamber(chamber)
    end
    return true
end

local function unlock(steal)
    local chamber = steal.chamber
    if not chamber or not chamber.Parent then
        return
    end
    setEggHidden(chamber, false)
    chamber:SetAttribute("StealLock", nil)
    if chamber:GetAttribute("Status") == "Loaded" then
        local prompt = hatchPrompt(chamber)
        if prompt then
            prompt.Enabled = true
        end -- HatchGoo skipped re-enabling it while locked
    end
end

finish = function(steal, result, reason)
    if steal.state ~= "Carrying" then
        return
    end
    steal.state = "Done"
    for _, conn in steal.conns do
        conn:Disconnect()
    end
    steal.conns = {}
    if steals[steal.thief] == steal then
        steals[steal.thief] = nil
    end
    local chamber = steal.chamber
    if chamber and byChamber[chamber] == steal then
        byChamber[chamber] = nil
    end
    if steal.info.eggId and byEggId[steal.info.eggId] == steal then
        byEggId[steal.info.eggId] = nil
    end

    local secured = false
    if result == "Secured" then
        local ok, res = pcall(secure, steal)
        secured = ok and res == true
        if not ok then
            warn("[EggSteal] secure failed: " .. tostring(res))
        end
        if not secured then
            reason = reason or "Error"
        end
    end

    destroyCarry(steal, secured)
    if not secured then
        unlock(steal)
        if steal.eggClone then
            steal.eggClone:Destroy()
            steal.eggClone = nil
        end
    end
    if steal.carrySource then
        steal.carrySource:Destroy()
        steal.carrySource = nil
    end

    cooldownUntil[steal.thief] = os.clock() + Rules.StealCooldown
    if chamber then
        chamberUntil[chamber] = os.clock() + Rules.ChamberCooldown
        task.delay(Rules.ChamberCooldown + 0.1, function()
            refreshPrompt(chamber)
        end)
    end

    steal.thief:SetAttribute("CarryingStolenEggId", nil)
    steal.thief:SetAttribute("CarryingStolenEggBase", nil)
    local finalResult = secured and "Secured" or "Failed"
    local payload = { id = steal.id, result = finalResult, reason = reason, info = steal.info }
    fire(steal.thief, "End", payload)
    if steal.victim then
        fire(steal.victim, "End", payload)
    end

    if secured and Service.OnSecured then
        task.spawn(function()
            local ok, err = pcall(Service.OnSecured, steal.thief, steal.info, steal.victim)
            if not ok then
                warn("[EggSteal] OnSecured hook failed: " .. tostring(err))
            end
        end)
    end
end

-- ─────────────────────────── the shared loop ───────────────────────────
-- One step for one steal. Every failure path returns finish(...) so nothing after it runs for this steal.
local function tick(steal, now)
    if steal.state ~= "Carrying" then
        return
    end
    local thief = steal.thief
    if thief.Parent ~= Players then
        return finish(steal, "Failed", "Left")
    end
    local _, _, root = aliveRoot(thief)
    if not root then
        return finish(steal, "Failed", "Died")
    end
    local home = steal.home
    if home.Parent == nil or home:GetAttribute("OwnerUserId") ~= thief.UserId then
        return finish(steal, "Failed", "HomeLost")
    end
    if now - steal.startedAt > Rules.MaxCarrySeconds then
        return finish(steal, "Failed", "Timeout")
    end
    if not steal.victimGone and not canSecure(steal) then
        return finish(steal, "Failed", "EggChanged")
    end
    if not steal.carry or not steal.carry.Parent then
        buildCarry(steal)
    end

    -- movement: a leaky bucket of "extra" studs. Normal running never drains it, teleports / speed hacks do.
    local position = root.Position
    local dt = math.max(now - steal.lastT, 0.05)
    local flatMoved = (Vector3.new(position.X, 0, position.Z) - Vector3.new(steal.lastPos.X, 0, steal.lastPos.Z)).Magnitude
    steal.lastPos, steal.lastT = position, now
    if flatMoved > Rules.HardTeleportDistance then
        return finish(steal, "Failed", "Teleport")
    end
    steal.budget = math.min(Rules.SpeedSlack, steal.budget + Rules.MaxSpeed * dt - flatMoved)
    if steal.budget < 0 then
        steal.budget = 0
        steal.violations += 1
        if steal.violations >= Rules.MaxViolations then
            return finish(steal, "Failed", "Speed")
        end
    else
        steal.travelled += flatMoved -- only legitimate movement counts towards "really walked there"
        steal.violations = math.max(0, steal.violations - 0.1)
    end

    if steal.victim and now >= steal.nextVictimUpdate then
        steal.nextVictimUpdate = now + Rules.VictimUpdateRate
        fire(steal.victim, "Pos", steal.id, position)
    end

    if now - steal.startedAt >= Rules.MinCarrySeconds and steal.travelled >= steal.needTravel then
        local _, inside = baseDistance(home, position)
        if inside then
            finish(steal, "Secured")
        end
    end
end

local function ensureLoop()
    if loopRunning then
        return
    end
    loopRunning = true
    task.spawn(function()
        while next(steals) do
            local now = os.clock()
            for _, steal in steals do
                local ok, err = pcall(tick, steal, now)
                if not ok then
                    warn("[EggSteal] tick error, cancelling steal: " .. tostring(err))
                    finish(steal, "Failed", "Error")
                end
            end
            task.wait(Rules.TickRate)
        end
        loopRunning = false
    end)
end

-- ─────────────────────────── starting a steal ───────────────────────────
startSteal = function(thief, chamber)
    if Rules.Enabled == false then
        return
    end
    if typeof(thief) ~= "Instance" or not thief:IsA("Player") or thief.Parent ~= Players then
        return
    end
    if steals[thief] or os.clock() < (cooldownUntil[thief] or 0) then
        return
    end
    local rec = chambers[chamber]
    if not rec or not rec.anchor or not stealable(chamber) then
        return
    end

    local _char, hum, root = aliveRoot(thief)
    if not root then
        return
    end
    if (root.Position - rec.anchor.Position).Magnitude > Rules.MaxStealDistance then
        return
    end

    local plot = chamber.Parent and chamber.Parent.Parent
    local victimId = plot and plot:GetAttribute("OwnerUserId") or 0
    if victimId == 0 or victimId == thief.UserId then
        return
    end
    local home = homePlot(thief)
    if not home or home == plot then
        return
    end -- you need a base to run back to
    local tool, victim = findEggTool(chamber)
    if not tool or not victim then
        return
    end
    local info = eggInfo(tool)
    if info.eggId and byEggId[info.eggId] then
        return
    end
    if Service.CanSteal and Service.CanSteal(thief, victim, chamber) == false then
        return
    end

    -- ── from here to the end of this block there are NO yields: lock + register is atomic ──
    nextId += 1
    local carryModel = eggSource(tool, info)
    local baseDist = baseDistance(home, root.Position)
    local steal = {
        id = nextId,
        state = "Carrying",
        thief = thief,
        victim = victim,
        victimUserId = victim.UserId,
        victimGone = false,
        chamber = chamber,
        plot = plot,
        home = home,
        tool = tool,
        info = info,
        eggClone = tool:Clone(), -- what the thief receives if they make it
        carrySource = carryModel and carryModel:Clone() or nil, -- what they visibly carry
        startedAt = os.clock(),
        lastPos = root.Position,
        lastT = os.clock(),
        budget = Rules.SpeedSlack,
        violations = 0,
        travelled = 0,
        needTravel = math.max(0, baseDist - 6) * Rules.TravelFraction,
        nextVictimUpdate = 0,
        conns = {},
    }
    steals[thief] = steal
    byChamber[chamber] = steal
    if info.eggId then
        byEggId[info.eggId] = steal
    end
    chamber:SetAttribute("StealLock", thief.UserId)
    local hatch = hatchPrompt(chamber)
    if hatch then
        hatch.Enabled = false
    end
    setEggHidden(chamber, true)

    table.insert(
        steal.conns,
        hum.Died:Connect(function()
            finish(steal, "Failed", "Died")
        end)
    )
    table.insert(
        steal.conns,
        thief.CharacterRemoving:Connect(function()
            finish(steal, "Failed", "Reset")
        end)
    )
    local basePos = home.PlotSpawn.Position
    -- Replicated state recovers the banner if a start event arrives before client startup.
    thief:SetAttribute("CarryingStolenEggBase", basePos)
    thief:SetAttribute("CarryingStolenEggType", info.eggType)
    thief:SetAttribute("CarryingStolenEggId", steal.id)
    local carried, carryError = pcall(buildCarry, steal)
    if not carried then
        warn("[EggSteal] carry visual: " .. tostring(carryError))
    end
    ensureLoop()
    fire(thief, "Start", {
        id = steal.id,
        name = info.name,
        eggType = info.eggType,
        rarity = info.rarity,
        price = info.price,
        base = basePos,
    })
    fire(victim, "Alert", {
        id = steal.id,
        name = info.name,
        eggType = info.eggType,
        rarity = info.rarity,
        thiefName = thief.DisplayName,
        thiefUserId = thief.UserId,
        pos = root.Position,
    })
end

-- ─────────────────────────── lifecycle ───────────────────────────
local function onRemoving(player)
    local mine = steals[player]
    if mine then
        finish(mine, "Failed", "Left")
    end
    for _, steal in steals do
        if steal.victimUserId == player.UserId and steal.state == "Carrying" then
            steal.victimGone = true -- their egg goes with them; the thief may still secure the server-held clone
            steal.victim = nil
            if Rules.VictimLeaves == "Cancel" then
                finish(steal, "Failed", "VictimGone")
            end
        end
    end
    cooldownUntil[player] = nil
end

function Service.IsCarrying(player)
    return steals[player] ~= nil
end

-- cancel a player's steal from another system (teleports, admin commands, round resets…)
function Service.Cancel(player, reason)
    local steal = steals[player]
    if steal then
        finish(steal, "Failed", reason or "Cancelled")
    end
end

function Service.Init()
    if started then
        return
    end
    started = true
    stealEvent = StealFolder:FindFirstChild("Event")
    if not stealEvent then
        stealEvent = Instance.new("RemoteEvent")
        stealEvent.Name = "Event" -- server → client ONLY. Nothing ever listens to OnServerEvent.
        stealEvent.Parent = StealFolder
    end

    local plots = workspace:WaitForChild("Plots")
    local function watchPlot(plot)
        task.spawn(function()
            local chambersFolder = plot:WaitForChild("Chambers", 60)
            if not chambersFolder then
                return
            end
            chambersFolder.ChildAdded:Connect(register)
            for _, chamber in chambersFolder:GetChildren() do
                register(chamber)
            end
        end)
    end
    for _, plot in plots:GetChildren() do
        watchPlot(plot)
    end
    plots.ChildAdded:Connect(watchPlot)
    Players.PlayerRemoving:Connect(onRemoving)
end

return Service
