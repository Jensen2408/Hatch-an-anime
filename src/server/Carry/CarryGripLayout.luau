--[[ ServerScriptService.CarryGripLayout  (ModuleScript, SERVER)
Computes where a two-hand carried item sits in front of the torso, so both straight arms can reach it.
Used by TwoHandItemCarryService.Attach (the returned CFrame becomes the "Carrier" part's CFrame).

Layout.Frame(character, torso, halfWidth) -> CFrame (world space)
  halfWidth = half the item's width; the hands grip just outside it.
Three strategies for the forward distance, tried in order:
  1. R15 Motor6Ds (Shoulder/Elbow/Wrist joints)   2. R15 rig attachments   3. R6 "Left Arm" size / fixed fallback.
]]
local Layout = {}

function Layout.Frame(character, torso, halfWidth)
    -- Height: just below shoulder height, averaged over both arms, where straight arms can support it.
    local heightSum, heightCount = 0, 0
    for _, side in { "Left", "Right" } do
        local shoulder = character:FindFirstChild(side .. "Shoulder", true)
        local wrist = character:FindFirstChild(side .. "Wrist", true)
        local anchor = torso:FindFirstChild(side .. "ShoulderRigAttachment")
        if shoulder and shoulder.Part0 and wrist then
            local shoulderPos = torso.CFrame:PointToObjectSpace((shoulder.Part0.CFrame * shoulder.C0).Position)
            heightSum += shoulderPos.Y - 0.35 + 0.1 - wrist.C1.Position.Y
            heightCount += 1
        elseif anchor then
            heightSum += anchor.Position.Y - 0.5
            heightCount += 1
        end
    end
    local gripY = heightCount > 0 and heightSum / heightCount or 0.5

    -- Forward distance: the closest point either arm can still reach at full extension (sphere of radius
    -- upper+lower arm length around the shoulder). The smaller of the two arms wins.
    local forward = math.huge
    for _, side in { "Left", "Right" } do
        local shoulder = character:FindFirstChild(side .. "Shoulder", true)
        local elbow = character:FindFirstChild(side .. "Elbow", true)
        local wrist = character:FindFirstChild(side .. "Wrist", true)
        if shoulder and elbow and wrist and shoulder.Part0 then
            local upperLength = (shoulder.C1.Position - elbow.C0.Position).Magnitude
            local lowerLength = (elbow.C1.Position - wrist.C0.Position).Magnitude
            local shoulderPos = torso.CFrame:PointToObjectSpace((shoulder.Part0.CFrame * shoulder.C0).Position)
            local handX = (side == "Left" and -halfWidth - 0.03 or halfWidth + 0.03) + wrist.C1.Position.X
            local handY = gripY - 0.1 + wrist.C1.Position.Y
            local reach = (upperLength + lowerLength)
            local handZ =
                math.sqrt(math.max(0.25, reach * reach - (handX - shoulderPos.X) ^ 2 - (handY - shoulderPos.Y) ^ 2))
            forward = math.min(forward, handZ - shoulderPos.Z + 0.12 + wrist.C1.Position.Z)
        end
    end
    -- Fallback 2: no Motor6Ds found, use the R15 rig attachments.
    if forward == math.huge then
        for _, side in { "Left", "Right" } do
            local upperArm = character:FindFirstChild(side .. "UpperArm")
            local lowerArm = character:FindFirstChild(side .. "LowerArm")
            local hand = character:FindFirstChild(side .. "Hand")
            local upperShoulderAtt = upperArm and upperArm:FindFirstChild(side .. "ShoulderRigAttachment")
            local upperElbowAtt = upperArm and upperArm:FindFirstChild(side .. "ElbowRigAttachment")
            local lowerElbowAtt = lowerArm and lowerArm:FindFirstChild(side .. "ElbowRigAttachment")
            local lowerWristAtt = lowerArm and lowerArm:FindFirstChild(side .. "WristRigAttachment")
            local handWristAtt = hand and hand:FindFirstChild(side .. "WristRigAttachment")
            local anchor = torso:FindFirstChild(side .. "ShoulderRigAttachment")
            if upperShoulderAtt and upperElbowAtt and lowerElbowAtt and lowerWristAtt and handWristAtt and anchor then
                local reach = (
                    (upperShoulderAtt.Position - upperElbowAtt.Position).Magnitude
                    + (lowerElbowAtt.Position - lowerWristAtt.Position).Magnitude
                )
                local shoulderPos = anchor.Position
                local handX = (side == "Left" and -halfWidth - 0.03 or halfWidth + 0.03) + handWristAtt.Position.X
                local handY = gripY - 0.1 + handWristAtt.Position.Y
                forward = math.min(
                    forward,
                    math.sqrt(math.max(0.25, reach * reach - (handX - shoulderPos.X) ^ 2 - (handY - shoulderPos.Y) ^ 2))
                        - shoulderPos.Z
                        + 0.12
                        + handWristAtt.Position.Z
                )
            end
        end
    end
    -- Fallback 3: R6 (or unknown rig) - estimate from the arm length.
    if forward == math.huge then
        local arm = character:FindFirstChild("Left Arm")
        forward = arm and math.max(1.1, arm.Size.Y * 0.82) or 1.65
    end
    return torso.CFrame * CFrame.new(0, gripY, -math.clamp(forward, 0.8, 6))
end

return Layout
