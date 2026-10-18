--[[ PlayerDataService — saves and restores each player's progress (DataStore "PlayerData_v1", key "u<UserId>").
Saved: Cash (+ uncollected stand cash), backpack/held/incubating egg + character tools, placed characters (same slot),
unlocked slots, temple level, incubator count/levels, index discoveries, quests.
Safety: never saves if the load failed (no wipes), session lock so two servers can't load the same player at once,
autosave every 90 s, save on leave and on server shutdown. In Studio without API access it runs session-only.
Other scripts: PlotManager waits for player attribute "DataLoaded" and calls ServerStorage.PlayerDataSnapshot before it clears the plot.
]]
local Players = game:GetService("Players")
local DSS = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")

local STORE_NAME, VERSION = "PlayerData_v1", 1
local AUTOSAVE, LOCK_TIMEOUT = 30, 150
local okStore, store = pcall(DSS.GetDataStore, DSS, STORE_NAME)
if not okStore then store = nil end
-- Studio: real DataStores are blocked unless API access is on, so use an in-memory practice store (nothing persists)
if RunService:IsStudio() then
	local ok = pcall(function() store:GetAsync("__probe") end)
	if not ok then
		local mem = {}
		store = { UpdateAsync = function(_, key, fn) local nv = fn(mem[key]) if nv ~= nil then mem[key] = nv end return nv end }
		warn("[PlayerData] Studio: using in-memory practice store (saves do not persist between play tests)")
	end
end

local Catalog = require(RS:WaitForChild("CharacterCatalog"))
local Economy = require(RS:WaitForChild("CharacterEconomy"))
local Rewards = require(SSS:WaitForChild("EggCharacterRewards"))
local SlotUnlocks = require(SSS:WaitForChild("TempleSlotUnlocks"))
local Quests do local ok, q = pcall(require, SSS:WaitForChild("GameMenu"):WaitForChild("QuestService")) Quests = ok and q or nil end
local Adapter do local ok, a = pcall(require, SSS.GameMenu:WaitForChild("GameAdapter")) Adapter = ok and a or nil end
local library = ServerStorage:WaitForChild("BrainrotModels")

local data, loaded, final, lastHeld = {}, {}, {}, {}
local lastSet = {}
local restored = {} -- [p] = { cash = bool, all = bool }: only overwrite saved fields once they were restored in-game
local carry = {}    -- [p] = records that could not be rebuilt; kept in the save instead of being deleted

------------------------------------------------------------ helpers
local function plotOf(p) for _, plot in workspace.Plots:GetChildren() do if plot:GetAttribute("OwnerUserId") == p.UserId then return plot end end end
local function cashOf(p) local ls = p:FindFirstChild("leaderstats") return ls and ls:FindFirstChild("Cash") end
local function attrs(obj)
	local t = {}
	for k, v in obj:GetAttributes() do local ty = typeof(v) if ty == "string" or ty == "number" or ty == "boolean" then t[k] = v end end
	return t
end
local SKIP = { Occupied = true, OwnerUserId = true, PlacementToken = true, SlotName = true, IncubatorChamber = true }
local function serializeTool(tool)
	if not tool:IsA("Tool") then return nil end
	local a = attrs(tool)
	if a.CharacterId or a.BrainrotId then return { k = "char", n = tool.Name, a = a } end
	if a.EggType then return { k = "egg", n = tool.Name, a = a } end
	return nil -- bat and other gear are given by their own scripts
end

