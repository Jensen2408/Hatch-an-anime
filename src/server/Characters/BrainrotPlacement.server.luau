local Players = game:GetService("Players")
local Catalog = require(game.ReplicatedStorage.CharacterCatalog)
local Economy = require(game.ReplicatedStorage.CharacterEconomy)
local SlotUnlocks = require(script.Parent.TempleSlotUnlocks)
local templates = game.ServerStorage:WaitForChild("BrainrotModels")
local Mutations = require(script.Parent:WaitForChild("Mutations"))
local plots = workspace:WaitForChild("Plots")
local function setup(plot)
    SlotUnlocks.Setup(plot)
    for _, slot in plot.Slots:GetChildren() do
        local base = slot.Platform
        local prompt = base.PlacePrompt
        local function placeCharacter(player, chosenTool) -- CharacterInventory: chosenTool = a specific backpack/held character
            if plot:GetAttribute("OwnerUserId") ~= player.UserId or slot:GetAttribute("Occupied") then
                return
            end
            if chosenTool and not slot:GetAttribute("Unlocked") then
                return
            end -- CharacterInventory: never buys a slot
            if not slot:GetAttribute("Unlocked") then
                local bought, reason = SlotUnlocks.Purchase(plot, slot, player)
                if not bought and reason == "Not enough money" then
                    local old = prompt.ActionText
                    prompt.ActionText = "Not enough money"
                    task.delay(1.5, function()
                        if prompt.Parent then
                            SlotUnlocks.Refresh(plot)
                        end
                    end)
                end
                return
            end
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local tool = chosenTool or (character and character:FindFirstChildOfClass("Tool"))
            if
                chosenTool
                and not (
                    typeof(tool) == "Instance"
                    and tool:IsA("Tool")
                    and (tool.Parent == character or tool.Parent == player:FindFirstChildOfClass("Backpack"))
                )
            then
                return
            end -- CharacterInventory
            if not root or (not chosenTool and (root.Position - base.Position).Magnitude > 12) or not tool then
                return
            end
            local id = tool:GetAttribute("BrainrotId")
            local template = id and templates:FindFirstChild(id)
            if tool:GetAttribute("GoldVariant") then
                template = game.ServerStorage.FutureUpdateContent.Characters:FindFirstChild("Golden Pirate")
            end
            if not template or not template:IsA("Model") then
                return
            end
            local stats = Economy.Read(tool, id) or Economy.Roll(id)
            local rate = stats.IncomePerSecond
            if type(rate) ~= "number" or rate < 0 or rate ~= rate or rate == math.huge then
                return
            end
            local placementToken = game:GetService("HttpService"):GenerateGUID(false)
            slot:SetAttribute("PlacementToken", placementToken)
            slot:SetAttribute("Occupied", true)
            local mutation = tool:GetAttribute("Mutation")
            local display = (mutation and Mutations.Model(id, mutation, template)) or template:Clone()
            if mutation then
                display:SetAttribute("Mutation", mutation)
            end
            display.Name = slot.Name .. "_Brainrot"
            for _, p in display:GetDescendants() do
                if p:IsA("BasePart") then
                    p.Anchored = true
                    p.CanCollide = false
                    p.CanTouch = false
                end
            end
            local _, size = display:GetBoundingBox()
            display:ScaleTo(display:GetScale() * 6 / math.max(size.Y, 0.01))
            -- Finish placement before replicating the display to clients.
            local stand = slot:FindFirstChild("MoneyStand")
            -- The saved stand has the same surface even if the live stand is still spawning.
            local standTemplates = game.ServerStorage:FindFirstChild("MoneyStandPlotTemplates")
            local plotTemplates = standTemplates and standTemplates:FindFirstChild(plot.Name)
            local geometry = stand or (plotTemplates and plotTemplates:FindFirstChild(slot.Name))
            local support = geometry and geometry:FindFirstChild("CharacterSlot")
            assert(support, "Missing podium surface: " .. plot.Name .. "." .. slot.Name)
            local box, displaySize = display:GetBoundingBox()
            local center = support.Position + Vector3.new(0, support.Size.Y / 2 + displaySize.Y / 2, 0)
            local facing = -geometry.Plate.CFrame.LookVector
            display.PrimaryPart = nil
            display.WorldPivot = CFrame.new(box.Position)
            local home = CFrame.lookAt(center, center + facing)
            display:SetAttribute("DisplayHeight", 6)
            display:SetAttribute("SlotSurfaceY", support.Position.Y + support.Size.Y / 2)
            display:PivotTo(home)
            display:SetAttribute("DisplayHome", home)
            display:SetAttribute("FloatHeight", 0.65)
            local partCount = 0
            for _, part in display:GetDescendants() do
                if part:IsA("BasePart") then
                    partCount += 1
                end
            end
            display:SetAttribute("DisplayPartCount", partCount)
            Economy.Apply(display, id, stats)
            display:SetAttribute("ItemId", tool:GetAttribute("ItemId"))
            display:SetAttribute("AcquiredAt", tool:GetAttribute("AcquiredAt")) -- CharacterInventory
            if tool:GetAttribute("GoldVariant") then
                display:SetAttribute("GoldVariant", true)
            end -- CharacterInventory
            display:SetAttribute("CharacterId", id)
            display:SetAttribute("BrainrotId", id) -- golden model carries its own "Golden Pirate" id; keep the real one so it can be picked up
            if mutation then
                Mutations.AddAura(display, mutation)
            end
            display.Parent = plot.PlacedItems
            game.CollectionService:AddTag(display, "FloatingCharacter")
            -- labels are drawn locally by StarterPlayerScripts.CharacterInfoClient (tag FloatingCharacter)
            tool:Destroy()
            prompt.Enabled = false
            task.spawn(function()
                while display.Parent and plot:GetAttribute("OwnerUserId") == player.UserId do
                    task.wait(1)
                    if not display.Parent or plot:GetAttribute("OwnerUserId") ~= player.UserId then
                        break
                    end
                    local stats = player:FindFirstChild("leaderstats")
                    local cash = stats and stats:FindFirstChild("Cash")
                    local stand = slot:FindFirstChild("MoneyStand")
                    if stand and stand:GetAttribute("OwnerUserId") == player.UserId then
                        stand:SetAttribute("IncomePerSecond", rate)
                        stand:SetAttribute(
                            "Stored",
                            (stand:GetAttribute("Stored") or 0)
                                + rate
                                    * ((workspace:GetAttribute("OwnerIncomeMultiplier") or 1) * (workspace:GetAttribute(
                                        "NightCashMultiplier"
                                    ) or 1) * (player:GetAttribute("CashMultiplier") or 1))
                        )
                    end
                end
                game.CollectionService:RemoveTag(display, "FloatingCharacter")
                if display.Parent then
                    display:Destroy()
                end
                if slot:GetAttribute("PlacementToken") == placementToken then
                    slot:SetAttribute("Occupied", false)
                    slot:SetAttribute("PlacementToken", nil)
                    SlotUnlocks.Refresh(plot)
                end
            end)
            -- FloatingCharacters handles showcase motion locally; no competing server animation.
            return true -- CharacterInventory
        end
        prompt.Triggered:Connect(placeCharacter)
        local request = base:FindFirstChild("RequestPlaceCharacter") or Instance.new("BindableEvent")
        request.Name = "RequestPlaceCharacter"
        request.Parent = base
        request.Event:Connect(placeCharacter)
        local invoke = base:FindFirstChild("InvokePlaceCharacter") or Instance.new("BindableFunction") -- CharacterInventory
        invoke.Name = "InvokePlaceCharacter"
        invoke.Parent = base
        invoke.OnInvoke = placeCharacter -- CharacterInventory
    end
end
local function joined(p)
    local stats = p:FindFirstChild("leaderstats") or Instance.new("Folder", p)
    stats.Name = "leaderstats"
    if not stats:FindFirstChild("Cash") then
        local cash = Instance.new("NumberValue", stats)
        cash.Name = "Cash"
    end
end
Players.PlayerAdded:Connect(joined)
for _, p in Players:GetPlayers() do
    joined(p)
end
for _, plot in plots:GetChildren() do
    setup(plot)
end
