--[[ StarterPlayerScripts.NighttimeHUD (LocalScript)
Top-right Nighttime indicator + announcements. Reads the server's workspace attributes
(NighttimeActive / NighttimeEndsAt / NighttimeNextAt, written by NighttimeService) and server time,
so every player is in sync. Purely visual: no remotes.
States: countdown pill -> (last 10s) expanded "APPROACHING" -> big start card -> active bar -> "DAYLIGHT RETURNS" -> countdown.
The bonus text (3x cash / 2x hatch / 3x luck) and DURATION mirror NighttimeService; keep them in sync by hand.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local _GuiService = game:GetService("GuiService") -- unused; GetService kept (no behaviour change)
local player = Players.LocalPlayer

local INDIGO, VIOLET, CYAN, GOLD, MOON =
    Color3.fromRGB(24, 22, 58),
    Color3.fromRGB(128, 104, 220),
    Color3.fromRGB(140, 222, 255),
    Color3.fromRGB(242, 190, 85),
    Color3.fromRGB(235, 238, 255)
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local DURATION = 20 -- night length in seconds (NighttimeService)
local CYCLE_SECONDS = 300 -- a night starts every 5 minutes (NighttimeService)

-- create(className, props, parent?): new instance with `props` applied, parented last
local function create(className, props, parent)
    local instance = Instance.new(className)
    for property, value in props do
        instance[property] = value
    end
    if parent then
        instance.Parent = parent
    end
    return instance
end
local function playTween(instance, duration, props, easingStyle)
    local tween = TweenService:Create(
        instance,
        TweenInfo.new(duration, easingStyle or Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        props
    )
    tween:Play()
    return tween
end

local gui = create(
    "ScreenGui",
    { Name = "NighttimeHUD", ResetOnSpawn = false, DisplayOrder = 40, ZIndexBehavior = Enum.ZIndexBehavior.Sibling },
    player:WaitForChild("PlayerGui")
)

-- Rounded indigo CanvasGroup (starts hidden); returns the frame and its UIStroke.
local function makePanel(name, size)
    local frame = create("CanvasGroup", {
        Name = name,
        AnchorPoint = Vector2.new(1, 0),
        Size = size,
        BackgroundColor3 = INDIGO,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        Visible = false,
    }, gui)
    create("UICorner", { CornerRadius = UDim.new(0, 14) }, frame)
    -- soft top sheen as its own layer (a UIGradient on a CanvasGroup would tint the text too)
    local sheen = create("Frame", {
        Size = UDim2.fromScale(1, 0.5),
        BackgroundColor3 = Color3.fromRGB(70, 62, 140),
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        ZIndex = 0,
    }, frame)
    create("UICorner", { CornerRadius = UDim.new(0, 14) }, sheen)
    local stroke = create("UIStroke", { Color = VIOLET, Thickness = 1.5, Transparency = 0.15 }, frame)
    return frame, stroke
end
local function makeLabel(parent, text, textSize, color, props)
    local label = create(
        "TextLabel",
        { BackgroundTransparency = 1, FontFace = FONT, TextSize = textSize, TextColor3 = color, Text = text },
        parent
    )
    for property, value in props or {} do
        label[property] = value
    end
    return label
end

-- compact pill (countdown / active)
local pill = makePanel("Pill", UDim2.fromOffset(250, 40))
local moon = create("Frame", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 12, 0.5, -2),
    Size = UDim2.fromOffset(20, 20),
    BackgroundColor3 = MOON,
}, pill)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, moon)
local bite = create("Frame", {
    Position = UDim2.fromOffset(7, -3),
    Size = UDim2.fromOffset(20, 20),
    BackgroundColor3 = Color3.fromRGB(40, 35, 92),
}, moon) -- crescent
create("UICorner", { CornerRadius = UDim.new(1, 0) }, bite)
local pillText = makeLabel(
    pill,
    "",
    17,
    MOON,
    { Position = UDim2.new(0, 40, 0, 0), Size = UDim2.new(1, -52, 1, -6), TextXAlignment = Enum.TextXAlignment.Left }
)
local pillBonus = makeLabel(pill, "3× CASH • 2× HATCH • 3× LUCK", 11, CYAN, {
    Position = UDim2.new(0, 40, 0, 22),
    Size = UDim2.new(1, -52, 0, 12),
    TextXAlignment = Enum.TextXAlignment.Left,
    Visible = false,
})
local track = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -4),
    Size = UDim2.new(1, -24, 0, 3),
    BackgroundColor3 = Color3.fromRGB(60, 56, 120),
    BorderSizePixel = 0,
}, pill)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
local bar = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = CYAN, BorderSizePixel = 0 }, track)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, bar)
local _barGradient = create("UIGradient", { Color = ColorSequence.new(CYAN, VIOLET) }, bar)
local goldDot = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(1, -12, 0.5, -2),
    Size = UDim2.fromOffset(5, 5),
    Rotation = 45,
    BackgroundColor3 = GOLD,
    BorderSizePixel = 0,
}, pill)
local pillScale = create("UIScale", {}, pill)
create("UIScale", {}, gui):Destroy() -- no-op leftover; kept to preserve instance creation order

