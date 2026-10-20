-- Cash display: the Cash UI (CashComponent / CashConfig) + smooth count, +$ popups, coin sounds, income per second.
-- LocalScript inside the MoneyDisplay ScreenGui. Display only: reads leaderstats.Cash and the IncomePerSecond
-- attributes of the local player's PlacedItems (x workspace OwnerIncomeMultiplier). No remotes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UISound = require(ReplicatedStorage:WaitForChild("UISound"))
local CashComponent = require(script.Parent:WaitForChild("CashComponent"))
local CashConfig = require(script.Parent:WaitForChild("CashConfig"))
local player = Players.LocalPlayer
local screenGui = script.Parent
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global -- CashComponent orders its layers with global ZIndex

-- the old Studio-built "Money" panel is replaced by CashComponent
local legacyPanel = screenGui:FindFirstChild("Money")
if legacyPanel then
    legacyPanel:Destroy()
end
local cashUI = CashComponent.new(screenGui)
local root = cashUI.Root

-- +$ popups float above the panel in their own layer, laid out exactly like the Cash UI root
local popupsFrame = Instance.new("Frame")
popupsFrame.Name = "CashPopups"
popupsFrame.BackgroundTransparency = 1
popupsFrame.Size = root.Size
local popupsScale = Instance.new("UIScale")
popupsScale.Parent = popupsFrame
popupsFrame.Parent = screenGui

local function layoutCash()
    local viewportSize = screenGui.AbsoluteSize
    if viewportSize.X <= 0 or viewportSize.Y <= 0 then
        return
    end
    local compact = math.min(viewportSize.X, viewportSize.Y) < CashConfig.CompactBreakpoint
    screenGui.ScreenInsets = compact and Enum.ScreenInsets.CoreUISafeInsets or Enum.ScreenInsets.None
    local scale = compact and CashConfig.Scale.Compact or CashConfig.Scale.Desktop
    local portrait = compact and viewportSize.X < viewportSize.Y
    local anchorPoint, position
    if compact then
        -- phones: top-right (bottom-left belongs to the thumbstick)
        anchorPoint = Vector2.new(1, 0)
        position = UDim2.new(1, portrait and -10 or -184, 0, 0)
    else
        -- desktop: bottom-left, 16 px margins. Anchored at its centre so the UIScale shrink can't shift the
        -- visible (scaled) panel away from the corner.
        local scaledWidth = CashConfig.RootSize.X * scale
        local scaledHeight = CashConfig.RootSize.Y * scale
        anchorPoint = Vector2.new(0.5, 0.5)
        position = UDim2.new(0, 16 + scaledWidth / 2, 1, -(16 + scaledHeight / 2))
    end
    for _, frame in { root, popupsFrame } do
        frame.AnchorPoint = anchorPoint
        frame.Position = position
    end
    cashUI.Scale.Scale = scale
    popupsScale.Scale = scale
end
screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutCash)
layoutCash()

local POPUP_FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
local INK = Color3.fromRGB(40, 24, 18)
local function playTween(instance, duration, goals)
    local tween = TweenService:Create(instance, TweenInfo.new(duration, Enum.EasingStyle.Quad), goals)
    tween:Play()
    return tween
end

local function popup(delta)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.FontFace = POPUP_FONT
    label.TextSize = 26
    label.ZIndex = 21
    label.Text = (delta > 0 and "+" or "-") .. CashComponent.FormatCash(math.abs(delta))
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
task.spawn(function()
    local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")
    shownCash, targetCash = cash.Value, cash.Value
    cashUI:SetCash(shownCash)
    cash.Changed:Connect(function(newValue)
        local delta = newValue - targetCash
        targetCash = newValue
        if delta == 0 then
            return
        end
        pendingDelta += delta
        -- the join sequence (loading, welcome back, offline cash) is silent
        local inPreload = (os.clock() - startupTime < 20) or (player:GetAttribute("StartupSessionReady") ~= true)
        if os.clock() - lastPopupAt > 0.20 then
            lastPopupAt = os.clock()
            popup(pendingDelta)
            if pendingDelta > 0 and not inPreload then
                if pendingDelta >= 500 then
                    UISound.Play("CoinChing", 1.0, 0.80)
                else
                    UISound.PlayCoinPickup()
                end
            end
            pendingDelta = 0
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
        cashUI:SetIncome(getIncomePerSecond())
        task.wait(1)
    end
end)

RunService.RenderStepped:Connect(function(dt)
    if shownCash ~= targetCash then
        shownCash += (targetCash - shownCash) * math.min(1, dt * 10)
        if math.abs(targetCash - shownCash) < 1 then
            shownCash = targetCash
        end
        cashUI:SetCash(math.floor(shownCash + 0.5))
    end
end)
