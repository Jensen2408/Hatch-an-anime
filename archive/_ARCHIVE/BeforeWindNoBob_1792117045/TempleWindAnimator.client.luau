-- Airborne visual wind across the central temple courtyard.
-- Authored beams provide an edit-mode preview; animation runs locally.
local RunService = game:GetService("RunService")
local folder = workspace:WaitForChild("TempleWindStreams")
local elapsed = 0
local accumulator = 0
local streams = {}

local function register(anchor)
 if not anchor:IsA("BasePart") or streams[anchor] then return end
 local beam = anchor:FindFirstChild("AirStreak")
 local origin = anchor:GetAttribute("Origin")
 local duration = anchor:GetAttribute("Duration")
 if not beam or not origin or not duration then return end
 streams[anchor] = {
  beam = beam, origin = origin, duration = duration,
  phase = anchor:GetAttribute("Phase") or 0,
 }
end

for _, anchor in folder:GetChildren() do register(anchor) end
folder.ChildAdded:Connect(register)
folder.ChildRemoved:Connect(function(anchor) streams[anchor] = nil end)

local connection
connection = RunService.Heartbeat:Connect(function(dt)
 if not folder.Parent then connection:Disconnect() return end
 elapsed += dt
 accumulator += dt
 if accumulator < 1 / 30 then return end
 accumulator = 0
 for anchor, stream in pairs(streams) do
  local phase = (elapsed / stream.duration + stream.phase) % 1
  local t = elapsed + stream.phase * 10
  -- gentle double-sine sway so streaks ripple instead of sliding straight
  local sway = math.sin(phase * math.pi * 6 + t * 0.8) * 3 + math.sin(t * 1.7) * 1.2
  anchor.Position = stream.origin + Vector3.new(phase * 500, math.sin(phase * math.pi * 2) * 2 + sway, phase * 17 + math.cos(t * 1.1) * 2.5)
  stream.beam.CurveSize0 = math.sin(t * 2.1) * 9
  stream.beam.CurveSize1 = -math.sin(t * 2.1 + 1.3) * 9
  local fade = math.clamp(math.min(phase / 0.12, (1 - phase) / 0.16), 0, 1)
  stream.beam.Transparency = NumberSequence.new({
   NumberSequenceKeypoint.new(0, 1),
   NumberSequenceKeypoint.new(0.16, 1 - 0.42 * fade),
   NumberSequenceKeypoint.new(0.68, 1 - 0.33 * fade),
   NumberSequenceKeypoint.new(1, 1),
  })
 end
end)
