--[[ ServerScriptService.CharacterInventory.InventoryService  (ModuleScript)
Server side of the character inventory. The server owns everything:

  • Inventory  = character Tools in the player's Backpack / Character, plus the characters placed on
                 the plot they own (Plots.*.PlacedItems). No separate copy is stored anywhere.
  • Item IDs   = a GUID attribute "ItemId" (and "AcquiredAt") stamped on each character the first
                 time the server sees it. It moves with the character when it is placed or stored.
  • Stats      = CharacterEconomy.Read (Power, IncomePerSecond, RollQuality). Never from the client.
  • Actions    = Place / Store / Hold / PutAway / PlaceBest, all validated here. Placing goes through
                 BrainrotPlacement's own placeCharacter (InvokePlaceCharacter), so slot rules,
                 ownership, unlocks and the money-stand loop stay exactly as they are.
  • Reveals    = after each chamber's HatchCycleCompleted, the owner gets the exact rolled stats.

The client can only ask: ("Fetch") or (action, { id = ItemId }). Every request is rate-limited and a
player can only run one action at a time.
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

local S = Config.Server
local plots = workspace:WaitForChild("Plots")
local library = ServerStorage:WaitForChild("BrainrotModels")

local Service = {}

local remote, event
local dirty = {}    -- [Player] = true when a new snapshot should be pushed
local busy = {}     -- [Player] = true while an action runs
local buckets = {}  -- [Player] = rate-limit bucket
local watched = {}  -- [Player] = { connections }

---------------------------------------------------------------- helpers
local function goldenTemplate()
	local future = ServerStorage:FindFirstChild("FutureUpdateContent")
	local chars = future and future:FindFirstChild("Characters")
	return chars and chars:FindFirstChild("Golden Pirate")
end

local function characterIdOf(obj)
	local id = obj:GetAttribute("CharacterId") or obj:GetAttribute("BrainrotId")
	if type(id) == "string" and Catalog.ById[id] then return id end
	return nil
end

local function isGolden(obj)
	return obj:GetAttribute("GoldVariant") == true or obj:GetAttribute("Golden") == true
end

local function isCharacterTool(obj)
	return obj:IsA("Tool") and characterIdOf(obj) ~= nil and not obj:GetAttribute("EggType")
end

local function stamp(obj)
	if type(obj:GetAttribute("ItemId")) ~= "string" then obj:SetAttribute("ItemId", HttpService:GenerateGUID(false)) end
	if type(obj:GetAttribute("AcquiredAt")) ~= "number" then obj:SetAttribute("AcquiredAt", workspace:GetServerTimeNow()) end
end

local function qualityOf(id, power)
	local band = Economy.Quality(id, power)
	for i, b in ipairs(Economy.Bands) do
		if b == band then return band, i end
	end
	return band, 1
end

local function plotOf(player)
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == player.UserId then return plot end
	end
	return nil
end

local function slotIndex(slot) return tonumber(slot.Name:match("%d+")) or 99 end

local function sortedSlots(plot)
	local list = {}
	local folder = plot and plot:FindFirstChild("Slots")
	if folder then for _, s in folder:GetChildren() do table.insert(list, s) end end
	table.sort(list, function(a, b) return slotIndex(a) < slotIndex(b) end)
	return list
end

local function capacityOf(plot)
	local cap = { hasPlot = plot ~= nil, total = 0, unlocked = 0, placed = 0 }
	for _, slot in sortedSlots(plot) do
		cap.total += 1
		if slot:GetAttribute("Unlocked") == true then cap.unlocked += 1 end
		if slot:GetAttribute("Occupied") == true then cap.placed += 1 end
	end
	return cap
end

-- Item = { ref = Instance, state = "Backpack" | "Held" | "Placed", slot = n?, data = table sent to client }
local function describe(obj, state, slotNumber)
	local id = characterIdOf(obj)
	if not id then return nil end
	local stats = Economy.Read(obj, id)
	if not stats then return nil end
	stamp(obj)
	local entry = Catalog.ById[id]
	local band, rank = qualityOf(id, stats.Power)
	local golden = isGolden(obj)
	return {
		ref = obj,
		state = state,
		data = {
			id = obj:GetAttribute("ItemId"),
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
			state = state,
			slot = slotNumber,
			acquired = obj:GetAttribute("AcquiredAt"),
		},
	}
end

local function collect(player)
	local items = {}
	local function addTools(container, state)
		if not container then return end
		for _, obj in container:GetChildren() do
			if isCharacterTool(obj) then
				local item = describe(obj, state)
				if item then table.insert(items, item) end
			end
		end
	end
	addTools(player:FindFirstChildOfClass("Backpack"), "Backpack")
	addTools(player.Character, "Held")
	local plot = plotOf(player)
	local placed = plot and plot:FindFirstChild("PlacedItems")
	if placed then
		for _, display in placed:GetChildren() do
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
	for i, item in items do list[i] = item.data end
	return {
		items = list,
		capacity = capacityOf(plot),
		multiplier = tonumber(workspace:GetAttribute("OwnerIncomeMultiplier")) or 1,
		allowStore = S.AllowStore,
		serverTime = workspace:GetServerTimeNow(),
	}
end

local function find(player, itemId)
	if type(itemId) ~= "string" or #itemId > 64 then return nil end
	local items, plot = collect(player)
	for _, item in items do
		if item.data.id == itemId then return item, plot end
	end
	return nil, plot
end

local function aliveHumanoid(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then return hum end
	return nil
end

local function markDirty(player) if player then dirty[player] = true end end
local function markOwner(plot)
	local owner = Players:GetPlayerByUserId(plot:GetAttribute("OwnerUserId") or 0)
	markDirty(owner)
end

---------------------------------------------------------------- actions
local function freeSlot(plot)
	for _, slot in sortedSlots(plot) do
		if slot:GetAttribute("Unlocked") == true and slot:GetAttribute("Occupied") ~= true then return slot end
	end
	return nil
end

local function placeTool(player, plot, tool)
	local slot = freeSlot(plot)
	if not slot then return false, "Full", "All unlocked slots are full." end
	local platform = slot:FindFirstChild("Platform")
	local invoke = platform and platform:FindFirstChild("InvokePlaceCharacter")
	if not invoke then return false, "Unavailable", "Placement isn't ready yet." end
	local ok, placed = pcall(invoke.Invoke, invoke, player, tool)
	if ok and placed == true then return true end
	if not ok then warn("[Inventory] place failed: " .. tostring(placed)) end
	return false, "Failed", "Couldn't place that character."
end

local function storeDisplay(player, plot, item)
	local display = item.ref
	local id = characterIdOf(display)
	local stats = id and Economy.Read(display, id)
	local template = isGolden(display) and goldenTemplate() or (id and library:FindFirstChild(id))
	local bag = player:FindFirstChildOfClass("Backpack")
	if not stats or not template or not bag then return false, "Failed", "Couldn't store that character." end
	local ok, tool = pcall(Rewards.Tool, template, id, stats)
	if not ok or not tool then
		warn("[Inventory] store failed: " .. tostring(tool))
		return false, "Failed", "Couldn't store that character."
	end
	-- same item: keep its identity
	tool:SetAttribute("ItemId", display:GetAttribute("ItemId"))
	tool:SetAttribute("AcquiredAt", display:GetAttribute("AcquiredAt"))
	-- No yields from here: free the slot, remove the display, hand the tool over.
	local slot = item.slotName and plot.Slots:FindFirstChild(item.slotName)
	display:Destroy() -- BrainrotPlacement's income loop ends when its display is gone
	if slot then
		slot:SetAttribute("Occupied", false)
		slot:SetAttribute("PlacementToken", nil)
		local stand = slot:FindFirstChild("MoneyStand")
		if stand then stand:SetAttribute("IncomePerSecond", 0) end
	end
	tool.Parent = bag
	SlotUnlocks.Refresh(plot)
	return true
end

local Actions = {}

function Actions.Place(player, payload)
	local item, plot = find(player, payload.id)
	if not item then return false, "Missing", "That character is no longer in your inventory." end
	if item.state == "Placed" then return false, "Already", "Already placed." end
	if not plot then return false, "NoPlot", "Claim a plot to place characters." end
	if not aliveHumanoid(player) then return false, "Dead", "Wait until you respawn." end
	return placeTool(player, plot, item.ref)
end

function Actions.Store(player, payload)
	if not S.AllowStore then return false, "Disabled", "Placed characters stay on their slot." end
	local item, plot = find(player, payload.id)
	if not item or item.state ~= "Placed" or not plot then return false, "Missing", "That character isn't placed." end
	return storeDisplay(player, plot, item)
end

function Actions.Hold(player, payload)
	local item = find(player, payload.id)
	if not item or item.state == "Placed" then return false, "Missing", "That character isn't in your backpack." end
	local hum = aliveHumanoid(player)
	if not hum then return false, "Dead", "Wait until you respawn." end
	if item.state ~= "Held" then hum:EquipTool(item.ref) end
	return true
end

function Actions.PutAway(player)
	local hum = aliveHumanoid(player)
	if hum then hum:UnequipTools() end
	return true
end

-- "Best" = highest actual income (Power breaks ties), limited to the unlocked slots.
function Actions.PlaceBest(player)
	local items, plot = collect(player)
	if not plot then return false, "NoPlot", "Claim a plot to place characters." end
	if not aliveHumanoid(player) then return false, "Dead", "Wait until you respawn." end
	local cap = capacityOf(plot)
	if cap.unlocked == 0 then return false, "Full", "Unlock a slot first." end
	table.sort(items, function(a, b)
		if a.data.income ~= b.data.income then return a.data.income > b.data.income end
		if a.data.power ~= b.data.power then return a.data.power > b.data.power end
		return a.data.id < b.data.id
	end)
	local toStore, toPlace = {}, {}
	if S.AllowStore then
		local keep = {}
		for i = 1, math.min(cap.unlocked, #items) do keep[items[i]] = true end
		for _, item in items do
			if item.state == "Placed" and not keep[item] then table.insert(toStore, item) end
			if item.state ~= "Placed" and keep[item] then table.insert(toPlace, item) end
		end
	else
		local free = cap.unlocked - cap.placed
		for _, item in items do
			if free <= 0 then break end
			if item.state ~= "Placed" then table.insert(toPlace, item) free -= 1 end
		end
	end
	if #toPlace == 0 then return true, "NoChange", "Your best characters are already placed." end
	-- Store only as many as needed to make room, weakest first.
	local free = cap.unlocked - cap.placed
	local stored = 0
	for i = #toStore, 1, -1 do
		if free >= #toPlace then break end
		if storeDisplay(player, plot, toStore[i]) then stored += 1 free += 1 end
	end
	local placed = 0
	for _, item in toPlace do
		if item.ref.Parent and placeTool(player, plot, item.ref) then placed += 1 end
	end
	if placed == 0 then return false, "Failed", "Couldn't place characters." end
	local message = "Placed " .. placed .. (stored > 0 and (" · swapped " .. stored) or "")
	return true, "Done", message
end

---------------------------------------------------------------- remote
local function allow(player)
	local now = os.clock()
	local b = buckets[player]
	if not b then b = { tokens = S.RequestBurst, at = now } buckets[player] = b end
	b.tokens = math.min(S.RequestBurst, b.tokens + (now - b.at) * S.RequestsPerSecond)
	b.at = now
	if b.tokens < 1 then return false end
	b.tokens -= 1
	return true
end

local function onRequest(player, action, payload)
	if type(action) ~= "string" then return { ok = false, code = "Bad" } end
	if not allow(player) then return { ok = false, code = "Busy", message = "Slow down a little." } end
	if action == "Fetch" then return { ok = true, snapshot = snapshot(player) } end
	local handler = Actions[action]
	if not handler then return { ok = false, code = "Bad" } end
	if type(payload) ~= "table" then payload = {} end
	if busy[player] then return { ok = false, code = "Busy", message = "Still working on your last request." } end
	busy[player] = true
	local ok, success, code, message = pcall(handler, player, payload)
	busy[player] = nil
	if not ok then
		warn("[Inventory] " .. action .. " error: " .. tostring(success))
		success, code, message = false, "Error", "Something went wrong. Try again."
	end
	dirty[player] = nil -- the answer carries the fresh snapshot
	return { ok = success == true, code = code, message = message, snapshot = snapshot(player) }
end

---------------------------------------------------------------- hatch reveals
local function plotOfInstance(inst)
	local node = inst
	while node and node.Parent ~= plots do node = node.Parent end
	return node
end

local hooked = setmetatable({}, { __mode = "k" })
local function hookChamber(inst)
	if hooked[inst] or inst.Name ~= "HatchCycleCompleted" or not inst:IsA("BindableEvent") then return end
	hooked[inst] = true
	inst.Event:Connect(function(who, tool, rewardId)
		if typeof(who) ~= "Instance" or not who:IsA("Player") or who.Parent ~= Players then return end
		local plot = plotOfInstance(inst)
		if not plot or plot:GetAttribute("OwnerUserId") ~= who.UserId then return end
		local chamber = inst.Parent
		local shown = chamber and chamber:FindFirstChild("HatchedCharacter")
		local id = type(rewardId) == "string" and Catalog.ById[rewardId] and rewardId
		local stats = shown and id and Economy.Read(shown, id)
		if not stats then return end
		local entry = Catalog.ById[id]
		local band, rank = qualityOf(id, stats.Power)
		local golden = typeof(tool) == "Instance" and tool:GetAttribute("GoldVariant") == true
		event:FireClient(who, "Reveal", {
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
	if folder then folder:Destroy() end
	folder = Instance.new("Folder")
	folder.Name = Config.PortraitFolder
	local function add(template, name)
		if not template or not template:IsA("Model") then return end
		local copy = template:Clone()
		copy.Name = name
		for _, d in copy:GetDescendants() do
			if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("Sound")
				or d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("ClickDetector") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
			end
		end
		copy.Parent = folder
	end
	for _, template in library:GetChildren() do
		if characterIdOf(template) or Catalog.ById[template.Name] then add(template, template.Name) end
	end
	add(goldenTemplate(), "Pirate_Golden")
	folder.Parent = Shared
end

---------------------------------------------------------------- watching
local function watchPlayer(player)
	local conns = {}
	watched[player] = conns
	local function hookContainer(container)
		if not container then return end
		table.insert(conns, container.ChildAdded:Connect(function(child)
			if isCharacterTool(child) then stamp(child) markDirty(player) end
		end))
		table.insert(conns, container.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then markDirty(player) end
		end))
		for _, child in container:GetChildren() do if isCharacterTool(child) then stamp(child) end end
	end
	local function onCharacter(char)
		hookContainer(char)
		markDirty(player)
	end
	table.insert(conns, player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then hookContainer(child) markDirty(player) end
	end))
	hookContainer(player:FindFirstChildOfClass("Backpack"))
	table.insert(conns, player.CharacterAdded:Connect(onCharacter))
	if player.Character then onCharacter(player.Character) end
end

local function unwatch(player)
	for _, c in watched[player] or {} do c:Disconnect() end
	watched[player] = nil
	dirty[player] = nil
	busy[player] = nil
	buckets[player] = nil
end

local function watchPlot(plot)
	local placed = plot:WaitForChild("PlacedItems", 10)
	if placed then
		placed.ChildAdded:Connect(function(child)
			if child:IsA("Model") and characterIdOf(child) then stamp(child) end
			markOwner(plot)
		end)
		placed.ChildRemoved:Connect(function() markOwner(plot) end)
	end
	local slots = plot:WaitForChild("Slots", 10)
	if slots then
		for _, slot in slots:GetChildren() do
			slot.AttributeChanged:Connect(function(name)
				if name == "Unlocked" or name == "Occupied" then markOwner(plot) end
			end)
		end
	end
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		for _, p in Players:GetPlayers() do markDirty(p) end
	end)
end

---------------------------------------------------------------- public
function Service.Init()
	remote = Shared:FindFirstChild(Config.RemoteName) or Instance.new("RemoteFunction")
	remote.Name = Config.RemoteName
	remote.Parent = Shared
	event = Shared:FindFirstChild(Config.EventName) or Instance.new("RemoteEvent")
	event.Name = Config.EventName
	event.Parent = Shared

	buildPortraits()
	remote.OnServerInvoke = onRequest
	ReplicatedStorage:SetAttribute("StartupInventoryReady",true)

	for _, p in Players:GetPlayers() do watchPlayer(p) end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(unwatch)
	for _, plot in plots:GetChildren() do task.spawn(watchPlot, plot) end
	plots.ChildAdded:Connect(function(plot) task.spawn(watchPlot, plot) end)
	for _, d in plots:GetDescendants() do hookChamber(d) end
	plots.DescendantAdded:Connect(hookChamber)
	workspace:GetAttributeChangedSignal("OwnerIncomeMultiplier"):Connect(function()
		for _, p in Players:GetPlayers() do markDirty(p) end
	end)

	-- one loop pushes batched snapshots
	task.spawn(function()
		while true do
			task.wait(S.PushInterval)
			for player in dirty do
				dirty[player] = nil
				if player.Parent == Players then
					local ok, snap = pcall(snapshot, player)
					if ok then event:FireClient(player, "Snapshot", snap) else warn("[Inventory] snapshot: " .. tostring(snap)) end
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
