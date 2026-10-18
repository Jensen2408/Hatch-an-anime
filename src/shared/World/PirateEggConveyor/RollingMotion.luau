-- Workspace.PirateEggConveyor.RollingMotion  (ModuleScript, required by server + client)
-- Moves a river egg along the new winding WaterfallRiver (ReplicatedStorage.WaterfallRiver.RiverPath).
-- Same API as before: returns update(), pose(elapsed) -> cframe, phase ("fall"|"land"|"travel"|"exit"), cycle, duration
--
-- The motion is a pure function of server time since the egg's "Epoch" attribute, so server and clients
-- agree on where an egg is without replicating its CFrame every frame. Phases:
--   fall   slide over the waterfall lip and drop to the water
--   land   first SettleDuration seconds on the water (dip + ripple ring on clients)
--   travel float downstream; the only phase in which the egg is collectible
--   exit   sink out of sight at the end of the river
-- Conveyor attributes: Speed (studs/s, default 14), DropDuration (1.8), SettleDuration (1.45).
-- Egg attributes: Sequence (lateral offset seed), Epoch (start time), RiverEggVisual, Collectible.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local riverFolder = ReplicatedStorage:WaitForChild("WaterfallRiver")
local Config = require(riverFolder:WaitForChild("RiverConfig"))
local Path = require(riverFolder:WaitForChild("RiverPath"))
return function(conveyor, egg)
    local labelAnchor = egg:WaitForChild("LabelAnchor")
    local collectAnchor = egg:WaitForChild("CollectAnchor")
    local pivot = egg:GetPivot()
    local _, size = egg:GetBoundingBox()
    -- Lowest visible point of the egg relative to its pivot (checks all 8 corners of every part), so the
    -- egg floats with its bottom on the water regardless of where the pivot is.
    local minY = math.huge
    for _, part in egg:GetDescendants() do
        if part:IsA("BasePart") and part.Transparency < 1 and part ~= labelAnchor and part ~= collectAnchor then
            for _, cornerX in { -1, 1 } do
                for _, cornerY in { -1, 1 } do
                    for _, cornerZ in { -1, 1 } do
                        minY = math.min(
                            minY,
                            pivot:PointToObjectSpace(
                                part.CFrame:PointToWorldSpace(part.Size * Vector3.new(cornerX, cornerY, cornerZ) * 0.5)
                            ).Y
                        )
                    end
                end
            end
        end
    end
    if minY == math.huge then
        minY = -size.Y / 2
    end
    local riverOrigin = Config.Origin
    -- Golden-ratio hash of the egg's sequence number: spreads consecutive eggs across the river width.
    local seed = ((egg:GetAttribute("Sequence") or 1) * 0.618034) % 1
    local lateral = (seed - 0.5) * Config.RiverWidth * 0.25
    local speed = math.max(conveyor:GetAttribute("Speed") or 14, 1)
    local fallDuration = conveyor:GetAttribute("DropDuration") or 1.8
    local settleDuration = conveyor:GetAttribute("SettleDuration") or 1.45
    local floatY = Path.SurfaceY - 0.3 - minY
    local topY = riverOrigin.Y + Config.FallHeight - minY + 0.1
    local startX = riverOrigin.X - 9
    local landDistance = Path.LandDistance
    local landPos, _, landRight = Path.At(landDistance)
    local landPoint = landPos + landRight * lateral
    local endDistance = Path.Total - 3
    local travelDuration = (endDistance - landDistance) / speed
    local exitDuration = 1.2
    local duration = fallDuration + travelDuration + exitDuration
    -- Point on the river at `distance`, offset sideways by the egg's lane plus a gentle sway that
    -- fades in over the first 3 seconds.
    local function riverPoint(distance, elapsed)
        local pos, _, right = Path.At(distance)
        local sway = math.sin(elapsed * 0.5 + seed * 10) * 0.7 * math.min(1, elapsed / 3)
        return pos + right * (lateral + sway)
    end
    local function pose(elapsed)
        local t = math.clamp(elapsed, 0, duration)
        local pos, rot, phase
        if t < fallDuration then
            local fallProgress = t / fallDuration
            if fallProgress < 0.3 then
                -- first 30%: accelerate along the cliff top towards the lip
                local k = fallProgress / 0.3
                pos = Vector3.new(startX + (riverOrigin.X + 1 - startX) * k * k, topY, riverOrigin.Z + lateral * k)
                rot = CFrame.identity
            else
                -- remaining 70%: arc out (ease-out on X) and drop (ease-in on Y) to the landing point, tumbling a bit
                local k = (fallProgress - 0.3) / 0.7
                local posX = riverOrigin.X + 1 + (landPoint.X - (riverOrigin.X + 1)) * (1 - (1 - k) ^ 2)
                pos = Vector3.new(
                    posX,
                    topY + (floatY - topY) * k * k,
                    (riverOrigin.Z + lateral) + (landPoint.Z - (riverOrigin.Z + lateral)) * k
                )
                rot = CFrame.Angles(0.15 * math.sin(math.pi * k), 0, -0.2 * math.sin(math.pi * k))
            end
            phase = "fall"
        elseif t < fallDuration + travelDuration then
            local waterTime = t - fallDuration
            local distance = landDistance + speed * waterTime
            local settleProgress = math.clamp(waterTime / settleDuration, 0, 1)
            local dip = -0.85 * math.sin(math.pi * settleProgress) ^ 2
            local bob = 0.1 * math.sin(waterTime * 2.2 + seed * 20) * settleProgress
            local point = riverPoint(distance, waterTime)
            pos = Vector3.new(point.X, floatY + dip + bob, point.Z)
            rot = CFrame.Angles(
                0.05 * math.sin(waterTime * 1.7 + seed * 9) * settleProgress,
                0,
                0.05 * math.sin(waterTime * 1.3 + seed * 4) * settleProgress
            )
            phase = waterTime < settleDuration and "land" or "travel"
        else
            local exitProgress = (t - fallDuration - travelDuration) / exitDuration
            local point = riverPoint(endDistance + speed * exitDuration * exitProgress, travelDuration)
            pos = Vector3.new(point.X, floatY - 6 * exitProgress * exitProgress, point.Z)
            rot = CFrame.identity
            phase = "exit"
        end
        -- third return value ("cycle") is always 0 on the river; kept for API compatibility
        return CFrame.new(pos) * rot, phase, 0, duration
    end
    local lastPhase
    local function update()
        local epoch = egg:GetAttribute("Epoch")
        if not epoch then
            return
        end
        local elapsed = math.max(0, workspace:GetServerTimeNow() - epoch)
        local eggCFrame, phase = pose(elapsed)
        -- only write the attribute when it actually changes (avoids replication spam)
        if egg:GetAttribute("RiverEggVisual") and egg:GetAttribute("Collectible") ~= (phase == "travel") then
            egg:SetAttribute("Collectible", phase == "travel")
        end
        egg:PivotTo(eggCFrame)
        labelAnchor.Position = eggCFrame.Position + Vector3.new(0, size.Y * 0.5 + 2, 0)
        collectAnchor.Position = eggCFrame.Position
        for _, gui in labelAnchor:GetDescendants() do
            if gui:IsA("BillboardGui") then
                gui.Enabled = (phase == "travel")
            end
        end
        local prompt = collectAnchor:FindFirstChildOfClass("ProximityPrompt")
        if prompt then
            prompt.Enabled = (phase == "travel")
        end
        -- Client-only splash: two expanding rings of 28 thin segments, once when the egg lands.
        if game:GetService("RunService"):IsClient() and phase == "land" and lastPhase ~= "land" then
            local river = workspace:FindFirstChild("WaterfallRiver")
            if river then
                local Debris = game:GetService("Debris")
                local TweenService = game:GetService("TweenService")
                local origin = Vector3.new(eggCFrame.Position.X, Path.SurfaceY + 0.07, eggCFrame.Position.Z)
                local rippleFolder = Instance.new("Folder")
                rippleFolder.Name = "LandingRipples"
                rippleFolder.Parent = river
                Debris:AddItem(rippleFolder, 1.7)
                for layer = 1, 2 do
                    for i = 1, 28 do
                        local angle = i / 28 * math.pi * 2
                        local segment = Instance.new("Part")
                        segment.Name = "Ripple"
                        segment.Anchored = true
                        segment.CanCollide = false
                        segment.CanTouch = false
                        segment.CanQuery = false
                        segment.CastShadow = false
                        segment.Material = Enum.Material.SmoothPlastic
                        segment.Color = Color3.fromRGB(210, 248, 250)
                        segment.Transparency = 0.3
                        local radius = 1.6 + layer * 0.25
                        segment.Size = Vector3.new(radius * math.pi * 2 / 28 + 0.02, 0.012, 0.09)
                        segment.CFrame = CFrame.new(
                            origin
                                + Vector3.new(math.cos(angle) * radius, layer * 0.005, math.sin(angle) * radius * 0.8)
                        ) * CFrame.Angles(0, -angle - math.pi * 0.5, 0)
                        segment.Parent = rippleFolder
                        local finalRadius = 4 + layer * 0.55
                        TweenService
                            :Create(
                                segment,
                                TweenInfo.new(1.1 + layer * 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                                {
                                    -- +1.4 on X: the ring drifts downstream while it expands
                                    CFrame = CFrame.new(
                                        origin
                                            + Vector3.new(
                                                1.4 + math.cos(angle) * finalRadius,
                                                layer * 0.005,
                                                math.sin(angle) * finalRadius * 0.8
                                            )
                                    )
                                        * CFrame.Angles(0, -angle - math.pi * 0.5, 0),
                                    Size = Vector3.new(finalRadius * math.pi * 2 / 28 + 0.02, 0.012, 0.025),
                                    Transparency = 1,
                                }
                            )
                            :Play()
                    end
                end
            end
        end
        lastPhase = phase
    end
    return update, pose
end
