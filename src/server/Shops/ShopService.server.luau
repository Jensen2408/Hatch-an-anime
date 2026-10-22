--[[ ServerScriptService.ShopService
Shop + Daily Rewards (server-authoritative).
  • Player attributes it maintains: CashMultiplier, HatchMultiplier, VIP, Money2xUntil, Hatch2xUntil, MoneyLevel,
    HatchLevel (HatchMultiplier = ShopConfig.HatchLevels mult × 2 while Hatch2x is active)
    (BrainrotPlacement multiplies stand income by CashMultiplier; HatchGoo multiplies hatch speed by HatchMultiplier.)
  • RemoteFunction ReplicatedStorage.ShopSystem.ShopRemote: "State" | "ClaimDaily" | "BuyMoneyLevel" | "BuyHatchLevel"
    | "Buy"(key)
  • The game's only ProcessReceipt lives here.
  • Saves (DataStore ShopData_v2; v1 = pre-launch, only money level + receipts carried over): money level, hatch level,
    daily streak, boost end times. Fails safely in Studio.

Network authority: the client only *asks*. Every remote call is validated here (loaded data, load failure lock,
one call at a time per player via `busy`). Purchases are only *prompted* from the remote; rewards are granted
exclusively in ProcessReceipt (developer products) and PromptGamePassPurchaseFinished / UserOwnsGamePassAsync
(game passes). The client never sends amounts.

Remote contract (ShopRemote:InvokeServer(action, key) -> ok: boolean, payloadOrMessage):
  "State"          -> true, { daily = {day, ready, nextIn, streak}, moneyLevel, hatchLevel, money2xUntil,
                              hatch2xUntil, vip, starter, serverTime }
  "ClaimDaily"     -> true, "Claimed day N!"  |  false, "Come back later"
  "BuyMoneyLevel"  -> true (product prompt shown) | false, "Maxed out!" / "Coming soon"
  "BuyHatchLevel"  -> true, "Hatch speed Nx!" (cash charged here) | false, "Maxed out!" / "Not enough cash"
  "Buy", key       -> key from ShopConfig.GamePasses or ShopConfig.Products; true | false, message
  any failure      -> false, "Loading…" / "Shop couldn't load. Please rejoin." / "One moment…" / "Server error" / "Unknown"

Receipt flow (ProcessReceipt): NotProcessedYet until the player's shop data AND main save (TutorialDataReady) are
loaded; receipts are de-duplicated by PurchaseId (last 50 kept) and only reported PurchaseGranted after the shop
save succeeds. Cash packs / Unknown Egg also trigger ServerStorage.PlayerDataSaveNow so the main save has them.

Studio only: BindableFunction script.StudioGiveUnknownEgg(player) gives an Unknown Egg for testing.
]]
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.ShopSystem.ShopConfig)

local shopRemote = ReplicatedStorage.ShopSystem:FindFirstChild("ShopRemote") or Instance.new("RemoteFunction")
shopRemote.Name = "ShopRemote"
shopRemote.Parent = ReplicatedStorage.ShopSystem
local shopStore
do
    local ok, dataStore = pcall(DataStoreService.GetDataStore, DataStoreService, "ShopData_v2")
    shopStore = ok and dataStore or nil
end
local legacyShopStore
do
    local ok, dataStore = pcall(DataStoreService.GetDataStore, DataStoreService, "ShopData_v1")
    legacyShopStore = ok and dataStore or nil
end -- launch reset: only paid things carry over

-- shopData[player] = { moneyLevel, hatchLevel, streak, dailyAt, money2xUntil, hatch2xUntil, starterGranted, receipts,
--                      receiptOrder, __loadFailed (never saved) }
-- busy[player] = true while a remote call runs; ownedPasses[player][passKey] = cached game-pass ownership
local shopData, busy, ownedPasses = {}, {}, {}
local DAY_SECONDS = 86400

local function getCashStat(player)
    local leaderstats = player:FindFirstChild("leaderstats")
    return leaderstats and leaderstats:FindFirstChild("Cash")
end
local function now()
    return os.time()
end

