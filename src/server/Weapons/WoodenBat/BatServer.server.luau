--[[
	BatServer
	Heavy-knockback baseball bat with reliable cone hit-detection,
	satisfying sound effects, impact sparks, and ragdoll fling.

	Lives in ServerStorage.Weapons.WoodenBat (template); WeaponGiver clones the Tool into each Backpack and the
	Script runs from there. BatMotionClient plays the swing animation on the client.

	Network authority: Tool.Activated is triggered by the client, but everything else is decided here: the
	cooldown, the HIT_WINDOW, the overlap + cone hit test, knockback and egg drops. During a knockdown the server
	takes network ownership of the target's root for RAGDOLL_TIME and then hands it back.
	Egg drops: a victim carrying a river egg -> RiverEggCarryService.Drop(victim); otherwise a held egg Tool
	(EggType without CharacterId) -> TwoHandItemCarryService.DropTool(victim, tool). Both are lazily required.
	Replicated attributes: Tool SwingTick / LastHitTime (server time), attacker Player BatEggKnocks (counter).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local _Debris = game:GetService("Debris")

local tool = script.Parent
local handle = tool:WaitForChild("Handle")

-- ===== SETTINGS =====
local SWING_COOLDOWN = 1.1 -- seconds between swings
local HIT_WINDOW = 0.50 -- seconds the bat can hit after click
local KNOCKBACK_FORCE = 50 -- horizontal fling strength (multiplied by AssemblyMass)
local UPWARD_FORCE = 20 -- upward lift (multiplied by AssemblyMass)
local RAGDOLL_TIME = 3 -- seconds the target stays down
local DAMAGE = 0 -- knockback only; raise above 0 to deal damage
local HIT_RANGE = 6.5 -- forward reach in studs
local HIT_ARC_COS = 0.25 -- ~150-degree forward sweep arc (dot product threshold)
-- ====================

local canSwing = true
local swinging = false
local hitThisSwing = {} -- debounce per swing
local ragdollTokens = {} -- [targetCharacter] = token; only the latest knockdown may end the ragdoll

local function getOwner()
    local character = tool.Parent
    if not character then
        return nil
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if humanoid and root and humanoid.Health > 0 then
        return character, humanoid, root
    end
    return nil
end

local function playSwingFX()
    local whoosh = handle:FindFirstChild("SwingWhoosh")
    if whoosh and not whoosh.IsPlaying then
        whoosh.SoundId = "rbxassetid://9113305311"
        whoosh.PlaybackSpeed = 1.0 + (math.random() - 0.5) * 0.10
        whoosh.Volume = 0.75
        whoosh:Play()
    end
    local trail = handle:FindFirstChild("SwingTrail")
    if trail then
        trail.Enabled = true
        task.delay(0.28, function()
            if trail and trail.Parent then
                trail.Enabled = false
            end
        end)
    end
end

local function playHitFX(_hitPosition)
    local thud = handle:FindFirstChild("HitThud")
    if thud then
        thud:Play()
    end
    local crack = handle:FindFirstChild("HitCrack")
    if crack then
        crack:Play()
    end

    local trailTop = handle:FindFirstChild("TrailTop")
    local sparks = trailTop and trailTop:FindFirstChild("HitSparks")
    if sparks then
        sparks:Emit(15)
    end
end

local function knockDown(targetCharacter, targetHumanoid, targetRoot, attackerRoot)
    -- 1) Fall over immediately
    targetHumanoid.PlatformStand = true

    -- 2) Server takes physics ownership for reliable impulse
    local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
    pcall(function()
        targetRoot:SetNetworkOwner(nil)
    end)

    -- 3) Heavy knockback: away from attacker, slightly upward, scaled by mass
    local offset = targetRoot.Position - attackerRoot.Position
    local flat = Vector3.new(offset.X, 0, offset.Z)
    local direction = flat.Magnitude > 0.01 and flat.Unit or attackerRoot.CFrame.LookVector

    local mass = targetRoot.AssemblyMass
    local impulse = (direction * KNOCKBACK_FORCE + Vector3.new(0, UPWARD_FORCE, 0)) * mass
    targetRoot:ApplyImpulse(impulse)

    -- Chaotic spin
    targetRoot:ApplyAngularImpulse(
        Vector3.new((math.random() - 0.5) * 2, (math.random() - 0.5) * 0.5, (math.random() - 0.5) * 2) * mass * 10
    )

    -- 4) Recovery after RAGDOLL_TIME
    local token = {}
    ragdollTokens[targetCharacter] = token

    task.delay(RAGDOLL_TIME, function()
        if ragdollTokens[targetCharacter] ~= token then
            return
        end
        ragdollTokens[targetCharacter] = nil

        if targetHumanoid.Parent and targetHumanoid.Health > 0 then
            targetHumanoid.PlatformStand = false
            targetHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end

        if targetPlayer and targetRoot.Parent then
            pcall(function()
                targetRoot:SetNetworkOwner(targetPlayer)
            end)
        end
    end)
