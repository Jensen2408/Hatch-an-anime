--[[ ServerScriptService.TwoHandItemCarryService  (ModuleScript, SERVER)
Two-hand carry for egg / character / brainrot Tools (unless HoldStyle == "OneHand"), plus dropping them on the ground.
Started by TwoHandItemCarryServer (Service.Init). Also used by RiverEggCarryService and by death/steal code.

Public API
  Service.Init()                       watch every character; equipping an eligible Tool attaches the carry visual
  Service.Attach(player, tool)         build "HeldItemCarry" in the character: a welded upright copy of the item in
                                       front of the torso (CarryGripLayout) + a rarity label for eggs. The Tool's own
                                       model is hidden (Transparency/Enabled restored by stopCarry).
  Service.DropTool(player, tool) -> boolean
                                       unequip, park the Tool in ServerStorage.DroppedItemStore and spawn a pickup
                                       model in workspace.DroppedCarryItems (beam, sparkles, label, bob animation).
Network authority: no remotes. Pickup is a server ProximityPrompt; the server checks alive, Backpack, distance <= 14,
and gives the dropper a 2 s grace period. Unclaimed drops return to the dropper after 60 s (destroyed if they left).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Service = {}
local carryRecords = {} -- [Player] = { tool, hidden = {[BasePart] = transparency}, off = {[effect] = true}?, visual? }
-- Instance.new(class, parent) is deprecated (selene: deprecated); kept as-is to keep creation order identical.
local droppedItemsFolder = workspace:FindFirstChild("DroppedCarryItems") or Instance.new("Folder", workspace)
droppedItemsFolder.Name = "DroppedCarryItems"
local function eligible(tool)
    return tool:IsA("Tool")
        and tool:GetAttribute("HoldStyle") ~= "OneHand"
        and (
            tool:GetAttribute("EggType") ~= nil
            or tool:GetAttribute("CharacterId") ~= nil
            or tool:GetAttribute("BrainrotId") ~= nil
        )
end
-- the item model inside the Tool (eggs: "Egg", characters: "Character")
local function sourceModelOf(tool)
    return tool:FindFirstChild("Egg") or tool:FindFirstChild("Character")
end
-- A copy of the tool's own model, put back in its upright build pose. The tool's model moves with the hand,
-- so copying it as-is gave mutated eggs/characters the arm's tilt (held sideways / rotated).
-- Eggs and characters are built with the Handle and the model both at the origin, so Handle space = upright.
local function uprightCopy(tool)
    local sourceModel = sourceModelOf(tool)
    local handle = tool:FindFirstChild("Handle")
    if not sourceModel then
        return nil
    end
    local copy = sourceModel:Clone()
    if handle and handle:IsA("BasePart") then
        local parts = {}
        for _, part in copy:GetDescendants() do
            if part:IsA("BasePart") then
                table.insert(parts, part)
            end
        end
        for _, part in parts do
            part.CFrame = handle.CFrame:ToObjectSpace(part.CFrame)
        end
        local box = copy:GetBoundingBox()
        copy.WorldPivot = CFrame.new(box.Position)
    end
    return copy
end
-- Which model to show for a carried / dropped item (the caller clones it).
-- Order: mutated own model -> golden variant -> clean catalog template -> the Tool's own model.
local function presentationOf(tool)
    -- mutated items keep their own mutated model + aura VFX (the plain templates would turn them back to normal)
    if tool:GetAttribute("Mutation") and sourceModelOf(tool) then
        return uprightCopy(tool)
    end
    if tool:GetAttribute("GoldVariant") then
        local future = game.ServerStorage:FindFirstChild("FutureUpdateContent")
        local kind = tool:GetAttribute("CharacterId") and "Characters" or "Eggs"
        local folder = future and future:FindFirstChild(kind)
        local gold = folder and folder:FindFirstChild("Golden Pirate")
        if gold then
            return gold
        end
    end
    local eggTemplates = game.ServerStorage:FindFirstChild("AuxEggTemplates")
    local characterModels = game.ServerStorage:FindFirstChild("BrainrotModels")
    local id = tool:GetAttribute("CharacterId") or tool:GetAttribute("BrainrotId")
    local template = id and characterModels and characterModels:FindFirstChild(id)
    if not template then
        local eggType = tool:GetAttribute("EggType")
        template = eggType and eggTemplates and eggTemplates:FindFirstChild(eggType)
    end
    return template or sourceModelOf(tool)
end
-- strip scripts, prompts, labels and sounds from a display copy
local function stripNonVisuals(model)
    for _, descendant in model:GetDescendants() do
        if
            descendant:IsA("LuaSourceContainer")
            or descendant:IsA("ProximityPrompt")
            or descendant:IsA("BillboardGui")
            or descendant:IsA("Sound")
        then
            descendant:Destroy()
        end
    end
end
local function calmVFX(model, factor)
    -- ScaleTo grows particles/lights with the model; held/dropped items keep normal-size, softer effects.
    local inverseScale = 1 / math.max(factor, 1)
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("ParticleEmitter") then
            local keypoints = {}
            for _, keypoint in descendant.Size.Keypoints do
                table.insert(
                    keypoints,
                    NumberSequenceKeypoint.new(
                        keypoint.Time,
                        math.min(keypoint.Value * inverseScale, 1.2),
                        math.min(keypoint.Envelope * inverseScale, 0.3)
                    )
                )
            end
            descendant.Size = NumberSequence.new(keypoints)
            descendant.Speed = NumberRange.new(descendant.Speed.Min * inverseScale, descendant.Speed.Max * inverseScale)
            descendant.Rate = descendant.Rate * 0.5
            descendant.LightEmission = math.min(descendant.LightEmission, 0.3)
            descendant.Brightness = math.min(descendant.Brightness, 1.5)
        elseif descendant:IsA("Light") then
            descendant.Range = math.min(descendant.Range * inverseScale, 8)
            descendant.Brightness = math.min(descendant.Brightness, 1)
        elseif descendant:IsA("Beam") or descendant:IsA("Trail") then
            descendant.LightEmission = math.min(descendant.LightEmission, 0.5)
        end
    end
end
-- remove the carry visual and un-hide the Tool's own model
local function stopCarry(player)
    local record = carryRecords[player]
    if not record then
        return
    end
    carryRecords[player] = nil
    if record.visual then
        record.visual:Destroy()
    end
    for part, transparency in record.hidden do
        if part.Parent then
            part.Transparency = transparency
        end
    end
    if record.off then
        for effect in record.off do
            if effect.Parent then
                effect.Enabled = true
            end
        end
    end
end
function Service.Attach(player, tool)
    if not eligible(tool) then
        return
    end
    local character = player.Character
    local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
    local original = sourceModelOf(tool)
    if not torso or not original or tool.Parent ~= character then
        return
    end
    stopCarry(player)
    local record = { tool = tool, hidden = {} }
    carryRecords[player] = record
    local model = Instance.new("Model")
    model.Name = "HeldItemCarry"
    local carrier = Instance.new("Part")
    carrier.Name = "Carrier"
    carrier.Size = Vector3.one * 0.2
    carrier.Transparency = 1
    carrier.Massless = true
    carrier.CanCollide = false
    carrier.CanTouch = false
    carrier.CanQuery = false
    carrier.CFrame = torso.CFrame * CFrame.new(0, -0.25, -1.15)
    carrier.Parent = model
    local visual = presentationOf(tool):Clone()
    stripNonVisuals(visual)
    local _, size = visual:GetBoundingBox()
    local isCharacter = tool:GetAttribute("CharacterId") or tool:GetAttribute("BrainrotId")
    local factor = isCharacter and 6 / math.max(size.Y, 0.01)
        or math.min(3.3 / math.max(size.Y, 0.01), 2.9 / math.max(size.X, 0.01)) -- eggs held at normal tool size
    visual:ScaleTo(visual:GetScale() * factor)
    calmVFX(visual, factor)
    local box, newSize = visual:GetBoundingBox()
    local halfWidth = math.clamp(newSize.X * 0.5, 0.45, isCharacter and 0.95 or 1.45)
    carrier.CFrame = require(game.ServerScriptService.CarryGripLayout).Frame(character, torso, halfWidth)
    visual:PivotTo(carrier.CFrame * box:ToObjectSpace(visual:GetPivot()))
    visual.Parent = model
    model:SetAttribute("GripHalfWidth", halfWidth)
    for _, part in visual:GetDescendants() do
        if part:IsA("BasePart") then
            part.Anchored = false
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
            part.Massless = true
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = carrier
            weld.Part1 = part
            weld.Parent = part
        end
    end
    local hold = Instance.new("WeldConstraint")
    hold.Part0 = torso
    hold.Part1 = carrier
    hold.Parent = carrier
    -- hide the Tool's own model (and its effects) while the carry copy is shown
    for _, descendant in original:GetDescendants() do
        if descendant:IsA("BasePart") then
            record.hidden[descendant] = descendant.Transparency
            descendant.Transparency = 1
        elseif
            (
                descendant:IsA("ParticleEmitter")
                or descendant:IsA("Light")
                or descendant:IsA("Beam")
                or descendant:IsA("Trail")
            ) and descendant.Enabled
        then
            record.off = record.off or {}
            record.off[descendant] = true
            descendant.Enabled = false
        end
    end
    if not isCharacter then -- name + glowing rarity over a held egg, readable from a distance
        local HELD_RARITY_COLORS = {
            Common = Color3.fromRGB(220, 225, 235),
            Uncommon = Color3.fromRGB(20, 255, 0),
            Rare = Color3.fromRGB(31, 139, 255),
            Epic = Color3.fromRGB(182, 61, 255),
            Legendary = Color3.fromRGB(255, 196, 0),
        }
        local rarity = tool:GetAttribute("Rarity")
        local eggType = tool:GetAttribute("EggType")
        if not rarity and eggType then
            local ok, CharacterCatalog = pcall(require, ReplicatedStorage:FindFirstChild("CharacterCatalog"))
            if ok and CharacterCatalog.ById[eggType] then
                rarity = CharacterCatalog.ById[eggType].Rarity
            end
        end
        rarity = HELD_RARITY_COLORS[rarity] and rarity or "Common"
        local rarityColor = HELD_RARITY_COLORS[rarity]
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "HeldEggLabel"
        billboard.Size = UDim2.fromOffset(200, 58)
        billboard.StudsOffset = Vector3.new(0, newSize.Y * 0.5 + 1.4, 0)
        billboard.MaxDistance = 160
        billboard.LightInfluence = 0
        billboard.AlwaysOnTop = false
        billboard.Adornee = carrier
        billboard.Parent = model
        local function addLabel(text, y, height, textSize, color, strokeColor, strokeThickness)
            local label = Instance.new("TextLabel")
            label.BackgroundTransparency = 1
            label.Position = UDim2.fromOffset(0, y)
            label.Size = UDim2.new(1, 0, 0, height)
            label.Font = Enum.Font.FredokaOne
            label.Text = text
            label.TextSize = textSize
            label.TextColor3 = color
            label.Parent = billboard
            local stroke = Instance.new("UIStroke")
            stroke.Color = strokeColor
            stroke.Thickness = strokeThickness
            stroke.LineJoinMode = Enum.LineJoinMode.Round
            stroke.Parent = label
            return label, stroke
        end
        addLabel(
            (eggType or tool.Name):gsub("%s*[Ee]gg$", "") .. " Egg",
            0,
            28,
            24,
            Color3.new(1, 1, 1),
            Color3.fromRGB(11, 10, 14),
            2
        )
        -- rarity text drawn twice: a soft glow layer (pulsing stroke) under a crisp white layer
        local glowLabel, glowStroke = addLabel(string.upper(rarity), 28, 26, 20, rarityColor, rarityColor, 6)
        glowLabel.TextTransparency = 0.4
        glowStroke.Transparency = 0.55
        local _rarityLabel, _rarityStroke =
            addLabel(string.upper(rarity), 28, 26, 20, Color3.new(1, 1, 1), rarityColor, 2.6)
        game:GetService("TweenService")
            :Create(
                glowStroke,
                TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { Transparency = 0.9, Thickness = 9 }
            )
            :Play()
    end
    model.Parent = character
    record.visual = model
end
function Service.DropTool(player, tool)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if
        not root
        or not humanoid
        or humanoid.Health <= 0
        or not eligible(tool)
        or not (tool.Parent == character or tool.Parent == player:FindFirstChildOfClass("Backpack"))
    then
        return false
    end
    local original = sourceModelOf(tool)
    if not original then
        return false
    end
    stopCarry(player)
    humanoid:UnequipTools()
    local model = Instance.new("Model")
    model.Name = tool.Name .. " Dropped"
    local visual = presentationOf(tool):Clone()
    stripNonVisuals(visual) -- mutated eggs use their own mutated model + aura (see presentationOf)
    local characterItem = tool:GetAttribute("CharacterId") or tool:GetAttribute("BrainrotId")
    local _, size = visual:GetBoundingBox()
    -- dropped eggs are big and easy to spot (about 1.6x the held size)
    local dropFactor = characterItem and 6 / math.max(size.Y, 0.01)
        or math.min(5.2 / math.max(size.Y, 0.01), 4.6 / math.max(size.X, 0.01))
    visual:ScaleTo(visual:GetScale() * dropFactor)
    calmVFX(visual, dropFactor)
    local box, newSize = visual:GetBoundingBox()
    -- land a few studs to the side so the knocked-out player doesn't fall on it
    local direction = CFrame.Angles(0, math.random() * math.pi * 2, 0).LookVector
    local position = root.Position + direction * 4
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { character, droppedItemsFolder }
    local hit = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), rayParams)
    local groundY = hit and hit.Position.Y or (root.Position.Y - 3)
    local restY = groundY + newSize.Y * 0.5 + 0.6
    local offset = box:ToObjectSpace(visual:GetPivot())
    visual:PivotTo(CFrame.new(position.X, restY + 6, position.Z) * offset)
    visual.Parent = model
    for _, part in visual:GetDescendants() do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
        end
    end
    local anchor = Instance.new("Part")
    anchor.Name = "PickupAnchor"
    anchor.Anchored = true
    anchor.Transparency = 1
    anchor.Size = Vector3.one
    anchor.Position = Vector3.new(position.X, restY, position.Z)
    anchor.CanCollide = false
    anchor.CanTouch = false
    anchor.CanQuery = false
    anchor.Parent = model
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Pick up"
    prompt.ObjectText = tool.Name
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.MaxActivationDistance = 12
    prompt.HoldDuration = 0.2
    prompt.RequiresLineOfSight = false
    prompt.Parent = anchor
    -- rarity colour for the FX
    local DROP_RARITY_COLORS = {
        Common = Color3.fromRGB(235, 240, 255),
        Uncommon = Color3.fromRGB(60, 255, 90),
        Rare = Color3.fromRGB(60, 160, 255),
        Epic = Color3.fromRGB(190, 90, 255),
        Legendary = Color3.fromRGB(255, 200, 40),
        Limited = Color3.fromRGB(255, 60, 90),
    }
    local MUTATION_COLORS = {
        Silver = Color3.fromRGB(220, 230, 245),
        Gold = Color3.fromRGB(255, 200, 60),
        Diamond = Color3.fromRGB(90, 225, 255),
        Rainbow = Color3.fromRGB(255, 90, 220),
    }
    local rarity = tool:GetAttribute("Rarity")
    local eggId = tool:GetAttribute("EggType")
    if not rarity and eggId then
        local ok, CharacterCatalog = pcall(require, ReplicatedStorage:FindFirstChild("CharacterCatalog"))
        if ok and CharacterCatalog.ById[eggId] then
            rarity = CharacterCatalog.ById[eggId].Rarity
        end
    end
    local mutation = tool:GetAttribute("Mutation")
    local fxColor = MUTATION_COLORS[mutation] or DROP_RARITY_COLORS[rarity] or DROP_RARITY_COLORS.Common
    -- light pillar + glow + sparkles + ground ring
    local beamBottom = Instance.new("Attachment")
    beamBottom.Parent = anchor
    beamBottom.Position = Vector3.new(0, -newSize.Y * 0.5, 0)
    local beamTop = Instance.new("Attachment")
    beamTop.Parent = anchor
    beamTop.Position = Vector3.new(0, 22, 0)
    local beam = Instance.new("Beam")
    beam.Attachment0 = beamBottom
    beam.Attachment1 = beamTop
    beam.Width0 = 2.6
    beam.Width1 = 0.4
    beam.FaceCamera = true
    beam.LightEmission = 1
    beam.LightInfluence = 0
    beam.Color = ColorSequence.new(fxColor)
    beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
    beam.Parent = anchor
    local light = Instance.new("PointLight")
    light.Color = fxColor
    light.Range = 14
    light.Brightness = 2.5
    light.Parent = anchor
    local sparkles = Instance.new("ParticleEmitter")
    sparkles.Name = "DropSparkles"
    sparkles.Color = ColorSequence.new(Color3.new(1, 1, 1), fxColor)
    sparkles.LightEmission = 1
    sparkles.Rate = 14
    sparkles.Lifetime = NumberRange.new(0.8, 1.4)
    sparkles.Speed = NumberRange.new(2, 4)
    sparkles.SpreadAngle = Vector2.new(180, 180)
    sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
    sparkles.Parent = anchor
    local burst = sparkles:Clone()
    burst.Name = "DropBurst"
    burst.Rate = 0
    burst.Speed = NumberRange.new(10, 18)
    burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
    burst.Parent = anchor
    local ring = Instance.new("Part")
    ring.Name = "GlowRing"
    ring.Shape = Enum.PartType.Cylinder
    ring.Anchored = true
    ring.CanCollide = false
    ring.CanTouch = false
    ring.CanQuery = false
    ring.Material = Enum.Material.Neon
    ring.Color = fxColor
    ring.Transparency = 0.35
    ring.Size = Vector3.new(0.15, newSize.X * 1.6, newSize.X * 1.6)
    ring.CFrame = CFrame.new(position.X, groundY + 0.08, position.Z) * CFrame.Angles(0, 0, math.pi / 2)
    ring.Parent = model
    -- floating label
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "DropLabel"
    billboard.Adornee = anchor
    billboard.Size = UDim2.fromOffset(240, 64)
    billboard.StudsOffset = Vector3.new(0, newSize.Y * 0.5 + 2.2, 0)
    billboard.MaxDistance = 120
    billboard.LightInfluence = 0
    billboard.AlwaysOnTop = true
    billboard.Parent = model
    local function addLabel(text, y, height, textSize, color, strokeThickness)
        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Position = UDim2.fromOffset(0, y)
        label.Size = UDim2.new(1, 0, 0, height)
        label.Font = Enum.Font.FredokaOne
        label.Text = text
        label.TextSize = textSize
        label.TextColor3 = color
        label.Parent = billboard
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(11, 10, 14)
        stroke.Thickness = strokeThickness
        stroke.Parent = label
        return label
    end
    local titleLabel = addLabel("DROPPED!", 0, 30, 28, fxColor, 3)
    addLabel(
        ((mutation and (mutation .. " ") or "") .. (eggId or tool.Name:gsub("%s*[Ee]gg$", ""))) .. " Egg  •  grab it!",
        30,
        26,
        19,
        Color3.new(1, 1, 1),
        2
    )
    local TweenService = game:GetService("TweenService")
    TweenService:Create(
        titleLabel,
        TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { TextSize = 32 }
    ):Play()
    -- the owned Tool is parked in ServerStorage: a Tool sitting in Workspace is auto-picked up by touch,
    -- which used to put it straight back into the knocked-out player's hand and left an empty egg on the ground
    local dropStore = game.ServerStorage:FindFirstChild("DroppedItemStore") or Instance.new("Folder")
    dropStore.Name = "DroppedItemStore"
    dropStore.Parent = game.ServerStorage
    local itemStorage = Instance.new("Folder")
    itemStorage.Name = game.HttpService:GenerateGUID(false)
    itemStorage.Parent = dropStore
    -- remove the dropper's StarterGear copy of this item, so it can't come back on respawn
    local itemId = tool:GetAttribute("EggId") or tool:GetAttribute("CarryItemId")
    if not itemId then
        itemId = game.HttpService:GenerateGUID(false)
        tool:SetAttribute("CarryItemId", itemId)
    end
    local starterGear = player:FindFirstChild("StarterGear")
    if starterGear then
        for _, other in starterGear:GetChildren() do
            if
                other:IsA("Tool")
                and (other:GetAttribute("EggId") == itemId or other:GetAttribute("CarryItemId") == itemId)
            then
                other:Destroy()
            end
        end
    end
    tool.Enabled = true
    tool:SetAttribute("ReturningToBase", nil)
    tool.Parent = itemStorage
    model.Parent = droppedItemsFolder
    -- pop: fall in with a bounce, burst of sparkles, then bob + spin
    local alive = true
    task.spawn(function()
        local startedAt = os.clock()
        while alive and model.Parent do
            local elapsed = os.clock() - startedAt
            local y
            if elapsed < 0.45 then
                local progress = elapsed / 0.45
                y = restY + 6 * (1 - progress * progress)
            elseif elapsed < 0.75 then
                local progress = (elapsed - 0.45) / 0.3
                y = restY + math.sin(progress * math.pi) * 1.2
            else
                y = restY + math.sin((elapsed - 0.75) * 2.4) * 0.35
            end
            visual:PivotTo(CFrame.new(position.X, y, position.Z) * CFrame.Angles(0, elapsed * 1.6, 0) * offset)
            if elapsed >= 0.45 and not burst:GetAttribute("Done") then
                burst:SetAttribute("Done", true)
                burst:Emit(40)
            end
            task.wait(1 / 30)
        end
    end)
    local claimed = false
    local droppedBy, droppedAt = player, os.clock()
    local function finish()
        alive = false
        claimed = true
        prompt.Enabled = false
        if model.Parent then
            model:Destroy()
        end
        if itemStorage.Parent and #itemStorage:GetChildren() == 0 then
            itemStorage:Destroy()
        end
    end
    prompt.Triggered:Connect(function(picker)
        if claimed or tool.Parent ~= itemStorage then
            return
        end
        if picker == droppedBy and os.clock() - droppedAt < 2 then
            return
        end
        local pickerRoot = picker.Character and picker.Character:FindFirstChild("HumanoidRootPart")
        local pickerHumanoid = picker.Character and picker.Character:FindFirstChildOfClass("Humanoid")
        local backpack = picker:FindFirstChildOfClass("Backpack")
        if
            not pickerRoot
            or not pickerHumanoid
            or pickerHumanoid.Health <= 0
            or not backpack
            or (pickerRoot.Position - anchor.Position).Magnitude > 14
        then
            return
        end
        tool.Parent = backpack
        finish()
        -- eggs go into the "carry it home" phase again; characters are just equipped
        if tool:GetAttribute("EggType") and not tool:GetAttribute("CharacterId") then
            local ok = pcall(require(game.ServerScriptService.RiverEggCarryService).Begin, picker, tool)
            if not ok then
                pickerHumanoid:EquipTool(tool)
            end
        else
            pickerHumanoid:EquipTool(tool)
        end
    end)
    -- nobody grabbed it: back to whoever dropped it after 60 s (or gone if they left)
    task.delay(60, function()
        if claimed or tool.Parent ~= itemStorage then
            return
        end
        local backpack = droppedBy.Parent and droppedBy:FindFirstChildOfClass("Backpack")
        if backpack then
            tool.Parent = backpack
        else
            tool:Destroy()
        end
        finish()
    end)
    return true
end
local function watchCharacter(player, character)
    character.ChildAdded:Connect(function(tool)
        if eligible(tool) then
            task.defer(Service.Attach, player, tool)
        end
    end)
    character.ChildRemoved:Connect(function(tool)
        local record = carryRecords[player]
        if record and record.tool == tool then
            stopCarry(player)
        end
    end)
    for _, tool in character:GetChildren() do
        if eligible(tool) then
            Service.Attach(player, tool)
        end
    end
end
function Service.Init()
    local function watchPlayer(player)
        player.CharacterAdded:Connect(function(character)
            stopCarry(player)
            watchCharacter(player, character)
        end)
        if player.Character then
            watchCharacter(player, player.Character)
        end
    end
    for _, player in Players:GetPlayers() do
        watchPlayer(player)
    end
    Players.PlayerAdded:Connect(watchPlayer)
    Players.PlayerRemoving:Connect(stopCarry)
end
return Service
