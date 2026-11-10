-- LeaveEarningsOverlay (LocalScript, colour backdrop look 2026-11-10; before that Folk Stud 2026-11-08; old look: ServerStorage._ARCHIVE.LeaveEarningsOverlay_BeforeStud_2026-11-08): when the Roblox menu (Esc) opens, show behind it that the temple keeps earning offline.
-- Offline rate matches PlayerDataService: half of live income, for up to 8 hours.
-- Display only (estimate from the local player's PlacedItems IncomePerSecond x OwnerIncomeMultiplier); no remotes.
-- If PlayerDataService's offline rate / cap change, OFFLINE_RATE / OFFLINE_CAP here must be updated by hand.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local OFFLINE_RATE, OFFLINE_CAP = 0.5, 8 * 3600
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
local GLOW_IMAGE = "rbxthumb://type=Asset&id=85372533044428&w=420&h=420"
local RAYS_IMAGE = "rbxthumb://type=Asset&id=110993746998606&w=420&h=420"
local SPARK_IMAGE = "rbxthumb://type=Asset&id=87376394612367&w=420&h=420"
local COINS_IMAGE = "rbxassetid://125162321561970"
local function create(className, props, parent)
    local instance = Instance.new(className)
    for key, value in props do
        instance[key] = value
    end
    instance.Parent = parent
    return instance
end
local UNITS = { { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
local function formatShortCash(value)
    value = tonumber(value) or 0
    for _, unit in UNITS do
        if value >= unit[1] then
            local scaled = value / unit[1]
            local text = scaled < 10 and string.format("%.2f", scaled)
                or scaled < 100 and string.format("%.1f", scaled)
                or tostring(math.floor(scaled + 0.5))
            -- trim decimals only ("5.50" -> "5.5"); whole numbers keep their zeros ("540" stays "540")
            if text:find("%.") then
                text = text:gsub("0+$", ""):gsub("%.$", "")
            end
            return "$" .. text .. unit[2]
        end
    end
    return "$" .. tostring(math.floor(value))
end
local function getIncomePerSecond()
    local total = 0
    local plots = workspace:FindFirstChild("Plots")
    if plots then
        for _, plot in plots:GetChildren() do
            if plot:GetAttribute("OwnerUserId") == player.UserId then
                local placedItems = plot:FindFirstChild("PlacedItems")
                if placedItems then
                    for _, item in placedItems:GetChildren() do
                        total += item:GetAttribute("IncomePerSecond") or 0
                    end
                end
            end
        end
    end
    return total
        * (workspace:GetAttribute("OwnerIncomeMultiplier") or 1)
        * (workspace:GetAttribute("AbuseCashMultiplier") or 1)
        * (workspace:GetAttribute("BoostCashMultiplier") or 1)
end

---------------------------------------------------------------- the screen (2026-11-10, no stud plate)
-- A full-screen colour backdrop (violet > blue > teal, slowly drifting) with soft glow blobs, spinning rays and a
-- gold glows behind the two text columns.
local GOLD_A, GOLD_B = Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 168, 0)

local screenGui = create(
    "ScreenGui",
    { Name = "LeaveEarningsOverlay", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling },
    player:WaitForChild("PlayerGui")
)
local backdrop = create("CanvasGroup", { Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, GroupTransparency = 1, ZIndex = 0 }, screenGui)
-- the gradient sits on its own frame: on the CanvasGroup it would tint the glow and the coins too
local sweepFrame = create("Frame", { Name = "Sweep", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 0 }, backdrop)
local sweep = create("UIGradient", {
    Rotation = 35,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(124, 40, 255)),
        ColorSequenceKeypoint.new(0.35, Color3.fromRGB(64, 84, 255)),
        ColorSequenceKeypoint.new(0.7, Color3.fromRGB(0, 170, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 224, 190)),
    }),
}, sweepFrame)
local blobs = {}
for i, spec in
    {
        { 0.12, 0.25, 0.75, Color3.fromRGB(255, 70, 200) },
        { 0.88, 0.2, 0.7, Color3.fromRGB(0, 255, 230) },
        { 0.2, 0.9, 0.8, Color3.fromRGB(60, 120, 255) },
        { 0.85, 0.85, 0.85, Color3.fromRGB(190, 70, 255) },
    }
do
    local blob = create("ImageLabel", {
        Name = "Blob" .. i,
        BackgroundTransparency = 1,
        Image = GLOW_IMAGE,
        ImageColor3 = spec[4],
        ImageTransparency = 0.35,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(spec[1], spec[2]),
        Size = UDim2.fromScale(spec[3], spec[3]),
        SizeConstraint = Enum.SizeConstraint.RelativeXX,
        ZIndex = 1,
    }, backdrop)
    blobs[i] = { gui = blob, x = spec[1], y = spec[2], phase = i * 1.7 }
