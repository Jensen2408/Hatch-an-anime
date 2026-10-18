--[[ ServerScriptService.PlotManager  (Script, server)
Owns the plot lifecycle and the temple on every plot in workspace.Plots.

Lifecycle
  * Plot setup: every plot starts unowned (OwnerUserId = 0, OwnerName = "") with a level-1 temple and gets a
    "RequestUpgrade" BindableEvent (fired by GameMenuServer / OwnerGameActions as (player, adminActor)).
  * Join: wait for PlayerDataService to set DataLoaded (max 30 s), read SavedTempleLevel, then assign the
    free plot with the lowest PlotId. If every plot is taken the player is queued (WaitingForPlot = true)
    and served as soon as a plot frees up.
  * Leave: invoke ServerStorage.PlayerDataSnapshot first (so the save sees the plot), then cancel any running
    construction, clear owner/placed items/slots and rebuild a level-1 temple for the next player.
  * Upgrade: validates owner/distance/level/slot unlocks, charges UpgradePrices, then plays the
    ConstructionService animation (falls back to an instant swap on error).

Contracts other systems depend on (attribute names are cross-system contracts):
  Plot:   OwnerUserId, OwnerName, PlotId (read), TempleLevel, TempleBuilding, TempleAppearance (read),
          AppearanceBuilding (read), child "Temple" (with OwnerUserId), RequestUpgrade
  Player: PlotId, TempleLevel, WaitingForPlot, StartupSessionReady, RespawnLocation
Used by e.g. PlayerDataService, TempleSlotUnlocks, PlotChambers, HomeAndBubbles, MoneyStand*, EggSteal,
BrainrotPlacement, GameMenuServer, the owner/admin tools and the client StartupLoader / PromptCards.
Saving itself lives in PlayerDataService; `save` below is intentionally a no-op.
]]

local Players = game:GetService("Players")

local plots = workspace:WaitForChild("Plots")
local templeTemplates = game.ServerStorage:WaitForChild("TempleUpgradeTemplates")
-- State: [player] = plot, FIFO queue of players waiting for a free plot, [plot] = cooldown end (os.clock)
local assignedPlots, waitingQueue, upgradeCooldowns = {}, {}, {}
local TempleOccupancy = require(script.Parent.TempleOccupancy)
local Construction = require(script.Parent:WaitForChild("Construction"):WaitForChild("ConstructionService"))

local ADMIN_USER_ID = 168774222 -- may upgrade from anywhere and for free
local MAX_TEMPLE_LEVEL = 3
local DATA_LOAD_TIMEOUT = 30 -- seconds to wait for PlayerDataService's DataLoaded
local UPGRADE_COOLDOWN = 2.4 -- seconds between upgrade requests per plot
local UPGRADE_MAX_DISTANCE = 80 -- studs from TempleAnchor

-- Temple footprint (TempleAnchor object space); characters inside are moved before a rebuild.
local FOOTPRINT_HALF_X = 40
local FOOTPRINT_HALF_Z = 35
local FOOTPRINT_MIN_Y = -2
local FOOTPRINT_MAX_Y = 100

-- State ---------------------------------------------------------------------------------------------------
local profiles = {} -- [player] = { level = savedTempleLevel }
local busy = {} -- [plot] = true while an upgrade (incl. its construction animation) is running

-- Persistence ---------------------------------------------------------------------------------------------
local function save(_player) end -- saving lives in PlayerDataService

-- Yields until PlayerDataService has loaded the player's data (or timeout). Returns false if they left.
local function load(player)
    local startTime = os.clock()
    while
        player.Parent == Players
        and not player:GetAttribute("DataLoaded")
        and os.clock() - startTime < DATA_LOAD_TIMEOUT
    do
        task.wait(0.2)
    end
    profiles[player] = {
        level = math.clamp(tonumber(player:GetAttribute("SavedTempleLevel")) or 1, 1, MAX_TEMPLE_LEVEL),
    }
    return player.Parent == Players
end

-- Temple building -----------------------------------------------------------------------------------------
-- Re-applies everything derived from owner / level / busy state.
local function refresh(plot)
    local _level = plot:GetAttribute("TempleLevel") or 1
    local owner = plot:GetAttribute("OwnerUserId") or 0
    TempleOccupancy.Apply(plot, owner ~= 0)
    require(script.Parent.TempleSlotUnlocks).Refresh(plot)
    plot:SetAttribute("TempleBuilding", busy[plot] == true)
end

-- Moves anyone standing where the new floors/stairs are about to appear.
local function clearFootprint(plot)
    for _, visitor in Players:GetPlayers() do
        local character = visitor.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root then
            local localPos = plot.TempleAnchor.CFrame:PointToObjectSpace(root.Position)
            if
                math.abs(localPos.X) < FOOTPRINT_HALF_X
                and math.abs(localPos.Z) < FOOTPRINT_HALF_Z
                and localPos.Y > FOOTPRINT_MIN_Y
                and localPos.Y < FOOTPRINT_MAX_Y
            then
                character:PivotTo(plot.PlotSpawn.CFrame * CFrame.new(0, 4, 0))
            end
        end
    end
