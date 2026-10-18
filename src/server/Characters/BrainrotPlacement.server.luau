--[[ ServerScriptService.BrainrotPlacement  (Script)
Server-authoritative placement of hatched characters on temple slots, plus the per-slot income loop.

For every Plots.<plot>.Slots.<slot>.Platform this script wires one `placeCharacter(player, chosenTool?)`
to three entry points:
  • Platform.PlacePrompt.Triggered          (ProximityPrompt — the player walks up, uses the held Tool)
  • Platform.RequestPlaceCharacter.Event    (BindableEvent, created here if missing)
  • Platform.InvokePlaceCharacter.OnInvoke  (BindableFunction, created here if missing; used by
                                             CharacterInventory.InventoryService with an explicit Tool,
                                             returns true on success)
A locked slot is bought via TempleSlotUnlocks only when no chosenTool is given (prompt / request event),
never through the inventory path.

Placement result (attributes are read by FloatingCharacters / CharacterInfoClient / InventoryService):
  slot:      Occupied, PlacementToken (GUID guarding against a stale income loop freeing a re-used slot)
  display:   Plots.<plot>.PlacedItems.<slot>_Brainrot, tag "FloatingCharacter", attributes DisplayHeight,
             SlotSurfaceY, DisplayHome, FloatHeight, DisplayPartCount, ItemId, AcquiredAt, GoldVariant,
             CharacterId, BrainrotId, Mutation + CharacterEconomy stats
Every second while the plot owner is unchanged and the display exists, the slot's MoneyStand "Stored"
grows by IncomePerSecond × OwnerIncomeMultiplier × NightCashMultiplier × player CashMultiplier.
Also ensures every player has leaderstats.Cash.
]]
local Players = game:GetService("Players")

local _Catalog = require(game.ReplicatedStorage.CharacterCatalog)
local Economy = require(game.ReplicatedStorage.CharacterEconomy)
local SlotUnlocks = require(script.Parent.TempleSlotUnlocks)
local brainrotModels = game.ServerStorage:WaitForChild("BrainrotModels")
local Mutations = require(script.Parent:WaitForChild("Mutations"))
local plots = workspace:WaitForChild("Plots")

local PROMPT_PLACE_RANGE = 12 -- studs from the platform when placing via the ProximityPrompt
local DISPLAY_HEIGHT = 6 -- studs; every placed character is scaled to this height
local FLOAT_HEIGHT = 0.65 -- default FloatingCharacters hover height
local NOT_ENOUGH_MONEY = "Not enough money"
local NOT_ENOUGH_MONEY_SECONDS = 1.5 -- how long the prompt shows the failure before SlotUnlocks restores it

