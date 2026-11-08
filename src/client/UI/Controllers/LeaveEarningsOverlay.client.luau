-- LeaveEarningsOverlay (LocalScript, Folk Stud look 2026-11-08; old look: ServerStorage._ARCHIVE.LeaveEarningsOverlay_BeforeStud_2026-11-08): when the Roblox menu (Esc) opens, show behind it that the temple keeps earning offline.
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
end

---------------------------------------------------------------- the card, in the Folk Stud look (2026-11-08)
-- A white studded plate at the top of the screen (the Roblox menu covers the middle): "YOUR TEMPLE KEEPS EARNING!"
-- on the top border, the cash stack breaking out over the left edge on spinning gold rays, the offline rate in candy
-- green and the 8 hour cap underneath, with coins raining behind it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FolkStud = require(ReplicatedStorage:WaitForChild("FolkStudUI"))
local H = FolkStud.H
local CASH_ART = "rbxassetid://136807180106184"
local CASH_GREEN = H.hex("2BF08C")
local W, HT = 700, 176

local screenGui = create(
    "ScreenGui",
    { Name = "LeaveEarningsOverlay", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling },
    player:WaitForChild("PlayerGui")
)
local background = create("Frame", { Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1, ZIndex = 0 }, screenGui)
local rain = create("Frame", { Name = "Rain", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 0 }, screenGui)

local root = create("Frame", { Name = "Root", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52), Size = UDim2.fromOffset(W, HT) }, screenGui)
local fitScale = create("UIScale", { Name = "Fit" }, root)
local stage = create("Frame", { Name = "Stage", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(1, 1) }, root)
local popScale = create("UIScale", { Name = "Pop", Scale = 0.6 }, stage)

H.rays(stage, 46, HT / 2 + 4, 300, 1, H.hex("FFD000"))
H.shadow(stage, "Plate", 0, 0, W, HT, 16, 2)
local plate = H.rect(stage, "Plate", 0, 0, W, HT, 14, 2)
H.ink(plate, 4)
H.studs(plate, Vector2.new(50, 46), 0.8, 12, 2)
H.shine(plate, 14, 3)
H.sticker(stage, "Cash", CASH_ART, 46, HT / 2 + 2, 136, 7, true)
H.sparkle(stage, "Twinkle1", 104, 30, 26, 8, 0)
H.sparkle(stage, "Twinkle2", 6, 150, 20, 8, 0.5)
H.gleam(H.text(stage, "Title", "YOUR TEMPLE KEEPS EARNING!", W / 2 + 40, -2, 40, 8))
local rateLabel = H.text(stage, "Rate", "$0/s while you're away", W / 2 + 46, 76, 44, 8, CASH_GREEN)
H.gleam(rateLabel)
local capLabel = H.text(stage, "Cap", "Come back to collect up to $0  ·  max 8 hours", W / 2 + 46, 132, 23, 8, H.hex("FFD000"))
FolkStud.animate(root, { sounds = false })

local isOpen, renderConnection = false, nil
local function spawnFallingCoin()
    local size = math.random(30, 58)
    local coinLabel = create("ImageLabel", {
        BackgroundTransparency = 1,
        Image = math.random() < 0.6 and CASH_ART or COINS_IMAGE,
        ScaleType = Enum.ScaleType.Fit,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(math.random(), 0, 0, -60),
        Size = UDim2.fromOffset(size, size),
        Rotation = math.random(-40, 40),
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
        capLabel.Text = "...they earn cash for you even while you're offline!"
    end
    fitScale.Scale = math.clamp(workspace.CurrentCamera.ViewportSize.X / (W + 260), 0.45, 1.1)
    screenGui.Enabled = true
    popScale.Scale = 0.6
    TweenService:Create(popScale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
    TweenService:Create(background, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.4 }):Play()
    local spawnTimer = 0
    renderConnection = RunService.RenderStepped:Connect(function(dt)
        spawnTimer += dt
        if spawnTimer > 0.14 then
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
    TweenService:Create(popScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.6 }):Play()
    TweenService:Create(background, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
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
