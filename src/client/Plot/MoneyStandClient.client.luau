--[[ StarterPlayerScripts.MoneyStandClient  (LocalScript)
Cosmetic only: plate spring, shine, +$ text, gold squares, display countdown and sounds.
Reads the server's Pressed / Stored attributes and MoneyCollected event. Never grants money.

Remote (listen only): ReplicatedStorage.MoneyCollected.OnClientEvent(standModel, amount)  amount = 0 -> "EMPTY".
Stands are models tagged "MoneyStand" (spawned by MoneyStandOwnership, collected by MoneyStandServer).
]]
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UISound = require(ReplicatedStorage:WaitForChild("UISound"))
local _player = Players.LocalPlayer
local Debris = game:GetService("Debris")

local Config = {
    PressDepth = 0.16,
}
local GOLD_COLOR = Color3.fromRGB(255, 207, 85)

local function formatMoney(amount)
    return require(game:GetService("ReplicatedStorage").CharacterInventory.InventoryFormat).Money(amount)
end

-- A local spatial key press follows the server-authorized plate state.
local function playPlateSound(model, name)
    local plate = model:FindFirstChild("Plate")
    if plate and plate:IsA("BasePart") then
        UISound.PlayAt(name, plate)
    end
end

-- stands[model] = { model, plate, restCF, busy, pressed, amount, status, shineFrame?, shineGrad?, pressTween? }
local stands = {}

local function setStatus(stand, text, isDim)
    if stand.status then
        stand.status.Text = text
    end
    if stand.amount then
        stand.amount.TextColor3 = isDim and Color3.fromRGB(138, 124, 102) or Color3.fromRGB(255, 246, 220)
    end
end

local function press(stand, isDown)
    if stand.pressed == isDown then
        return
    end
    stand.pressed = isDown
    if stand.pressTween then
        stand.pressTween:Cancel()
    end
    local targetCFrame = isDown and stand.restCF * CFrame.new(0, -Config.PressDepth, 0) or stand.restCF
    -- Back easing gives the small spring overshoot
    stand.pressTween = TweenService:Create(
        stand.plate,
        TweenInfo.new(isDown and 0.14 or 0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { CFrame = targetCFrame }
    )
    stand.pressTween:Play()
    playPlateSound(stand.model, isDown and "PlatePress" or "PlateRelease")
    if isDown then
        setStatus(stand, "COLLECTED", false)
    elseif not stand.busy then
        setStatus(stand, (stand.model:GetAttribute("Stored") or 0) >= 1 and "STEP TO COLLECT" or "EMPTY", false)
    end
end

-- Currently unused (never called); kept for the optional plate "Shine" > "Band" gradient sweep.
local function _shine(stand)
    local gradient = stand.shineGrad
    if not gradient then
        return
    end
    gradient.Offset = Vector2.new(-1, 0)
    stand.shineFrame.BackgroundTransparency = 0
    local tween = TweenService:Create(
        gradient,
        TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
        { Offset = Vector2.new(1, 0) }
    )
    tween:Play()
    tween.Completed:Once(function()
        stand.shineFrame.BackgroundTransparency = 1
    end)
end

local function popText(stand, amount)
    local anchor = Instance.new("Part")
    anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.Transparency =
        true, false, false, false, 1
    anchor.Size = Vector3.new(0.2, 0.2, 0.2)
    anchor.CFrame = stand.restCF * CFrame.new(0, 2.2, 0)
    anchor.Parent = workspace
    local billboard = Instance.new("BillboardGui")
    billboard.Size, billboard.AlwaysOnTop, billboard.LightInfluence = UDim2.fromOffset(220, 56), true, 0
    billboard.Parent = anchor
    local label = Instance.new("TextLabel")
    label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
    label.Font, label.TextScaled, label.Text, label.TextColor3 =
        Enum.Font.FredokaOne, true, "+" .. formatMoney(amount), Color3.fromRGB(255, 224, 138)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 3
    stroke.Color = Color3.fromRGB(12, 14, 13)
    stroke.Parent = label
    label.Parent = billboard
    TweenService:Create(
        anchor,
        TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { CFrame = anchor.CFrame * CFrame.new(0, 2.2, 0) }
    ):Play()
    task.delay(0.55, function()
        TweenService:Create(label, TweenInfo.new(0.45), { TextTransparency = 1 }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.45), { Transparency = 1 }):Play()
    end)
    Debris:AddItem(anchor, 1.1)
end

