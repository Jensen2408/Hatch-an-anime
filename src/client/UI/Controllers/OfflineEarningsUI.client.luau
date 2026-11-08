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

    -- 2026-11-08: Folk Stud look (white studded sheet, black outlines, title on the top border, kit buttons).
    -- The old MenuArt window: ServerStorage._ARCHIVE.Scripts_BeforeStudJoinUI_2026-11-08.OfflineEarningsUI
    local Kit = require(ReplicatedStorage:WaitForChild("FolkStudUI"))
    local H = Kit.H
    local hex = Color3.fromHex
    local W, HT = 560, 540 -- design size of the holder; the sheet sits inside it with room for the overhangs
    local screenGui = create("ScreenGui", {
        Name = "OfflineEarningsUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 80,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, player:WaitForChild("PlayerGui"))
    local dimFrame = create(
        "Frame",
        { BackgroundColor3 = BLACK, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1 },
        screenGui
    )
    TweenService:Create(dimFrame, TweenInfo.new(0.3), { BackgroundTransparency = 0.45 }):Play()
    -- two scales: Fit follows the screen, Pop is the open/close bounce (a pop that tweens a saved fit value can leave
    -- the window invisible when the camera size is still 0 at Play start)
    local holder = create("Frame", {
        Name = "Root",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(W, HT),
        BackgroundTransparency = 1,
        ZIndex = 2,
    }, screenGui)
    local fitScale = create("UIScale", { Name = "Fit" }, holder)
    local function rescale()
        local screenSize = screenGui.AbsoluteSize
        return math.clamp(math.min(screenSize.X / 620, screenSize.Y / 600), 0.5, 1.15)
    end
    fitScale.Scale = rescale()
    screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        fitScale.Scale = rescale()
    end)
    local window = create("Frame", { Name = "Stage", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, holder)
    local popScale = create("UIScale", { Name = "Pop", Scale = 0.8 }, window)
    TweenService:Create(popScale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

    -- the sheet: white, studs, thick black outline, hard shadow
    local SX, SY, SW, SH = 20, 44, 520, 470
    H.shadow(window, "Sheet", SX - 2, SY + 4, SW + 4, SH + 4, 16, 2)
    local sheet = H.rect(window, "Sheet", SX, SY, SW, SH, 14, 3)
    H.ink(sheet, 4)
    H.studs(sheet, Vector2.new(50, 46), 0.8, 14, 3)
    -- title centred on the top border, the coin icon hanging over the corner, the red X over the other corner
    H.sticker(window, "Icon", COINS_IMAGE, SX + 22, SY - 2, 84, 9)
    H.gleam(H.text(window, "Title", "WELCOME BACK!", SX + 70, SY - 2, 46, 9, WHITE, "left"))
    local closeButton = H.closeButton(window, SX + SW - 42, SY - 26)

    -- away pill (only read, so flat: no studs, no lip)
    local pill = H.rect(window, "AwayPill", 130, SY + 40, 300, 42, 12, 5)
    H.ink(pill, 3)
    H.grad(pill, hex("2FB8FF"), hex("0283FB"))
    H.text(pill, "Away", "You were away for " .. formatAwayTime(awaySeconds), 150, 21, 22, 6, WHITE)

    -- hero: spinning gold rays behind a floating coin pile, sparkles round it
    local HX, HY = W / 2, SY + 158
    H.beams(window, HX, HY, 340, 4, hex("FFC400"), 0.3, 8) -- drawn rays (the rays image does not load in this place)
    local pile = { { 0, 18, 96 }, { -66, 34, 72 }, { 68, 32, 74 }, { -30, -10, 66 }, { 36, -12, 68 } }
    for i, coin in pile do
        local s = H.sticker(window, "Coin" .. i, COINS_IMAGE, HX + coin[1], HY + coin[2], coin[3], 5 + i, true)
        s.Rotation = (i % 2 == 0 and -1 or 1) * (4 + i * 2)
    end
    H.sparkle(window, "Spark1", HX - 140, HY - 40, 34, 12, 0)
    H.sparkle(window, "Spark2", HX + 146, HY - 18, 26, 12, 1.3)
    H.sparkle(window, "Spark3", HX - 112, HY + 54, 22, 12, 2.4)
    H.sparkle(window, "Spark4", HX + 118, HY + 60, 30, 12, 0.7)

    -- amount (counts up), green with a light sweep
    local amountLabel = H.text(window, "Amount", "$0", HX, SY + 286, 76, 12, hex("12D67A"))
    amountLabel:FindFirstChild("UIStroke").Thickness = 5
    H.gleam(amountLabel)
    H.text(window, "Sub", "earned while you were away", HX, SY + 330, 22, 12, WHITE)
    task.spawn(function()
        local startedAt = os.clock()
        while amountLabel.Parent do
            local progress = math.clamp((os.clock() - startedAt) / 1.2, 0, 1)
            progress = 1 - (1 - progress) ^ 3
            amountLabel.Text = formatShortCash(amount * progress)
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
        TweenService:Create(popScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.8 }):Play()
        TweenService:Create(dimFrame, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
        task.delay(0.16, function()
            holder.Visible = false
        end)
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
    closeButton.Activated:Connect(function()
        collectAndClose()
    end)
    -- a studded kit button with a big word and a small line under it; hover/press bounce comes from Kit.animate
    local BY, BH = SY + 364, 88
    local function makeButton(name, textValue, subtitle, pal, x, w, onClick)
        local b = H.button(window, name, x, BY, w, BH, 16, pal, 8)
        H.text(b, "Label", textValue, w / 2, subtitle and 30 or (BH - 4) / 2, subtitle and 34 or 40, 11)
        if subtitle then
            H.text(b, "Sub", subtitle, w / 2, 64, 19, 11)
        end
        b.Activated:Connect(function()
            onClick()
        end)
        return b
    end
    if canDouble then
        makeButton("Collect", "COLLECT", formatShortCash(amount), Kit.COLOR.lime, SX + 30, 220, function()
            collectAndClose()
        end)
        local doubleButton = makeButton(
            "Double",
            "2× COLLECT",
            formatShortCash(amount * 2) .. "  ·  R$ " .. tostring(ShopConfig.Prices.Offline2x or 19),
            Kit.COLOR.gold,
            SX + SW - 30 - 220,
            220,
            function()
                pcall(function()
                    shopRemote:InvokeServer("Buy", "Offline2x")
                end)
            end
        )
        doubleButton:SetAttribute("Glint", true) -- the best deal's outline glints gold
        -- red tag on the corner of the 2x button, wiggling
        local badge = H.rect(doubleButton, "Badge", 134, -30, 104, 36, 10, 14)
        H.ink(badge, 3)
        H.grad(badge, Kit.COLOR.red[1], Kit.COLOR.red[2])
        H.text(badge, "Label", "2× CASH!", 52, 17, 20, 15)
        badge.Rotation = 6
        badge:SetAttribute("Wiggle", 6)
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
                    if progress >= 1 then
                        break
                    end
                    task.wait()
                end
            end)
            local flash = H.rect(sheet, "Flash", 0, 0, SW, SH, 14, 30)
            flash.BackgroundTransparency = 0.2
            TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
            task.delay(1.8, function()
                collectAndClose(amount * 2)
            end)
        end)
    else
        makeButton("Collect", "AWESOME!", nil, Kit.COLOR.lime, W / 2 - 150, 300, function()
            collectAndClose()
        end)
    end
    -- the kit animates it all: rays spin, coins float, sparkles twinkle, words gleam, buttons bounce with the game's sounds
    Kit.animate(screenGui, {
        sound = function(kind)
            UISound.Play(kind == "hover" and "Hover" or "Click")
        end,
    })
    UISound.Play("Open")
end

-- wait for the join sequence (loading screen + sky arrival) to finish, then show
task.spawn(function()
    local startedAt = os.clock()
    -- 2026-11-08: the loading screen is gone (SkyStart sets LoadingScreenDone as soon as the sky cover fades), so wait
    -- for the sky-drop intro itself to finish; otherwise the window popped up in the middle of the drop
    repeat
        task.wait(0.5)
    until player:GetAttribute("JoinArrivalFinished")
        or (player:GetAttribute("LoadingScreenDone") and not player:GetAttribute("JoinArrivalStarted") and os.clock() - startedAt > 6)
        or os.clock() - startedAt > 45
    task.wait(1.2)
    showWindow()
    player:GetAttributeChangedSignal("OfflineEarnings"):Connect(showWindow)
end)
