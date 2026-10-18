local fx = script.Parent
local hl, light = fx:WaitForChild("GoldShine"), fx:WaitForChild("GoldFX_Emitter"):WaitForChild("PointLight")
local RunService = game:GetService("RunService")
local t0 = os.clock()
RunService.Heartbeat:Connect(function()
	local t = (os.clock() - t0) % 3.2
	local k = math.max(0, 1 - math.abs(t - 0.45) / 0.45)   -- quick flash every 3.2 s
	hl.FillTransparency = 0.88 - 0.4 * k * k
	light.Brightness = 2.6 + 0.4 * math.sin(os.clock() * 2) + 2 * k
end)
