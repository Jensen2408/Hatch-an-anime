local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer
local catalog = require(RS:WaitForChild("EggCatalog"))
local entries = {}
for _, e in ipairs(catalog) do
    entries[e.Id] = e
end
local gui = Instance.new("ScreenGui")
gui.Name = "EggPickupFeedback"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local Style = require(RS:WaitForChild("EggUIStyle"))
local holder = Instance.new("Frame")
holder.Name = "PickupCard"
holder.AnchorPoint = Vector2.new(0.5, 1)
holder.Position = UDim2.fromScale(0.5, 0.83)
holder.Size = UDim2.new(0.8, 0, 0, 60)
holder.BackgroundTransparency = 1
holder.Visible = false
holder.Parent = gui
local constraint = Instance.new("UISizeConstraint")
constraint.MaxSize = Vector2.new(370, 60)
constraint.Parent = holder
local panel = Style.Panel(holder, Color3.fromRGB(70, 195, 90))
local label = Style.Text(panel, "", UDim2.fromScale(0.04, 0.1), UDim2.fromScale(0.92, 0.8))
local scale = Instance.new("UIScale")
scale.Parent = holder
local voiceIds = {
    Tung = "138857089980331",
    Ballerina = "136160874492071",
    Lirili = "77891869376009",
    Patapim = "135871919265006",
    Crocodilo = "95943432024838",
}
local voices = {}
for id, asset in pairs(voiceIds) do
    local sound = Instance.new("Sound")
    sound.Name = "EggVoice_" .. id
    sound.SoundId = "rbxassetid://" .. asset
    sound.Volume = 0.35
    sound.Parent = SoundService
    voices[id] = sound
    task.spawn(function()
        pcall(function()
            game:GetService("ContentProvider"):PreloadAsync({ sound })
        end)
    end)
end
local currentVoice
local voiceToken = 0
local function playPickup(id)
    voiceToken += 1
    local token = voiceToken
    if currentVoice then
        currentVoice:Stop()
    end
    local voice = voices[id]
    if not voice then
        return
    end
    currentVoice = voice
    voice.TimePosition = 0
    voice:Play()
    task.delay(7, function()
        if token == voiceToken then
            voice:Stop()
        end
    end)
end
local serial = 0
RS:WaitForChild("EggCollected").OnClientEvent:Connect(function(id, from, size)
    local e = entries[id]
    local template = RS.EggVisuals:FindFirstChild(id)
    if not e or not template then
        return
    end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end
    local visual = template:Clone()
    visual.Name = "CollectingEgg"
    visual.Size = size
    visual.CFrame = from
    visual.Anchored = true
    visual.CanCollide = false
    visual.CanTouch = false
    visual.CanQuery = false
    visual.Parent = workspace
    local elapsed = 0
    local duration = 0.65
    local connection
    connection = RunService.RenderStepped:Connect(function(dt)
        elapsed += dt
        local t = math.min(elapsed / duration, 1)
        if not root.Parent then
            connection:Disconnect()
            visual:Destroy()
            return
        end
        local target = root.CFrame:PointToWorldSpace(Vector3.new(0, 0.6, 1.25))
        local control = (from.Position + target) / 2 + Vector3.new(0, 5, 0)
        local u = t * t * (3 - 2 * t)
        local pos = (1 - u) ^ 2 * from.Position + 2 * (1 - u) * u * control + u * u * target
        visual.CFrame = CFrame.new(pos) * from.Rotation * CFrame.Angles(0, u * math.pi * 2, 0)
        visual.Size = size * math.max(0.05, 1 - 0.95 * u)
        if t >= 1 then
            connection:Disconnect()
            visual:Destroy()
            playPickup(id)
            serial += 1
            local token = serial
            label.Text = "+1 " .. e.Name .. " Egg"
            holder.Visible = true
            scale.Scale = 0.8
            TweenService
                :Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
                :Play()
            task.delay(1.7, function()
                if serial == token then
                    holder.Visible = false
                end
            end)
        end
    end)
end)
