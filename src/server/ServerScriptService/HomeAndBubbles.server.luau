-- HomeAndBubbles: Home button teleport (RemoteEvent RS.GoHome) + owner avatar bubble above every claimed temple.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local plots = workspace:WaitForChild("Plots")

---------------------------------------------------------------- home teleport
local remote = RS:FindFirstChild("GoHome") or Instance.new("RemoteEvent") remote.Name = "GoHome" remote.Parent = RS
local COOLDOWN = 0
local last = {}
local function plotOf(p) for _, plot in plots:GetChildren() do if plot:GetAttribute("OwnerUserId") == p.UserId then return plot end end end
remote.OnServerEvent:Connect(function(p)
	if os.clock() - (last[p] or 0) < COOLDOWN then remote:FireClient(p, "Wait a moment") return end
	if p:GetAttribute("CarryingStolenEggId") then remote:FireClient(p, "Can't go home while carrying a stolen egg!") return end
	local char = p.Character local hum = char and char:FindFirstChildOfClass("Humanoid")
	local plot = plotOf(p) local spawn = plot and plot:FindFirstChild("PlotSpawn")
	if not hum or hum.Health <= 0 or not spawn then remote:FireClient(p, "You don't have a temple yet") return end
	last[p] = os.clock()
	hum.Sit = false
	char:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
	remote:FireClient(p, "OK")
end)
Players.PlayerRemoving:Connect(function(p) last[p] = nil end)

---------------------------------------------------------------- avatar bubbles
local function clearBubble(plot) local ref = plot:FindFirstChild("OwnerBubble") if ref and ref:IsA("ObjectValue") and ref.Value then ref.Value:Destroy() end if ref then ref:Destroy() end end
local function buildBubble(plot)
	clearBubble(plot)
	local userId = plot:GetAttribute("OwnerUserId") or 0
	if userId == 0 then return end
	local owner = Players:GetPlayerByUserId(userId)
	local anchor = plot:FindFirstChild("TempleAnchor")
	if not anchor then return end
	local temple = plot:FindFirstChild("Temple")
	local top = anchor.Position.Y + 30
	if temple then local cf, size = temple:GetBoundingBox() top = cf.Position.Y + size.Y / 2 end
	local att = Instance.new("Attachment") att.Name = "OwnerBubble" att.WorldPosition = Vector3.new(anchor.Position.X, top + 18, anchor.Position.Z) att.Parent = workspace.Terrain
	att:SetAttribute("Plot", plot.Name)
	local bb = Instance.new("BillboardGui") bb.Name = "Bubble" bb.Size = UDim2.fromScale(20, 24) bb.MaxDistance = 400 bb.MaxDistance = 260 bb.LightInfluence = 0 bb.Parent = att
	local card = Instance.new("Frame") card.Size = UDim2.fromScale(1, 0.78) card.BackgroundColor3 = Color3.fromRGB(38, 56, 68) card.BorderSizePixel = 0 card.Parent = bb
	local st = Instance.new("UIStroke") st.Color = Color3.new(0, 0, 0) st.Thickness = 4 st.LineJoinMode = Enum.LineJoinMode.Miter st.Parent = card
	local strip = Instance.new("Frame") strip.Size = UDim2.fromScale(1, 0.06) strip.BackgroundColor3 = Color3.fromRGB(255, 150, 30) strip.BorderSizePixel = 0 strip.ZIndex = 3 strip.Parent = card
	local img = Instance.new("ImageLabel") img.BackgroundTransparency = 1 img.Size = UDim2.fromScale(1, 1) img.ZIndex = 2 img.Parent = card
	task.spawn(function() local ok, url = pcall(Players.GetUserThumbnailAsync, Players, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420) if ok and img.Parent then img.Image = url end end)
	local tail = Instance.new("Frame") tail.AnchorPoint = Vector2.new(0.5, 0) tail.Position = UDim2.fromScale(0.5, 0.78) tail.Size = UDim2.fromScale(0.16, 0.06) tail.BackgroundColor3 = Color3.new(0, 0, 0) tail.BorderSizePixel = 0 tail.Parent = bb
	local name = Instance.new("TextLabel") name.BackgroundTransparency = 1 name.Position = UDim2.fromScale(0, 0.84) name.Size = UDim2.fromScale(1, 0.16)
	name.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json") name.TextScaled = true name.TextColor3 = Color3.new(1, 1, 1)
	name.Text = owner and owner.DisplayName or (plot:GetAttribute("OwnerName") or "")
	local ns = Instance.new("UIStroke") ns.Color = Color3.new(0, 0, 0) ns.Thickness = 3 ns.Parent = name
	name.Parent = bb
	plot:SetAttribute("OwnerBubbleId", att:GetFullName())
	-- keep a reference so we can find/remove it later
	local ref = Instance.new("ObjectValue") ref.Name = "OwnerBubble" ref.Value = att ref.Parent = plot
end
local function refresh(plot)
	local ref = plot:FindFirstChild("OwnerBubble")
	if ref and ref:IsA("ObjectValue") and ref.Value then ref.Value:Destroy() end
	if ref then ref:Destroy() end
	if (plot:GetAttribute("OwnerUserId") or 0) ~= 0 then task.delay(1.5, function() if (plot:GetAttribute("OwnerUserId") or 0) ~= 0 and not plot:FindFirstChild("OwnerBubble") then buildBubble(plot) end end) end
end
local function watch(plot)
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function() refresh(plot) end)
	plot:GetAttributeChangedSignal("TempleLevel"):Connect(function() task.delay(4, function() refresh(plot) end) end)
	refresh(plot)
end
for _, plot in plots:GetChildren() do watch(plot) end
plots.ChildAdded:Connect(watch)
