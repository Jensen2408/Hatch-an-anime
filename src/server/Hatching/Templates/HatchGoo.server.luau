local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Collection = game:GetService("CollectionService")
local h = script.Parent
while h:GetAttribute("UnderConstruction") do
    task.wait(0.05)
end
if not h.Parent then
    return
end
local frame = h:GetPivot()
local controller = require(game.ReplicatedStorage.IncubatorController).new(h)
h.Destroying:Connect(function()
    controller:Destroy()
end)
local m = h:WaitForChild("LiquidSystemAndTrim")
local button = m.HatchButton
local prompt = button.ProximityPrompt
local door = h.LoadingDoor
local liquid = m.TankLiquid
local text = m.TimerAnchor.CycleTimer.Status
local camera = game.ReplicatedStorage:WaitForChild("CinematicHatchCue")
local Rewards = require(game.ServerScriptService:WaitForChild("EggCharacterRewards"))
local Economy = require(game.ReplicatedStorage.CharacterEconomy)
local rest, doorRest = button.CFrame, door.CFrame
local fullSize, fullCF = liquid.Size, liquid.CFrame
local busy = false
local waitingOwner, startRequested
local complete = Instance.new("BindableEvent")
complete.Name = "HatchCycleCompleted"
complete.Parent = h
local function tween(p, t, props)
    local tw = TweenService:Create(p, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), props)
    tw:Play()
    return tw
end
local function say(state, message)
    h:SetAttribute("Status", state)
    text.Text = message
    m.TimerAnchor.CycleTimer.Enabled = state ~= "Ready" or message == "EQUIP AN EGG FIRST"
end
local function valid(player, range)
    if not player then
        return true
    end
    local plot = h.Parent and h.Parent.Parent
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return player.Parent == Players
        and plot
        and plot:GetAttribute("OwnerUserId") == player.UserId
        and root
        and hum
        and hum.Health > 0
        and (root.Position - button.Position).Magnitude < (range or 20)
end
-- An egg belongs to this chamber until collected. Walking away or respawning
-- does not cancel incubation; distance is checked only for button/pickup actions.
local function ownsChamber(player)
    if not player then
        return true
    end
    local plot = h.Parent and h.Parent.Parent
    return player.Parent == Players
        and plot
        and plot:GetAttribute("OwnerUserId") == player.UserId
        and not h:GetAttribute("EggStolen") -- EggSteal
end
local function press()
    tween(button, 0.1, { CFrame = rest + frame:VectorToWorldSpace(Vector3.new(0, 0, 0.25)) })
    task.delay(0.13, function()
        if button.Parent then
            tween(button, 0.18, { CFrame = rest })
        end
    end)
