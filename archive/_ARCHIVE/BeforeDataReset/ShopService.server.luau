--[[ ServerScriptService.ShopService
Shop + Daily Rewards (server-authoritative).
  • Player attributes it maintains: CashMultiplier, HatchMultiplier, VIP, Money2xUntil, Hatch2xUntil, MoneyLevel
    (BrainrotPlacement multiplies stand income by CashMultiplier; HatchGoo multiplies hatch speed by HatchMultiplier.)
  • RemoteFunction ReplicatedStorage.ShopSystem.ShopRemote: "State" | "ClaimDaily" | "BuyMoneyLevel" | "Buy"(key)
  • The game's only ProcessReceipt lives here.
  • Saves (DataStore ShopData_v1): money level, daily streak, boost end times. Fails safely in Studio.
]]
local Players = game:GetService("Players")
local MPS = game:GetService("MarketplaceService")
local DSS = game:GetService("DataStoreService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.ShopSystem.ShopConfig)

local remote = RS.ShopSystem:FindFirstChild("ShopRemote") or Instance.new("RemoteFunction")
remote.Name = "ShopRemote"; remote.Parent = RS.ShopSystem
local store do local ok, s = pcall(DSS.GetDataStore, DSS, "ShopData_v1"); store = ok and s or nil end

local data, busy, owns = {}, {}, {}
local DAY = 86400

local function cashOf(p) local ls = p:FindFirstChild("leaderstats"); return ls and ls:FindFirstChild("Cash") end
local function now() return os.time() end

local function save(p)
	local d = data[p]; if not d or not store then return end
	pcall(store.SetAsync, store, "u" .. p.UserId, d)
end

local function ownsPass(p, key)
	local id = Config.GamePasses[key]
	if not id or id == 0 then return owns[p] and owns[p][key] == true end
	owns[p] = owns[p] or {}
	if owns[p][key] == nil then
		local ok, r = pcall(MPS.UserOwnsGamePassAsync, MPS, p.UserId, id)
		owns[p][key] = ok and r or false
	end
	return owns[p][key]
end

-- recompute multipliers from level + active boosts + VIP
local function refresh(p)
	local d = data[p]; if not d then return end
	local lvl = Config.MoneyLevels[d.moneyLevel or 0]
	local vip = ownsPass(p, "VIP")
	local t = now()
	local cash = (lvl and lvl.mult or 1) * ((d.money2xUntil or 0) > t and 2 or 1) * (vip and Config.VIPCashBonus or 1)
	p:SetAttribute("CashMultiplier", cash)
	p:SetAttribute("HatchMultiplier", (d.hatch2xUntil or 0) > t and 2 or 1)
	p:SetAttribute("MoneyLevel", d.moneyLevel or 0)
	p:SetAttribute("Money2xUntil", d.money2xUntil or 0)
	p:SetAttribute("Hatch2xUntil", d.hatch2xUntil or 0)
	p:SetAttribute("VIP", vip)
end

local function addBoost(p, which, minutes)
	local d = data[p]; if not d then return end
	local key = which == "Money2x" and "money2xUntil" or "hatch2xUntil"
	d[key] = math.max(d[key] or 0, now()) + minutes * 60
	refresh(p)
end
local function addCash(p, n) local c = cashOf(p); if c then c.Value += n; return true end end

---------------------------------------------------------------- VIP perks: crown over head
local CROWN = "rbxassetid://95157813840098"
local function crown(p)
	local char = p.Character; local head = char and char:FindFirstChild("Head")
	if not head then return end
	local old = head:FindFirstChild("VIPCrown"); if old then old:Destroy() end
	if not p:GetAttribute("VIP") then return end
	local bb = Instance.new("BillboardGui")
	bb.Name = "VIPCrown"; bb.Size = UDim2.fromScale(2.2, 2.2); bb.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0); bb.LightInfluence = 0; bb.MaxDistance = 120
	local img = Instance.new("ImageLabel"); img.Size = UDim2.fromScale(1, 1); img.BackgroundTransparency = 1; img.Image = CROWN; img.Parent = bb
	bb.Parent = head
end