-- big announcement card (same top-right anchor as the pill)
local big, bigStroke = makePanel("Announcement", UDim2.fromOffset(330, 104))
local bigScale = create("UIScale", {}, big)
local bigTitle = makeLabel(big, "", 26, MOON, { Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 40) })
local bigSub = makeLabel(big, "", 16, GOLD, { Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 20) })
local bigBonus = makeLabel(big, "", 12, CYAN, { Position = UDim2.fromOffset(0, 82), Size = UDim2.new(1, 0, 0, 18) })
for _, xScale in { 0.08, 0.92 } do
    create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(xScale, 0.3),
        Size = UDim2.fromOffset(6, 6),
        Rotation = 45,
        BackgroundColor3 = GOLD,
        BorderSizePixel = 0,
    }, big)
end
create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 52),
    Size = UDim2.fromOffset(120, 1),
    BackgroundColor3 = GOLD,
    BackgroundTransparency = 0.4,
    BorderSizePixel = 0,
}, big)

-- ScreenGui already excludes the top bar and hardware safe area.
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
-- shrink both panels on small screens (never scale above 1)
local function layout()
    local screenSize = gui.AbsoluteSize
    if screenSize.X <= 0 or screenSize.Y <= 0 then
        return
    end
    local uiScale = math.min(1, screenSize.X / 600, screenSize.Y / 560)
    pillScale.Scale = uiScale
    bigScale.Scale = uiScale
    pill.Position = UDim2.new(1, -10, 0, 10)
    big.Position = UDim2.new(1, -10, 0, 10)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
layout()

-- Fades a panel in/out; hides it once fully transparent (unless it was faded back in meanwhile).
local function show(frame, visible, duration)
    if visible then
        frame.Visible = true
    end
    local fadeTween = playTween(frame, duration or 0.35, { GroupTransparency = visible and 0 or 1 })
    if not visible then
        fadeTween.Completed:Once(function()
            if frame.GroupTransparency > 0.99 then
                frame.Visible = false
            end
        end)
    end
end
local function resizePill(width, height)
    playTween(pill, 0.35, { Size = UDim2.fromOffset(width, height) })
end

-- "MM:SS", rounded up, never negative
local function formatClock(seconds)
    seconds = math.max(0, math.ceil(seconds))
    return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

