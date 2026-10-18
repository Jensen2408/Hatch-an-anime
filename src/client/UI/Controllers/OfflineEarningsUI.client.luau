-- OfflineEarningsUI (LocalScript): "while you were away" window from Figma "Offline Earnings v3".
-- Reads player attributes set by PlayerDataService: OfflineEarnings (cash put on the stands), OfflineSeconds.
-- 2× button buys ShopConfig.Products.Offline2x (hidden while that id is 0); ShopService pays the same amount again.
local Players = game:GetService("Players")
local TS = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local UISound = require(RS:WaitForChild("UISound"))
local SC = require(RS:WaitForChild("ShopSystem"):WaitForChild("ShopConfig"))
local remote = RS.ShopSystem:WaitForChild("ShopRemote")

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local K, W = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
local STUDS = "rbxassetid://132561191216691"
local GLOW = "rbxthumb://type=Asset&id=85372533044428&w=420&h=420"
local SPARK = "rbxthumb://type=Asset&id=87376394612367&w=420&h=420"
local COINS = SC.Icons and SC.Icons.Coins or ""
local function c3(r, g, b)
    return Color3.fromRGB(r, g, b)
end
local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in props do
        o[k] = v
    end
    o.Parent = parent
    return o
end
local function corner(o, r)
    new("UICorner", { CornerRadius = UDim.new(0, r or 12) }, o)
end
local function studs(o, t)
    return new("ImageLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = STUDS,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(24, 24),
        ImageTransparency = t or 0.55,
        ZIndex = o.ZIndex,
    }, o)
end
local function lbl(parent, s, size, color, props)
    local l = new("TextLabel", {
        BackgroundTransparency = 1,
        Text = s,
        FontFace = FONT,
        TextSize = size,
        TextColor3 = color or W,
        Size = UDim2.new(1, 0, 0, size + 8),
        ZIndex = (parent.ZIndex or 1) + 2,
    }, parent)
    if props then
        for k, v in props do
            if k ~= "NoStroke" then
                l[k] = v
            end
        end
    end
    if not (props and props.NoStroke) then
        new("UIStroke", {
            Color = K,
            Thickness = size >= 40 and 5 or (size >= 22 and 3 or 2),
            LineJoinMode = Enum.LineJoinMode.Round,
        }, l)
    end
    return l
