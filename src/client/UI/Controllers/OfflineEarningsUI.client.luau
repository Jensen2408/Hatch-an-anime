-- OfflineEarningsUI (LocalScript): "while you were away" window from Figma "Offline Earnings v3".
-- Reads player attributes set by PlayerDataService: OfflineEarnings (cash put on the stands), OfflineSeconds.
-- 2× button buys ShopConfig.Products.Offline2x (hidden while that id is 0); ShopService pays the same amount again.
-- Remote: ShopRemote:InvokeServer("Buy", "Offline2x") only opens the Robux prompt; the payout happens in ShopService's
-- ProcessReceipt, which sets the OfflineDoubled attribute that this window listens for. Display only; never grants cash.
-- Shown once per session, after JoinArrivalFinished / LoadingScreenDone (or 20 s) + 1.2 s.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local UISound = require(ReplicatedStorage:WaitForChild("UISound"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopSystem"):WaitForChild("ShopConfig"))
local shopRemote = ReplicatedStorage.ShopSystem:WaitForChild("ShopRemote")

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
local STUDS_IMAGE = "rbxassetid://132561191216691"
local GLOW_IMAGE = "rbxthumb://type=Asset&id=85372533044428&w=420&h=420"
local SPARK_IMAGE = "rbxthumb://type=Asset&id=87376394612367&w=420&h=420"
local COINS_IMAGE = ShopConfig.Icons and ShopConfig.Icons.Coins or ""
local function rgb(red, green, blue)
    return Color3.fromRGB(red, green, blue)
end
local function create(class, props, parent)
    local instance = Instance.new(class)
    for key, value in props do
        instance[key] = value
    end
    instance.Parent = parent
    return instance
end
local function addCorner(target, radius)
    create("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, target)
end
local function addStuds(target, transparency)
    return create("ImageLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = STUDS_IMAGE,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(24, 24),
        ImageTransparency = transparency or 0.55,
        ZIndex = target.ZIndex,
    }, target)
end
local function makeLabel(parent, text, size, color, props)
    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Text = text,
        FontFace = FONT,
        TextSize = size,
        TextColor3 = color or WHITE,
        Size = UDim2.new(1, 0, 0, size + 8),
        ZIndex = (parent.ZIndex or 1) + 2,
    }, parent)
    if props then
        for key, value in props do
            if key ~= "NoStroke" then
                label[key] = value
            end
        end
    end
    if not (props and props.NoStroke) then
        create("UIStroke", {
            Color = BLACK,
            Thickness = size >= 40 and 5 or (size >= 22 and 3 or 2),
            LineJoinMode = Enum.LineJoinMode.Round,
        }, label)
    end
    return label
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
local function formatAwayTime(seconds)
    seconds = math.floor(seconds or 0)
    local hours, minutes = seconds // 3600, (seconds // 60) % 60
    if hours > 0 then
        return hours .. "h " .. minutes .. "m"
    end
    return math.max(1, minutes) .. "m"
end