------------------------------------------------------------ rebuild
local function goldenTemplate() local f = ServerStorage:FindFirstChild("FutureUpdateContent") local c = f and f:FindFirstChild("Characters") return c and c:FindFirstChild("Golden Pirate") end
local function buildChar(rec)
	local a = rec.a
	local id = a.CharacterId or a.BrainrotId
	if not id or not Catalog.ById[id] then return nil end
	local template = (a.GoldVariant or a.Golden) and goldenTemplate() or library:FindFirstChild(id)
	if not template then return nil end
	local probe = Instance.new("Folder") for k, v in a do probe:SetAttribute(k, v) end
	local stats = Economy.Read(probe, id) or Economy.Roll(id) probe:Destroy()
	local ok, tool = pcall(Rewards.Tool, template, id, stats)
	if not ok or not tool then warn("[PlayerData] char rebuild failed", id, tool) return nil end
	for k, v in a do if not SKIP[k] then tool:SetAttribute(k, v) end end
	if rec.n then tool.Name = rec.n end
	return tool
end
local function buildEgg(rec)
	local a = rec.a
	local id = a.EggType
	local template
	if a.UnknownEgg then template = RS.ShopSystem.ShopModels:FindFirstChild("UnknownEgg")
	else template = ServerStorage.AuxEggTemplates:FindFirstChild(id) end
	if not template and not a.UnknownEgg then return nil end
	local tool = Instance.new("Tool") tool.Name = rec.n or (id .. " Egg") tool.CanBeDropped = false
	local entry = Catalog.ById[id] if entry then pcall(Catalog.Stamp, tool, entry) end
	for k, v in a do if not SKIP[k] then tool:SetAttribute(k, v) end end
	local handle = Instance.new("Part") handle.Name = "Handle" handle.Size = Vector3.one handle.Transparency = 1
	handle.CanCollide = false handle.Massless = true handle.Parent = tool
	if template then
		local visual = template:Clone() visual.Name = "Egg"
		if a.UnknownEgg then local _, size = visual:GetBoundingBox() visual:ScaleTo(visual:GetScale() * 2.2 / math.max(size.Y, 0.01))
		else visual:ScaleTo(template:GetScale() * 0.5) end
		visual:PivotTo(CFrame.new())
		for _, d in visual:GetDescendants() do
			if d:IsA("BasePart") then d.Anchored = false d.CanCollide = false d.CanTouch = false d.Massless = true
				local w = Instance.new("WeldConstraint") w.Part0 = handle w.Part1 = d w.Parent = handle
			elseif d:IsA("BaseScript") then d:Destroy() end
		end
		visual.Parent = tool
	end
	return tool
end
local function build(rec, p)
	local ok, t = pcall(function() if rec.k == "char" then return buildChar(rec) elseif rec.k == "egg" then return buildEgg(rec) end end)
	if not ok or not t then if p then carry[p] = carry[p] or {} table.insert(carry[p], rec) warn("[PlayerData] kept unbuildable item in save", p.Name, rec.n) end return nil end
	return t
end