-- Writes the player's shop data (up to 3 attempts). Never saves data whose load failed (would wipe the real save).
local function savePlayer(player)
    local playerData = shopData[player]
    if not playerData or not shopStore or playerData.__loadFailed then
        return false
    end
    local copy = table.clone(playerData)
    copy.__loadFailed = nil
    for attempt = 1, 3 do
        local ok, err = pcall(shopStore.UpdateAsync, shopStore, "u" .. player.UserId, function()
            return copy
        end)
        if ok then
            return true
        end
        warn("[Shop] save failed", player.Name, err)
        task.wait(attempt)
    end
    return false
end

-- Game passes with id 0 (not yet created) can only be owned through a grant this session (ownedPasses cache).
local function ownsPass(player, passKey)
    local passId = Config.GamePasses[passKey]
    if not passId or passId == 0 then
        return ownedPasses[player] and ownedPasses[player][passKey] == true
    end
    ownedPasses[player] = ownedPasses[player] or {}
    if ownedPasses[player][passKey] == nil then
        local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
        ownedPasses[player][passKey] = ok and owns or false
    end
    return ownedPasses[player][passKey]
end

-- recompute multipliers from level + active boosts + VIP
local function refreshMultipliers(player)
    local playerData = shopData[player]
    if not playerData then
        return
    end
    local levelInfo = Config.MoneyLevels[playerData.moneyLevel or 0]
    local isVip = ownsPass(player, "VIP")
    local currentTime = now()
    local cash = (levelInfo and levelInfo.mult or 1)
        * ((playerData.money2xUntil or 0) > currentTime and 2 or 1)
        * (isVip and Config.VIPCashBonus or 1)
    player:SetAttribute("CashMultiplier", cash)
    local hatchLevelInfo = Config.HatchLevels[playerData.hatchLevel or 0]
    player:SetAttribute(
        "HatchMultiplier",
        (hatchLevelInfo and hatchLevelInfo.mult or 1) * ((playerData.hatch2xUntil or 0) > currentTime and 2 or 1)
    )
    player:SetAttribute("MoneyLevel", playerData.moneyLevel or 0)
    player:SetAttribute("HatchLevel", playerData.hatchLevel or 0)
    player:SetAttribute("Money2xUntil", playerData.money2xUntil or 0)
    player:SetAttribute("Hatch2xUntil", playerData.hatch2xUntil or 0)
    player:SetAttribute("VIP", isVip)
end

-- Extends (or starts) a timed boost. boostName: "Money2x" | anything else = Hatch2x.
local function addBoost(player, boostName, minutes)
    local playerData = shopData[player]
    if not playerData then
        return
    end
    local key = boostName == "Money2x" and "money2xUntil" or "hatch2xUntil"
    playerData[key] = math.max(playerData[key] or 0, now()) + minutes * 60
    refreshMultipliers(player)
end
local function addCash(player, amount)
    local cashStat = getCashStat(player)
    if cashStat then
        cashStat.Value += amount
        return true
    end
end

---------------------------------------------------------------- VIP perks: crown over head
local CROWN_IMAGE = "rbxassetid://95157813840098"
local function updateVipCrown(player)
    local character = player.Character
    local head = character and character:FindFirstChild("Head")
    if not head then
        return
    end
    local oldCrown = head:FindFirstChild("VIPCrown")
    if oldCrown then
        oldCrown:Destroy()
    end
    if not player:GetAttribute("VIP") then
        return
    end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "VIPCrown"
    billboard.Size = UDim2.fromScale(2.2, 2.2)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
    billboard.LightInfluence = 0
    billboard.MaxDistance = 120
    local image = Instance.new("ImageLabel")
    image.Size = UDim2.fromScale(1, 1)
    image.BackgroundTransparency = 1
    image.Image = CROWN_IMAGE
    image.Parent = billboard
    billboard.Parent = head
end

---------------------------------------------------------------- daily rewards
-- 7-day cycle. Claimable once DAY_SECONDS passed since the last claim; the streak resets after 2 days without a claim.
local function dailyState(player)
    local playerData = shopData[player]
    local currentTime = now()
    local lastClaimAt = playerData.dailyAt or 0
    local streak = playerData.streak or 0
    if lastClaimAt > 0 and currentTime - lastClaimAt > 2 * DAY_SECONDS then
        streak = 0
    end -- missed a day
    local ready = currentTime - lastClaimAt >= DAY_SECONDS
    local day = ready and (streak % 7) + 1 or ((streak - 1) % 7) + 1
    return {
        day = day,
        ready = ready,
        nextIn = ready and 0 or (lastClaimAt + DAY_SECONDS - currentTime),
        streak = streak,
    }
