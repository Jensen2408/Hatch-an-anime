--[[ ServerScriptService.OwnerGameActions  (ModuleScript, server only)
Plot / cash / teleport actions for the owner dispatcher. Only OwnerControlServer's dispatch calls Run, after its own
permission check (owner, or admin for ADMIN_BRIDGE actions) and rate limit.

Who is authorized: Run re-asserts AdminRoles.Role(owner) ~= nil (any staff). Owner-vs-admin per action is decided by
the callers (AdminRoles.Can in OwnerPanelServer, ADMIN_BRIDGE in OwnerControlServer), not here.
Trusted input: payload comes from the staff client through OwnerPanelServer; Target / Destination / Amount / Index are
validated here. Errors are raised with assert / error and turned into { Ok = false, Message } by the caller.
API: Handles (set of action names), Run(owner, action, payload) -> { Ok, Message }, GetPlayer(owner, value).
Known issue (docs/PROJECT_AUDIT.md): Respawn uses LoadCharacterAsync, which does not fire Died, so the backpack is lost.
]]
-- ===== 1. Services and action set =====
local Players = game:GetService("Players")
local TempleSlotUnlocks = require(script.Parent.TempleSlotUnlocks)
local OwnerGameActions = {}
OwnerGameActions.Handles = {
    GiveCash = true,
    SetCash = true,
    UnlockSlots = true,
    UnlockNextSlot = true,
    ResetSlots = true,
    ClearPlaced = true,
    ClearInventory = true,
    Respawn = true,
    TeleportTo = true,
    Bring = true,
    SendToPlayer = true,
    GoHome = true,
    UpgradeTemple = true,
    AddChamber = true,
    UpgradeChamber = true,
    SetSpawnInterval = true,
}

