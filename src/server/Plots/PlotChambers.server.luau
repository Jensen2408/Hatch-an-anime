--[[ ServerScriptService.PlotChambers  (Script, server)
Manages the incubator chambers (plot.Chambers.Chamber1..3) next to each temple.
  * plot.RequestChamberUpgrade (BindableEvent, created here) -> add the next chamber (max 3).
  * ChamberN.RequestIncubatorUpgrade (BindableEvent, created here) -> upgrade that chamber (max level 3).
  Both are fired as (player, adminActor) by the game menu / owner tools; a non-nil adminActor skips the charge.
Prices come from ReplicatedStorage.UpgradePrices (AddIncubator / IncubatorLevel); construction is animated by
ConstructionService under the key "<plot>:Chamber<index>".
Ownership change (OwnerUserId) wipes the chambers and restores them from the owner's SavedChambers attribute
(a string of levels, e.g. "1,3,2", written by PlayerDataService).
Plot attributes written: ChamberCount, ChamberBuilding. Chamber attributes: ChamberIndex, UpgradeLevel,
OwnerUserId, UnderConstruction (Status is read: only "Ready" chambers can upgrade).
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
    local busy = false -- one add/upgrade at a time per plot
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
    local function refresh()
        local count = #chambers:GetChildren()
        plot:SetAttribute("ChamberCount", count)
        plot:SetAttribute("ChamberBuilding", busy)
    end
    -- Chambers line up along the plot side, 17 studs apart, facing the temple path.
    local function chamberCFrame(index)
        return plot.TempleAnchor.CFrame
            * CFrame.new(-44, 0.25, 15 - (index - 1) * 17)
            * CFrame.Angles(0, -math.pi / 2, 0)
    end
    local upgradeChamber -- forward-declared: wireUpgradeRequest needs it before it is defined
    local function wireUpgradeRequest(model, index)
        model.RequestIncubatorUpgrade.Event:Connect(function(player, adminActor)
            upgradeChamber(player, index, adminActor)
        end)
    end
    -- Unparented chamber model for the given level, with its RequestIncubatorUpgrade event (not wired yet).
    local function makeChamber(index, level)
        local model = incubatorTemplates["Level" .. level]:Clone()
        model.Name = "Chamber" .. index
        model:SetAttribute("ChamberIndex", index)
        model:SetAttribute("UpgradeLevel", level)
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
        wireUpgradeRequest(model, index)
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
    -- Animated build/upgrade (runs in its own thread). Always clears `busy` at the end unless the plot changed
    -- owner meanwhile (then the new ownership pass already reset everything). On failure it falls back to an
    -- instant placement.
    local function constructChamber(player, index, level, oldChamber)
        local expectedOwner = plot:GetAttribute("OwnerUserId")
        local myGeneration = generation
        local function stillValid()
            return plot.Parent ~= nil
                and generation == myGeneration
                and plot:GetAttribute("OwnerUserId") == expectedOwner
                and expectedOwner ~= 0
        end
        busy = true
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
            wireUpgradeRequest(model, index)
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
            if not current or current:GetAttribute("UpgradeLevel") ~= level then
                placeChamber(index, level)
            end
        end
        local current = chambers:FindFirstChild("Chamber" .. index)
        if current then
            current:SetAttribute("UnderConstruction", nil)
        end
        busy = false
        refresh()
    end
    upgradeChamber = function(player, index, adminActor)
        if busy then
            return
        end
        local oldChamber = chambers:FindFirstChild("Chamber" .. index)
        if not oldChamber then
            return
        end
        local level = oldChamber:GetAttribute("UpgradeLevel") or 1
        if
            level >= MAX_CHAMBER_LEVEL
            or oldChamber:GetAttribute("UnderConstruction")
            or (oldChamber:GetAttribute("Status") or "Ready") ~= "Ready"
        then
            return
        end
        if not isAuthorizedOwner(player, plot.TempleAnchor, adminActor) then
            return
        end
        if
            not adminActor
            and not require(game.ReplicatedStorage.UpgradePrices).Charge(
                player,
                require(game.ReplicatedStorage.UpgradePrices).IncubatorLevel[level + 1]
            )
        then
            return
        end
        -- Lock synchronously before dispatch: repeated clicks cannot queue upgrades.
        busy = true
        refresh()
        oldChamber:SetAttribute("UnderConstruction", true)
        task.spawn(constructChamber, player, index, level + 1, oldChamber)
    end
    local function addChamber(player, adminActor)
        if
            busy
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
        busy = true
        refresh()
        task.spawn(constructChamber, player, index, 1, nil)
    end
    -- Owner joined/left: cancel running builds and rebuild the chambers from the new owner's save.
    local function onOwnershipChanged()
        generation += 1
        busy = false
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
