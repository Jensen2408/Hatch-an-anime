-- StarterPlayerScripts.WaterFX  (client only: animates flow streaks, foam and ripples — nothing replicates)
-- Drives Beams under workspace.WaterfallRiver by their attributes:
--   FlowSpeed / FlowLen / FlowAlpha / FlowPhase / FlowCount -> scrolling dash transparency (RiverPath.Dash)
--   Ripple / RippleCount -> re-shaped every tick into an expanding arc just below the waterfall
-- Updates at ~30 Hz; streaks farther than 350 studs from the camera are skipped.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local riverAssets = ReplicatedStorage:WaitForChild("WaterfallRiver")
local RiverPath = require(riverAssets:WaitForChild("RiverPath"))
local riverRoot = workspace:WaitForChild("WaterfallRiver")

local streaks, ripples = {}, {}
local function registerBeam(beam)
    if not beam:IsA("Beam") then
        return
    end
    if beam:GetAttribute("FlowSpeed") then
        local attachment0, attachment1 = beam.Attachment0, beam.Attachment1
        table.insert(streaks, {
            beam = beam,
            speed = beam:GetAttribute("FlowSpeed"),
            len = beam:GetAttribute("FlowLen"),
            alpha = beam:GetAttribute("FlowAlpha"),
            phase = beam:GetAttribute("FlowPhase") or 0,
            count = beam:GetAttribute("FlowCount") or 1,
            mid = (attachment0 and attachment1) and (attachment0.WorldPosition + attachment1.WorldPosition) / 2
                or Vector3.zero,
        })
    elseif beam:GetAttribute("Ripple") then
        table.insert(
            ripples,
            { beam = beam, i = beam:GetAttribute("Ripple"), n = beam:GetAttribute("RippleCount") or 7 }
        )
    end
end
for _, descendant in riverRoot:GetDescendants() do
    registerBeam(descendant)
end
riverRoot.DescendantAdded:Connect(registerBeam)

local newKeypoint = NumberSequenceKeypoint.new
local camera = workspace.CurrentCamera
local cleanupAt = 0
local accumulated = 0
RunService.RenderStepped:Connect(function(dt)
    accumulated += dt
    if accumulated < 1 / 30 then
        return
    end -- 30 Hz is plenty for soft streaks
    accumulated = 0
    local now = os.clock()
    camera = workspace.CurrentCamera
    if not camera then
        return
    end
    if now > cleanupAt then
        cleanupAt = now + 2
        for i = #streaks, 1, -1 do
            if not streaks[i].beam:IsDescendantOf(riverRoot) then
                table.remove(streaks, i)
            end
        end
        for i = #ripples, 1, -1 do
            if not ripples[i].beam:IsDescendantOf(riverRoot) then
                table.remove(ripples, i)
            end
        end
    end
    local cameraPosition = camera.CFrame.Position
    for _, streak in streaks do
        if streak.beam.Parent and (streak.mid - cameraPosition).Magnitude < 350 then
            streak.beam.Transparency =
                RiverPath.Dash(now * streak.speed + streak.phase, streak.len, streak.alpha, streak.count)
        end
    end
    for _, ripple in ripples do
        local beam = ripple.beam
        if beam.Parent and beam.Attachment0 and beam.Attachment1 then
            local progress = (now / 3.6 + ripple.i / ripple.n) % 1
            local distance = RiverPath.LandDistance + 1 + progress * 22
            local position, tangent, right = RiverPath.At(distance)
            local halfWidth = math.min(2 + progress * 5.5, RiverPath.WidthAt(distance) / 2 - 1)
            local center = Vector3.new(position.X, RiverPath.SurfaceY + 0.1, position.Z)
            -- selene flags Vector3.yAxis:Cross (below) as incorrect_standard_library_use: false positive (Vector3 method).
            local direction0, direction1 = (right + tangent * 0.9).Unit, (right - tangent * 0.9).Unit
            beam.Attachment0.WorldCFrame =
                CFrame.fromMatrix(center - right * halfWidth, direction0, Vector3.yAxis:Cross(direction0))
            beam.Attachment1.WorldCFrame =
                CFrame.fromMatrix(center + right * halfWidth, direction1, Vector3.yAxis:Cross(direction1))
            beam.CurveSize0, beam.CurveSize1 = halfWidth * 0.6, halfWidth * 0.6
            local alpha = 0.5 + 0.5 * progress
            beam.Transparency = NumberSequence.new({
                newKeypoint(0, 1),
                newKeypoint(0.2, alpha),
                newKeypoint(0.8, alpha),
                newKeypoint(1, 1),
            })
            beam.Width0 = 0.16 + 0.2 * progress
            beam.Width1 = beam.Width0
        end
    end
end)