end
local rays = create("ImageLabel", {
    Name = "Rays",
    BackgroundTransparency = 1,
    Image = RAYS_IMAGE,
    ImageColor3 = Color3.fromRGB(255, 236, 150),
    ImageTransparency = 0.78,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromScale(1.5, 1.5),
    SizeConstraint = Enum.SizeConstraint.RelativeXX,
    ZIndex = 2,
}, backdrop)
-- darker edges so the middle (the Roblox menu) and the headline stay the focus
local shade = create("Frame", { Name = "Shade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 6, 48), BorderSizePixel = 0, ZIndex = 3 }, backdrop)
create("UIGradient", {
    Rotation = 90,
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.75),
        NumberSequenceKeypoint.new(0.3, 1),
        NumberSequenceKeypoint.new(0.6, 0.85),
        NumberSequenceKeypoint.new(1, 0.25),
    }),
}, shade)
local rain = create("Frame", { Name = "Rain", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 4 }, backdrop)

-- The Roblox menu covers the middle of the screen (about 22%..78% across, 9%..94% down), so nothing readable may
-- sit there. The message lives in the two side strips, plus one short line in the thin band above the menu.
local COL_W, COL_H = 300, 380
local function strokeOn(textLabel, thickness)
    create("UIStroke", { Color = Color3.fromRGB(20, 8, 60), Thickness = thickness, LineJoinMode = Enum.LineJoinMode.Bevel }, textLabel)
end
local columns = {}
local function column(name, xScale)
    local root = create("Frame", { Name = name, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(xScale, 0.5), Size = UDim2.fromOffset(COL_W, COL_H), ZIndex = 5 }, screenGui)
    local fit = create("UIScale", { Name = "Fit" }, root)
    local stage = create("Frame", { Name = "Stage", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, root)
    local pop = create("UIScale", { Name = "Pop", Scale = 0.6 }, stage)
    create("ImageLabel", { Name = "Glow", BackgroundTransparency = 1, Image = GLOW_IMAGE, ImageColor3 = Color3.fromRGB(255, 200, 40), ImageTransparency = 0.35, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(COL_W * 1.9, COL_W * 1.9), ZIndex = 4 }, stage)
    table.insert(columns, { fit = fit, pop = pop })
    return stage
end
local function label(parent, name, text, y, height, size, color, stroke)
    local textLabel = create("TextLabel", {
        Name = name,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, y),
        Size = UDim2.fromOffset(COL_W, height),
        FontFace = FONT,
        Text = text,
        TextSize = size,
        TextWrapped = true,
        TextColor3 = color,
        ZIndex = 6,
    }, parent)
    strokeOn(textLabel, stroke)
    return textLabel
end
local MINT = Color3.fromRGB(150, 255, 214)
local left = column("Left", 0.11)
local leftTop = label(left, "Top", "YOUR TEMPLE EARNS", 20, 80, 34, WHITE, 3.7)
local amountLabel = label(left, "Amount", "$0", 110, 130, 110, WHITE, 6)
amountLabel.TextWrapped = false
amountLabel.TextScaled = true
create("UITextSizeConstraint", { MaxTextSize = 110, MinTextSize = 30 }, amountLabel)
create("UIGradient", { Rotation = 90, Color = ColorSequence.new(GOLD_A, GOLD_B) }, amountLabel)
local dayLabel = label(left, "Day", "A DAY OFFLINE", 250, 90, 38, WHITE, 3.7)
local right = column("Right", 0.89)
local rightTop = label(right, "Top", "WHILE YOU'RE AWAY", 20, 80, 34, WHITE, 3.7)
local rateLabel = label(right, "Rate", "$0/s", 115, 90, 70, MINT, 5)
rateLabel.TextWrapped = false
rateLabel.TextScaled = true
create("UITextSizeConstraint", { MaxTextSize = 70, MinTextSize = 24 }, rateLabel)
local tipLabel = label(right, "Tip", "FILLS UP OVER 8 HOURS, COME BACK TO COLLECT!", 215, 130, 28, WHITE, 3.2)
-- the one-liner above the menu
local topLine = create("TextLabel", {
    Name = "TopLine",
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0, 30),
    Size = UDim2.new(0.6, 0, 0, 34),
    FontFace = FONT,
    Text = "",
    TextScaled = true,
    TextColor3 = WHITE,
    TextTransparency = 1,
    ZIndex = 6,
}, screenGui)
create("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 12 }, topLine)
local topStroke = create("UIStroke", { Color = Color3.fromRGB(20, 8, 60), Thickness = 3, LineJoinMode = Enum.LineJoinMode.Bevel, Transparency = 1 }, topLine)

local isOpen, renderConnection = false, nil
local function spawnFallingCoin()
    local size = math.random(26, 52)
    local coinLabel = create("ImageLabel", {
        BackgroundTransparency = 1,
        Image = COINS_IMAGE,
        ImageTransparency = 0.15,
        ScaleType = Enum.ScaleType.Fit,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(math.random(), 0, 0, -60),
        Size = UDim2.fromOffset(size, size),
        Rotation = math.random(-40, 40),
        ZIndex = 4,
    }, rain)
    local duration = 3.5 + math.random() * 2.5
    TweenService:Create(coinLabel, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        Position = coinLabel.Position + UDim2.new((math.random() - 0.5) * 0.1, 0, 1.15, 0),
        Rotation = coinLabel.Rotation + math.random(-180, 180),
    }):Play()
    task.delay(duration, function()
        coinLabel:Destroy()
    end)