end

-- Replaces plot.Temple with ServerStorage.TempleUpgradeTemplates["Level<level>"].
-- animate = false: instant swap. animate = true: ConstructionService upgrade animation; yields until it has
-- finished (so the caller keeps `busy` set) and errors if the animation could not start.
local function build(plot, level, animate)
    local template = templeTemplates:FindFirstChild("Level" .. level)
    if not template then
        return
    end
    local expectedOwner = plot:GetAttribute("OwnerUserId")
    local oldTemple = plot:FindFirstChild("Temple")
    local function swapInstantly(prepare)
        clearFootprint(plot)
        local clone = template:Clone()
        require(game.ReplicatedStorage.TempleAppearanceThemes).Apply(
            clone,
            plot:GetAttribute("TempleAppearance") or "Original"
        )
        clone.Name = "Temple"
        clone:PivotTo(plot.TempleAnchor.CFrame)
        clone.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
        if prepare then
            prepare(clone)
        end
        clone.Parent = plot
        if oldTemple then
            oldTemple:Destroy()
        end
        plot:SetAttribute("TempleLevel", level)
        clone:SetAttribute("OwnerUserId", plot:GetAttribute("OwnerUserId") or 0)
        refresh(plot)
        return clone
    end
    if not animate then
        return swapInstantly()
    end

    local constructionKey = plot.Name .. ":Temple"
    if plot:GetAttribute("OwnerUserId") ~= expectedOwner or expectedOwner == 0 then
        return
    end
    local clone = template:Clone()
    require(game.ReplicatedStorage.TempleAppearanceThemes).Apply(
        clone,
        plot:GetAttribute("TempleAppearance") or "Original"
    )
    clone.Name = "Temple"
    clone.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
    clearFootprint(plot)
    -- Known issue (docs/PROJECT_AUDIT.md): an incremental upgrade can leave the old model named
    -- "Temple_Retiring"; it is only renamed back here on failure.
    if oldTemple then
        oldTemple.Name = "Temple_Retiring"
    end
    local ok, model = Construction.Upgrade({
        key = constructionKey,
        owner = Players:GetPlayerByUserId(expectedOwner),
        kind = "Temple",
        parent = plot,
        oldModel = oldTemple,
        template = clone,
        pivot = plot.TempleAnchor.CFrame,
        mode = "auto",
    })
    clone:Destroy()
    if not ok then
        if oldTemple then
            oldTemple.Name = "Temple"
        end
        error(model) -- model holds the error message here
    end
    plot:SetAttribute("TempleLevel", level)
    model:SetAttribute("OwnerUserId", plot:GetAttribute("OwnerUserId") or 0)
    refresh(plot)
    -- keep the upgrade lock (busy) until the construction animation has finished
    while Construction.IsBusy(constructionKey) do
        task.wait(0.1)
    end
    return model
end

local function moveCharacter(player, character)
    local root = character:WaitForChild("HumanoidRootPart", 10)
    local plot = assignedPlots[player]
    if root and plot and player.Character == character then
        character:PivotTo(plot.PlotSpawn.CFrame * CFrame.new(0, 4, 0))
    end
end

-- Upgrades ------------------------------------------------------------------------------------------------
-- Handler for plot.RequestUpgrade. adminActor (optional) is the player who triggered it from an admin tool.
local function upgrade(plot, player, adminActor)
    local isAdmin = adminActor and adminActor.UserId == ADMIN_USER_ID
    if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then
        return
    end
    if busy[plot] or plot:GetAttribute("AppearanceBuilding") then
        return
    end
    if assignedPlots[player] ~= plot or plot:GetAttribute("OwnerUserId") ~= player.UserId then
        return
    end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if
        not isAdmin
        and (
            not root
            or not humanoid
            or humanoid.Health <= 0
            or (root.Position - plot.TempleAnchor.Position).Magnitude > UPGRADE_MAX_DISTANCE
        )
    then
        return
    end
    local level = plot:GetAttribute("TempleLevel") or 1
    if level >= MAX_TEMPLE_LEVEL or os.clock() < (upgradeCooldowns[plot] or 0) then
        return
    end
    if not require(script.Parent.TempleSlotUnlocks).CanUpgrade(plot) then
        return
    end
    if
        not isAdmin
        and not require(game.ReplicatedStorage.UpgradePrices).Charge(
            player,
            require(game.ReplicatedStorage.UpgradePrices).Temple[level + 1]
        )
    then
        return
    end
    busy[plot] = true
    upgradeCooldowns[plot] = os.clock() + UPGRADE_COOLDOWN
    refresh(plot) -- locks the prompt for the duration of the animation
    player:SetAttribute("TempleLevel", level + 1)
    if profiles[player] then
        profiles[player].level = level + 1
    end
    task.spawn(save, player)
    task.spawn(function()
        -- The owner may leave mid-animation; PlayerRemoving then resets the plot, so stop touching it.
        if plot:GetAttribute("OwnerUserId") ~= player.UserId then
            return
        end
        local ok, err = pcall(build, plot, level + 1, true)
        if plot:GetAttribute("OwnerUserId") ~= player.UserId then
            return
        end
        if not ok then
            warn("Temple upgrade effect failed, falling back to instant build: " .. tostring(err))
            pcall(build, plot, level + 1, false)
        end
        busy[plot] = nil
        refresh(plot)
    end)
