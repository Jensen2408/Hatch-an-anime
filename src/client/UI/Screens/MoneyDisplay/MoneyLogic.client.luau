-- Cash display: panel + coin art from ReplicatedStorage.GameMenuImages (CashPanel / CashCoin),
-- smooth count, +$ popups, coin bounce, shine sweep, income per second.
-- LocalScript inside the MoneyDisplay ScreenGui. Display only: reads leaderstats.Cash and the IncomePerSecond
-- attributes of the local player's PlacedItems (x workspace OwnerIncomeMultiplier). No remotes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UISound = require(ReplicatedStorage:WaitForChild("UISound"))
local player = Players.LocalPlayer
local screenGui = script.Parent
local moneyFrame = screenGui.Money
local face = moneyFrame.Face
local amountLabel = face.Amount
local shineSweep = face.Shine.Sweep
local coinBox = moneyFrame.CoinBox
local coinScale = coinBox.UIScale
local panelScale = moneyFrame.UIScale
local baseScale = 0.68 -- panel scale at rest; layoutMoney switches it to 0.46 on compact screens
panelScale.Scale = baseScale
screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
local function layoutMoney()
    local viewportSize = screenGui.AbsoluteSize
    if viewportSize.X <= 0 or viewportSize.Y <= 0 then
        return
    end
    local compact = math.min(viewportSize.X, viewportSize.Y) < 600
    screenGui.ScreenInsets = compact and Enum.ScreenInsets.CoreUISafeInsets or Enum.ScreenInsets.None
    baseScale = compact and 0.46 or 0.68
    panelScale.Scale = baseScale
    local portrait = compact and viewportSize.X < viewportSize.Y
    if compact then
        -- phones: top-right (bottom-left belongs to the thumbstick)
        moneyFrame.AnchorPoint = Vector2.new(1, 0)
        moneyFrame.Position = UDim2.new(1, portrait and -10 or -184, 0, 0)
    else
        -- desktop: bottom-left, 16 px margins. Anchored at its centre so the UIScale shrink can't shift the
        -- visible (scaled) panel away from the corner.
        local size = moneyFrame.Size
        local scaledWidth = (size.X.Scale * viewportSize.X + size.X.Offset) * baseScale
        local scaledHeight = (size.Y.Scale * viewportSize.Y + size.Y.Offset) * baseScale
        moneyFrame.AnchorPoint = Vector2.new(0.5, 0.5)
        moneyFrame.Position = UDim2.new(0, 16 + scaledWidth / 2, 1, -(16 + scaledHeight / 2))
    end
end

screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutMoney)
moneyFrame:GetPropertyChangedSignal("Size"):Connect(layoutMoney)
layoutMoney()
local incomeText = face.Income.Text
local popupsFrame = moneyFrame.Popups
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
local INK = Color3.fromRGB(40, 24, 18)

local NumberFormat = require(ReplicatedStorage:WaitForChild("CharacterInventory"):WaitForChild("InventoryFormat"))
local function formatShort(value)
    return NumberFormat.Short(value)
