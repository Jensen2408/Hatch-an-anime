--[[ ServerScriptService.MoneyStandServer  (Script)
Owner-only, server-validated money collection for every stand tagged "MoneyStand".

Each stand Model needs:
  • Plate        (Part, the movable pressure plate; the server never moves it)
  • Display      (Part with SurfaceGui "Screen" > TextLabel "Amount" + "Status"), built by MoneyStandBuilder
  • Attributes   OwnerUserId (number), Stored (number), IncomePerSecond (number, optional)

Your existing earning system can write Stored directly. Set Config.BuiltInIncome = false to stop this script accruing it.
]]
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = {
	Tag = "MoneyStand",
	BuiltInIncome = false,          -- adds IncomePerSecond to Stored once a second
	Cooldown = 0.8,                -- seconds between collections per stand
	ZonePadding = 0.6,             -- studs around the plate's footprint
	ZoneHeight = 6,                -- studs above the plate that still count as "standing on it"
	CurrencyStat = "Cash",         -- leaderstats value that receives the money
}

-- Replace this to route money through your own economy module.
local function award(player, amount)
	local ls = player:FindFirstChild("leaderstats")
	local stat = ls and ls:FindFirstChild(Config.CurrencyStat)
	if stat then stat.Value += amount return true end
	warn("[MoneyStand] no leaderstats." .. Config.CurrencyStat .. " for " .. player.Name)
	return false
end

local remote = ReplicatedStorage:FindFirstChild("MoneyCollected") or Instance.new("RemoteEvent")
remote.Name = "MoneyCollected"
remote.Parent = ReplicatedStorage

local stands = {}

local function inZone(plate, pos)
	local rel = plate.CFrame:PointToObjectSpace(pos)
	local hx, hz = plate.Size.X / 2 + Config.ZonePadding, plate.Size.Z / 2 + Config.ZonePadding
	return math.abs(rel.X) <= hx and math.abs(rel.Z) <= hz and rel.Y >= -0.5 and rel.Y <= Config.ZoneHeight
end

local function add(model)
	if stands[model] or not model:IsA("Model") then return end
	local plate = model:WaitForChild("Plate", 10)
	if not plate then warn("[MoneyStand] " .. model:GetFullName() .. " has no Plate") return end
	stands[model] = { model = model, plate = plate, lastCollect = 0 }
	if model:GetAttribute("Stored") == nil then model:SetAttribute("Stored", 0) end
	model:SetAttribute("Pressed", false)
end
local function remove(model) stands[model] = nil end

for _, m in CollectionService:GetTagged(Config.Tag) do task.spawn(add, m) end
CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(add)
CollectionService:GetInstanceRemovedSignal(Config.Tag):Connect(remove)

-- presence check (10 Hz). A position check on the server is harder to spoof than Touched, and it can't double-fire.
task.spawn(function()
	while true do
		task.wait(0.1)
		local now = os.clock()
		for model, s in stands do
			if not model.Parent then stands[model] = nil continue end
			local owner = Players:GetPlayerByUserId(model:GetAttribute("OwnerUserId") or 0)
			local hrp = owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
			local hum = owner and owner.Character and owner.Character:FindFirstChildOfClass("Humanoid")
			local on = hrp ~= nil and hum ~= nil and hum.Health > 0 and inZone(s.plate, hrp.Position)
			if model:GetAttribute("Pressed") ~= on then
				model:SetAttribute("Pressed", on)
				if on and now - s.lastCollect >= Config.Cooldown then
					s.lastCollect = now
					local stored = model:GetAttribute("Stored") or 0
                    local amount = math.floor(stored)
					if amount >= 1 then
						model:SetAttribute("Stored", stored - amount) -- clear first so nothing can be collected twice
						if award(owner, amount) then
							remote:FireAllClients(model, amount)
						else
							model:SetAttribute("Stored", (model:GetAttribute("Stored") or 0) + amount) -- refund on failure
						end
					else
						remote:FireAllClients(model, 0) -- "empty" feedback
					end
				end
			end
		end
	end
end)

if Config.BuiltInIncome then
	task.spawn(function()
		while true do
			task.wait(1)
			for model in stands do
				local rate = model:GetAttribute("IncomePerSecond")
				if rate and rate > 0 and (model:GetAttribute("OwnerUserId") or 0) ~= 0 then
					model:SetAttribute("Stored", (model:GetAttribute("Stored") or 0) + rate)
				end
			end
		end
	end)
end

