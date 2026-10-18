--[[ ServerStorage.MoneyStandBuilder  (ModuleScript)
Builds one stand from Parts at a CFrame and tags it "MoneyStand".
  local Build = require(game.ServerStorage.MoneyStandBuilder)
  local stand = Build(slotFrontCFrame, plotFolder, ownerUserId, incomePerSecond)
Origin = ground under the screen post. CharacterSlot is behind it (-Z), the plate in front (+Z, walkway).
Studs: set StudTexture to your uploaded stud albedo (rbxassetid://...), else Roblox Studs surfaces are used.
]]
local CollectionService = game:GetService("CollectionService")
local StudTexture = "" -- rbxassetid:// of your stud_cavity albedo (1 tile = 4 studs)

local C = {
	Char = Color3.fromRGB(125, 111, 99), CharL = Color3.fromRGB(147, 133, 122), CharD = Color3.fromRGB(74, 63, 55),
	Jade = Color3.fromRGB(233, 226, 200), JadeL = Color3.fromRGB(244, 239, 220), JadeD = Color3.fromRGB(201, 192, 162),
	Glow = Color3.fromRGB(255, 243, 207), Gold = Color3.fromRGB(201, 160, 106),
}

return function(origin, parent, ownerUserId, income)
	local model = Instance.new("Model")
	model.Name = "MoneyStand"
	local function part(name, color, x0, x1, y0, y1, z0, z1, o)
		o = o or {}
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
		p.CFrame = origin * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
		p.Color = color
		p.Material = o.material or Enum.Material.Plastic
        p.MaterialVariant = name == "CharacterSlot" and "Incubator One Stud Cavity 5x5" or "Incubator One Stud Cavity" -- 10-stud tile keeps studs whole on the 5x5 slot
		if o.metal then p.Material = Enum.Material.Metal; p.MaterialVariant="Incubator One Stud Cavity Metal"; p.Reflectance = 0.05 end
		if o.neon then p.Material = Enum.Material.Neon; p.MaterialVariant="" end
		if not o.neon and not o.metal then
			if StudTexture ~= "" then
				for _, f in Enum.NormalId:GetEnumItems() do
					local t = Instance.new("Texture"); t.Texture = StudTexture; t.Face = f; t.StudsPerTileU = 4; t.StudsPerTileV = 4; t.Parent = p
				end
			end
		end
		p.Parent = o.parent or model
		return p
	end
	-- slim plate frame (plate centre at Z = 3)
	part("Frame_Floor", C.Glow, -2.0625, 2.0625, 0, 0.0625, 0.9375, 5.0625, { neon = true }).Transparency = 0.35
	part("Frame_Left", C.Char, -2.5, -2.0625, 0, 0.375, 0.5, 5.5)
	part("Frame_Right", C.Char, 2.0625, 2.5, 0, 0.375, 0.5, 5.5)
	part("Frame_Front", C.Char, -2.0625, 2.0625, 0, 0.375, 5.0625, 5.5)
	part("Frame_Back", C.Char, -2.0625, 2.0625, 0, 0.375, 0.5, 0.9375)
	-- plate: ONE movable part, top 0.125 above the frame
	local plate = part("Plate", C.Jade, -2, 2, 0.05, 0.5, 1, 5)
	plate.CanCollide = true
	-- character standing slot (behind the screen post, centre Z = -4.25)
	part("Slot_FrameLeft", C.Char, -3, -2.5, 0, 0.375, -7.25, -1.25)
	part("Slot_FrameRight", C.Char, 2.5, 3, 0, 0.375, -7.25, -1.25)
	part("Slot_FrameFront", C.Char, -2.5, 2.5, 0, 0.375, -1.75, -1.25)
	part("Slot_FrameBack", C.Char, -2.5, 2.5, 0, 0.375, -7.25, -6.75)
	part("Slot_Top", C.Jade, -2.5, 2.5, 0, 0.4375, -6.75, -1.75).Name = "CharacterSlot"
	-- slim screen post
	part("Post_Foot", C.Char, -0.75, 0.75, 0, 0.25, -0.5, 0.5)
	part("Post", C.CharL, -0.25, 0.25, 0.25, 1.75, -0.25, 0.25)
	local tilt = origin * CFrame.new(0, 2.2, 0.05) * CFrame.Angles(math.rad(-32), 0, 0)
	local display = Instance.new("Part"); display.Name = "Display"; display.Anchored = true; display.Size = Vector3.new(2.75, 1.25, 0.25)
	display.CFrame = tilt * CFrame.new(0, 0, -0.125); display.Color = C.Char; display.Material = Enum.Material.SmoothPlastic; display.Parent = model
	local trim = Instance.new("Part"); trim.Name = "Display_Trim"; trim.Anchored = true; trim.Size = Vector3.new(2.75, 0.0625, 0.0625)
	trim.CFrame = tilt * CFrame.new(0, -0.594, 0.03125); trim.Color = C.Gold; trim.Material = Enum.Material.SmoothPlastic; trim.Parent = model
	local sg = Instance.new("SurfaceGui"); sg.Name = "Screen"; sg.Face = Enum.NormalId.Front; sg.PixelsPerStud = 80; sg.LightInfluence = 0; sg.Parent = display
	local bg = Instance.new("Frame"); bg.Size = UDim2.new(1, -16, 1, -16); bg.Position = UDim2.fromOffset(8, 8); bg.BackgroundColor3 = Color3.fromRGB(43, 35, 29); bg.BorderSizePixel = 0; bg.Parent = sg
	local amount = Instance.new("TextLabel"); amount.Name = "Amount"; amount.Size = UDim2.fromScale(1, 0.68); amount.BackgroundTransparency = 1
	amount.Font = Enum.Font.FredokaOne; amount.TextScaled = true; amount.Text = "$0"; amount.TextColor3 = Color3.fromRGB(255, 246, 220); amount.Parent = bg
	local as = Instance.new("UIStroke"); as.Thickness = 3; as.Color = Color3.fromRGB(20, 15, 11); as.Parent = amount
	local status = Instance.new("TextLabel"); status.Name = "Status"; status.Position = UDim2.fromScale(0, 0.7); status.Size = UDim2.fromScale(1, 0.24); status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamBold; status.TextScaled = true; status.Text = "COLLECT"; status.TextColor3 = Color3.fromRGB(242, 201, 76); status.Parent = bg

	model.PrimaryPart = plate
	model:SetAttribute("OwnerUserId", ownerUserId or 0)
	model:SetAttribute("Stored", 0)
	if income then model:SetAttribute("IncomePerSecond", income) end
	model.Parent = parent or workspace
	CollectionService:AddTag(model, "MoneyStand")
	return model
end

