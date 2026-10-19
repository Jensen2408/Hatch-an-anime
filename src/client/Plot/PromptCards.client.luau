--[[ StarterPlayerScripts.PromptCards
One shared controller for every ProximityPrompt: hides Roblox's default prompt UI (Style = Custom, client-side)
and draws a compact cream card instead. The prompt itself still fires the existing server Triggered handlers,
so distance / ownership / price checks stay on the server.
Also adds owner-only PICK UP (E) and SELL (F) prompts to occupied character slots
(server actions: InventoryRequest "PickUp" / "Sell"; the server checks ownership, distance and price).
All card state is cosmetic: "GOT IT!" / "SOLD!" etc. are optimistic or mirror the server's reply.

Table of contents (section banners below are "-- ===== N. ... =====")
  1. Services, palette, helpers (formatShort, getCash, myPlot, menuRefresh)
  2. What a prompt is about: describe(prompt) -> card details (kind, title, badge, info, price, button, colour)
  3. The card BillboardGui: cinematic hiding, keycap, buildCard, destroyCard, showConfirmed, shakeCard
  4. ProximityPromptService hooks (shown / hidden / hold / triggered) + RiverEggPurchaseFeedback
  5. Custom style for every ProximityPrompt in workspace (client-side only)
  6. Owner PICK UP / SELL prompts on occupied slots of the local player's plot

Remotes / bindables:
  ReplicatedStorage.CharacterInventory.InventoryRequest (RF, WaitForChild 20 s)
    InvokeServer("PickUp" | "Sell", { slot = slotName }) -> { ok, message } (Sell: message = cash earned)
  ReplicatedStorage.RiverEggPurchaseFeedback (RE, optional)  server -> reason: shakes every open egg card
  PlayerGui.GameMenus.LocalRefresh (Bindable, owned by MenuLogic)  fired after slot / inventory changes
Instance names / tags read: Plots > <plot> (attribute OwnerUserId) > Slots > <slot> > Platform; prompt names
  PickUpCharacter, PlacePrompt, PickUpPlaced, SellPlaced; parents CollectAnchor (river egg), HatchButton;
  tag HatchRewardDisplay; PlayerGui.CinematicHatchUI (attribute Active), PlayerGui.EggLabels; leaderstats.Cash.
Attributes read: EggType, EggName, Price, Rarity, CharacterName, CharacterId, Power, IncomePerSecond, SellValue,
  Unlocked, UnlockPrice, Occupied. Created: PromptCard BillboardGuis, PlayerGui.SellToast, prompts PickUpPlaced
  (E, hold 0.35 s) and SellPlaced (F / ButtonY, hold 0.8 s) on slot platforms.
]]

