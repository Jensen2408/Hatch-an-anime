--[[ ReplicatedStorage.CharacterInfo.Style  (ModuleScript)  shared look + number formatting
Required by CharacterInfoClient. Exposes the palette (Ink, Cream, Rarity, Plate, Mut, ...), the font,
number formatting (Short / Full), small instance builders (make / corner / stroke / label) and the
character nameplate card: Card(parent, dims) builds it, Apply(ui, data) fills it, Celebrate(ui, reduced)
plays the "exceptional roll" shine. Purely cosmetic; no remotes.
]]
local Style = {}
local function rgb(r, g, b)
    return Color3.fromRGB(r, g, b)
end
Style.Ink, Style.Cream, Style.CreamLow, Style.Crimson, Style.Gold, Style.Bracket =
    rgb(29, 20, 32), rgb(255, 243, 220), rgb(241, 220, 182), rgb(200, 32, 44), rgb(255, 211, 107), rgb(214, 164, 67)
Style.MoneyBg, Style.MoneyText, Style.Muted = rgb(216, 242, 207), rgb(34, 106, 46), rgb(107, 85, 96)
-- [rarity] = { background, text }
Style.Rarity = {
    Common = { rgb(138, 145, 156), Color3.new(1, 1, 1) },
    Uncommon = { rgb(63, 174, 74), Color3.new(1, 1, 1) },
    Rare = { rgb(45, 111, 214), Color3.new(1, 1, 1) },
    Epic = { rgb(138, 63, 208), Color3.new(1, 1, 1) },
    Legendary = { rgb(255, 197, 61), rgb(29, 20, 32) },
}
Style.Font = Font.new("rbxasset://fonts/families/FredokaOne.json")

