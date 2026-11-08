--[[ StarterPlayerScripts.UpcomingTeaser  (LocalScript)
"Coming soon" card for the next update or event in ReplicatedStorage.UpcomingConfig: picture, title and a live
countdown, sitting under the top-right HUD. Click it for the full list. When an update's time has passed and it
has WhatsNew lines, a "What's new" window shows once per update Id (player attribute SeenUpdate_<Id>).
Same look as StaffAnnouncements: Fredoka One, ink strokes, rounded card with a soft glow. Display only.
]]
-- ===== 1. Services, config, constants =====
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("UpcomingConfig"))
local HudScale = require(ReplicatedStorage:WaitForChild("HudScale"))
local INK = Color3.fromRGB(17, 23, 26)
local STUDS = "rbxassetid://132561191216691"
local GLOW = "rbxassetid://130563114903838"
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local THEMES = { -- colour name -> { light, dark }
    red = { Color3.fromRGB(255, 95, 95), Color3.fromRGB(210, 35, 45) },
    blue = { Color3.fromRGB(90, 170, 255), Color3.fromRGB(40, 100, 230) },
    tide = { Color3.fromRGB(70, 200, 255), Color3.fromRGB(18, 95, 205) },
    green = { Color3.fromRGB(130, 235, 90), Color3.fromRGB(55, 170, 40) },
    gold = { Color3.fromRGB(255, 215, 70), Color3.fromRGB(240, 140, 0) },
    pink = { Color3.fromRGB(255, 130, 200), Color3.fromRGB(220, 50, 140) },
    purple = { Color3.fromRGB(190, 140, 255), Color3.fromRGB(110, 60, 220) },
}
local CARD = { Width = 262, Height = 76, Right = 14, Top = 92 } -- desktop pixels, times HudScale
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
local DAYS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

local items = table.clone(Config.Items)
table.sort(items, function(a, b)
    return a.Time < b.Time
end)
local function now()
    return workspace:GetServerTimeNow()
end
local function theme(item)
    return THEMES[item.Color] or THEMES.purple
end
local function kindWord(item)
    return item.Kind == "event" and "EVENT" or "UPDATE"
end
local function countdownText(item)
    local left = math.floor(item.Time - now())
    if left <= 0 then
        return item.Kind == "event" and "LIVE NOW!" or "OUT NOW! REJOIN"
    end
    local d, h, m, s = left // 86400, (left // 3600) % 24, (left // 60) % 60, left % 60
    if d > 0 then
        return string.format("%dd %02dh %02dm", d, h, m)
    end
    return string.format("%02dh %02dm %02ds", h, m, s)
end
-- "Fri 6 Nov, 20:00" in the player's local time
local function dateText(item)
    local t = os.date("*t", item.Time)
    return string.format("%s %d %s, %02d:%02d", DAYS[t.wday], t.day, MONTHS[t.month], t.hour, t.min)
end

-- ===== 2. Builders =====
local function make(className, props, parent)
    local o = Instance.new(className)
    for key, value in pairs(props) do
        o[key] = value
    end
    o.Parent = parent
    return o
end
local function round(instance, radius)
    make("UICorner", { CornerRadius = UDim.new(0, radius) }, instance)
end
local function label(parent, text, size, props)
    local l = make("TextLabel", {
        BackgroundTransparency = 1,
        Text = text,
        FontFace = FONT,
        TextSize = size,
        TextColor3 = Color3.new(1, 1, 1),
        TextWrapped = true,
    }, parent)
    make("UIStroke", { Color = INK, Thickness = size >= 24 and 3 or 2 }, l)
    for key, value in pairs(props or {}) do
        l[key] = value
    end
    return l
end
-- dark rounded card with a tinted top, a white/colour edge and a faint stud tile
local function card(parent, colours, props)
    local face = make("Frame", {
        BackgroundColor3 = Color3.fromRGB(14, 10, 28),
        BackgroundTransparency = 0.1,
        ClipsDescendants = true,
    }, parent)
    for key, value in pairs(props or {}) do
        face[key] = value
    end
    round(face, 16)
    local edge = make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3 }, face)
    make("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, colours[1]),
            ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, colours[2]),
        }),
    }, edge)
    local tint = make("Frame", {
        BackgroundColor3 = colours[2],
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
    }, face)
    make("UIGradient", { Transparency = NumberSequence.new(0, 1), Rotation = 90 }, tint)
    make("ImageLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = STUDS,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(24, 24),
        ImageTransparency = 0.8,
    }, face)
    return face
