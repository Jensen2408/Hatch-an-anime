--[[ ServerStorage.MoneyStandBuilder  (ModuleScript)
Builds one stand from Parts at a CFrame and tags it "MoneyStand".
  local Build = require(game.ServerStorage.MoneyStandBuilder)
  local stand = Build(slotFrontCFrame, plotFolder, ownerUserId, incomePerSecond)
Origin = ground under the screen post. CharacterSlot is behind it (-Z), the plate in front (+Z, walkway).
Studs: set STUD_TEXTURE to your uploaded stud albedo (rbxassetid://...), else Roblox Studs surfaces are used.
The instance names (Plate, Display > Screen > Amount / Status, CharacterSlot) and the attributes OwnerUserId / Stored /
IncomePerSecond are read by MoneyStandServer and MoneyStandClient.
Note: no active script in src/ requires this builder at the moment (stands are cloned from
ServerStorage.MoneyStandPlotTemplates by MoneyStandOwnership).
]]
local CollectionService = game:GetService("CollectionService")
local STUD_TEXTURE = "" -- rbxassetid:// of your stud_cavity albedo (1 tile = 4 studs)

local COLORS = {
    Char = Color3.fromRGB(125, 111, 99),
    CharL = Color3.fromRGB(147, 133, 122),
    CharD = Color3.fromRGB(74, 63, 55),
    Jade = Color3.fromRGB(233, 226, 200),
    JadeL = Color3.fromRGB(244, 239, 220),
    JadeD = Color3.fromRGB(201, 192, 162),
    Glow = Color3.fromRGB(255, 243, 207),
    Gold = Color3.fromRGB(201, 160, 106),
}

return function(origin, parent, ownerUserId, incomePerSecond)
    local model = Instance.new("Model")
    model.Name = "MoneyStand"
    -- Axis-aligned box from min/max corners in origin space. options: { material, metal, neon, parent }
    local function makePart(name, color, x0, x1, y0, y1, z0, z1, options)
        options = options or {}
        local newPart = Instance.new("Part")
        newPart.Name = name
        newPart.Anchored = true
        newPart.Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
        newPart.CFrame = origin * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
        newPart.Color = color
        newPart.Material = options.material or Enum.Material.Plastic
        newPart.MaterialVariant = name == "CharacterSlot" and "Incubator One Stud Cavity 5x5"
            or "Incubator One Stud Cavity" -- 10-stud tile keeps studs whole on the 5x5 slot
        if options.metal then
            newPart.Material = Enum.Material.Metal
            newPart.MaterialVariant = "Incubator One Stud Cavity Metal"
            newPart.Reflectance = 0.05
        end
        if options.neon then
            newPart.Material = Enum.Material.Neon
            newPart.MaterialVariant = ""
        end
        if not options.neon and not options.metal then
            if STUD_TEXTURE ~= "" then
                for _, face in Enum.NormalId:GetEnumItems() do
                    local texture = Instance.new("Texture")
                    texture.Texture = STUD_TEXTURE
                    texture.Face = face
                    texture.StudsPerTileU = 4
                    texture.StudsPerTileV = 4
                    texture.Parent = newPart
                end
            end
        end
        newPart.Parent = options.parent or model
        return newPart
    end
    -- slim plate frame (plate centre at Z = 3)
    makePart("Frame_Floor", COLORS.Glow, -2.0625, 2.0625, 0, 0.0625, 0.9375, 5.0625, { neon = true }).Transparency =
        0.35
    makePart("Frame_Left", COLORS.Char, -2.5, -2.0625, 0, 0.375, 0.5, 5.5)
    makePart("Frame_Right", COLORS.Char, 2.0625, 2.5, 0, 0.375, 0.5, 5.5)
    makePart("Frame_Front", COLORS.Char, -2.0625, 2.0625, 0, 0.375, 5.0625, 5.5)
    makePart("Frame_Back", COLORS.Char, -2.0625, 2.0625, 0, 0.375, 0.5, 0.9375)
    -- plate: ONE movable part, top 0.125 above the frame
    local plate = makePart("Plate", COLORS.Jade, -2, 2, 0.05, 0.5, 1, 5)
    plate.CanCollide = true
    -- character standing slot (behind the screen post, centre Z = -4.25)
    makePart("Slot_FrameLeft", COLORS.Char, -3, -2.5, 0, 0.375, -7.25, -1.25)
    makePart("Slot_FrameRight", COLORS.Char, 2.5, 3, 0, 0.375, -7.25, -1.25)
    makePart("Slot_FrameFront", COLORS.Char, -2.5, 2.5, 0, 0.375, -1.75, -1.25)
    makePart("Slot_FrameBack", COLORS.Char, -2.5, 2.5, 0, 0.375, -7.25, -6.75)
    makePart("Slot_Top", COLORS.Jade, -2.5, 2.5, 0, 0.4375, -6.75, -1.75).Name = "CharacterSlot"
    -- slim screen post
    makePart("Post_Foot", COLORS.Char, -0.75, 0.75, 0, 0.25, -0.5, 0.5)
    makePart("Post", COLORS.CharL, -0.25, 0.25, 0.25, 1.75, -0.25, 0.25)
    local tilt = origin * CFrame.new(0, 2.2, 0.05) * CFrame.Angles(math.rad(-32), 0, 0)
    local display = Instance.new("Part")
    display.Name = "Display"
    display.Anchored = true
    display.Size = Vector3.new(2.75, 1.25, 0.25)
    display.CFrame = tilt * CFrame.new(0, 0, -0.125)
    display.Color = COLORS.Char
    display.Material = Enum.Material.SmoothPlastic
    display.Parent = model
    local trim = Instance.new("Part")
    trim.Name = "Display_Trim"
    trim.Anchored = true
    trim.Size = Vector3.new(2.75, 0.0625, 0.0625)
    trim.CFrame = tilt * CFrame.new(0, -0.594, 0.03125)
    trim.Color = COLORS.Gold
    trim.Material = Enum.Material.SmoothPlastic
    trim.Parent = model
    local screenGui = Instance.new("SurfaceGui")
    screenGui.Name = "Screen"
    screenGui.Face = Enum.NormalId.Front
    screenGui.PixelsPerStud = 80
    screenGui.LightInfluence = 0
    screenGui.Parent = display
    local background = Instance.new("Frame")
    background.Size = UDim2.new(1, -16, 1, -16)
    background.Position = UDim2.fromOffset(8, 8)
    background.BackgroundColor3 = Color3.fromRGB(43, 35, 29)
    background.BorderSizePixel = 0
    background.Parent = screenGui
    local amount = Instance.new("TextLabel")
    amount.Name = "Amount"
    amount.Size = UDim2.fromScale(1, 0.68)
    amount.BackgroundTransparency = 1
    amount.Font = Enum.Font.FredokaOne
    amount.TextScaled = true
    amount.Text = "$0"
    amount.TextColor3 = Color3.fromRGB(255, 246, 220)
    amount.Parent = background
    local amountStroke = Instance.new("UIStroke")
    amountStroke.Thickness = 3
    amountStroke.Color = Color3.fromRGB(20, 15, 11)
    amountStroke.Parent = amount
    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.Position = UDim2.fromScale(0, 0.7)
    status.Size = UDim2.fromScale(1, 0.24)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.GothamBold
    status.TextScaled = true
    status.Text = "COLLECT"
    status.TextColor3 = Color3.fromRGB(242, 201, 76)
    status.Parent = background

    model.PrimaryPart = plate
    model:SetAttribute("OwnerUserId", ownerUserId or 0)
    model:SetAttribute("Stored", 0)
    if incomePerSecond then
        model:SetAttribute("IncomePerSecond", incomePerSecond)
    end
    model.Parent = parent or workspace
    CollectionService:AddTag(model, "MoneyStand")
    return model
end
