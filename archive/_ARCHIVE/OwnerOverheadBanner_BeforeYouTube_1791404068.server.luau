local Players = game:GetService("Players")
local ROLES = {
 [168774222] = "[OWNER]",
 [353101613] = "[CO-OWNER]",
}
local function attach(player, character)
 local role = ROLES[player.UserId]
 if not role then return end
 local head = character:WaitForChild("Head", 10)
 if not head or not character.Parent then return end
 local old = head:FindFirstChild("OwnerBanner")
 if old then old:Destroy() end
 local gui = Instance.new("BillboardGui")
 gui.Name = "OwnerBanner"
 gui.Adornee = head
 gui.Size = UDim2.fromOffset(180, 32)
 gui.StudsOffsetWorldSpace = Vector3.new(0, 3.1, 0)
 gui.AlwaysOnTop = false
 gui.MaxDistance = 100
 gui.LightInfluence = 0
 local text = Instance.new("TextLabel")
 text.Name = "Title"
 text.BackgroundTransparency = 1
 text.Size = UDim2.fromScale(1, 1)
 text.Text = role
 text.Font = Enum.Font.GothamBlack
 text.TextSize = 20
 text.TextColor3 = Color3.new(1, 1, 1)
 text.TextStrokeColor3 = Color3.new(0, 0, 0)
 text.TextStrokeTransparency = 0
 text.Parent = gui
 local gradient = Instance.new("UIGradient")
 gradient.Name = "RoleShine"
 gradient.Color = ColorSequence.new({
  ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 25, 42)),
  ColorSequenceKeypoint.new(.38, Color3.fromRGB(255, 52, 65)),
  ColorSequenceKeypoint.new(.48, Color3.fromRGB(255, 180, 184)),
  ColorSequenceKeypoint.new(.52, Color3.fromRGB(255, 220, 222)),
  ColorSequenceKeypoint.new(.62, Color3.fromRGB(255, 52, 65)),
  ColorSequenceKeypoint.new(1, Color3.fromRGB(235, 25, 42)),
 })
 gradient.Rotation = 15
 gradient.Offset = Vector2.new(-1, 0)
 gradient.Parent = text
 gui.Parent = head
end
local function joined(player)
 if not ROLES[player.UserId] then return end
 player.CharacterAdded:Connect(function(character) attach(player, character) end)
 if player.Character then task.spawn(attach, player, player.Character) end
end
Players.PlayerAdded:Connect(joined)
for _, player in Players:GetPlayers() do joined(player) end
