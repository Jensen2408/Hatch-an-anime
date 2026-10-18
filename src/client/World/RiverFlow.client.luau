-- RiverFlow: scrolling current streaks laid along the river so the water visibly flows downstream (client only).
local RS = game:GetService("ReplicatedStorage")
local Path = require(RS:WaitForChild("WaterfallRiver"):WaitForChild("RiverPath"))
local TEX = script:GetAttribute("Texture")
local SPEED = script:GetAttribute("Speed") or 0.9
local folder = Instance.new("Folder")
folder.Name = "RiverFlowLocal"
folder.Parent = workspace
local anchor = Instance.new("Part")
anchor.Name = "FlowAnchor"
anchor.Anchored = true
anchor.CanCollide = false
anchor.CanQuery = false
anchor.CanTouch = false
anchor.Transparency = 1
anchor.Size = Vector3.one
anchor.CFrame = CFrame.new()
anchor.Parent = folder
local STEP = 12
local function layer(lift, speed, len, alpha, widthMul, color)
    local prev
    for d = Path.LandDistance or 0, Path.Total, STEP do
        local p = Path.At(d)
        local a = Instance.new("Attachment")
        a.Parent = anchor
        a.WorldCFrame = CFrame.fromMatrix(p + Vector3.new(0, lift, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1))
        if prev then
            local w = (Path.WidthAt and Path.WidthAt(d) or 14) * widthMul
            local b = Instance.new("Beam")
            b.Attachment0 = prev
            b.Attachment1 = a
            b.Texture = TEX
            b.TextureMode = Enum.TextureMode.Static
            b.TextureLength = len
            b.TextureSpeed = speed
            b.Width0 = w
            b.Width1 = w
            b.FaceCamera = false
            b.LightEmission = 0.35
            b.LightInfluence = 0.6
            b.Color = ColorSequence.new(color)
            b.Transparency = NumberSequence.new(alpha)
            b.Segments = 1
            b.Parent = anchor
        end
        prev = a
    end
end
-- beams lie flat because both attachments are level and FaceCamera is off (their up = world Y)
layer(0.06, SPEED, STEP * 2.5, 0.35, 0.9, Color3.fromRGB(235, 255, 255))
layer(0.09, SPEED * 1.6, STEP * 1.6, 0.55, 0.7, Color3.fromRGB(200, 250, 255))
