--[[ ServerScriptService.GameMenu.GameAdapter  (ModuleScript, server)
Game Menu adapters: use existing server inventory/economy, never client stats.
GameMenuServer calls these; this module owns no remotes itself.

Network authority: every value returned here is read from server state (InventoryService, leaderstats,
Backpack tools, plot attributes). Spend / grant functions validate amounts on the server.

Public API (all take the Player first unless noted):
  GetCatalog() -> { eggs = {...}, characters = {...} }      static catalog for the menu
  GetPlot(player) -> { availableSlots, canUpgrade, plotOwned, level, unlocked, items }
  GetOwnedEggs(player) -> { ["egg:<id>"] = count }
  GetDiscovered / ExportDiscovered / ImportDiscovered        "char:<id>" / "egg:<id>" / "hatch:<id>" keys
  PlaceCharacters / StoreCharacters(player, uids) -> count? , message   (max 60 uids, 0.27 s between requests)
  EquipBest(player) -> ok, message
  GetCash(player) -> number;  SpendCash(player, price) -> true | nil, message;  GrantReward(player, {cash}) -> true | nil, message
  BuyCash(player, shopEntry) -> ok, message   (pays with Cash, delivers an egg Tool, refunds on delivery failure)
  GrantShopItem(player, shopEntry) -> true | nil, message
  Init(pushState)   hooks backpack / hatch / plot events; calls pushState(player) when menu data changed and
                    increments QuestService counters (HatchEgg, DiscoverCharacter, Upgrade, PlaceCharacter).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local CharacterCatalog = require(ReplicatedStorage.CharacterCatalog)
local InventoryService = require(ServerScriptService.CharacterInventory.InventoryService)
local _EggCharacterRewards = require(ServerScriptService.EggCharacterRewards) -- required for load order only
local QuestService = require(script.Parent.QuestService)

local GameAdapter = {}

-- discoveries[player] = { [discoveryKey] = true }  (persisted by GameMenuServer via Export/ImportDiscovered)
local discoveries = {}

local function getOwnedPlot(player)
    for _, plot in workspace.Plots:GetChildren() do
        if plot:GetAttribute("OwnerUserId") == player.UserId then
            return plot
        end
    end
end

-- Returns true only the first time a key is discovered.
local function markDiscovered(player, key)
    discoveries[player] = discoveries[player] or {}
    if not discoveries[player][key] then
        discoveries[player][key] = true
        return true
    end
    return false
end

function GameAdapter.GetCatalog()
    local catalog = { eggs = {}, characters = {} }
    for _, entry in CharacterCatalog.Order do
        table.insert(catalog.characters, {
            id = "char:" .. entry.Id,
            name = entry.Name,
            rarity = entry.Rarity,
            image = entry.image,
            description = "Each hatch rolls individual Power and earnings.",
            obtain = "Hatch a " .. entry.Id .. " egg in your incubator.",
        })
        local model = ServerStorage.AuxEggTemplates:FindFirstChild(entry.Id)
        if model and model:GetAttribute("ReleaseEnabled") ~= false then
            table.insert(catalog.eggs, {
                id = "egg:" .. entry.Id,
                name = entry.Id .. " Egg",
                rarity = entry.Rarity,
                model = "MenuEgg_" .. entry.Id,
                description = "Price: " .. CharacterCatalog.FormatPrice(entry.Price),
                obtain = "Collect from the river and return to your plot.",
            })
        end
    end
    return catalog
end

function GameAdapter.GetPlot(player)
    local snapshot = InventoryService.Snapshot(player)
    local plot = getOwnedPlot(player)
    local items = {}
    for _, item in snapshot.items do
        local entry = CharacterCatalog.ById[item.characterId]
        table.insert(items, {
            uid = item.id,
            id = "char:" .. item.characterId,
            name = item.name,
            rarity = item.rarity,
            power = item.power,
            income = item.income * snapshot.multiplier,
            state = ({ Placed = "placed", Held = "held", Backpack = "stored" })[item.state],
            slot = item.slot, -- slot number while placed (Plot menu grid)
            acquired = item.acquired,
            image = entry.image,
        })
    end
    local TempleSlotUnlocks = require(ServerScriptService.TempleSlotUnlocks)
    return {
        availableSlots = plot and TempleSlotUnlocks.Capacity(plot) or 0,
        canUpgrade = plot and TempleSlotUnlocks.CanUpgrade(plot) or false,
        plotOwned = plot ~= nil,
        level = plot and plot:GetAttribute("TempleLevel") or 0,
        unlocked = snapshot.capacity.unlocked,
        items = items,
    }
end

function GameAdapter.GetOwnedEggs(player)
    local ownedEggs = {}
    for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
        if container then
            for _, tool in container:GetChildren() do
                local eggId = tool:GetAttribute("EggType")
                if tool:IsA("Tool") and eggId and CharacterCatalog.ById[eggId] then
                    local key = "egg:" .. eggId
                    ownedEggs[key] = (ownedEggs[key] or 0) + 1
                end
            end
        end
    end
    return ownedEggs
end

function GameAdapter.ExportDiscovered(player)
    local keys = {}
    for key in discoveries[player] or {} do
        table.insert(keys, key)
    end
    return keys
end

function GameAdapter.ImportDiscovered(player, list)
    discoveries[player] = discoveries[player] or {}
    for _, key in list do
        if type(key) == "string" then
            discoveries[player][key] = true
        end
    end
end

function GameAdapter.GetDiscovered(player)
    discoveries[player] = discoveries[player] or {}
    for _, item in InventoryService.Snapshot(player).items do
        markDiscovered(player, "char:" .. item.characterId)
    end
    for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
        if container then
            for _, tool in container:GetChildren() do
                local eggId = tool:GetAttribute("EggType")
                if tool:IsA("Tool") and eggId and CharacterCatalog.ById[eggId] then
                    markDiscovered(player, "egg:" .. eggId)
                end
            end
        end
    end
    return table.clone(discoveries[player])
end

-- Validates the whole uid list first, then runs InventoryService.MenuRequest per uid.
-- Stops at the first failure and returns the number already done (or nil if none) + the error message.
local function runBatchRequest(player, uids, action)
    if type(uids) ~= "table" or #uids > 60 then
        return nil, "Invalid selection."
    end
    local completed, seen = 0, {}
    for _, uid in ipairs(uids) do
        if type(uid) ~= "string" or seen[uid] then
            return nil, "Invalid selection."
        end
        seen[uid] = true
    end
    for _, uid in ipairs(uids) do
        local result = InventoryService.MenuRequest(player, action, { id = uid })
        if not result.ok then
            return completed > 0 and completed or nil, result.message or result.code
        end
        completed += 1
        if #uids > 1 then
            task.wait(0.27)
        end
    end
    return completed
end

function GameAdapter.PlaceCharacters(player, uids)
    return runBatchRequest(player, uids, "Place")
end

function GameAdapter.StoreCharacters(player, uids)
    return runBatchRequest(player, uids, "Store")
end

function GameAdapter.EquipBest(player)
    local result = InventoryService.MenuRequest(player, "PlaceBest", {})
    return result.ok, result.message or (result.ok and "Best earners placed." or result.code)
end

function GameAdapter.GetCash(player)
    local leaderstats = player:FindFirstChild("leaderstats")
    local cash = leaderstats and leaderstats:FindFirstChild("Cash")
    return cash and cash.Value or 0
end

-- price must be a non-negative integer (NaN rejected via `price ~= price`).
function GameAdapter.SpendCash(player, price)
    local leaderstats = player:FindFirstChild("leaderstats")
    local cash = leaderstats and leaderstats:FindFirstChild("Cash")
    if not cash or type(price) ~= "number" or price ~= price or price < 0 or price % 1 ~= 0 then
        return nil, "Invalid price."
    end
    if cash.Value < price then
        return nil, "Not enough cash."
    end
    cash.Value -= price
    return true
end

-- reward.cash must be a non-negative number; it is floored before being added.
function GameAdapter.GrantReward(player, reward)
    local leaderstats = player:FindFirstChild("leaderstats")
    local cash = leaderstats and leaderstats:FindFirstChild("Cash")
    local amount = reward and reward.cash
    if not cash or type(amount) ~= "number" or amount < 0 or amount ~= amount then
        return nil, "Cash is unavailable."
    end
    cash.Value += math.floor(amount)
    return true
end

-- Builds (but does not parent) an egg Tool for eggId. Returns tool, backpack or nil, message.
local function createEgg(player, eggId)
    local entry = CharacterCatalog.ById[eggId]
    local template = entry and ServerStorage.AuxEggTemplates:FindFirstChild(eggId)
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack or not template or template:GetAttribute("ReleaseEnabled") == false then
        return nil, "Egg is unavailable."
    end
    local tool = Instance.new("Tool")
    tool.Name = eggId .. " Egg"
    tool.CanBeDropped = false
    CharacterCatalog.Stamp(tool, entry)
    tool:SetAttribute("EggType", eggId)
    tool:SetAttribute("EggId", HttpService:GenerateGUID(false))
    tool:SetAttribute("ShopPurchased", true)
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
    for _, part in visual:GetDescendants() do
        if part:IsA("BasePart") then
            part.Anchored = false
            part.CanCollide = false
            part.CanTouch = false
            part.Massless = true
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = handle
            weld.Part1 = part
            weld.Parent = handle
        elseif part:IsA("BaseScript") then
            part:Destroy()
        end
    end
    return tool, backpack
end

function GameAdapter.BuyCash(player, shop)
    local eggId = shop.grant and shop.grant.egg
    local tool, backpackOrMessage = createEgg(player, eggId)
    if not tool then
        return false, backpackOrMessage
    end
    local ok, reason = GameAdapter.SpendCash(player, shop.price)
    if not ok then
        tool:Destroy()
        return false, reason
    end
    -- No yield between payment and delivery; refund if delivery unexpectedly fails.
    local delivered, _err = pcall(function()
        tool.Parent = backpackOrMessage
    end)
    if not delivered then
        GameAdapter.GrantReward(player, { cash = shop.price })
        tool:Destroy()
        return false, "Purchase refunded."
    end
    return true, "Bought " .. shop.name
end

function GameAdapter.GrantShopItem(player, shopEntry)
    local tool, backpackOrMessage = createEgg(player, shopEntry.grant and shopEntry.grant.egg)
    if not tool then
        return nil, backpackOrMessage
    end
    tool.Parent = backpackOrMessage
    return true
end

function GameAdapter.Init(pushState)
    local watchedHatchEvents = setmetatable({}, { __mode = "k" })
    local function watchPlayer(player)
        discoveries[player] = {}
        -- New tools in the Backpack / Character mark discoveries and refresh the menu.
        local function watchContainer(container)
            if not container then
                return
            end
            container.ChildAdded:Connect(function(tool)
                if not tool:IsA("Tool") then
                    return
                end
                task.defer(function()
                    local characterId = tool:GetAttribute("CharacterId")
                    local eggId = tool:GetAttribute("EggType")
                    if characterId and CharacterCatalog.ById[characterId] then
                        markDiscovered(player, "char:" .. characterId)
                    end
                    if eggId and CharacterCatalog.ById[eggId] then
                        markDiscovered(player, "egg:" .. eggId)
                    end
                    pushState(player)
                end)
            end)
        end
        watchContainer(player:FindFirstChildOfClass("Backpack"))
        watchContainer(player.Character)
        player.CharacterAdded:Connect(watchContainer)
        player.ChildAdded:Connect(function(child)
            if child:IsA("Backpack") then
                watchContainer(child)
            end
        end)
    end
    for _, player in Players:GetPlayers() do
        watchPlayer(player)
    end
    Players.PlayerAdded:Connect(watchPlayer)
    Players.PlayerRemoving:Connect(function(player)
        discoveries[player] = nil
    end)
    -- Each incubator fires a BindableEvent "HatchCycleCompleted(player, tool, characterId)" inside its plot.
    local function hookHatch(event)
        if event.Name ~= "HatchCycleCompleted" or not event:IsA("BindableEvent") or watchedHatchEvents[event] then
            return
        end
        watchedHatchEvents[event] = true
        event.Event:Connect(function(player, _tool, characterId)
            local plot = getOwnedPlot(player)
            if not plot or not event:IsDescendantOf(plot) then
                return
            end
            QuestService.Increment(player, "HatchEgg", 1)
            if characterId and CharacterCatalog.ById[characterId] then
                local marker = "hatch:" .. characterId
                if markDiscovered(player, marker) then
                    QuestService.Increment(player, "DiscoverCharacter", 1)
                end
                markDiscovered(player, "char:" .. characterId)
            end
            pushState(player)
        end)
    end
    for _, descendant in workspace.Plots:GetDescendants() do
        hookHatch(descendant)
    end
    workspace.Plots.DescendantAdded:Connect(hookHatch)
    local function getPlotOwner(plot)
        return Players:GetPlayerByUserId(plot:GetAttribute("OwnerUserId") or 0)
    end
    local function watchPlot(plot)
        local placedItems = plot:WaitForChild("PlacedItems", 30)
        local slots = plot:WaitForChild("Slots", 30)
        local chambers = plot:WaitForChild("Chambers", 30)
        if not placedItems or not slots or not chambers then
            warn("[GameMenu] plot folders not ready: " .. plot.Name)
            return
        end
        -- Upgrade quest counts only level increases (decreases / resets do not count).
        local previousLevel = plot:GetAttribute("TempleLevel") or 1
        plot:GetAttributeChangedSignal("TempleLevel"):Connect(function()
            local newLevel = plot:GetAttribute("TempleLevel") or 1
            local owner = getPlotOwner(plot)
            if owner and newLevel > previousLevel then
                QuestService.Increment(owner, "Upgrade", 1)
            end
            previousLevel = newLevel
            if owner then
                pushState(owner)
            end
        end)
        placedItems.ChildAdded:Connect(function(model)
            task.defer(function()
                local owner = getPlotOwner(plot)
                if owner and model.Parent and model:GetAttribute("CharacterId") then
                    QuestService.Increment(owner, "PlaceCharacter", 1)
                    pushState(owner)
                end
            end)
        end)
        for _, slot in slots:GetChildren() do
            slot:GetAttributeChangedSignal("Unlocked"):Connect(function()
                local owner = getPlotOwner(plot)
                if owner then
                    pushState(owner)
                end
            end)
        end
        local function watchChamber(chamber)
            local level = chamber:GetAttribute("UpgradeLevel") or 1
            chamber:GetAttributeChangedSignal("UpgradeLevel"):Connect(function()
                local newLevel = chamber:GetAttribute("UpgradeLevel") or 1
                local owner = getPlotOwner(plot)
                if owner and newLevel > level then
                    QuestService.Increment(owner, "Upgrade", 1)
                end
                level = newLevel
                if owner then
                    pushState(owner)
                end
            end)
        end
        for _, chamber in chambers:GetChildren() do
            watchChamber(chamber)
        end
        chambers.ChildAdded:Connect(watchChamber)
    end
    for _, plot in workspace.Plots:GetChildren() do
        task.spawn(watchPlot, plot)
    end
    workspace.Plots.ChildAdded:Connect(function(plot)
        task.spawn(watchPlot, plot)
    end)
end

return GameAdapter
