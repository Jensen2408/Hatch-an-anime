--[[ ServerStorage.FutureUpdateContent.RiverBeforeGoldContentReservation  (server Script, PARKED)
Snapshot of the river egg spawner from before the golden-egg content, reserved for a future update. It does not
run: Scripts never execute in ServerStorage (it is not marked Disabled in default.project.json, so moving it to
ServerScriptService would start it immediately, next to the live PirateEggFreeConveyor using the same folder
and remote).
Spawns a free egg from ServerStorage.AuxEggTemplates (round-robin by Order) into workspace.WaterfallEggs every
SpawnInterval seconds, moved by workspace.PirateEggConveyor.RollingMotion.
Network authority: ReplicatedStorage.CollectRiverEgg:FireServer(egg) is only honoured while the egg is in its
"travel" phase and the player's root is within 17 studs; the server builds the egg Tool itself.
]]
local _RunService = game:GetService("RunService")
local conveyor = workspace:WaitForChild("PirateEggConveyor")
local templates = game.ServerStorage:WaitForChild("AuxEggTemplates"):GetChildren()
table.sort(templates, function(templateA, templateB)
    return templateA:GetAttribute("Order") < templateB:GetAttribute("Order")
end)
local eggFolder = workspace:WaitForChild("WaterfallEggs")
local RollingMotion = require(conveyor:WaitForChild("RollingMotion"))
local collectHandlers = {} -- [egg Model] = collectEgg(player) while the egg can be collected
local serial = 0
local function spawnEgg()
    serial += 1
    local template = templates[(serial - 1) % #templates + 1]
    local egg = template:Clone()
    egg.Name = "RiverEgg_" .. serial
    egg:SetAttribute("Sequence", serial)
    egg:PivotTo(CFrame.new(conveyor:GetAttribute("FallStart")))
    for _, name in { "LabelAnchor", "CollectAnchor" } do
        local anchorCopy = conveyor[name]:Clone()
        anchorCopy.CFrame = egg:GetPivot()
        anchorCopy.Parent = egg
    end
    local labelAnchor = egg.LabelAnchor
    for _, existingGui in labelAnchor:GetChildren() do
        if existingGui:IsA("BillboardGui") then
            existingGui:Destroy()
        end
    end
    local gui = Instance.new("BillboardGui")
    gui.Name = "EggName"
    gui.Size = UDim2.fromOffset(190, 65)
    gui.MaxDistance = 100
    gui.AlwaysOnTop = false
    gui.Parent = labelAnchor
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.fromScale(1, 1)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 21
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextStrokeTransparency = 0.2
    nameLabel.Text = template.Name .. " Egg\nFREE"
    nameLabel.Parent = gui
    if template:GetAttribute("Golden") then
        nameLabel.TextColor3 = Color3.fromRGB(255, 219, 111)
    end
    local prompt = egg.CollectAnchor:FindFirstChildOfClass("ProximityPrompt")
    if prompt then
        prompt.ObjectText = template.Name .. " Egg"
        prompt.ActionText = "Collect • Free"
    end
    egg:SetAttribute("Epoch", workspace:GetServerTimeNow())
    egg.Parent = eggFolder
    local _update, pose = RollingMotion(conveyor, egg)
    local _, _, _, duration = pose(0)

    local collectPrompt = egg.CollectAnchor:FindFirstChildOfClass("ProximityPrompt")
    local collected = false
    local function collectEgg(player)
        if collected or not egg.Parent then
            return
        end
        local eggCFrame, phase = pose(workspace:GetServerTimeNow() - egg:GetAttribute("Epoch"))
        if phase ~= "travel" then
            return
        end
        local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local backpack = player:FindFirstChildOfClass("Backpack")
        if not rootPart or not backpack or (rootPart.Position - eggCFrame.Position).Magnitude > 17 then
            return
        end
        collected = true
        local tool = Instance.new("Tool")
        tool.Name = template.Name .. " Egg"
        tool.ToolTip = "FREE"
        tool:SetAttribute("EggType", template.Name)
        tool.CanBeDropped = false
        tool:SetAttribute("Price", 0)
        local visual = template:Clone()
        visual.Name = "Egg"
        visual:ScaleTo(template:GetScale() * 0.5)
        visual:PivotTo(CFrame.new())
        visual.Parent = tool
        local handle = Instance.new("Part")
        handle.Name = "Handle"
        handle.Size = Vector3.one
        handle.Transparency = 1
        handle.CanCollide = false
        handle.Massless = true
        handle.Parent = tool
        for _, descendant in visual:GetDescendants() do
            if descendant:IsA("BasePart") then
                descendant.Anchored = false
                descendant.CanCollide = false
                descendant.CanTouch = false
                descendant.Massless = true
                local weld = Instance.new("WeldConstraint")
                weld.Part0 = handle
                weld.Part1 = descendant
                weld.Parent = handle
            end
        end
        tool.Parent = backpack
        collectHandlers[egg] = nil
        egg:Destroy()
    end
    collectHandlers[egg] = collectEgg
    if collectPrompt then
        collectPrompt.Triggered:Connect(collectEgg)
    end
    task.delay(duration - 0.05, function()
        collectHandlers[egg] = nil
        if egg.Parent then
            egg:Destroy()
        end
    end)
end
game.ReplicatedStorage.CollectRiverEgg.OnServerEvent:Connect(function(player, egg)
    if typeof(egg) ~= "Instance" then
        return
    end
    local collectHandler = collectHandlers[egg]
    if collectHandler then
        collectHandler(player)
    end
end)
while true do
    spawnEgg()
    task.wait(conveyor:GetAttribute("SpawnInterval") or 5)
end
