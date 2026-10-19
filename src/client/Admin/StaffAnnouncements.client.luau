--[[ StarterPlayerScripts.StaffAnnouncements  (LocalScript)
Announcement banner (staff announcements, events, /update). Rounded 3D card in the game's clean style: no pill studs.
/update countdown ticks update ONE banner in place instead of stacking five.

Remote: ReplicatedStorage.OwnerPanel.Announcement (RemoteEvent, server -> client), fired by OwnerPanelServer and
CrossServerService. Payload (all optional): { title, text, color = "red"|"blue"|"green"|"gold"|"pink"|"purple",
by = sender display name ("Server" hides the byline), byId = UserId (avatar), style = "chat", isUpdate = true }.
Unknown colours fall back to red. Display only: nothing here is trusted for gameplay.
Queue: one banner at a time; up to 3 more wait in bannerQueue, extra ones are dropped.
]]
-- ===== 1. Services, constants and GUI root =====
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local announcementEvent = ReplicatedStorage:WaitForChild("OwnerPanel"):WaitForChild("Announcement")
local INK = Color3.fromRGB(17, 23, 26)
local STUDS = "rbxassetid://132561191216691"
local GLOW = "rbxassetid://130563114903838"
-- colour name -> { light colour, dark colour, icon }
local THEMES = {
    red = { Color3.fromRGB(255, 95, 95), Color3.fromRGB(210, 35, 45), "📢" },
    blue = { Color3.fromRGB(90, 170, 255), Color3.fromRGB(40, 100, 230), "📢" },
    green = { Color3.fromRGB(130, 235, 90), Color3.fromRGB(55, 170, 40), "✅" },
    gold = { Color3.fromRGB(255, 215, 70), Color3.fromRGB(240, 140, 0), "⭐" },
    pink = { Color3.fromRGB(255, 130, 200), Color3.fromRGB(220, 50, 140), "💬" },
    purple = { Color3.fromRGB(190, 140, 255), Color3.fromRGB(110, 60, 220), "🌙" },
}
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local gui = Instance.new("ScreenGui")
gui.Name = "StaffAnnouncements"
gui.ResetOnSpawn = false
gui.DisplayOrder = 60
gui.IgnoreGuiInset = true
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

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
local function makeLabel(parent, text, size, props)
    local textLabel = make("TextLabel", {
        BackgroundTransparency = 1,
        Text = text,
        FontFace = FONT,
        TextSize = size,
        TextColor3 = Color3.new(1, 1, 1),
        TextWrapped = true,
    }, parent)
    make("UIStroke", { Color = INK, Thickness = size >= 24 and 3 or 2 }, textLabel)
    for key, value in pairs(props or {}) do
        textLabel[key] = value
    end
    return textLabel
end

