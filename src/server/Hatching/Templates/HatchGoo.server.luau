--[[ HatchGoo (Script inside every hatch chamber Model)
Rojo maps this one file into four incubators in ServerStorage: HatchChamberTemplate and
IncubatorUpgradeTemplates.Level1/2/3. PlotChambers clones those models into the plots, so every
chamber runs its own copy and everything below uses `script.Parent` (the chamber) as its root.

Hatch cycle (one at a time per chamber, guarded by `busy`):
  insert egg -> incubate (countdown, liquid drains) -> "READY • PRESS HATCH" -> owner presses again
  -> camera gate + HatchFX reveal -> reward character waits on the platform -> owner collects it.

Inputs:   HatchButton.ClickDetector, HatchButton.ProximityPrompt, chamber.RequestHatch (BindableEvent),
          chamber.ResumeEgg (BindableFunction, created here; PlayerDataService puts a saved egg back).
Outputs:  chamber.HatchCycleCompleted (BindableEvent, fired with player, eggTool, rewardId),
          ReplicatedStorage.CinematicHatchCue (RemoteEvent: "HatchStarted" / "Reveal" / "End"),
          chamber attributes Status / Hatching / HatchStart / HatchDuration / CycleEnd / RewardId / Venting ...
          that clients and other server scripts read.
Server authoritative: the reward roll is read from (or rolled onto) the egg tool before incubation starts.
EggSteal integration: the "StealLock" / "EggStolen" attributes and "IncubatorChamber" on the tool.
--]]
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local chamber = script.Parent

-- Plot builders flag a chamber while they move/rebuild it; its pivot is only final afterwards.
while chamber:GetAttribute("UnderConstruction") do
    task.wait(0.05)
end
if not chamber.Parent then
    return
end
local chamberPivot = chamber:GetPivot()
local glassController = require(game.ReplicatedStorage.IncubatorController).new(chamber)
chamber.Destroying:Connect(function()
    glassController:Destroy()
end)

local liquidSystem = chamber:WaitForChild("LiquidSystemAndTrim")
local hatchButton = liquidSystem.HatchButton
local prompt = hatchButton.ProximityPrompt
local loadingDoor = chamber.LoadingDoor
local tankLiquid = liquidSystem.TankLiquid
local statusLabel = liquidSystem.TimerAnchor.CycleTimer.Status
local cinematicCue = game.ReplicatedStorage:WaitForChild("CinematicHatchCue")
local Rewards = require(game.ServerScriptService:WaitForChild("EggCharacterRewards"))
local Economy = require(game.ReplicatedStorage.CharacterEconomy)

-- `_doorRest` is no longer used: the glass doors are driven by IncubatorController now.
local buttonRest, _doorRest = hatchButton.CFrame, loadingDoor.CFrame
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
-- The status billboard stays hidden while idle unless it is showing the "equip an egg" hint.
local function say(state, message)
    chamber:SetAttribute("Status", state)
    statusLabel.Text = message
    liquidSystem.TimerAnchor.CycleTimer.Enabled = state ~= "Ready" or message == "EQUIP AN EGG FIRST"
end

-- Owner, alive and within `range` studs of the hatch button. A nil player is the
-- server-side preview cycle (RequestHatch without a player) and is always allowed.
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
    return player.Parent == Players
        and plot
        and plot:GetAttribute("OwnerUserId") == player.UserId
        and not chamber:GetAttribute("EggStolen") -- EggSteal
end

local function pressButton()
    tween(hatchButton, 0.1, { CFrame = buttonRest + chamberPivot:VectorToWorldSpace(Vector3.new(0, 0, 0.25)) })
    task.delay(0.13, function()
        if hatchButton.Parent then
            tween(hatchButton, 0.18, { CFrame = buttonRest })
        end
    end)
end