local hasShown = false
local function showWindow()
    if hasShown then
        return
    end
    local amount = tonumber(player:GetAttribute("OfflineEarnings")) or 0
    if amount <= 0 then
        return
    end
    hasShown = true
    local awaySeconds = tonumber(player:GetAttribute("OfflineSeconds")) or 0
    local canDouble = (ShopConfig.Products.Offline2x or 0) ~= 0

    local screenGui = create("ScreenGui", {
        Name = "OfflineEarningsUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 80,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, player:WaitForChild("PlayerGui"))
    local dimFrame = create(
        "Frame",
        { BackgroundColor3 = rgb(10, 6, 22), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1 },
        screenGui
    )
    TweenService:Create(dimFrame, TweenInfo.new(0.3), { BackgroundTransparency = 0.35 }):Play()
    local holder = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(560, 540),
        BackgroundTransparency = 1,
        ZIndex = 2,
    }, screenGui)
    local fitScale = create("UIScale", { Scale = 0.6 }, holder)
    local function rescale()
        local screenSize = screenGui.AbsoluteSize
        return math.clamp(math.min(screenSize.X / 620, screenSize.Y / 600), 0.5, 1.15)
    end
    TweenService:Create(fitScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = rescale() }):Play()
    screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        fitScale.Scale = rescale()
    end)
    create("ImageLabel", {
        BackgroundTransparency = 1,
        Image = GLOW_IMAGE,
        ImageColor3 = rgb(255, 200, 40),
        ImageTransparency = 0.5,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 160, 1, 160),
        ZIndex = 2,
    }, holder)
    create("Frame", {
        BackgroundColor3 = BLACK,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 10),
        Size = UDim2.fromScale(1, 1),
        ZIndex = 3,
    }, holder).Name =
        "Shadow"
    addCorner(holder:FindFirstChild("Shadow"), 18)
    local window = create(
        "Frame",
        { BackgroundColor3 = WHITE, Size = UDim2.fromScale(1, 1), ZIndex = 4, ClipsDescendants = true },
        holder
    )
    addCorner(window, 18)
    create("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(47, 35, 87), rgb(20, 13, 43)) }, window)
    addStuds(window, 0.7)
    create("UIStroke", { Color = WHITE, Thickness = 5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, window)
    -- header
    local header = create(
        "Frame",
        { BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 78), ZIndex = 5 },
        window
    )
    create("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(255, 214, 72), rgb(230, 140, 0)) }, header)
    addStuds(header, 0.45)
    create("Frame", {
        BackgroundColor3 = BLACK,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 5),
        ZIndex = 6,
    }, header)
    makeLabel(header, "OFFLINE EARNINGS", 38, WHITE, { Size = UDim2.fromScale(1, 1), ZIndex = 7 })
    -- away pill
    local pill = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 98),
        Size = UDim2.fromOffset(0, 36),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = rgb(20, 14, 40),
        ZIndex = 6,
    }, window)
    addCorner(pill, 18)
    create("UIStroke", { Color = WHITE, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, pill)
    create("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, pill)
    create("ImageLabel", {
        BackgroundTransparency = 1,
        Image = "rbxassetid://112731802177209",
        ScaleType = Enum.ScaleType.Fit,
        ResampleMode = Enum.ResamplerMode.Pixelated,
        LayoutOrder = 0,
        Size = UDim2.fromOffset(26, 26),
        ZIndex = 8,
    }, pill)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, pill)
    makeLabel(
        pill,
        "You were away for " .. formatAwayTime(awaySeconds),
        17,
        rgb(255, 220, 120),
        { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 7 }
    )
    -- hero: glow + coin pile
    local hero = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 140),
        Size = UDim2.fromOffset(300, 150),
        BackgroundTransparency = 1,
        ZIndex = 6,
    }, window)
    local halo = create("ImageLabel", {
        BackgroundTransparency = 1,
        Image = GLOW_IMAGE,
        ImageColor3 = rgb(255, 220, 90),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(260, 260),
        ZIndex = 6,
    }, hero)
    TweenService:Create(
        halo,
        TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { ImageTransparency = 0.35, Size = UDim2.fromOffset(290, 290) }
    ):Play()
    local pile = { { 0, 18, 92 }, { -60, 34, 70 }, { 62, 32, 72 }, { -28, -6, 64 }, { 34, -8, 66 } }
    for i, coin in pile do
        local coinImage = create("ImageLabel", {
            BackgroundTransparency = 1,
            Image = COINS_IMAGE,
            ScaleType = Enum.ScaleType.Fit,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, coin[1], 0.5, coin[2]),
            Size = UDim2.fromOffset(coin[3], coin[3]),
            ZIndex = 8 + i,
        }, hero)
        TweenService:Create(
            coinImage,
            TweenInfo.new(1 + i * 0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Position = UDim2.new(0.5, coin[1], 0.5, coin[2] - 6) }
        ):Play()
    end
    for i = 1, 7 do
        local angle = i / 7 * math.pi * 2
        local sparkle = create("ImageLabel", {
            BackgroundTransparency = 1,
            Image = SPARK_IMAGE,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, math.cos(angle) * 140, 0.5, math.sin(angle) * 70),
            Size = UDim2.fromOffset(i % 2 == 0 and 14 or 22, i % 2 == 0 and 14 or 22),
            ImageColor3 = i % 2 == 0 and WHITE or rgb(255, 230, 140),
            ZIndex = 15,
        }, hero)
        TweenService:Create(
            sparkle,
            TweenInfo.new(0.7 + i * 0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { ImageTransparency = 0.85, Rotation = 45 }
        ):Play()
    end
    -- amount (counts up)
    local amountLabel = makeLabel(
        window,
        "$0",
        72,
        rgb(130, 255, 110),
        { Position = UDim2.fromOffset(0, 292), Size = UDim2.new(1, 0, 0, 80), ZIndex = 8 }
    )
    local amountGlow = amountLabel:Clone()
    amountGlow.ZIndex = 7
    amountGlow.TextTransparency = 0.6
    amountGlow:FindFirstChildOfClass("UIStroke").Color = rgb(90, 255, 90)
    amountGlow:FindFirstChildOfClass("UIStroke").Thickness = 12
    amountGlow:FindFirstChildOfClass("UIStroke").Transparency = 0.7
    amountGlow.Parent = window
    makeLabel(
        window,
        "earned while you were away · collect it from your money stands",
        15,
        rgb(210, 205, 240),
        { Position = UDim2.fromOffset(0, 370), Size = UDim2.new(1, 0, 0, 20), ZIndex = 8, NoStroke = true }
    )
    task.spawn(function()
        local startedAt = os.clock()
        while amountLabel.Parent do
            local progress = math.clamp((os.clock() - startedAt) / 1.2, 0, 1)
            progress = 1 - (1 - progress) ^ 3
            amountLabel.Text = formatShortCash(amount * progress)
            amountGlow.Text = amountLabel.Text
            if progress >= 1 then
                break
            end
            task.wait()
        end
    end)
    -- buttons
    local closing = false
    local function close()
        if closing then
            return
        end
        closing = true
        UISound.Play("Close")
        TweenService
            :Create(fitScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.6 })
            :Play()
        TweenService:Create(dimFrame, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
        task.delay(0.22, function()
            screenGui:Destroy()
        end)
    end
    local function makeButton(text, subtitle, color, anchorX, width, onClick, pulse)
        local buttonHolder = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(anchorX, 0, 1, -26),
            Size = UDim2.fromOffset(width, 84),
            BackgroundTransparency = 1,
            ZIndex = 8,
        }, window)
        create("Frame", {
            BackgroundColor3 = BLACK,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 6),
            Size = UDim2.fromScale(1, 1),
            ZIndex = 8,
        }, buttonHolder).Name =
            "Base"
        addCorner(buttonHolder.Base, 14)
        local buttonFace = create("TextButton", {
            Text = "",
            AutoButtonColor = false,
            BackgroundColor3 = WHITE,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 9,
            ClipsDescendants = true,
        }, buttonHolder)
        addCorner(buttonFace, 14)
        create(
            "UIGradient",
            { Rotation = 90, Color = ColorSequence.new(color:Lerp(WHITE, 0.25), color:Lerp(BLACK, 0.12)) },
            buttonFace
        )
        addStuds(buttonFace, 0.55)
        create(
            "UIStroke",
            { Color = WHITE, Thickness = 3.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
            buttonFace
        )
        create("Frame", {
            BackgroundColor3 = WHITE,
            BackgroundTransparency = 0.65,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(10, 6),
            Size = UDim2.new(1, -20, 0, 5),
            ZIndex = 10,
        }, buttonFace)
        makeLabel(buttonFace, text, 28, WHITE, {
            Position = UDim2.fromOffset(0, subtitle and 10 or 0),
            Size = UDim2.new(1, 0, 0, subtitle and 34 or 84),
            ZIndex = 11,
        })
        if subtitle then
            makeLabel(
                buttonFace,
                subtitle,
                16,
                rgb(255, 255, 225),
                { Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 22), ZIndex = 11 }
            )
        end
        local pulseScale = create("UIScale", {}, buttonHolder)
        if pulse then
            TweenService:Create(
                pulseScale,
                TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { Scale = 1.05 }
            ):Play()
            local pulseGlow = create("ImageLabel", {
                BackgroundTransparency = 1,
                Image = GLOW_IMAGE,
                ImageColor3 = color,
                ImageTransparency = 0.4,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.new(1, 70, 1, 70),
                ZIndex = 7,
            }, buttonHolder)
            TweenService:Create(
                pulseGlow,
                TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { ImageTransparency = 0.75 }
            ):Play()
        end
        buttonFace.MouseEnter:Connect(function()
            UISound.Play("Hover")
        end)
        buttonFace.MouseButton1Down:Connect(function()
            buttonFace.Position = UDim2.fromOffset(0, 3)
        end)
        buttonFace.MouseButton1Up:Connect(function()
            buttonFace.Position = UDim2.new()
        end)
        buttonFace.Activated:Connect(function()
            UISound.Play("Click")
            onClick()
        end)
        return buttonHolder
    end
    if canDouble then
        makeButton("COLLECT", formatShortCash(amount), rgb(70, 190, 70), 0.27, 230, close)
        local doubleButton = makeButton(
            "2× COLLECT",
            formatShortCash(amount * 2) .. "  ·  R$ " .. tostring(ShopConfig.Prices.Offline2x or 19),
            rgb(255, 180, 30),
            0.73,
            250,
            function()
                pcall(function()
                    shopRemote:InvokeServer("Buy", "Offline2x")
                end)
            end,
            true
        )
        local badge = create("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 8, 0, 0),
            Size = UDim2.fromOffset(0, 28),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = rgb(226, 52, 60),
            Rotation = -6,
            ZIndex = 14,
        }, doubleButton)
        addCorner(badge, 8)
        create("UIStroke", { Color = WHITE, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, badge)
        create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, badge)
        makeLabel(
            badge,
            "2× CASH!",
            15,
            WHITE,
            { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 15 }
        )
        player:GetAttributeChangedSignal("OfflineDoubled"):Connect(function()
            if not player:GetAttribute("OfflineDoubled") or not amountLabel.Parent then
                return
            end
            UISound.Play("Purchase")
            local startedAt = os.clock()
            task.spawn(function()
                while amountLabel.Parent do
                    local progress = math.clamp((os.clock() - startedAt) / 0.8, 0, 1)
                    amountLabel.Text = formatShortCash(amount * (1 + progress))
                    amountGlow.Text = amountLabel.Text
                    if progress >= 1 then
                        break
                    end
                    task.wait()
                end
            end)
            local flash = create(
                "Frame",
                { BackgroundColor3 = WHITE, BackgroundTransparency = 0.2, Size = UDim2.fromScale(1, 1), ZIndex = 30 },
                window
            )
            TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
            task.delay(1.8, close)
        end)
    else
        makeButton("AWESOME!", nil, rgb(70, 190, 70), 0.5, 300, close)
    end
    UISound.Play("Open")
end

-- wait for the join sequence (loading screen + sky arrival) to finish, then show
task.spawn(function()
    local startedAt = os.clock()
    repeat
        task.wait(0.5)
    until (player:GetAttribute("JoinArrivalFinished") or player:GetAttribute("LoadingScreenDone"))
        or os.clock() - startedAt > 20
    task.wait(1.2)
    showWindow()
    player:GetAttributeChangedSignal("OfflineEarnings"):Connect(showWindow)
end)