-- ===== 3. Banner layouts =====
-- Both builders return { holder, body, fill, title, update } (update = this banner can be refreshed in place).
local bannerQueue, currentBanner = {}, nil
-- chat-style staff message (like big games' admin messages): avatar · Name ✓ : message, sliding in at the top
local function buildChatBanner(data)
    local theme = THEMES[data.color] or THEMES.red
    local width, height = 700, 86
    local holder = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, -170),
        Size = UDim2.fromOffset(width, height),
        BackgroundTransparency = 1,
    }, gui)
    make("UIScale", { Scale = math.clamp((workspace.CurrentCamera.ViewportSize.X - 24) / width, 0.5, 1) }, holder)
    local glow = make("ImageLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 120, 1, 120),
        Image = GLOW,
        ImageColor3 = theme[1],
        ImageTransparency = 0.55,
    }, holder)
    TweenService:Create(
        glow,
        TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { ImageTransparency = 0.8 }
    ):Play()
    local face = make("Frame", {
        BackgroundColor3 = Color3.fromRGB(14, 10, 28),
        BackgroundTransparency = 0.12,
        Size = UDim2.fromScale(1, 1),
        ClipsDescendants = true,
    }, holder)
    round(face, 22)
    local edge = make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3 }, face)
    local edgeGradient = make("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, theme[1]),
            ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, theme[2]),
        }),
    }, edge)
    TweenService
        :Create(
            edgeGradient,
            TweenInfo.new(2.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
            { Rotation = 360 }
        )
        :Play()
    local tint = make("Frame", {
        BackgroundColor3 = theme[2],
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
    }, face)
    make("UIGradient", { Transparency = NumberSequence.new(0, 1) }, tint)
    local sweep = make(
        "Frame",
        { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) },
        face
    )
    local sweepGradient = make("UIGradient", {
        Rotation = 20,
        Offset = Vector2.new(-1.2, 0),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.45, 1),
            NumberSequenceKeypoint.new(0.5, 0.6),
            NumberSequenceKeypoint.new(0.55, 1),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, sweep)
    TweenService:Create(
        sweepGradient,
        TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, -1, false, 1.8),
        { Offset = Vector2.new(1.2, 0) }
    ):Play()
    -- avatar
    local avatar = make("ImageLabel", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 14, 0.5, 0),
        Size = UDim2.fromOffset(62, 62),
        BackgroundColor3 = theme[2],
    }, face)
    round(avatar, 99)
    make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3 }, avatar)
    if data.byId then
        task.spawn(function()
            local ok, imageUrl = pcall(function()
                return Players:GetUserThumbnailAsync(
                    data.byId,
                    Enum.ThumbnailType.HeadShot,
                    Enum.ThumbnailSize.Size150x150
                )
            end)
            if ok then
                avatar.Image = imageUrl
            end
        end)
    end
    -- name ✓ : message
    local headerLine = make("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(90, 10),
        Size = UDim2.new(1, -104, 0, 26),
        RichText = true,
        FontFace = FONT,
        TextSize = 24,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Color3.new(1, 1, 1),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = '<font color="#'
            .. theme[1]:ToHex()
            .. '">'
            .. tostring(data.by or "Staff")
            .. '</font> <font color="#4FC3FF">✔</font>  <font size="15" color="#FFFFFF">'
            .. tostring(data.title or "")
            .. "</font>",
    }, face)
    make("UIStroke", { Color = INK, Thickness = 2.5 }, headerLine)
    local body = makeLabel(face, tostring(data.text or ""), 22, {
        Position = UDim2.fromOffset(90, 38),
        Size = UDim2.new(1, -104, 0, 36),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextScaled = true,
    })
    make("UITextSizeConstraint", { MaxTextSize = 22 }, body)
    local trough = make("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 90, 1, -6),
        Size = UDim2.new(1, -104, 0, 4),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.5,
    }, face)
    round(trough, 99)
    local fill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = theme[1] }, trough)
    round(fill, 99)
    TweenService:Create(holder, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 58) })
        :Play()
    return { holder = holder, body = body, fill = fill, title = headerLine, update = false }