------------------------------------------------------------ snapshot (live state -> table)
local function snapshot(p, isFinal)
	local d = data[p] if not d or not loaded[p] then return end
	local r = restored[p]
	if not r or not r.cash then return end -- nothing given back yet: keep the loaded save exactly as it is
	local cash = cashOf(p)
	local plot = plotOf(p)
	local tools, seen = {}, {}
	local function addFrom(container) if not container then return end
		for _, t in container:GetChildren() do if not seen[t] then local r = serializeTool(t) if r then seen[t] = true table.insert(tools, r) end end end end
	addFrom(p:FindFirstChildOfClass("Backpack"))
	do local held = p:FindFirstChild("IncubatorHeldEggs")
		if held then for _, t in held:GetChildren() do if not seen[t] then local r = serializeTool(t) if r then seen[t] = true
			local key = t:GetAttribute("IncubatorChamber")
			if plot and key then for _, m in (plot:FindFirstChild("Chambers") and plot.Chambers:GetChildren() or {}) do if m:GetFullName() == key then
				local ends = m:GetAttribute("CycleEnd")
				r.inc = { c = m:GetAttribute("ChamberIndex") or 1, left = (m:GetAttribute("Hatching") and ends) and math.max(0, ends - workspace:GetServerTimeNow()) or 0 }
			end end end
			r.a.Incubating = nil
			table.insert(tools, r) end end end end
	end
	if p.Character then addFrom(p.Character) elseif isFinal then for _, r in lastHeld[p] or {} do table.insert(tools, r) end end
	local placed, unlocked, standCash, chambers = {}, {}, 0, {}
	if plot then
		for _, display in plot.PlacedItems:GetChildren() do
			local slotName = display.Name:match("^(.-)_Brainrot$")
			local a = attrs(display)
			if slotName and (a.CharacterId or a.BrainrotId) then table.insert(placed, { s = slotName, k = "char", n = display:GetAttribute("ToolName"), a = a }) end
		end
		for _, slot in plot.Slots:GetChildren() do
			if slot:GetAttribute("Unlocked") then table.insert(unlocked, slot.Name) end
			local stand = slot:FindFirstChild("MoneyStand")
			if stand and isFinal then standCash += tonumber(stand:GetAttribute("Stored")) or 0 end
		end
		local ch = plot:FindFirstChild("Chambers")
		if ch then for _, m in ch:GetChildren() do local i = m:GetAttribute("ChamberIndex") if i then chambers[i] = m:GetAttribute("UpgradeLevel") or 1 end end end
		d.templeLevel = plot:GetAttribute("TempleLevel") or d.templeLevel or 1
	end
	if cash then d.cash = math.max(0, math.floor(cash.Value + standCash)) end
	if not r.all then -- items / plot not fully restored yet: only cash + flags are safe to update
		if isFinal then final[p] = true end
		return
	end
	for _, rec in carry[p] or {} do table.insert(tools, rec) end
	d.tools, d.placed = tools, placed
	d.tutorialCompleted = p:GetAttribute("TutorialCompleted") == true
	d.tutorialIncomeCollected = p:GetAttribute("TutorialIncomeCollected") == true
	d.tutorialTourStage = p:GetAttribute("TutorialTourStage") or 9
	if plot and #unlocked > 0 then d.unlocked = unlocked local list = {} for i = 1, 3 do if chambers[i] then table.insert(list, chambers[i]) end end if #list > 0 then d.chambers = list end end
	if Adapter and Adapter.ExportDiscovered then d.discovered = Adapter.ExportDiscovered(p) end
	if isFinal then final[p] = true end
end

------------------------------------------------------------ store
local function save(p, releaseLock)
	local d = data[p]
	if not store or not d or not loaded[p] then return end
	d.v = VERSION
	d.savedAt = os.time()
	d.lock = (not releaseLock) and { job = game.JobId, t = os.time() } or nil
	for attempt = 1, 3 do
		local blocked = false
		local ok, err = pcall(store.UpdateAsync, store, "u" .. p.UserId, function(old)
			if old and old.lock and old.lock.job ~= game.JobId and os.time() - (old.lock.t or 0) < LOCK_TIMEOUT then blocked = true return nil end -- another server owns it
			return d
		end)
		if ok and not blocked then p:SetAttribute("TempleSaveStatus", "Saved") return true end
		if blocked then warn("[PlayerData] save skipped: another server holds the lock", p.Name) return false end
		warn("[PlayerData] save failed", p.Name, err) task.wait(1 + attempt)
	end
end

local function load(p)
	if not store then return nil, "nostore" end
	local key = "u" .. p.UserId
	for attempt = 1, 8 do
		local result, lockedElsewhere
		local ok, err = pcall(store.UpdateAsync, store, key, function(old)
			old = old or { v = VERSION }
			if old.lock and old.lock.job ~= game.JobId and os.time() - (old.lock.t or 0) < LOCK_TIMEOUT and attempt < 8 then lockedElsewhere = true return nil end
			old.lock = { job = game.JobId, t = os.time() }
			result = old
			return old
		end)
		if ok and result then return result end
		if not ok then warn("[PlayerData] load error", p.Name, err) if tostring(err):find("StudioAccessToApisNotAllowed") or tostring(err):find("Studio access") then return nil, "studio" end end
		if not p.Parent then return nil, "left" end
		task.wait(lockedElsewhere and 2 or (1 + attempt))
	end
	return nil, "failed"