-- ===== 1. Services, palette, helpers =====
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UISound = require(ReplicatedStorage:WaitForChild("UISound"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CREAM, INK, RED, GOLD, GREEN =
    Color3.fromRGB(255, 243, 217),
    Color3.fromRGB(56, 34, 24),
    Color3.fromRGB(204, 68, 54),
    Color3.fromRGB(242, 190, 85),
    Color3.fromRGB(85, 163, 78)
local GREY, MUTED = Color3.fromRGB(160, 145, 128), Color3.fromRGB(120, 92, 70)
local RARITY_COLORS = {
    Common = Color3.fromRGB(150, 150, 150),
    Uncommon = Color3.fromRGB(85, 163, 78),
    Rare = Color3.fromRGB(70, 130, 220),
    Epic = Color3.fromRGB(150, 80, 210),
    Legendary = Color3.fromRGB(235, 160, 30),
    Mythic = Color3.fromRGB(220, 60, 90),
    Secret = Color3.fromRGB(30, 30, 30),
}
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")

local function create(className, props, parent)
    local instance = Instance.new(className)
    for key, value in props do
        instance[key] = value
    end
    if parent then
        instance.Parent = parent
    end
    return instance
end
local function formatShort(amount)
    amount = tonumber(amount) or 0
    for _, unit in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
        if amount >= unit[1] then
            local scaled = amount / unit[1]
            return (scaled >= 100 and string.format("%d", scaled) or string.format("%.1f", scaled):gsub("%.0$", ""))
                .. unit[2]
        end
    end
    return tostring(math.floor(amount))
end
local function getCash()
    local leaderstats = player:FindFirstChild("leaderstats")
    local cashValue = leaderstats and leaderstats:FindFirstChild("Cash")
    return cashValue and cashValue.Value or 0
end
local function myPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then
        return
    end
    for _, plot in plots:GetChildren() do
        if plot:GetAttribute("OwnerUserId") == player.UserId then
            return plot
        end
    end
end
local function menuRefresh()
    local gameMenus = playerGui:FindFirstChild("GameMenus")
    local localRefresh = gameMenus and gameMenus:FindFirstChild("LocalRefresh")
    if localRefresh then
        localRefresh:Fire()
    end
end

-- ===== 2. What a prompt is about =====
local function ancestorWith(inst, attributeName)
    while inst and inst ~= workspace do
        if inst:GetAttribute(attributeName) ~= nil then
            return inst
        end
        inst = inst.Parent
    end
end
local function anchorPosition(prompt)
    local parent = prompt.Parent
    if parent:IsA("Attachment") then
        return parent.WorldPosition
    end
    if parent:IsA("BasePart") then
        return parent.Position
    end
    if parent:IsA("Model") then
        return parent:GetPivot().Position
    end
end
local function nearestModel(pos, tag, radius)
    local best, bestDistance
    for _, model in CollectionService:GetTagged(tag) do
        if model:IsA("Model") and model:IsDescendantOf(workspace) then
            local distance = (model:GetPivot().Position - pos).Magnitude
            if distance < radius and (not bestDistance or distance < bestDistance) then
                best, bestDistance = model, distance
            end
        end
    end
    return best
end
local function placedOn(slot)
    local platform = slot:FindFirstChild("Platform")
    if not platform then
        return
    end
    local plot = slot.Parent and slot.Parent.Parent
    local best, bestDistance
    for _, descendant in (plot or slot):GetDescendants() do
        if descendant:IsA("Model") and descendant:GetAttribute("Power") ~= nil then
            local distance = (descendant:GetPivot().Position - platform.Position).Magnitude
            if distance < 8 and (not bestDistance or distance < bestDistance) then
                best, bestDistance = descendant, distance
            end
        end
    end
    return best
end

-- returns the card details for a prompt; prompt kinds are recognised by prompt / parent names and attributes
local function describe(prompt)
    local action, object = prompt.ActionText, prompt.ObjectText
    -- river egg
    local egg = ancestorWith(prompt.Parent, "EggType") or ancestorWith(prompt.Parent, "EggName")
    if egg and prompt.Parent.Name == "CollectAnchor" then
        local price = tonumber(egg:GetAttribute("Price")) or 0
        local name = egg:GetAttribute("EggName") or ((egg:GetAttribute("EggType") or "Mystery") .. " Egg")
        if not tostring(name):find("Egg") then
            name = name .. " Egg"
        end
        return {
            kind = "egg",
            title = name,
            badge = egg:GetAttribute("Rarity"),
            price = price,
            info = price > 0 and ("$" .. formatShort(price)) or "FREE",
            infoColor = price > 0 and INK or GREEN,
            button = "BUY",
            color = GREEN,
        }
    end
    -- hatched character waiting in the incubator
    if prompt.Name == "PickUpCharacter" then
        local model = nearestModel(anchorPosition(prompt) or Vector3.zero, "HatchRewardDisplay", 18)
        local name = model and (model:GetAttribute("CharacterName") or model.Name)
            or object:match("^(.-) •")
            or object
        local power, income = model and model:GetAttribute("Power"), model and model:GetAttribute("IncomePerSecond")
        local info = (power and ("Power " .. formatShort(power)) or object:match("Power [%d%.%a]+") or "")
            .. (income and ("  •  $" .. formatShort(income) .. "/s") or "")
        return {
            kind = "grab",
            title = name,
            badge = model and model:GetAttribute("Rarity"),
            info = info,
            button = "GRAB",
            color = GREEN,
        }
    end
    -- owner pick-up (local prompt)
    if prompt.Name == "PickUpPlaced" then
        local model = placedOn(prompt.Parent.Parent)
        local name = model and (model:GetAttribute("CharacterName") or model:GetAttribute("CharacterId") or model.Name)
            or "Character"
        local power, income = model and model:GetAttribute("Power"), model and model:GetAttribute("IncomePerSecond")
        return {
            kind = "pickup",
            title = name,
            badge = model and model:GetAttribute("Rarity"),
            info = (power and ("Power " .. formatShort(power)) or "")
                .. (income and ("  •  $" .. formatShort(income) .. "/s") or ""),
            button = "PICK UP",
            color = GOLD,
            dark = true,
        }
    end
    -- owner sell (local prompt); price comes from the server's SellValue attribute
    if prompt.Name == "SellPlaced" then
        local model = placedOn(prompt.Parent.Parent)
        local name = model and (model:GetAttribute("CharacterName") or model:GetAttribute("CharacterId") or model.Name)
            or "Character"
        local sellValue = model and tonumber(model:GetAttribute("SellValue"))
        return {
            kind = "sell",
            title = name,
            badge = model and model:GetAttribute("Rarity"),
            info = sellValue and "Hold to sell" or "Can't be sold",
            sellValue = sellValue,
            button = sellValue and ("SELL  $" .. formatShort(sellValue)) or "CAN'T SELL",
            color = sellValue and GREEN or GREY,
        }
    end
    -- character slots
    if prompt.Name == "PlacePrompt" then
        local slotNumber = object:match("(%d+)") or "?"
        local slot = ancestorWith(prompt.Parent, "Unlocked")
        local price = slot and tonumber(slot:GetAttribute("UnlockPrice"))
            or tonumber((action:gsub(",", "")):match("%$(%d+)"))
        if slot and slot:GetAttribute("Unlocked") ~= true or not slot and action:find("Unlock") then
            return {
                kind = "slot",
                title = "SLOT " .. slotNumber,
                badge = "LOCKED",
                badgeColor = MUTED,
                price = price,
                info = "$" .. formatShort(price or 0),
                button = "BUY SLOT",
                color = GREEN,
            }
        end
        return {
            kind = "place",
            title = "SLOT " .. slotNumber,
            info = "Place the character you're holding",
            infoColor = MUTED,
            button = "PLACE",
            color = GOLD,
            dark = true,
        }
    end
    -- incubator buttons
    if prompt.Parent.Name == "HatchButton" then
        return {
            kind = "hatch",
            title = object ~= "" and object or "Incubator",
            info = action:find("Insert") and "Carry an egg here" or nil,
            infoColor = MUTED,
            button = string.upper(action ~= "" and action or "Use"),
            color = RED,
        }
    end
    return {
        kind = "generic",
        title = object ~= "" and object or action,
        button = string.upper(action ~= "" and action or "Use"),
        color = RED,
    }
end

-- ===== 3. The card =====
-- billboards must sit directly in PlayerGui to render / receive input (container for input-enabled billboards)
local billboardParent = playerGui
local cards = {} -- prompt -> card
local CARD_WIDTH, CARD_HEIGHT = 260, 66

-- Interaction cards must stay out of the owner's hatch cinematic.
local function cinematicActive()
    local cinematic = playerGui:FindFirstChild("CinematicHatchUI")
    return cinematic and cinematic:GetAttribute("Active") == true
end
local function syncCinematicCards()
    local enabled = not cinematicActive()
    for _, card in cards do
        card.bb.Enabled = enabled
    end
end
local function watchCinematic(cinematic)
    if cinematic.Name ~= "CinematicHatchUI" then
        return
    end
    cinematic:GetAttributeChangedSignal("Active"):Connect(syncCinematicCards)
    syncCinematicCards()
end
local cinematic = playerGui:FindFirstChild("CinematicHatchUI")
if cinematic then
    watchCinematic(cinematic)
end
playerGui.ChildAdded:Connect(watchCinematic)

local function keycapFor(prompt, inputType)
    if inputType == Enum.ProximityPromptInputType.Touch then
        return nil
    end
    if inputType == Enum.ProximityPromptInputType.Gamepad then
        local image = UserInputService:GetImageForKeyCode(prompt.GamepadKeyCode)
        return { image = image, text = prompt.GamepadKeyCode.Name:gsub("Button", "") }
    end
    local keyName = prompt.KeyboardKeyCode.Name
    local keyString = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
    return { text = (keyString ~= "" and keyString or keyName):upper() }
end

local function buildCard(prompt, inputType)
    local details = describe(prompt)
    local part = prompt.Parent
    local adornee = (part:IsA("BasePart") or part:IsA("Attachment")) and part
        or (part:IsA("Model") and part.PrimaryPart)
        or nil
    if not adornee then
        return
    end
    local baseScale = 1 -- size / tween scale multiplier (always 1; stored on the card as card.base)
    -- the SELL card shares the slot with the PICK UP card: draw it one card-height above
    local billboard = create("BillboardGui", {
        Name = "PromptCard",
        Adornee = adornee,
        Size = UDim2.fromOffset(
            CARD_WIDTH * baseScale,
            (details.kind == "sell" and CARD_HEIGHT * 3 + 12 or CARD_HEIGHT) * baseScale
        ),
        StudsOffsetWorldSpace = Vector3.new(0, details.kind == "egg" and 2.2 or 3.4, 0),
        AlwaysOnTop = true,
        LightInfluence = 0,
        ResetOnSpawn = false,
        Active = true,
        Enabled = not cinematicActive(),
        ClipsDescendants = false,
        MaxDistance = 60,
    }, billboardParent)
    local root = create("Frame", {
        Name = "Root",
        Size = details.kind == "sell" and UDim2.new(1, 0, 0, CARD_HEIGHT) or UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
    }, billboard)
    -- anchor at the centre so the pop / bounce animations grow from the middle, not the top-left corner
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = details.kind == "sell" and UDim2.new(0.5, 0, 0, CARD_HEIGHT / 2) or UDim2.fromScale(0.5, 0.5)
    local scale = create("UIScale", { Scale = 0.01 }, root) -- grows in from nothing (mirrors the shrink-out)
    -- one small line of text above the button: name • rarity / info (no box)
    local lineParts = { details.title or "" }
    if details.badge and details.kind ~= "slot" then
        table.insert(
            lineParts,
            string.format('<font color="#%s">%s</font>', (RARITY_COLORS[details.badge] or MUTED):ToHex(), details.badge)
        )
    end
    if details.info and details.info ~= "" and details.kind ~= "egg" and details.kind ~= "slot" then
        table.insert(lineParts, details.info)
    end
    local infoLabel = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        FontFace = FONT,
        TextSize = 16,
        RichText = true,
        TextColor3 = Color3.new(1, 1, 1),
        Text = table.concat(lineParts, "  •  "),
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, root)
    create("UIStroke", { Color = INK, Thickness = 1.5 }, infoLabel)
    -- chunky pill button with a small dark base
    local buttonHolder = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 24),
        Size = UDim2.fromOffset(0, 38),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
    }, root)
    local buttonBase = create("Frame", {
        Position = UDim2.fromOffset(0, 4),
        Size = UDim2.new(1, 0, 1, -4),
        BackgroundColor3 = INK,
        BorderSizePixel = 0,
    }, buttonHolder)
    create("UICorner", { CornerRadius = UDim.new(1, 0) }, buttonBase)
    local face = create("TextButton", {
        Size = UDim2.new(0, 0, 1, -4),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = details.color,
        AutoButtonColor = false,
        Text = "",
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, buttonHolder)
    create("UICorner", { CornerRadius = UDim.new(1, 0) }, face)
    create("UIStroke", { Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, face)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 7),
    }, face)
    create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 14) }, face)
    local fill = create("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.65,
        BorderSizePixel = 0,
        ZIndex = 0,
    }, buttonHolder)
    fill.Parent = buttonHolder
    fill.Size = UDim2.fromScale(0, 1)
    fill.ZIndex = 3
    fill.Position = UDim2.fromOffset(0, 0)
    fill:SetAttribute("Fill", true)
    create("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
    local keycap = keycapFor(prompt, inputType)
    if keycap then
        local keycapFrame = create(
            "Frame",
            { LayoutOrder = 1, Size = UDim2.fromOffset(24, 24), BackgroundColor3 = CREAM, BorderSizePixel = 0 },
            face
        )
        create("UICorner", { CornerRadius = UDim.new(0, 7) }, keycapFrame)
        create("UIStroke", { Color = INK, Thickness = 1.5 }, keycapFrame)
        if keycap.image and keycap.image ~= "" then
            create(
                "ImageLabel",
                { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = keycap.image },
                keycapFrame
            )
        else
            create("TextLabel", {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                FontFace = FONT,
                TextSize = 14,
                TextColor3 = INK,
                Text = keycap.text,
            }, keycapFrame)
        end
    else
        face:FindFirstChildOfClass("UIPadding").PaddingLeft = UDim.new(0, 14)
    end
    local function buttonText()
        return (details.kind == "egg" or details.kind == "slot")
                and details.price
                and (details.button .. "  " .. (details.price > 0 and ("$" .. formatShort(details.price)) or "FREE"))
            or (details.kind == "egg" and (details.button .. "  FREE"))
            or details.button
    end
    details.button = buttonText()
    local label = create("TextLabel", {
        LayoutOrder = 2,
        Size = UDim2.fromOffset(0, 30),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        FontFace = FONT,
        TextSize = 18,
        TextColor3 = details.dark and INK or Color3.new(1, 1, 1),
        Text = details.button,
    }, face)
    local card = {
        base = baseScale,
        bb = billboard,
        root = root,
        scale = scale,
        face = face,
        fill = fill,
        label = label,
        info = infoLabel,
        d = details,
        prompt = prompt,
        conns = {},
        hold = nil,
    }
    -- affordability (live)
    local function refreshAffordability()
        if not details.price or details.price <= 0 then
            return
        end
        local canAfford = getCash() >= details.price
        face.BackgroundColor3 = canAfford and details.color or GREY
        label.Text = canAfford and details.button or ("NEED $" .. formatShort(details.price - getCash()))
    end
    refreshAffordability()
    local leaderstats = player:FindFirstChild("leaderstats")
    local cashValue = leaderstats and leaderstats:FindFirstChild("Cash")
    if cashValue then
        table.insert(card.conns, cashValue.Changed:Connect(refreshAffordability))
    end
    -- hover lift / press push
    local function tweenFaceY(y)
        TweenService:Create(face, TweenInfo.new(0.08), { Position = UDim2.fromOffset(0, y) }):Play()
    end
    table.insert(
        card.conns,
        face.MouseEnter:Connect(function()
            tweenFaceY(-2)
        end)
    )
    table.insert(
        card.conns,
        face.MouseLeave:Connect(function()
            tweenFaceY(0)
        end)
    )
    table.insert(
        card.conns,
        face.MouseButton1Down:Connect(function()
            tweenFaceY(4)
            prompt:InputHoldBegin()
        end)
    )
    table.insert(
        card.conns,
        face.MouseButton1Up:Connect(function()
            tweenFaceY(0)
            prompt:InputHoldEnd()
        end)
    )
    -- live text changes (e.g. slot bought -> PLACE)
    table.insert(
        card.conns,
        prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
            local newDetails = describe(prompt)
            if prompt.ActionText == "Not enough money" or prompt.ActionText == "Not enough cash" then
                label.Text = "NOT ENOUGH MONEY"
                face.BackgroundColor3 = RED
                card.confirmed = false
            elseif
                card.d.kind == "slot"
                and newDetails.kind == "place"
                and ancestorWith(prompt.Parent, "Unlocked")
                and ancestorWith(prompt.Parent, "Unlocked"):GetAttribute("Unlocked") == true
            then
                label.Text = "UNLOCKED!"
                face.BackgroundColor3 = GREEN
                TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1.08 * baseScale })
                    :Play()
                task.delay(0.12, function()
                    TweenService:Create(scale, TweenInfo.new(0.15), { Scale = baseScale }):Play()
                end)
                menuRefresh()
            elseif newDetails.kind == "slot" then
                refreshAffordability()
            end
        end)
    )
    -- appear
    TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = baseScale }):Play()
    -- river eggs already have a floating name label; hide it while the card is up (no double text)
    if details.kind == "egg" then
        local eggLabels = playerGui:FindFirstChild("EggLabels")
        local egg = prompt.Parent.Parent
        if eggLabels and egg then
            for _, eggLabel in eggLabels:GetChildren() do
                if
                    eggLabel:IsA("BillboardGui")
                    and eggLabel.Adornee
                    and eggLabel.Adornee:IsDescendantOf(egg)
                    and eggLabel.Enabled
                then
                    eggLabel.Enabled = false
                    card.hidLabel = eggLabel
                end
            end
        end
    end
    cards[prompt] = card
    return card
