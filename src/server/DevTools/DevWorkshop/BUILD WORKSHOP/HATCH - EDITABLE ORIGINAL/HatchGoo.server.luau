--[[ HatchGoo — EDITABLE ORIGINAL (ServerStorage DevWorkshop, Script is Disabled)
Older reference version of the hatch chamber script kept with the editable build model in the
BUILD WORKSHOP. The live script is src/server/Hatching/Templates/HatchGoo.server.luau; this copy is
NOT kept in sync with it (no IncubatorController glass, HatchFX, economy rolls, mutations, countdown
billboard, resume or EggSteal support). Its own scripted 6 s reveal and the sliding LoadingDoor live here.

`chamberPivot` is the model pivot shifted by (-22.75, -26, -92); the egg/character/pickup offsets
below (22.75, ~34, ~90) undo that shift for this model, unlike the templates which use the pivot directly.
Uses ReplicatedStorage.CinematicHatchCue ("Start" / "Reveal" / "End") and fires chamber.HatchCycleCompleted.
--]]
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local chamber = script.Parent
local chamberPivot = chamber:GetPivot() * CFrame.new(-22.75, -26, -92)
local liquidSystem = chamber:WaitForChild("LiquidSystemAndTrim")
local hatchButton = liquidSystem.HatchButton
local prompt = hatchButton.ProximityPrompt
local loadingDoor = chamber.LoadingDoor
local tankLiquid = liquidSystem.TankLiquid
local statusLabel = liquidSystem.TimerAnchor.CycleTimer.Status
local cinematicCue = game.ReplicatedStorage:WaitForChild("CinematicHatchCue")
local Rewards = require(game.ServerScriptService:WaitForChild("EggCharacterRewards"))
local buttonRest, doorRest = hatchButton.CFrame, loadingDoor.CFrame
local liquidFullSize, liquidFullCFrame = tankLiquid.Size, tankLiquid.CFrame

-- Cycle state (one cycle per chamber at a time)
local busy = false
local waitingOwner, startRequested

local cycleCompleted = Instance.new("BindableEvent")
cycleCompleted.Name = "HatchCycleCompleted"
cycleCompleted.Parent = chamber

local function tween(instance, duration, props)
    local activeTween =
        TweenService:Create(instance, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), props)
    activeTween:Play()
    return activeTween
end

-- Sets the replicated Status attribute and the chamber's status text.
local function say(state, message)
    chamber:SetAttribute("Status", state)
    statusLabel.Text = message
    liquidSystem.TimerAnchor.CycleTimer.Enabled = state ~= "Ready" or message == "EQUIP AN EGG FIRST"
end

-- Owner, alive and within `range` studs of the hatch button. A nil player is the preview cycle.
local function canUseChamber(player, range)
    if not player then
        return true
    end
    local plot = chamber.Parent and chamber.Parent.Parent
    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return player.Parent == Players
        and plot
        and plot:GetAttribute("OwnerUserId") == player.UserId
        and rootPart
        and humanoid
        and humanoid.Health > 0
        and (rootPart.Position - hatchButton.Position).Magnitude < (range or 20)
end

-- An egg belongs to this chamber until collected. Walking away or respawning
-- does not cancel incubation; distance is checked only for button/pickup actions.
local function ownsChamber(player)
    if not player then
        return true
    end
    local plot = chamber.Parent and chamber.Parent.Parent
    return player.Parent == Players and plot and plot:GetAttribute("OwnerUserId") == player.UserId
end

local function pressButton()
    tween(hatchButton, 0.1, { CFrame = buttonRest + chamberPivot:VectorToWorldSpace(Vector3.new(0, 0, 0.25)) })
    task.delay(0.13, function()
        if hatchButton.Parent then
            tween(hatchButton, 0.18, { CFrame = buttonRest })
        end
    end)
end

