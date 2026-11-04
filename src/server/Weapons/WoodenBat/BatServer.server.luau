--[[
	BatServer
	Heavy-knockback baseball bat with reliable cone hit-detection,
	satisfying sound effects, impact sparks, and ragdoll fling.

	Lives in ServerStorage.Weapons.WoodenBat (template); WeaponGiver clones the Tool into each Backpack and the
	Script runs from there. BatMotionClient plays the swing animation on the client.

	Network authority: Tool.Activated is triggered by the client, but everything else is decided here: the
	cooldown, the HIT_WINDOW, the overlap + cone hit test, knockback and egg drops. During a knockdown the server
	takes network ownership of the target's root for RAGDOLL_TIME and then hands it back.
	Egg drops: only a victim still carrying an egg home (RiverEggCarryId set) drops it, via
	RiverEggCarryService.Drop(victim) (lazily required). A secured egg stays with its owner when they are hit.
	Replicated attributes: Tool SwingTick / LastHitTime (server time), attacker Player BatEggKnocks (counter).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local _Debris = game:GetService("Debris")

local tool = script.Parent
local handle = tool:WaitForChild("Handle")

-- ===== SETTINGS =====
local SWING_COOLDOWN = tool:GetAttribute("SwingCooldown") or 1.1 -- seconds between swings (shop tier: SwingCooldown)
local HIT_WINDOW = 0.50 -- seconds the bat can hit after click
-- bat tiers (ShopConfig.Weapons, stamped by WeaponGiver) override SWING_COOLDOWN / KNOCKBACK_FORCE / HIT_RANGE with
-- the Tool attributes SwingCooldown / Knockback / HitRange
local KNOCKBACK_FORCE = tool:GetAttribute("Knockback") or 50 -- horizontal fling strength (multiplied by AssemblyMass)
local UPWARD_FORCE = 20 -- upward lift (multiplied by AssemblyMass)
local RAGDOLL_TIME = 3 -- seconds the target stays down
local DAMAGE = 0 -- knockback only; raise above 0 to deal damage
local HIT_RANGE = tool:GetAttribute("HitRange") or 6.5 -- forward reach in studs
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

local function knockDown(targetCharacter, targetHumanoid, targetRoot, attackerRoot, attackerPlayer)
    -- 1) Fall over immediately
    targetHumanoid.PlatformStand = true

    -- 2) Server takes physics ownership for reliable impulse
    local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
    pcall(function()
        targetRoot:SetNetworkOwner(nil)
    end)

    -- 3) Heavy knockback: away from attacker, slightly upward, scaled by mass + Arena Podium buffs
    local offset = targetRoot.Position - attackerRoot.Position
    local flat = Vector3.new(offset.X, 0, offset.Z)
    local direction = flat.Magnitude > 0.01 and flat.Unit or attackerRoot.CFrame.LookVector

    local kbMult = (
        attackerPlayer
        and attackerPlayer:GetAttribute("ArenaIn")
        and tonumber(attackerPlayer:GetAttribute("ArenaKnockbackMult"))
    ) or 1
    local kbResist = (
        targetPlayer
        and targetPlayer:GetAttribute("ArenaIn")
        and math.clamp(tonumber(targetPlayer:GetAttribute("ArenaKnockbackResist")) or 0, 0, 0.55)
    ) or 0
    local recoveryMult = (
        targetPlayer
        and targetPlayer:GetAttribute("ArenaIn")
        and math.max(1, tonumber(targetPlayer:GetAttribute("ArenaRecoveryMult")) or 1)
    ) or 1

    local effectiveKnockback = KNOCKBACK_FORCE * kbMult * (1 - kbResist)
    local effectiveUpward = UPWARD_FORCE * (1 + (kbMult - 1) * 0.45) * (1 - kbResist * 0.5)
    local effectiveRagdoll = RAGDOLL_TIME / recoveryMult

    local mass = targetRoot.AssemblyMass
    local impulse = (direction * effectiveKnockback + Vector3.new(0, effectiveUpward, 0)) * mass
    targetRoot:ApplyImpulse(impulse)

    -- Chaotic spin
    targetRoot:ApplyAngularImpulse(
        Vector3.new((math.random() - 0.5) * 2, (math.random() - 0.5) * 0.5, (math.random() - 0.5) * 2) * mass * 10
    )

    -- 4) Recovery after RAGDOLL_TIME
    local token = {}
    ragdollTokens[targetCharacter] = token

    task.delay(effectiveRagdoll, function()
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
    -- Arena Brawl fighters waiting for the fight to start cannot be hit
    local protectedPlayer = Players:GetPlayerFromCharacter(targetCharacter)
    if protectedPlayer and protectedPlayer:GetAttribute("ArenaSafe") then
        return
    end

    hitThisSwing[targetCharacter] = true
    tool:SetAttribute("LastHitTime", workspace:GetServerTimeNow())

    playHitFX(targetRoot.Position)

    -- Bat hit makes a player carrying an egg home drop it; anyone can then pick it up and run it home.
    -- Once the egg is secured (carry finished) it belongs to the player and is never knocked out again.
    local victim = Players:GetPlayerFromCharacter(targetCharacter)
    -- who hit this player last (the Arena Brawl credits knockouts from it)
    local attackerPlayer = Players:GetPlayerFromCharacter(attackerCharacter)
    if victim and attackerPlayer then
        victim:SetAttribute("LastBatHitBy", attackerPlayer.UserId)
        victim:SetAttribute("LastBatHitAt", workspace:GetServerTimeNow())
    end
    if victim and victim:GetAttribute("RiverEggCarryId") then
        local ok, dropped = pcall(function()
            return require(game:GetService("ServerScriptService").RiverEggCarryService).Drop(victim)
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
    knockDown(targetCharacter, targetHumanoid, targetRoot, attackerRoot, attackerPlayer)
end

tool.Activated:Connect(function()
    if not canSwing then
        return
    end
    local attackerCharacter, _, attackerRoot = getOwner()
    if not attackerCharacter then
        return
    end
    local attackerPlayer = Players:GetPlayerFromCharacter(attackerCharacter)
    local inArena = attackerPlayer and attackerPlayer:GetAttribute("ArenaIn") == true
    local swingMult = inArena and math.max(0.5, tonumber(attackerPlayer:GetAttribute("ArenaSwingSpeedMult")) or 1) or 1
    local reachBonus = inArena and (tonumber(attackerPlayer:GetAttribute("ArenaReachBonus")) or 0) or 0
    local effectiveHitRange = HIT_RANGE + reachBonus
    local effectiveCooldown = SWING_COOLDOWN / swingMult

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

    local bossHitThisSwing = false
    local swingTick = tool:GetAttribute("SwingTick")
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if not swinging then
            connection:Disconnect()
            return
        end

        if tool.Parent ~= attackerCharacter or not attackerRoot.Parent then
            connection:Disconnect()
            return
        end
        -- The boss is rendered locally, so its server service tests the swing against shared bounds.
        if not bossHitThisSwing and workspace:GetServerTimeNow() - swingTick >= 0.12 then
            local service = game:GetService("ServerScriptService"):FindFirstChild("BossEventService")
            local hit = service and service:FindFirstChild("BatHit")
            local attacker = Players:GetPlayerFromCharacter(attackerCharacter)
            if hit and attacker then
                local ok, accepted = pcall(hit.Invoke, hit, attacker, tool, swingTick)
                if ok and accepted then
                    bossHitThisSwing = true
                    tool:SetAttribute("LastHitTime", workspace:GetServerTimeNow())
                    playHitFX(handle.Position)
                end
            end
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
        local forwardCenter = attackerRoot.Position + look * (effectiveHitRange * 0.5)
        local boxSize = Vector3.new(effectiveHitRange * 1.1, 4.5, effectiveHitRange)
        local forwardBox = CFrame.new(forwardCenter, forwardCenter + look)

        for _, part in ipairs(workspace:GetPartBoundsInBox(forwardBox, boxSize, overlapParams)) do
            local character = part:FindFirstAncestorOfClass("Model")
            if character and not hitThisSwing[character] then
                local targetRoot = character:FindFirstChild("HumanoidRootPart")
                if targetRoot then
                    local toTarget = targetRoot.Position - attackerRoot.Position
                    local distance = toTarget.Magnitude
                    if distance <= effectiveHitRange then
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

    task.delay(effectiveCooldown, function()
        canSwing = true
    end)
end)

tool.Unequipped:Connect(function()
    swinging = false
end)
