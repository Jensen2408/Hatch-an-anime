--[[ StarterPlayerScripts.StolenEggCarryPose  (LocalScript)
Client-side two-hand carry pose for EVERY character in the server (not only the local player).
While a character has a "RiverEggCarry" / "HeldItemCarry" / "StolenEggCarry" model containing a "Carrier" part,
each frame (PreSimulation) the R15 shoulder / elbow / wrist Motor6D.Transform is set so both hands reach the
sides of the carried object (GripHalfWidth attribute on the carry model, default 0.75).
When the carry ends, the transforms are reset to identity once. No remotes; reads only replicated instances.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local watchedCharacters = {} -- [character Model] = { arms = { {side, shoulder, elbow, wrist} }, active, lastScan }
local function findJoint(part, name)
    return part and part:FindFirstChild(name, true)
end
-- (Re)collects the arm joints of a character; keeps the previous `active` flag so a pose reset is not lost.
local function scanCharacter(character)
    local arms = {}
    for _, side in { "Left", "Right" } do
        local _upperArm = character:FindFirstChild(side .. "UpperArm")
        local _lowerArm = character:FindFirstChild(side .. "LowerArm")
        local _hand = character:FindFirstChild(side .. "Hand")
        local shoulder = findJoint(character, side .. "Shoulder")
        local elbow = findJoint(character, side .. "Elbow")
        local wrist = findJoint(character, side .. "Wrist")
        if shoulder and elbow and wrist then
            table.insert(arms, { side = side, shoulder = shoulder, elbow = elbow, wrist = wrist })
        end
    end
    local previous = watchedCharacters[character]
    watchedCharacters[character] =
        { arms = arms, active = previous and previous.active or false, lastScan = os.clock() }
end
local function setupPlayer(otherPlayer)
    otherPlayer.CharacterAdded:Connect(function(character)
        task.delay(0.5, function() -- give the rig time to load its joints
            if character.Parent then
                scanCharacter(character)
            end
        end)
    end)
    if otherPlayer.Character then
        scanCharacter(otherPlayer.Character)
    end
    otherPlayer.CharacterRemoving:Connect(function(character)
        watchedCharacters[character] = nil
    end)
end
for _, otherPlayer in Players:GetPlayers() do
    setupPlayer(otherPlayer)
end
Players.PlayerAdded:Connect(setupPlayer)

-- Shortest rotation taking unit vector fromDir onto unit vector toDir.
local function rotateVector(fromDir, toDir)
    local dot = math.clamp(fromDir:Dot(toDir), -1, 1)
    if dot > 0.99999 then
        return CFrame.identity
    end
    if dot < -0.99999 then
        -- opposite vectors: any axis perpendicular to fromDir works
        local ortho = math.abs(fromDir.X) < 0.8 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
        local axis = fromDir:Cross(ortho).Unit
        return CFrame.fromAxisAngle(axis, math.pi)
    end
    local axis = fromDir:Cross(toDir).Unit
    return CFrame.fromAxisAngle(axis, math.acos(dot))
end

local scanElapsed = 0
RunService.PreSimulation:Connect(function(dt)
    -- every 0.5 s pick up characters that were missed (streaming, early CharacterAdded)
    scanElapsed += dt
    if scanElapsed >= 0.5 then
        scanElapsed = 0
        for _, otherPlayer in Players:GetPlayers() do
            local character = otherPlayer.Character
            if character and character.Parent and not watchedCharacters[character] then
                scanCharacter(character)
            end
        end
    end
    for character, record in watchedCharacters do
        if not character.Parent then
            watchedCharacters[character] = nil
        else
            -- rig not complete yet: rescan at most every 0.5 s
            if #record.arms < 2 and os.clock() - record.lastScan > 0.5 then
                scanCharacter(character)
                record = watchedCharacters[character]
            end
            local carry = character:FindFirstChild("RiverEggCarry")
                or character:FindFirstChild("HeldItemCarry")
                or character:FindFirstChild("StolenEggCarry")
            local carrier = carry and carry:FindFirstChild("Carrier")
            if carrier then
                local gripHalfWidth = carry:GetAttribute("GripHalfWidth") or 0.75
                local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")
                local torsoUp = torso and torso.CFrame.UpVector or Vector3.new(0, 1, 0)
                for _, arm in record.arms do
                    local shoulder, elbow, wrist = arm.shoulder, arm.elbow, arm.wrist
                    if shoulder.Parent and elbow.Parent and wrist.Parent and shoulder.Part0 then
                        local isLeft = arm.side == "Left"
                        local sign = isLeft and -1 or 1
                        local shoulderWorld = shoulder.Part0.CFrame * shoulder.C0
                        -- grip point: just outside the carrier's side, slightly low and in front
                        local target =
                            carrier.CFrame:PointToWorldSpace(Vector3.new(sign * (gripHalfWidth + 0.03), -0.1, 0.12))
                        local delta = target - shoulderWorld.Position
                        local dir = delta.Magnitude > 0.001 and delta.Unit or carrier.CFrame.LookVector

                        -- 1. Shoulder: pure rotation (never dislocates)
                        local upperBoneDir = (elbow.C0.Position - shoulder.C1.Position).Unit
                        local desiredDir = shoulderWorld:VectorToObjectSpace(dir)
                        shoulder.Transform = rotateVector(upperBoneDir, desiredDir)

                        -- 2. Elbow: pure rotation
                        local upperCFrame = shoulder.Part0.CFrame
                            * shoulder.C0
                            * shoulder.Transform
                            * shoulder.C1:Inverse()
                        local elbowWorld = upperCFrame * elbow.C0
                        local lowerBoneDir = (wrist.C0.Position - elbow.C1.Position).Unit
                        local desiredElbowDir = elbowWorld:VectorToObjectSpace(dir)
                        elbow.Transform = rotateVector(lowerBoneDir, desiredElbowDir)

                        -- 3. Wrist: pure rotation, hands face forward from front of arm and cup inward
                        local lowerCFrame = upperCFrame * elbow.C0 * elbow.Transform * elbow.C1:Inverse()
                        local wristWorld = lowerCFrame * wrist.C0
                        local desiredHandRot = CFrame.lookAt(Vector3.zero, dir, torsoUp)
                            * CFrame.Angles(math.pi / 2, 0, 0)
                        desiredHandRot = desiredHandRot * CFrame.Angles(0, 0, math.rad(isLeft and 12 or -12))
                        wrist.Transform = CFrame.fromMatrix(
                            Vector3.zero,
                            wristWorld:VectorToObjectSpace(desiredHandRot.RightVector),
                            wristWorld:VectorToObjectSpace(desiredHandRot.UpVector),
                            wristWorld:VectorToObjectSpace(-desiredHandRot.LookVector)
                        )
                    end
                end
            elseif record.active then
                -- carry just ended: hand the joints back to the Animator
                for _, arm in record.arms do
                    for _, joint in { arm.shoulder, arm.elbow, arm.wrist } do
                        if joint.Parent then
                            joint.Transform = CFrame.identity
                        end
                    end
                end
            end
            record.active = carrier ~= nil
        end
    end
end)