end
local function showOverlay()
    if isOpen then
        return
    end
    isOpen = true
    local rate = getIncomePerSecond() * OFFLINE_RATE
    -- a full day away pays out the cap (8 hours of offline income), so that is the honest "per day" number
    local perDay = rate * math.min(86400, OFFLINE_CAP)
    if rate > 0 then
        leftTop.Text = "YOUR TEMPLE EARNS"
        amountLabel.Text = formatShortCash(perDay)
        dayLabel.Text = "A DAY OFFLINE"
        rightTop.Text = "WHILE YOU'RE AWAY"
        rateLabel.Text = formatShortCash(rate) .. "/s"
        tipLabel.Text = "FILLS UP OVER 8 HOURS, COME BACK TO COLLECT!"
        topLine.Text = "YOUR TEMPLE EARNS " .. formatShortCash(perDay) .. " A DAY OFFLINE"
    else
        leftTop.Text = "YOUR TEMPLE CAN EARN"
        amountLabel.Text = "$0"
        dayLabel.Text = "A DAY OFFLINE... SO FAR"
        rightTop.Text = "START EARNING"
        rateLabel.Text = "$0/s"
        tipLabel.Text = "PLACE CHARACTERS ON YOUR STANDS TO EARN WHILE OFFLINE!"
        topLine.Text = "PLACE CHARACTERS TO EARN CASH WHILE YOU'RE OFFLINE"
    end
    local viewport = workspace.CurrentCamera.ViewportSize
    local fit = math.clamp(math.min(viewport.X * 0.2 / COL_W, viewport.Y * 0.8 / COL_H), 0.35, 1.6)
    screenGui.Enabled = true
    for _, col in columns do
        col.fit.Scale = fit
        col.pop.Scale = 0.6
        TweenService:Create(col.pop, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
    end
    TweenService:Create(topLine, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
    TweenService:Create(topStroke, TweenInfo.new(0.3), { Transparency = 0 }):Play()
    TweenService:Create(backdrop, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { GroupTransparency = 0.04 }):Play()
    local spawnTimer, clock = 0, 0
    renderConnection = RunService.RenderStepped:Connect(function(dt)
        clock += dt
        sweep.Rotation = 35 + math.sin(clock * 0.35) * 18
        sweep.Offset = Vector2.new(math.sin(clock * 0.25) * 0.18, 0)
        rays.Rotation = clock * 9
        for _, blob in blobs do
            blob.gui.Position = UDim2.fromScale(blob.x + math.sin(clock * 0.4 + blob.phase) * 0.05, blob.y + math.cos(clock * 0.33 + blob.phase) * 0.06)
        end
        amountLabel.Rotation = math.sin(clock * 1.6) * 1.2
        spawnTimer += dt
        if spawnTimer > 0.28 then
            spawnTimer = 0
            spawnFallingCoin()
        end
    end)
end
local function hideOverlay()
    if not isOpen then
        return
    end
    isOpen = false
    for _, col in columns do
        TweenService:Create(col.pop, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.6 }):Play()
    end
    TweenService:Create(topLine, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
    TweenService:Create(topStroke, TweenInfo.new(0.2), { Transparency = 1 }):Play()
    TweenService:Create(backdrop, TweenInfo.new(0.25), { GroupTransparency = 1 }):Play()
    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end
    task.delay(0.26, function()
        if not isOpen then
            screenGui.Enabled = false
            rain:ClearAllChildren()
        end
    end)
end
GuiService.MenuOpened:Connect(showOverlay)
GuiService.MenuClosed:Connect(hideOverlay)