---------------------------------------------------------------- number formatting
-- Largest unit first; Short() uses the first unit the value reaches.
local UNITS = { { 1e18, "Qi" }, { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
-- Compact number: 3 significant digits with a unit suffix, trailing zeros trimmed (1.50K -> "1.5K").
-- Below 1000: rounded to one decimal, shown without ".0".
function Style.Short(n)
    n = tonumber(n) or 0
    for _, unit in UNITS do
        if math.abs(n) >= unit[1] then
            local scaled = n / unit[1]
            local text = scaled < 10 and string.format("%.2f", scaled)
                or scaled < 100 and string.format("%.1f", scaled)
                or tostring(math.floor(scaled + 0.5))
            if text:find("%.") then
                text = text:gsub("0+$", ""):gsub("%.$", "")
            end
            return text .. unit[2]
        end
    end
    local rounded = math.floor(n * 10 + 0.5) / 10
    return (rounded % 1 == 0) and tostring(math.floor(rounded)) or tostring(rounded)
end
-- Whole number with thousands separators ("1,234,567"); %.4g scientific notation from 1e15 up.
function Style.Full(n)
    n = math.floor((tonumber(n) or 0) + 0.5)
    if n >= 1e15 then
        return string.format("%.4g", n)
    end
    local text = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (text:gsub("^,", ""))
end

---------------------------------------------------------------- instance builders
function Style.make(className, props, parent)
    local instance = Instance.new(className)
    for key, value in props do
        instance[key] = value
    end
    if parent then
        instance.Parent = parent
    end
    return instance
end
function Style.corner(target, radius)
    Style.make("UICorner", { CornerRadius = UDim.new(0, radius) }, target)
end
function Style.stroke(target, thickness)
    return Style.make(
        "UIStroke",
        { Color = Style.Ink, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
        target
    )
end
function Style.label(parent, text, size, color, props)
    local textLabel = Style.make("TextLabel", {
        BackgroundTransparency = 1,
        Text = text,
        TextSize = size,
        TextColor3 = color or Style.Ink,
        FontFace = Style.Font,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
    if props then
        for key, value in props do
            textLabel[key] = value
        end
    end
    return textLabel
end

-- Outlined-text label (no frame). d: { w, nameSize, rarSize, powLabel, powerSize, incSize, stroke, gap }.
-- Order: name, rarity, POWER value, $income/s. Each line is a TextLabel with a UIStroke.
Style.Power, Style.PowerGold, Style.Income, Style.White =
    rgb(255, 107, 74), rgb(255, 211, 77), rgb(125, 255, 90), Color3.new(1, 1, 1)
Style.RarityText = {
    Common = rgb(212, 217, 224),
    Uncommon = rgb(95, 227, 106),
    Rare = rgb(79, 163, 255),
    Epic = rgb(196, 107, 255),
    Legendary = rgb(255, 197, 61),
}
-- Unused (superseded by the v3 plate in Style.Card); kept for reference.
local function _outlined(parent, size, color, thickness, order)
    local textLabel = Style.make("TextLabel", {
        BackgroundTransparency = 1,
        Text = "",
        TextSize = size,
        TextColor3 = color,
        FontFace = Style.Font,
        AutomaticSize = Enum.AutomaticSize.XY,
        Size = UDim2.new(),
        LayoutOrder = order,
        ZIndex = 4,
    }, parent)
    Style.make("UIPadding", { PaddingTop = UDim.new(0, 1), PaddingBottom = UDim.new(0, 1) }, textLabel)
    Style.make(
        "UIStroke",
        { Color = Style.Ink, Thickness = thickness, LineJoinMode = Enum.LineJoinMode.Round },
        textLabel
    )
    return textLabel
end
-- Velm plate (Figma "World Nameplates v2"): rarity strip on top, studded night-purple plate, white border.
Style.Stud = "rbxassetid://132561191216691"
-- [rarity] = { gradient top, gradient bottom }
Style.Plate = {
    Common = { rgb(150, 156, 172), rgb(64, 70, 86) },
    Uncommon = { rgb(67, 220, 78), rgb(11, 122, 27) },
    Rare = { rgb(59, 120, 255), rgb(11, 42, 156) },
    Epic = { rgb(168, 102, 255), rgb(74, 21, 166) },
    Legendary = { rgb(255, 214, 72), rgb(214, 132, 0) },
    Mythic = { rgb(255, 74, 74), rgb(150, 0, 20) },
    Secret = { rgb(40, 40, 48), rgb(0, 0, 0) },
}
-- Mutation badge colours.
Style.Mut = {
    Silver = rgb(220, 228, 240),
    Gold = rgb(255, 214, 72),
    Diamond = rgb(120, 230, 255),
    Rainbow = rgb(255, 120, 200),
}
local function verticalGradient(target, topColor, bottomColor)
    return Style.make("UIGradient", { Rotation = 90, Color = ColorSequence.new(topColor, bottomColor) }, target)
end
local function studs(target, transparency)
    return Style.make("ImageLabel", {
        Name = "Studs",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = Style.Stud,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(18, 18),
        ImageTransparency = transparency or 0.55,
        ZIndex = target.ZIndex,
    }, target)
end
local function text(parent, size, color, thickness, props)
    local textLabel = Style.make("TextLabel", {
        BackgroundTransparency = 1,
        Text = "",
        TextSize = size,
        TextColor3 = color,
        FontFace = Style.Font,
        ZIndex = 5,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
    Style.make(
        "UIStroke",
        { Color = Style.Ink, Thickness = thickness, LineJoinMode = Enum.LineJoinMode.Round },
        textLabel
    )
    if props then
        for key, value in props do
            textLabel[key] = value
        end
    end
    return textLabel
end

---------------------------------------------------------------- nameplate card
-- dims: { nameSize, rarSize?, powerSize, incSize, stroke? } (sizes in px). Returns the handles Apply/Celebrate use;
-- the returned field names (root, card, name, badge, strip, mut, power, pgrad, income, spark, sparkScale) are a contract.
function Style.Card(parent, dims)
    -- v3 plate: whole plate in the rarity colour, rarity tag on top, big name, stats in a dark inset bar
    local root =
        Style.make("Frame", { Name = "Card", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, parent)
    local shadow = Style.make("Frame", {
        Name = "Shadow",
        BackgroundColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(6, 20),
        Size = UDim2.new(1, -12, 1, -22),
        ZIndex = 1,
    }, root)
    Style.corner(shadow, 12)
    local plate = Style.make("Frame", {
        Name = "Plate",
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(6, 14),
        Size = UDim2.new(1, -12, 1, -22),
        ZIndex = 2,
        ClipsDescendants = true,
    }, root)
    Style.corner(plate, 12)
    local stripGradient = verticalGradient(plate, Style.Plate.Common[1], Style.Plate.Common[2])
    studs(plate, 0.5)
    Style.make(
        "UIStroke",
        { Color = Color3.new(1, 1, 1), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
        plate
    )
    local gloss = Style.make("Frame", {
        Name = "Gloss",
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.82,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(8, 5),
        Size = UDim2.new(1, -16, 0, 5),
        ZIndex = 3,
    }, plate)
    Style.corner(gloss, 3)
    -- rarity tag sitting on the top edge
    local rarityTag = Style.make("Frame", {
        Name = "RarityTag",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 2),
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 22),
        BackgroundColor3 = Style.Ink,
        BorderSizePixel = 0,
        ZIndex = 6,
    }, root)
    Style.corner(rarityTag, 7)
    Style.make(
        "UIStroke",
        { Color = Color3.new(1, 1, 1), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
        rarityTag
    )
    Style.make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, rarityTag)
    local badge = Style.make("TextLabel", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        Text = "",
        TextSize = dims.rarSize or 13,
        TextColor3 = Color3.new(1, 1, 1),
        FontFace = Style.Font,
        ZIndex = 7,
    }, rarityTag)
    local name = text(
        plate,
        dims.nameSize + 2,
        Color3.new(1, 1, 1),
        (dims.stroke or 2.5) + 0.5,
        { Position = UDim2.fromOffset(6, 16), Size = UDim2.new(1, -12, 0, dims.nameSize + 8) }
    )
    local statsBar = Style.make("Frame", {
        Name = "Stats",
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundColor3 = Style.Ink,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, 0, 1, -7),
        Size = UDim2.new(1, -18, 0, dims.powerSize + 10),
        ZIndex = 3,
    }, plate)
    Style.corner(statsBar, 8)
    local statsRow =
        Style.make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, statsBar)
    Style.make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 14),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, statsRow)
    local power = text(
        statsRow,
        dims.powerSize,
        Style.Power,
        dims.stroke or 2.5,
        { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 1 }
    )
    -- Gold text with a white highlight band; disabled until an exceptional roll, swept by Celebrate().
    local powerGradient = Style.make("UIGradient", {
        Enabled = false,
        Rotation = 20,
        Offset = Vector2.new(-1.3, 0),
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Style.PowerGold),
            ColorSequenceKeypoint.new(0.45, Style.PowerGold),
            ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.55, Style.PowerGold),
            ColorSequenceKeypoint.new(1, Style.PowerGold),
        }),
    }, power)
    local income = text(
        statsRow,
        dims.incSize + 2,
        Style.Income,
        dims.stroke or 2.5,
        { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2 }
    )
    -- mutation badge in the top-right corner
    local mutationBadge = Style.make("TextLabel", {
        Name = "Mutation",
        Visible = false,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -2, 0, 4),
        Rotation = 6,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 18),
        BackgroundColor3 = Style.Mut.Gold,
        Text = "",
        TextSize = 12,
        TextColor3 = Style.Ink,
        FontFace = Style.Font,
        ZIndex = 8,
    }, root)
    Style.corner(mutationBadge, 6)
    Style.make(
        "UIStroke",
        { Color = Style.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
        mutationBadge
    )
    Style.make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, mutationBadge)
    -- Four-point sparkle (two crossed bars), parented to the card's parent so it can sit outside the plate.
    local spark = Style.make("Frame", {
        Size = UDim2.fromOffset(14, 14),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 10,
    }, parent)
    local sparkScale = Style.make("UIScale", { Scale = 0 }, spark)
    for _, barSize in { UDim2.new(0, 3, 1, 0), UDim2.new(1, 0, 0, 3) } do
        local sparkBar = Style.make("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = barSize,
            BackgroundColor3 = Color3.fromRGB(255, 246, 200),
            BorderSizePixel = 0,
            ZIndex = 10,
        }, spark)
        Style.corner(sparkBar, 2)
        Style.stroke(sparkBar, 1.5)
    end
    return {
        root = root,
        card = plate,
        name = name,
        badge = badge,
        strip = stripGradient,
        mut = mutationBadge,
        power = power,
        pgrad = powerGradient,
        income = income,
        spark = spark,
        sparkScale = sparkScale,
    }