end

local function claimDaily(player)
    local playerData = shopData[player]
    local daily = dailyState(player)
    if not daily.ready then
        return false, "Come back later"
    end
    local reward = Config.Daily[daily.day]
    local isVip = player:GetAttribute("VIP")
    if reward.kind == "cash" then
        addCash(player, reward.amount * (isVip and 2 or 1))
    elseif reward.kind == "boost" then
        addBoost(player, reward.boost, reward.minutes)
    elseif reward.kind == "mystery" then
        addCash(player, reward.amount * (isVip and 2 or 1))
        addBoost(player, "Money2x", reward.minutes)
        addBoost(player, "Hatch2x", reward.minutes)
    end
    playerData.streak = (daily.streak % 7) + 1
    playerData.dailyAt = now()
    savePlayer(player)
    return true, "Claimed day " .. daily.day .. "!"
end

---------------------------------------------------------------- remote
shopRemote.OnServerInvoke = function(player, action, key)
    if not shopData[player] then
        return false, "Loading…"
    end
    if shopData[player].__loadFailed and action ~= "State" then
        return false, "Shop couldn't load. Please rejoin."
    end
    if busy[player] then
        return false, "One moment…"
    end
    busy[player] = true
    local ok, result, message = pcall(function()
        if action == "State" then
            local playerData = shopData[player]
            return true,
                {
                    daily = dailyState(player),
                    moneyLevel = playerData.moneyLevel or 0,
                    hatchLevel = playerData.hatchLevel or 0,
                    money2xUntil = playerData.money2xUntil or 0,
                    hatch2xUntil = playerData.hatch2xUntil or 0,
                    vip = player:GetAttribute("VIP") == true,
                    starter = ownsPass(player, "StarterPack"),
                    serverTime = now(),
                }
        elseif action == "ClaimDaily" then
            return claimDaily(player)
        elseif action == "BuyMoneyLevel" then
            local playerData = shopData[player]
            local nextLevel = Config.MoneyLevels[(playerData.moneyLevel or 0) + 1]
            if not nextLevel then
                return false, "Maxed out!"
            end
            if (nextLevel.productId or 0) == 0 then
                return false, "Coming soon"
            end
            MarketplaceService:PromptProductPurchase(player, nextLevel.productId)
            return true
        elseif action == "BuyHatchLevel" then
            local playerData = shopData[player]
            local level = (playerData.hatchLevel or 0) + 1
            local nextLevel = Config.HatchLevels[level]
            if not nextLevel then
                return false, "Maxed out!"
            end
            if not player:GetAttribute("TutorialDataReady") then
                return false, "Loading…"
            end -- main save (cash) not restored yet
            local cashStat = getCashStat(player)
            if not cashStat or cashStat.Value < nextLevel.cash then
                return false, "Not enough cash"
            end
            cashStat.Value -= nextLevel.cash
            playerData.hatchLevel = level
            refreshMultipliers(player)
            savePlayer(player)
            -- the cash was taken from the main save; write it now so the level and the cash stay in step
            local saveNow = game:GetService("ServerStorage"):FindFirstChild("PlayerDataSaveNow")
            if saveNow then
                pcall(saveNow.Invoke, saveNow, player)
            end
            return true, "Hatch speed " .. nextLevel.mult .. "×!"
        elseif action == "Buy" and type(key) == "string" then
            if Config.GamePasses[key] ~= nil then
                local passId = Config.GamePasses[key]
                if passId == 0 then
                    return false, "Coming soon"
                end
                if ownsPass(player, key) then
                    return false, "You already own this"
                end
                MarketplaceService:PromptGamePassPurchase(player, passId)
                return true
            elseif Config.Products[key] ~= nil then
                local productId = Config.Products[key]
                if productId == 0 then
                    return false, "Coming soon"
                end
                MarketplaceService:PromptProductPurchase(player, productId)
                return true
            end
        end
        return false, "Unknown"
    end)
    busy[player] = nil
    if not ok then
        warn("[Shop] " .. tostring(result))
        return false, "Server error"
    end
    return result, message
end