end
local function formatFull(value)
    local withCommas = tostring(math.floor(value)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (withCommas:gsub("^,", ""))
end
-- Below 100k the full number with thousands separators, above that the short form (InventoryFormat.Short).
local function formatCash(value)
    return "$" .. (value < 1e5 and formatFull(value) or formatShort(value))
end
local function playTween(instance, duration, goals, easingStyle, easingDirection)
    local tween = TweenService:Create(
        instance,
        TweenInfo.new(duration, easingStyle or Enum.EasingStyle.Quad, easingDirection or Enum.EasingDirection.Out),
        goals
    )
    tween:Play()
    return tween
end

local gameMenuImages = ReplicatedStorage:WaitForChild("GameMenuImages", 10)
local function setArt()
    if not gameMenuImages then
        return
    end
    moneyFrame.Image = gameMenuImages:GetAttribute("CashPanel") or ""
    local coinImage = gameMenuImages:GetAttribute("CashCoin") or ""
    coinBox.Coin.Image = coinImage
    coinBox.CoinShadow.Image = coinImage
end
if gameMenuImages then
    gameMenuImages:GetAttributeChangedSignal("CashPanel"):Connect(setArt)
    gameMenuImages:GetAttributeChangedSignal("CashCoin"):Connect(setArt)
end
setArt()

local function shine(playSound)
    shineSweep.Offset = Vector2.new(-1.5, 0)
    playTween(shineSweep, 0.7, { Offset = Vector2.new(1.5, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    if playSound then
        UISound.Play("Shine", nil, 0.38)
    end
end

local function popup(delta)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.FontFace = FONT
    label.TextSize = 26
    label.ZIndex = 21
    label.Text = (delta > 0 and "+" or "-") .. formatCash(math.abs(delta))
    label.TextColor3 = delta > 0 and Color3.fromRGB(120, 245, 110) or Color3.fromRGB(255, 95, 80)
    label.AutomaticSize = Enum.AutomaticSize.XY
    label.Size = UDim2.new()
    label.AnchorPoint = Vector2.new(1, 1)
    label.Position = UDim2.new(1, math.random(-10, 6), 0, 8)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 3
    stroke.Color = delta > 0 and Color3.fromRGB(20, 70, 25) or INK
    stroke.Parent = label
    label.Parent = popupsFrame
    playTween(label, 0.9, { Position = label.Position - UDim2.fromOffset(0, 44) })
    task.delay(0.5, function()
        playTween(label, 0.4, { TextTransparency = 1 })
        playTween(stroke, 0.4, { Transparency = 1 })
    end)
    task.delay(1, function()
        label:Destroy()
    end)
end

-- shownCash eases toward targetCash every frame; popups are throttled to one per 0.2 s (pendingDelta accumulates).
local shownCash, targetCash = 0, 0
local lastPopupAt, pendingDelta = 0, 0
local startupTime = os.clock()
local preloadChingPlayed = false
task.spawn(function()
    local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")
    shownCash, targetCash = cash.Value, cash.Value
    amountLabel.Text = formatCash(shownCash)
    cash.Changed:Connect(function(newValue)
        local delta = newValue - targetCash
        targetCash = newValue
        if delta == 0 then
            return
        end
        pendingDelta += delta

        -- During startup / preload, ensure exactly ONE cash sound plays
        -- the join sequence (loading, welcome back, offline cash) counts as startup too, so only the first ching plays
        local inPreload = (os.clock() - startupTime < 20) or (player:GetAttribute("StartupSessionReady") ~= true)

        if os.clock() - lastPopupAt > 0.20 then
            lastPopupAt = os.clock()
            popup(pendingDelta)
            if pendingDelta > 0 then
                if inPreload then
                    if false and not preloadChingPlayed then -- startup is silent; the Shine already plays on join
                        preloadChingPlayed = true
                        UISound.Play("CoinChing", 1.0, 0.80)
                    end
                else
                    if pendingDelta >= 500 then
                        UISound.Play("CoinChing", 1.0, 0.80)
                    else
                        UISound.PlayCoinPickup()
                    end
                end
            end
            pendingDelta = 0
        end
        coinScale.Scale = 1.18
        playTween(coinScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
        panelScale.Scale = baseScale * (delta > 0 and 1.04 or 0.97)
        playTween(panelScale, 0.3, { Scale = baseScale }, Enum.EasingStyle.Back)
        if not inPreload and delta > 0 and delta >= math.max(1000, targetCash * 0.1) then
            shine(true)
        end
    end)
end)

local function getIncomePerSecond()
    local total = 0
    for _, plot in workspace:WaitForChild("Plots"):GetChildren() do
        if plot:GetAttribute("OwnerUserId") == player.UserId then
            local placedItems = plot:FindFirstChild("PlacedItems")
            if placedItems then
                for _, item in placedItems:GetChildren() do
                    total += item:GetAttribute("IncomePerSecond") or 0
                end
            end
        end
    end
    return total * (workspace:GetAttribute("OwnerIncomeMultiplier") or 1)
end
task.spawn(function()
    while true do
        incomeText.Text = "+" .. formatCash(getIncomePerSecond()) .. "/sec"
        task.wait(1)
    end
end)
task.spawn(function()
    while true do
        task.wait(7)
        shine(false)
    end
end)

local bobStartTime = os.clock()
RunService.RenderStepped:Connect(function(dt)
    coinBox.Rotation = math.sin((os.clock() - bobStartTime) * 1.6) * 4
    if shownCash ~= targetCash then
        shownCash += (targetCash - shownCash) * math.min(1, dt * 10)
        if math.abs(targetCash - shownCash) < 1 then
            shownCash = targetCash
        end
        amountLabel.Text = formatCash(math.floor(shownCash + 0.5))
    end
end)

-- IncomeShimmer: shine across the green pill + soft glow pulse
local pillSweep = face.Income.Shimmer.Sweep
local pillGlow = face:FindFirstChild("IncomeGlow")
task.spawn(function()
    while true do
        pillSweep.Offset = Vector2.new(-1.5, 0)
        playTween(pillSweep, 0.9, { Offset = Vector2.new(1.5, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(2.6)
    end
end)
if pillGlow then
    RunService.RenderStepped:Connect(function()
        pillGlow.ImageTransparency = 0.72 + math.sin(os.clock() * 2.2) * 0.1
    end)
end
