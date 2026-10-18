--[[ ServerScriptService.CharacterInventory.InventoryService  (ModuleScript)
Server side of the character inventory. The server owns everything:

  • Inventory  = character Tools in the player's Backpack / Character, plus the characters placed on
                 the plot they own (Plots.*.PlacedItems). No separate copy is stored anywhere.
  • Item IDs   = a GUID attribute "ItemId" (and "AcquiredAt") stamped on each character the first
                 time the server sees it. It moves with the character when it is placed or stored.
  • Stats      = CharacterEconomy.Read (Power, IncomePerSecond, RollQuality). Never from the client.
  • Actions    = Place / Store / Hold / PutAway / PlaceBest / PickUp / Sell, all validated here. Placing goes through
                 BrainrotPlacement's own placeCharacter (InvokePlaceCharacter), so slot rules,
                 ownership, unlocks and the money-stand loop stay exactly as they are.
  • Reveals    = after each chamber's HatchCycleCompleted, the owner gets the exact rolled stats.

The client can only ask: ("Fetch") or (action, { id = ItemId }). Every request is rate-limited and a
player can only run one action at a time.

Network contract (instances live in ReplicatedStorage.CharacterInventory, created by Service.Init):
  RemoteFunction Config.RemoteName ("InventoryRequest")  — client -> server, answered by onRequest
      args:   (action: string, payload: table?)  — anything else is rejected with code "Bad"
      action: "Fetch" | "Place" | "Store" | "PickUp" | "Sell" | "SellBackpack" | "SellBackpackAll"
              | "Hold" | "PutAway" | "PlaceBest"
      payload fields read: id (ItemId, ≤ 64 chars), ids (array ≤ 300 of ItemIds), slot (slot name ≤ 32)
      reply:  Fetch -> { ok = true, snapshot }
              other -> { ok: boolean, code: string?, message: string?, snapshot }
              rejected -> { ok = false, code = "Bad" | "Busy", message? }
  RemoteEvent Config.EventName ("InventoryEvent")  — server -> one client
      ("Snapshot", snapshot)  batched every Config.Server.PushInterval for players marked dirty
      ("Reveal", revealData)  after a hatch on the player's own plot
  snapshot = { items = { itemData }, capacity = { hasPlot, total, unlocked, placed }, multiplier,
               allowStore, serverTime }  (itemData fields: see `describe`)
Also creates ReplicatedStorage.CharacterInventory.<Config.PortraitFolder> (display-only model copies) and
sets ReplicatedStorage attribute "StartupInventoryReady". Placed displays get a "SellValue" attribute.
Server-only API: Service.Init(), Service.MenuRequest (= onRequest), Service.Snapshot, Service.Refresh.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("CharacterInventory")
local Config = require(Shared:WaitForChild("InventoryConfig"))
local Catalog = require(ReplicatedStorage:WaitForChild("CharacterCatalog"))
local Economy = require(ReplicatedStorage:WaitForChild("CharacterEconomy"))
local Rewards = require(ServerScriptService:WaitForChild("EggCharacterRewards"))
local SlotUnlocks = require(ServerScriptService:WaitForChild("TempleSlotUnlocks"))

local ServerConfig = Config.Server
local plots = workspace:WaitForChild("Plots")
local brainrotModels = ServerStorage:WaitForChild("BrainrotModels")

local MAX_ITEM_ID_LENGTH = 64
local MAX_SLOT_NAME_LENGTH = 32
local MAX_SELL_IDS = 300
local ACTION_RANGE = 16 -- studs from the slot platform for PickUp / Sell

local Service = {}

local inventoryRemote, inventoryEvent
local dirtyPlayers = {} -- [Player] = true when a new snapshot should be pushed
local busyPlayers = {} -- [Player] = true while an action runs
local rateBuckets = {} -- [Player] = rate-limit bucket
local playerConnections = {} -- [Player] = { connections }

---------------------------------------------------------------- helpers
local function goldenTemplate()
    local future = ServerStorage:FindFirstChild("FutureUpdateContent")
    local characters = future and future:FindFirstChild("Characters")
    return characters and characters:FindFirstChild("Golden Pirate")
end

local function characterIdOf(instance)
    local id = instance:GetAttribute("CharacterId") or instance:GetAttribute("BrainrotId")
    if type(id) == "string" and Catalog.ById[id] then
        return id
    end
    -- golden displays placed before the fix carry CharacterId "Golden Pirate": fall back to the real id
    local brainrotId = instance:GetAttribute("BrainrotId")
    if type(brainrotId) == "string" and Catalog.ById[brainrotId] then
        return brainrotId
    end
    if (instance:GetAttribute("GoldVariant") or instance:GetAttribute("Golden")) and Catalog.ById.Pirate then
        return "Pirate"
    end
    return nil
end

local function isGolden(instance)
    return instance:GetAttribute("GoldVariant") == true or instance:GetAttribute("Golden") == true
end

-- Sell value of a placed character: half its egg price, scaled by how well it rolled (Power / base Power),
-- never less than a minute of its income (so free-egg characters still sell). Limited, golden and
-- owner-spawned characters can't be sold. Shown to the owner as the display's "SellValue" attribute.
local SELL_RATE, SELL_MIN_SECONDS = 0.5, 60
local function sellValueOf(instance)
    local id = characterIdOf(instance)
    local entry = id and Catalog.ById[id]
    if not entry or entry.Limited or isGolden(instance) or instance:GetAttribute("OwnerSpawned") then
        return nil
    end
    local stats = Economy.Read(instance, id)
    if not stats then
        return nil
    end
    local basePower = Economy.BasePower(id)
    local rollFactor = (type(basePower) == "number" and basePower > 0 and type(stats.Power) == "number")
            and math.clamp(stats.Power / basePower, 0.25, 4)
        or 1
    local value = math.max((entry.Price or 0) * SELL_RATE * rollFactor, (stats.IncomePerSecond or 0) * SELL_MIN_SECONDS)
    if value ~= value or value == math.huge or value < 0 then
        return nil
    end
    return math.floor(value)
end

-- Eggs are Tools too; they carry "EggType" and are not characters.
local function isCharacterTool(instance)
    return instance:IsA("Tool") and characterIdOf(instance) ~= nil and not instance:GetAttribute("EggType")
end

-- Give a character its persistent identity the first time the server sees it.
local function stamp(instance)
    if type(instance:GetAttribute("ItemId")) ~= "string" then
        instance:SetAttribute("ItemId", HttpService:GenerateGUID(false))
    end
    if type(instance:GetAttribute("AcquiredAt")) ~= "number" then
        instance:SetAttribute("AcquiredAt", workspace:GetServerTimeNow())
    end
end

-- Returns the roll-quality band and its 1-based rank in Economy.Bands (1 if not found).
local function qualityOf(id, power)
    local band = Economy.Quality(id, power)
    for rank, candidate in ipairs(Economy.Bands) do
        if candidate == band then
            return band, rank
        end
    end
    return band, 1
end

local function plotOf(player)
    for _, plot in plots:GetChildren() do
        if plot:GetAttribute("OwnerUserId") == player.UserId then
            return plot
        end
    end
    return nil
end

-- "Slot3" -> 3; slots without a number sort last.
local function slotIndex(slot)
    return tonumber(slot.Name:match("%d+")) or 99
end

local function sortedSlots(plot)
    local list = {}
    local folder = plot and plot:FindFirstChild("Slots")
    if folder then
        for _, slot in folder:GetChildren() do
            table.insert(list, slot)
        end
    end
    table.sort(list, function(slotA, slotB)
        return slotIndex(slotA) < slotIndex(slotB)
    end)
    return list
end

local function capacityOf(plot)
    local capacity = { hasPlot = plot ~= nil, total = 0, unlocked = 0, placed = 0 }
    for _, slot in sortedSlots(plot) do
        capacity.total += 1
        if slot:GetAttribute("Unlocked") == true then
            capacity.unlocked += 1
        end
        if slot:GetAttribute("Occupied") == true then
            capacity.placed += 1
        end
    end
    return capacity
end

-- Item = { ref = Instance, state = "Backpack" | "Held" | "Placed", slot = n?, data = table sent to client }
local function describe(instance, state, slotNumber)
    local id = characterIdOf(instance)
    if not id then
        return nil
    end
    local stats = Economy.Read(instance, id)
    if not stats then
        return nil
    end
    stamp(instance)
    local entry = Catalog.ById[id]
    local band, rank = qualityOf(id, stats.Power)
    local golden = isGolden(instance)
    return {
        ref = instance,
        state = state,
        data = {
            id = instance:GetAttribute("ItemId"),
            characterId = id,
            name = (golden and "Golden " or "") .. entry.Name,
            golden = golden,
            rarity = entry.Rarity,
            rarityRank = entry.RarityRank,
            power = stats.Power,
            basePower = Economy.BasePower(id),
            income = stats.IncomePerSecond,
            sellValue = sellValueOf(instance),
            quality = band.Name,
            qualityRank = rank,
            qualityColor = band.Color,
            state = state,
            slot = slotNumber,
            acquired = instance:GetAttribute("AcquiredAt"),
        },
    }
end

-- All of a player's characters: backpack, held, and placed on their own plot. Returns (items, plot?).
local function collect(player)
    local items = {}
    local function addTools(container, state)
        if not container then
            return
        end
        for _, child in container:GetChildren() do
            if isCharacterTool(child) then
                local item = describe(child, state)
                if item then
                    table.insert(items, item)
                end
            end
        end
    end
    addTools(player:FindFirstChildOfClass("Backpack"), "Backpack")
    addTools(player.Character, "Held")
    local plot = plotOf(player)
    local placedItems = plot and plot:FindFirstChild("PlacedItems")
    if placedItems then
        for _, display in placedItems:GetChildren() do
            if display:IsA("Model") then
                local slotName = display.Name:match("^(.-)_Brainrot$")
                local item = describe(display, "Placed", slotName and slotIndex({ Name = slotName }) or nil)
                if item then
                    item.slotName = slotName
                    table.insert(items, item)
                end
            end
        end
    end
    return items, plot
end

local function snapshot(player)
    local items, plot = collect(player)
    local list = table.create(#items)
    for i, item in items do
        list[i] = item.data
    end
    return {
        items = list,
        capacity = capacityOf(plot),
        multiplier = (tonumber(workspace:GetAttribute("OwnerIncomeMultiplier")) or 1)
            * (workspace:GetAttribute("NightCashMultiplier") or 1),
        allowStore = ServerConfig.AllowStore,
        serverTime = workspace:GetServerTimeNow(),
    }
end

-- Validates the client-supplied ItemId and looks it up among the player's own items. Returns (item?, plot?).
local function find(player, itemId)
    if type(itemId) ~= "string" or #itemId > MAX_ITEM_ID_LENGTH then
        return nil
    end
    local items, plot = collect(player)
    for _, item in items do
        if item.data.id == itemId then
            return item, plot
        end
    end
    return nil, plot
end

local function aliveHumanoid(player)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if humanoid and rootPart and humanoid.Health > 0 then
        return humanoid
    end
    return nil
end

local function markDirty(player)
    if player then
        dirtyPlayers[player] = true
    end
end
local function markOwner(plot)
    local owner = Players:GetPlayerByUserId(plot:GetAttribute("OwnerUserId") or 0)
    markDirty(owner)
end

---------------------------------------------------------------- actions
-- Every action returns (success: boolean, code: string?, message: string?, ...).

local function freeSlot(plot)
    for _, slot in sortedSlots(plot) do
        if slot:GetAttribute("Unlocked") == true and slot:GetAttribute("Occupied") ~= true then
            return slot
        end
    end
    return nil
end

local function placeTool(player, plot, tool)
    local slot = freeSlot(plot)
    if not slot then
        return false, "Full", "All unlocked slots are full."
    end
    local platform = slot:FindFirstChild("Platform")
    local invoke = platform and platform:FindFirstChild("InvokePlaceCharacter")
    if not invoke then
        return false, "Unavailable", "Placement isn't ready yet."
    end
    local ok, placed = pcall(invoke.Invoke, invoke, player, tool)
    if ok and placed == true then
        return true
    end
    if not ok then
        warn("[Inventory] place failed: " .. tostring(placed))
    end
    return false, "Failed", "Couldn't place that character."
end

-- Turns a placed display back into a backpack Tool (same ItemId / stats). 4th return value = the new Tool.
local function storeDisplay(player, plot, item)
    local display = item.ref
    local id = characterIdOf(display)
    local stats = id and Economy.Read(display, id)
    local template = isGolden(display) and goldenTemplate() or (id and brainrotModels:FindFirstChild(id))
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not stats or not template or not backpack then
        return false, "Failed", "Couldn't store that character."
    end
    local ok, tool = pcall(Rewards.Tool, template, id, stats, display:GetAttribute("Mutation") or false)
    if not ok or not tool then
        warn("[Inventory] store failed: " .. tostring(tool))
        return false, "Failed", "Couldn't store that character."
    end
    -- same item: keep its identity and any extra traits the display carries
    for attributeName, attributeValue in display:GetAttributes() do
        if
            tool:GetAttribute(attributeName) == nil
            and attributeName ~= "Occupied"
            and attributeName ~= "OwnerUserId"
            and attributeName ~= "PlacementToken"
            and attributeName ~= "SlotName"
        then
            tool:SetAttribute(attributeName, attributeValue)
        end
    end
    tool:SetAttribute("ItemId", display:GetAttribute("ItemId"))
    tool:SetAttribute("AcquiredAt", display:GetAttribute("AcquiredAt"))
    -- No yields from here: free the slot, remove the display, hand the tool over.
    local slot = item.slotName and plot.Slots:FindFirstChild(item.slotName)
    display:Destroy() -- BrainrotPlacement's income loop ends when its display is gone
    if slot then
        slot:SetAttribute("Occupied", false)
        slot:SetAttribute("PlacementToken", nil)
        local stand = slot:FindFirstChild("MoneyStand")
        if stand then
            stand:SetAttribute("IncomePerSecond", 0)
        end
    end
    tool.Parent = backpack
    SlotUnlocks.Refresh(plot)
    return true, nil, nil, tool
end

local Actions = {}

function Actions.Place(player, payload)
    local item, plot = find(player, payload.id)
    if not item then
        return false, "Missing", "That character is no longer in your inventory."
    end
    if item.state == "Placed" then
        return false, "Already", "Already placed."
    end
    if not plot then
        return false, "NoPlot", "Claim a plot to place characters."
    end
    if not aliveHumanoid(player) then
        return false, "Dead", "Wait until you respawn."
    end
    return placeTool(player, plot, item.ref)
end

function Actions.Store(player, payload)
    if not ServerConfig.AllowStore then
        return false, "Disabled", "Placed characters stay on their slot."
    end
    local item, plot = find(player, payload.id)
    if not item or item.state ~= "Placed" or not plot then
        return false, "Missing", "That character isn't placed."
    end
    return storeDisplay(player, plot, item)
end

-- Owner-only: take a placed character off its slot, back into the backpack, and equip it.
-- Same character (ItemId, Power, rarity); the slot stays unlocked; stand cash is untouched.
function Actions.PickUp(player, payload)
    local items, plot = collect(player)
    if not plot then
        return false, "NoPlot", "Claim a plot first."
    end
    local humanoid = aliveHumanoid(player)
    if not humanoid then
        return false, "Dead", "Wait until you respawn."
    end
    local target
    for _, item in items do
        if
            item.state == "Placed"
            and (
                item.slotName == payload.slot
                or (payload.id and (item.data.itemId == payload.id or item.data.id == payload.id))
            )
        then
            target = item
            break
        end
    end
    if not target then
        return false, "Missing", "Nothing to pick up there."
    end
    local slot = target.slotName and plot.Slots:FindFirstChild(target.slotName)
    local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if slot and rootPart and (rootPart.Position - slot.Platform.Position).Magnitude > ACTION_RANGE then
        return false, "Far", "Move closer to that slot."
    end
    local ok, code, message, tool = storeDisplay(player, plot, target)
    if not ok then
        return false, code, message
    end
    if tool and tool.Parent then
        humanoid:EquipTool(tool)
    end
    return true
end

-- Owner-only: sell a placed character for cash. The slot stays unlocked; stand cash is untouched.
function Actions.Sell(player, payload)
    if type(payload.slot) ~= "string" or #payload.slot > MAX_SLOT_NAME_LENGTH then
        return false, "Bad", "Nothing to sell there."
    end
    local items, plot = collect(player) -- only the caller's own plot is searched
    if not plot then
        return false, "NoPlot", "Claim a plot first."
    end
    if not aliveHumanoid(player) then
        return false, "Dead", "Wait until you respawn."
    end
    local target
    for _, item in items do
        if item.state == "Placed" and item.slotName == payload.slot then
            target = item
            break
        end
    end
    if not target then
        return false, "Missing", "Nothing to sell there."
    end
    local slot = plot.Slots:FindFirstChild(target.slotName)
    local rootPart = player.Character.HumanoidRootPart -- guaranteed by aliveHumanoid above
    if not slot or (rootPart.Position - slot.Platform.Position).Magnitude > ACTION_RANGE then
        return false, "Far", "Move closer to that slot."
    end
    local value = sellValueOf(target.ref)
    if not value then
        return false, "NoSell", "Can't sell this one."
    end
    local leaderstats = player:FindFirstChild("leaderstats")
    local cash = leaderstats and leaderstats:FindFirstChild("Cash")
    if not cash then
        return false, "NotReady", "Try again in a moment."
    end
    -- No yields from here: remove the display, free the slot, pay out.
    target.ref:Destroy() -- BrainrotPlacement's income loop ends when its display is gone
    slot:SetAttribute("Occupied", false)
    slot:SetAttribute("PlacementToken", nil)
    local stand = slot:FindFirstChild("MoneyStand")
    if stand then
        stand:SetAttribute("IncomePerSecond", 0)
    end
    SlotUnlocks.Refresh(plot)
    cash.Value += value
    return true, "Sold", tostring(value)
end

-- Sell only the caller's carried characters. Placed characters keep the existing slot action.
-- sellAll: payload.ids (array of ItemIds); otherwise payload.id. Incubating tools are skipped.
local function sellBackpack(player, payload, sellAll)
    if not aliveHumanoid(player) then
        return false, "Dead", "Wait until you respawn."
    end
    local wanted = {}
    if sellAll then
        if type(payload.ids) ~= "table" or #payload.ids > MAX_SELL_IDS then
            return false, "Bad", "Invalid character selection."
        end
        for _, itemId in ipairs(payload.ids) do
            if type(itemId) ~= "string" or #itemId > MAX_ITEM_ID_LENGTH then
                return false, "Bad", "Invalid character selection."
            end
            wanted[itemId] = true
        end
    else
        if type(payload.id) ~= "string" or #payload.id > MAX_ITEM_ID_LENGTH then
            return false, "Bad", "Choose a character."
        end
        wanted[payload.id] = true
    end
    local cash = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Cash")
    if not cash then
        return false, "NotReady", "Try again in a moment."
    end
    local items = collect(player)
    local selected, total = {}, 0
    for _, item in items do
        if wanted[item.data.id] and item.state ~= "Placed" and item.ref:IsA("Tool") then
            local value = sellValueOf(item.ref)
            if value ~= nil and not item.ref:GetAttribute("Incubating") then
                table.insert(selected, item.ref)
                total += value
            end
        end
    end
    if #selected == 0 then
        return false, "NoSell", "No sellable backpack characters selected."
    end
    -- No yields: remove each owned tool once and pay only the server-calculated total.
    for _, tool in selected do
        tool:Destroy()
    end
    cash.Value += total
    return true, "Sold", HttpService:JSONEncode({ cash = total, count = #selected })
end
function Actions.SellBackpack(player, payload)
    return sellBackpack(player, payload, false)
end
function Actions.SellBackpackAll(player, payload)
    return sellBackpack(player, payload, true)
end

function Actions.Hold(player, payload)
    local item = find(player, payload.id)
    if not item or item.state == "Placed" then
        return false, "Missing", "That character isn't in your backpack."
    end
    local humanoid = aliveHumanoid(player)
    if not humanoid then
        return false, "Dead", "Wait until you respawn."
    end
    if item.state ~= "Held" then
        humanoid:EquipTool(item.ref)
    end
    return true
end

function Actions.PutAway(player)
    local humanoid = aliveHumanoid(player)
    if humanoid then
        humanoid:UnequipTools()
    end
    return true
end

-- "Best" = highest actual income (Power breaks ties), limited to the unlocked slots.
function Actions.PlaceBest(player)
    local items, plot = collect(player)
    if not plot then
        return false, "NoPlot", "Claim a plot to place characters."
    end
    if not aliveHumanoid(player) then
        return false, "Dead", "Wait until you respawn."
    end
    local capacity = capacityOf(plot)
    if capacity.unlocked == 0 then
        return false, "Full", "Unlock a slot first."
    end
    table.sort(items, function(itemA, itemB)
        if itemA.data.income ~= itemB.data.income then
            return itemA.data.income > itemB.data.income
        end
        if itemA.data.power ~= itemB.data.power then
            return itemA.data.power > itemB.data.power
        end
        return itemA.data.id < itemB.data.id
    end)
    local toStore, toPlace = {}, {}
    if ServerConfig.AllowStore then
        local keep = {}
        for i = 1, math.min(capacity.unlocked, #items) do
            keep[items[i]] = true
        end
        for _, item in items do
            if item.state == "Placed" and not keep[item] then
                table.insert(toStore, item)
            end
            if item.state ~= "Placed" and keep[item] then
                table.insert(toPlace, item)
            end
        end
    else
        local freeSlots = capacity.unlocked - capacity.placed
        for _, item in items do
            if freeSlots <= 0 then
                break
            end
            if item.state ~= "Placed" then
                table.insert(toPlace, item)
                freeSlots -= 1
            end
        end
    end
    if #toPlace == 0 then
        return true, "NoChange", "Your best characters are already placed."
    end
    -- Store only as many as needed to make room, weakest first.
    local freeSlots = capacity.unlocked - capacity.placed
    local stored = 0
    for i = #toStore, 1, -1 do
        if freeSlots >= #toPlace then
            break
        end
        if storeDisplay(player, plot, toStore[i]) then
            stored += 1
            freeSlots += 1
        end
    end
    local placed = 0
    for _, item in toPlace do
        if item.ref.Parent and placeTool(player, plot, item.ref) then
            placed += 1
        end
    end
    if placed == 0 then
        return false, "Failed", "Couldn't place characters."
    end
    local message = "Placed " .. placed .. (stored > 0 and (" · swapped " .. stored) or "")
    return true, "Done", message
end

---------------------------------------------------------------- remote
-- Token bucket: RequestBurst tokens, refilled at RequestsPerSecond.
local function allow(player)
    local now = os.clock()
    local bucket = rateBuckets[player]
    if not bucket then
        bucket = { tokens = ServerConfig.RequestBurst, at = now }
        rateBuckets[player] = bucket
    end
    bucket.tokens =
        math.min(ServerConfig.RequestBurst, bucket.tokens + (now - bucket.at) * ServerConfig.RequestsPerSecond)
    bucket.at = now
    if bucket.tokens < 1 then
        return false
    end
    bucket.tokens -= 1
    return true
end

-- RemoteFunction handler. All client input is untrusted: action must name an Actions entry, payload is
-- replaced by {} when not a table, and each action validates the fields it reads.
local function onRequest(player, action, payload)
    if type(action) ~= "string" then
        return { ok = false, code = "Bad" }
    end
    if not allow(player) then
        return { ok = false, code = "Busy", message = "Slow down a little." }
    end
    if action == "Fetch" then
        return { ok = true, snapshot = snapshot(player) }
    end
    local handler = Actions[action]
    if not handler then
        return { ok = false, code = "Bad" }
    end
    if type(payload) ~= "table" then
        payload = {}
    end
    if busyPlayers[player] then
        return { ok = false, code = "Busy", message = "Still working on your last request." }
    end
    busyPlayers[player] = true
    local ok, success, code, message = pcall(handler, player, payload)
    busyPlayers[player] = nil
    if not ok then
        warn("[Inventory] " .. action .. " error: " .. tostring(success))
        success, code, message = false, "Error", "Something went wrong. Try again."
    end
    dirtyPlayers[player] = nil -- the answer carries the fresh snapshot
    return { ok = success == true, code = code, message = message, snapshot = snapshot(player) }
end

---------------------------------------------------------------- hatch reveals
-- The direct child of Plots that contains `instance` (nil if it isn't under Plots).
local function plotOfInstance(instance)
    local node = instance
    while node and node.Parent ~= plots do
        node = node.Parent
    end
    return node
end

local hookedEvents = setmetatable({}, { __mode = "k" })
-- HatchCycleCompleted:Fire(player, tool, rewardId) is raised by the hatch chamber on the server.
local function hookChamber(instance)
    if hookedEvents[instance] or instance.Name ~= "HatchCycleCompleted" or not instance:IsA("BindableEvent") then
        return
    end
    hookedEvents[instance] = true
    instance.Event:Connect(function(hatchingPlayer, tool, rewardId)
        if
            typeof(hatchingPlayer) ~= "Instance"
            or not hatchingPlayer:IsA("Player")
            or hatchingPlayer.Parent ~= Players
        then
            return
        end
        local plot = plotOfInstance(instance)
        if not plot or plot:GetAttribute("OwnerUserId") ~= hatchingPlayer.UserId then
            return
        end
        local chamber = instance.Parent
        local shown = chamber and chamber:FindFirstChild("HatchedCharacter")
        local id = type(rewardId) == "string" and Catalog.ById[rewardId] and rewardId
        local stats = shown and id and Economy.Read(shown, id)
        if not stats then
            return
        end
        local entry = Catalog.ById[id]
        local band, rank = qualityOf(id, stats.Power)
        local golden = typeof(tool) == "Instance" and tool:GetAttribute("GoldVariant") == true
        inventoryEvent:FireClient(hatchingPlayer, "Reveal", {
            revealId = HttpService:GenerateGUID(false),
            characterId = id,
            name = (golden and "Golden " or "") .. entry.Name,
            golden = golden,
            rarity = entry.Rarity,
            rarityRank = entry.RarityRank,
            power = stats.Power,
            basePower = Economy.BasePower(id),
            income = stats.IncomePerSecond,
            quality = band.Name,
            qualityRank = rank,
            qualityColor = band.Color,
        })
    end)
end

---------------------------------------------------------------- portraits (display-only copies)
local function buildPortraits()
    local folder = Shared:FindFirstChild(Config.PortraitFolder)
    if folder then
        folder:Destroy()
    end
    folder = Instance.new("Folder")
    folder.Name = Config.PortraitFolder
    local function addPortrait(template, name)
        if not template or not template:IsA("Model") then
            return
        end
        local copy = template:Clone()
        copy.Name = name
        for _, descendant in copy:GetDescendants() do
            if
                descendant:IsA("LuaSourceContainer")
                or descendant:IsA("ProximityPrompt")
                or descendant:IsA("BillboardGui")
                or descendant:IsA("Sound")
                or descendant:IsA("ParticleEmitter")
                or descendant:IsA("Light")
                or descendant:IsA("ClickDetector")
            then
                descendant:Destroy()
            elseif descendant:IsA("BasePart") then
                descendant.Anchored = true
                descendant.CanCollide = false
                descendant.CanTouch = false
                descendant.CanQuery = false
            end
        end
        copy.Parent = folder
    end
    for _, template in brainrotModels:GetChildren() do
        if characterIdOf(template) or Catalog.ById[template.Name] then
            addPortrait(template, template.Name)
        end
    end
    addPortrait(goldenTemplate(), "Pirate_Golden")
    folder.Parent = Shared
end

---------------------------------------------------------------- watching
local function watchPlayer(player)
    local connections = {}
    playerConnections[player] = connections
    local function hookContainer(container)
        if not container then
            return
        end
        table.insert(
            connections,
            container.ChildAdded:Connect(function(child)
                if isCharacterTool(child) then
                    stamp(child)
                    markDirty(player)
                end
            end)
        )
        table.insert(
            connections,
            container.ChildRemoved:Connect(function(child)
                if child:IsA("Tool") then
                    markDirty(player)
                end
            end)
        )
        for _, child in container:GetChildren() do
            if isCharacterTool(child) then
                stamp(child)
            end
        end
    end
    local function onCharacter(character)
        hookContainer(character)
        markDirty(player)
    end
    table.insert(
        connections,
        player.ChildAdded:Connect(function(child)
            if child:IsA("Backpack") then
                hookContainer(child)
                markDirty(player)
            end
        end)
    )
    hookContainer(player:FindFirstChildOfClass("Backpack"))
    table.insert(connections, player.CharacterAdded:Connect(onCharacter))
    if player.Character then
        onCharacter(player.Character)
    end
end

local function unwatch(player)
    for _, connection in playerConnections[player] or {} do
        connection:Disconnect()
    end
    playerConnections[player] = nil
    dirtyPlayers[player] = nil
    busyPlayers[player] = nil
    rateBuckets[player] = nil
end

-- Yields (WaitForChild up to 10 s each); always run in its own thread.
local function watchPlot(plot)
    local placedItems = plot:WaitForChild("PlacedItems", 10)
    if placedItems then
        local function stampAndPrice(child)
            if child:IsA("Model") and characterIdOf(child) then
                stamp(child)
                child:SetAttribute("SellValue", sellValueOf(child))
            end
        end
        for _, child in placedItems:GetChildren() do
            stampAndPrice(child)
        end
        placedItems.ChildAdded:Connect(function(child)
            stampAndPrice(child)
            markOwner(plot)
        end)
        placedItems.ChildRemoved:Connect(function()
            markOwner(plot)
        end)
    end
    local slots = plot:WaitForChild("Slots", 10)
    if slots then
        for _, slot in slots:GetChildren() do
            slot.AttributeChanged:Connect(function(name)
                if name == "Unlocked" or name == "Occupied" then
                    markOwner(plot)
                end
            end)
        end
    end
    plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
        for _, otherPlayer in Players:GetPlayers() do
            markDirty(otherPlayer)
        end
    end)
end

---------------------------------------------------------------- public
function Service.Init()
    inventoryRemote = Shared:FindFirstChild(Config.RemoteName) or Instance.new("RemoteFunction")
    inventoryRemote.Name = Config.RemoteName
    inventoryRemote.Parent = Shared
    inventoryEvent = Shared:FindFirstChild(Config.EventName) or Instance.new("RemoteEvent")
    inventoryEvent.Name = Config.EventName
    inventoryEvent.Parent = Shared

    buildPortraits()
    inventoryRemote.OnServerInvoke = onRequest
    ReplicatedStorage:SetAttribute("StartupInventoryReady", true)

    for _, player in Players:GetPlayers() do
        watchPlayer(player)
    end
    Players.PlayerAdded:Connect(watchPlayer)
    Players.PlayerRemoving:Connect(unwatch)
    for _, plot in plots:GetChildren() do
        task.spawn(watchPlot, plot)
    end
    plots.ChildAdded:Connect(function(plot)
        task.spawn(watchPlot, plot)
    end)
    for _, descendant in plots:GetDescendants() do
        hookChamber(descendant)
    end
    plots.DescendantAdded:Connect(hookChamber)
    workspace:GetAttributeChangedSignal("NightCashMultiplier"):Connect(function()
        for _, player in Players:GetPlayers() do
            markDirty(player)
        end
    end)
    workspace:GetAttributeChangedSignal("OwnerIncomeMultiplier"):Connect(function()
        for _, player in Players:GetPlayers() do
            markDirty(player)
        end
    end)

    -- one loop pushes batched snapshots
    task.spawn(function()
        while true do
            task.wait(ServerConfig.PushInterval)
            for player in dirtyPlayers do
                dirtyPlayers[player] = nil
                if player.Parent == Players then
                    local ok, snap = pcall(snapshot, player)
                    if ok then
                        inventoryEvent:FireClient(player, "Snapshot", snap)
                    else
                        warn("[Inventory] snapshot: " .. tostring(snap))
                    end
                end
            end
        end
    end)
end

-- Server-side helpers for other systems
Service.MenuRequest = onRequest -- internal server adapter; existing validation/rate limits
Service.Snapshot = snapshot
Service.Refresh = markDirty

return Service
