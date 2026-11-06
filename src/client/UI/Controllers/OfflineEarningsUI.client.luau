-- OfflineEarningsUI (LocalScript): "while you were away" window, drawn from the MenuArt art (assets/ui/menus3:
-- GPT Image window art in the Halloween Shop style) with the amount, coins and button texts on top.
-- Reads player attributes set by PlayerDataService: OfflineEarnings (cash put on the stands), OfflineSeconds.
-- 2× button buys ShopConfig.Products.Offline2x (hidden while that id is 0); ShopService pays the same amount again.
-- Remote: ShopRemote:InvokeServer("Buy", "Offline2x") only opens the Robux prompt; the payout happens in ShopService's
-- ProcessReceipt, which sets the OfflineDoubled attribute that this window listens for. Closing the window (COLLECT,
-- 2x, X) asks the server to move the offline cash from the money stands into Cash (OfflineCollect) while coins fly
-- into the money card; the server decides the amount.
-- Shown once per session, after JoinArrivalFinished / LoadingScreenDone (or 20 s) + 1.2 s.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local UISound = require(ReplicatedStorage:WaitForChild("UISound"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopSystem"):WaitForChild("ShopConfig"))
local shopRemote = ReplicatedStorage.ShopSystem:WaitForChild("ShopRemote")
local MenuArt = require(ReplicatedStorage:WaitForChild("MenuArt"):WaitForChild("MenuArt"))

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
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

---------------------------------------------------------------- collect: coins fly into the money card
-- ReplicatedStorage.OfflineCollect moves the offline cash from the money stands into Cash (server, once). It is called
-- when the first coin lands, so the card's number climbs while the coins arrive; MoneyDisplay.CashPulse makes the
-- card bump with each coin and flash when the last one is in.
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local collectRemote = ReplicatedStorage:WaitForChild("OfflineCollect", 30)

-- centre of a GuiObject in screen pixels (the space of a ScreenGui with ScreenInsets None). AbsolutePosition is
-- measured from below the top bar inset whatever the object's own ScreenGui does, so the inset is always added.
local function screenCentre(object)
    return object.AbsolutePosition + object.AbsoluteSize / 2 + GuiService:GetGuiInset()
end

local function collectOffline()
    if collectRemote then
        pcall(collectRemote.InvokeServer, collectRemote)
    end
end

local function flyCoins(fromObject, amount)
    local playerGui = player:WaitForChild("PlayerGui")
    local moneyGui = playerGui:FindFirstChild("MoneyDisplay")
    local cashCard = moneyGui and moneyGui:FindFirstChild("CashUI")
    local coinIcon = cashCard and cashCard:FindFirstChild("CoinIcon", true)
    local cashPulse = moneyGui and moneyGui:FindFirstChild("CashPulse")
    if not coinIcon or not moneyGui.Enabled then
        collectOffline()
        return
    end
    local from = screenCentre(fromObject)
    local to = screenCentre(coinIcon)
    local layer = create("ScreenGui", {
        Name = "OfflineCoinFly",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ScreenInsets = Enum.ScreenInsets.None,
        DisplayOrder = 85,
    }, playerGui)
    local count = math.clamp(math.floor(8 + math.log10(math.max(amount, 1)) * 1.5), 10, 20)
    local coinSize = math.clamp(coinIcon.AbsoluteSize.X * 1.1, 26, 56)
    local coins, landed, startedAt = {}, 0, os.clock()
    for i = 1, count do
        local angle = math.random() * math.pi * 2
        local spread = Vector2.new(math.cos(angle), math.sin(angle) * 0.7) * (50 + math.random() * 90)
        local image = create("ImageLabel", {
            BackgroundTransparency = 1,
            Image = coinIcon.Image,
            ScaleType = Enum.ScaleType.Fit,
            ResampleMode = Enum.ResamplerMode.Pixelated,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(from.X, from.Y),
            Size = UDim2.fromOffset(coinSize, coinSize),
            Rotation = math.random(-30, 30),
        }, layer)
        -- out: a quick burst around the amount; in: a curve (bending up and away) into the card's coin icon
        local burst = from + spread
        local bend = (burst + to) / 2 + Vector2.new(spread.X * 0.6, -120 - math.random() * 80)
        coins[i] = {
            image = image,
            burst = burst,
            bend = bend,
            outAt = (i - 1) * 0.015,
            inAt = 0.32 + (i - 1) * 0.045,
            flight = 0.42 + math.random() * 0.12,
            spin = math.random(-360, 360),
        }
    end
    local connection
    connection = RunService.RenderStepped:Connect(function()
        local t = os.clock() - startedAt
        for i, coin in coins do
            if coin.done then
                continue
            end
            local position, size = nil, coinSize
            if t < coin.inAt then
                local u = math.clamp((t - coin.outAt) / 0.22, 0, 1)
                u = 1 - (1 - u) ^ 3
                position = from:Lerp(coin.burst, u)
            else
                local u = math.clamp((t - coin.inAt) / coin.flight, 0, 1)
                local e = u * u
                local a = coin.burst:Lerp(coin.bend, e)
                local b = coin.bend:Lerp(to, e)
                position = a:Lerp(b, e)
                size = coinSize * (1 - 0.45 * e)
                coin.image.Rotation += coin.spin * 0.016
                if u >= 1 then
                    coin.done = true
                    coin.image:Destroy()
                    landed += 1
                    if landed == 1 then
                        task.spawn(collectOffline)
                    end
                    if cashPulse then
                        cashPulse:Fire(landed == count and "burst" or "coin")
                    end
                    if landed == count then
                        UISound.Play("CoinChing", 1.0, 0.9)
                    elseif i % 3 == 1 then
                        UISound.PlayCoinPickup()
                    end
                    continue
                end
            end
            coin.image.Position = UDim2.fromOffset(position.X, position.Y)
            coin.image.Size = UDim2.fromOffset(size, size)
        end
        if landed >= count then
            connection:Disconnect()
            layer:Destroy()
        end
    end)
    UISound.Play("CoinRustle")
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
    -- the window art (ReplicatedStorage.MenuArt, assets/ui/menus3): header with the title and X, the away pill,
    -- the golden glow; buttons and badge are pieces. Every rect below is in pixels of the 560 x 540 window.
    create("ImageLabel", {
        BackgroundTransparency = 1,
        Image = GLOW_IMAGE,
        ImageColor3 = rgb(255, 200, 40),
        ImageTransparency = 0.6,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 160, 1, 160),
        ZIndex = 2,
    }, holder)
    local window = create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, holder)
    MenuArt.background(window, "Offline", nil, 4)
    -- away pill (drawn): clock + "You were away for ..." centred in it
    local pill = create("Frame", {
        Position = UDim2.fromOffset(173, 84),
        Size = UDim2.fromOffset(213, 41),
        BackgroundTransparency = 1,
        ZIndex = 6,
    }, window)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 7),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, pill)
    create("ImageLabel", {
        BackgroundTransparency = 1,
        Image = "rbxassetid://112731802177209",
        ScaleType = Enum.ScaleType.Fit,
        ResampleMode = Enum.ResamplerMode.Pixelated,
        LayoutOrder = 0,
        Size = UDim2.fromOffset(24, 24),
        ZIndex = 8,
    }, pill)
    makeLabel(
        pill,
        "You were away for " .. formatAwayTime(awaySeconds),
        17,
        rgb(255, 220, 120),
        { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, ZIndex = 7 }
    )
    -- hero: coin pile + sparkles over the drawn glow
    local hero = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 148),
        Size = UDim2.fromOffset(300, 140),
        BackgroundTransparency = 1,
        ZIndex = 6,
    }, window)
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
        { Position = UDim2.fromOffset(0, 288), Size = UDim2.new(1, 0, 0, 78), ZIndex = 8 }
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
        "earned while you were away",
        15,
        rgb(220, 215, 245),
        { Position = UDim2.fromOffset(0, 364), Size = UDim2.new(1, 0, 0, 20), ZIndex = 8 }
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
    -- every way out of the window collects: the cash flies from the amount into the money card, then it closes
    local collected = false
    local function collectAndClose(shownAmount)
        if not collected then
            collected = true
            flyCoins(amountLabel, shownAmount or amount)
        end
        close()
    end
    -- the drawn X closes too
    local closeButton = create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(494, 3),
        Size = UDim2.fromOffset(62, 55),
        ZIndex = 20,
    }, window)
    closeButton.Activated:Connect(function()
        collectAndClose()
    end)
    -- a button piece (OffGreen / OffGold) at rect with its title + subtitle and a press bounce
    local function makeButton(text, subtitle, pieceName, rect, onClick, pulse)
        local buttonHolder = create("Frame", {
            Position = UDim2.fromOffset(rect[1], rect[2]),
            Size = UDim2.fromOffset(rect[3], rect[4]),
            BackgroundTransparency = 1,
            ZIndex = 8,
        }, window)
        local art = MenuArt.piece(buttonHolder, "Art", pieceName, { 0, 0, rect[3], rect[4] }, 9, 18)
        makeLabel(art, text, 28, WHITE, {
            Position = UDim2.fromOffset(0, subtitle and 14 or 0),
            Size = UDim2.new(1, 0, 0, subtitle and 34 or rect[4]),
            ZIndex = 11,
        })
        if subtitle then
            makeLabel(
                art,
                subtitle,
                16,
                rgb(255, 255, 225),
                { Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 22), ZIndex = 11 }
            )
        end
        local hit = create("TextButton", {
            Text = "",
            AutoButtonColor = false,
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 12,
        }, buttonHolder)
        local pulseScale = create("UIScale", {}, buttonHolder)
        if pulse then
            TweenService:Create(
                pulseScale,
                TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { Scale = 1.05 }
            ):Play()
        end
        hit.MouseEnter:Connect(function()
            UISound.Play("Hover")
        end)
        hit.MouseButton1Down:Connect(function()
            art.Position = UDim2.fromOffset(0, 3)
        end)
        hit.MouseButton1Up:Connect(function()
            art.Position = UDim2.fromScale(0, 0)
        end)
        hit.Activated:Connect(function()
            UISound.Play("Click")
            onClick()
        end)
        return buttonHolder
    end
    if canDouble then
        makeButton("COLLECT", formatShortCash(amount), "OffGreen", { 39, 408, 240, 101 }, function()
            collectAndClose()
        end)
        local doubleButton = makeButton(
            "2× COLLECT",
            formatShortCash(amount * 2) .. "  ·  R$ " .. tostring(ShopConfig.Prices.Offline2x or 19),
            "OffGold",
            { 284, 408, 240, 101 },
            function()
                pcall(function()
                    shopRemote:InvokeServer("Buy", "Offline2x")
                end)
            end,
            true
        )
        local badge = MenuArt.piece(doubleButton, "Badge", "OffBadge", { 162, -26, 90, 40 }, 14, 12)
        badge.Rotation = -6
        makeLabel(badge, "2× CASH!", 15, WHITE, { Size = UDim2.fromScale(1, 1), ZIndex = 15 })
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
            addCorner(flash, 18)
            TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
            task.delay(1.8, function()
                collectAndClose(amount * 2)
            end)
        end)
    else
        makeButton("AWESOME!", nil, "OffGreen", { 130, 408, 300, 101 }, function()
            collectAndClose()
        end)
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
