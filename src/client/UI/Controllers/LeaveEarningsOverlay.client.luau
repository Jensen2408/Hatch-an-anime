-- LeaveEarningsOverlay (LocalScript): when the Roblox menu (Esc) opens, show behind it that the temple keeps earning offline.
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
    return total * (workspace:GetAttribute("OwnerIncomeMultiplier") or 1)
end

local screenGui = create(
    "ScreenGui",
    { Name = "LeaveEarningsOverlay", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999, Enabled = false },
    player:WaitForChild("PlayerGui")
)
local background = create(
    "Frame",
    { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(18, 8, 40), BackgroundTransparency = 1 },
    screenGui
)
create(
    "UIGradient",
    { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(60, 20, 110), Color3.fromRGB(10, 4, 24)) },
    background
)
local rays = create("ImageLabel", {
    BackgroundTransparency = 1,
    Image = RAYS_IMAGE,
    ImageColor3 = Color3.fromRGB(255, 210, 90),
    ImageTransparency = 1,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.16),
    Size = UDim2.fromOffset(900, 900),
}, screenGui)
local halo = create("ImageLabel", {
    BackgroundTransparency = 1,
    Image = GLOW_IMAGE,
    ImageColor3 = Color3.fromRGB(255, 200, 60),
    ImageTransparency = 1,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.13),
    Size = UDim2.fromOffset(620, 300),
}, screenGui)
local textHolder = create("Frame", {
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 24),
    Size = UDim2.fromOffset(900, 170),
}, screenGui)
local textScale = create("UIScale", {}, textHolder)
local function makeText(text, y, size, color, thickness)
    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, y),
        Size = UDim2.new(1, 0, 0, size + 8),
        Text = text,
        FontFace = FONT,
        TextSize = size,
        TextColor3 = color,
        TextTransparency = 1,
    }, textHolder)
    local stroke = create(
        "UIStroke",
        { Color = BLACK, Thickness = thickness, Transparency = 1, LineJoinMode = Enum.LineJoinMode.Round },
        label
    )
    return label, stroke
end
local titleLabel, titleStroke = makeText("🌙  YOUR TEMPLE KEEPS EARNING!", 0, 44, WHITE, 5)
local rateLabel, rateStroke = makeText("$0/s while you're away", 58, 34, Color3.fromRGB(130, 255, 110), 4)
local capLabel, capStroke =
    makeText("Come back to collect up to $0  ·  max 8 hours", 104, 22, Color3.fromRGB(255, 225, 150), 3)
local titleGradient = create("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 214, 72)),
        ColorSequenceKeypoint.new(0.5, WHITE),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 140, 220)),
    }),
}, titleLabel)
local rain =
    create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true }, screenGui)

local isOpen, renderConnection = false, nil
local function fadeOverlay(isVisible)
    local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad)
    TweenService:Create(background, tweenInfo, { BackgroundTransparency = isVisible and 0.25 or 1 }):Play()
    TweenService:Create(rays, tweenInfo, { ImageTransparency = isVisible and 0.55 or 1 }):Play()
    TweenService:Create(halo, tweenInfo, { ImageTransparency = isVisible and 0.3 or 1 }):Play()
    for _, target in { titleLabel, rateLabel, capLabel } do
        TweenService:Create(target, tweenInfo, { TextTransparency = isVisible and 0 or 1 }):Play()
    end
    for _, target in { titleStroke, rateStroke, capStroke } do
        TweenService:Create(target, tweenInfo, { Transparency = isVisible and 0 or 1 }):Play()
    end
end
local function spawnFallingCoin()
    local size = math.random(26, 54)
    local image = math.random() < 0.75 and COINS_IMAGE or SPARK_IMAGE
    local coinLabel = create("ImageLabel", {
        BackgroundTransparency = 1,
        Image = image,
        ScaleType = Enum.ScaleType.Fit,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(math.random(), 0, 0, -60),
        Size = UDim2.fromOffset(size, size),
        Rotation = math.random(-40, 40),
        ImageTransparency = image == SPARK_IMAGE and 0.2 or 0,
    }, rain)
    local duration = 3 + math.random() * 2.5
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
    rateLabel.Text = formatShortCash(rate) .. "/s while you're away"
    capLabel.Text = "Come back to collect up to " .. formatShortCash(rate * OFFLINE_CAP) .. "  ·  max 8 hours"
    if rate <= 0 then
        rateLabel.Text = "Place characters on your stands"
        capLabel.Text = "...and they earn cash for you even while you're offline!"
    end
    textScale.Scale = math.clamp(workspace.CurrentCamera.ViewportSize.X / 960, 0.5, 1.1)
    screenGui.Enabled = true
    fadeOverlay(true)
    textScale.Scale *= 0.85
    TweenService:Create(textScale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = textScale.Scale / 0.85 })
        :Play()
    local spawnTimer, startedAt = 0, os.clock()
    renderConnection = RunService.RenderStepped:Connect(function(dt)
        rays.Rotation += dt * 8
        titleGradient.Offset = Vector2.new(math.sin((os.clock() - startedAt) * 1.5) * 0.4, 0)
        halo.Size = UDim2.fromOffset(620 + math.sin(os.clock() * 2) * 40, 300 + math.sin(os.clock() * 2) * 20)
        spawnTimer += dt
        if spawnTimer > 0.12 then
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
    fadeOverlay(false)
    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end
    task.delay(0.4, function()
        if not isOpen then
            screenGui.Enabled = false
            rain:ClearAllChildren()
        end
    end)
end
GuiService.MenuOpened:Connect(showOverlay)
GuiService.MenuClosed:Connect(hideOverlay)
