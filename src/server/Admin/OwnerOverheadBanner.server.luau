--[[ ServerScriptService.OwnerOverheadBanner  (Script)
Animated [OWNER] / [CO-OWNER] / [YOUTUBE] BillboardGui ("OwnerBanner") above the head of the listed accounts.
Cosmetic only. Matches by UserId or by verified username (Player.Name, never DisplayName). UserIds duplicate
AdminRoles / RoleTagServer. Each banner runs its own shine loop until the GUI or character is gone.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- ===== 1. Who gets a banner =====
local ROLE_BY_USER_ID = {
    [168774222] = { Text = "OWNER", Size = 25 },
    [353101613] = { Text = "CO-OWNER", Size = 21 },
    [10192461618] = { Text = "YOUTUBE", Size = 21 },
}
local ROLE_BY_USERNAME = {
    rofloxreal = { Text = "YOUTUBE", Size = 21 },
}

local function roleFor(player)
    return ROLE_BY_USER_ID[player.UserId] or ROLE_BY_USERNAME[player.Name:lower()]
end

-- ===== 2. Banner =====
local function attachBanner(player, character)
    local role = roleFor(player)
    if not role then
        return
    end
    local head = character:WaitForChild("Head", 10)
    if not head or not character.Parent then
        return
    end
    local oldBanner = head:FindFirstChild("OwnerBanner")
    if oldBanner then
        oldBanner:Destroy()
    end

    local banner = Instance.new("BillboardGui")
    banner.Name = "OwnerBanner"
    banner.Adornee = head
    banner.Size = UDim2.fromOffset(200, 40)
    banner.StudsOffsetWorldSpace = Vector3.new(0, 3.1, 0)
    banner.AlwaysOnTop = false
    banner.MaxDistance = 100
    banner.LightInfluence = 0

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.fromScale(1, 1)
    titleLabel.Text = "[" .. role.Text .. "]"
    titleLabel.Font = Enum.Font.FredokaOne
    titleLabel.TextSize = role.Size
    titleLabel.TextColor3 = Color3.new(1, 1, 1)
    titleLabel.Parent = banner

    local outline = Instance.new("UIStroke")
    outline.Color = Color3.fromRGB(12, 7, 9)
    outline.Thickness = 2.4
    outline.LineJoinMode = Enum.LineJoinMode.Round
    outline.Parent = titleLabel

    local gradient = Instance.new("UIGradient")
    gradient.Name = "RoleShine"
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 24, 43)),
        ColorSequenceKeypoint.new(0.42, Color3.fromRGB(255, 45, 61)),
        ColorSequenceKeypoint.new(0.49, Color3.fromRGB(255, 218, 222)),
        ColorSequenceKeypoint.new(0.52, Color3.fromRGB(255, 245, 246)),
        ColorSequenceKeypoint.new(0.59, Color3.fromRGB(255, 45, 61)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(235, 24, 43)),
    })
    gradient.Rotation = 18
    gradient.Offset = Vector2.new(-1, 0)
    gradient.Parent = titleLabel
    banner.Parent = head

    task.spawn(function()
        while banner.Parent and character.Parent do
            gradient.Offset = Vector2.new(-1, 0)
            local shine = TweenService:Create(
                gradient,
                TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { Offset = Vector2.new(1, 0) }
            )
            shine:Play()
            shine.Completed:Wait()
            task.wait(2.6)
        end
    end)
end

-- ===== 3. Players =====
local function onPlayerAdded(player)
    if not roleFor(player) then
        return
    end
    player.CharacterAdded:Connect(function(character)
        task.spawn(attachBanner, player, character)
    end)
    if player.Character then
        task.spawn(attachBanner, player, player.Character)
    end
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
    onPlayerAdded(player)
end