---------------------------------------------------------------- daily rewards
local function dailyState(p)
	local d = data[p]; local t = now()
	local last = d.dailyAt or 0
	local streak = d.streak or 0
	if last > 0 and t - last > 2 * DAY then streak = 0 end -- missed a day
	local ready = t - last >= DAY
	local day = ready and (streak % 7) + 1 or ((streak - 1) % 7) + 1
	return { day = day, ready = ready, nextIn = ready and 0 or (last + DAY - t), streak = streak }
end

local function claimDaily(p)
	local d = data[p]; local st = dailyState(p)
	if not st.ready then return false, "Come back later" end
	local r = Config.Daily[st.day]
	local vip = p:GetAttribute("VIP")
	if r.kind == "cash" then addCash(p, r.amount * (vip and 2 or 1))
	elseif r.kind == "boost" then addBoost(p, r.boost, r.minutes)
	elseif r.kind == "mystery" then addCash(p, r.amount * (vip and 2 or 1)); addBoost(p, "Money2x", r.minutes); addBoost(p, "Hatch2x", r.minutes) end
	d.streak = (st.streak % 7) + 1
	d.dailyAt = now()
	save(p)
	return true, "Claimed day " .. st.day .. "!"
end

---------------------------------------------------------------- remote
remote.OnServerInvoke = function(p, action, key)
	if not data[p] then return false, "Loading…" end
	if busy[p] then return false, "One moment…" end
	busy[p] = true
	local ok, a, b = pcall(function()
		if action == "State" then
			local d = data[p]
			return true, { daily = dailyState(p), moneyLevel = d.moneyLevel or 0, money2xUntil = d.money2xUntil or 0, hatch2xUntil = d.hatch2xUntil or 0,
				vip = p:GetAttribute("VIP") == true, starter = ownsPass(p, "StarterPack"), serverTime = now() }
		elseif action == "ClaimDaily" then return claimDaily(p)
		elseif action == "BuyMoneyLevel" then
			local d = data[p]; local lv = Config.MoneyLevels[(d.moneyLevel or 0) + 1]
			if not lv then return false, "Maxed out!" end
			if (lv.productId or 0) == 0 then return false, "Coming soon" end
			MPS:PromptProductPurchase(p, lv.productId); return true
		elseif action == "Buy" and type(key) == "string" then
			if Config.GamePasses[key] ~= nil then
				local id = Config.GamePasses[key]; if id == 0 then return false, "Coming soon" end
				if ownsPass(p, key) then return false, "You already own this" end
				MPS:PromptGamePassPurchase(p, id); return true
			elseif Config.Products[key] ~= nil then
				local id = Config.Products[key]; if id == 0 then return false, "Coming soon" end
				MPS:PromptProductPurchase(p, id); return true
			end
		end
		return false, "Unknown"
	end)
	busy[p] = nil
	if not ok then warn("[Shop] " .. tostring(a)); return false, "Server error" end
	return a, b
end