end

local function tryHit(targetCharacter, attackerCharacter, attackerRoot)
    if not targetCharacter or targetCharacter == attackerCharacter then
        return
    end
    if hitThisSwing[targetCharacter] then
        return
    end

    local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
    local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
    if not targetHumanoid or not targetRoot or targetHumanoid.Health <= 0 then
        return
    end

    hitThisSwing[targetCharacter] = true
    tool:SetAttribute("LastHitTime", workspace:GetServerTimeNow())

    playHitFX(targetRoot.Position)

    -- Bat hit makes a player carrying a river egg drop it; anyone can then pick it up and run it home.
    local victim = Players:GetPlayerFromCharacter(targetCharacter)
    -- also knocks out an egg that's simply held in hand (not only one being carried home from the river)
    local heldEgg = targetCharacter:FindFirstChildOfClass("Tool")
    if heldEgg and not (heldEgg:GetAttribute("EggType") and not heldEgg:GetAttribute("CharacterId")) then
        heldEgg = nil
    end
    if victim and (victim:GetAttribute("RiverEggCarryId") or heldEgg) then
        local ok, dropped = pcall(function()
            if victim:GetAttribute("RiverEggCarryId") then
                return require(game:GetService("ServerScriptService").RiverEggCarryService).Drop(victim)
            end
            return require(game:GetService("ServerScriptService").TwoHandItemCarryService).DropTool(victim, heldEgg)
        end)
        if ok and dropped then
            local attacker = Players:GetPlayerFromCharacter(attackerCharacter)
            if attacker then
                attacker:SetAttribute("BatEggKnocks", (attacker:GetAttribute("BatEggKnocks") or 0) + 1)
            end
        end
    end

    if DAMAGE > 0 then
        targetHumanoid:TakeDamage(DAMAGE)
    end
    knockDown(targetCharacter, targetHumanoid, targetRoot, attackerRoot)
end

tool.Activated:Connect(function()
    if not canSwing then
        return
    end
    local attackerCharacter, _, attackerRoot = getOwner()
    if not attackerCharacter then
        return
    end

    canSwing = false
    swinging = true
    table.clear(hitThisSwing)

    -- Replicate swing timestamp to all clients
    tool:SetAttribute("SwingTick", workspace:GetServerTimeNow())
    playSwingFX()

    -- Robust hit detection: handle overlap + forward sweep cone
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = { attackerCharacter }

    local connection
    connection = RunService.Heartbeat:Connect(function()
        if not swinging then
            connection:Disconnect()
            return
        end

        -- Check 1: direct handle intersection
        for _, part in ipairs(workspace:GetPartsInPart(handle, overlapParams)) do
            local character = part:FindFirstAncestorOfClass("Model")
            if character then
                tryHit(character, attackerCharacter, attackerRoot)
            end
        end

        -- Check 2: forward swing cone sweep
        local look = attackerRoot.CFrame.LookVector
        local forwardCenter = attackerRoot.Position + look * (HIT_RANGE * 0.5)
        local boxSize = Vector3.new(HIT_RANGE * 1.1, 4.5, HIT_RANGE)
        local forwardBox = CFrame.new(forwardCenter, forwardCenter + look)

        for _, part in ipairs(workspace:GetPartBoundsInBox(forwardBox, boxSize, overlapParams)) do
            local character = part:FindFirstAncestorOfClass("Model")
            if character and not hitThisSwing[character] then
                local targetRoot = character:FindFirstChild("HumanoidRootPart")
                if targetRoot then
                    local toTarget = targetRoot.Position - attackerRoot.Position
                    local distance = toTarget.Magnitude
                    if distance <= HIT_RANGE then
                        local flatDir = Vector3.new(toTarget.X, 0, toTarget.Z).Unit
                        local dot = flatDir:Dot(Vector3.new(look.X, 0, look.Z).Unit)
                        if dot >= HIT_ARC_COS then
                            tryHit(character, attackerCharacter, attackerRoot)
                        end
                    end
                end
            end
        end
    end)

    task.delay(HIT_WINDOW, function()
        swinging = false
    end)

    task.delay(SWING_COOLDOWN, function()
        canSwing = true
    end)
end)

tool.Unequipped:Connect(function()
    swinging = false
end)