end
local UNITS = { { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
local function short(n)
    n = tonumber(n) or 0
    for _, u in UNITS do
        if n >= u[1] then
            local v = n / u[1]
            local s = v < 10 and string.format("%.2f", v)
                or v < 100 and string.format("%.1f", v)
                or tostring(math.floor(v + 0.5))
            s = s:gsub("%.?0+$", "")
            return "$" .. s .. u[2]
        end
    end
    return "$" .. tostring(math.floor(n))
end
local function away(sec)
    sec = math.floor(sec or 0)
    local h, m = sec // 3600, (sec // 60) % 60
    if h > 0 then
        return h .. "h " .. m .. "m"
    end
    return math.max(1, m) .. "m"
end

local shown = false
local function show()
    if shown then
        return
    end
    local amount = tonumber(player:GetAttribute("OfflineEarnings")) or 0
    if amount <= 0 then
        return
    end
    shown = true
    local secs = tonumber(player:GetAttribute("OfflineSeconds")) or 0
    local canDouble = (SC.Products.Offline2x or 0) ~= 0

    local gui = new("ScreenGui", {
        Name = "OfflineEarningsUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 80,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, player:WaitForChild("PlayerGui"))
    local dim = new(
        "Frame",
        { BackgroundColor3 = c3(10, 6, 22), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1 },
        gui
    )
    TS:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = 0.35 }):Play()
    local holder = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(560, 540),
        BackgroundTransparency = 1,
        ZIndex = 2,
    }, gui)
    local fit = new("UIScale", { Scale = 0.6 }, holder)
    local function rescale()
        local v = gui.AbsoluteSize
        return math.clamp(math.min(v.X / 620, v.Y / 600), 0.5, 1.15)
    end
    TS:Create(fit, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = rescale() }):Play()
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        fit.Scale = rescale()
    end)
    new("ImageLabel", {
        BackgroundTransparency = 1,
        Image = GLOW,
        ImageColor3 = c3(255, 200, 40),
        ImageTransparency = 0.5,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 160, 1, 160),
        ZIndex = 2,
    }, holder)
    new("Frame", {
        BackgroundColor3 = K,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 10),
        Size = UDim2.fromScale(1, 1),
        ZIndex = 3,
    }, holder).Name =
        "Shadow"
    corner(holder:FindFirstChild("Shadow"), 18)
    local win = new(
        "Frame",
        { BackgroundColor3 = W, Size = UDim2.fromScale(1, 1), ZIndex = 4, ClipsDescendants = true },
        holder
    )
    corner(win, 18)
    new("UIGradient", { Rotation = 90, Color = ColorSequence.new(c3(47, 35, 87), c3(20, 13, 43)) }, win)
    studs(win, 0.7)
    new("UIStroke", { Color = W, Thickness = 5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, win)
    -- header
    local hd =
        new("Frame", { BackgroundColor3 = W, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 78), ZIndex = 5 }, win)
    new("UIGradient", { Rotation = 90, Color = ColorSequence.new(c3(255, 214, 72), c3(230, 140, 0)) }, hd)
    studs(hd, 0.45)
    new("Frame", {
        BackgroundColor3 = K,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 5),
        ZIndex = 6,
    }, hd)
    lbl(hd, "OFFLINE EARNINGS", 38, W, { Size = UDim2.fromScale(1, 1), ZIndex = 7 })
    -- away pill
    local pill = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 98),
        Size = UDim2.fromOffset(0, 36),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = c3(20, 14, 40),
        ZIndex = 6,
    }, win)
    corner(pill, 18)
    new("UIStroke", { Color = W, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, pill)
    new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, pill)
    new("ImageLabel", {
        BackgroundTransparency = 1,
        Image = "rbxassetid://112731802177209",
        ScaleType = Enum.ScaleType.Fit,
        ResampleMode = Enum.ResamplerMode.Pixelated,
        LayoutOrder = 0,
        Size = UDim2.fromOffset(26, 26),
        ZIndex = 8,
    }, pill)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, pill)
    lbl(
        pill,
        "You were away for " .. away(secs),
        17,
        c3(255, 220, 120),
        { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 7 }
    )
    -- hero: glow + coin pile
    local hero = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 140),
        Size = UDim2.fromOffset(300, 150),
        BackgroundTransparency = 1,
        ZIndex = 6,
    }, win)
    local halo = new("ImageLabel", {
        BackgroundTransparency = 1,
        Image = GLOW,
        ImageColor3 = c3(255, 220, 90),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(260, 260),
        ZIndex = 6,
    }, hero)
    TS:Create(
        halo,
        TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { ImageTransparency = 0.35, Size = UDim2.fromOffset(290, 290) }
    ):Play()
    local pile = { { 0, 18, 92 }, { -60, 34, 70 }, { 62, 32, 72 }, { -28, -6, 64 }, { 34, -8, 66 } }
    for i, c in pile do
        local im = new("ImageLabel", {
            BackgroundTransparency = 1,
            Image = COINS,
            ScaleType = Enum.ScaleType.Fit,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, c[1], 0.5, c[2]),
            Size = UDim2.fromOffset(c[3], c[3]),
            ZIndex = 8 + i,
        }, hero)
        TS:Create(
            im,
            TweenInfo.new(1 + i * 0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Position = UDim2.new(0.5, c[1], 0.5, c[2] - 6) }
        ):Play()
    end
    for i = 1, 7 do
        local a = i / 7 * math.pi * 2
        local sp = new("ImageLabel", {
            BackgroundTransparency = 1,
            Image = SPARK,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, math.cos(a) * 140, 0.5, math.sin(a) * 70),
            Size = UDim2.fromOffset(i % 2 == 0 and 14 or 22, i % 2 == 0 and 14 or 22),
            ImageColor3 = i % 2 == 0 and W or c3(255, 230, 140),
            ZIndex = 15,
        }, hero)
        TS:Create(
            sp,
            TweenInfo.new(0.7 + i * 0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { ImageTransparency = 0.85, Rotation = 45 }
        ):Play()
    end
    -- amount (counts up)
    local amt = lbl(
        win,
        "$0",
        72,
        c3(130, 255, 110),
        { Position = UDim2.fromOffset(0, 292), Size = UDim2.new(1, 0, 0, 80), ZIndex = 8 }
    )
    local glowAmt = amt:Clone()
    glowAmt.ZIndex = 7
    glowAmt.TextTransparency = 0.6
    glowAmt:FindFirstChildOfClass("UIStroke").Color = c3(90, 255, 90)
    glowAmt:FindFirstChildOfClass("UIStroke").Thickness = 12
    glowAmt:FindFirstChildOfClass("UIStroke").Transparency = 0.7
    glowAmt.Parent = win
    lbl(
        win,
        "earned while you were away · collect it from your money stands",
        15,
        c3(210, 205, 240),
        { Position = UDim2.fromOffset(0, 370), Size = UDim2.new(1, 0, 0, 20), ZIndex = 8, NoStroke = true }
    )
    task.spawn(function()
        local t0 = os.clock()
        while amt.Parent do
            local p = math.clamp((os.clock() - t0) / 1.2, 0, 1)
            p = 1 - (1 - p) ^ 3
            amt.Text = short(amount * p)
            glowAmt.Text = amt.Text
            if p >= 1 then
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
        TS:Create(fit, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.6 }):Play()
        TS:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
        task.delay(0.22, function()
            gui:Destroy()
        end)
    end
    local function button(text, sub, color, x, w, onClick, pulse)
        local h = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(x, 0, 1, -26),
            Size = UDim2.fromOffset(w, 84),
            BackgroundTransparency = 1,
            ZIndex = 8,
        }, win)
        new("Frame", {
            BackgroundColor3 = K,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 6),
            Size = UDim2.fromScale(1, 1),
            ZIndex = 8,
        }, h).Name =
            "Base"
        corner(h.Base, 14)
        local b = new("TextButton", {
            Text = "",
            AutoButtonColor = false,
            BackgroundColor3 = W,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 9,
            ClipsDescendants = true,
        }, h)
        corner(b, 14)
        new("UIGradient", { Rotation = 90, Color = ColorSequence.new(color:Lerp(W, 0.25), color:Lerp(K, 0.12)) }, b)
        studs(b, 0.55)
        new("UIStroke", { Color = W, Thickness = 3.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
        new("Frame", {
            BackgroundColor3 = W,
            BackgroundTransparency = 0.65,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(10, 6),
            Size = UDim2.new(1, -20, 0, 5),
            ZIndex = 10,
        }, b)
        lbl(b, text, 28, W, {
            Position = UDim2.fromOffset(0, sub and 10 or 0),
            Size = UDim2.new(1, 0, 0, sub and 34 or 84),
            ZIndex = 11,
        })
        if sub then
            lbl(
                b,
                sub,
                16,
                c3(255, 255, 225),
                { Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 22), ZIndex = 11 }
            )
        end
        local sc = new("UIScale", {}, h)
        if pulse then
            TS:Create(
                sc,
                TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { Scale = 1.05 }
            ):Play()
            local g = new("ImageLabel", {
                BackgroundTransparency = 1,
                Image = GLOW,
                ImageColor3 = color,
                ImageTransparency = 0.4,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.new(1, 70, 1, 70),
                ZIndex = 7,
            }, h)
            TS:Create(
                g,
                TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { ImageTransparency = 0.75 }
            ):Play()
        end
        b.MouseEnter:Connect(function()
            UISound.Play("Hover")
        end)
        b.MouseButton1Down:Connect(function()
            b.Position = UDim2.fromOffset(0, 3)
        end)
        b.MouseButton1Up:Connect(function()
            b.Position = UDim2.new()
        end)
        b.Activated:Connect(function()
            UISound.Play("Click")
            onClick()
        end)
        return h
    end
    if canDouble then
        button("COLLECT", short(amount), c3(70, 190, 70), 0.27, 230, close)
        local dbl = button(
            "2× COLLECT",
            short(amount * 2) .. "  ·  R$ " .. tostring(SC.Prices.Offline2x or 19),
            c3(255, 180, 30),
            0.73,
            250,
            function()
                pcall(function()
                    remote:InvokeServer("Buy", "Offline2x")
                end)
            end,
            true
        )
        local tag = new("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 8, 0, 0),
            Size = UDim2.fromOffset(0, 28),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = c3(226, 52, 60),
            Rotation = -6,
            ZIndex = 14,
        }, dbl)
        corner(tag, 8)
        new("UIStroke", { Color = W, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, tag)
        new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, tag)
        lbl(
            tag,
            "2× CASH!",
            15,
            W,
            { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 15 }
        )
        player:GetAttributeChangedSignal("OfflineDoubled"):Connect(function()
            if not player:GetAttribute("OfflineDoubled") or not amt.Parent then
                return
            end
            UISound.Play("Purchase")
            local t0 = os.clock()
            task.spawn(function()
                while amt.Parent do
                    local p = math.clamp((os.clock() - t0) / 0.8, 0, 1)
                    amt.Text = short(amount * (1 + p))
                    glowAmt.Text = amt.Text
                    if p >= 1 then
                        break
                    end
                    task.wait()
                end
            end)
            local fl = new(
                "Frame",
                { BackgroundColor3 = W, BackgroundTransparency = 0.2, Size = UDim2.fromScale(1, 1), ZIndex = 30 },
                win
            )
            TS:Create(fl, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
            task.delay(1.8, close)
        end)
    else
        button("AWESOME!", nil, c3(70, 190, 70), 0.5, 300, close)
    end
    UISound.Play("Open")
end

-- wait for the join sequence (loading screen + sky arrival) to finish, then show
task.spawn(function()
    local t0 = os.clock()
    repeat
        task.wait(0.5)
    until (player:GetAttribute("JoinArrivalFinished") or player:GetAttribute("LoadingScreenDone"))
        or os.clock() - t0 > 20
    task.wait(1.2)
    show()
    player:GetAttributeChangedSignal("OfflineEarnings"):Connect(show)
end)
