--[[ ServerScriptService.GameMenu.GameMenuServer  (Script, server)
Remotes: ReplicatedStorage.GameMenu.Remotes.{ GetState (RF), Action (RF), Changed (RE) }
Connect HOOKS to your existing catalog / CharacterEconomy / inventory / plot / placement code.
Unconnected hooks return a clear "not connected" message; nothing pretends to work.
]]
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local root = RS:WaitForChild("GameMenu")
local Config = require(root:WaitForChild("Config"))
local Quests = require(script.Parent:WaitForChild("QuestService"))

local remotes = root:FindFirstChild("Remotes") or Instance.new("Folder"); remotes.Name = "Remotes"; remotes.Parent = root
local function remote(class, name) local r = remotes:FindFirstChild(name) or Instance.new(class); r.Name = name; r.Parent = remotes; return r end
local GetState, Action, Changed = remote("RemoteFunction", "GetState"), remote("RemoteFunction", "Action"), remote("RemoteEvent", "Changed")

local HOOKS=require(script.Parent:WaitForChild("GameAdapter"))
HOOKS.OwnsGamePass=function(player,id)local ok,r=pcall(MarketplaceService.UserOwnsGamePassAsync,MarketplaceService,player.UserId,id);return ok and r end

local busy = {}
local requestAt={}
local readAt={}
local function push(p) if p and p.Parent==Players then Changed:FireClient(p) end end
task.spawn(HOOKS.Init,push)
Quests.Changed.Event:Connect(push)

local function plotOrErr(p) local plot, err = HOOKS.GetPlot(p); return plot, err end

GetState.OnServerInvoke = function(p, section)
	local now=os.clock();if now-(readAt[p] or -100)<.005 then return {error="Please wait a moment."} end;readAt[p]=now
	if section == "index" then
		local cat, err = HOOKS.GetCatalog(p); if not cat then return { error = err } end
		local disc = HOOKS.GetDiscovered(p) or {}
		local owned = {}
		local plot = HOOKS.GetPlot(p)
		if plot and plot.items then for _, it in plot.items do owned[it.id] = (owned[it.id] or 0) + 1 end end
		for id,n in HOOKS.GetOwnedEggs(p) do owned[id]=n end
		return { catalog = cat, discovered = disc, owned = owned }
	elseif section == "plot" then
		local plot, err = plotOrErr(p); if not plot then return { error = err } end
		return plot
	elseif section == "quests" then
		return Quests.Snapshot(p)
	elseif section == "shop" then
		local out = {}
		for _, e in Config.Shop do
			local available = (e.kind == "cash" and e.price ~= nil) or (e.kind == "robux" and (e.productId or e.gamePassId) ~= nil)
			local item = table.clone(e); item.available = available
            if e.grant and e.grant.egg then item.model="MenuEgg_"..e.grant.egg end
			if e.gamePassId then item.owned = HOOKS.OwnsGamePass(p, e.gamePassId) end
			table.insert(out, item)
		end
		return { items = out, tabs = Config.ShopTabs, serverTime = os.time() }
	end
	return { error = "Unknown section" }
end

local ACT = {}
ACT.EquipBest = function(p) return HOOKS.EquipBest(p) end
ACT.UnequipAll = function(p)
	local plot, err = plotOrErr(p); if not plot then return false, err end
	local uids = {}; for _, it in plot.items do if it.state == "placed" then table.insert(uids, it.uid) end end
	if #uids == 0 then return false, "Nothing is placed" end
	local n, e = HOOKS.StoreCharacters(p, uids); if n == nil then return false, e end
	return true, ("%d back in inventory"):format(n)
end
local function uidList(a) local t = {}; if type(a.uids) == "table" then for i, u in a.uids do if i > 60 then break end if type(u) == "string" then table.insert(t, u) end end end return t end
ACT.PlaceSelected = function(p, a)
	local plot, err = plotOrErr(p); if not plot then return false, err end
	if not plot.plotOwned then return false, "You don't have a plot yet" end
	local used = 0; for _, it in plot.items do if it.state == "placed" then used += 1 end end
	if used >= plot.unlocked then return false, "No free stands" end
	local n, e = HOOKS.PlaceCharacters(p, uidList(a)); if n == nil then return false, e end
	return true, "Placed " .. n
end
ACT.StoreSelected = function(p, a) local n, e = HOOKS.StoreCharacters(p, uidList(a)); if n == nil then return false, e end return true, "Stored " .. n end
ACT.Claim = function(p, a) return Quests.Claim(p, tostring(a.id), function(pl, rw) return HOOKS.GrantReward(pl, rw) == true end) end
ACT.ClaimAll = function(p)
	local n = 0
	for _, q in Quests.Snapshot(p).list do if q.progress >= q.target and not q.claimed then if Quests.Claim(p, q.id, function(pl, rw) return HOOKS.GrantReward(pl, rw) == true end) then n += 1 end end end
	return n > 0, n > 0 and ("Claimed %d rewards"):format(n) or "Nothing to claim"
end
ACT.UpgradeTemple = function(p)
	local plot
	for _, pl in workspace.Plots:GetChildren() do if pl:GetAttribute("OwnerUserId") == p.UserId then plot = pl end end
	if not plot then return false, "You don't have a plot yet" end
	local before = plot:GetAttribute("TempleLevel") or 1
	if before >= 3 then return false, "Temple is fully upgraded" end
	if plot:GetAttribute("TempleBuilding") then return false, "Upgrade already in progress" end
	local req = plot:FindFirstChild("RequestUpgrade"); if not req then return false, "Upgrade unavailable" end
	req:Fire(p) -- PlotManager checks ownership + distance
	task.wait(0.4)
	if plot:GetAttribute("TempleBuilding") or (plot:GetAttribute("TempleLevel") or 1) > before then return true, "Upgrading temple!" end
	return false, "Go to your plot to upgrade"
