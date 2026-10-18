-- ServerScriptService.OwnerOverheadBanner
-- Verified account usernames are used, never DisplayName.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ROLES = {
 [168774222] = {Text = "OWNER", Size = 25},
 [353101613] = {Text = "CO-OWNER", Size = 21},
 [10192461618] = {Text = "YOUTUBE", Size = 21},
}
local USERNAME_ROLES = {
 rofloxreal = {Text = "YOUTUBE", Size = 21},
}

local function roleFor(player)
 return ROLES[player.UserId] or USERNAME_ROLES[player.Name:lower()]
end

local function attach(player, character)
 local role = roleFor(player)
 if not role then return end
 local head = character:WaitForChild("Head", 10)
 if not head or not character.Parent then return end
 local old = head:FindFirstChild("OwnerBanner")
 if old then old:Destroy() end

 local gui = Instance.new("BillboardGui")
 gui.Name = "OwnerBanner"
 gui.Adornee = head
 gui.Size = UDim2.fromOffset(200, 40)
 gui.StudsOffsetWorldSpace = Vector3.new(0, 3.1, 0)
 gui.AlwaysOnTop = false
 gui.MaxDistance = 100
 gui.LightInfluence = 0

 local text = Instance.new("TextLabel")
 text.Name = "Title"
 text.BackgroundTransparency = 1
 text.Size = UDim2.fromScale(1, 1)
 text.Text = "[" .. role.Text .. "]"
 text.Font = Enum.Font.FredokaOne
 text.TextSize = role.Size
 text.TextColor3 = Color3.new(1, 1, 1)
 text.Parent = gui

 local outline = Instance.new("UIStroke")
 outline.Color = Color3.fromRGB(12, 7, 9)
 outline.Thickness = 2.4
 outline.LineJoinMode = Enum.LineJoinMode.Round
 outline.Parent = text

 local gradient = Instance.new("UIGradient")
 gradient.Name = "RoleShine"
 gradient.Color = ColorSequence.new({
  ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 24, 43)),
  ColorSequenceKeypoint.new(.42, Color3.fromRGB(255, 45, 61)),
  ColorSequenceKeypoint.new(.49, Color3.fromRGB(255, 218, 222)),
  ColorSequenceKeypoint.new(.52, Color3.fromRGB(255, 245, 246)),
  ColorSequenceKeypoint.new(.59, Color3.fromRGB(255, 45, 61)),
  ColorSequenceKeypoint.new(1, Color3.fromRGB(235, 24, 43)),
 })
 gradient.Rotation = 18
 gradient.Offset = Vector2.new(-1, 0)
 gradient.Parent = text
 gui.Parent = head

 task.spawn(function()
  while gui.Parent and character.Parent do
   gradient.Offset = Vector2.new(-1, 0)
   local shine = TweenService:Create(gradient,
    TweenInfo.new(.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
    {Offset = Vector2.new(1, 0)})
   shine:Play()
   shine.Completed:Wait()
   task.wait(2.6)
  end
 end)
end

local function joined(player)
 if not roleFor(player) then return end
 player.CharacterAdded:Connect(function(character)
  task.spawn(attach, player, character)
 end)
 if player.Character then task.spawn(attach, player, player.Character) end
end
Players.PlayerAdded:Connect(joined)
for _,player in Players:GetPlayers() do joined(player) end
