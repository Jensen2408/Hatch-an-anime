-- HatchVideoService (owners only): "hatching until I get a GOD" recording run.
-- Client sends "Start" -> server hatches a chain of eggs in incubator 1 instantly (no waiting),
-- each with the real hatch reveal, ending on the chosen top egg. Rewards are removed again afterwards.
--
-- Remote: ReplicatedStorage.HatchVideo (RemoteEvent, created here if missing)
--   client -> server: ("Start", optionalIdList) | ("Stop")
--   server -> client: ("Begin", chamber) | ("Egg", index, count, id) | ("Error", message) | ("Done")
-- Drives the chamber through its own HatchGoo interface: ResumeEgg (insert with 0.6 s left),
-- RequestHatch (press hatch) and EggPickupAnchor.RequestPickup (collect), polling the Status attribute.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local OWNERS = { [168774222] = true, [353101613] = true }
local DEFAULT_CHAIN = { "Shinobi", "Hero", "Soul", "Devil", "God" }

local Catalog = require(ReplicatedStorage:WaitForChild("CharacterCatalog"))
local remote = ReplicatedStorage:FindFirstChild("HatchVideo") or Instance.new("RemoteEvent")
remote.Name = "HatchVideo"
remote.Parent = ReplicatedStorage
local running = {} -- [player] = true while a run is active; cleared by "Stop" to end it early

local function plotOf(player)
    for _, plot in workspace.Plots:GetChildren() do
        if plot:GetAttribute("OwnerUserId") == player.UserId then
            return plot
        end
    end
end

-- Polls chamber.Status until it equals `want` (or is in the list `want`). False on timeout / chamber removed.
local function waitStatus(chamber, want, timeout)
    local startTime = os.clock()
    while os.clock() - startTime < (timeout or 60) do
        if not chamber.Parent then
            return false
        end
        local status = chamber:GetAttribute("Status")
        if (type(want) == "table" and table.find(want, status)) or status == want then
            return true
        end
        task.wait(0.1)
    end
    return false
end

-- Builds a throwaway egg tool (tagged HatchVideo) shaped like a normal held egg.
local function makeEgg(id)
    local entry = Catalog.ById[id]
    local template = ServerStorage.AuxEggTemplates:FindFirstChild(id)
    if not entry or not template then
        return
    end
    local tool = Instance.new("Tool")
    tool.Name = id .. " Egg"
    tool.CanBeDropped = false
    Catalog.Stamp(tool, entry)
    tool:SetAttribute("EggType", id)
    tool:SetAttribute("OwnerSpawned", true)
    tool:SetAttribute("HatchVideo", true)
    local visual = template:Clone()
    visual.Name = "Egg"
    visual:ScaleTo(template:GetScale() * 0.5)
    visual:PivotTo(CFrame.new())
    visual.Parent = tool
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.one
    handle.Transparency = 1
    handle.CanCollide = false
    handle.Massless = true
    handle.Parent = tool
    for _, descendant in visual:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.Anchored = false
            descendant.CanCollide = false
            descendant.Massless = true
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = handle
            weld.Part1 = descendant
            weld.Parent = handle
        elseif descendant:IsA("BaseScript") then
            descendant:Destroy()
        end
    end
    return tool
end

-- Hatched reward tools from the recording run are removed again so the run awards nothing.
local function destroyHatchedReward(child)
    if child:IsA("Tool") and child:GetAttribute("Hatched") then
        task.defer(function()
            child:Destroy()
        end)
    end
end

local function run(player, chain)
    local plot = plotOf(player)
    if not plot then
        remote:FireClient(player, "Error", "No temple")
        return
    end
    local chamber = plot.Chambers:FindFirstChild("Chamber1")
    if not chamber then
        return
    end
    local button = chamber:FindFirstChild("HatchButton", true)
    local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return
    end
    local backpack = player:FindFirstChildOfClass("Backpack")
    -- park the (locally hidden) character right by the hatch button so all range checks pass
    local stand = (button and button:IsA("BasePart") and button.CFrame or chamber:GetPivot()) * CFrame.new(0, 0, -6)
    local function park()
        if player.Character then
            player.Character:PivotTo(CFrame.new(stand.Position + Vector3.new(0, 3, 0)))
        end
    end
    local backpackRewardConnection = backpack and backpack.ChildAdded:Connect(destroyHatchedReward)
    local characterRewardConnection = player.Character and player.Character.ChildAdded:Connect(destroyHatchedReward)
    remote:FireClient(player, "Begin", chamber)
    waitStatus(chamber, "Ready", 30)
    for i, id in chain do
        if not running[player] or not player.Parent then
            break
        end
        park()
        local egg = makeEgg(id)
        if not egg then
            continue
        end
        egg.Parent = backpack
        remote:FireClient(player, "Egg", i, #chain, id)
        chamber.ResumeEgg:Invoke(player, egg, 0.6)
        if not waitStatus(chamber, "Loaded", 20) then
            break
        end
        task.wait(0.8)
        park()
        chamber.RequestHatch:Fire(player)
        if not waitStatus(chamber, "AwaitingPickup", 40) then
            break
        end
        task.wait(i == #chain and 5 or 1.6) -- hold longer on the final reveal
        local anchor = chamber:FindFirstChild("EggPickupAnchor", true)
        park()
        if anchor and anchor:FindFirstChild("RequestPickup") then
            anchor.RequestPickup:Fire(player)
        end
        waitStatus(chamber, "Ready", 15)
        task.wait(0.4)
    end
    if backpackRewardConnection then
        backpackRewardConnection:Disconnect()
    end
    if characterRewardConnection then
        characterRewardConnection:Disconnect()
    end
    running[player] = nil
    remote:FireClient(player, "Done")
end

remote.OnServerEvent:Connect(function(player, action, list)
    if not OWNERS[player.UserId] then
        return
    end
    if action == "Start" and not running[player] then
        -- Optional custom chain from the client: 1..10 ids, unknown ids are dropped.
        local chain = DEFAULT_CHAIN
        if type(list) == "table" and #list > 0 and #list <= 10 then
            chain = {}
            for _, id in list do
                if type(id) == "string" and Catalog.ById[id] then
                    table.insert(chain, id)
                end
            end
        end
        running[player] = true
        task.spawn(run, player, chain)
    elseif action == "Stop" then
        running[player] = nil
    end
end)
Players.PlayerRemoving:Connect(function(player)
    running[player] = nil
end)