end
ACT.UpgradeIncubator = function(p, a)
	local plot
	for _, pl in workspace.Plots:GetChildren() do if pl:GetAttribute("OwnerUserId") == p.UserId then plot = pl end end
	if not plot then return false, "You don't have a plot yet" end
	local i = tonumber(a.index)
	local c = i and plot.Chambers:FindFirstChild("Chamber" .. math.floor(i))
	if not c then return false, "No incubator there" end
	local lv = c:GetAttribute("UpgradeLevel") or 1
	if lv >= 3 then return false, "Incubator is max level" end
	if (c:GetAttribute("Status") or "Ready") ~= "Ready" then return false, "Wait until the incubator is empty" end
	local req = c:FindFirstChild("RequestIncubatorUpgrade"); if not req then return false, "Upgrade unavailable" end
	req:Fire(p) -- PlotChambers checks ownership + distance
	task.wait(0.4)
	local now = plot.Chambers:FindFirstChild(c.Name)
	if (now and now:GetAttribute("UnderConstruction")) or now ~= c then return true, "Upgrading incubator " .. i .. "!" end
	return false, "Go to your plot to upgrade"
end
ACT.AddIncubator = function(p)
	local plot
	for _, pl in workspace.Plots:GetChildren() do if pl:GetAttribute("OwnerUserId") == p.UserId then plot = pl end end
	if not plot then return false, "You don't have a plot yet" end
	local before = #plot.Chambers:GetChildren()
	if before >= 3 then return false, "You have all 3 incubators" end
	local req = plot:FindFirstChild("RequestChamberUpgrade"); if not req then return false, "Unavailable" end
	req:Fire(p)
	task.wait(0.4)
	if plot:GetAttribute("ChamberCount") ~= before or #plot.Chambers:GetChildren() > before then return true, "Building a new incubator!" end
	return false, "Go to your plot to add one"
end
ACT.UnlockSlot = function(p)
	local plot
	for _, pl in workspace.Plots:GetChildren() do if pl:GetAttribute("OwnerUserId") == p.UserId then plot = pl end end
	if not plot then return false, "You don't have a plot yet" end
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - plot.TempleAnchor.Position).Magnitude > 80 then return false, "Go to your plot to unlock" end
	local Slots = require(game.ServerScriptService.TempleSlotUnlocks)
	-- next locked slot in order
	local nextSlot, i
	for n = 1, 12 do
		local s = plot.Slots:FindFirstChild(string.format("Slot%02d", n))
		if s and not s:GetAttribute("Unlocked") then nextSlot, i = s, n break end
	end
	if not nextSlot then return false, "All slots unlocked!" end
	local cash = p:FindFirstChild("leaderstats") and p.leaderstats:FindFirstChild("Cash")
	local price = Slots.Prices[i] or 250000
	if not cash or cash.Value < price then return false, "Not enough cash" end
	cash.Value -= price
	nextSlot:SetAttribute("Unlocked", true)
	Slots.Refresh(plot)
	return true, "Slot " .. i .. " unlocked!"
end
ACT.Buy = function(p, a)
	local e; for _, x in Config.Shop do if x.id == a.id then e = x end end
	if not e then return false, "Unknown item" end
	if e.endsAt and os.time() > e.endsAt then return false, "This item has ended" end
	if e.kind == "cash" then
		return HOOKS.BuyCash(p,e)
		--[[ Legacy spend-then-grant path replaced with atomic prepared delivery.
		local ok, why = HOOKS.SpendCash(p, e.price); if not ok then return false, why or "Not enough cash" end
		local g, gwhy = HOOKS.GrantShopItem(p, e)
		if not g then warn("[GameMenu] grant failed after spend; refund in your SpendCash/Grant code:", gwhy); return false, gwhy end
		return true, "Bought " .. e.name ]]
	elseif e.productId then MarketplaceService:PromptProductPurchase(p, e.productId); return true, "Opening purchase"
	elseif e.gamePassId then MarketplaceService:PromptGamePassPurchase(p, e.gamePassId); return true, "Opening purchase" end
	return false, "Coming soon"
end

Action.OnServerInvoke = function(p, name, args)
	if type(name) ~= "string" or not ACT[name] then return false, "Unknown action" end
	if busy[p] or os.clock()-(requestAt[p] or -100)<.2 then return false, "Please wait a moment." end
 requestAt[p]=os.clock()
	busy[p] = true
	local ok, res, msg = pcall(ACT[name], p, type(args) == "table" and args or {})
	busy[p] = nil
	if not ok then warn("[GameMenu]", name, res); return false, "Server error" end
	if res then push(p) end
	return res, msg
end
Players.PlayerRemoving:Connect(function(p) busy[p] = nil;requestAt[p]=nil;readAt[p]=nil end)

--[[ Robux receipts: Roblox allows ONE ProcessReceipt per game. If you already have one, add a branch there that calls
     HOOKS.GrantShopItem(player, entry) for entries whose productId matches, and return PurchaseGranted only after it succeeds. ]]
