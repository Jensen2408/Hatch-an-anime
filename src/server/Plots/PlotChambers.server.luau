--[[ ServerScriptService.PlotChambers  (Script, server)
Manages the incubator chambers (plot.Chambers.Chamber1..3) next to each temple.
  * plot.RequestChamberUpgrade (BindableEvent, created here) -> add the next chamber (max 3), built at the
    plot's current incubator level.
  * ChamberN.RequestIncubatorUpgrade (BindableEvent, created here) -> upgrade ALL chambers one level (max 3).
  Both are fired as (player, adminActor) by the game menu / owner tools; a non-nil adminActor skips the charge.
Upgrading never waits for a chamber to be empty: UpgradeLevel (and with it the hatch speed, see
EggHatchTiming.LevelSpeed) rises at once on every chamber. The model swap is animated right away for empty
chambers and deferred for busy ones until their Status returns to "Ready" (ModelLevel = level of the model
that is actually standing there).
Prices come from ReplicatedStorage.UpgradePrices (AddIncubator / IncubatorLevel); construction is animated by
ConstructionService under the key "<plot>:Chamber<index>".
Ownership change (OwnerUserId) wipes the chambers and restores them from the owner's SavedChambers attribute
(a string of levels, e.g. "1,3,2", written by PlayerDataService).
Plot attributes written: ChamberCount, ChamberBuilding, IncubatorLevel (lowest chamber level).
Chamber attributes: ChamberIndex, UpgradeLevel, ModelLevel, OwnerUserId, UnderConstruction.
]]

local Players = game:GetService("Players")
local incubatorTemplates = game.ServerStorage:WaitForChild("IncubatorUpgradeTemplates")
local plots = workspace:WaitForChild("Plots")
local Construction = require(script.Parent:WaitForChild("Construction"):WaitForChild("ConstructionService"))

local ADMIN_USER_ID = 168774222 -- skips the distance check
local MAX_CHAMBERS = 3
local MAX_CHAMBER_LEVEL = 3
local UPGRADE_MAX_DISTANCE = 80 -- studs from TempleAnchor ("anywhere on own plot")