end

local function destroyCard(prompt, delaySeconds)
    local card = cards[prompt]
    if not card then
        return
    end
    cards[prompt] = nil
    for _, conn in card.conns do
        conn:Disconnect()
    end
    if card.hold then
        card.hold:Cancel()
    end
    if card.hidLabel and card.hidLabel.Parent then
        card.hidLabel.Enabled = true
    end
    TweenService:Create(card.scale, TweenInfo.new(0.15), { Scale = 0.01 }):Play()
    task.delay(math.max(0.16, delaySeconds or 0), function()
        card.bb:Destroy()
    end)
end

local function showConfirmed(card, text)
    card.label.Text = text
    card.face.BackgroundColor3 = GREEN
    card.fill.Size = UDim2.fromScale(1, 1)
    TweenService:Create(card.scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1.08 * card.base }):Play()
end

local function shakeCard(card, text)
    if not card then
        return
    end
    card.label.Text = text
    local root = card.root
    local home = card.home or root.Position
    card.home = home
    for i, offsetX in { 6, -6, 4, -4, 0 } do
        task.delay(i * 0.04, function()
            if root.Parent then
                root.Position = home + UDim2.fromOffset(offsetX, 0)
            end
        end)
    end
end

-- ===== 4. ProximityPromptService hooks =====
ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
    if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
        return
    end
    if cards[prompt] then
        destroyCard(prompt)
    end
    buildCard(prompt, inputType)