end

-- Assignment ----------------------------------------------------------------------------------------------
-- Gives the player the free plot with the lowest PlotId. Returns false when every plot is taken.
local function assign(player)
    if assignedPlots[player] then
        return true
    end
    local sorted = plots:GetChildren()
    table.sort(sorted, function(plotA, plotB)
        return (plotA:GetAttribute("PlotId") or 0) < (plotB:GetAttribute("PlotId") or 0)
    end)
    for _, plot in sorted do
        if plot:GetAttribute("OwnerUserId") == 0 then
            assignedPlots[player] = plot
            plot:SetAttribute("OwnerUserId", player.UserId)
            plot:SetAttribute("OwnerName", player.DisplayName)
            build(plot, profiles[player].level, false)
            player:SetAttribute("PlotId", plot:GetAttribute("PlotId"))
            player:SetAttribute("TempleLevel", plot:GetAttribute("TempleLevel"))
            player:SetAttribute("WaitingForPlot", false)
            player.RespawnLocation = plot.PlotSpawn
            plot.Temple:SetAttribute("OwnerUserId", player.UserId)
            refresh(plot)
            player:SetAttribute("StartupSessionReady", true)
            if player.Character then
                task.spawn(moveCharacter, player, player.Character)
            end
            return true
        end
    end
    return false
end

-- Drops players who left, then assigns plots to the queue in FIFO order until no plot is free.
local function serviceWaiting()
    for i = #waitingQueue, 1, -1 do
        if waitingQueue[i].Parent ~= Players then
            table.remove(waitingQueue, i)
        end
    end
    while #waitingQueue > 0 do
        if assign(waitingQueue[1]) then
            table.remove(waitingQueue, 1)
        else
            break
        end
    end
end

-- Plot setup ----------------------------------------------------------------------------------------------
local function setup(plot)
    plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
        TempleOccupancy.ApplyPaths(plot, (plot:GetAttribute("OwnerUserId") or 0) ~= 0)
    end)
    -- Fence pieces can stream/arrive later; re-apply the path state once they are in.
    plot.DescendantAdded:Connect(function(item)
        local fence = plot:FindFirstChild("FENCE")
        if fence and item:IsDescendantOf(fence) then
            task.defer(function()
                if plot.Parent then
                    TempleOccupancy.ApplyPaths(plot, (plot:GetAttribute("OwnerUserId") or 0) ~= 0)
                end
            end)
        end
    end)

    plot:SetAttribute("OwnerUserId", 0)
    plot:SetAttribute("OwnerName", "")
    build(plot, 1, false)

    local requestUpgrade = Instance.new("BindableEvent")
    requestUpgrade.Name = "RequestUpgrade"
    requestUpgrade.Parent = plot
    requestUpgrade.Event:Connect(function(requester, adminActor)
        upgrade(plot, requester, adminActor)
    end)
    serviceWaiting()
end

for _, plot in plots:GetChildren() do
    setup(plot)
end
plots.ChildAdded:Connect(setup)

-- Players -------------------------------------------------------------------------------------------------
local function joined(player)
    if assignedPlots[player] or table.find(waitingQueue, player) then
        return
    end
    player.CharacterAdded:Connect(function(character)
        moveCharacter(player, character)
    end)
    if not load(player) then
        return
    end
    if not assign(player) then
        player:SetAttribute("WaitingForPlot", true)
        table.insert(waitingQueue, player)
    end
end

Players.PlayerRemoving:Connect(function(player)
    local snapshot = game:GetService("ServerStorage"):FindFirstChild("PlayerDataSnapshot")
    if snapshot then
        pcall(snapshot.Invoke, snapshot, player)
    end -- save before the plot is cleared
    local queueIndex = table.find(waitingQueue, player)
    if queueIndex then
        table.remove(waitingQueue, queueIndex)
    end
    task.spawn(function()
        save(player)
        profiles[player] = nil
    end)
    local plot = assignedPlots[player]
    assignedPlots[player] = nil
    if not plot then
        return
    end
    Construction.Cancel(plot.Name .. ":Temple")
    plot:SetAttribute("OwnerUserId", 0)
    plot:SetAttribute("OwnerName", "")
    plot.PlacedItems:ClearAllChildren()
    for _, slot in plot.Slots:GetChildren() do
        slot:SetAttribute("Occupied", false)
        slot.Platform.PlacePrompt.Enabled = true
    end
    upgradeCooldowns[plot] = nil
    busy[plot] = nil
    build(plot, 1, false)
    serviceWaiting()
end)

Players.PlayerAdded:Connect(joined)
for _, player in Players:GetPlayers() do
    task.spawn(joined, player)
end
