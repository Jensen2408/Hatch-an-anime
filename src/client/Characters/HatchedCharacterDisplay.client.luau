--[[ StarterPlayerScripts.HatchedCharacterDisplay  (LocalScript)
Client-only presentation of a freshly hatched character standing in its incubator (tag "HatchRewardDisplay").
On tag: a smoke puff + fading highlight (temporary "LocalHatchReveal" part in workspace, removed after 1 s),
a permanent soft "RewardAura" Highlight and a PointLight on the Torso.
Every frame (within REVEAL_DISTANCE of the camera): rises out of the platform with a half turn, then bobs
while slowly turning.
Reads attributes set by the server: RewardHome (CFrame, required) and RevealEpoch (server time, optional)
so every client plays the entrance in sync.
]]
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local TAG = "HatchRewardDisplay"
local REVEAL_DISTANCE = 130
local ENTRANCE_SECONDS = 0.75

local active = {} -- [Model] = { home = CFrame, epoch = server time the reveal started }

local function add(model)
    if active[model] then
        return
    end
    local home = model:GetAttribute("RewardHome")
    if not home then
        return
    end
    active[model] = { home = home, epoch = model:GetAttribute("RevealEpoch") or workspace:GetServerTimeNow() }

    -- one-shot reveal effects
    local revealRoot = Instance.new("Part")
    revealRoot.Name = "LocalHatchReveal"
    revealRoot.Size = Vector3.one
    revealRoot.Transparency = 1
    revealRoot.Anchored = true
    revealRoot.CanCollide = false
    revealRoot.CanQuery = false
    revealRoot.CanTouch = false
    revealRoot.CFrame = home * CFrame.new(0, 1.8, 0)
    revealRoot.Parent = workspace
    local puff = Instance.new("ParticleEmitter")
    puff.Texture = "rbxasset://textures/particles/smoke_main.dds"
    puff.Rate = 0
    puff.Color = ColorSequence.new(Color3.fromRGB(240, 250, 231))
    puff.LightEmission = 0.5
    puff.Lifetime = NumberRange.new(0.35, 0.65)
    puff.Speed = NumberRange.new(1.5, 3)
    puff.SpreadAngle = Vector2.new(180, 180)
    puff.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.8) })
    puff.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
    puff.Parent = revealRoot
    puff:Emit(12)
    local highlight = Instance.new("Highlight")
    highlight.Adornee = model
    highlight.FillColor = Color3.fromRGB(255, 237, 167)
    highlight.FillTransparency = 0.4
    highlight.OutlineTransparency = 0.2
    highlight.Parent = revealRoot
    TweenService:Create(highlight, TweenInfo.new(0.5), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
    Debris:AddItem(revealRoot, 1)

    -- lasting glow (lives on the model, gone with it)
    local aura = Instance.new("Highlight")
    aura.Name = "RewardAura"
    aura.Adornee = model
    aura.FillColor = Color3.fromRGB(255, 226, 133)
    aura.FillTransparency = 0.96
    aura.OutlineColor = aura.FillColor
    aura.OutlineTransparency = 0.65
    aura.DepthMode = Enum.HighlightDepthMode.Occluded
    aura.Parent = model
    local torso = model:FindFirstChild("Torso", true)
    if torso then
        local lamp = Instance.new("PointLight")
        lamp.Color = Color3.fromRGB(255, 230, 155)
        lamp.Range = 6
        lamp.Brightness = 0.55
        lamp.Shadows = false
        lamp.Parent = torso
    end
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
    active[model] = nil
end)
for _, model in CollectionService:GetTagged(TAG) do
    add(model)
end

RunService:BindToRenderStep("HatchedCharacterIdle", Enum.RenderPriority.Camera.Value + 2, function()
    local now = workspace:GetServerTimeNow()
    for model, reveal in active do
        if not model:IsDescendantOf(workspace) then
            active[model] = nil
        elseif
            workspace.CurrentCamera
            and (workspace.CurrentCamera.CFrame.Position - reveal.home.Position).Magnitude < REVEAL_DISTANCE
        then
            local elapsed = math.max(0, now - reveal.epoch)
            -- entrance: rises out of the platform with a half turn, then eases into the idle bob
            local entrance = 1 - (1 - math.clamp(elapsed / ENTRANCE_SECONDS, 0, 1)) ^ 3 -- ease-out cubic
            model:PivotTo(
                reveal.home
                    * CFrame.new(0, -0.45 * (1 - entrance) + 0.16 * (1 - math.cos(elapsed * 2)) * entrance, 0)
                    * CFrame.Angles(0, elapsed * 0.7 - math.pi * (1 - entrance), 0)
            )
        end
    end
end)
