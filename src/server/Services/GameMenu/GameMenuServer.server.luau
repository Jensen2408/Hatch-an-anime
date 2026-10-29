--[[ ServerScriptService.GameMenu.GameMenuServer  (Script, server)
Remotes: ReplicatedStorage.GameMenu.Remotes.{ GetState (RF), Action (RF), Changed (RE) }
Connect HOOKS to your existing catalog / CharacterEconomy / inventory / plot / placement code.
Unconnected hooks return a clear "not connected" message; nothing pretends to work.

Network authority: the client only sends a section name or an action name + args table. Every action is
re-validated here (ownership, prices via UpgradePrices / TempleSlotUnlocks / GameMenu Config, cash on the server).
Upgrade actions only *request* the upgrade through the plot's BindableEvents; PlotManager / PlotChambers do the
actual ownership + distance checks and charge the cost.

Remote contract:
  GetState:InvokeServer(section) -> table      (rate-limited to one read per 5 ms per player)
    "index"  -> { catalog, discovered, owned, mutations = { { tier, odds, multiplier } } }
    "plot"   -> GameAdapter.GetPlot result
    "quests" -> QuestService.Snapshot             "shop" -> { items, tabs, serverTime }
    otherwise / errors -> { error = message }
  Action:InvokeServer(actionName, args) -> ok, message   (one at a time, >= 0.2 s apart per player)
    actionName in ACTIONS: EquipBest, UnequipAll, PlaceSelected{uids}, StoreSelected{uids}, Claim{id}, ClaimAll,
    UpgradeTemple, UpgradeIncubator (all incubators), AddIncubator, UnlockSlot, Buy{id}, ClaimCollection{at}
  Changed:FireClient(player)   "your menu data changed, re-fetch"; fired after successful actions,
                               quest changes and GameAdapter events.
Robux items from the Shop are only prompted here; see the note at the bottom about ProcessReceipt.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local gameMenuFolder = ReplicatedStorage:WaitForChild("GameMenu")
local Config = require(gameMenuFolder:WaitForChild("Config"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))

local remotes = gameMenuFolder:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = gameMenuFolder
local function ensureRemote(className, name)
    local remoteInstance = remotes:FindFirstChild(name) or Instance.new(className)
    remoteInstance.Name = name
    remoteInstance.Parent = remotes
    return remoteInstance
end
local GetState, Action, Changed =
    ensureRemote("RemoteFunction", "GetState"),
    ensureRemote("RemoteFunction", "Action"),
    ensureRemote("RemoteEvent", "Changed")

local HOOKS = require(script.Parent:WaitForChild("GameAdapter"))
HOOKS.OwnsGamePass = function(player, gamePassId)
    local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, gamePassId)
    return ok and owns
end

local busy = {} -- [player] = true while an Action runs
local requestAt = {} -- [player] = os.clock() of the last accepted Action
local readAt = {} -- [player] = os.clock() of the last accepted GetState
local function pushState(player)
    if player and player.Parent == Players then
        Changed:FireClient(player)
    end
end
task.spawn(HOOKS.Init, pushState)
QuestService.Changed.Event:Connect(pushState)

local function plotOrErr(player)
    local plot, err = HOOKS.GetPlot(player)
    return plot, err
end

GetState.OnServerInvoke = function(player, section)
    local now = os.clock()
    if now - (readAt[player] or -100) < 0.005 then
        return { error = "Please wait a moment." }
    end
    readAt[player] = now
    if section == "index" then
        local catalog, err = HOOKS.GetCatalog(player)
        if not catalog then
            return { error = err }
        end
        local discovered = HOOKS.GetDiscovered(player) or {}
        local owned = {}
        local plot = HOOKS.GetPlot(player)
        if plot and plot.items then
            for _, item in plot.items do
                owned[item.id] = (owned[item.id] or 0) + 1
            end
        end
        for eggKey, count in HOOKS.GetOwnedEggs(player) do
            owned[eggKey] = count
        end
        -- mutation tiers for the Index MUTATIONS page (odds are server-only data)
        local Mutations = require(game:GetService("ServerScriptService"):WaitForChild("Mutations"))
        local Economy = require(ReplicatedStorage:WaitForChild("CharacterEconomy"))
        local mutations = {}
        for _, tier in Mutations.Order do
            table.insert(
                mutations,
                { tier = tier, odds = Mutations.Odds[tier], multiplier = Economy.MutationMult[tier] }
            )
        end
        return { catalog = catalog, discovered = discovered, owned = owned, mutations = mutations }
    elseif section == "plot" then
        local plot, err = plotOrErr(player)
        if not plot then
            return { error = err }
        end
        return plot
    elseif section == "quests" then
        return QuestService.Snapshot(player)
    elseif section == "shop" then
        local items = {}
        for _, entry in Config.Shop do
            local available = (entry.kind == "cash" and entry.price ~= nil)
                or (entry.kind == "robux" and (entry.productId or entry.gamePassId) ~= nil)
            local item = table.clone(entry)
            item.available = available
            if entry.grant and entry.grant.egg then
                item.model = "MenuEgg_" .. entry.grant.egg
            end
            if entry.gamePassId then
                item.owned = HOOKS.OwnsGamePass(player, entry.gamePassId)
            end
            table.insert(items, item)
        end
        return { items = items, tabs = Config.ShopTabs, serverTime = os.time() }
    end
    return { error = "Unknown section" }
end

-- ACTIONS[name](player, args) -> ok, message. Called inside pcall by Action.OnServerInvoke.
local ACTIONS = {}
ACTIONS.EquipBest = function(player)
    return HOOKS.EquipBest(player)
end
ACTIONS.UnequipAll = function(player)
    local plot, err = plotOrErr(player)
    if not plot then
        return false, err
    end
    local uids = {}
    for _, item in plot.items do
        if item.state == "placed" then
            table.insert(uids, item.uid)
        end
    end
    if #uids == 0 then
        return false, "Nothing is placed"
    end
    local count, message = HOOKS.StoreCharacters(player, uids)
    if count == nil then
        return false, message
    end
    return true, ("%d back in inventory"):format(count)
end
-- First 60 entries of args.uids, keeping only strings.
local function collectUids(args)
    local uids = {}
    if type(args.uids) == "table" then
        for i, uid in args.uids do
            if i > 60 then
                break
            end
            if type(uid) == "string" then
                table.insert(uids, uid)
            end
        end
    end
    return uids
end
ACTIONS.PlaceSelected = function(player, args)
    local plot, err = plotOrErr(player)
    if not plot then
        return false, err
    end
    if not plot.plotOwned then
        return false, "You don't have a plot yet"
    end
    local used = 0
    for _, item in plot.items do
        if item.state == "placed" then
            used += 1
        end
    end
    if used >= plot.unlocked then
        return false, "No free stands"
    end
    local count, message = HOOKS.PlaceCharacters(player, collectUids(args))
    if count == nil then
        return false, message
    end
    return true, "Placed " .. count
end
ACTIONS.StoreSelected = function(player, args)
    local count, message = HOOKS.StoreCharacters(player, collectUids(args))
    if count == nil then
        return false, message
    end
    return true, "Stored " .. count
end
ACTIONS.Claim = function(player, args)
    return QuestService.Claim(player, tostring(args.id), function(grantPlayer, reward)
        return HOOKS.GrantReward(grantPlayer, reward) == true
    end)
end
ACTIONS.ClaimAll = function(player)
    local claimedCount = 0
    for _, quest in QuestService.Snapshot(player).list do
        if quest.progress >= quest.target and not quest.claimed then
            if
                QuestService.Claim(player, quest.id, function(grantPlayer, reward)
                    return HOOKS.GrantReward(grantPlayer, reward) == true
                end)
            then
                claimedCount += 1
            end
        end
    end
    return claimedCount > 0, claimedCount > 0 and ("Claimed %d rewards"):format(claimedCount) or "Nothing to claim"
end
ACTIONS.ClaimCollection = function(player, args)
    return HOOKS.ClaimCollection(player, tonumber(args.at))
end
-- The upgrade actions below fire the plot's request BindableEvent, wait 0.4 s and then report whether the
-- upgrade visibly started. CanAfford here is only a pre-check for a nicer message; the plot scripts charge.
ACTIONS.UpgradeTemple = function(player)
    local plot
    for _, candidate in workspace.Plots:GetChildren() do
        if candidate:GetAttribute("OwnerUserId") == player.UserId then
            plot = candidate
        end
    end
    if not plot then
        return false, "You don't have a plot yet"
    end
    local TempleSlotUnlocks = require(game.ServerScriptService.TempleSlotUnlocks)
    if not TempleSlotUnlocks.CanUpgrade(plot) then
        return false, "Buy all " .. TempleSlotUnlocks.Capacity(plot) .. " current slots before upgrading your temple"
    end
    local before = plot:GetAttribute("TempleLevel") or 1
    if before >= 3 then
        return false, "Temple is fully upgraded"
    end
    if plot:GetAttribute("TempleBuilding") then
        return false, "Upgrade already in progress"
    end
    do
        local UpgradePrices = require(game.ReplicatedStorage.UpgradePrices)
        if not UpgradePrices.CanAfford(player, UpgradePrices.Temple[before + 1]) then
            return false, "Not enough money"
        end
    end
    local requestEvent = plot:FindFirstChild("RequestUpgrade")
    if not requestEvent then
        return false, "Upgrade unavailable"
    end
    requestEvent:Fire(player) -- PlotManager checks ownership + distance
    task.wait(0.4)
    if plot:GetAttribute("TempleBuilding") or (plot:GetAttribute("TempleLevel") or 1) > before then
        return true, "Upgrading temple!"
    end
    return false, "Go to your plot to upgrade"
end
ACTIONS.UpgradeIncubator = function(player, _args)
    local plot
    for _, candidate in workspace.Plots:GetChildren() do
        if candidate:GetAttribute("OwnerUserId") == player.UserId then
            plot = candidate
        end
    end
    if not plot then
        return false, "You don't have a plot yet"
    end
    -- one upgrade raises every incubator (busy ones too); args.index is ignored
    local chamber = plot.Chambers:FindFirstChild("Chamber1")
    if not chamber then
        return false, "No incubator there"
    end
    local level = plot:GetAttribute("IncubatorLevel") or 1
    if level >= 3 then
        return false, "Incubators are max level"
    end
    if plot:GetAttribute("ChamberBuilding") then
        return false, "Wait for the incubator build to finish"
    end
    do
        local UpgradePrices = require(game.ReplicatedStorage.UpgradePrices)
        if not UpgradePrices.CanAfford(player, UpgradePrices.IncubatorLevel[level + 1]) then
            return false, "Not enough money"
        end
    end
    local requestEvent = chamber:FindFirstChild("RequestIncubatorUpgrade")
    if not requestEvent then
        return false, "Upgrade unavailable"
    end
    requestEvent:Fire(player) -- PlotChambers checks ownership + distance
    task.wait(0.4)
    if (plot:GetAttribute("IncubatorLevel") or 1) > level then
        return true, "All incubators upgraded to level " .. (level + 1) .. "!"
    end
    return false, "Go to your plot to upgrade"
end
ACTIONS.AddIncubator = function(player)
    local plot
    for _, candidate in workspace.Plots:GetChildren() do
        if candidate:GetAttribute("OwnerUserId") == player.UserId then
            plot = candidate
        end
    end
    if not plot then
        return false, "You don't have a plot yet"
    end
    local before = #plot.Chambers:GetChildren()
    if before >= 3 then
        return false, "You have all 3 incubators"
    end
    do
        local UpgradePrices = require(game.ReplicatedStorage.UpgradePrices)
        if not UpgradePrices.CanAfford(player, UpgradePrices.AddIncubator[before + 1]) then
            return false, "Not enough money"
        end
    end
    local requestEvent = plot:FindFirstChild("RequestChamberUpgrade")
    if not requestEvent then
        return false, "Unavailable"
    end
    requestEvent:Fire(player)
    task.wait(0.4)
    if plot:GetAttribute("ChamberCount") ~= before or #plot.Chambers:GetChildren() > before then
        return true, "Building a new incubator!"
    end
    return false, "Go to your plot to add one"
end
-- Unlike the upgrades, slot unlocks are charged right here (TempleSlotUnlocks.Prices, fallback 250000).
ACTIONS.UnlockSlot = function(player)
    local plot
    for _, candidate in workspace.Plots:GetChildren() do
        if candidate:GetAttribute("OwnerUserId") == player.UserId then
            plot = candidate
        end
    end
    if not plot then
        return false, "You don't have a plot yet"
    end
    local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart or (rootPart.Position - plot.TempleAnchor.Position).Magnitude > 80 then
        return false, "Go to your plot to unlock"
    end
    local TempleSlotUnlocks = require(game.ServerScriptService.TempleSlotUnlocks)
    -- next locked slot in order
    local nextSlot, slotIndex
    for slotNumber = 1, TempleSlotUnlocks.Capacity(plot) do
        local slot = plot.Slots:FindFirstChild(string.format("Slot%02d", slotNumber))
        if slot and not slot:GetAttribute("Unlocked") then
            nextSlot, slotIndex = slot, slotNumber
            break
        end
    end
    if not nextSlot then
        return false, "All slots unlocked!"
    end
    local cash = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Cash")
    local price = TempleSlotUnlocks.Prices[slotIndex] or 250000
    if not cash or cash.Value < price then
        return false, "Not enough cash"
    end
    cash.Value -= price
    nextSlot:SetAttribute("Unlocked", true)
    TempleSlotUnlocks.Refresh(plot)
    return true, "Slot " .. slotIndex .. " unlocked!"
end
ACTIONS.Buy = function(player, args)
    local entry
    for _, candidate in Config.Shop do
        if candidate.id == args.id then
            entry = candidate
        end
    end
    if not entry then
        return false, "Unknown item"
    end
    if entry.endsAt and os.time() > entry.endsAt then
        return false, "This item has ended"
    end
    if entry.kind == "cash" then
        return HOOKS.BuyCash(player, entry)
        --[[ Legacy spend-then-grant path replaced with atomic prepared delivery.
		local ok, why = HOOKS.SpendCash(p, e.price); if not ok then return false, why or "Not enough cash" end
		local g, gwhy = HOOKS.GrantShopItem(p, e)
		if not g then warn("[GameMenu] grant failed after spend; refund in your SpendCash/Grant code:", gwhy); return false, gwhy end
		return true, "Bought " .. e.name ]]
    elseif entry.productId then
        MarketplaceService:PromptProductPurchase(player, entry.productId)
        return true, "Opening purchase"
    elseif entry.gamePassId then
        MarketplaceService:PromptGamePassPurchase(player, entry.gamePassId)
        return true, "Opening purchase"
    end
    return false, "Coming soon"
end

Action.OnServerInvoke = function(player, name, args)
    if type(name) ~= "string" or not ACTIONS[name] then
        return false, "Unknown action"
    end
    if busy[player] or os.clock() - (requestAt[player] or -100) < 0.2 then
        return false, "Please wait a moment."
    end
    requestAt[player] = os.clock()
    busy[player] = true
    local ok, result, message = pcall(ACTIONS[name], player, type(args) == "table" and args or {})
    busy[player] = nil
    if not ok then
        warn("[GameMenu]", name, result)
        return false, "Server error"
    end
    if result then
        pushState(player)
    end
    return result, message
end
Players.PlayerRemoving:Connect(function(player)
    busy[player] = nil
    requestAt[player] = nil
    readAt[player] = nil
end)

--[[ Robux receipts: Roblox allows ONE ProcessReceipt per game. If you already have one, add a branch there that calls
     HOOKS.GrantShopItem(player, entry) for entries whose productId matches, and return PurchaseGranted only after it succeeds. ]]
