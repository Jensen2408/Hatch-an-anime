local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("HatchFX"):WaitForChild("HatchFXConfig"))

local TAG = "Hatching"
local Service = {}
local active = {} -- [incubator] = job

-- Adapter: connect your glass doors here. Default tries the IncubatorController module from earlier.
local Controller
pcall(function() Controller = require(ServerScriptService:FindFirstChild("IncubatorController", true) or game.ReplicatedStorage:FindFirstChild("IncubatorController", true)) end)
local controllers = setmetatable({}, { __mode = "k" })
local function ctl(inc)
	if not Controller then return nil end
	controllers[inc] = controllers[inc] or Controller.new(inc)
	return controllers[inc]
end
Service.Hooks = {
	CloseGlass = function(inc) local c = ctl(inc); if c then task.spawn(c.Close, c, 0.5) end end,
	OpenGlass = function(inc) local c = ctl(inc); if c then task.spawn(c.Open, c, 0.7) end end,
	-- where the character stands: platform top, facing the walkway (incubator front = LookVector)
	DisplayCFrame = function(inc, character)
		local anchor = inc:FindFirstChild("EggAnchor", true)
		local base = anchor and (anchor:IsA("BasePart") and anchor.CFrame or anchor:GetPivot()) or inc:GetPivot()
		local _, size = character:GetBoundingBox()
		local face = inc:GetPivot().Rotation
		return CFrame.new(base.Position) * face * CFrame.new(0, size.Y / 2, 0)
	end,
}

local function lock(model, store)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			store[p] = { p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery }
			p.Anchored, p.CanCollide, p.CanTouch = true, false, false; p.CanQuery = true -- enable surface raycasts
		end
	end
end
local function unlock(store) for p, v in store do if p.Parent then p.Anchored, p.CanCollide, p.CanTouch = v[1], v[2], v[3]; p.CanQuery = v[4] end end end

local function clearAttrs(inc)
	for _, n in { "HatchToken", "HatchStart", "HatchRarity", "HatchRoll", "HatchPower", "HatchIncome", "HatchName", "HatchOwner" } do inc:SetAttribute(n, nil) end
	for _, n in { "HatchEgg", "HatchCharacter" } do local v = inc:FindFirstChild(n); if v then v:Destroy() end end
	CollectionService:RemoveTag(inc, TAG)
end

local function finish(job, cancelled)
	if job.done then return end
	job.done = true
	if job.ancestry then job.ancestry:Disconnect() end
	for _, th in job.threads do if th ~= coroutine.running() then pcall(task.cancel, th) end end
	local ch = job.o.character
	if ch and not ch.Parent then ch.Parent = job.o.characterParent or job.o.incubator end -- reward always ends up in the world
	if ch and ch.Parent then ch:PivotTo(job.display) end
	if job.o.egg and job.o.egg.Parent then job.o.egg:Destroy() end
	unlock(job.locks)
	if job.o.incubator.Parent then
		job.o.incubator:SetAttribute("HatchToken", "")
		if job.o.openGlass then job.o.openGlass() else Service.Hooks.OpenGlass(job.o.incubator) end
	end
	active[job.o.incubator] = nil
	task.delay(Config.LabelHold + 0.5, function() if job.o.incubator.Parent and not active[job.o.incubator] and job.o.incubator:GetAttribute('HatchToken') == '' then clearAttrs(job.o.incubator) end end)
	if job.o.onComplete then task.spawn(job.o.onComplete, ch, cancelled) end
end

function Service.Play(o)
	local inc = o.incubator
	if not (inc and inc.Parent and o.character and o.egg) then return false, "Missing incubator, egg or character" end
	if active[inc] then return false, "Already hatching" end
	local T = Config.Timeline(o.roll)
	local job = { o = o, token = HttpService:GenerateGUID(false), threads = {}, locks = {} }
	active[inc] = job
	job.display = o.displayCFrame or Service.Hooks.DisplayCFrame(inc, o.character)
	lock(o.egg, job.locks)
	lock(o.character, job.locks)
	o.character.Parent = nil
	o.character:PivotTo(job.display)

	inc:SetAttribute("HatchStart", workspace:GetServerTimeNow())
	inc:SetAttribute("HatchRarity", o.rarity or "Common")
	inc:SetAttribute("HatchRoll", o.roll or "Ordinary")
	inc:SetAttribute("HatchPower", tonumber(o.power) or 0)
	inc:SetAttribute("HatchIncome", tonumber(o.income) or 0)
	inc:SetAttribute("HatchName", o.name or o.character.Name)
	inc:SetAttribute("HatchOwner", o.owner and o.owner.UserId or 0)
	local ev = Instance.new("ObjectValue"); ev.Name = "HatchEgg"; ev.Value = o.egg; ev.Parent = inc
	local cv = Instance.new("ObjectValue"); cv.Name = "HatchCharacter"; cv.Parent = inc
	inc:SetAttribute("HatchToken", job.token) -- set last: clients start when this changes
	CollectionService:AddTag(inc, TAG)
	if o.closeGlass then o.closeGlass() else Service.Hooks.CloseGlass(inc) end

	table.insert(job.threads, task.delay(math.max(0, T.Break - 0.4), function()
		o.character.Parent = o.characterParent or inc -- arrives slightly early; clients hide it until the break
		cv.Value = o.character
	end))
	table.insert(job.threads, task.delay(T.Break + 0.6, function() if o.egg.Parent then o.egg:Destroy() end end))
	table.insert(job.threads, task.delay(T.End, function() finish(job, false) end))
	job.ancestry = inc.AncestryChanged:Connect(function() if not inc:IsDescendantOf(workspace) then finish(job, true) end end)
	return true, job.token
end

-- Ends instantly but still leaves the awarded character in place (owner left, plot reset, etc.)
function Service.Cancel(inc) local job = active[inc]; if job then finish(job, true) end end
function Service.IsBusy(inc) return active[inc] ~= nil end

return Service