end

------------------------------------------------------------ apply saved state
local function waitFor(fn, timeout) local t = os.clock() repeat local v = fn() if v then return v end task.wait(0.25) until os.clock() - t > (timeout or 20) end

local function apply(p, d)
	-- wait for the character: Roblox resets the Backpack when the first character spawns, wiping anything given earlier
	local char = p.Character or waitFor(function() return p.Character end, 40)
	if not char or not p.Parent then return end
	waitFor(function() return char:FindFirstChild("HumanoidRootPart") end, 15)
	task.wait(1)
	local offline = math.clamp(os.time() - (tonumber(d.savedAt) or os.time()), 0, 28800) -- up to 8 h counts (economy v4)
	local cash = waitFor(function() return cashOf(p) end, 20)
	if cash and d.cash then cash.Value = d.cash end
	restored[p] = { cash = cash ~= nil, all = false }
	local bag = waitFor(function() return p:FindFirstChildOfClass("Backpack") end, 20)
	local incubating = {}
	for _, rec in d.tools or {} do
		if rec.inc then table.insert(incubating, rec)
		else local t = build(rec, p) if t and bag then t.Parent = bag end end
	end
	local plot = waitFor(function() return plotOf(p) end, 40)
	if not plot then warn("[PlayerData] no plot for", p.Name, "- keeping saved temple/characters untouched") return end
	for _, name in d.unlocked or {} do local s = plot.Slots:FindFirstChild(name) if s then s:SetAttribute("Unlocked", true) end end
	pcall(SlotUnlocks.Refresh, plot)
	local placedSlots = {}
	for _, rec in d.placed or {} do
		local tool = build(rec, p)
		if tool and bag then
			tool.Parent = bag
			local slot = plot.Slots:FindFirstChild(rec.s)
			local inv = slot and slot:FindFirstChild("Platform") and slot.Platform:FindFirstChild("InvokePlaceCharacter")
			if inv and slot:GetAttribute("Unlocked") and not slot:GetAttribute("Occupied") then
				local ok, placed = pcall(inv.Invoke, inv, p, tool)
				if ok and placed then table.insert(placedSlots, slot) end
			end
		end
	end
	pcall(SlotUnlocks.Refresh, plot)
	-- offline earnings land on the money stands
	if offline > 5 and #placedSlots > 0 then
		task.wait(1.5)
		local total = 0
		for _, slot in placedSlots do
			local stand = slot:FindFirstChild("MoneyStand")
			local rate = stand and tonumber(stand:GetAttribute("IncomePerSecond")) or 0
			if stand and rate > 0 then local add = math.floor(rate * offline * 0.5) --[[ offline earns half ]] stand:SetAttribute("Stored", (stand:GetAttribute("Stored") or 0) + add) total += add end
		end
		if total > 0 then p:SetAttribute("OfflineEarnings", total) p:SetAttribute("OfflineSeconds", offline) end
	end
	-- eggs go back into their incubator with the time they had left, minus the time you were away
	for _, rec in incubating do
		local tool = build(rec, p)
		if tool then
			tool:SetAttribute("Incubating", nil)
			local chamber = waitFor(function()
				local ch = plot:FindFirstChild("Chambers") local m = ch and ch:FindFirstChild("Chamber" .. (rec.inc.c or 1))
				return m and not m:GetAttribute("UnderConstruction") and m:FindFirstChild("ResumeEgg") and m
			end, 25)
			local ok = false
			if chamber and plotOf(p) == plot then
				tool.Parent = bag
				local s2, r2 = pcall(chamber.ResumeEgg.Invoke, chamber.ResumeEgg, p, tool, math.max(0, (rec.inc.left or 0) - offline))
				ok = s2 and r2 == true
				if ok then task.wait(1) end
			end
			if not ok and bag then tool.Parent = bag end
		end
	end