---------------------------------------------------------------- purchases
-- Unknown Egg: a mystery egg that always hatches a Rare or better character (rolled at purchase).
local UNKNOWN_ODDS = { { "Rare", 70 }, { "Epic", 25 }, { "Legendary", 5 } }
local function giveUnknownEgg(p)
	local Catalog = require(RS.CharacterCatalog)
	local roll, pick = math.random() * 100, "Rare"
	for _, e in UNKNOWN_ODDS do roll -= e[2]; if roll <= 0 then pick = e[1]; break end end
	local pool = {}
	for id, entry in Catalog.ById do if entry.Rarity == pick then table.insert(pool, entry) end end
	if #pool == 0 then for _, entry in Catalog.ById do table.insert(pool, entry) end end
	local entry = Catalog.ById.Unknown or pool[math.random(1, #pool)]
	local bag = p:FindFirstChildOfClass("Backpack"); if not bag then return false end
	local tool = Instance.new("Tool"); tool.Name = "Unknown Egg"; tool.CanBeDropped = false
	Catalog.Stamp(tool, entry)
	tool:SetAttribute("EggType", entry.Id); tool:SetAttribute("UnknownEgg", true)
	tool.ToolTip = "LIMITED • Hatches the Unknown character"
	local template = RS.ShopSystem.ShopModels:FindFirstChild("UnknownEgg")
	local handle = Instance.new("Part"); handle.Name = "Handle"; handle.Size = Vector3.one; handle.Transparency = 1
	handle.CanCollide = false; handle.Massless = true; handle.Parent = tool
	if template then
		local visual = template:Clone(); visual.Name = "Egg"
		local _, size = visual:GetBoundingBox(); visual:ScaleTo(visual:GetScale() * 2.2 / math.max(size.Y, 0.01))
		visual:PivotTo(CFrame.new())
		for _, d in visual:GetDescendants() do
			if d:IsA("BasePart") then d.Anchored = false; d.CanCollide = false; d.CanTouch = false; d.Massless = true
				local w = Instance.new("WeldConstraint"); w.Part0 = handle; w.Part1 = d; w.Parent = handle
			elseif d:IsA("BaseScript") then d:Destroy() end
		end
		visual.Parent = tool
	end
	tool.Parent = bag
	return true
end
if game:GetService("RunService"):IsStudio() then local bf = Instance.new("BindableFunction"); bf.Name = "StudioGiveUnknownEgg"; bf.OnInvoke = giveUnknownEgg; bf.Parent = script end

local function grantPass(p, key)
	owns[p] = owns[p] or {}; owns[p][key] = true
	local d = data[p]
	if key == "StarterPack" and d and not d.starterGranted then
		d.starterGranted = true
		addCash(p, Config.StarterPack.cash); addBoost(p, "Money2x", Config.StarterPack.boostMinutes); addBoost(p, "Hatch2x", Config.StarterPack.boostMinutes)
		save(p)
	end
	refresh(p); crown(p)
end
MPS.PromptGamePassPurchaseFinished:Connect(function(p, id, bought)
	if not bought then return end
	for key, pid in Config.GamePasses do if pid == id then grantPass(p, key) end end
end)

MPS.ProcessReceipt = function(info)
	local p = Players:GetPlayerByUserId(info.PlayerId)
	if not p or not data[p] then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local d = data[p]
	d.receipts = d.receipts or {}
	if d.receipts[info.PurchaseId] then return Enum.ProductPurchaseDecision.PurchaseGranted end
	local key; for k, id in Config.Products do if id == info.ProductId then key = k end end
	local level; for i, lv in Config.MoneyLevels do if lv.productId ~= 0 and lv.productId == info.ProductId then level = i end end
	if level then key = "MoneyLevel" end
	if not key then return Enum.ProductPurchaseDecision.NotProcessedYet end
	if key == "MoneyLevel" then d.moneyLevel = math.max(d.moneyLevel or 0, level); refresh(p)
	elseif key == "Money2x" or key == "Hatch2x" then addBoost(p, key, Config.BoostMinutes)
	elseif key == "UnknownEgg" then if not giveUnknownEgg(p) then return Enum.ProductPurchaseDecision.NotProcessedYet end
	elseif Config.CashPacks[key] then addCash(p, Config.CashPacks[key]) end
	d.receipts[info.PurchaseId] = true
	-- keep the receipt list small
	local n = 0; for _ in d.receipts do n += 1 end
	if n > 50 then d.receipts = { [info.PurchaseId] = true } end
	save(p)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

---------------------------------------------------------------- players
local function onPlayer(p)
	local d
	if store then local ok, r = pcall(store.GetAsync, store, "u" .. p.UserId); if ok and type(r) == "table" then d = r end end
	data[p] = d or { moneyLevel = 0, streak = 0, dailyAt = 0 }
	if ownsPass(p, "StarterPack") then grantPass(p, "StarterPack") end
	refresh(p)
	p.CharacterAdded:Connect(function() task.wait(1); crown(p) end)
	if p.Character then crown(p) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do task.spawn(onPlayer, p) end
Players.PlayerRemoving:Connect(function(p) save(p); data[p] = nil; busy[p] = nil; owns[p] = nil end)
game:BindToClose(function() for _, p in Players:GetPlayers() do save(p) end end)

-- boosts expire on their own
task.spawn(function() while true do task.wait(5); for p in data do refresh(p) end end end)