end)
ProximityPromptService.PromptHidden:Connect(function(prompt)
    local card = cards[prompt]
    destroyCard(prompt, card and card.confirmed and 0.35 or 0)
end)
ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
    local card = cards[prompt]
    if not card then
        return
    end
    card.fill.Size = UDim2.fromScale(0, 1)
    card.hold = TweenService:Create(
        card.fill,
        TweenInfo.new(math.max(prompt.HoldDuration, 0.01), Enum.EasingStyle.Linear),
        { Size = UDim2.fromScale(1, 1) }
    )
    card.hold:Play()
end)
ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
    local card = cards[prompt]
    if not card then
        return
    end
    if card.hold then
        card.hold:Cancel()
    end
    if not card.confirmed then
        TweenService:Create(card.fill, TweenInfo.new(0.12), { Size = UDim2.fromScale(0, 1) }):Play()
    end
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
    local card = cards[prompt]
    if not card then
        return
    end
    local kind = card.d.kind
    if kind == "egg" then
        if not card.d.price or card.d.price <= getCash() then
            card.confirmed = true
            showConfirmed(card, "GOT IT!")
            UISound.Play("EggBuy")
        end
    elseif kind == "grab" then
        card.confirmed = true
        showConfirmed(card, "GRABBED!")
        UISound.Play("Claim")
    elseif kind == "slot" then
        if card.d.price and card.d.price > getCash() then
            shakeCard(card, "NOT ENOUGH MONEY")
        else
            UISound.Play("EggBuy")
        end
    end