end

local function applyAll(p, d)
	local ok, err = pcall(apply, p, d)
	if not ok then warn("[PlayerData] restore error", p.Name, err) return end
	local plot = plotOf(p)
	if p.Parent and plot and restored[p] then restored[p].all = true end
end

local function onJoin(p)
	data[p] = { v = VERSION }
	local jd = p:GetJoinData() local td = jd and jd.TeleportData
	if type(td) == "table" and td.SoftShutdown == true then -- /update waiting server: just passing through, never touch the save
		p:SetAttribute("DataLoaded", true) p:SetAttribute("TempleSaveStatus", "Updating…") return
	end
	local d, why = load(p)
	if not p.Parent then return end
	if d then
		data[p] = d loaded[p] = true
		p:SetAttribute("TutorialCompleted", d.tutorialCompleted == true)
		p:SetAttribute("TutorialIncomeCollected", d.tutorialIncomeCollected == true or d.tutorialCompleted == true)
		p:SetAttribute("TutorialTourStage", math.clamp(tonumber(d.tutorialTourStage) or 9, 9, 12))
		for k, v in d.settings or {} do p:SetAttribute(k, v) end
		p:SetAttribute("SavedTempleLevel", d.templeLevel or 1)
		if d.chambers then p:SetAttribute("SavedChambers", table.concat(d.chambers, ",")) end
		if Adapter and Adapter.ImportDiscovered and d.discovered then pcall(Adapter.ImportDiscovered, p, d.discovered) end
		p:SetAttribute("DataLoaded", true)
		p:SetAttribute("TempleSaveStatus", "Saved")
		task.spawn(function()
			applyAll(p, d)
			if p.Parent then p:SetAttribute("TutorialDataReady", true) end
		end)
	elseif why == "studio" or why == "nostore" then
		p:SetAttribute("DataLoaded", true) p:SetAttribute("TempleSaveStatus", "Session only (Studio)")
		p:SetAttribute("TutorialCompleted", false)
		p:SetAttribute("TutorialIncomeCollected", false)
		p:SetAttribute("TutorialTourStage", 9)
		p:SetAttribute("TutorialDataReady", true)
	elseif why ~= "left" then
		p:Kick("We couldn't load your save right now, so nothing was changed. Please rejoin in a minute.")
	end
end

local function onLeave(p)
	if loaded[p] then
		if not final[p] then snapshot(p, true) end
		save(p, true)
	end
	data[p], loaded[p], final[p], lastHeld[p], lastSet[p], restored[p], carry[p] = nil, nil, nil, nil, nil, nil, nil
end

------------------------------------------------------------ studio debug hook
if RunService:IsStudio() then
	local dbg = ServerStorage:FindFirstChild("PlayerDataDebug") or Instance.new("BindableFunction") dbg.Name = "PlayerDataDebug" dbg.Parent = ServerStorage
	dbg.OnInvoke = function(action, p, extra)
		if action == "dump" then snapshot(p, false) return game:GetService("HttpService"):JSONEncode(data[p]) end
		if action == "rejoin" then -- snapshot, wipe live state like a leave, then restore like a rejoin (extra = seconds away)
			snapshot(p, true) final[p] = nil
			local d = data[p] d.savedAt = os.time() - (tonumber(extra) or 0)
			for _, c in { p:FindFirstChildOfClass("Backpack"), p.Character, p:FindFirstChild("IncubatorHeldEggs") } do if c then for _, t in c:GetChildren() do if serializeTool(t) then t:Destroy() end end end end
			local plot = plotOf(p)
			if plot then plot.PlacedItems:ClearAllChildren() for _, sl in plot.Slots:GetChildren() do sl:SetAttribute("Occupied", false) sl:SetAttribute("Unlocked", nil) end
				plot:SetAttribute("OwnerUserId", 0) task.wait(1) plot:SetAttribute("OwnerUserId", p.UserId) task.wait(1)
				for _, sl in plot.Slots:GetChildren() do if sl.Name == "Slot01" then sl:SetAttribute("Unlocked", true) end end end
			local cash = cashOf(p) if cash then cash.Value = 0 end
			applyAll(p, d) return "restored"
		end
	end
