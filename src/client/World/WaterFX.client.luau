-- StarterPlayerScripts.WaterFX  (client only: animates flow streaks, foam and ripples — nothing replicates)
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local folder = RS:WaitForChild("WaterfallRiver")
local Path = require(folder:WaitForChild("RiverPath"))
local root = workspace:WaitForChild("WaterfallRiver")

local streaks, ripples = {}, {}
local function register(b)
    if not b:IsA("Beam") then
        return
    end
    if b:GetAttribute("FlowSpeed") then
        local a0, a1 = b.Attachment0, b.Attachment1
        table.insert(streaks, {
            beam = b,
            speed = b:GetAttribute("FlowSpeed"),
            len = b:GetAttribute("FlowLen"),
            alpha = b:GetAttribute("FlowAlpha"),
            phase = b:GetAttribute("FlowPhase") or 0,
            count = b:GetAttribute("FlowCount") or 1,
            mid = (a0 and a1) and (a0.WorldPosition + a1.WorldPosition) / 2 or Vector3.zero,
        })
    elseif b:GetAttribute("Ripple") then
        table.insert(ripples, { beam = b, i = b:GetAttribute("Ripple"), n = b:GetAttribute("RippleCount") or 7 })
    end
end
for _, d in root:GetDescendants() do
    register(d)
end
root.DescendantAdded:Connect(register)

local KP = NumberSequenceKeypoint.new
local camera = workspace.CurrentCamera
local cleanupAt = 0
local acc = 0
RunService.RenderStepped:Connect(function(dt)
    acc += dt
    if acc < 1 / 30 then
        return
    end -- 30 Hz is plenty for soft streaks
    acc = 0
    local t = os.clock()
    camera = workspace.CurrentCamera
    if not camera then
        return
    end
    if t > cleanupAt then
        cleanupAt = t + 2
        for i = #streaks, 1, -1 do
            if not streaks[i].beam:IsDescendantOf(root) then
                table.remove(streaks, i)
            end
        end
        for i = #ripples, 1, -1 do
            if not ripples[i].beam:IsDescendantOf(root) then
                table.remove(ripples, i)
            end
        end
    end
    local cp = camera.CFrame.Position
    for _, s in streaks do
        if s.beam.Parent and (s.mid - cp).Magnitude < 350 then
            s.beam.Transparency = Path.Dash(t * s.speed + s.phase, s.len, s.alpha, s.count)
        end
    end
    for _, rp in ripples do
        local b = rp.beam
        if b.Parent and b.Attachment0 and b.Attachment1 then
            local u = (t / 3.6 + rp.i / rp.n) % 1
            local d = Path.LandDistance + 1 + u * 22
            local pos, tan, right = Path.At(d)
            local hw = math.min(2 + u * 5.5, Path.WidthAt(d) / 2 - 1)
            local c = Vector3.new(pos.X, Path.SurfaceY + 0.1, pos.Z)
            local d0, d1 = (right + tan * 0.9).Unit, (right - tan * 0.9).Unit
            b.Attachment0.WorldCFrame = CFrame.fromMatrix(c - right * hw, d0, Vector3.yAxis:Cross(d0))
            b.Attachment1.WorldCFrame = CFrame.fromMatrix(c + right * hw, d1, Vector3.yAxis:Cross(d1))
            b.CurveSize0, b.CurveSize1 = hw * 0.6, hw * 0.6
            local a = 0.5 + 0.5 * u
            b.Transparency = NumberSequence.new({ KP(0, 1), KP(0.2, a), KP(0.8, a), KP(1, 1) })
            b.Width0 = 0.16 + 0.2 * u
            b.Width1 = b.Width0
        end
    end
end)
