--[[ ServerScriptService.Portal.PortalServer  (Script)
Builds a Summon Gate on every Part tagged "PortalSpot" (gate stands on the part's bottom, facing its Front face).
Optional demo on the spot part (attributes):
  DemoFolder   (string)  name of a Folder in ServerStorage holding rigged characters, e.g. "PortalDemo"
  DemoInterval (number)  seconds between arrivals (default 9)
  DemoStay     (number)  seconds a character stays before vanishing (default 5)
Characters may carry a "Rarity" attribute; it sets the vortex colour.
]]
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local C = require(game:GetService("ReplicatedStorage"):WaitForChild("Portal"):WaitForChild("PortalConfig"))
local Portal = require(script.Parent:WaitForChild("PortalService"))

local function demo(spot, portal)
	local folder = ServerStorage:FindFirstChild(spot:GetAttribute("DemoFolder") or "")
	if not folder then return end
	local i = 0
	while portal.Parent do
		local list = folder:GetChildren()
		if #list > 0 then
			i = i % #list + 1
			local src = list[i]
			local ch = src:Clone()
			local stay = spot:GetAttribute("DemoStay") or 5
			Portal.Emerge(portal, ch, {
				rarity = src:GetAttribute("Rarity"),
				onComplete = function(c) task.delay(stay, function() if c then c:Destroy() end end) end,
			})
		end
		task.wait(math.max(C.Total() + 1, spot:GetAttribute("DemoInterval") or 9))
	end
end

local function build(spot)
	if not spot:IsA("BasePart") or spot:GetAttribute("PortalBuilt") then return end
	spot:SetAttribute("PortalBuilt", true)
	local base = spot.CFrame * CFrame.new(0, -spot.Size.Y / 2, 0)
	base = CFrame.lookAt(base.Position, base.Position + (spot.CFrame.LookVector * Vector3.new(1, 0, 1)))
	spot.Transparency = 1; spot.CanCollide = false; spot.CanQuery = false
	local portal = Portal.Build(base, spot.Parent)
	task.spawn(demo, spot, portal)
end

local n = #CollectionService:GetTagged(C.SpotTag)
if n == 0 then warn("[Portal] no Part tagged '" .. C.SpotTag .. "' yet: tag one to build a gate") else print("[Portal] building " .. n .. " gate(s)") end
for _, s in CollectionService:GetTagged(C.SpotTag) do task.spawn(build, s) end
CollectionService:GetInstanceAddedSignal(C.SpotTag):Connect(build)
