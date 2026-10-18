local Players=game:GetService("Players")
local OWNER_USER_ID=168774222
local function attach(player,character)
 if player.UserId~=OWNER_USER_ID then return end
 local head=character:WaitForChild("Head",10)
 if not head or not character.Parent then return end
 local old=head:FindFirstChild("OwnerBanner") if old then old:Destroy() end
 local gui=Instance.new("BillboardGui")
 gui.Name="OwnerBanner" gui.Adornee=head gui.Size=UDim2.fromOffset(150,38)
 gui.StudsOffsetWorldSpace=Vector3.new(0,3.1,0)
 gui.AlwaysOnTop=false gui.MaxDistance=100 gui.LightInfluence=0
 local frame=Instance.new("Frame") frame.Size=UDim2.fromScale(1,1)
 frame.BackgroundColor3=Color3.fromRGB(35,12,16) frame.BackgroundTransparency=1 frame.BorderSizePixel=0 frame.Parent=gui
 local corner=Instance.new("UICorner") corner.CornerRadius=UDim.new(0,10) corner.Parent=frame
 local stroke=Instance.new("UIStroke") stroke.Color=Color3.fromRGB(255,61,76) stroke.Thickness=0 stroke.Parent=frame
 local text=Instance.new("TextLabel") text.Name="Title" text.BackgroundTransparency=1
 text.Size=UDim2.fromScale(1,1) text.Text="★  OWNER  ★"
 text.Font=Enum.Font.GothamBlack text.TextSize=21 text.TextColor3=Color3.fromRGB(255,35,45)
 text.TextStrokeColor3=Color3.new(0,0,0) text.TextStrokeTransparency=0 text.Parent=frame
 local gradient=Instance.new("UIGradient")
 gradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,156,162)),ColorSequenceKeypoint.new(.5,Color3.fromRGB(235,35,55)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,156,162))})
 gradient.Rotation=90 gradient:Destroy()
 gui.Parent=head
end
local function joined(player)
 if player.UserId~=OWNER_USER_ID then return end
 player.CharacterAdded:Connect(function(character)attach(player,character)end)
 if player.Character then task.spawn(attach,player,player.Character) end
end
Players.PlayerAdded:Connect(joined)
for _,player in ipairs(Players:GetPlayers())do joined(player)end
