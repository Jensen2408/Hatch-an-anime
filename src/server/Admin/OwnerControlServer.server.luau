--[[ ServerScriptService.OwnerControlServer  (Script)
Owner game-control dispatcher (gifts, river eggs, live events, moderation, plus everything in OwnerGameActions).

Entry points
  ReplicatedStorage.OwnerControl (RemoteFunction, legacy owner UI): OnServerInvoke(player, action, payload) ->
      { Ok = boolean, Message = string, ... }. Only OWNER_USER_ID gets past the first check.
  script.Dispatch (BindableFunction, server only): OnInvoke(player, action, payload). Used by OwnerPanelServer, which
      has already checked AdminRoles.Can for the panel action and maps it to the dispatch action name.
  TextChatCommand "OpenOwnerPanel" (/owner): fires ReplicatedStorage.OwnerPanelOpen to the owner.

Who is authorized (checked in dispatch): OWNER_USER_ID for every action; an AdminRoles "Admin" only for the dispatch
actions listed in ADMIN_BRIDGE. OwnerGameActions.Run re-checks AdminRoles.Role ~= nil.
Trusted input: action must be a string and payload a table (or nil); every payload field is validated per action
(asserts). Per-player rate limit: one request at a time and >= 0.2 s apart. Errors become { Ok = false, Message }.
Kick / Ban24h / Unban refuse the owner account; bans use Players:BanAsync (universe-wide, 24 h).
Owner UserId is hard-coded here (also in AdminRoles, OwnerShowcase, OwnerOverheadBanner...).
]]
-- ===== 1. Services and dependencies =====
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local OWNER_USER_ID = 168774222
local Catalog = require(ReplicatedStorage:WaitForChild("CharacterCatalog"))
local EggCharacterRewards = require(script.Parent:WaitForChild("EggCharacterRewards"))
local OwnerGameActions = require(script.Parent:WaitForChild("OwnerGameActions"))
local AdminRoles = require(script.Parent:WaitForChild("AdminRoles"))
-- Dispatch actions an Admin may run through the Dispatch bindable (everything else is owner-only).
local ADMIN_BRIDGE = {
    Info = true,
    SpawnRiverEgg = true,
    StartEvent = true,
    StopEvent = true,
    SetSpawnInterval = true,
    GoHome = true,
    Bring = true,
    TeleportTo = true,
    SendToPlayer = true,
    Respawn = true,
}

-- ===== 2. State =====
local ownerControlRemote = ReplicatedStorage:WaitForChild("OwnerControl")
-- lastRequestAt / busy: per-player rate limit. activeEvent: the one running live event in this server.
local lastRequestAt = {}
local busy = {}
local activeEvent = nil
-- Owner-only gift entry (Golden Pirate). Its templates live in ServerStorage.FutureUpdateContent.<kind>.
local GOLD_ENTRY = { Id = "Pirate", Name = "Golden Pirate", Rarity = "Legendary", Price = 0, OwnerGold = true }

-- ===== 3. Helpers =====
local function goldTemplate(kind)
    local future = game.ServerStorage:FindFirstChild("FutureUpdateContent")
    local folder = future and future:FindFirstChild(kind)
    return folder and folder:FindFirstChild("Golden Pirate")
end
-- Username or UserId -> userId, player-in-this-server (player is nil when offline). nil for invalid input.
local function resolveTarget(raw)
    if type(raw) ~= "string" or #raw > 50 then
        return nil
    end
    local id = tonumber(raw)
    if id then
        if id < 1 or id % 1 ~= 0 then
            return nil
        end
        return id, Players:GetPlayerByUserId(id)
    end
    for _, onlinePlayer in ipairs(Players:GetPlayers()) do
        if onlinePlayer.Name:lower() == raw:lower() then
            return onlinePlayer.UserId, onlinePlayer
        end
    end
    local ok, result = pcall(Players.GetUserIdFromNameAsync, Players, raw)
    if ok then
        return result, Players:GetPlayerByUserId(result)
    end