-- One full hatch cycle; also the "press hatch" handler while a cycle waits in "Loaded".
local function runCycle(player)
    if chamber:GetAttribute("UnderConstruction") then
        return
    end
    if busy then
        if
            chamber:GetAttribute("Status") == "Loaded"
            and player == waitingOwner
            and canUseChamber(player, 20)
            and not startRequested
        then
            startRequested = true
            prompt.Enabled = false
            pressButton()
        end
        return
    end
    if not canUseChamber(player, 20) then
        return
    end
    local tool, eggSource
    if player then
        for _, child in player.Character:GetChildren() do
            if child:IsA("Tool") and child.Name:lower():find("egg") then
                tool = child
                break
            end
        end
        eggSource = tool and tool:FindFirstChild("Egg")
    else
        eggSource = game.ServerStorage:FindFirstChild("WaterfallEggTemplate")
    end
    if not eggSource or not eggSource:IsA("Model") then
        say("Ready", "EQUIP AN EGG FIRST")
        task.delay(2, function()
            if not busy then
                say("Ready", "HOLD AN EGG • INSERT")
            end
        end)
        return
    end
    local rewardTemplate, rewardId = Rewards.Resolve(tool, eggSource)
    if not rewardTemplate then
        say("Ready", "NO CHARACTER FOR " .. tostring(rewardId):upper())
        return
    end
    busy = true
    prompt.Enabled = false
    waitingOwner = player
    startRequested = false
    local visual, pickupAnchor
    local toolWasEnabled = tool and tool.Enabled
    local focusSent = false
    local ok, err = xpcall(function()
        local hatchSeconds = tonumber(tool and tool:GetAttribute("HatchSeconds"))
            or chamber:GetAttribute("PreviewHatchSeconds")
            or 10
        hatchSeconds = math.clamp(hatchSeconds, 1, 3600)
        if tool then
            tool:SetAttribute("Incubating", true)
            player.Character.Humanoid:UnequipTools()
            local heldEggs = player:FindFirstChild("IncubatorHeldEggs") or Instance.new("Folder")
            heldEggs.Name = "IncubatorHeldEggs"
            heldEggs.Parent = player
            tool.Enabled = false
            tool.Parent = heldEggs
        end
        local eggTemplates = game.ServerStorage:FindFirstChild("AuxEggTemplates")
        local eggType = tool and tool:GetAttribute("EggType")
        local cleanSource = eggType and eggTemplates and eggTemplates:FindFirstChild(eggType)
        visual = (cleanSource or eggSource):Clone()
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
        for _, descendant in visual:GetDescendants() do
            if
                descendant:IsA("LuaSourceContainer")
                or descendant:IsA("ProximityPrompt")
                or descendant:IsA("BillboardGui")
            then
                descendant:Destroy()
            elseif descendant:IsA("BasePart") then
                descendant.Anchored = true
                descendant.CanCollide = false
                descendant.CanTouch = false
                descendant.CanQuery = false
            end
        end
        local _, eggSize = visual:GetBoundingBox()
        visual:ScaleTo(visual:GetScale() * math.min(2.5 / eggSize.Y, 2.6 / eggSize.X, 2.6 / eggSize.Z))
        local eggBox = visual:GetBoundingBox()
        visual.PrimaryPart = nil
        visual.WorldPivot = CFrame.new(eggBox.Position)
        local inside = chamberPivot * CFrame.new(22.75, 34.125, 92)
        visual:PivotTo(inside)
        visual:SetAttribute("ChamberHome", inside)
        local targetTransparency = {}
        for _, part in visual:GetDescendants() do
            if part:IsA("BasePart") then
                targetTransparency[part] = part.Transparency
                part.Transparency = 1
            end
        end
        visual.Parent = chamber
        say("Loading", "INSERTING EGG")
        pressButton()
        chamber:SetAttribute("TeleportPulse", workspace:GetServerTimeNow())
        task.wait(0.22)
        for part, alpha in targetTransparency do
            if part.Parent then
                tween(part, 0.35, { Transparency = alpha })
            end
        end
        task.wait(0.45)

        -- Incubate: one long liquid tween, countdown from the start time.
        local incubationStart = workspace:GetServerTimeNow()
        chamber:SetAttribute("Hatching", true)
        chamber:SetAttribute("HatchStart", incubationStart)
        chamber:SetAttribute("HatchDuration", hatchSeconds)
        chamber:SetAttribute("CycleEnd", incubationStart + hatchSeconds)
        say("Incubating", "INCUBATING")
        tween(tankLiquid, hatchSeconds, {
            Size = Vector3.new(0.5, liquidFullSize.Y, liquidFullSize.Z),
            CFrame = liquidFullCFrame - Vector3.new(0, (liquidFullSize.X - 0.5) / 2, 0),
        })
        while workspace:GetServerTimeNow() < incubationStart + hatchSeconds do
            if not ownsChamber(player) or not chamber:IsDescendantOf(workspace) then
                return
            end
            local remaining = math.ceil(incubationStart + hatchSeconds - workspace:GetServerTimeNow())
            statusLabel.Text = string.format("INCUBATING • %02d:%02d", math.floor(remaining / 60), remaining % 60)
            task.wait(0.1)
        end
        chamber:SetAttribute("Hatching", false)
        chamber:SetAttribute("CycleEnd", nil)
        say("Loaded", "READY • PRESS HATCH")
        prompt.ActionText = "Hatch"
        prompt.ObjectText = rewardId .. " Egg"
        prompt.Enabled = player ~= nil
        while player and not startRequested do
            if not ownsChamber(player) or not chamber:IsDescendantOf(workspace) then
                return
            end
            task.wait(0.08)
        end
        prompt.Enabled = false
        if not ownsChamber(player) then
            return
        end

        -- Scripted reveal: the egg travels out for 1.7 s, then cracks in 4 stages until `duration`.
        local duration = 6
        local epoch = workspace:GetServerTimeNow()
        local outside = inside * CFrame.new(0, 0, -5.5)
        visual:SetAttribute("HatchEpoch", epoch)
        visual:SetAttribute("HatchDuration", duration)
        visual:SetAttribute("HatchOutside", outside)
        visual:SetAttribute("HatchTravelDuration", 1.7)
        visual:SetAttribute("HatchOwner", player and player.UserId or 0)
        tween(loadingDoor, 0.55, { CFrame = doorRest + chamberPivot:VectorToWorldSpace(Vector3.new(-4.25, 0, 0)) })
        CollectionService:AddTag(visual, "CinematicEggHatch")
        if player then
            cinematicCue:FireClient(player, "Start", chamber, inside, duration)
            focusSent = true
        end
        say("HatchReveal", "HATCHING...")
        while workspace:GetServerTimeNow() < epoch + duration do
            if not ownsChamber(player) or not chamber:IsDescendantOf(workspace) then
                return
            end
            local elapsed = workspace:GetServerTimeNow() - epoch
            local travelAlpha = TweenService:GetValue(
                math.clamp(elapsed / 1.7, 0, 1),
                Enum.EasingStyle.Sine,
                Enum.EasingDirection.InOut
            )
            visual:PivotTo(inside:Lerp(outside, travelAlpha))
            chamber:SetAttribute(
                "CrackStage",
                math.min(4, math.floor(math.max(0, elapsed - 1.7) / (duration - 1.7) * 4))
            )
            statusLabel.Text = elapsed < 1.7 and "RELEASING EGG..."
                or elapsed < 4.5 and "SHELL CRACKING..."
                or "AWAKENING..."
            task.wait(0.05)
        end
        visual:PivotTo(outside)
        chamber:SetAttribute("Hatching", false)
        chamber:SetAttribute("CrackStage", 4)
        say("Revealing", "HATCHING " .. rewardId:upper())
        visual:SetAttribute("HatchOpening", true)
        if player then
            cinematicCue:FireClient(player, "Reveal", chamber, outside, rewardId)
        end
        task.wait(0.55)
        local oldEgg = visual
        for _, part in oldEgg:GetDescendants() do
            if part:IsA("BasePart") then
                tween(part, 0.25, { Transparency = 1 })
            end
        end
        local character = rewardTemplate:Clone()
        character.Name = "HatchedCharacter"
        for _, part in character:GetDescendants() do
            if part:IsA("BasePart") then
                part.Anchored = true
                part.CanCollide = false
                part.CanTouch = false
                part.CanQuery = false
            end
        end
        local _, charSize = character:GetBoundingBox()
        character:ScaleTo(character:GetScale() * math.min(2.65 / charSize.Y, 1.95 / charSize.X, 1.85 / charSize.Z))
        local charBox, finalSize = character:GetBoundingBox()
        local _bottom = charBox.Y - finalSize.Y * 0.5
        local home = chamberPivot * CFrame.new(22.75, 32.975, 86.5)
        character:PivotTo(home * CFrame.new(0, finalSize.Y * 0.5, 0) * charBox:ToObjectSpace(character:GetPivot()))
        character:SetAttribute("RewardHome", character:GetPivot())
        character:SetAttribute("RevealEpoch", workspace:GetServerTimeNow())
        character:SetAttribute("CharacterId", rewardId)
        character:SetAttribute("ChamberReveal", true)
        character.Parent = chamber
        visual = character
        chamber:SetAttribute("RewardId", rewardId)
        CollectionService:AddTag(character, "HatchRewardDisplay")
        task.delay(0.3, function()
            if oldEgg.Parent then
                oldEgg:Destroy()
            end
        end)
        cycleCompleted:Fire(player, tool, rewardId)
        task.wait(2.3)
        if player then
            cinematicCue:FireClient(player, "End", chamber)
            focusSent = false
        end

        -- Pickup
        chamber:SetAttribute("Venting", true)
        tween(loadingDoor, 0.45, { CFrame = doorRest + chamberPivot:VectorToWorldSpace(Vector3.new(-4.25, 0, 0)) })
        say("AwaitingPickup", "READY • COLLECT " .. rewardId:upper())
        pickupAnchor = Instance.new("Part")
        pickupAnchor.Name = "EggPickupAnchor"
        pickupAnchor.Size = Vector3.one
        pickupAnchor.Transparency = 1
        pickupAnchor.Anchored = true
        pickupAnchor.CanCollide = false
        pickupAnchor.CanTouch = false
        pickupAnchor.CanQuery = false
        pickupAnchor.Position = chamberPivot:PointToWorldSpace(Vector3.new(22.75, 34.125, 87))
        pickupAnchor.Parent = chamber
        local pickup = Instance.new("ProximityPrompt")
        pickup.Name = "PickUpCharacter"
        pickup.ActionText = "Collect character"
        pickup.ObjectText = rewardId
        pickup.RequiresLineOfSight = false
        pickup.MaxActivationDistance = 12
        pickup.HoldDuration = 0.2
        pickup.Parent = pickupAnchor
        local collected = false
        local function collect(who)
            if collected or (player and who ~= player) then
                return
            end
            local rootPart = who and who.Character and who.Character:FindFirstChild("HumanoidRootPart")
            local backpack = who and who:FindFirstChildOfClass("Backpack")
            if not rootPart or not backpack or (rootPart.Position - pickupAnchor.Position).Magnitude > 14 then
                return
            end
            collected = true
            pickup.Enabled = false
            local rewardTool = Rewards.Tool(rewardTemplate, rewardId)
            rewardTool.Parent = backpack
            collected = true
            pickup.Enabled = false
            if tool and tool.Parent then
                tool:Destroy()
                tool = nil
            end
        end
        pickup.Triggered:Connect(collect)
        local pickupRequest = Instance.new("BindableEvent")
        pickupRequest.Name = "RequestPickup"
        pickupRequest.Parent = pickupAnchor
        pickupRequest.Event:Connect(collect)
        task.delay(2, function()
            if chamber.Parent then
                chamber:SetAttribute("Venting", false)
            end
        end)
        while not collected and (not player or player.Parent == Players) and chamber:IsDescendantOf(workspace) do
            task.wait(0.1)
        end
    end, debug.traceback)

    -- Cleanup (always runs, also after errors)
    if focusSent and player and player.Parent == Players then
        cinematicCue:FireClient(player, "End", chamber)
    end
    chamber:SetAttribute("Hatching", false)
    chamber:SetAttribute("Venting", false)
    chamber:SetAttribute("CycleEnd", nil)
    chamber:SetAttribute("RewardId", nil)
    chamber:SetAttribute("CrackStage", nil)
    if pickupAnchor then
        pickupAnchor:Destroy()
    end
    if visual then
        visual:Destroy()
    end
    if tool and tool.Parent then
        tool:SetAttribute("Incubating", nil)
        tool.Enabled = toolWasEnabled
        local backpack = player and player:FindFirstChildOfClass("Backpack")
        if backpack then
            tool.Parent = backpack
        end
    end
    if hatchButton.Parent then
        tween(hatchButton, 0.2, { CFrame = buttonRest })
    end
    if loadingDoor.Parent then
        tween(loadingDoor, 0.45, { CFrame = doorRest })
    end
    if tankLiquid.Parent then
        tween(tankLiquid, 1.25, { Size = liquidFullSize, CFrame = liquidFullCFrame }).Completed:Wait()
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

hatchButton.ClickDetector.MouseClick:Connect(runCycle)
prompt.Triggered:Connect(runCycle)
chamber.RequestHatch.Event:Connect(runCycle)
chamber:SetAttribute("Hatching", false)
prompt.ActionText = "Insert egg"
say("Ready", "HOLD AN EGG • INSERT")