local function burst(stand)
    for i = 1, 8 do
        local chip = Instance.new("Part")
        chip.Anchored, chip.CanCollide, chip.CanQuery, chip.CanTouch, chip.CastShadow = true, false, false, false, false
        chip.Size = Vector3.new(0.25, 0.25, 0.25)
        chip.Color, chip.Material = GOLD_COLOR, Enum.Material.Neon
        local angle = (i / 8) * math.pi * 2
        local startCFrame = stand.restCF * CFrame.new(math.cos(angle) * 0.6, 0.4, math.sin(angle) * 0.6)
        chip.CFrame = startCFrame
        chip.Parent = workspace
        local velocity = Vector3.new(math.cos(angle) * 1.8, 5 + math.random() * 2, math.sin(angle) * 1.8)
        local startedAt, lifetime = os.clock(), 0.65 + math.random() * 0.2
        local connection
        connection = RunService.RenderStepped:Connect(function()
            local elapsed = os.clock() - startedAt
            if elapsed >= lifetime or not chip.Parent then
                connection:Disconnect()
                chip:Destroy()
                return
            end
            local position = startCFrame.Position + velocity * elapsed + Vector3.new(0, -8 * elapsed * elapsed, 0)
            local progress = elapsed / lifetime
            chip.Size = Vector3.new(0.25, 0.25, 0.25) * (progress > 0.7 and (1 - (progress - 0.7) / 0.3) or 1)
            chip.CFrame = CFrame.new(position) * CFrame.Angles(elapsed * 7, elapsed * 5, 0)
        end)
    end
end

local function countdown(stand, amount)
    stand.busy = true
    setStatus(stand, "COLLECTING", false)
    local counter = Instance.new("NumberValue")
    counter.Value = amount
    local changedConnection = counter.Changed:Connect(function(value)
        if stand.amount then
            stand.amount.Text = formatMoney(value)
        end
    end)
    local tween = TweenService:Create(
        counter,
        TweenInfo.new(0.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
        { Value = 0 }
    )
    tween:Play()
    tween.Completed:Wait()
    changedConnection:Disconnect()
    counter:Destroy()
    setStatus(stand, "EMPTY", true)
    task.wait(0.6)
    stand.busy = false
    setStatus(stand, stand.model:GetAttribute("Pressed") and "COLLECTED" or "STEP TO COLLECT", false)
end

local function addStand(model)
    if stands[model] then
        return
    end
    local plate = model:WaitForChild("Plate", 10)
    if not plate then
        return
    end
    local display = model:FindFirstChild("Display", true)
    local screenGui = display and display:FindFirstChild("Screen")
    local stand = {
        model = model,
        plate = plate,
        restCF = plate.CFrame,
        busy = false,
        pressed = model:GetAttribute("Pressed") == true,
        amount = screenGui and screenGui:FindFirstChild("Amount", true),
        status = screenGui and screenGui:FindFirstChild("Status", true),
    }
    local shineGui = plate:FindFirstChild("Shine")
    if shineGui then
        stand.shineFrame = shineGui:FindFirstChild("Band")
        stand.shineGrad = stand.shineFrame and stand.shineFrame:FindFirstChildOfClass("UIGradient")
    end
    stands[model] = stand
    local function refresh()
        if stand.busy or not stand.amount then
            return
        end
        local stored = model:GetAttribute("Stored") or 0
        stand.amount.Text = formatMoney(stored)
        if not model:GetAttribute("Pressed") then
            setStatus(stand, stored >= 1 and "STEP TO COLLECT" or "EMPTY", stored < 1)
        end
    end
    model:GetAttributeChangedSignal("Stored"):Connect(refresh)
    model:GetAttributeChangedSignal("Pressed"):Connect(function()
        press(stand, model:GetAttribute("Pressed") == true)
    end)
    refresh()
end

for _, model in CollectionService:GetTagged("MoneyStand") do
    task.spawn(addStand, model)
end
CollectionService:GetInstanceAddedSignal("MoneyStand"):Connect(addStand)
CollectionService:GetInstanceRemovedSignal("MoneyStand"):Connect(function(model)
    stands[model] = nil
end)

ReplicatedStorage:WaitForChild("MoneyCollected").OnClientEvent:Connect(function(model, amount)
    local stand = stands[model]
    if not stand then
        return
    end
    if amount <= 0 then
        setStatus(stand, "EMPTY", true)
        return
    end
    -- Plate thock + HUD payout chime trigger together for maximum satisfaction.
    popText(stand, amount)
    burst(stand)
    task.spawn(countdown, stand, amount)
end)