---------------------------------------------------------------- purchases
-- Unknown Egg: a mystery egg that always hatches a Rare or better character (rolled at purchase).
-- Note: the rolled pool is only used when the catalog has no "Unknown" entry (see `entry` below).
local UNKNOWN_ODDS = { { "Rare", 70 }, { "Epic", 25 }, { "Legendary", 5 } }
local function giveUnknownEgg(player)
    local CharacterCatalog = require(ReplicatedStorage.CharacterCatalog)
    local roll, pickedRarity = math.random() * 100, "Rare"
    for _, odds in UNKNOWN_ODDS do
        roll -= odds[2]
        if roll <= 0 then
            pickedRarity = odds[1]
            break
        end
    end
    local pool = {}
    for _id, entry in CharacterCatalog.ById do
        if entry.Rarity == pickedRarity then
            table.insert(pool, entry)
        end
    end
    if #pool == 0 then
        for _, entry in CharacterCatalog.ById do
            table.insert(pool, entry)
        end
    end
    local entry = CharacterCatalog.ById.Unknown or pool[math.random(1, #pool)]
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then
        return false
    end
    local tool = Instance.new("Tool")
    tool.Name = "Unknown Egg"
    tool.CanBeDropped = false
    CharacterCatalog.Stamp(tool, entry)
    tool:SetAttribute("EggType", entry.Id)
    tool:SetAttribute("UnknownEgg", true)
    tool.ToolTip = "LIMITED • Hatches the Unknown character"
    local template = ReplicatedStorage.ShopSystem.ShopModels:FindFirstChild("UnknownEgg")
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.one
    handle.Transparency = 1
    handle.CanCollide = false
    handle.Massless = true
    handle.Parent = tool
    if template then
        -- egg visual scaled to 2.2 studs tall and welded to the invisible handle
        local visual = template:Clone()
        visual.Name = "Egg"
        local _, size = visual:GetBoundingBox()
        visual:ScaleTo(visual:GetScale() * 2.2 / math.max(size.Y, 0.01))
        visual:PivotTo(CFrame.new())
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
            elseif descendant:IsA("BaseScript") then
                descendant:Destroy()
            end
        end
        visual.Parent = tool
    end
    tool.Parent = backpack
    return true
end
if game:GetService("RunService"):IsStudio() then
    local studioGiveEgg = Instance.new("BindableFunction")
    studioGiveEgg.Name = "StudioGiveUnknownEgg"
    studioGiveEgg.OnInvoke = giveUnknownEgg
    studioGiveEgg.Parent = script
end

-- Marks a pass as owned for this session; StarterPack contents are granted once (starterGranted is saved).
local function grantPass(player, passKey)
    ownedPasses[player] = ownedPasses[player] or {}
    ownedPasses[player][passKey] = true
    local playerData = shopData[player]
    if passKey == "StarterPack" and playerData and not playerData.starterGranted then
        playerData.starterGranted = true
        addCash(player, Config.StarterPack.cash)
        addBoost(player, "Money2x", Config.StarterPack.boostMinutes)
        addBoost(player, "Hatch2x", Config.StarterPack.boostMinutes)
        savePlayer(player)
    end
    refreshMultipliers(player)
    updateVipCrown(player)
end
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, purchasedPassId, wasPurchased)
    if not wasPurchased then
        return
    end
    for passKey, passId in Config.GamePasses do
        if passId == purchasedPassId then
            grantPass(player, passKey)
        end
    end
end)

