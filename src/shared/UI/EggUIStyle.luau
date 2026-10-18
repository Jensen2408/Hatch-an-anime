-- ReplicatedStorage.EggUIStyle  (ModuleScript, shared)
-- Cartoon egg-shop UI pieces: a rounded gradient panel with a faint egg-dot pattern, and outlined
-- Cartoon-font text. Both return the created instance (already parented).
local Style = {}
function Style.Panel(parent, color)
    local frame = Instance.new("Frame")
    frame.Name = "Panel"
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = color
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = true
    frame.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.09, 0)
    corner.Parent = frame
    local border = Instance.new("UIStroke")
    border.Thickness = 3
    border.Color = Color3.fromRGB(20, 20, 25)
    border.Parent = frame
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 90
    gradient.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.2), color:Lerp(Color3.new(0, 0, 0), 0.18))
    gradient.Parent = frame
    -- Repeated egg silhouettes, deliberately low contrast behind the lettering.
    -- 4 rows x 10 columns; odd rows are shifted half a column (staggered grid).
    for row = 0, 3 do
        for col = 0, 9 do
            local dot = Instance.new("Frame")
            dot.Name = "EggPattern"
            dot.AnchorPoint = Vector2.new(0.5, 0.5)
            dot.Position = UDim2.fromScale(col * 0.12 + (row % 2) * 0.06, row * 0.32 + 0.04)
            dot.Size = UDim2.fromScale(0.065, 0.23)
            dot.BackgroundColor3 = Color3.new(1, 1, 1)
            dot.BackgroundTransparency = 0.88
            dot.BorderSizePixel = 0
            dot.Parent = frame
            local round = Instance.new("UICorner")
            round.CornerRadius = UDim.new(0.5, 0)
            round.Parent = dot
        end
    end
    return frame
end
function Style.Text(parent, text, position, size, color)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = position
    label.Size = size
    label.Font = Enum.Font.Cartoon
    label.TextScaled = true
    label.Text = text
    label.TextColor3 = color or Color3.new(1, 1, 1)
    label.ZIndex = 3
    label.Parent = parent
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(18, 18, 22)
    stroke.Thickness = 2
    stroke.Parent = label
    return label
end
return Style