end
-- Restores whatever the active event changed and clears the replicated event attributes.
local function stopEvent()
    if not activeEvent then
        return
    end
    local event = activeEvent
    activeEvent = nil
    if event.Kind == "EggRush" and event.Conveyor.Parent then
        event.Conveyor:SetAttribute("SpawnInterval", event.Before)
    elseif event.Kind == "DoubleCash" then
        workspace:SetAttribute("OwnerIncomeMultiplier", event.Before)
    elseif event.Kind == "GoldenHour" then
        Lighting.ClockTime = event.Before
    end
    workspace:SetAttribute("OwnerEventName", nil)
    workspace:SetAttribute("OwnerEventEnds", nil)
end

-- ===== 4. Dispatcher (permission check, validation, rate limit, actions) =====
local dispatch = function(player, action, payload)
    if player.UserId ~= OWNER_USER_ID and not (AdminRoles.Role(player) == "Admin" and ADMIN_BRIDGE[action]) then
        return { Ok = false, Message = "Owner access only." }
    end
    if type(action) ~= "string" or (payload ~= nil and type(payload) ~= "table") then
        return { Ok = false, Message = "Invalid request." }
    end
    if busy[player] or os.clock() - (lastRequestAt[player] or -100) < 0.2 then
        return { Ok = false, Message = "Please wait a moment." }
    end
    lastRequestAt[player] = os.clock()
    busy[player] = true
    payload = payload or {}
    if type(payload.Target) == "string" then
        local normalized = payload.Target:upper():gsub("%s", "")
        if normalized == "ALL" or normalized == "LOBBY" then
            payload.Target = "ALL"
        end
    end
    local ok, result = pcall(function()
        -- Plot / cash / teleport actions live in OwnerGameActions (it re-checks the role).
        if OwnerGameActions.Handles[action] then
            return OwnerGameActions.Run(player, action, payload)
        -- Catalog + roster snapshot for the panel.
        elseif action == "Info" then
            local items = {}
            for _, catalogEntry in ipairs(Catalog.Order) do
                table.insert(items, {
                    Id = catalogEntry.Id,
                    Name = catalogEntry.Name,
                    Rarity = catalogEntry.Rarity,
                    Price = catalogEntry.Price,
                    CharacterAvailable = game.ServerStorage.BrainrotModels:FindFirstChild(catalogEntry.Id) ~= nil,
                    Reserved = false,
                    EggAvailable = game.ServerStorage.AuxEggTemplates:FindFirstChild(catalogEntry.Id) ~= nil,
                })
            end
            table.insert(items, {
                Id = "Golden Pirate",
                Name = "Golden Pirate • Owner only",
                Rarity = "Legendary",
                Price = 0,
                CharacterAvailable = goldTemplate("Characters") ~= nil,
                EggAvailable = goldTemplate("Eggs") ~= nil,
                Reserved = false,
                NoRiver = true,
            })
            local roster = {}
            for _, rosterPlayer in ipairs(Players:GetPlayers()) do
                table.insert(
                    roster,
                    { Id = rosterPlayer.UserId, Name = rosterPlayer.Name, Display = rosterPlayer.DisplayName }
                )
            end
            return { Ok = true, Items = items, Players = roster, Event = activeEvent and activeEvent.Kind or "None" }
        elseif action == "SpawnRiverEgg" then
            assert(payload.Id ~= "Golden Pirate", "Golden items are owner gifts only; river spawning is disabled.")
            local entry = type(payload.Id) == "string" and Catalog.ById[payload.Id]
            assert(entry, "Choose an egg.")
            local isMutation = ({ Silver = 1, Gold = 1, Diamond = 1, Rainbow = 1 })[payload.Mutation]
            local template = game.ServerStorage.AuxEggTemplates:FindFirstChild(entry.Id)
            assert(isMutation or (template and template:GetAttribute("ReleaseEnabled") ~= false), "Egg unavailable.")
            local request = workspace.PirateEggConveyor:FindFirstChild("RequestOwnerRiverEgg")
            assert(request, "River is not ready.")
            local mutation = ({ Silver = 1, Gold = 1, Diamond = 1, Rainbow = 1 })[payload.Mutation] and payload.Mutation
                or nil
            request:Fire(player, entry.Id, mutation)
            return {
                Ok = true,
                Message = mutation
                        and (mutation .. " " .. entry.Id .. " egg queued: it's the next egg down the river.")
                    or (entry.Id .. " egg spawned at the waterfall."),
            }
        elseif action == "SpawnEgg" or action == "SpawnCharacter" then
            local entry = payload.Id == "Golden Pirate" and GOLD_ENTRY
                or (type(payload.Id) == "string" and Catalog.ById[payload.Id])
            assert(entry, "Choose an egg or character.")
            local recipients = payload.Target == "ALL" and Players:GetPlayers()
                or { OwnerGameActions.GetPlayer(player, payload.Target) }
            if payload.Target == "ALL" then
                assert(payload.Confirmed == true, "Confirm gifting to the whole lobby.")
            end
            for _, recipient in ipairs(recipients) do
                assert(recipient:FindFirstChildOfClass("Backpack"), "A player backpack is not ready. Try again.")
            end
            for _, recipient in ipairs(recipients) do
                local bag = recipient:FindFirstChildOfClass("Backpack")
                assert(bag, "Your backpack is not ready.")
                if action == "SpawnCharacter" then
                    local template = entry.OwnerGold and goldTemplate("Characters")
                        or game.ServerStorage.BrainrotModels:FindFirstChild(entry.Id)
                    assert(template, "Character unavailable.")
                    local gift = EggCharacterRewards.Tool(template, entry.Id)
                    if entry.OwnerGold then
                        gift:SetAttribute("GoldVariant", true)
                        gift:SetAttribute("Golden", true)
                        gift.Name = "Golden Pirate Character"
                    end
                    if not gift:GetAttribute("ItemId") then
                        gift:SetAttribute("ItemId", game:GetService("HttpService"):GenerateGUID(false))
                    end
                    gift.Parent = bag
                else
                    local template = entry.OwnerGold and goldTemplate("Eggs")
                        or game.ServerStorage.AuxEggTemplates:FindFirstChild(entry.Id)
                    assert(
                        template and (entry.OwnerGold or template:GetAttribute("ReleaseEnabled") ~= false),
                        "Egg unavailable."
                    )
                    local tool = Instance.new("Tool")
                    tool.Name = entry.Id .. " Egg"
                    tool.CanBeDropped = false
                    Catalog.Stamp(tool, entry)
                    tool:SetAttribute("EggType", entry.Id)
                    tool:SetAttribute("OwnerSpawned", true)
                    tool.ToolTip = entry.Rarity .. " • Owner test egg"
                    if entry.OwnerGold then
                        tool.Name = "Golden Pirate Egg"
                        tool:SetAttribute("GoldVariant", true)
                        tool:SetAttribute("Golden", true)
                    end
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
                    for _, part in ipairs(visual:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.Anchored = false
                            part.CanCollide = false
                            part.CanTouch = false
                            part.Massless = true
                            local weld = Instance.new("WeldConstraint")
                            weld.Part0 = handle
                            weld.Part1 = part
                            weld.Parent = handle
                        elseif part:IsA("BaseScript") then
                            part:Destroy()
                        end
                    end
                    tool.Parent = bag
                end
            end
            return { Ok = true, Message = entry.Name .. " given to " .. #recipients .. " player(s)." }
        -- Unreachable: OwnerGameActions.Handles.GiveCash is checked first (kept as-is).
        elseif action == "GiveCash" then
            local amount = tonumber(payload.Amount)
            assert(
                amount and amount == amount and amount > 0 and amount <= 1000000000000,
                "Enter an amount from 1 to 1 trillion."
            )
            local cash = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Cash")
            assert(cash, "Cash is not ready.")
            cash.Value = math.min(cash.Value + math.floor(amount), 1000000000000000)
            return { Ok = true, Message = "Test cash added to your account." }
        elseif action == "StartEvent" then
            assert(
                payload.Kind == "EggRush" or payload.Kind == "DoubleCash" or payload.Kind == "GoldenHour",
                "Unknown event."
            )
            local duration = tonumber(payload.Duration) or 120
            assert(duration == duration and duration >= 15 and duration <= 1800, "Duration must be 15–1800 seconds.")
            assert(not activeEvent, "Stop the active event before starting another.")
            local event = { Kind = payload.Kind }
            if event.Kind == "EggRush" then
                event.Conveyor = workspace:FindFirstChild("PirateEggConveyor")
                assert(event.Conveyor, "River unavailable.")
                event.Before = event.Conveyor:GetAttribute("SpawnInterval") or 4
                event.Conveyor:SetAttribute("SpawnInterval", math.max(1.5, event.Before * 0.5))
            elseif event.Kind == "DoubleCash" then
                event.Before = workspace:GetAttribute("OwnerIncomeMultiplier") or 1
                workspace:SetAttribute("OwnerIncomeMultiplier", 2)
            else
                event.Before = Lighting.ClockTime
                Lighting.ClockTime = 17.4
            end
            activeEvent = event
            workspace:SetAttribute("OwnerEventName", event.Kind)
            workspace:SetAttribute("OwnerEventEnds", workspace:GetServerTimeNow() + duration)
            task.delay(duration, function()
                if activeEvent == event then
                    stopEvent()
                end
            end)
            return { Ok = true, Message = event.Kind .. " started in this server for " .. duration .. " seconds." }
        elseif action == "StopEvent" then
            stopEvent()
            return { Ok = true, Message = "Event stopped; original settings restored." }
        -- Moderation. Note: dispatch-level Kick is owner-only; admin kicks are handled in OwnerPanelServer.
        elseif action == "Kick" or action == "Ban24h" or action == "Unban" then
            assert(payload.Confirmed == true, "Confirm this moderation action first.")
            local targetId, targetPlayer = resolveTarget(payload.Target)
            assert(targetId, "Enter an exact username or numeric User ID.")
            assert(targetId ~= OWNER_USER_ID, "Your owner account is protected.")
            if action == "Kick" then
                assert(targetPlayer, "That player is not in this server.")
                targetPlayer:Kick("Removed by the game owner.")
            else
                assert(
                    not RunService:IsStudio(),
                    "Persistent bans must be used in the published game; Studio is a preview."
                )
                if action == "Ban24h" then
                    Players:BanAsync({
                        UserIds = { targetId },
                        Duration = 86400,
                        ApplyToUniverse = true,
                        DisplayReason = "Temporarily banned by the game owner.",
                        PrivateReason = "Owner panel: 24 hour ban by " .. player.UserId,
                        ExcludeAltAccounts = true,
                        ApplyDeviceBlock = false,
                    })
                else
                    Players:UnbanAsync({ UserIds = { targetId }, ApplyToUniverse = true })
                end
            end
            return { Ok = true, Message = action .. " completed for User ID " .. targetId .. "." }
        end
        return { Ok = false, Message = "Unknown action." }
    end)
    busy[player] = nil
    if not ok then
        return { Ok = false, Message = tostring(result):gsub("^.-:%d+: ", "") }
    end
    return result
end

-- ===== 5. Entry points =====
ownerControlRemote.OnServerInvoke = function(player, ...)
    if player.UserId ~= OWNER_USER_ID then
        return { Ok = false, Message = "Owner access only." }
    end
    return dispatch(player, ...)
end
Players.PlayerRemoving:Connect(function(leavingPlayer)
    lastRequestAt[leavingPlayer] = nil
    busy[leavingPlayer] = nil
end)
local TextChatService = game:GetService("TextChatService")
local command = TextChatService:FindFirstChild("OpenOwnerPanel") or Instance.new("TextChatCommand")
command.Name = "OpenOwnerPanel"
command.PrimaryAlias = "/owner"
command.Parent = TextChatService
command.Triggered:Connect(function(source)
    if source and source.UserId == OWNER_USER_ID then
        local ownerPlayer = Players:GetPlayerByUserId(OWNER_USER_ID)
        if ownerPlayer then
            ReplicatedStorage.OwnerPanelOpen:FireClient(ownerPlayer)
        end
    end
end)

-- Shared owner dispatcher for the v3 interface; all checks remain in this server.
local bridge = script:FindFirstChild("Dispatch") or Instance.new("BindableFunction")
bridge.Name = "Dispatch"
bridge.Parent = script
bridge.OnInvoke = function(player, action, payload)
    return dispatch(player, action, payload)
end
