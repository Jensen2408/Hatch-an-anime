--[[ ReplicatedStorage.MutationShade (ModuleScript, client) - 2026-11-09
Mutation look for egg labels and character cards in the world: the mutation's colour shading over the plate,
breathing softly, and a bright shine band sweeping across it. Rainbow turns through every colour.
  MutationShade.Apply(plate, mutation, zIndex?)  adds (or swaps) the layers inside `plate`; mutation nil = remove
One Heartbeat loop drives every plate; plates that leave the game drop out on their own. Reduced motion keeps the
colours and stops the movement. Used by EggLabel (eggs) and CharacterInfo.Style (characters). ]]
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local MutationShade = {}
-- { light, dark, shine }
MutationShade.Colors = {
    Silver = { Color3.fromRGB(235, 242, 255), Color3.fromRGB(120, 135, 160), Color3.fromRGB(255, 255, 255) },
    Gold = { Color3.fromRGB(255, 226, 90), Color3.fromRGB(210, 120, 0), Color3.fromRGB(255, 250, 200) },
    Diamond = { Color3.fromRGB(150, 240, 255), Color3.fromRGB(30, 130, 255), Color3.fromRGB(235, 255, 255) },
    Rainbow = { Color3.fromRGB(255, 120, 220), Color3.fromRGB(120, 80, 255), Color3.fromRGB(255, 255, 255) },
    Molten = { Color3.fromRGB(255, 150, 40), Color3.fromRGB(150, 20, 0), Color3.fromRGB(255, 230, 120) },
}
local RAINBOW = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 90)),
    ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 40)),
    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 240, 70)),
    ColorSequenceKeypoint.new(0.6, Color3.fromRGB(70, 230, 120)),
    ColorSequenceKeypoint.new(0.8, Color3.fromRGB(70, 150, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
})

local live = setmetatable({}, { __mode = "k" }) -- [plate] = { base, sweep, rainbow, seed }
local loop
local function startLoop()
    if loop then
        return
    end
    loop = RunService.Heartbeat:Connect(function()
        if GuiService.ReducedMotionEnabled then
            return
        end
        local t = os.clock()
        for plate, info in live do
            if not plate.Parent or not info.base.Parent then
                live[plate] = nil
            else
                local k = t + info.seed
                local phase = (k % 2.6) / 1.1
                info.sweep.Offset = Vector2.new(phase <= 1 and (phase * 2.4 - 1.2) or 1.5, 0)
                if info.rainbow then
                    info.base.Rotation = (k * 60) % 360
                else
                    local breath = (math.sin(k * 2.2) + 1) / 2
                    info.base.Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0.75 - breath * 0.1),
                        NumberSequenceKeypoint.new(1, 0.3 - breath * 0.12),
                    })
                end
            end
        end
    end)
end

function MutationShade.Apply(plate, mutation, zIndex)
    for _, name in { "MutationShade", "MutationSweep" } do
        local old = plate:FindFirstChild(name)
        if old then
            old:Destroy()
        end
    end
    live[plate] = nil
    local colors = mutation and MutationShade.Colors[mutation]
    if not colors then
        return
    end
    local light, dark, shine = colors[1], colors[2], colors[3]
    local rainbow = mutation == "Rainbow"
    local radius = plate:FindFirstChildOfClass("UICorner")
    local function layer(name)
        local frame = Instance.new("Frame")
        frame.Name = name
        frame.Size = UDim2.fromScale(1, 1)
        frame.BackgroundColor3 = Color3.new(1, 1, 1)
        frame.BorderSizePixel = 0
        frame.ZIndex = zIndex or plate.ZIndex
        if radius then
            radius:Clone().Parent = frame
        end
        frame.Parent = plate
        return frame
    end
    local base = Instance.new("UIGradient")
    base.Rotation = rainbow and 0 or 90
    base.Color = rainbow and RAINBOW or ColorSequence.new(light, dark)
    base.Transparency = rainbow and NumberSequence.new(0.45)
        or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.25) })
    base.Parent = layer("MutationShade")
    local sweep = Instance.new("UIGradient")
    sweep.Rotation = 20
    sweep.Color = ColorSequence.new(shine)
    sweep.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.4, 1),
        NumberSequenceKeypoint.new(0.5, 0.25),
        NumberSequenceKeypoint.new(0.6, 1),
        NumberSequenceKeypoint.new(1, 1),
    })
    sweep.Offset = Vector2.new(-1.2, 0)
    sweep.Parent = layer("MutationSweep")
    live[plate] = { base = base, sweep = sweep, rainbow = rainbow, seed = math.random() * 3 }
    startLoop()
end

return MutationShade