end
local function cycle(player, resumeTool, resumeLeft) -- resumeTool/resumeLeft: PlayerDataService puts a saved egg back with its remaining time
    if player and require(game.ServerScriptService.HatchFX.HatchFXServer).IsPlayerBusy(player) then
        return
    end
    if h:GetAttribute("StealLock") then
        return
    end -- EggSteal
    if h:GetAttribute("UnderConstruction") then
        return
    end
    if busy then
        if
            h:GetAttribute("Status") == "Loaded"
            and player == waitingOwner
            and valid(player, 20)
            and not startRequested
        then
            startRequested = true
            prompt.Enabled = false
            press()
        end
        return
    end
    if not resumeTool and not valid(player, 20) then
        return
    end
    if resumeTool and not ownsChamber(player) then
        return
    end
    local tool, source
    if player then
        if resumeTool then
            tool = resumeTool
        else
            for _, v in player.Character:GetChildren() do
                if v:IsA("Tool") and v.Name:lower():find("egg") then
                    tool = v
                    break
                end
            end
        end
        source = tool and tool:FindFirstChild("Egg")
    else
        source = game.ServerStorage:FindFirstChild("WaterfallEggTemplate")
    end
    if not source or not source:IsA("Model") then
        say("Ready", "EQUIP AN EGG FIRST")
        task.delay(2, function()
            if not busy then
                say("Ready", "HOLD AN EGG • INSERT")
            end
        end)
        return
    end
    local rewardTemplate, rewardId = Rewards.Resolve(tool, source)
    if not rewardTemplate then
        say("Ready", "NO CHARACTER FOR " .. tostring(rewardId):upper())
        return
    end
    busy = true
    prompt.Enabled = false
    waitingOwner = player
    startRequested = false
    local visual, pickupAnchor, eggTimer, timerAnchor
    local enabled = tool and tool.Enabled
    local mut = tool and tool:GetAttribute("Mutation") -- the egg's mutation carries over to the egg in the tank, the reveal and the character
    local Mutations = require(game.ServerScriptService.Mutations)
    local focusSent = false
    local ok, err = xpcall(function()
        local Timing = require(game.ReplicatedStorage.EggHatchTiming)
        local rewardStats = Economy.Read(tool, rewardId) or Economy.Roll(rewardId)
        if tool then
            Economy.Apply(tool, rewardId, rewardStats)
        end
        local seconds = Timing.Seconds(rewardId, rewardStats)
        if resumeTool and tonumber(tool:GetAttribute("HatchSeconds")) then
            seconds = tonumber(tool:GetAttribute("HatchSeconds"))
        end
        if not player then
            seconds = h:GetAttribute("PreviewHatchSeconds") or seconds
        end
        if tool then
            tool:SetAttribute("HatchSeconds", seconds)
        end
        seconds = math.clamp(seconds, 1, 86400)
        if tool then
            tool:SetAttribute("Incubating", true)
            tool:SetAttribute("IncubatorChamber", h:GetFullName()) -- EggSteal
            if not resumeTool and player.Character then
                player.Character.Humanoid:UnequipTools()
            end
            local held = player:FindFirstChild("IncubatorHeldEggs") or Instance.new("Folder")
            held.Name = "IncubatorHeldEggs"
            held.Parent = player
            tool.Enabled = false
            tool.Parent = held
            task.wait() -- let the carry visual restore the tool's own egg before we copy it
        end
        local eggTemplates = game.ServerStorage:FindFirstChild("AuxEggTemplates")
        local eggType = tool and tool:GetAttribute("EggType")
        local cleanSource = eggType and eggTemplates and eggTemplates:FindFirstChild(eggType)
        if tool and tool:GetAttribute("GoldVariant") then
            cleanSource = game.ServerStorage.FutureUpdateContent.Eggs:FindFirstChild("Golden Pirate")
        end
        if mut then
            cleanSource = nil
        end -- mutated egg: use its own mutated model (with aura), not the plain template
        visual = (cleanSource or source):Clone()
        visual.Name = "IncubatingEgg"
        -- Tool carry hides its own geometry; chamber visuals must never inherit that state.
        for _, part in visual:GetDescendants() do
            if part:IsA("BasePart") then
                local alpha = part:GetAttribute("CarryOriginalTransparency")
                if alpha ~= nil then
                    part.Transparency = alpha
                end
                part.LocalTransparencyModifier = 0
            elseif part:IsA("WeldConstraint") or part:IsA("JointInstance") then
                part:Destroy()
            end
        end
        for _, v in visual:GetDescendants() do
            if v:IsA("LuaSourceContainer") or v:IsA("ProximityPrompt") or v:IsA("BillboardGui") then
                v:Destroy()
            elseif v:IsA("BasePart") then
                v.Anchored = true
                v.CanCollide = false
                v.CanTouch = false
                v.CanQuery = false
            end
        end
        local _, size = visual:GetBoundingBox()
        visual:ScaleTo(visual:GetScale() * math.min(2.5 / size.Y, 2.6 / size.X, 2.6 / size.Z))
        local box = visual:GetBoundingBox()
        visual.PrimaryPart = nil
        visual.WorldPivot = CFrame.new(box.Position)
        local inside = frame * CFrame.new(0, 3.5, -1.5)
        visual:PivotTo(inside)
        visual:SetAttribute("ChamberHome", inside)
        local appearances = {}
        for _, p in visual:GetDescendants() do
            if p:IsA("BasePart") then
                appearances[p] = p.Transparency
                p.Transparency = 1
            end
        end
        visual.Parent = h
        local chamberBox, chamberSize = h:GetBoundingBox()
        timerAnchor = Instance.new("Attachment")
        timerAnchor.Name = "IncubationTimerAnchor"
        timerAnchor.Parent = m.TimerAnchor
        timerAnchor.WorldPosition = chamberBox.Position + Vector3.new(0, chamberSize.Y / 2 + 1, 0)
        eggTimer = Instance.new("BillboardGui")
        eggTimer.Name = "IncubationCountdown"
        eggTimer.Adornee = timerAnchor
        eggTimer.Size = UDim2.fromScale(4, 0.65)
        eggTimer.StudsOffsetWorldSpace = Vector3.zero
        eggTimer.MaxDistance = 65
        eggTimer.AlwaysOnTop = true
        eggTimer.Parent = h
        local timerText = Instance.new("TextLabel")
        timerText.Size = UDim2.fromScale(1, 1)
        timerText.BackgroundColor3 = Color3.fromRGB(29, 38, 57)
        timerText.BackgroundTransparency = 0.15
        timerText.TextColor3 = Color3.fromRGB(213, 236, 255)
        timerText.Font = Enum.Font.GothamBold
        timerText.TextScaled = true
        timerText.Text = Timing.Format(seconds)
        timerText.Parent = eggTimer
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.3, 0)
        corner.Parent = timerText
        -- HatchFX owns this chamber egg presentation.
        say("Loading", "INSERTING EGG")
        controller:Open(0.45)
        press()
        h:SetAttribute("TeleportPulse", workspace:GetServerTimeNow())
        task.wait(0.22)
        for p, alpha in appearances do
            if p.Parent then
                tween(p, 0.35, { Transparency = alpha })
            end
        end
        task.wait(0.45)
        controller:Close(0.45)
        local incubationStart = workspace:GetServerTimeNow()
        h:SetAttribute("Hatching", true)
        h:SetAttribute("HatchStart", incubationStart)
        h:SetAttribute("HatchDuration", seconds)
        h:SetAttribute("CycleEnd", incubationStart + seconds)
        say("Incubating", "INCUBATING")
        local workLeft = resumeLeft and math.clamp(resumeLeft, 0, seconds) or seconds
        local previous = workspace:GetServerTimeNow()
        while workLeft > 0 do
            if not ownsChamber(player) or not h:IsDescendantOf(workspace) then
                return
            end
            local now = workspace:GetServerTimeNow()
            local speed = (workspace:GetAttribute("NightHatchSpeedMultiplier") or 1)
                * (player and player:GetAttribute("HatchMultiplier") or 1)
            workLeft = math.max(0, workLeft - (now - previous) * speed)
            previous = now
            local remaining = math.ceil(workLeft / speed)
            timerText.Text = Timing.Format(remaining) .. (speed > 1 and "  •  2×" or "")
            h:SetAttribute("CycleEnd", now + workLeft / speed)
            h:SetAttribute("HatchDuration", seconds / speed)
            text.Text = string.format("INCUBATING • %02d:%02d", math.floor(remaining / 60), remaining % 60)
            local progress = 1 - workLeft / seconds
            liquid.Size = fullSize:Lerp(Vector3.new(0.5, fullSize.Y, fullSize.Z), progress)
            liquid.CFrame = fullCF:Lerp(fullCF - Vector3.new(0, (fullSize.X - 0.5) / 2, 0), progress)
            task.wait(0.1)
        end
        h:SetAttribute("Hatching", false)
        h:SetAttribute("CycleEnd", nil)
        timerText.Text = "READY TO HATCH"
        say("Loaded", "READY • PRESS HATCH")
        prompt.ActionText = "Hatch"
        prompt.ObjectText = rewardId .. " Egg"
        prompt.Enabled = player ~= nil and not h:GetAttribute("StealLock") -- EggSteal
        while player and not startRequested do
            if not ownsChamber(player) or not h:IsDescendantOf(workspace) then
                return
            end
            task.wait(0.08)
        end
        prompt.Enabled = false
        if not ownsChamber(player) then
            return
        end
        local HatchFX = require(game.ServerScriptService.HatchFX.HatchFXServer)
        while player and HatchFX.IsPlayerBusy(player) do
            startRequested = false
            prompt.Enabled = true
            if not ownsChamber(player) or not h:IsDescendantOf(workspace) then
                return
            end
            task.wait(0.1)
        end
        if player and not startRequested then
            say("Loaded", "READY • PRESS HATCH")
            prompt.Enabled = true
            while not startRequested do
                if not ownsChamber(player) or not h:IsDescendantOf(workspace) then
                    return
                end
                task.wait(0.08)
            end
        end
        prompt.Enabled = false
        eggTimer.Enabled = false
        local Config = require(game.ReplicatedStorage.HatchFX.HatchFXConfig)
        local Catalog = require(game.ReplicatedStorage.CharacterCatalog)
        -- rewardStats was rolled once when the egg was created or inserted.
        local earlyTimeline = Config.Timeline(rewardStats.RollQuality, Catalog.ById[rewardId].Rarity)
        if player then
            focusSent = true
            -- the cinematic camera is a nice extra: if the client never answers (slow device, UI error) the hatch still happens
            if not require(game.ServerScriptService.HatchCameraGate).Focus(player, h, inside, earlyTimeline.Break) then
                warn("[Hatch] camera not ready for " .. player.Name .. " - hatching without the cinematic")
            end
        end
        say("HatchReveal", "OPENING...")
        task.spawn(function()
            controller:Open(0.65)
        end)
        local character = (mut and Mutations.Model(rewardId, mut, rewardTemplate)) or rewardTemplate:Clone()
        character.Name = "HatchedCharacter"
        if mut then
            character:SetAttribute("Mutation", mut)
        end
        for _, p in character:GetDescendants() do
            if p:IsA("BasePart") then
                p.Anchored = true
                p.CanCollide = false
                p.CanTouch = false
                p.CanQuery = false
            end
        end
        local _, charSize = character:GetBoundingBox()
        character:ScaleTo(character:GetScale() * 6 / math.max(charSize.Y, 0.01))
        local charBox, finalSize = character:GetBoundingBox()
        local bottom = charBox.Y - finalSize.Y * 0.5
        local home = frame * CFrame.new(0, 2.25, -5.5)
        character:PivotTo(home * CFrame.new(0, finalSize.Y * 0.5, 0) * charBox:ToObjectSpace(character:GetPivot()))
        character:SetAttribute("RewardHome", character:GetPivot())
        character:SetAttribute("RevealEpoch", workspace:GetServerTimeNow())
        character:SetAttribute("CharacterId", rewardId)
        character:SetAttribute("ChamberReveal", true)
        Economy.Apply(character, rewardId, rewardStats)
        if mut then
            pcall(Mutations.AddAura, character, mut)
        end

        local oldEgg = visual
        local timeline = Config.Timeline(character:GetAttribute("RollQuality"), Catalog.ById[rewardId].Rarity)

        if player then
            camera:FireClient(player, "HatchStarted", h)
        end
        say("HatchReveal", "HATCHING...")
        local finished = false
        local played, reason = HatchFX.Play({
            incubator = h,
            owner = player,
            egg = oldEgg,
            character = character,
            characterParent = h,
            displayCFrame = character:GetPivot(),
            rarity = Catalog.ById[rewardId].Rarity,
            name = Catalog.ById[rewardId].Name,
            power = rewardStats.Power,
            income = rewardStats.IncomePerSecond,
            roll = character:GetAttribute("RollQuality"),
            closeGlass = function() end,
            openGlass = function() end,
            onComplete = function()
                finished = true
            end,
        })
        if not played then
            character:Destroy()
            error("HatchFX: " .. tostring(reason))
        end
        visual = character
        local epoch = workspace:GetServerTimeNow()
        local revealed = false
        while not finished do
            if not ownsChamber(player) or not h:IsDescendantOf(workspace) then
                HatchFX.Cancel(h)
                return
            end
            if not revealed and workspace:GetServerTimeNow() - epoch >= timeline.Break then
                revealed = true
                if player then
                    camera:FireClient(player, "Reveal", h, home * CFrame.new(0, finalSize.Y * 0.5, 0), rewardId)
                end
            end
            task.wait(0.05)
        end
        character:SetAttribute("RewardHome", character:GetPivot())
        character:SetAttribute("RevealEpoch", workspace:GetServerTimeNow())
        Economy.Label(character, rewardId, rewardStats)
        h:SetAttribute("RewardId", rewardId)
        Collection:AddTag(character, "HatchRewardDisplay")
        complete:Fire(player, tool, rewardId)
        if player then
            camera:FireClient(player, "End", h)
            focusSent = false
        end
        h:SetAttribute("Venting", true)
        controller:Open(0.45)
        say(
            "AwaitingPickup",
            "POWER "
                .. Economy.Format(rewardStats.Power)
                .. " • $"
                .. Economy.Format(rewardStats.IncomePerSecond)
                .. "/sec"
        )
        pickupAnchor = Instance.new("Part")
        pickupAnchor.Name = "EggPickupAnchor"
        pickupAnchor.Size = Vector3.one
        pickupAnchor.Transparency = 1
        pickupAnchor.Anchored = true
        pickupAnchor.CanCollide = false
        pickupAnchor.CanTouch = false
        pickupAnchor.CanQuery = false
        pickupAnchor.Position = frame:PointToWorldSpace(Vector3.new(0, 3.5, -1.5))
        pickupAnchor.Parent = h
        local pickup = Instance.new("ProximityPrompt")
        pickup.Name = "PickUpCharacter"
        pickup.ActionText = "Collect character"
        pickup.ObjectText = rewardId .. " • Power " .. Economy.Format(rewardStats.Power)
        pickup.RequiresLineOfSight = false
        pickup.MaxActivationDistance = 12
        pickup.HoldDuration = 0.2
        pickup.Parent = pickupAnchor
        local collected = false
        local function collect(who)
            if collected or (player and who ~= player) then
                return
            end
            local root = who and who.Character and who.Character:FindFirstChild("HumanoidRootPart")
            local bag = who and who:FindFirstChildOfClass("Backpack")
            if not root or not bag or (root.Position - pickupAnchor.Position).Magnitude > 14 then
                return
            end
            collected = true
            pickup.Enabled = false
            local rewardTool = Rewards.Tool(rewardTemplate, rewardId, rewardStats, mut or nil)
            rewardTool.Parent = bag
            local humanoid = who.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:EquipTool(rewardTool)
            end
            collected = true
            pickup.Enabled = false
            if tool and tool.Parent then
                tool:Destroy()
                tool = nil
            end
        end
        pickup.Triggered:Connect(collect)
        local request = Instance.new("BindableEvent")
        request.Name = "RequestPickup"
        request.Parent = pickupAnchor
        request.Event:Connect(collect)
        task.delay(2, function()
            if h.Parent then
                h:SetAttribute("Venting", false)
            end
        end)
        while not collected and (not player or player.Parent == Players) and h:IsDescendantOf(workspace) do
            task.wait(0.1)
        end
    end, debug.traceback)
    if focusSent and player and player.Parent == Players then
        camera:FireClient(player, "End", h)
    end
    h:SetAttribute("Hatching", false)
    h:SetAttribute("Venting", false)
    h:SetAttribute("CycleEnd", nil)
    h:SetAttribute("RewardId", nil)
    h:SetAttribute("CrackStage", nil)
    require(game.ServerScriptService.HatchFX.HatchFXServer).Cancel(h)
    if eggTimer then
        eggTimer:Destroy()
    end
    if timerAnchor then
        timerAnchor:Destroy()
    end
    if pickupAnchor then
        pickupAnchor:Destroy()
    end
    if visual then
        visual:Destroy()
    end
    if tool and tool.Parent then
        tool:SetAttribute("Incubating", nil)
        tool.Enabled = enabled
        local bag = player and player:FindFirstChildOfClass("Backpack")
        if bag then
            tool.Parent = bag
        end
    end
    if button.Parent then
        tween(button, 0.2, { CFrame = rest })
    end
    if h.Parent then
        controller:Close(0.45)
    end
    if liquid.Parent then
        tween(liquid, 1.25, { Size = fullSize, CFrame = fullCF }).Completed:Wait()
    end
    busy = false
    waitingOwner = nil
    startRequested = false
    prompt.ActionText = "Insert egg"
    prompt.ObjectText = "Hatching chamber"
    prompt.Enabled = true
    say("Ready", "HOLD AN EGG • INSERT")
    if not ok then
        warn("Hatch cycle recovered: " .. tostring(err))
    end
end
button.ClickDetector.MouseClick:Connect(cycle)
prompt.Triggered:Connect(cycle)
h.RequestHatch.Event:Connect(cycle)
h:SetAttribute("Hatching", false)
prompt.ActionText = "Insert egg"
say("Ready", "HOLD AN EGG • INSERT")

do
    local r = h:FindFirstChild("ResumeEgg") or Instance.new("BindableFunction")
    r.Name = "ResumeEgg"
    r.Parent = h
    r.OnInvoke = function(player, tool, left)
        if busy or h:GetAttribute("UnderConstruction") then
            return false
        end
        task.spawn(cycle, player, tool, left)
        return true
    end
end