MarketplaceService.ProcessReceipt = function(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player or not shopData[player] then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    local playerData = shopData[player]
    if playerData.__loadFailed then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    if not player:GetAttribute("TutorialDataReady") then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end -- save not restored yet: Roblox retries later
    playerData.receipts = playerData.receipts or {}
    if playerData.receipts[receiptInfo.PurchaseId] then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    -- resolve the product: a ShopConfig.Products key, or a money level (money level wins)
    local key
    for productKey, productId in Config.Products do
        if productId == receiptInfo.ProductId then
            key = productKey
        end
    end
    local level
    for levelIndex, levelInfo in Config.MoneyLevels do
        if levelInfo.productId ~= 0 and levelInfo.productId == receiptInfo.ProductId then
            level = levelIndex
        end
    end
    if level then
        key = "MoneyLevel"
    end
    if not key then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    if key == "MoneyLevel" then
        playerData.moneyLevel = math.max(playerData.moneyLevel or 0, level)
        refreshMultipliers(player)
    elseif key == "Money2x" or key == "Hatch2x" then
        addBoost(player, key, Config.BoostMinutes)
    elseif key == "UnknownEgg" then
        if not giveUnknownEgg(player) then
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
    elseif key == "Offline2x" then -- doubles this join's offline earnings (paid straight as cash)
        local amount = math.floor(tonumber(player:GetAttribute("OfflineEarnings")) or 0)
        if amount > 0 then
            addCash(player, amount)
        end
        player:SetAttribute("OfflineDoubled", true)
    elseif Config.CashPacks[key] then
        addCash(player, Config.CashPacks[key])
    end
    playerData.receipts[receiptInfo.PurchaseId] = true
    -- keep the receipt list small
    local receiptCount = 0
    for _ in playerData.receipts do
        receiptCount += 1
    end
    if receiptCount > 50 then
        playerData.receiptOrder = playerData.receiptOrder or {}
    end
    playerData.receiptOrder = playerData.receiptOrder or {}
    table.insert(playerData.receiptOrder, receiptInfo.PurchaseId)
    while #playerData.receiptOrder > 50 do
        playerData.receipts[table.remove(playerData.receiptOrder, 1)] = nil
    end
    if not savePlayer(player) then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    local saveNow = game:GetService("ServerStorage"):FindFirstChild("PlayerDataSaveNow")
    if saveNow and (key == "UnknownEgg" or Config.CashPacks[key]) then
        pcall(saveNow.Invoke, saveNow, player)
    end -- egg/cash written to the main save right away -- Roblox retries; receipt already marked, so no double grant this session
    return Enum.ProductPurchaseDecision.PurchaseGranted
end

---------------------------------------------------------------- players
local function onPlayerAdded(player)
    local playerData
    local failed = false
    if shopStore then
        local loaded = false
        for attempt = 1, 5 do
            local ok, result = pcall(shopStore.GetAsync, shopStore, "u" .. player.UserId)
            if ok then
                loaded = true
                if type(result) == "table" then
                    playerData = result
                end
                break
            end
            if tostring(result):find("Studio") then
                loaded = true
                break
            end
            task.wait(attempt)
        end
        failed = not loaded
    end
    if not playerData and legacyShopStore then -- launch reset (v1 -> v2): keep Robux-bought money level + receipts, reset streak/daily/boosts
        local ok, legacyData = pcall(legacyShopStore.GetAsync, legacyShopStore, "u" .. player.UserId)
        if ok and type(legacyData) == "table" and ((legacyData.moneyLevel or 0) > 0 or legacyData.receipts) then
            playerData =
                { moneyLevel = legacyData.moneyLevel or 0, streak = 0, dailyAt = 0, receipts = legacyData.receipts }
        end
    end
    shopData[player] = playerData or { moneyLevel = 0, streak = 0, dailyAt = 0 }
    if failed then
        shopData[player].__loadFailed = true
        warn("[Shop] load failed, shop locked for", player.Name)
    end
    if ownsPass(player, "StarterPack") then
        grantPass(player, "StarterPack")
    end
    refreshMultipliers(player)
    player.CharacterAdded:Connect(function()
        task.wait(1)
        updateVipCrown(player)
    end)
    if player.Character then
        updateVipCrown(player)
    end
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
    task.spawn(onPlayerAdded, player)
end
Players.PlayerRemoving:Connect(function(player)
    savePlayer(player)
    shopData[player] = nil
    busy[player] = nil
    ownedPasses[player] = nil
end)
game:BindToClose(function()
    local pendingSaves = 0
    for _, player in Players:GetPlayers() do
        pendingSaves += 1
        task.spawn(function()
            savePlayer(player)
            pendingSaves -= 1
        end)
    end
    local closeStartedAt = os.clock()
    while pendingSaves > 0 and os.clock() - closeStartedAt < 25 do
        task.wait(0.2)
    end
end)
-- autosave every 2 min (boost timers / streaks)
task.spawn(function()
    while true do
        task.wait(120)
        for player in shopData do
            task.spawn(savePlayer, player)
        end
    end
end)

-- boosts expire on their own
task.spawn(function()
    while true do
        task.wait(5)
        for player in shopData do
            refreshMultipliers(player)
        end
    end
end)
