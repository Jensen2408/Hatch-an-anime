local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local watched = {}
local function joint(part, name)
    return part and part:FindFirstChild(name, true)
end
local function watch(c)
    local arms = {}
    for _, side in { "Left", "Right" } do
        local upper = c:FindFirstChild(side .. "UpperArm")
        local lower = c:FindFirstChild(side .. "LowerArm")
        local hand = c:FindFirstChild(side .. "Hand")
        local shoulder = joint(c, side .. "Shoulder")
        local elbow = joint(c, side .. "Elbow")
        local wrist = joint(c, side .. "Wrist")
        if shoulder and elbow and wrist then
            table.insert(arms, { side = side, shoulder = shoulder, elbow = elbow, wrist = wrist })
        end
    end
    local previous = watched[c]
    watched[c] = { arms = arms, active = previous and previous.active or false, lastScan = os.clock() }
end
local function setup(p)
    p.CharacterAdded:Connect(function(c)
        task.delay(0.5, function()
            if c.Parent then
                watch(c)
            end
        end)
    end)
    if p.Character then
        watch(p.Character)
    end
    p.CharacterRemoving:Connect(function(c)
        watched[c] = nil
    end)
end
for _, p in Players:GetPlayers() do
    setup(p)
end
Players.PlayerAdded:Connect(setup)

local function rotateVector(vFrom, vTo)
    local dot = math.clamp(vFrom:Dot(vTo), -1, 1)
    if dot > 0.99999 then
        return CFrame.identity
    end
    if dot < -0.99999 then
        local ortho = math.abs(vFrom.X) < 0.8 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
        local axis = vFrom:Cross(ortho).Unit
        return CFrame.fromAxisAngle(axis, math.pi)
    end
    local axis = vFrom:Cross(vTo).Unit
    return CFrame.fromAxisAngle(axis, math.acos(dot))
end

local scanElapsed = 0
RunService.PreSimulation:Connect(function(dt)
    scanElapsed += dt
    if scanElapsed >= 0.5 then
        scanElapsed = 0
        for _, p in Players:GetPlayers() do
            local c = p.Character
            if c and c.Parent and not watched[c] then
                watch(c)
            end
        end
    end
    for c, rec in watched do
        if not c.Parent then
            watched[c] = nil
        else
            if #rec.arms < 2 and os.clock() - rec.lastScan > 0.5 then
                watch(c)
                rec = watched[c]
            end
            local carry = c:FindFirstChild("RiverEggCarry")
                or c:FindFirstChild("HeldItemCarry")
                or c:FindFirstChild("StolenEggCarry")
            local carrier = carry and carry:FindFirstChild("Carrier")
            if carrier then
                local half = carry:GetAttribute("GripHalfWidth") or 0.75
                local torso = c:FindFirstChild("UpperTorso") or c:FindFirstChild("HumanoidRootPart")
                local torsoUp = torso and torso.CFrame.UpVector or Vector3.new(0, 1, 0)
                for _, a in rec.arms do
                    local shoulder, elbow, wrist = a.shoulder, a.elbow, a.wrist
                    if shoulder.Parent and elbow.Parent and wrist.Parent and shoulder.Part0 then
                        local isLeft = a.side == "Left"
                        local sign = isLeft and -1 or 1
                        local sWorld = shoulder.Part0.CFrame * shoulder.C0
                        local target = carrier.CFrame:PointToWorldSpace(Vector3.new(sign * (half + 0.03), -0.1, 0.12))
                        local delta = target - sWorld.Position
                        local dir = delta.Magnitude > 0.001 and delta.Unit or carrier.CFrame.LookVector

                        -- 1. Shoulder: pure rotation (never dislocates)
                        local uBone = (elbow.C0.Position - shoulder.C1.Position).Unit
                        local desiredDir = sWorld:VectorToObjectSpace(dir)
                        shoulder.Transform = rotateVector(uBone, desiredDir)

                        -- 2. Elbow: pure rotation
                        local upperCFrame = shoulder.Part0.CFrame
                            * shoulder.C0
                            * shoulder.Transform
                            * shoulder.C1:Inverse()
                        local eWorld = upperCFrame * elbow.C0
                        local lBone = (wrist.C0.Position - elbow.C1.Position).Unit
                        local desiredElbowDir = eWorld:VectorToObjectSpace(dir)
                        elbow.Transform = rotateVector(lBone, desiredElbowDir)

                        -- 3. Wrist: pure rotation, hands face forward from front of arm and cup inward
                        local lowerCFrame = upperCFrame * elbow.C0 * elbow.Transform * elbow.C1:Inverse()
                        local wWorld = lowerCFrame * wrist.C0
                        local desiredHandRot = CFrame.lookAt(Vector3.zero, dir, torsoUp)
                            * CFrame.Angles(math.pi / 2, 0, 0)
                        desiredHandRot = desiredHandRot * CFrame.Angles(0, 0, math.rad(isLeft and 12 or -12))
                        wrist.Transform = CFrame.fromMatrix(
                            Vector3.zero,
                            wWorld:VectorToObjectSpace(desiredHandRot.RightVector),
                            wWorld:VectorToObjectSpace(desiredHandRot.UpVector),
                            wWorld:VectorToObjectSpace(-desiredHandRot.LookVector)
                        )
                    end
                end
            elseif rec.active then
                for _, a in rec.arms do
                    for _, j in { a.shoulder, a.elbow, a.wrist } do
                        if j.Parent then
                            j.Transform = CFrame.identity
                        end
                    end
                end
            end
            rec.active = carrier ~= nil
        end
    end
end)
