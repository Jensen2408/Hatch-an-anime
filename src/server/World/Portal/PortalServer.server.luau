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
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Portal"):WaitForChild("PortalConfig"))
local PortalService = require(script.Parent:WaitForChild("PortalService"))

-- Cycles the DemoFolder characters through the gate until the gate is removed.
local function runDemo(spot, portal)
    local folder = ServerStorage:FindFirstChild(spot:GetAttribute("DemoFolder") or "")
    if not folder then
        return
    end
    local nextIndex = 0
    while portal.Parent do
        local demoCharacters = folder:GetChildren()
        if #demoCharacters > 0 then
            nextIndex = nextIndex % #demoCharacters + 1
            local template = demoCharacters[nextIndex]
            local character = template:Clone()
            local stay = spot:GetAttribute("DemoStay") or 5
            PortalService.Emerge(portal, character, {
                rarity = template:GetAttribute("Rarity"),
                onComplete = function(emerged)
                    task.delay(stay, function()
                        if emerged then
                            emerged:Destroy()
                        end
                    end)
                end,
            })
        end
        task.wait(math.max(Config.Total() + 1, spot:GetAttribute("DemoInterval") or 9))
    end
end

-- Builds the gate once per spot (PortalBuilt guards re-entry) and hides the spot part.
local function buildGate(spot)
    if not spot:IsA("BasePart") or spot:GetAttribute("PortalBuilt") then
        return
    end
    spot:SetAttribute("PortalBuilt", true)
    -- ground centre of the spot, facing its LookVector flattened onto the XZ plane
    local baseCFrame = spot.CFrame * CFrame.new(0, -spot.Size.Y / 2, 0)
    baseCFrame =
        CFrame.lookAt(baseCFrame.Position, baseCFrame.Position + (spot.CFrame.LookVector * Vector3.new(1, 0, 1)))
    spot.Transparency = 1
    spot.CanCollide = false
    spot.CanQuery = false
    local portal = PortalService.Build(baseCFrame, spot.Parent)
    task.spawn(runDemo, spot, portal)
end

local spotCount = #CollectionService:GetTagged(Config.SpotTag)
if spotCount == 0 then
    warn("[Portal] no Part tagged '" .. Config.SpotTag .. "' yet: tag one to build a gate")
else
    print("[Portal] building " .. spotCount .. " gate(s)")
end
for _, spot in CollectionService:GetTagged(Config.SpotTag) do
    task.spawn(buildGate, spot)
end
CollectionService:GetInstanceAddedSignal(Config.SpotTag):Connect(buildGate)