-- One full hatch cycle. Also used as the "press hatch" handler while a cycle is waiting
-- in the "Loaded" state. resumeTool/resumeLeft: PlayerDataService puts a saved egg back
-- with its remaining incubation time (see ResumeEgg below).
local function runCycle(player, resumeTool, resumeLeft)
    if player and require(game.ServerScriptService.HatchFX.HatchFXServer).IsPlayerBusy(player) then
        return
    end
    -- EggSteal
    if chamber:GetAttribute("StealLock") then
        return
    end
    if chamber:GetAttribute("UnderConstruction") then
        return
    end
    if busy then
        -- Second press while the egg is ready: let the running cycle continue into the hatch.
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
    if not resumeTool and not canUseChamber(player, 20) then
        return
    end
    if resumeTool and not ownsChamber(player) then
        return
    end

    -- Find the egg: the held egg tool, the resumed tool, or the preview template.
    local tool, eggSource
    if player then
        if resumeTool then
            tool = resumeTool
        else
            for _, child in player.Character:GetChildren() do
                if child:IsA("Tool") and child.Name:lower():find("egg") then
                    tool = child
                    break
                end
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
    -- Instances created inside the xpcall body; the cleanup below destroys whatever exists.
    local visual, pickupAnchor, eggTimer, timerAnchor
    local toolWasEnabled = tool and tool.Enabled
    -- The egg's mutation carries over to the egg in the tank, the reveal and the character.
    local mutation = tool and tool:GetAttribute("Mutation")
    local Mutations = require(game.ServerScriptService.Mutations)
    local focusSent = false
    local ok, err = xpcall(function()
        ---------------------------------------------------------------- roll + duration
        local EggHatchTiming = require(game.ReplicatedStorage.EggHatchTiming)
        local rewardStats = Economy.Read(tool, rewardId) or Economy.Roll(rewardId)
        if tool then
            Economy.Apply(tool, rewardId, rewardStats)
        end
        local hatchSeconds = EggHatchTiming.Seconds(rewardId, rewardStats)
        if resumeTool and tonumber(tool:GetAttribute("HatchSeconds")) then
            hatchSeconds = tonumber(tool:GetAttribute("HatchSeconds"))
        end
        if not player then
            hatchSeconds = chamber:GetAttribute("PreviewHatchSeconds") or hatchSeconds
        end
        if tool then
            tool:SetAttribute("HatchSeconds", hatchSeconds)
        end
        hatchSeconds = math.clamp(hatchSeconds, 1, 86400)

        ---------------------------------------------------------------- take the egg tool
        if tool then
            tool:SetAttribute("Incubating", true)
            tool:SetAttribute("IncubatorChamber", chamber:GetFullName()) -- EggSteal
            if not resumeTool and player.Character then
                player.Character.Humanoid:UnequipTools()
            end
            local heldEggs = player:FindFirstChild("IncubatorHeldEggs") or Instance.new("Folder")
            heldEggs.Name = "IncubatorHeldEggs"
            heldEggs.Parent = player
            tool.Enabled = false
            tool.Parent = heldEggs
            task.wait() -- let the carry visual restore the tool's own egg before we copy it
        end

        ---------------------------------------------------------------- egg visual in the tank
        local eggTemplates = game.ServerStorage:FindFirstChild("AuxEggTemplates")
        local eggType = tool and tool:GetAttribute("EggType")
        local cleanSource = eggType and eggTemplates and eggTemplates:FindFirstChild(eggType)
        if tool and tool:GetAttribute("GoldVariant") then
            cleanSource = game.ServerStorage.FutureUpdateContent.Eggs:FindFirstChild("Golden Pirate")
        end
        -- Mutated egg: use its own mutated model (with aura), not the plain template.
        if mutation then
            cleanSource = nil
        end
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
        local inside = chamberPivot * CFrame.new(0, 3.5, -1.5)
        visual:PivotTo(inside)
        visual:SetAttribute("ChamberHome", inside)
        -- Start invisible and fade in after the teleport pulse.
        local targetTransparency = {}
        for _, part in visual:GetDescendants() do
            if part:IsA("BasePart") then
                targetTransparency[part] = part.Transparency
                part.Transparency = 1
            end
        end
        visual.Parent = chamber

        ---------------------------------------------------------------- countdown billboard
        local chamberBox, chamberSize = chamber:GetBoundingBox()
        timerAnchor = Instance.new("Attachment")
        timerAnchor.Name = "IncubationTimerAnchor"
        timerAnchor.Parent = liquidSystem.TimerAnchor
        timerAnchor.WorldPosition = chamberBox.Position + Vector3.new(0, chamberSize.Y / 2 + 1, 0)
        eggTimer = Instance.new("BillboardGui")
        eggTimer.Name = "IncubationCountdown"
        eggTimer.Adornee = timerAnchor
        eggTimer.Size = UDim2.fromScale(4, 0.65)
        eggTimer.StudsOffsetWorldSpace = Vector3.zero
        eggTimer.MaxDistance = 65
        eggTimer.AlwaysOnTop = true
        eggTimer.Parent = chamber
        local timerText = Instance.new("TextLabel")
        timerText.Size = UDim2.fromScale(1, 1)
        timerText.BackgroundColor3 = Color3.fromRGB(29, 38, 57)
        timerText.BackgroundTransparency = 0.15
        timerText.TextColor3 = Color3.fromRGB(213, 236, 255)
        timerText.Font = Enum.Font.GothamBold
        timerText.TextScaled = true
        timerText.Text = EggHatchTiming.Format(hatchSeconds)
        timerText.Parent = eggTimer
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.3, 0)
        corner.Parent = timerText

        ---------------------------------------------------------------- insert
        -- HatchFX owns this chamber egg presentation.
        say("Loading", "INSERTING EGG")
        glassController:Open(0.45)
        pressButton()
        chamber:SetAttribute("TeleportPulse", workspace:GetServerTimeNow())
        task.wait(0.22)
        for part, alpha in targetTransparency do
            if part.Parent then
                tween(part, 0.35, { Transparency = alpha })
            end
        end
        task.wait(0.45)
        glassController:Close(0.45)

        ---------------------------------------------------------------- incubate
        local incubationStart = workspace:GetServerTimeNow()
        chamber:SetAttribute("Hatching", true)
        chamber:SetAttribute("HatchStart", incubationStart)
        chamber:SetAttribute("HatchDuration", hatchSeconds)
        chamber:SetAttribute("CycleEnd", incubationStart + hatchSeconds)
        say("Incubating", "INCUBATING")
        -- `workLeft` is in unboosted seconds; the night / player multipliers can change at any
        -- tick, so progress is integrated per step instead of computed from the start time.
        local workLeft = resumeLeft and math.clamp(resumeLeft, 0, hatchSeconds) or hatchSeconds
        local previousTime = workspace:GetServerTimeNow()
        while workLeft > 0 do
            if not ownsChamber(player) or not chamber:IsDescendantOf(workspace) then
                return
            end
            local now = workspace:GetServerTimeNow()
            local speed = (workspace:GetAttribute("NightHatchSpeedMultiplier") or 1)
                * (player and player:GetAttribute("HatchMultiplier") or 1)
            workLeft = math.max(0, workLeft - (now - previousTime) * speed)
            previousTime = now
            -- The countdown shows unboosted seconds, so a boost makes it tick faster instead of
            -- cutting the shown time down at once. CycleEnd / HatchDuration stay unboosted too
            -- (PlayerDataService saves CycleEnd - now as the resume workLeft).
            local remaining = math.ceil(workLeft)
            timerText.Text = EggHatchTiming.Format(remaining)
                .. (speed > 1 and string.format("  •  %g×", speed) or "")
            chamber:SetAttribute("CycleEnd", now + workLeft)
            chamber:SetAttribute("HatchDuration", hatchSeconds)
            statusLabel.Text = string.format("INCUBATING • %02d:%02d", math.floor(remaining / 60), remaining % 60)
            local progress = 1 - workLeft / hatchSeconds
            tankLiquid.Size = liquidFullSize:Lerp(Vector3.new(0.5, liquidFullSize.Y, liquidFullSize.Z), progress)
            tankLiquid.CFrame =
                liquidFullCFrame:Lerp(liquidFullCFrame - Vector3.new(0, (liquidFullSize.X - 0.5) / 2, 0), progress)
            task.wait(0.1)
        end
        chamber:SetAttribute("Hatching", false)
        chamber:SetAttribute("CycleEnd", nil)
        timerText.Text = "READY TO HATCH"

        ---------------------------------------------------------------- wait for the hatch press
        say("Loaded", "READY • PRESS HATCH")
        prompt.ActionText = "Hatch"
        prompt.ObjectText = rewardId .. " Egg"
        prompt.Enabled = player ~= nil and not chamber:GetAttribute("StealLock") -- EggSteal
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
        -- A player can only watch one opening at a time: while another chamber of theirs is
        -- playing HatchFX, drop the press and wait for a fresh one afterwards.
        local HatchFX = require(game.ServerScriptService.HatchFX.HatchFXServer)
        while player and HatchFX.IsPlayerBusy(player) do
            startRequested = false
            prompt.Enabled = true
            if not ownsChamber(player) or not chamber:IsDescendantOf(workspace) then
                return
            end
            task.wait(0.1)
        end
        if player and not startRequested then
            say("Loaded", "READY • PRESS HATCH")
            prompt.Enabled = true
            while not startRequested do
                if not ownsChamber(player) or not chamber:IsDescendantOf(workspace) then
                    return
                end
                task.wait(0.08)
            end
        end
        prompt.Enabled = false
        eggTimer.Enabled = false

        ---------------------------------------------------------------- camera gate
        local Config = require(game.ReplicatedStorage.HatchFX.HatchFXConfig)
        local Catalog = require(game.ReplicatedStorage.CharacterCatalog)
        -- rewardStats was rolled once when the egg was created or inserted.
        local earlyTimeline = Config.Timeline(rewardStats.RollQuality, Catalog.ById[rewardId].Rarity)
        if player then
            focusSent = true
            -- the cinematic camera is a nice extra: if the client never answers (slow device, UI error) the hatch still happens
            if
                not require(game.ServerScriptService.HatchCameraGate).Focus(
                    player,
                    chamber,
                    inside,
                    earlyTimeline.Break
                )
            then
                warn("[Hatch] camera not ready for " .. player.Name .. " - hatching without the cinematic")
            end
        end
        say("HatchReveal", "OPENING...")
        task.spawn(function()
            glassController:Open(0.65)
        end)

        ---------------------------------------------------------------- reward character
        local character = (mutation and Mutations.Model(rewardId, mutation, rewardTemplate)) or rewardTemplate:Clone()
        character.Name = "HatchedCharacter"
        if mutation then
            character:SetAttribute("Mutation", mutation)
        end
        for _, part in character:GetDescendants() do
            if part:IsA("BasePart") then
                part.Anchored = true
                part.CanCollide = false
                part.CanTouch = false
                part.CanQuery = false
            end
        end
        -- Normalise every character to 6 studs tall on the egg platform.
        local _, charSize = character:GetBoundingBox()
        character:ScaleTo(character:GetScale() * 6 / math.max(charSize.Y, 0.01))
        local charBox, finalSize = character:GetBoundingBox()
        local _bottom = charBox.Y - finalSize.Y * 0.5
        local home = chamberPivot * CFrame.new(0, 2.25, -5.5)
        character:PivotTo(home * CFrame.new(0, finalSize.Y * 0.5, 0) * charBox:ToObjectSpace(character:GetPivot()))
        character:SetAttribute("RewardHome", character:GetPivot())
        character:SetAttribute("RevealEpoch", workspace:GetServerTimeNow())
        character:SetAttribute("CharacterId", rewardId)
        character:SetAttribute("ChamberReveal", true)
        Economy.Apply(character, rewardId, rewardStats)
        if mutation then
            pcall(Mutations.AddAura, character, mutation)
        end

        local oldEgg = visual
        local timeline = Config.Timeline(character:GetAttribute("RollQuality"), Catalog.ById[rewardId].Rarity)

        ---------------------------------------------------------------- HatchFX reveal
        if player then
            cinematicCue:FireClient(player, "HatchStarted", chamber)
        end
        say("HatchReveal", "HATCHING...")
        local finished = false
        -- The glass is driven by glassController above, so HatchFX gets no-op glass hooks.
        local played, reason = HatchFX.Play({
            incubator = chamber,
            owner = player,
            egg = oldEgg,
            character = character,
            characterParent = chamber,
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
            if not ownsChamber(player) or not chamber:IsDescendantOf(workspace) then
                HatchFX.Cancel(chamber)
                return
            end
            if not revealed and workspace:GetServerTimeNow() - epoch >= timeline.Break then
                revealed = true
                if player then
                    cinematicCue:FireClient(
                        player,
                        "Reveal",
                        chamber,
                        home * CFrame.new(0, finalSize.Y * 0.5, 0),
                        rewardId
                    )
                end
            end
            task.wait(0.05)
        end
        character:SetAttribute("RewardHome", character:GetPivot())
        character:SetAttribute("RevealEpoch", workspace:GetServerTimeNow())
        Economy.Label(character, rewardId, rewardStats)
        chamber:SetAttribute("RewardId", rewardId)
        CollectionService:AddTag(character, "HatchRewardDisplay")
        cycleCompleted:Fire(player, tool, rewardId)
        if player then
            cinematicCue:FireClient(player, "End", chamber)
            focusSent = false
        end

        ---------------------------------------------------------------- pickup
        chamber:SetAttribute("Venting", true)
        glassController:Open(0.45)
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
        pickupAnchor.Position = chamberPivot:PointToWorldSpace(Vector3.new(0, 3.5, -1.5))
        pickupAnchor.Parent = chamber
        local pickup = Instance.new("ProximityPrompt")
        pickup.Name = "PickUpCharacter"
        pickup.ActionText = "Collect character"
        pickup.ObjectText = rewardId .. " • Power " .. Economy.Format(rewardStats.Power)
        pickup.RequiresLineOfSight = false
        pickup.MaxActivationDistance = 12
        pickup.HoldDuration = 0.2
        pickup.Parent = pickupAnchor
        local collected = false
        -- Fired by the pickup prompt or the RequestPickup bindable (HatchVideoService).
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
            local rewardTool = Rewards.Tool(rewardTemplate, rewardId, rewardStats, mutation or nil)
            rewardTool.Parent = backpack
            local humanoid = who.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:EquipTool(rewardTool)
            end
            collected = true
            pickup.Enabled = false
            -- The egg is consumed only once the reward exists; until then it can be returned.
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

    ---------------------------------------------------------------- cleanup (always runs, also after errors)
    if focusSent and player and player.Parent == Players then
        cinematicCue:FireClient(player, "End", chamber)
    end
    chamber:SetAttribute("Hatching", false)
    chamber:SetAttribute("Venting", false)
    chamber:SetAttribute("CycleEnd", nil)
    chamber:SetAttribute("RewardId", nil)
    chamber:SetAttribute("CrackStage", nil)
    require(game.ServerScriptService.HatchFX.HatchFXServer).Cancel(chamber)
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
    -- Egg not collected (cancelled / error / owner left): give the tool back.
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
    if chamber.Parent then
        glassController:Close(0.45)
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

-- ResumeEgg(player, tool, secondsLeft) -> boolean: restarts a saved incubation (PlayerDataService)
-- and HatchVideoService's instant hatches. Returns false if the chamber is busy or being rebuilt.
do
    local resumeEgg = chamber:FindFirstChild("ResumeEgg") or Instance.new("BindableFunction")
    resumeEgg.Name = "ResumeEgg"
    resumeEgg.Parent = chamber
    resumeEgg.OnInvoke = function(player, tool, secondsLeft)
        if busy or chamber:GetAttribute("UnderConstruction") then
            return false
        end
        task.spawn(runCycle, player, tool, secondsLeft)
        return true
    end
end
