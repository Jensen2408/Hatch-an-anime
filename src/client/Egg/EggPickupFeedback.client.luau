--[[ StarterPlayerScripts.EggPickupFeedback  (LocalScript)
Pickup feedback for conveyor eggs: when the server reports a collected egg, a local copy of the egg flies
along a curve into the player's hands, then a "+1 <Name> Egg" card pops up and a per-egg voice line plays.

Remote: ReplicatedStorage.EggCollected (server -> client, fired by ConveyorEggs):
  OnClientEvent(eggId: string, eggCFrame: CFrame, eggSize: Vector3)
Purely cosmetic; the egg was already granted on the server before this fires.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer
local EggCatalog = require(ReplicatedStorage:WaitForChild("EggCatalog"))
local catalogById = {} -- [egg Id] = EggCatalog entry
for _, entry in ipairs(EggCatalog) do
    catalogById[entry.Id] = entry
end

-- ═══════════════════════════ pickup card UI ═══════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name = "EggPickupFeedback"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local Style = require(ReplicatedStorage:WaitForChild("EggUIStyle"))
local pickupCard = Instance.new("Frame")
pickupCard.Name = "PickupCard"
pickupCard.AnchorPoint = Vector2.new(0.5, 1)
pickupCard.Position = UDim2.fromScale(0.5, 0.83)
pickupCard.Size = UDim2.new(0.8, 0, 0, 60)
pickupCard.BackgroundTransparency = 1
pickupCard.Visible = false
pickupCard.Parent = gui
local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MaxSize = Vector2.new(370, 60)
sizeConstraint.Parent = pickupCard
local panel = Style.Panel(pickupCard, Color3.fromRGB(70, 195, 90))
local cardLabel = Style.Text(panel, "", UDim2.fromScale(0.04, 0.1), UDim2.fromScale(0.92, 0.8))
local cardScale = Instance.new("UIScale")
cardScale.Parent = pickupCard

-- ═══════════════════════════ voice lines ═══════════════════════════
local VOICE_ASSET_IDS = { -- [egg Id] = audio asset id
    Tung = "138857089980331",
    Ballerina = "136160874492071",
    Lirili = "77891869376009",
    Patapim = "135871919265006",
    Crocodilo = "95943432024838",
}
local voiceSounds = {} -- [egg Id] = Sound
for eggId, assetId in pairs(VOICE_ASSET_IDS) do
    local sound = Instance.new("Sound")
    sound.Name = "EggVoice_" .. eggId
    sound.SoundId = "rbxassetid://" .. assetId
    sound.Volume = 0.35
    sound.Parent = SoundService
    voiceSounds[eggId] = sound
    task.spawn(function()
        pcall(function()
            game:GetService("ContentProvider"):PreloadAsync({ sound })
        end)
    end)
end

local currentVoice
local voiceToken = 0 -- bumped per pickup so only the latest voice's 7 s auto-stop applies
local function playPickup(eggId)
    voiceToken += 1
    local token = voiceToken
    if currentVoice then
        currentVoice:Stop()
    end
    local voice = voiceSounds[eggId]
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

-- ═══════════════════════════ fly-to-player animation ═══════════════════════════
local cardSerial = 0 -- bumped per card show so only the latest pickup hides the card
ReplicatedStorage:WaitForChild("EggCollected").OnClientEvent:Connect(function(eggId, startCFrame, startSize)
    local entry = catalogById[eggId]
    local template = ReplicatedStorage.EggVisuals:FindFirstChild(eggId)
    if not entry or not template then
        return
    end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end
    local visual = template:Clone()
    visual.Name = "CollectingEgg"
    visual.Size = startSize
    visual.CFrame = startCFrame
    visual.Anchored = true
    visual.CanCollide = false
    visual.CanTouch = false
    visual.CanQuery = false
    visual.Parent = workspace
    local elapsed = 0
    local duration = 0.65
    local flightConn
    flightConn = RunService.RenderStepped:Connect(function(dt)
        elapsed += dt
        local progress = math.min(elapsed / duration, 1)
        if not root.Parent then
            flightConn:Disconnect()
            visual:Destroy()
            return
        end
        -- quadratic Bezier from the conveyor to just in front of the (moving) player, arcing 5 studs up
        local target = root.CFrame:PointToWorldSpace(Vector3.new(0, 0.6, 1.25))
        local control = (startCFrame.Position + target) / 2 + Vector3.new(0, 5, 0)
        local eased = progress * progress * (3 - 2 * progress) -- smoothstep
        local position = (1 - eased) ^ 2 * startCFrame.Position
            + 2 * (1 - eased) * eased * control
            + eased * eased * target
        visual.CFrame = CFrame.new(position) * startCFrame.Rotation * CFrame.Angles(0, eased * math.pi * 2, 0)
        visual.Size = startSize * math.max(0.05, 1 - 0.95 * eased)
        if progress >= 1 then
            flightConn:Disconnect()
            visual:Destroy()
            playPickup(eggId)
            cardSerial += 1
            local token = cardSerial
            cardLabel.Text = "+1 " .. entry.Name .. " Egg"
            pickupCard.Visible = true
            cardScale.Scale = 0.8
            TweenService
                :Create(cardScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
                :Play()
            task.delay(1.7, function()
                if cardSerial == token then
                    pickupCard.Visible = false
                end
            end)
        end
    end)
end)
