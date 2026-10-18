--[[ ServerScriptService.HomeAndBubbles  (Script, server)
1) Home button teleport: RemoteEvent ReplicatedStorage.GoHome (created here if missing).
   Client fires it with no args; the server replies with GoHome:FireClient(player, status) where status is
   "OK" or a message to show ("Wait a moment", "Can't go home while carrying a stolen egg!", ...).
2) Owner avatar bubble: a BillboardGui on a Terrain attachment above every claimed temple, rebuilt when
   OwnerUserId / TempleLevel change. plot.OwnerBubble (ObjectValue) points at the attachment and
   plot.OwnerBubbleId holds its full name.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local plots = workspace:WaitForChild("Plots")

---------------------------------------------------------------- home teleport
local goHomeRemote = ReplicatedStorage:FindFirstChild("GoHome") or Instance.new("RemoteEvent")
goHomeRemote.Name = "GoHome"
goHomeRemote.Parent = ReplicatedStorage
-- Known issue (docs/PROJECT_AUDIT.md, not fixed): COOLDOWN = 0 disables the cooldown, and only
-- CarryingStolenEggId blocks the teleport (a carried river egg / ragdoll does not).
local COOLDOWN = 0
local lastTeleport = {}
-- The plot this player owns, or nil.
local function plotOf(player)
    for _, plot in plots:GetChildren() do
        if plot:GetAttribute("OwnerUserId") == player.UserId then
            return plot
        end
    end
end
goHomeRemote.OnServerEvent:Connect(function(player)
    if os.clock() - (lastTeleport[player] or 0) < COOLDOWN then
        goHomeRemote:FireClient(player, "Wait a moment")
        return
    end
    if player:GetAttribute("CarryingStolenEggId") then
        goHomeRemote:FireClient(player, "Can't go home while carrying a stolen egg!")
        return
    end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local plot = plotOf(player)
    local plotSpawn = plot and plot:FindFirstChild("PlotSpawn")
    if not humanoid or humanoid.Health <= 0 or not plotSpawn then
        goHomeRemote:FireClient(player, "You don't have a temple yet")
        return
    end
    lastTeleport[player] = os.clock()
    humanoid.Sit = false
    character:PivotTo(plotSpawn.CFrame + Vector3.new(0, 4, 0))
    goHomeRemote:FireClient(player, "OK")
end)
Players.PlayerRemoving:Connect(function(player)
    lastTeleport[player] = nil
end)

---------------------------------------------------------------- avatar bubbles
local function clearBubble(plot)
    local bubbleRef = plot:FindFirstChild("OwnerBubble")
    if bubbleRef and bubbleRef:IsA("ObjectValue") and bubbleRef.Value then
        bubbleRef.Value:Destroy()
    end
    if bubbleRef then
        bubbleRef:Destroy()
    end
end
-- Billboard: avatar headshot card with an orange top strip, a small black "tail" and the owner name.
local function buildBubble(plot)
    clearBubble(plot)
    local userId = plot:GetAttribute("OwnerUserId") or 0
    if userId == 0 then
        return
    end
    local owner = Players:GetPlayerByUserId(userId)
    local anchor = plot:FindFirstChild("TempleAnchor")
    if not anchor then
        return
    end
    local temple = plot:FindFirstChild("Temple")
    local topY = anchor.Position.Y + 30
    if temple then
        local boxCFrame, size = temple:GetBoundingBox()
        topY = boxCFrame.Position.Y + size.Y / 2
    end
    local bubbleAttachment = Instance.new("Attachment")
    bubbleAttachment.Name = "OwnerBubble"
    bubbleAttachment.WorldPosition = Vector3.new(anchor.Position.X, topY + 18, anchor.Position.Z)
    bubbleAttachment.Parent = workspace.Terrain
    bubbleAttachment:SetAttribute("Plot", plot.Name)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Bubble"
    billboard.Size = UDim2.fromScale(20, 24)
    billboard.MaxDistance = 400
    billboard.MaxDistance = 260 -- overrides the line above; 260 is the effective value
    billboard.LightInfluence = 0
    billboard.Parent = bubbleAttachment
    local card = Instance.new("Frame")
    card.Size = UDim2.fromScale(1, 0.78)
    card.BackgroundColor3 = Color3.fromRGB(38, 56, 68)
    card.BorderSizePixel = 0
    card.Parent = billboard
    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Color3.new(0, 0, 0)
    cardStroke.Thickness = 4
    cardStroke.LineJoinMode = Enum.LineJoinMode.Miter
    cardStroke.Parent = card
    local strip = Instance.new("Frame")
    strip.Size = UDim2.fromScale(1, 0.06)
    strip.BackgroundColor3 = Color3.fromRGB(255, 150, 30)
    strip.BorderSizePixel = 0
    strip.ZIndex = 3
    strip.Parent = card
    local avatarImage = Instance.new("ImageLabel")
    avatarImage.BackgroundTransparency = 1
    avatarImage.Size = UDim2.fromScale(1, 1)
    avatarImage.ZIndex = 2
    avatarImage.Parent = card
    task.spawn(function()
        local ok, url = pcall(
            Players.GetUserThumbnailAsync,
            Players,
            userId,
            Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size420x420
        )
        if ok and avatarImage.Parent then
            avatarImage.Image = url
        end
    end)
    local tail = Instance.new("Frame")
    tail.AnchorPoint = Vector2.new(0.5, 0)
    tail.Position = UDim2.fromScale(0.5, 0.78)
    tail.Size = UDim2.fromScale(0.16, 0.06)
    tail.BackgroundColor3 = Color3.new(0, 0, 0)
    tail.BorderSizePixel = 0
    tail.Parent = billboard
    local nameLabel = Instance.new("TextLabel")
    nameLabel.BackgroundTransparency = 1
    nameLabel.Position = UDim2.fromScale(0, 0.84)
    nameLabel.Size = UDim2.fromScale(1, 0.16)
    nameLabel.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
    nameLabel.TextScaled = true
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.Text = owner and owner.DisplayName or (plot:GetAttribute("OwnerName") or "")
    local nameStroke = Instance.new("UIStroke")
    nameStroke.Color = Color3.new(0, 0, 0)
    nameStroke.Thickness = 3
    nameStroke.Parent = nameLabel
    nameLabel.Parent = billboard
    plot:SetAttribute("OwnerBubbleId", bubbleAttachment:GetFullName())
    -- keep a reference so we can find/remove it later
    local bubbleRef = Instance.new("ObjectValue")
    bubbleRef.Name = "OwnerBubble"
    bubbleRef.Value = bubbleAttachment
    bubbleRef.Parent = plot
end
-- Clears the bubble now and rebuilds it 1.5 s later (gives the new temple model time to appear).
local function refresh(plot)
    clearBubble(plot)
    if (plot:GetAttribute("OwnerUserId") or 0) ~= 0 then
        task.delay(1.5, function()
            if (plot:GetAttribute("OwnerUserId") or 0) ~= 0 and not plot:FindFirstChild("OwnerBubble") then
                buildBubble(plot)
            end
        end)
    end
end
local function watch(plot)
    plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
        refresh(plot)
    end)
    -- The temple height changes with its level; rebuild once the construction animation is mostly done.
    plot:GetAttributeChangedSignal("TempleLevel"):Connect(function()
        task.delay(4, function()
            refresh(plot)
        end)
    end)
    refresh(plot)
end
for _, plot in plots:GetChildren() do
    watch(plot)
end
plots.ChildAdded:Connect(watch)