local function setupPlot(plot)
    SlotUnlocks.Setup(plot)
    for _, slot in plot.Slots:GetChildren() do
        local platform = slot.Platform
        local prompt = platform.PlacePrompt

        -- chosenTool: set by CharacterInventory (a specific backpack/held character); nil when the prompt
        -- fires, in which case the currently held Tool is used and the player must stand near the platform.
        local function placeCharacter(player, chosenTool)
            if plot:GetAttribute("OwnerUserId") ~= player.UserId or slot:GetAttribute("Occupied") then
                return
            end
            if chosenTool and not slot:GetAttribute("Unlocked") then
                return
            end -- CharacterInventory: never buys a slot
            if not slot:GetAttribute("Unlocked") then
                local bought, reason = SlotUnlocks.Purchase(plot, slot, player)
                if not bought and reason == NOT_ENOUGH_MONEY then
                    local _previousActionText = prompt.ActionText
                    prompt.ActionText = NOT_ENOUGH_MONEY
                    task.delay(NOT_ENOUGH_MONEY_SECONDS, function()
                        if prompt.Parent then
                            SlotUnlocks.Refresh(plot)
                        end
                    end)
                end
                return
            end

            -- Validate the tool: an inventory-chosen tool must be a Tool the player actually carries.
            local character = player.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
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
            if
                not rootPart
                or (not chosenTool and (rootPart.Position - platform.Position).Magnitude > PROMPT_PLACE_RANGE)
                or not tool
            then
                return
            end
            local characterId = tool:GetAttribute("BrainrotId")
            local template = characterId and brainrotModels:FindFirstChild(characterId)
            if tool:GetAttribute("GoldVariant") then
                template = game.ServerStorage.FutureUpdateContent.Characters:FindFirstChild("Golden Pirate")
            end
            if not template or not template:IsA("Model") then
                return
            end
            local stats = Economy.Read(tool, characterId) or Economy.Roll(characterId)
            local incomePerSecond = stats.IncomePerSecond
            -- reject NaN / infinite / negative income
            if
                type(incomePerSecond) ~= "number"
                or incomePerSecond < 0
                or incomePerSecond ~= incomePerSecond
                or incomePerSecond == math.huge
            then
                return
            end

            -- Claim the slot before anything else can run.
            local placementToken = game:GetService("HttpService"):GenerateGUID(false)
            slot:SetAttribute("PlacementToken", placementToken)
            slot:SetAttribute("Occupied", true)

            -- Build the display model (still unparented).
            local mutation = tool:GetAttribute("Mutation")
            local display = (mutation and Mutations.Model(characterId, mutation, template)) or template:Clone()
            if mutation then
                display:SetAttribute("Mutation", mutation)
            end
            display.Name = slot.Name .. "_Brainrot"
            for _, part in display:GetDescendants() do
                if part:IsA("BasePart") then
                    part.Anchored = true
                    part.CanCollide = false
                    part.CanTouch = false
                end
            end
            local _, unscaledSize = display:GetBoundingBox()
            display:ScaleTo(display:GetScale() * DISPLAY_HEIGHT / math.max(unscaledSize.Y, 0.01))
            -- Finish placement before replicating the display to clients.
            local stand = slot:FindFirstChild("MoneyStand")
            -- The saved stand has the same surface even if the live stand is still spawning.
            local standTemplates = game.ServerStorage:FindFirstChild("MoneyStandPlotTemplates")
            local plotTemplates = standTemplates and standTemplates:FindFirstChild(plot.Name)
            local geometry = stand or (plotTemplates and plotTemplates:FindFirstChild(slot.Name))
            local support = geometry and geometry:FindFirstChild("CharacterSlot")
            assert(support, "Missing podium surface: " .. plot.Name .. "." .. slot.Name)
            local boundingBox, displaySize = display:GetBoundingBox()
            local center = support.Position + Vector3.new(0, support.Size.Y / 2 + displaySize.Y / 2, 0)
            local facing = -geometry.Plate.CFrame.LookVector
            -- re-centre the pivot on the scaled bounds so DisplayHome is the visual centre
            display.PrimaryPart = nil
            display.WorldPivot = CFrame.new(boundingBox.Position)
            local home = CFrame.lookAt(center, center + facing)
            display:SetAttribute("DisplayHeight", DISPLAY_HEIGHT)
            display:SetAttribute("SlotSurfaceY", support.Position.Y + support.Size.Y / 2)
            display:PivotTo(home)
            display:SetAttribute("DisplayHome", home)
            display:SetAttribute("FloatHeight", FLOAT_HEIGHT)
            -- clients wait until this many parts have streamed in before animating / labelling
            local partCount = 0
            for _, part in display:GetDescendants() do
                if part:IsA("BasePart") then
                    partCount += 1
                end
            end
            display:SetAttribute("DisplayPartCount", partCount)
            Economy.Apply(display, characterId, stats)
            display:SetAttribute("ItemId", tool:GetAttribute("ItemId"))
            display:SetAttribute("AcquiredAt", tool:GetAttribute("AcquiredAt")) -- CharacterInventory
            if tool:GetAttribute("GoldVariant") then
                display:SetAttribute("GoldVariant", true)
            end -- CharacterInventory
            display:SetAttribute("CharacterId", characterId)
            display:SetAttribute("BrainrotId", characterId) -- golden model carries its own "Golden Pirate" id; keep the real one so it can be picked up
            if mutation then
                Mutations.AddAura(display, mutation)
            end
            display.Parent = plot.PlacedItems
            game.CollectionService:AddTag(display, "FloatingCharacter")
            -- labels are drawn locally by StarterPlayerScripts.CharacterInfoClient (tag FloatingCharacter)
            tool:Destroy()
            prompt.Enabled = false

            -- Income loop: ends when the display is removed (store / sell / pick up) or the plot changes owner.
            task.spawn(function()
                while display.Parent and plot:GetAttribute("OwnerUserId") == player.UserId do
                    task.wait(1)
                    if not display.Parent or plot:GetAttribute("OwnerUserId") ~= player.UserId then
                        break
                    end
                    local leaderstats = player:FindFirstChild("leaderstats")
                    local _cash = leaderstats and leaderstats:FindFirstChild("Cash")
                    local liveStand = slot:FindFirstChild("MoneyStand")
                    if liveStand and liveStand:GetAttribute("OwnerUserId") == player.UserId then
                        liveStand:SetAttribute("IncomePerSecond", incomePerSecond)
                        liveStand:SetAttribute(
                            "Stored",
                            (liveStand:GetAttribute("Stored") or 0)
                                + incomePerSecond
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
                -- only free the slot if no newer placement has claimed it meanwhile
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
        local request = platform:FindFirstChild("RequestPlaceCharacter") or Instance.new("BindableEvent")
        request.Name = "RequestPlaceCharacter"
        request.Parent = platform
        request.Event:Connect(placeCharacter)
        local invoke = platform:FindFirstChild("InvokePlaceCharacter") or Instance.new("BindableFunction") -- CharacterInventory
        invoke.Name = "InvokePlaceCharacter"
        invoke.Parent = platform
        invoke.OnInvoke = placeCharacter -- CharacterInventory
    end
end

-- Instance.new(class, parent) is deprecated but kept: it parents before Name is set (existing behaviour).
local function ensureLeaderstats(player)
    local leaderstats = player:FindFirstChild("leaderstats") or Instance.new("Folder", player)
    leaderstats.Name = "leaderstats"
    if not leaderstats:FindFirstChild("Cash") then
        local cash = Instance.new("NumberValue", leaderstats)
        cash.Name = "Cash"
    end
end

Players.PlayerAdded:Connect(ensureLeaderstats)
for _, player in Players:GetPlayers() do
    ensureLeaderstats(player)
end
for _, plot in plots:GetChildren() do
    setupPlot(plot)
end
