--[[ ServerScriptService.TempleSlotUnlocks  (ModuleScript, server)
Character slot unlocks on a plot (plot.Slots.Slot01..Slot36). Each temple level opens 12 slots
(Capacity = TempleLevel * 12); slots must be bought in order and paid from leaderstats.Cash.
  Slots.Prices[i]           -- unlock price of slot i (slot 1 free; slots 13..36 = previous * 3)
  Slots.Capacity(plot)      -- number of slots the current temple level allows
  Slots.CanUpgrade(plot)    -- true when every slot within capacity is unlocked (gate for the temple upgrade)
  Slots.Refresh(plot)       -- visibility, PlacePrompt and SlotUnlockLabel billboard state of every slot
  Slots.Purchase(plot, slot, player) -> ok, reason   -- reason strings are shown to the player
  Slots.Setup(plot)         -- builds the billboards once, resets unlocks and wires owner/level changes
  Slots.Reset(plot)         -- relock all but slot 1 (on owner change)
  Slots.Format(n)           -- "$" .. InventoryFormat.Short(n)
Slot attributes: Unlocked, UnlockPrice, Available (written), Occupied (read; written by placement code).
Used by PlotManager, BrainrotPlacement, InventoryService and OwnerGameActions.
]]
local InventoryFormat =
    require(game:GetService("ReplicatedStorage"):WaitForChild("CharacterInventory"):WaitForChild("InventoryFormat"))
local Slots = {}

local SLOTS_PER_LEVEL = 12
local MAX_TEMPLE_LEVEL = 3
local FALLBACK_PRICE = 250000 -- used when Slots.Prices has no entry for a slot
local MAX_PURCHASE_DISTANCE = 12 -- studs from the slot platform

Slots.Prices = { 0, 250, 2500, 25000, 150000, 750000, 5000000, 25000000, 150000000, 750000000, 3000000000, 15000000000 }
-- Slots 13..36 (temple levels 2 and 3) each cost 3x the previous slot.
for i = 13, 36 do
    Slots.Prices[i] = Slots.Prices[i - 1] * 3
end
function Slots.Capacity(plot)
    return math.clamp(plot:GetAttribute("TempleLevel") or 1, 1, MAX_TEMPLE_LEVEL) * SLOTS_PER_LEVEL
end
function Slots.CanUpgrade(plot)
    local capacity = Slots.Capacity(plot)
    for i = 1, capacity do
        local slot = plot.Slots:FindFirstChild(string.format("Slot%02d", i))
        if not slot or slot:GetAttribute("Unlocked") ~= true then
            return false
        end
    end
    return true
end
-- "Slot07" -> 7
local function slotIndex(slot)
    return tonumber(slot.Name:match("%d+")) or 1
