-- StarterPlayerScripts.RiverFlow: scrolling current streaks laid along the river so the water visibly flows
-- downstream (client only, no remotes). Script attributes: Texture (beam texture id), Speed (default 0.9).
-- Two beam layers follow ReplicatedStorage.WaterfallRiver.RiverPath, sampled every SAMPLE_STEP studs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RiverPath = require(ReplicatedStorage:WaitForChild("WaterfallRiver"):WaitForChild("RiverPath"))
local TEXTURE = script:GetAttribute("Texture")
local SPEED = script:GetAttribute("Speed") or 0.9
local flowFolder = Instance.new("Folder")
flowFolder.Name = "RiverFlowLocal"
flowFolder.Parent = workspace
local flowAnchor = Instance.new("Part")
flowAnchor.Name = "FlowAnchor"
flowAnchor.Anchored = true
flowAnchor.CanCollide = false
flowAnchor.CanQuery = false
flowAnchor.CanTouch = false
flowAnchor.Transparency = 1
flowAnchor.Size = Vector3.one
flowAnchor.CFrame = CFrame.new()
flowAnchor.Parent = flowFolder
local SAMPLE_STEP = 12
local function addFlowLayer(lift, textureSpeed, textureLength, transparency, widthScale, color)
    local previousAttachment
    for distance = RiverPath.LandDistance or 0, RiverPath.Total, SAMPLE_STEP do
        local point = RiverPath.At(distance)
        local attachment = Instance.new("Attachment")
        attachment.Parent = flowAnchor
        attachment.WorldCFrame =
            CFrame.fromMatrix(point + Vector3.new(0, lift, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1))
        if previousAttachment then
            local width = (RiverPath.WidthAt and RiverPath.WidthAt(distance) or 14) * widthScale
            local beam = Instance.new("Beam")
            beam.Attachment0 = previousAttachment
            beam.Attachment1 = attachment
            beam.Texture = TEXTURE
            beam.TextureMode = Enum.TextureMode.Static
            beam.TextureLength = textureLength
            beam.TextureSpeed = textureSpeed
            beam.Width0 = width
            beam.Width1 = width
            beam.FaceCamera = false
            beam.LightEmission = 0.35
            beam.LightInfluence = 0.6
            beam.Color = ColorSequence.new(color)
            beam.Transparency = NumberSequence.new(transparency)
            beam.Segments = 1
            beam.Parent = flowAnchor
        end
        previousAttachment = attachment
    end
end
-- beams lie flat because both attachments are level and FaceCamera is off (their up = world Y)
addFlowLayer(0.06, SPEED, SAMPLE_STEP * 2.5, 0.35, 0.9, Color3.fromRGB(235, 255, 255))
addFlowLayer(0.09, SPEED * 1.6, SAMPLE_STEP * 1.6, 0.55, 0.7, Color3.fromRGB(200, 250, 255))