end
------------------------------------------------------------ settings (volume + toggles)
local SETTINGS = { MusicVolume = "number", SFXVolume = "number", SFXMuted = "boolean", ReducedMotion = "boolean", NightFX = "boolean", HideLabels = "boolean" }
local setRemote = RS:FindFirstChild("SaveSettings") or Instance.new("RemoteEvent") setRemote.Name = "SaveSettings" setRemote.Parent = RS
setRemote.OnServerEvent:Connect(function(p, t)
	if type(t) ~= "table" or not data[p] or os.clock() - (lastSet[p] or 0) < 0.5 then return end
	lastSet[p] = os.clock()
	local clean = {}
	for k, ty in SETTINGS do local v = t[k] if typeof(v) == ty then if ty == "number" then v = math.clamp(v, 0, 1) if v ~= v then v = 1 end end clean[k] = v p:SetAttribute(k, v) end end
	data[p].settings = clean
end)
------------------------------------------------------------ wiring
local saveAll = ServerStorage:FindFirstChild("PlayerDataSaveAll") or Instance.new("BindableFunction")
saveAll.Name = "PlayerDataSaveAll" saveAll.Parent = ServerStorage
saveAll.OnInvoke = function() -- save + release every player (used by /update before teleporting)
	local n = 0
	for _, p in Players:GetPlayers() do if loaded[p] then n += 1 task.spawn(function() pcall(snapshot, p, true) pcall(save, p, true) loaded[p] = nil n -= 1 end) end end
	local t = os.clock() while n > 0 and os.clock() - t < 20 do task.wait(0.2) end
	return n == 0
end
local saveNow = ServerStorage:FindFirstChild("PlayerDataSaveNow") or Instance.new("BindableFunction")
saveNow.Name = "PlayerDataSaveNow" saveNow.Parent = ServerStorage
saveNow.OnInvoke = function(p) -- returns true only once the player's items are restored AND the save landed
	if not loaded[p] or not (restored[p] and restored[p].all) then return false end
	pcall(snapshot, p, false)
	return save(p, false) == true
end
local snapFn = ServerStorage:FindFirstChild("PlayerDataSnapshot") or Instance.new("BindableFunction")
snapFn.Name = "PlayerDataSnapshot" snapFn.Parent = ServerStorage
snapFn.OnInvoke = function(p) pcall(snapshot, p, true) return true end

if Quests and Quests.Persistence then
	Quests.Persistence.Load = function(p) waitFor(function() return p:GetAttribute("DataLoaded") or not p.Parent end, 30) return data[p] and data[p].quests or nil end
	Quests.Persistence.Save = function(p, tbl) if data[p] then data[p].quests = tbl end end
end

local function watchChar(p)
	p.CharacterRemoving:Connect(function(c)
		local list = {} for _, t in c:GetChildren() do local r = serializeTool(t) if r then table.insert(list, r) end end
		lastHeld[p] = list
	end)
end
Players.PlayerAdded:Connect(function(p) watchChar(p) onJoin(p) end)
for _, p in Players:GetPlayers() do task.spawn(function() watchChar(p) onJoin(p) end) end
Players.PlayerRemoving:Connect(onLeave)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE)
		for _, p in Players:GetPlayers() do if loaded[p] and not final[p] then pcall(snapshot, p, false) task.spawn(save, p, false) end end
	end
end)

game:BindToClose(function()
	if not store then return end
	local n = 0
	for _, p in Players:GetPlayers() do if loaded[p] then n += 1 task.spawn(function() if not final[p] then pcall(snapshot, p, true) end save(p, true) n -= 1 end) end end
	local t = os.clock() while n > 0 and os.clock() - t < 25 do task.wait(0.2) end
end)