end)

-- server says the egg was too expensive: show it on the card, no popup
local purchaseFeedback = ReplicatedStorage:FindFirstChild("RiverEggPurchaseFeedback")
if purchaseFeedback then
    purchaseFeedback.OnClientEvent:Connect(function(reason)
        for _prompt, card in cards do
            if card.d.kind == "egg" then
                card.confirmed = false
                shakeCard(card, string.upper(tostring(reason or "Not enough cash")))
            end
        end
    end)
end

-- ===== 5. Use Custom style everywhere (client-side only) =====
local function adoptPrompt(inst)
    if inst:IsA("ProximityPrompt") then
        inst.Style = Enum.ProximityPromptStyle.Custom
    end
end
for _, descendant in workspace:GetDescendants() do
    adoptPrompt(descendant)
end
workspace.DescendantAdded:Connect(adoptPrompt)

-- ===== 6. Owner PICK UP / SELL on occupied slots =====
local inventoryFolder = ReplicatedStorage:WaitForChild("CharacterInventory", 20)
local inventoryRequest = inventoryFolder and inventoryFolder:WaitForChild("InventoryRequest", 20)
-- "+$X" toast (screen space): the slot's cards vanish as soon as the slot frees, so the payout shows here too
local function cashToast(text)
    local toastGui = playerGui:FindFirstChild("SellToast")
        or create(
            "ScreenGui",
            { Name = "SellToast", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50 },
            playerGui
        )
    local toast = create("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.42),
        Size = UDim2.fromOffset(360, 56),
        BackgroundTransparency = 1,
        FontFace = FONT,
        TextSize = 40,
        TextColor3 = Color3.fromRGB(120, 220, 95),
        Text = text,
    }, toastGui)
    local toastStroke = create("UIStroke", { Color = INK, Thickness = 3 }, toast)
    local toastScale = create("UIScale", { Scale = 0.6 }, toast)
    TweenService:Create(toastScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
    TweenService:Create(
        toast,
        TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = UDim2.fromScale(0.5, 0.32), TextTransparency = 1 }
    ):Play()
    TweenService
        :Create(toastStroke, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 })
        :Play()
    task.delay(1.5, function()
        toast:Destroy()
    end)