local mode -- "countdown" | "approach" | "active" | nil
-- Runs the one-shot transition into `newMode`. Delayed steps re-check `mode` so a newer state wins.
local function setMode(newMode)
    if newMode == mode then
        return
    end
    local previousMode = mode
    mode = newMode
    if newMode == "countdown" then
        if previousMode == "active" then -- daylight returns transition
            bigTitle.Text = "DAYLIGHT RETURNS"
            bigTitle.TextColor3 = Color3.fromRGB(255, 226, 160)
            bigSub.Text = "Bonuses have ended"
            bigBonus.Text = ""
            show(pill, false, 0.25)
            big.Position = big.Position - UDim2.fromOffset(0, 10)
            show(big, true, 0.35)
            playTween(big, 0.4, { Position = big.Position + UDim2.fromOffset(0, 10) })
            task.delay(2.2, function()
                if mode == "countdown" then
                    show(big, false, 0.4)
                    task.delay(0.3, function()
                        if mode == "countdown" then
                            show(pill, true)
                        end
                    end)
                end
            end)
        else
            show(big, false)
            show(pill, true)
        end
        pillBonus.Visible = false
        resizePill(250, 40)
        goldDot.Visible = true
    elseif newMode == "approach" then
        show(pill, false, 0.25)
        bigTitle.Text = "NIGHTTIME APPROACHING"
        bigTitle.TextColor3 = MOON
        bigBonus.Text = "3× CASH  •  2× HATCH SPEED  •  3× RIVER LUCK"
        big.Position = big.Position - UDim2.fromOffset(0, 12)
        show(big, true, 0.4)
        playTween(big, 0.45, { Position = big.Position + UDim2.fromOffset(0, 12) })
    elseif newMode == "active" then
        bigTitle.Text = "NIGHTTIME"
        bigTitle.TextColor3 = MOON
        bigSub.Text = DURATION .. " SECONDS OF BONUS REWARDS"
        bigBonus.Text = "3× CASH  •  2× HATCH SPEED  •  3× RIVER LUCK"
        local fresh = previousMode == "approach" or previousMode == "countdown"
        local now = workspace:GetServerTimeNow()
        local secondsLeft = (workspace:GetAttribute("NighttimeEndsAt") or now) - now
        pillBonus.Visible = true
        goldDot.Visible = false
        resizePill(270, 52)
        -- big start card only if we saw night begin (not when joining / forced mid-event)
        if fresh and secondsLeft > DURATION - 3 then
            show(pill, false, 0.2)
            show(big, true, 0.3)
            bigScale.Scale = bigScale.Scale * 1.06
            playTween(bigScale, 0.5, { Scale = bigScale.Scale / 1.06 }, Enum.EasingStyle.Back)
            task.delay(2.6, function()
                if mode == "active" then
                    show(big, false, 0.45)
                    task.delay(0.25, function()
                        if mode == "active" then
                            show(pill, true)
                        end
                    end)
                end
            end)
        else -- joined mid-event: go straight to the compact bar
            show(big, false, 0.2)
            show(pill, true)
        end
    end
end

-- 20 Hz update
local throttleTimer = 0
RunService.RenderStepped:Connect(function(dt)
    throttleTimer += dt
    if throttleTimer < 0.05 then
        return
    end
    throttleTimer = 0
    local now = workspace:GetServerTimeNow()
    local active = workspace:GetAttribute("NighttimeActive") == true
    -- fallback mirrors NighttimeService's 300 s cycle
    local nextAt = workspace:GetAttribute("NighttimeNextAt") or (math.floor(now / CYCLE_SECONDS) + 1) * CYCLE_SECONDS
    if active then
        local secondsLeft = math.max(0, (workspace:GetAttribute("NighttimeEndsAt") or now) - now)
        setMode("active")
        pillText.Text = "NIGHTTIME • " .. formatClock(secondsLeft)
        pillText.Size = UDim2.new(1, -52, 0, 24)
        pillText.Position = UDim2.fromOffset(40, 2)
        bar.Size = UDim2.fromScale(math.clamp(secondsLeft / DURATION, 0, 1), 1)
    else
        local untilNight = nextAt - now
        if untilNight <= 10 and untilNight > 0 then
            setMode("approach")
            bigSub.Text = "Begins in " .. math.ceil(untilNight) .. "s"
            bigStroke.Thickness = untilNight <= 3 and (1.5 + math.abs(math.sin(now * math.pi)) * 2) or 1.5
            if untilNight <= 3 then
                bigScale.Scale = pillScale.Scale * (1 + math.abs(math.sin(now * math.pi)) * 0.025)
            end
        else
            setMode("countdown")
            pillText.Text = "NIGHTTIME IN " .. formatClock(untilNight)
            pillText.Size = UDim2.new(1, -52, 1, -6)
            pillText.Position = UDim2.fromOffset(40, 0)
            bar.Size = UDim2.fromScale(math.clamp(1 - untilNight / (CYCLE_SECONDS - DURATION), 0, 1), 1)
        end
    end
end)
