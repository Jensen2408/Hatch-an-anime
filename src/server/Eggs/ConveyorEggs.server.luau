--[[ ServerScriptService.ConveyorEggs  (Script, SERVER)
Legacy free-egg conveyor: every 6 s spawns a random egg (weighted by EggCatalog[i].Weight, roll 0..100) at
workspace.EggConveyor.Belt.EggStart and tweens it to EggEnd. Exits immediately if workspace has no EggConveyor.
Collecting = server-side ProximityPrompt "Collect (Free)": the server checks alive, Backpack + StarterGear exist,
and distance <= 12 studs, then puts a new egg Tool in the Backpack (no StarterGear copy).
Uses: ServerStorage.EggTemplates / EggLabelTemplates, ReplicatedStorage.EggCatalog / EggUIStyle,
ReplicatedStorage.EggCollected (place-owned RemoteEvent, server -> client: eggId, eggCFrame, eggSize for pickup FX).
]]
local _Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local templates = game.ServerStorage:WaitForChild("EggTemplates")
local EGG_CATALOG = require(ReplicatedStorage:WaitForChild("EggCatalog"))
local eggCollectedEvent = ReplicatedStorage:WaitForChild("EggCollected")
local conveyor = workspace:FindFirstChild("EggConveyor")
if not conveyor then
    return
end
local belt = conveyor:WaitForChild("Belt")
local eggFolder = Instance.new("Folder")
eggFolder.Name = "ConveyorEggs"
eggFolder.Parent = workspace
local random = Random.new()
local function chooseEntry()
    local roll = random:NextNumber(0, 100)
    local sum = 0
    for _, entry in ipairs(EGG_CATALOG) do
        sum += entry.Weight
        if roll < sum then
            return entry
        end
    end
    return EGG_CATALOG[#EGG_CATALOG]
end
-- The owned inventory Tool: Handle = template clone scaled to 2.6 studs tall.
local function makeTool(entry)
    local tool = Instance.new("Tool")
    tool.Name = entry.Name .. " Egg"
    tool.ToolTip = entry.Rarity .. " • " .. entry.Name
    tool.CanBeDropped = false
    tool:SetAttribute("EggType", entry.Id)
    tool:SetAttribute("Rarity", entry.Rarity)
    tool:SetAttribute("Price", entry.Price)
    tool:SetAttribute("EggId", game:GetService("HttpService"):GenerateGUID(false))
    local handle = templates[entry.Id]:Clone()
    handle.Name = "Handle"
    handle.Size *= 2.6 / handle.Size.Y
    handle.Anchored = false
    handle.CanCollide = false
    handle.CanTouch = false
    handle.Massless = true
    handle.Parent = tool
    return tool
end
-- World egg on the belt (4.8 studs tall) with a price tag, collect prompt and belt tween.
local function spawnEgg()
    local entry = chooseEntry()
    local egg = templates[entry.Id]:Clone()
    egg.Name = entry.Id
    egg.Size *= 4.8 / egg.Size.Y
    egg.Anchored = true
    egg.CanCollide = false
    egg.CanTouch = false
    egg:SetAttribute("EggType", entry.Id)
    egg:SetAttribute("Rarity", entry.Rarity)
    egg:SetAttribute("Price", entry.Price)
    local startPos = belt.EggStart.WorldPosition
    local endPos = belt.EggEnd.WorldPosition
    local eggCenterY = belt.Position.Y + belt.Size.Y / 2 + egg.Size.Y / 2 + 0.1
    startPos = Vector3.new(startPos.X, eggCenterY, startPos.Z)
    endPos = Vector3.new(endPos.X, eggCenterY, endPos.Z)
    egg.Position = startPos
    egg.Parent = eggFolder
    local customLabel = game.ServerStorage.EggLabelTemplates:FindFirstChild(entry.Id)
    if customLabel then
        local gui = customLabel:Clone()
        gui.Name = "PriceTag"
        gui.Adornee = egg
        gui.StudsOffsetWorldSpace = Vector3.new(0, 4.3, 0)
        gui.MaxDistance = 95
        gui.Enabled = true
        local content = gui.EggLabel.EggLabelContent
        content.Rarity.Text = entry.Rarity
        content.Price.Text = "$" .. entry.Price
        gui.Parent = egg
    else
        local Style = require(ReplicatedStorage.EggUIStyle)
        local gui = Instance.new("BillboardGui")
        gui.Name = "PriceTag"
        gui.Size = UDim2.fromScale(7.6, 3.2)
        gui.StudsOffsetWorldSpace = Vector3.new(0, 4.3, 0)
        gui.MaxDistance = 95
        gui.Parent = egg
        local frame = Style.Panel(gui, entry.Color)
        Style.Text(frame, entry.Name .. " Egg", UDim2.fromScale(0.04, 0.06), UDim2.fromScale(0.92, 0.33))
        Style.Text(
            frame,
            string.upper(entry.Rarity),
            UDim2.fromScale(0.08, 0.43),
            UDim2.fromScale(0.84, 0.20),
            Color3.fromRGB(255, 239, 154)
        )
        local priceBadge = Instance.new("Frame")
        priceBadge.Position = UDim2.fromScale(0.25, 0.69)
        priceBadge.Size = UDim2.fromScale(0.5, 0.26)
        priceBadge.BackgroundColor3 = Color3.fromRGB(54, 189, 72)
        priceBadge.BorderSizePixel = 0
        priceBadge.ZIndex = 2
        priceBadge.Parent = frame
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.25, 0)
        corner.Parent = priceBadge
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 2
        stroke.Color = Color3.fromRGB(20, 30, 20)
        stroke.Parent = priceBadge
        Style.Text(priceBadge, "$" .. entry.Price, UDim2.fromScale(0.04, 0), UDim2.fromScale(0.92, 1))
    end
    local speed = math.max(math.abs(conveyor:GetAttribute("Speed") or 12), 1)
    local tween = TweenService:Create(
        egg,
        TweenInfo.new((endPos - startPos).Magnitude / speed, Enum.EasingStyle.Linear),
        { Position = endPos }
    )
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "CollectPrompt"
    prompt.ActionText = "Collect (Free)"
    prompt.ObjectText = entry.Name .. " • " .. entry.Rarity
    prompt.HoldDuration = 0.15
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Parent = egg
    local collected = false -- one collect per egg (prompt can fire for several players in one frame)
    prompt.Triggered:Connect(function(player)
        if collected or not egg.Parent then
            return
        end
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local backpack = player:FindFirstChildOfClass("Backpack")
        local starterGear = player:FindFirstChild("StarterGear")
        if
            not root
            or not humanoid
            or humanoid.Health <= 0
            or not backpack
            or not starterGear
            or (root.Position - egg.Position).Magnitude > 12
        then
            return
        end
        collected = true
        prompt.Enabled = false
        local tool = makeTool(entry)
        tool.Parent = backpack
        eggCollectedEvent:FireClient(player, entry.Id, egg.CFrame, egg.Size)
        tween:Cancel()
        egg:Destroy()
    end)
    tween.Completed:Once(function()
        if egg.Parent then
            egg:Destroy()
        end
    end)
    tween:Play()
end
-- Spawn loop (runs forever; nothing after this line executes).
while true do
    spawnEgg()
    task.wait(6)
end