end
local pickPrompts, sellPrompts, plotConns = {}, {}, {}
local requestPending = false -- one InventoryRequest at a time (shared by PICK UP and SELL)
local function syncSell(slot, platform, shouldExist)
    local prompt = sellPrompts[slot]
    if shouldExist and not prompt then
        prompt = create("ProximityPrompt", {
            Name = "SellPlaced",
            ActionText = "Sell",
            ObjectText = "Character slot",
            HoldDuration = 0.8,
            MaxActivationDistance = 9,
            KeyboardKeyCode = Enum.KeyCode.F,
            GamepadKeyCode = Enum.KeyCode.ButtonY,
            RequiresLineOfSight = false,
            Style = Enum.ProximityPromptStyle.Custom,
        }, platform)
        sellPrompts[slot] = prompt
        prompt.Triggered:Connect(function()
            if requestPending or not inventoryRequest then
                return
            end
            local card = cards[prompt]
            if card and not card.d.sellValue then
                shakeCard(card, "CAN'T SELL")
                return
            end
            requestPending = true
            local ok, result = pcall(inventoryRequest.InvokeServer, inventoryRequest, "Sell", { slot = slot.Name })
            requestPending = false
            card = cards[prompt] or card
            if ok and result and result.ok then
                if card then
                    card.confirmed = true
                    showConfirmed(card, "SOLD!  +$" .. formatShort(result.message))
                end
                cashToast("+$" .. formatShort(result.message))
                UISound.Play("CoinChing")
                menuRefresh()
            else
                shakeCard(card, string.upper(tostring(result and result.message or "Try again")))
            end
        end)
    elseif not shouldExist and prompt then
        sellPrompts[slot] = nil
        prompt:Destroy()
    end