end
-- `nextAvailable` = this slot is the next one that may be bought (slot 1, or the previous slot is unlocked).
function Slots.Refresh(plot)
    local claimed = (plot:GetAttribute("OwnerUserId") or 0) ~= 0
    for _, slot in ipairs(plot.Slots:GetChildren()) do
        local slotNumber = slotIndex(slot)
        local available = slotNumber <= Slots.Capacity(plot)
        slot:SetAttribute("Available", available)
        for _, descendant in slot:GetDescendants() do
            if descendant:IsA("BasePart") then
                if descendant:GetAttribute("ClaimTransparency") == nil then
                    descendant:SetAttribute("ClaimTransparency", descendant.Transparency)
                    descendant:SetAttribute("ClaimCollide", descendant.CanCollide)
                    descendant:SetAttribute("ClaimQuery", descendant.CanQuery)
                end
                descendant.Transparency = claimed and available and descendant:GetAttribute("ClaimTransparency") or 1
                descendant.CanCollide = claimed and available and descendant:GetAttribute("ClaimCollide") or false
                descendant.CanQuery = claimed and available and descendant:GetAttribute("ClaimQuery") or false
            end
        end
        local unlocked = slot:GetAttribute("Unlocked") == true
        local occupied = slot:GetAttribute("Occupied") == true
        local previousSlot = plot.Slots:FindFirstChild(string.format("Slot%02d", slotNumber - 1))
        local nextAvailable = slotNumber == 1 or (previousSlot and previousSlot:GetAttribute("Unlocked") == true)
        local prompt = slot.Platform.PlacePrompt
        prompt.Enabled = claimed and available and not occupied and (unlocked or nextAvailable)
        prompt.ActionText = unlocked and "Place character"
            or ("Unlock • " .. Slots.Format(Slots.Prices[slotNumber] or FALLBACK_PRICE))
        prompt.ObjectText = "Character slot " .. slotNumber
        prompt.HoldDuration = unlocked and 0.15 or 0.4
        local unlockLabel = slot.Platform:FindFirstChild("SlotUnlockLabel")
        if unlockLabel and unlockLabel:FindFirstChild("Card") then
            unlockLabel.Enabled = claimed and available and not unlocked
            local card = unlockLabel.Card
            local price = Slots.Prices[slotNumber] or FALLBACK_PRICE
            card.Title.Text = "SLOT " .. slotNumber
            if nextAvailable then
                unlockLabel.Size = UDim2.fromScale(4.6, 2)
                card.BackgroundColor3 = Color3.fromRGB(34, 22, 40)
                card.BackgroundTransparency = 1
                card.Stroke.Color = Color3.fromRGB(255, 200, 90)
                card.Stroke.Transparency = 1
                card.Title.TextColor3 = Color3.new(1, 1, 1)
                card.Price.Visible = false
                card.Locked.Visible = false -- the green BUY SLOT prompt already shows the price card.Stroke.Enabled=false
                card.Price.Amount.Text = Slots.Format(price)
            else
                unlockLabel.Size = UDim2.fromScale(3.5, 1.5)
                card.BackgroundColor3 = Color3.fromRGB(18, 14, 22)
                card.BackgroundTransparency = 0.35
                card.Stroke.Color = Color3.fromRGB(120, 110, 130)
                card.Stroke.Transparency = 0.5
                card.Title.TextColor3 = Color3.fromRGB(170, 165, 180)
                card.Price.Visible = false
                card.Locked.Visible = true
                card.Stroke.Enabled = true
                card.Locked.Text = "🔒  UNLOCK SLOT " .. (slotNumber - 1) .. " FIRST"
            end
        end
    end
end
function Slots.Format(n)
    return "$" .. InventoryFormat.Short(n)
end
function Slots.Reset(plot)
    for _, slot in ipairs(plot.Slots:GetChildren()) do
        slot:SetAttribute("Unlocked", slotIndex(slot) == 1)
        slot:SetAttribute("UnlockPrice", Slots.Prices[slotIndex(slot)] or FALLBACK_PRICE)
    end
    Slots.Refresh(plot)
end
function Slots.Purchase(plot, slot, player)
    if
        plot:GetAttribute("OwnerUserId") ~= player.UserId
        or slot:GetAttribute("Unlocked")
        or slot:GetAttribute("Occupied")
    then
        return false, "Unavailable"
    end
    local slotNumber = slotIndex(slot)
    if slotNumber > Slots.Capacity(plot) then
        return false, "Upgrade your temple to unlock this floor"
    end
    local previousSlot = plot.Slots:FindFirstChild(string.format("Slot%02d", slotNumber - 1))
    if slotNumber > 1 and (not previousSlot or not previousSlot:GetAttribute("Unlocked")) then
        return false, "Unlock the previous slot first"
    end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if
        not root
        or not humanoid
        or humanoid.Health <= 0
        or (root.Position - slot.Platform.Position).Magnitude > MAX_PURCHASE_DISTANCE
    then
        return false, "Too far away"
    end
    local leaderstats = player:FindFirstChild("leaderstats")
    local cash = leaderstats and leaderstats:FindFirstChild("Cash")
    local price = Slots.Prices[slotNumber] or FALLBACK_PRICE
    if not cash or cash.Value < price then
        return false, "Not enough money"
    end
    -- No yielding between payment and unlock, preventing duplicate charges.
    cash.Value -= price
    slot:SetAttribute("Unlocked", true)
    Slots.Refresh(plot)
    return true