end
-- Default 3D card (also used for /update countdown ticks).
local function buildBanner(data)
    if data.style == "chat" then
        return buildChatBanner(data)
    end
    local theme = THEMES[data.color] or THEMES.red
    local isUpdate = data.isUpdate == true
    local width, height = 640, isUpdate and 132 or 118
    local holder = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, -170),
        Size = UDim2.fromOffset(width, height),
        BackgroundTransparency = 1,
    }, gui)
    make("UIScale", { Scale = math.clamp((workspace.CurrentCamera.ViewportSize.X - 24) / width, 0.5, 1) }, holder)
    -- 3D base
    local base = make("Frame", {
        BackgroundColor3 = theme[2]:Lerp(Color3.new(), 0.45),
        Position = UDim2.fromOffset(0, 8),
        Size = UDim2.new(1, 0, 1, -8),
    }, holder)
    round(base, 20)
    make("UIStroke", { Color = INK, Thickness = 3.5 }, base)
    local face = make(
        "Frame",
        { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 1, -8), ClipsDescendants = true },
        holder
    )
    round(face, 20)
    make("UIStroke", { Color = INK, Thickness = 3.5 }, face)
    make("UIGradient", { Rotation = 90, Color = ColorSequence.new(theme[1], theme[2]) }, face)
    local studs = make("ImageLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = STUDS,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(26, 26),
        ImageTransparency = 0.15,
    }, face)
    round(studs, 20)
    local gloss = make("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.65,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(18, 6),
        Size = UDim2.new(1, -36, 0, 5),
    }, face)
    round(gloss, 99)
    -- shine sweep
    local sweep = make(
        "Frame",
        { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) },
        face
    )
    round(sweep, 20)
    local sweepGradient = make("UIGradient", {
        Rotation = 20,
        Offset = Vector2.new(-1.2, 0),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.44, 1),
            NumberSequenceKeypoint.new(0.5, 0.45),
            NumberSequenceKeypoint.new(0.56, 1),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, sweep)
    TweenService:Create(
        sweepGradient,
        TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, -1, false, 1.6),
        { Offset = Vector2.new(1.2, 0) }
    ):Play()
    -- icon badge
    local badge = make("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 16, 0.5, -4),
        Size = UDim2.fromOffset(74, 74),
        BackgroundColor3 = theme[2]:Lerp(Color3.new(), 0.35),
    }, face)
    round(badge, 18)
    make("UIStroke", { Color = INK, Thickness = 3 }, badge)
    local glow = make("ImageLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1.6, 1.6),
        Image = GLOW,
        ImageColor3 = theme[1],
        ImageTransparency = 0.35,
    }, badge)
    TweenService
        :Create(glow, TweenInfo.new(8, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
        :Play()
    local icon = make("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = isUpdate and "🚨" or theme[3],
        TextSize = 40,
        FontFace = FONT,
    }, badge)
    local bob = make("UIScale", {}, icon)
    TweenService
        :Create(bob, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.12 })
        :Play()
    -- text
    local title = makeLabel(face, tostring(data.title or ""), 28, {
        Position = UDim2.fromOffset(104, 12),
        Size = UDim2.new(1, -120, 0, 34),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextScaled = true,
    })
    make("UITextSizeConstraint", { MaxTextSize = 28 }, title)
    local body = makeLabel(face, tostring(data.text or ""), 19, {
        Position = UDim2.fromOffset(104, 48),
        Size = UDim2.new(1, -120, 0, isUpdate and 34 or 42),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    })
    local byLabel = data.by
            and data.by ~= "Server"
            and makeLabel(face, "— " .. tostring(data.by), 13, {
                AnchorPoint = Vector2.new(1, 1),
                Position = UDim2.new(1, -16, 1, -8),
                Size = UDim2.fromOffset(240, 16),
                TextXAlignment = Enum.TextXAlignment.Right,
                TextColor3 = Color3.fromRGB(240, 240, 240),
            })
        or nil
    -- time bar
    local trough = make("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 104, 1, -12),
        Size = UDim2.new(1, byLabel and -372 or -124, 0, 8),
        BackgroundColor3 = Color3.fromRGB(20, 30, 36),
        BackgroundTransparency = 0.2,
    }, face)
    round(trough, 99)
    local fill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1) }, trough)
    round(fill, 99)
    TweenService:Create(holder, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 64) })
        :Play()
    return { holder = holder, body = body, fill = fill, title = title, update = isUpdate }
end

-- ===== 4. Queue and playback =====
local function hideBanner(banner)
    TweenService:Create(
        banner.holder,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = UDim2.new(0.5, 0, 0, -170) }
    ):Play()
    task.wait(0.32)
    banner.holder:Destroy()
end
-- Shows one banner for its duration (until_ can be pushed back by countdown ticks), then the next queued one.
local function playBanner(data)
    currentBanner = buildBanner(data)
    local duration = data.isUpdate and 1.3 or (data.style == "chat" and 7 or 5.5)
    currentBanner.until_ = os.clock() + duration
    TweenService
        :Create(currentBanner.fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) })
        :Play()
    while os.clock() < currentBanner.until_ do
        task.wait(0.1)
    end
    local finished = currentBanner
    currentBanner = nil
    hideBanner(finished)
    if #bannerQueue > 0 then
        task.spawn(playBanner, table.remove(bannerQueue, 1))
    end
end
announcementEvent.OnClientEvent:Connect(function(data)
    if type(data) ~= "table" then
        return
    end
    -- /update countdown: refresh the banner that is already showing
    if data.isUpdate and currentBanner and currentBanner.update then
        currentBanner.body.Text = tostring(data.text or "")
        currentBanner.title.Text = tostring(data.title or currentBanner.title.Text)
        currentBanner.until_ = os.clock() + 1.3
        currentBanner.fill.Size = UDim2.fromScale(1, 1)
        TweenService
            :Create(currentBanner.fill, TweenInfo.new(1.3, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) })
            :Play()
        return
    end
    if currentBanner then
        if #bannerQueue < 3 then
            table.insert(bannerQueue, data)
        end
    else
        task.spawn(playBanner, data)
    end
end)