end
local function syncSlot(slot)
    local platform = slot:FindFirstChild("Platform")
    if not platform then
        return
    end
    local isOccupied = slot:GetAttribute("Occupied") == true
    syncSell(slot, platform, isOccupied)
    local prompt = pickPrompts[slot]
    if isOccupied and not prompt then
        prompt = create("ProximityPrompt", {
            Name = "PickUpPlaced",
            ActionText = "Pick up",
            ObjectText = "Character slot",
            HoldDuration = 0.35,
            MaxActivationDistance = 9,
            RequiresLineOfSight = false,
            Style = Enum.ProximityPromptStyle.Custom,
        }, platform)
        pickPrompts[slot] = prompt
        prompt.Triggered:Connect(function()
            if requestPending or not inventoryRequest then
                return
            end
            requestPending = true
            local card = cards[prompt]
            local ok, result = pcall(inventoryRequest.InvokeServer, inventoryRequest, "PickUp", { slot = slot.Name })
            requestPending = false
            if ok and result and result.ok then
                if card then
                    card.confirmed = true
                    showConfirmed(card, "PICKED UP!")
                end
                menuRefresh()
            else
                shakeCard(cards[prompt], string.upper(tostring(result and result.message or "Try again")))
            end
        end)
    elseif not isOccupied and prompt then
        pickPrompts[slot] = nil
        prompt:Destroy()
    end
end
-- rebuilds the owner prompts for the local player's current plot (called on any plot's OwnerUserId change)
local function watchPlot()
    for _, conn in plotConns do
        conn:Disconnect()
    end
    table.clear(plotConns)
    for _slot, prompt in pickPrompts do
        prompt:Destroy()
    end
    table.clear(pickPrompts)
    for _slot, prompt in sellPrompts do
        prompt:Destroy()
    end
    table.clear(sellPrompts)
    local plot = myPlot()
    if not plot or not plot:FindFirstChild("Slots") then
        return
    end
    for _, slot in plot.Slots:GetChildren() do
        syncSlot(slot)
        table.insert(
            plotConns,
            slot:GetAttributeChangedSignal("Occupied"):Connect(function()
                syncSlot(slot)
                menuRefresh()
            end)
        )
        table.insert(plotConns, slot:GetAttributeChangedSignal("Unlocked"):Connect(menuRefresh))
    end
end
task.spawn(function()
    local plots = workspace:WaitForChild("Plots")
    for _, plot in plots:GetChildren() do
        plot:GetAttributeChangedSignal("OwnerUserId"):Connect(watchPlot)
    end
    watchPlot()
end)