end
-- Builds the SlotUnlockLabel billboard (Card > Title, Price > Amount, Locked) on every slot; Refresh fills it.
function Slots.Setup(plot)
    for _, slot in ipairs(plot.Slots:GetChildren()) do
        local platform = slot.Platform
        local oldLabel = platform:FindFirstChild("SlotUnlockLabel")
        if oldLabel then
            oldLabel:Destroy()
        end
        local unlockLabel = Instance.new("BillboardGui")
        unlockLabel.Name = "SlotUnlockLabel"
        unlockLabel.Size = UDim2.fromScale(4.6, 2)
        unlockLabel.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
        unlockLabel.MaxDistance = 45
        unlockLabel.AlwaysOnTop = false
        unlockLabel.LightInfluence = 0
        unlockLabel.Parent = platform
        local card = Instance.new("Frame")
        card.Name = "Card"
        card.Size = UDim2.fromScale(1, 1)
        card.BorderSizePixel = 0
        card.Parent = unlockLabel
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
        local cardStroke = Instance.new("UIStroke")
        cardStroke.Name = "Stroke"
        cardStroke.Thickness = 2.5
        cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        cardStroke.Parent = card
        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "Title"
        titleLabel.BackgroundTransparency = 1
        titleLabel.Size = UDim2.new(1, 0, 0.42, 0)
        titleLabel.Position = UDim2.fromScale(0, 0.06)
        titleLabel.Font = Enum.Font.FredokaOne
        titleLabel.TextScaled = true
        titleLabel.Parent = card
        local titleStroke = Instance.new("UIStroke")
        titleStroke.Thickness = 2
        titleStroke.Color = Color3.fromRGB(20, 10, 24)
        titleStroke.Parent = titleLabel
        local titleSizeLimit = Instance.new("UITextSizeConstraint")
        titleSizeLimit.MaxTextSize = 26
        titleSizeLimit.Parent = titleLabel
        local priceFrame = Instance.new("Frame")
        priceFrame.Name = "Price"
        priceFrame.AnchorPoint = Vector2.new(0.5, 1)
        priceFrame.Position = UDim2.fromScale(0.5, 0.91)
        priceFrame.Size = UDim2.new(0.82, 0, 0.42, 0)
        priceFrame.BackgroundColor3 = Color3.fromRGB(255, 196, 60)
        priceFrame.BorderSizePixel = 0
        priceFrame.Parent = card
        Instance.new("UICorner", priceFrame).CornerRadius = UDim.new(1, 0)
        local priceGradient = Instance.new("UIGradient")
        priceGradient.Rotation = 90
        priceGradient.Color = ColorSequence.new(Color3.fromRGB(255, 232, 140), Color3.fromRGB(240, 160, 30))
        priceGradient.Parent = priceFrame
        local priceStroke = Instance.new("UIStroke")
        priceStroke.Color = Color3.fromRGB(120, 70, 10)
        priceStroke.Thickness = 2
        priceStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        priceStroke.Parent = priceFrame
        local amountLabel = Instance.new("TextLabel")
        amountLabel.Name = "Amount"
        amountLabel.BackgroundTransparency = 1
        amountLabel.Size = UDim2.fromScale(1, 1)
        amountLabel.Font = Enum.Font.FredokaOne
        amountLabel.TextScaled = true
        amountLabel.TextColor3 = Color3.fromRGB(70, 35, 5)
        amountLabel.Parent = priceFrame
        local amountPadding = Instance.new("UIPadding")
        amountPadding.PaddingTop = UDim.new(0.1, 0)
        amountPadding.PaddingBottom = UDim.new(0.1, 0)
        amountPadding.Parent = amountLabel
        local lockedLabel = Instance.new("TextLabel")
        lockedLabel.Name = "Locked"
        lockedLabel.BackgroundTransparency = 1
        lockedLabel.AnchorPoint = Vector2.new(0.5, 1)
        lockedLabel.Position = UDim2.fromScale(0.5, 0.9)
        lockedLabel.Size = UDim2.new(0.92, 0, 0.36, 0)
        lockedLabel.Font = Enum.Font.GothamBold
        lockedLabel.TextScaled = true
        lockedLabel.TextColor3 = Color3.fromRGB(165, 160, 175)
        lockedLabel.Parent = card
    end
    Slots.Reset(plot)
    plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
        Slots.Reset(plot)
        task.defer(Slots.Refresh, plot)
    end)
    plot:GetAttributeChangedSignal("TempleLevel"):Connect(function()
        task.defer(Slots.Refresh, plot)
    end)
end
return Slots
