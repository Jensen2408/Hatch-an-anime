-- Workspace.PumpkinGentleman.PumpkinIdle (server Script)
-- Runs on the server, so the Motor6D C0 writes replicate to every client each Heartbeat.
-- Idle loop for the Pumpkin Gentleman: breathing, look around, cane tap, hat tip, flickering face.
local model = script.Parent
local rigRoot = model.Root
local function findMotor(motorName)
    return rigRoot:FindFirstChild(motorName, true) or model:FindFirstChild(motorName, true)
end
local hips = findMotor("HipsMotor")
local head = findMotor("HeadMotor")
local hat = findMotor("HatMotor")
local shoulderL = findMotor("ShoulderLMotor")
local shoulderR = findMotor("ShoulderRMotor")
local baseC0 = {}
for _, motorInstance in ipairs({ hips, head, hat, shoulderL, shoulderR }) do
    baseC0[motorInstance] = motorInstance.C0
end
local face = model:FindFirstChild("FaceGlow", true)
local _glowParts = {}
for _, part in ipairs(model:GetDescendants()) do
    if part:IsA("BasePart") and part.Material == Enum.Material.Neon then
        table.insert(_glowParts, part)
    end
end
local LOOP_SECONDS = 8 -- length of one idle cycle; every timeline below is in seconds within it
local function ease(t)
    return (1 - math.cos(math.pi * math.clamp(t, 0, 1))) / 2
end
local function pulse(t, startTime, endTime)
    if t < startTime or t > endTime then
        return 0
    end
    return math.sin(math.pi * (t - startTime) / (endTime - startTime))
end
local rad = math.rad
local startClock = os.clock()
game:GetService("RunService").Heartbeat:Connect(function()
    local t = (os.clock() - startClock) % LOOP_SECONDS
    local breath = math.sin(t / LOOP_SECONDS * math.pi * 2 * 4)
    hips.C0 = baseC0[hips] * CFrame.new(0, 0.15 * breath, 0) * CFrame.Angles(rad(1.2) * breath, 0, 0)
    -- look left, hold, look right, hold
    local yaw = 0
    if t < 1.5 then
        yaw = ease(t / 1.5) * 18
    elseif t < 3 then
        yaw = 18
    elseif t < 4.5 then
        yaw = 18 - ease((t - 3) / 1.5) * 36
    elseif t < 6 then
        yaw = -18
    else
        yaw = -18 + ease((t - 6) / 1.2) * 18
    end
    head.C0 = baseC0[head] * CFrame.Angles(rad(-3 * breath), rad(yaw), rad(yaw * 0.15))
    -- cane taps
    local tap = pulse(t, 3.2, 3.5) + pulse(t, 3.6, 3.9)
    shoulderR.C0 = baseC0[shoulderR] * CFrame.Angles(rad(-10 * tap), 0, 0)
    shoulderL.C0 = baseC0[shoulderL]
        * CFrame.Angles(rad(4 * math.sin(t / LOOP_SECONDS * math.pi * 2)), 0, rad(-2 * breath))
    -- hat tip
    local tip = pulse(t, 6.6, 7.8)
    hat.C0 = baseC0[hat] * CFrame.new(0, 1.2 * tip, -0.6 * tip) * CFrame.Angles(rad(-25 * tip), 0, 0)
    -- candle flicker
    local flicker = 0.75 + 0.25 * math.noise(os.clock() * 3, 0.5) + 0.1 * math.random()
    if face then
        face.Brightness = 3 * flicker
    end
end)