end
local function picture(parent, item, size, zIndex)
    local p = make("ImageLabel", {
        BackgroundColor3 = Color3.new(0, 0, 0),
        Size = UDim2.fromOffset(size, size),
        Image = item.Image,
        ScaleType = Enum.ScaleType.Crop,
        ZIndex = zIndex,
    }, parent)
    round(p, 10)
    make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }, p)
    return p
end
local function pulse(target, prop, from, to, seconds)
    target[prop] = from
    TweenService:Create(target, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { [prop] = to }):Play()
end

-- ===== 3. GUI root and scale =====
local gui = make("ScreenGui", {
    Name = "UpcomingTeaser",
    ResetOnSpawn = false,
    DisplayOrder = 41,
    IgnoreGuiInset = false,
    ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
}, player:WaitForChild("PlayerGui"))
local root = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
local scale = make("UIScale", {}, root)
local function fit()
    scale.Scale = HudScale.For(gui.AbsoluteSize)
    root.Size = UDim2.fromScale(1 / scale.Scale, 1 / scale.Scale)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

-- ===== 4. Full list window =====
local listWindow
local function closeList()
    if listWindow then
        listWindow:Destroy()
        listWindow = nil
    end
end
local function openList()
    if listWindow then
        return
    end
    local dim = make("TextButton", {
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.45,
        Size = UDim2.new(1, 0, 1, 80),
        Position = UDim2.fromOffset(0, -40),
        ZIndex = 20,
    }, root)
    listWindow = dim
    local rowHeight, pad = 118, 14
    local height = 96 + #items * (rowHeight + pad)
    local win = card(dim, THEMES.purple, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 20),
        Size = UDim2.fromOffset(560, height),
        ZIndex = 21,
    })
    local winScale = make("UIScale", { Scale = 0.85 }, win)
    TweenService:Create(winScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
    label(win, "✨ COMING SOON ✨", 32, { Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 40), ZIndex = 24 })
    for i, item in ipairs(items) do
        local colours = theme(item)
        local row = card(win, colours, {
            Position = UDim2.fromOffset(20, 72 + (i - 1) * (rowHeight + pad)),
            Size = UDim2.new(1, -40, 0, rowHeight),
            ZIndex = 22,
        })
        picture(row, item, 94, 25).Position = UDim2.fromOffset(12, 12)
        label(row, kindWord(item) .. " · " .. dateText(item), 15, {
            Position = UDim2.fromOffset(120, 10),
            Size = UDim2.new(1, -132, 0, 18),
            TextColor3 = colours[1],
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 25,
        })
        label(row, item.Title, 28, {
            Position = UDim2.fromOffset(120, 28),
            Size = UDim2.new(1, -132, 0, 34),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextScaled = true,
            ZIndex = 25,
        })
        label(row, item.Subtitle or "", 16, {
            Position = UDim2.fromOffset(120, 62),
            Size = UDim2.new(1, -132, 0, 20),
            TextColor3 = Color3.fromRGB(220, 215, 240),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 25,
        })
        local cd = label(row, countdownText(item), 20, {
            Position = UDim2.fromOffset(120, 84),
            Size = UDim2.new(1, -132, 0, 24),
            TextColor3 = Color3.fromRGB(255, 240, 170),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 25,
        })
        task.spawn(function()
            while cd.Parent do
                cd.Text = countdownText(item)
                task.wait(1)
            end
        end)
    end
    local closeButton = make("TextButton", {
        Text = "",
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 12),
        Size = UDim2.fromOffset(40, 40),
        BackgroundColor3 = Color3.fromRGB(235, 60, 70),
        ZIndex = 26,
    }, win)
    round(closeButton, 10)
    make("UIStroke", { Color = INK, Thickness = 3 }, closeButton)
    label(closeButton, "X", 24, { Size = UDim2.fromScale(1, 1), ZIndex = 27 })
    closeButton.Activated:Connect(closeList)
    dim.Activated:Connect(closeList)
end

-- ===== 5. Countdown card (next item that has not happened yet) =====
local function nextItem()
    for _, item in ipairs(items) do
        if now() < item.Time then
            return item
        end
    end
