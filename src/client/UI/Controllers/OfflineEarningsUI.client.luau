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

---------------------------------------------------------------- the window, in the Folk Stud look (2026-11-08)
-- A white studded sheet with a black outline: "OFFLINE EARNINGS" on the top border with the cash stack hanging over the
-- corner, the red X, a purple away pill, the cash stack floating on spinning gold rays, the amount in candy green and
-- chunky studded COLLECT / 2x COLLECT buttons. Old look (MenuArt): ServerStorage._ARCHIVE.OfflineEarningsUI_BeforeStud_2026-11-08
local FolkStud = require(ReplicatedStorage:WaitForChild("FolkStudUI"))
local H = FolkStud.H
local CASH_ART = "rbxassetid://136807180106184" -- FOLK cash stack, same as the cash card
local CLOCK_ART = "rbxassetid://112731802177209"
local CASH_GREEN = H.hex("2BF08C")

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
    local W, HT = 580, 456

    local screenGui = H.new("ScreenGui", {
        Name = "OfflineEarningsUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 80,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, player:WaitForChild("PlayerGui"))
    local dimFrame = H.new("Frame", { Name = "Dim", BackgroundColor3 = BLACK, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 0 }, screenGui)
    TweenService:Create(dimFrame, TweenInfo.new(0.3), { BackgroundTransparency = 0.45 }):Play()
    -- two scales: Fit follows the screen size, Pop is only the open / close bounce
    local root = H.new("Frame", { Name = "Root", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.54), Size = UDim2.fromOffset(W, HT) }, screenGui)
    local fitScale = H.new("UIScale", { Name = "Fit" }, root)
    local stage = H.new("Frame", { Name = "Stage", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, root)
    local popScale = H.new("UIScale", { Name = "Pop", Scale = 0.6 }, stage)
    local function rescale()
        local size = screenGui.AbsoluteSize
        if size.X < 10 then
            return
        end
        fitScale.Scale = math.clamp(math.min(size.X / (W + 120), size.Y / (HT + 170)), 0.45, 1.1)
    end
    rescale()
    screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
    TweenService:Create(popScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()

    -- the sheet
    H.shadow(stage, "Window", -2, 4, W + 4, HT + 4, 16, 1)
    local win = H.rect(stage, "Window", 0, 0, W, HT, 14, 1)
    H.ink(win, 4)
    H.neon(win)
    H.studs(win, Vector2.new(50, 46), 0.8, 12, 1)
    H.sticker(stage, "Icon", CASH_ART, 18, -3, 84, 8)
    H.gleam(H.text(stage, "Title", "OFFLINE EARNINGS", 66, -2, 46, 8, WHITE, "left"))
    local closeButton = H.closeButton(stage, W - 42, -26)

    -- away pill: read only, so flat (no lip, no studs)
    local PW, PH = 320, 46
    local px = (W - PW) / 2
    H.shadow(stage, "Away", px, 50, PW, PH, 12, 2)
    local pill = H.rect(stage, "Away", px, 50, PW, PH, 12, 3)
    H.ink(pill, 4)
    H.grad(pill, FolkStud.COLOR.purple[1], FolkStud.COLOR.purple[2])
    H.art(pill, "Clock", CLOCK_ART, 28, PH / 2, 30, 5)
    H.text(pill, "Label", "You were away for " .. formatAwayTime(awaySeconds), PW / 2 + 16, PH / 2, 22, 5)

    -- hero: the cash stack floating on spinning gold rays, with twinkles
    H.rays(stage, W / 2, 178, 330, 2, H.hex("FFD000"))
    H.sticker(stage, "Cash", CASH_ART, W / 2, 176, 150, 6, true)
    H.sparkle(stage, "Twinkle1", W / 2 - 118, 128, 30, 7, 0)
    H.sparkle(stage, "Twinkle2", W / 2 + 122, 150, 24, 7, 0.4)
    H.sparkle(stage, "Twinkle3", W / 2 + 92, 222, 20, 7, 0.75)
    H.sparkle(stage, "Twinkle4", W / 2 - 98, 218, 18, 7, 0.2)

    -- amount (counts up) and its line
    local amountLabel = H.text(stage, "Amount", "$0", W / 2, 276, 72, 8, CASH_GREEN)
    H.gleam(amountLabel)
    H.text(stage, "Sub", "earned while you were away", W / 2, 334, 22, 8)
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

    local closing = false
    local function close()
        if closing then
            return
        end
        closing = true
        UISound.Play("Close")
        TweenService:Create(popScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.6 }):Play()
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
    closeButton.Activated:Connect(function()
        collectAndClose()
    end)

    -- studded candy buttons (centre anchored, lip + studs because they can be pressed)
    local BY, BH = 366, 80
    local function makeButton(name, label, subtitle, palette, x, w, onClick)
        H.shadow(stage, name, x, BY, w, BH, 14, 2)
        local b = H.button(stage, name, x, BY, w, BH, 14, palette, 4)
        H.text(b, "Label", label, w / 2, subtitle and BH / 2 - 14 or BH / 2 - 3, 34, b.ZIndex + 2)
        if subtitle then
            H.text(b, "Sub", subtitle, w / 2, BH / 2 + 17, 19, b.ZIndex + 2)
        end
        b.MouseEnter:Connect(function()
            UISound.Play("Hover")
        end)
        b.Activated:Connect(function()
            UISound.Play("Click")
            onClick()
        end)
        return b
    end
    if canDouble then
        makeButton("Collect", "COLLECT", formatShortCash(amount), FolkStud.COLOR.green, 34, 244, function()
            collectAndClose()
        end)
        local doubleButton = makeButton(
            "Double",
            "2× COLLECT",
            formatShortCash(amount * 2) .. "  ·  R$ " .. tostring(ShopConfig.Prices.Offline2x or 19),
            FolkStud.COLOR.gold,
            W - 34 - 244,
            244,
            function()
                pcall(function()
                    shopRemote:InvokeServer("Buy", "Offline2x")
                end)
            end
        )
        doubleButton:SetAttribute("Beat", true)
        -- the "2x CASH!" tag hanging off the 2x button's corner
        local badge = H.rect(stage, "Badge", W - 34 - 84, BY - 34, 112, 38, 12, 9)
        H.ink(badge, 4)
        H.grad(badge, FolkStud.COLOR.red[1], FolkStud.COLOR.red[2])
        badge.Rotation = -7
        badge:SetAttribute("Wiggle", -7)
        H.text(badge, "Label", "2× CASH!", 56, 18, 20, 10)
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
            local flash = H.rect(stage, "Flash", 0, 0, W, HT, 14, 30, WHITE)
            flash.BackgroundTransparency = 0.2
            TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
            task.delay(1.8, function()
                collectAndClose(amount * 2)
            end)
        end)
    else
        makeButton("Collect", "AWESOME!", nil, FolkStud.COLOR.green, (W - 300) / 2, 300, function()
            collectAndClose()
        end)
    end
    FolkStud.animate(root, { sounds = false })
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