-- ===== 2. Helpers =====
-- "" / nil / "me" -> owner; otherwise exact UserId or username, then a unique DisplayName, in this server only.
local function getPlayer(owner, value)
    if type(value) == "string" then
        value = value:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^@", "")
    end
    if value == nil or value == "" or value:upper() == "ME" then
        return owner
    end
    assert(type(value) == "string" and #value <= 50, "Enter an exact username or User ID.")
    for _, candidate in ipairs(Players:GetPlayers()) do
        if tostring(candidate.UserId) == value or candidate.Name:lower() == value:lower() then
            return candidate
        end
    end
    local matches = {}
    for _, candidate in ipairs(Players:GetPlayers()) do
        if candidate.DisplayName:lower() == value:lower() then
            table.insert(matches, candidate)
        end
    end
    if #matches == 1 then
        return matches[1]
    end
    if #matches > 1 then
        error("Multiple players share that display name. Use their @username or User ID.")
    end
    error("That player is not in this server.")
end
local function findPlot(player)
    for _, plot in ipairs(workspace.Plots:GetChildren()) do
        if plot:GetAttribute("OwnerUserId") == player.UserId then
            return plot
        end
    end
    error("That player has no plot.")
end
local function getRootPart(player)
    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    assert(rootPart, "Character is not ready.")
    return rootPart
end

-- ===== 3. Run =====
function OwnerGameActions.Run(owner, action, payload)
    assert(require(script.Parent.AdminRoles).Role(owner) ~= nil, "Staff access only.")
    if type(payload.Target) == "string" then
        local normalized = payload.Target:upper():gsub("%s", "")
        if normalized == "LOBBY" or normalized == "ALL" then
            payload.Target = "ALL"
        end
    end
    -- Lobby-wide actions first (no target player).
    if action == "SetSpawnInterval" then
        local interval = tonumber(payload.Amount)
        assert(
            interval and interval == interval and interval >= 1.5 and interval <= 30,
            "Spawn interval must be 1.5–30 seconds."
        )
        assert(not workspace:GetAttribute("OwnerEventName"), "Stop the active event before changing spawn timing.")
        workspace.PirateEggConveyor:SetAttribute("SpawnInterval", interval)
        return { Ok = true, Message = "River spawn interval: " .. interval .. " seconds." }
    end
    if action == "GiveCash" or action == "SetCash" then
        local amount = tonumber(payload.Amount)
        assert(
            amount and amount == amount and amount >= 0 and amount < math.huge,
            "Enter a finite, non-negative amount."
        )
        if action == "SetCash" then
            assert(payload.Confirmed, "Confirm replacing the player's cash.")
        end
        local recipients = payload.Target == "ALL" and Players:GetPlayers() or { getPlayer(owner, payload.Target) }
        if payload.Target == "ALL" then
            assert(payload.Confirmed, "Confirm giving money to everyone.")
            assert(action == "GiveCash", "Set cash supports one player at a time.")
        end
        local changed = 0
        for _, recipient in ipairs(recipients) do
            local cash = recipient:FindFirstChild("leaderstats") and recipient.leaderstats:FindFirstChild("Cash")
            if cash then
                assert(cash.Value + amount < math.huge, "Amount is too large for numeric storage.")
                cash.Value = action == "GiveCash" and (cash.Value + math.floor(amount)) or math.floor(amount)
                changed += 1
            end
        end
        assert(changed > 0, "Player cash is not ready.")
        return {
            Ok = true,
            Message = (action == "GiveCash" and "Added $" or "Set cash to $")
                .. math.floor(amount)
                .. " for "
                .. changed
                .. " player(s).",
        }
    end
    -- Single-player actions from here on.
    local targetPlayer = getPlayer(owner, payload.Target)
    if action == "ClearInventory" then
        assert(payload.Confirmed, "Confirm clearing inventory.")
        for _, container in ipairs({ targetPlayer:FindFirstChildOfClass("Backpack"), targetPlayer.Character }) do
            if container then
                for _, tool in ipairs(container:GetChildren()) do
                    if tool:IsA("Tool") then
                        tool:Destroy()
                    end
                end
            end
        end
    elseif action == "Respawn" then
        assert(payload.Confirmed, "Confirm respawning this player.")
        targetPlayer:LoadCharacterAsync()
    elseif action == "TeleportTo" then
        getRootPart(owner)
        owner.Character:PivotTo(getRootPart(targetPlayer).CFrame * CFrame.new(4, 0, 0))
    elseif action == "Bring" then
        getRootPart(targetPlayer)
        targetPlayer.Character:PivotTo(getRootPart(owner).CFrame * CFrame.new(4, 0, 0))
    elseif action == "SendToPlayer" then
        assert(
            type(payload.Destination) == "string" and payload.Destination ~= "ALL",
            "Choose an online destination player."
        )
        local destination = getPlayer(owner, payload.Destination)
        assert(destination ~= targetPlayer, "Choose a different destination player.")
        local sourceRoot = getRootPart(targetPlayer)
        local destinationRoot = getRootPart(destination)
        local sourceHumanoid = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
        local destinationHumanoid = destination.Character:FindFirstChildOfClass("Humanoid")
        assert(
            sourceHumanoid and sourceHumanoid.Health > 0 and destinationHumanoid and destinationHumanoid.Health > 0,
            "Both characters must be alive."
        )
        targetPlayer.Character:PivotTo(destinationRoot.CFrame * CFrame.new(4.5, 0, 0))
        sourceRoot.AssemblyLinearVelocity = Vector3.zero
        sourceRoot.AssemblyAngularVelocity = Vector3.zero
        return { Ok = true, Message = "Teleported @" .. targetPlayer.Name .. " to @" .. destination.Name .. "." }
    elseif action == "GoHome" then
        getRootPart(targetPlayer)
        targetPlayer.Character:PivotTo(findPlot(targetPlayer).PlotSpawn.CFrame * CFrame.new(0, 4, 0))
    else
        -- Plot actions. Temple / incubator upgrades go through the plot's own request bindables (free for staff).
        local plot = findPlot(targetPlayer)
        if action == "UnlockNextSlot" then
            local ordered = plot.Slots:GetChildren()
            table.sort(ordered, function(slotA, slotB)
                return slotA.Name < slotB.Name
            end)
            for _, slot in ipairs(ordered) do
                if
                    (tonumber(slot.Name:match("%d+")) or 1) <= TempleSlotUnlocks.Capacity(plot)
                    and not slot:GetAttribute("Unlocked")
                then
                    slot:SetAttribute("Unlocked", true)
                    TempleSlotUnlocks.Refresh(plot)
                    return { Ok = true, Message = slot.Name .. " unlocked for @" .. targetPlayer.Name .. "." }
                end
            end
            error("All character slots are already unlocked.")
        elseif action == "UnlockSlots" then
            for _, slot in ipairs(plot.Slots:GetChildren()) do
                if (tonumber(slot.Name:match("%d+")) or 1) <= TempleSlotUnlocks.Capacity(plot) then
                    slot:SetAttribute("Unlocked", true)
                end
            end
            TempleSlotUnlocks.Refresh(plot)
        elseif action == "ResetSlots" then
            assert(payload.Confirmed, "Confirm resetting slot unlocks.")
            for _, slot in ipairs(plot.Slots:GetChildren()) do
                assert(not slot:GetAttribute("Occupied"), "Clear placed characters before resetting slots.")
            end
            TempleSlotUnlocks.Reset(plot)
        elseif action == "ClearPlaced" then
            assert(payload.Confirmed, "Confirm clearing placed characters.")
            plot.PlacedItems:ClearAllChildren()
            for _, slot in ipairs(plot.Slots:GetChildren()) do
                slot:SetAttribute("Occupied", false)
                slot:SetAttribute("PlacementToken", nil)
            end
            TempleSlotUnlocks.Refresh(plot)
        elseif action == "UpgradeTemple" then
            assert(TempleSlotUnlocks.CanUpgrade(plot), "Buy all current slots before upgrading the temple.")
            assert(not plot:GetAttribute("TempleBuilding"), "Temple is already upgrading.")
            assert((plot:GetAttribute("TempleLevel") or 1) < 3, "Temple is already level 3.")
            plot.RequestUpgrade:Fire(targetPlayer, owner)
        elseif action == "AddChamber" then
            assert((plot:GetAttribute("ChamberCount") or 0) < 3, "The plot already has 3 incubators.")
            assert(not plot:GetAttribute("ChamberBuilding"), "An incubator is already upgrading.")
            plot.RequestChamberUpgrade:Fire(targetPlayer, owner)
        elseif action == "UpgradeChamber" then
            local chamberIndex = tonumber(payload.Index)
            assert(
                chamberIndex and chamberIndex % 1 == 0 and chamberIndex >= 1 and chamberIndex <= 3,
                "Choose incubator 1, 2, or 3."
            )
            local chamber = plot.Chambers:FindFirstChild("Chamber" .. chamberIndex)
            assert(chamber, "That incubator has not been built.")
            -- upgrades every incubator one level (PlotChambers); busy incubators are fine
            assert((plot:GetAttribute("IncubatorLevel") or 1) < 3, "Incubators are already level 3.")
            assert(not plot:GetAttribute("ChamberBuilding"), "An incubator is still being built.")
            chamber.RequestIncubatorUpgrade:Fire(targetPlayer, owner)
        end
    end
    return { Ok = true, Message = action .. " applied to @" .. targetPlayer.Name .. "." }
end
OwnerGameActions.GetPlayer = getPlayer
return OwnerGameActions