end
-- data: { name, rarity, mutation?, power, income, exceptional? }
function Style.Apply(ui, data)
    ui.name.Text = data.name
    local plateColors = Style.Plate[data.rarity] or Style.Plate.Common
    ui.strip.Color = ColorSequence.new(plateColors[1], plateColors[2])
    ui.badge.Text = string.upper(data.rarity)
    local rarityTag = ui.badge.Parent
    if rarityTag and rarityTag:IsA("Frame") then
        rarityTag.BackgroundColor3 = (Style.Plate[data.rarity] or Style.Plate.Common)[2]
    end
    ui.mut.Visible = data.mutation ~= nil
    if data.mutation then
        ui.mut.Text = "✦ " .. string.upper(data.mutation)
        ui.mut.BackgroundColor3 = Style.Mut[data.mutation] or Style.Mut.Gold
    end
    ui.power.Text = "⚡ " .. Style.Short(data.power)
    ui.power.TextColor3 = data.exceptional and Color3.new(1, 1, 1) or Style.Power
    ui.pgrad.Enabled = data.exceptional == true
    ui.income.Text = "$" .. Style.Short(data.income) .. "/s"
end

-- exceptional roll: one diagonal shine through the gold Power text + one sparkle
function Style.Celebrate(ui, reduced)
    if reduced then
        return
    end
    local TweenService = game:GetService("TweenService")
    ui.pgrad.Offset = Vector2.new(-1.3, 0)
    task.delay(0.35, function()
        TweenService:Create(
            ui.pgrad,
            TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
            { Offset = Vector2.new(1.3, 0) }
        ):Play()
    end)
    task.delay(0.7, function()
        -- Place the sparkle just right of the Power text, in the spark parent's coordinate space.
        local offset = ui.power.AbsolutePosition - ui.spark.Parent.AbsolutePosition
        ui.spark.Position = UDim2.fromOffset(offset.X + ui.power.AbsoluteSize.X + 6, offset.Y + 4)
        ui.spark.Visible = true
        ui.spark.Rotation = 0
        TweenService:Create(ui.sparkScale, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Scale = 1 }):Play()
        TweenService:Create(ui.spark, TweenInfo.new(0.5), { Rotation = 90 }):Play()
        task.delay(0.25, function()
            local shrinkTween = TweenService:Create(ui.sparkScale, TweenInfo.new(0.22), { Scale = 0 })
            shrinkTween.Completed:Once(function()
                ui.spark.Visible = false
            end)
            shrinkTween:Play()
        end)
    end)
end

return Style