end
local cardHolder
local function buildCard(item)
    if cardHolder then
        cardHolder:Destroy()
    end
    local colours = theme(item)
    local holder = make("TextButton", {
        Text = "",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -CARD.Right, 0, CARD.Top),
        Size = UDim2.fromOffset(CARD.Width, CARD.Height),
    }, root)
    cardHolder = holder
    local glow = make("ImageLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 90, 1, 90),
        Image = GLOW,
        ImageColor3 = colours[1],
    }, holder)
    pulse(glow, "ImageTransparency", 0.55, 0.85, 1.2)
    local face = card(holder, colours, { Size = UDim2.fromScale(1, 1), ZIndex = 2 })
    picture(face, item, CARD.Height - 18, 4).Position = UDim2.fromOffset(9, 9)
    local left = CARD.Height + 2
    label(face, kindWord(item) .. " IN", 13, {
        Position = UDim2.fromOffset(left, 7),
        Size = UDim2.new(1, -left - 8, 0, 16),
        TextColor3 = colours[1],
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 5,
    })
    label(face, item.Title, 22, {
        Position = UDim2.fromOffset(left, 22),
        Size = UDim2.new(1, -left - 8, 0, 26),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextScaled = true,
        ZIndex = 5,
    })
    local cd = label(face, countdownText(item), 18, {
        Position = UDim2.fromOffset(left, 48),
        Size = UDim2.new(1, -left - 8, 0, 22),
        TextColor3 = Color3.fromRGB(255, 240, 170),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 5,
    })
    -- hover: lift a little
    local hoverScale = make("UIScale", {}, holder)
    holder.MouseEnter:Connect(function()
        TweenService:Create(hoverScale, TweenInfo.new(0.12), { Scale = 1.05 }):Play()
    end)
    holder.MouseLeave:Connect(function()
        TweenService:Create(hoverScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
    end)
    holder.Activated:Connect(openList)
    task.spawn(function()
        while holder.Parent do
            cd.Text = countdownText(item)
            if now() >= item.Time then
                task.wait(15) -- show "OUT NOW" for a bit, then move on to the next one
                local following = nextItem()
                if holder.Parent then
                    if following then
                        buildCard(following)
                    else
                        holder:Destroy()
                    end
                end
                return
            end
            task.wait(1)
        end
    end)
end
local first = nextItem()
if first and Config.ShowCard ~= false then -- the corner card is off while the in-world board is used
    buildCard(first)
end

-- ===== 6. "What's new" window after an update launches (once per Id) =====
for _, item in ipairs(items) do
    local lines = item.WhatsNew
    if item.Kind == "update" and now() >= item.Time and lines and #lines > 0 and player:GetAttribute("SeenUpdate_" .. item.Id) == nil then
        player:SetAttribute("SeenUpdate_" .. item.Id, true)
        task.delay(6, function() -- let the join intro finish
            local colours = theme(item)
            local dim = make("TextButton", {
                Text = "",
                AutoButtonColor = false,
                BackgroundColor3 = Color3.new(0, 0, 0),
                BackgroundTransparency = 0.45,
                Size = UDim2.new(1, 0, 1, 80),
                Position = UDim2.fromOffset(0, -40),
                ZIndex = 30,
            }, root)
            local height = 190 + #lines * 36
            local win = card(dim, colours, {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 20),
                Size = UDim2.fromOffset(540, height),
                ZIndex = 31,
            })
            local winScale = make("UIScale", { Scale = 0.85 }, win)
            TweenService:Create(winScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
            picture(win, item, 72, 34).Position = UDim2.fromOffset(18, 14)
            label(win, "✨ WHAT'S NEW ✨", 30, { Position = UDim2.fromOffset(100, 14), Size = UDim2.new(1, -118, 0, 36), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 34 })
            label(win, item.Title, 22, { Position = UDim2.fromOffset(100, 52), Size = UDim2.new(1, -118, 0, 28), TextColor3 = colours[1], TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 34 })
            for i, line in ipairs(lines) do
                label(win, line, 18, {
                    Position = UDim2.fromOffset(26, 104 + (i - 1) * 36),
                    Size = UDim2.new(1, -52, 0, 32),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 34,
                })
            end
            local ok = make("TextButton", {
                Text = "",
                AutoButtonColor = false,
                AnchorPoint = Vector2.new(0.5, 1),
                Position = UDim2.new(0.5, 0, 1, -16),
                Size = UDim2.fromOffset(190, 48),
                BackgroundColor3 = Color3.fromRGB(67, 220, 78),
                ZIndex = 34,
            }, win)
            round(ok, 10)
            make("UIStroke", { Color = INK, Thickness = 3 }, ok)
            label(ok, "LET'S GO!", 24, { Size = UDim2.fromScale(1, 1), ZIndex = 35 })
            local function close()
                dim:Destroy()
            end
            ok.Activated:Connect(close)
            dim.Activated:Connect(close)
        end)
    end
end