local function setup(plot)
    local templeAnchor = plot.TempleAnchor
    local chambers = plot:FindFirstChild("Chambers") or Instance.new("Folder")
    chambers.Name = "Chambers"
    chambers.Parent = plot
    local building = 0 -- running chamber constructions on this plot (they run in parallel, one per chamber)
    local generation = 0 -- bumped on every ownership change; stale constructions check it and bail out
    -- Owner check; non-admins must also have a root part near the temple. (_target is unused.)
    local function isAuthorizedOwner(player, _target, adminActor)
        if adminActor and adminActor.UserId == ADMIN_USER_ID then
            return player and player.Parent == Players and plot:GetAttribute("OwnerUserId") == player.UserId
        end
        local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        return player
            and player.Parent == Players
            and plot:GetAttribute("OwnerUserId") == player.UserId
            and root
            and (root.Position - plot.TempleAnchor.Position).Magnitude <= UPGRADE_MAX_DISTANCE -- anywhere on own plot
    end
    -- Lowest UpgradeLevel over the chambers (1 when there are none).
    local function plotLevel()
        local lowest
        for _, chamber in chambers:GetChildren() do
            local level = chamber:GetAttribute("UpgradeLevel") or 1
            lowest = math.min(lowest or level, level)
        end
        return lowest or 1
    end
    local function refresh()
        local count = #chambers:GetChildren()
        plot:SetAttribute("ChamberCount", count)
        plot:SetAttribute("ChamberBuilding", building > 0)
        plot:SetAttribute("IncubatorLevel", plotLevel())
    end
    -- Chambers line up along the plot side, 17 studs apart, facing the temple path.
    local function chamberCFrame(index)
        return plot.TempleAnchor.CFrame
            * CFrame.new(-44, 0.25, 15 - (index - 1) * 17)
            * CFrame.Angles(0, -math.pi / 2, 0)
    end
    local upgradeAll, syncModel -- forward-declared: wireChamber needs them before they are defined
    local function wireChamber(model)
        model.RequestIncubatorUpgrade.Event:Connect(function(player, adminActor)
            upgradeAll(player, adminActor)
        end)
        -- a busy chamber upgraded earlier swaps its model once it is empty again
        model:GetAttributeChangedSignal("Status"):Connect(function()
            syncModel(model)
        end)
    end
    -- Unparented chamber model for the given level, with its RequestIncubatorUpgrade event (not wired yet).
    local function makeChamber(index, level)
        local model = incubatorTemplates["Level" .. level]:Clone()
        model.Name = "Chamber" .. index
        model:SetAttribute("ChamberIndex", index)
        model:SetAttribute("UpgradeLevel", level)
        model:SetAttribute("ModelLevel", level)
        model:SetAttribute("OwnerUserId", plot:GetAttribute("OwnerUserId"))
        model:SetAttribute("ClientEffectsReady", nil)
        model:PivotTo(chamberCFrame(index))
        local request = Instance.new("BindableEvent")
        request.Name = "RequestIncubatorUpgrade"
        request.Parent = model
        return model
    end
    -- Instant (non-animated) placement, replacing any existing chamber with the same index.
    local function placeChamber(index, level, prepare)
        local model = makeChamber(index, level)
        wireChamber(model)
        if prepare then
            prepare(model)
        end
        local oldChamber = chambers:FindFirstChild(model.Name)
        model.Parent = chambers
        if oldChamber then
            oldChamber:Destroy()
        end
        refresh()
        return model
    end
    -- Animated build/upgrade (runs in its own thread). Always releases its `building` count at the end unless
    -- the plot changed owner meanwhile (then the new ownership pass already reset everything). On failure it
    -- falls back to an instant placement.
    local function constructChamber(player, index, level, oldChamber)
        local expectedOwner = plot:GetAttribute("OwnerUserId")
        local myGeneration = generation
        local function stillValid()
            return plot.Parent ~= nil
                and generation == myGeneration
                and plot:GetAttribute("OwnerUserId") == expectedOwner
                and expectedOwner ~= 0
        end
        building += 1
        refresh()
        if oldChamber then
            oldChamber:SetAttribute("UnderConstruction", true)
        end
        local constructionKey = plot.Name .. ":Chamber" .. index
        local ok, err = pcall(function()
            if not stillValid() then
                return
            end
            local template = makeChamber(index, level)
            template.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
            if oldChamber then
                oldChamber.Name = "Chamber" .. index .. "_Retiring"
            end -- avoid two models sharing a name while the old one sinks
            local built, model = Construction.Upgrade({
                key = constructionKey,
                owner = player,
                kind = "Incubator",
                parent = chambers,
                oldModel = oldChamber,
                template = template,
                pivot = chamberCFrame(index),
                mode = "replace",
            })
            template:Destroy()
            if not built then
                if oldChamber then
                    oldChamber.Name = "Chamber" .. index
                end
                error(model)
            end
            wireChamber(model)
            model:SetAttribute("UnderConstruction", true)
            refresh()
            while Construction.IsBusy(constructionKey) and stillValid() do
                task.wait(0.1)
            end
        end)
        if generation ~= myGeneration then
            return
        end
        if not ok and stillValid() then
            warn("Incubator construction recovered: " .. tostring(err))
            local current = chambers:FindFirstChild("Chamber" .. index)
            if not current or current:GetAttribute("ModelLevel") ~= level then
                placeChamber(index, level)
            end
        end
        local current = chambers:FindFirstChild("Chamber" .. index)
        if current then
            current:SetAttribute("UnderConstruction", nil)
        end
        building -= 1
        refresh()
    end
    -- Starts the model swap of an empty chamber whose model is behind its UpgradeLevel.
    syncModel = function(chamber)
        local level = chamber:GetAttribute("UpgradeLevel") or 1
        if
            chamber.Parent ~= chambers
            or (chamber:GetAttribute("ModelLevel") or level) >= level
            or chamber:GetAttribute("UnderConstruction")
            or (chamber:GetAttribute("Status") or "Ready") ~= "Ready"
        then
            return
        end
        local index = chamber:GetAttribute("ChamberIndex")
        if not index then
            return
        end
        -- lock synchronously: no egg can be inserted between this check and the swap
        chamber:SetAttribute("UnderConstruction", true)
        local owner = Players:GetPlayerByUserId(plot:GetAttribute("OwnerUserId") or 0)
        task.spawn(constructChamber, owner, index, level, chamber)
    end
    upgradeAll = function(player, adminActor)
        if building > 0 or #chambers:GetChildren() == 0 then
            return
        end
        local target = plotLevel() + 1
        if target > MAX_CHAMBER_LEVEL then
            return
        end
        if not isAuthorizedOwner(player, plot.TempleAnchor, adminActor) then
            return
        end
        if
            not adminActor
            and not require(game.ReplicatedStorage.UpgradePrices).Charge(
                player,
                require(game.ReplicatedStorage.UpgradePrices).IncubatorLevel[target]
            )
        then
            return
        end
        -- the level (and the hatch speed) applies to every chamber at once, busy ones included
        for _, chamber in chambers:GetChildren() do
            if (chamber:GetAttribute("UpgradeLevel") or 1) < target then
                chamber:SetAttribute("UpgradeLevel", target)
            end
        end
        refresh()
        for _, chamber in chambers:GetChildren() do
            syncModel(chamber)
        end
    end
    local function addChamber(player, adminActor)
        if
            building > 0
            or #chambers:GetChildren() >= MAX_CHAMBERS
            or not isAuthorizedOwner(player, templeAnchor, adminActor)
        then
            return
        end
        local index = #chambers:GetChildren() + 1
        if
            not adminActor
            and not require(game.ReplicatedStorage.UpgradePrices).Charge(
                player,
                require(game.ReplicatedStorage.UpgradePrices).AddIncubator[index]
            )
        then
            return
        end
        task.spawn(constructChamber, player, index, plotLevel(), nil)
    end
    -- Owner joined/left: cancel running builds and rebuild the chambers from the new owner's save.
    local function onOwnershipChanged()
        generation += 1
        building = 0
        for i = 1, MAX_CHAMBERS do
            Construction.Cancel(plot.Name .. ":Chamber" .. i)
        end
        chambers:ClearAllChildren()
        local ownerId = plot:GetAttribute("OwnerUserId") or 0
        if ownerId ~= 0 then
            local owner = game:GetService("Players"):GetPlayerByUserId(ownerId)
            local saved = owner and owner:GetAttribute("SavedChambers")
            local savedCount = 0
            if type(saved) == "string" then
                for savedLevel in saved:gmatch("%d+") do
                    savedCount += 1
                    if savedCount <= MAX_CHAMBERS then
                        placeChamber(savedCount, math.clamp(tonumber(savedLevel) or 1, 1, MAX_CHAMBER_LEVEL))
                    end
                end
            end
            if savedCount == 0 then
                placeChamber(1, 1)
            end
        end
        refresh()
    end

    local oldRequest = plot:FindFirstChild("RequestChamberUpgrade")
    if oldRequest then
        oldRequest:Destroy()
    end
    local request = Instance.new("BindableEvent")
    request.Name = "RequestChamberUpgrade"
    request.Parent = plot
    request.Event:Connect(addChamber)
    plot:GetAttributeChangedSignal("OwnerUserId"):Connect(onOwnershipChanged)
    onOwnershipChanged()
end
for _, plot in ipairs(plots:GetChildren()) do
    task.spawn(setup, plot)
end
plots.ChildAdded:Connect(function(plot)
    task.spawn(setup, plot)
end)
