--[[ PlayerDataService — saves and restores each player's progress.
Runtime: Script in ServerScriptService. DataStore "PlayerData_v1", key "u<UserId>".

Saved: Cash (+ uncollected stand cash), backpack/held/incubating egg + character tools, placed characters (same slot),
unlocked slots, temple level, incubator count/levels, index discoveries, quests, tutorial progress, settings.
Safety: never saves if the load failed (no wipes), session lock so two servers can't load the same player at once,
autosave every AUTOSAVE_INTERVAL (30 s), save on leave and on server shutdown. In Studio without API access it runs
session-only (in-memory store).

SAVED SCHEMA (one table per player; field names are a persistence contract — never rename):
    v                       number   schema VERSION (1)
    savedAt                 number   os.time() of the last save (drives offline earnings, capped at 8 h)
    lock                    table?   { job = game.JobId, t = os.time() } while a server owns the session; nil once released
    restoredAt              number?  only written by SaveRestore (owner panel rollback)
    cash                    number   floor(Cash + uncollected stand cash on the final save), >= 0
    tools                   array    tool records (backpack, RespawnHold, IncubatorHeldEggs, character, carried-over)
    placed                  array    { s = slotName, k = "char", n = ToolName attribute, a = attributes }
    unlocked                array?   slot names with attribute Unlocked (only written when the plot has >= 1 unlocked)
    chambers                array?   incubator UpgradeLevel for ChamberIndex 1..3, nil entries skipped (compacted)
    templeLevel             number   plot attribute TempleLevel
    tutorialCompleted       boolean
    tutorialIncomeCollected boolean
    tutorialTourStage       number   9..12 (clamped on load)
    settings                table?   SETTING_TYPES keys only (written by the SaveSettings remote)
    discovered              any      GameAdapter.ExportDiscovered(player) / ImportDiscovered
    quests                  any      QuestService.Persistence.Save/Load payload
  Tool record: { k = "char" | "egg", n = Tool.Name, a = { string/number/boolean attributes },
                 inc = { c = ChamberIndex, left = seconds of hatching left }? } (inc only for eggs in an incubator)

FLOW
    Load:  PlayerAdded -> onJoin -> loadData (UpdateAsync, takes the lock, 8 attempts) -> player attributes
           (DataLoaded, Tutorial*, SavedTempleLevel, SavedChambers, settings) -> task.spawn restoreSavedState
           (cash, tools, slots, placed characters, offline earnings, incubating eggs) -> TutorialDataReady.
    Save:  snapshot (live state -> sessionData[player]) then saveData (UpdateAsync, 3 attempts, respects foreign locks).
           Triggers: autosave loop, PlayerRemoving, BindToClose, the PlayerDataSaveAll / PlayerDataSaveNow hooks.
    Failure handling: load failure (not Studio / not left) kicks the player so nothing is overwritten; snapshot keeps the
           loaded save untouched until cash was restored (restoreState.cash) and only rewrites items / plot once the
           whole restore finished (restoreState.all). Records that cannot be rebuilt are carried in the save (unbuildable).
    Known issue: see docs/PROJECT_AUDIT.md "PlayerData restore" — saved tools are given before the plot wait.

Other scripts: PlotManager waits for player attribute "DataLoaded" and calls ServerStorage.PlayerDataSnapshot before it
clears the plot; CrossServerService (/update) calls PlayerDataSaveAll; ShopService calls PlayerDataSaveNow.
Creates: ReplicatedStorage.SaveSettings (RemoteEvent), ServerStorage.PlayerDataSaveAll / PlayerDataSaveNow /
PlayerDataSnapshot (BindableFunctions), ServerStorage.PlayerDataDebug (Studio only).
]]

-- Services
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Constants
local STORE_NAME, VERSION = "PlayerData_v1", 1
-- LOCK_TIMEOUT: a lock older than this (seconds) is considered abandoned by a crashed server and can be taken over.
-- SaveRestore hard-codes the same 150.
local AUTOSAVE_INTERVAL, LOCK_TIMEOUT = 30, 150

-- DataStore (nil when unavailable -> load() returns "nostore" and the session is not saved)
local okStore, store = pcall(DataStoreService.GetDataStore, DataStoreService, STORE_NAME)
if not okStore then
    store = nil
end
-- Studio: real DataStores are blocked unless API access is on, so use an in-memory practice store (nothing persists)
if RunService:IsStudio() then
    local probeOk = pcall(function()
        store:GetAsync("__probe")
    end)
    if not probeOk then
        local memoryStore = {}
        store = {
            UpdateAsync = function(_, key, transform)
                local newValue = transform(memoryStore[key])
                if newValue ~= nil then
                    memoryStore[key] = newValue
                end
                return newValue
            end,
        }
        warn("[PlayerData] Studio: using in-memory practice store (saves do not persist between play tests)")
    end
end

-- Dependencies
local Catalog = require(ReplicatedStorage:WaitForChild("CharacterCatalog"))
local Economy = require(ReplicatedStorage:WaitForChild("CharacterEconomy"))
local EggCharacterRewards = require(ServerScriptService:WaitForChild("EggCharacterRewards"))
local TempleSlotUnlocks = require(ServerScriptService:WaitForChild("TempleSlotUnlocks"))
local QuestService -- optional: nil when GameMenu.QuestService fails to load
do
    local ok, module = pcall(require, ServerScriptService:WaitForChild("GameMenu"):WaitForChild("QuestService"))
    QuestService = ok and module or nil
end
local GameAdapter -- optional: nil when GameMenu.GameAdapter fails to load
do
    local ok, module = pcall(require, ServerScriptService.GameMenu:WaitForChild("GameAdapter"))
    GameAdapter = ok and module or nil
end
local brainrotModels = ServerStorage:WaitForChild("BrainrotModels")

-- State (all keyed by Player; cleared in onLeave)
-- sessionData: the save table being edited live; isLoaded: the save was loaded (only then may we write it back);
-- hasFinalSnapshot: the leave/shutdown snapshot was already taken; lastHeldTools: records of tools held by the last
-- character (used when the player leaves without a character); lastSettingsAt: SaveSettings rate limit.
local sessionData, isLoaded, hasFinalSnapshot, lastHeldTools = {}, {}, {}, {}
local lastSettingsAt = {}
local restoreState = {} -- [p] = { cash = bool, all = bool }: only overwrite saved fields once they were restored in-game
local unbuildable = {} -- [p] = records that could not be rebuilt; kept in the save instead of being deleted

------------------------------------------------------------ helpers
local function plotOf(player)
    for _, plot in workspace.Plots:GetChildren() do
        if plot:GetAttribute("OwnerUserId") == player.UserId then
            return plot
        end
    end
end
local function cashOf(player)
    local leaderstats = player:FindFirstChild("leaderstats")
    return leaderstats and leaderstats:FindFirstChild("Cash")
end
-- Copies the attributes that a DataStore can hold (string / number / boolean).
local function copyAttributes(instance)
    local result = {}
    for name, value in instance:GetAttributes() do
        local valueType = typeof(value)
        if valueType == "string" or valueType == "number" or valueType == "boolean" then
            result[name] = value
        end
    end
    return result
end
-- Placement / incubator bookkeeping attributes: never copied back onto a rebuilt tool.
local SKIPPED_ATTRIBUTES =
    { Occupied = true, OwnerUserId = true, PlacementToken = true, SlotName = true, IncubatorChamber = true }
local function serializeTool(tool)
    if not tool:IsA("Tool") then
        return nil
    end
    local attributes = copyAttributes(tool)
    if attributes.CharacterId or attributes.BrainrotId then
        return { k = "char", n = tool.Name, a = attributes }
    end
    if attributes.EggType then
        return { k = "egg", n = tool.Name, a = attributes }
    end
    return nil -- bat and other gear are given by their own scripts
end

------------------------------------------------------------ rebuild (saved record -> Tool)
local function goldenTemplate()
    local futureContent = ServerStorage:FindFirstChild("FutureUpdateContent")
    local characters = futureContent and futureContent:FindFirstChild("Characters")
    return characters and characters:FindFirstChild("Golden Pirate")
end
local function buildCharacterTool(record)
    local attributes = record.a
    local characterId = attributes.CharacterId or attributes.BrainrotId
    if not characterId or not Catalog.ById[characterId] then
        return nil
    end
    local template = (attributes.GoldVariant or attributes.Golden) and goldenTemplate()
        or brainrotModels:FindFirstChild(characterId)
    if not template then
        return nil
    end
    -- Economy.Read reads stats from attributes, so stage the saved attributes on a throwaway instance
    local attributeProbe = Instance.new("Folder")
    for name, value in attributes do
        attributeProbe:SetAttribute(name, value)
    end
    local stats = Economy.Read(attributeProbe, characterId) or Economy.Roll(characterId)
    attributeProbe:Destroy()
    local ok, tool = pcall(EggCharacterRewards.Tool, template, characterId, stats, attributes.Mutation or false)
    if not ok or not tool then
        warn("[PlayerData] char rebuild failed", characterId, tool)
        return nil
    end
    for name, value in attributes do
        if not SKIPPED_ATTRIBUTES[name] then
            tool:SetAttribute(name, value)
        end
    end
    if record.n then
        tool.Name = record.n
    end
    return tool
end
local function buildEggTool(record)
    local attributes = record.a
    local eggType = attributes.EggType
    local template
    if attributes.UnknownEgg then
        template = ReplicatedStorage.ShopSystem.ShopModels:FindFirstChild("UnknownEgg")
    else
        template = ServerStorage.AuxEggTemplates:FindFirstChild(eggType)
    end
    if not template and not attributes.UnknownEgg then
        return nil
    end
    local tool = Instance.new("Tool")
    tool.Name = record.n or (eggType .. " Egg")
    tool.CanBeDropped = false
    local entry = Catalog.ById[eggType]
    if entry then
        pcall(Catalog.Stamp, tool, entry)
    end
    for name, value in attributes do
        if not SKIPPED_ATTRIBUTES[name] then
            tool:SetAttribute(name, value)
        end
    end
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.one
    handle.Transparency = 1
    handle.CanCollide = false
    handle.Massless = true
    handle.Parent = tool
    -- saved mutation eggs come back as their mutated model (same size as the plain egg) with the aura VFX
    local mutatedModel
    if attributes.Mutation and template and not attributes.UnknownEgg then
        local mutationPack = ServerStorage:FindFirstChild("UpdatePack_Mutations_Halloween")
        local mutationEggs = mutationPack and mutationPack:FindFirstChild("Update_Eggs_Halloween", true)
        mutatedModel = mutationEggs
            and (
                mutationEggs:FindFirstChild(eggType .. "_Halloween_" .. attributes.Mutation .. "_Egg")
                or mutationEggs:FindFirstChild(eggType .. "_" .. attributes.Mutation .. "_Egg")
            )
    end
    if template then
        local visual = (mutatedModel or template):Clone()
        visual.Name = "Egg"
        if attributes.UnknownEgg then
            local _, size = visual:GetBoundingBox()
            visual:ScaleTo(visual:GetScale() * 2.2 / math.max(size.Y, 0.01))
        elseif mutatedModel then
            local _, plainSize = template:GetBoundingBox()
            local _, visualSize = visual:GetBoundingBox()
            visual:ScaleTo(visual:GetScale() * plainSize.Y * 0.5 / math.max(visualSize.Y, 0.01))
            pcall(function()
                require(ServerScriptService.Mutations).AddAura(visual, attributes.Mutation)
            end)
        else
            visual:ScaleTo(template:GetScale() * 0.5)
        end
        visual:PivotTo(CFrame.new())
        for _, descendant in visual:GetDescendants() do
            if descendant:IsA("BasePart") then
                descendant.Anchored = false
                descendant.CanCollide = false
                descendant.CanTouch = false
                descendant.Massless = true
                local weld = Instance.new("WeldConstraint")
                weld.Part0 = handle
                weld.Part1 = descendant
                weld.Parent = handle
            elseif descendant:IsA("BaseScript") then
                descendant:Destroy()
            end
        end
        visual.Parent = tool
    end
    return tool
end
-- Rebuilds one saved record. On failure the record is remembered in unbuildable[player] so the next save keeps it.
local function buildTool(record, player)
    local ok, tool = pcall(function()
        if record.k == "char" then
            return buildCharacterTool(record)
        elseif record.k == "egg" then
            return buildEggTool(record)
        end
    end)
    if not ok or not tool then
        if player then
            unbuildable[player] = unbuildable[player] or {}
            table.insert(unbuildable[player], record)
            warn("[PlayerData] kept unbuildable item in save", player.Name, record.n)
        end
        return nil
    end
    return tool
end

------------------------------------------------------------ snapshot (live state -> table)
-- Writes the player's live state into sessionData[player]. isFinal = leave / shutdown snapshot: also banks uncollected
-- stand cash, uses lastHeldTools when the character is gone, and marks hasFinalSnapshot.
local function snapshot(player, isFinal)
    local saved = sessionData[player]
    if not saved or not isLoaded[player] then
        return
    end
    local restoreFlags = restoreState[player]
    if not restoreFlags or not restoreFlags.cash then
        return
    end -- nothing given back yet: keep the loaded save exactly as it is
    local cash = cashOf(player)
    local plot = plotOf(player)
    local tools, seen = {}, {}
    local function addFrom(container)
        if not container then
            return
        end
        for _, tool in container:GetChildren() do
            if not seen[tool] then
                local record = serializeTool(tool)
                if record then
                    seen[tool] = true
                    table.insert(tools, record)
                end
            end
        end
    end
    addFrom(player:FindFirstChildOfClass("Backpack"))
    addFrom(player:FindFirstChild("RespawnHold")) -- KeepItemsOnRespawn parks eggs/characters here during a respawn
    do
        -- eggs sitting in an incubator: remember which chamber and how much hatch time is left
        local heldEggs = player:FindFirstChild("IncubatorHeldEggs")
        if heldEggs then
            for _, tool in heldEggs:GetChildren() do
                if not seen[tool] then
                    local record = serializeTool(tool)
                    if record then
                        seen[tool] = true
                        local chamberPath = tool:GetAttribute("IncubatorChamber")
                        if plot and chamberPath then
                            for _, chamber in (plot:FindFirstChild("Chambers") and plot.Chambers:GetChildren() or {}) do
                                if chamber:GetFullName() == chamberPath then
                                    local cycleEnd = chamber:GetAttribute("CycleEnd")
                                    record.inc = {
                                        c = chamber:GetAttribute("ChamberIndex") or 1,
                                        left = (chamber:GetAttribute("Hatching") and cycleEnd)
                                                and math.max(0, cycleEnd - workspace:GetServerTimeNow())
                                            or 0,
                                    }
                                end
                            end
                        end
                        record.a.Incubating = nil
                        table.insert(tools, record)
                    end
                end
            end
        end
    end
    if player.Character then
        addFrom(player.Character)
    elseif isFinal then
        for _, record in lastHeldTools[player] or {} do
            table.insert(tools, record)
        end
    end
    local placed, unlocked, standCash, chamberLevelsByIndex = {}, {}, 0, {}
    if plot then
        for _, display in plot.PlacedItems:GetChildren() do
            local slotName = display.Name:match("^(.-)_Brainrot$")
            local attributes = copyAttributes(display)
            if slotName and (attributes.CharacterId or attributes.BrainrotId) then
                table.insert(placed, { s = slotName, k = "char", n = display:GetAttribute("ToolName"), a = attributes })
            end
        end
        for _, slot in plot.Slots:GetChildren() do
            if slot:GetAttribute("Unlocked") then
                table.insert(unlocked, slot.Name)
            end
            local stand = slot:FindFirstChild("MoneyStand")
            if stand and isFinal then
                standCash += tonumber(stand:GetAttribute("Stored")) or 0
            end
        end
        local chambersFolder = plot:FindFirstChild("Chambers")
        if chambersFolder then
            for _, chamber in chambersFolder:GetChildren() do
                local chamberIndex = chamber:GetAttribute("ChamberIndex")
                if chamberIndex then
                    chamberLevelsByIndex[chamberIndex] = chamber:GetAttribute("UpgradeLevel") or 1
                end
            end
        end
        saved.templeLevel = plot:GetAttribute("TempleLevel") or saved.templeLevel or 1
    end
    if cash then
        saved.cash = math.max(0, math.floor(cash.Value + standCash))
    end
    if not restoreFlags.all then -- items / plot not fully restored yet: only cash + flags are safe to update
        if isFinal then
            hasFinalSnapshot[player] = true
        end
        return
    end
    for _, record in unbuildable[player] or {} do
        table.insert(tools, record)
    end
    saved.tools, saved.placed = tools, placed
    saved.tutorialCompleted = player:GetAttribute("TutorialCompleted") == true
    saved.tutorialIncomeCollected = player:GetAttribute("TutorialIncomeCollected") == true
    saved.tutorialTourStage = player:GetAttribute("TutorialTourStage") or 9
    if plot and #unlocked > 0 then
        saved.unlocked = unlocked
        local chamberLevels = {}
        for i = 1, 3 do
            if chamberLevelsByIndex[i] then
                table.insert(chamberLevels, chamberLevelsByIndex[i])
            end
        end
        if #chamberLevels > 0 then
            saved.chambers = chamberLevels
        end
    end
    if GameAdapter and GameAdapter.ExportDiscovered then
        saved.discovered = GameAdapter.ExportDiscovered(player)
    end
    if isFinal then
        hasFinalSnapshot[player] = true
    end
end

------------------------------------------------------------ store
-- Writes sessionData[player]. releaseLock = true clears the session lock (leave / shutdown / SaveAll), otherwise the
-- lock is refreshed. Returns true on success, false when another server holds the lock, nil after 3 failed attempts.
local function saveData(player, releaseLock)
    local saved = sessionData[player]
    if not store or not saved or not isLoaded[player] then
        return
    end
    saved.v = VERSION
    saved.savedAt = os.time()
    saved.lock = (not releaseLock) and { job = game.JobId, t = os.time() } or nil
    for attempt = 1, 3 do
        local blocked = false
        local ok, err = pcall(store.UpdateAsync, store, "u" .. player.UserId, function(stored)
            if
                stored
                and stored.lock
                and stored.lock.job ~= game.JobId
                and os.time() - (stored.lock.t or 0) < LOCK_TIMEOUT
            then
                blocked = true
                return nil
            end -- another server owns it
            return saved
        end)
        if ok and not blocked then
            player:SetAttribute("TempleSaveStatus", "Saved")
            return true
        end
        if blocked then
            warn("[PlayerData] save skipped: another server holds the lock", player.Name)
            return false
        end
        warn("[PlayerData] save failed", player.Name, err)
        task.wait(1 + attempt)
    end
end

-- Loads the save and takes the session lock in the same UpdateAsync. A fresh lock held by another server is respected
-- for 7 attempts; the 8th attempt takes the lock over. Returns (data) or (nil, "nostore" | "studio" | "left" | "failed").
local function loadData(player)
    if not store then
        return nil, "nostore"
    end
    local key = "u" .. player.UserId
    for attempt = 1, 8 do
        local result, lockedElsewhere
        local ok, err = pcall(store.UpdateAsync, store, key, function(stored)
            stored = stored or { v = VERSION }
            if
                stored.lock
                and stored.lock.job ~= game.JobId
                and os.time() - (stored.lock.t or 0) < LOCK_TIMEOUT
                and attempt < 8
            then
                lockedElsewhere = true
                return nil
            end
            stored.lock = { job = game.JobId, t = os.time() }
            result = stored
            return stored
        end)
        if ok and result then
            return result
        end
        if not ok then
            warn("[PlayerData] load error", player.Name, err)
            if tostring(err):find("StudioAccessToApisNotAllowed") or tostring(err):find("Studio access") then
                return nil, "studio"
            end
        end
        if not player.Parent then
            return nil, "left"
        end
        task.wait(lockedElsewhere and 2 or (1 + attempt))
    end
    return nil, "failed"
end

------------------------------------------------------------ apply saved state
-- Polls getter every 0.25 s until it returns a truthy value or timeout (default 20 s) passes; returns that value or nil.
local function waitFor(getter, timeout)
    local startedAt = os.clock()
    repeat
        local value = getter()
        if value then
            return value
        end
        task.wait(0.25)
    until os.clock() - startedAt > (timeout or 20)
end

-- Puts the saved state back into the game. Yields a lot (character, backpack, plot, chambers). restoreState.cash is set
-- right after cash is restored; restoreState.all is only set by restoreSavedState once this returns with a plot.
local function applySavedState(player, saved)
    -- wait for the character: Roblox resets the Backpack when the first character spawns, wiping anything given earlier
    local character = player.Character or waitFor(function()
        return player.Character
    end, 40)
    if not character or not player.Parent then
        return
    end
    waitFor(function()
        return character:FindFirstChild("HumanoidRootPart")
    end, 15)
    task.wait(1)
    local offlineSeconds = math.clamp(os.time() - (tonumber(saved.savedAt) or os.time()), 0, 28800) -- up to 8 h counts (economy v4)
    local cash = waitFor(function()
        return cashOf(player)
    end, 20)
    if cash and saved.cash then
        cash.Value = saved.cash
    end
    restoreState[player] = { cash = cash ~= nil, all = false }
    local backpack = waitFor(function()
        return player:FindFirstChildOfClass("Backpack")
    end, 20)
    -- Known issue (PROJECT_AUDIT "PlayerData restore dup"): tools are given here, before the plot wait below.
    local incubating = {}
    for _, record in saved.tools or {} do
        if record.inc then
            table.insert(incubating, record)
        else
            local tool = buildTool(record, player)
            if tool and backpack then
                tool.Parent = backpack
            end
        end
    end
    local plot = waitFor(function()
        return plotOf(player)
    end, 40)
    if not plot then
        warn("[PlayerData] no plot for", player.Name, "- keeping saved temple/characters untouched")
        return
    end
    for _, slotName in saved.unlocked or {} do
        local slot = plot.Slots:FindFirstChild(slotName)
        if slot then
            slot:SetAttribute("Unlocked", true)
        end
    end
    pcall(TempleSlotUnlocks.Refresh, plot)
    -- placed characters: give the tool, then let the slot's own InvokePlaceCharacter put it back on the platform
    local placedSlots = {}
    for _, record in saved.placed or {} do
        local tool = buildTool(record, player)
        if tool and backpack then
            tool.Parent = backpack
            local slot = plot.Slots:FindFirstChild(record.s)
            local placeInvoke = slot
                and slot:FindFirstChild("Platform")
                and slot.Platform:FindFirstChild("InvokePlaceCharacter")
            if placeInvoke and slot:GetAttribute("Unlocked") and not slot:GetAttribute("Occupied") then
                local ok, placed = pcall(placeInvoke.Invoke, placeInvoke, player, tool)
                if ok and placed then
                    table.insert(placedSlots, slot)
                end
            end
        end
    end
    pcall(TempleSlotUnlocks.Refresh, plot)
    -- offline earnings land on the money stands
    if offlineSeconds > 5 and #placedSlots > 0 then
        task.wait(1.5)
        local total = 0
        for _, slot in placedSlots do
            local stand = slot:FindFirstChild("MoneyStand")
            local rate = stand and tonumber(stand:GetAttribute("IncomePerSecond")) or 0
            if stand and rate > 0 then
                local earned = math.floor(rate * offlineSeconds * 0.5) --[[ offline earns half ]]
                stand:SetAttribute("Stored", (stand:GetAttribute("Stored") or 0) + earned)
                total += earned
            end
        end
        if total > 0 then
            player:SetAttribute("OfflineEarnings", total)
            player:SetAttribute("OfflineSeconds", offlineSeconds)
        end
    end
    -- eggs go back into their incubator with the time they had left, minus the time you were away
    for _, record in incubating do
        local tool = buildTool(record, player)
        if tool then
            tool:SetAttribute("Incubating", nil)
            local chamber = waitFor(function()
                local chambersFolder = plot:FindFirstChild("Chambers")
                local candidate = chambersFolder and chambersFolder:FindFirstChild("Chamber" .. (record.inc.c or 1))
                return candidate
                    and not candidate:GetAttribute("UnderConstruction")
                    and candidate:FindFirstChild("ResumeEgg")
                    and candidate
            end, 25)
            local resumedOk = false
            if chamber and plotOf(player) == plot then
                tool.Parent = backpack
                local invokeOk, resumed = pcall(
                    chamber.ResumeEgg.Invoke,
                    chamber.ResumeEgg,
                    player,
                    tool,
                    math.max(0, (record.inc.left or 0) - offlineSeconds)
                )
                resumedOk = invokeOk and resumed == true
                if resumedOk then
                    task.wait(1)
                end
            end
            if not resumedOk and backpack then
                tool.Parent = backpack
            end
        end
    end
end

-- pcall wrapper: marks restoreState.all only when the restore finished, the player is still here and owns a plot.
local function restoreSavedState(player, saved)
    local ok, err = pcall(applySavedState, player, saved)
    if not ok then
        warn("[PlayerData] restore error", player.Name, err)
        return
    end
    local plot = plotOf(player)
    if player.Parent and plot and restoreState[player] then
        restoreState[player].all = true
    end
end

local function onJoin(player)
    sessionData[player] = { v = VERSION }
    local joinData = player:GetJoinData()
    local teleportData = joinData and joinData.TeleportData
    if type(teleportData) == "table" and teleportData.SoftShutdown == true then -- /update waiting server: just passing through, never touch the save
        player:SetAttribute("DataLoaded", true)
        player:SetAttribute("TempleSaveStatus", "Updating…")
        return
    end
    local saved, failReason = loadData(player)
    if not player.Parent then
        return
    end
    if saved then
        sessionData[player] = saved
        isLoaded[player] = true
        player:SetAttribute("TutorialCompleted", saved.tutorialCompleted == true)
        player:SetAttribute(
            "TutorialIncomeCollected",
            saved.tutorialIncomeCollected == true or saved.tutorialCompleted == true
        )
        player:SetAttribute("TutorialTourStage", math.clamp(tonumber(saved.tutorialTourStage) or 9, 9, 12))
        for name, value in saved.settings or {} do
            player:SetAttribute(name, value)
        end
        player:SetAttribute("SavedTempleLevel", saved.templeLevel or 1)
        if saved.chambers then
            player:SetAttribute("SavedChambers", table.concat(saved.chambers, ","))
        end
        if GameAdapter and GameAdapter.ImportDiscovered and saved.discovered then
            pcall(GameAdapter.ImportDiscovered, player, saved.discovered)
        end
        player:SetAttribute("DataLoaded", true)
        player:SetAttribute("TempleSaveStatus", "Saved")
        task.spawn(function()
            restoreSavedState(player, saved)
            if player.Parent then
                player:SetAttribute("TutorialDataReady", true)
            end
        end)
    elseif failReason == "studio" or failReason == "nostore" then
        player:SetAttribute("DataLoaded", true)
        player:SetAttribute("TempleSaveStatus", "Session only (Studio)")
        player:SetAttribute("TutorialCompleted", false)
        player:SetAttribute("TutorialIncomeCollected", false)
        player:SetAttribute("TutorialTourStage", 9)
        player:SetAttribute("TutorialDataReady", true)
    elseif failReason ~= "left" then
        -- load failed for real: kick instead of playing on an empty profile that would overwrite the save
        player:Kick("We couldn't load your save right now, so nothing was changed. Please rejoin in a minute.")
    end
end

local function onLeave(player)
    if isLoaded[player] then
        if not hasFinalSnapshot[player] then
            snapshot(player, true)
        end
        saveData(player, true)
    end
    sessionData[player], isLoaded[player], hasFinalSnapshot[player], lastHeldTools[player], lastSettingsAt[player], restoreState[player], unbuildable[player] =
        nil, nil, nil, nil, nil, nil, nil
end

------------------------------------------------------------ studio debug hook
-- ServerStorage.PlayerDataDebug:Invoke("dump", player) -> JSON of the save; ("rejoin", player, secondsAway) simulates
-- a leave + rejoin on the same server.
if RunService:IsStudio() then
    local debugHook = ServerStorage:FindFirstChild("PlayerDataDebug") or Instance.new("BindableFunction")
    debugHook.Name = "PlayerDataDebug"
    debugHook.Parent = ServerStorage
    debugHook.OnInvoke = function(action, player, secondsAway)
        if action == "dump" then
            snapshot(player, false)
            return game:GetService("HttpService"):JSONEncode(sessionData[player])
        end
        if action == "rejoin" then -- snapshot, wipe live state like a leave, then restore like a rejoin (extra = seconds away)
            snapshot(player, true)
            hasFinalSnapshot[player] = nil
            local saved = sessionData[player]
            saved.savedAt = os.time() - (tonumber(secondsAway) or 0)
            for _, container in
                {
                    player:FindFirstChildOfClass("Backpack"),
                    player.Character,
                    player:FindFirstChild("IncubatorHeldEggs"),
                }
            do
                if container then
                    for _, tool in container:GetChildren() do
                        if serializeTool(tool) then
                            tool:Destroy()
                        end
                    end
                end
            end
            local plot = plotOf(player)
            if plot then
                plot.PlacedItems:ClearAllChildren()
                for _, slot in plot.Slots:GetChildren() do
                    slot:SetAttribute("Occupied", false)
                    slot:SetAttribute("Unlocked", nil)
                end
                plot:SetAttribute("OwnerUserId", 0)
                task.wait(1)
                plot:SetAttribute("OwnerUserId", player.UserId)
                task.wait(1)
                for _, slot in plot.Slots:GetChildren() do
                    if slot.Name == "Slot01" then
                        slot:SetAttribute("Unlocked", true)
                    end
                end
            end
            local cash = cashOf(player)
            if cash then
                cash.Value = 0
            end
            restoreSavedState(player, saved)
            return "restored"
        end
    end
end
------------------------------------------------------------ settings (volume + toggles)
-- Allowed setting -> expected type. Numbers are clamped to 0..1 (NaN -> 1). Saved under sessionData[player].settings
-- and re-applied as player attributes on join.
local SETTING_TYPES = {
    MusicVolume = "number",
    SFXVolume = "number",
    SFXMuted = "boolean",
    ReducedMotion = "boolean",
    NightFX = "boolean",
    HideLabels = "boolean",
}
local saveSettingsRemote = ReplicatedStorage:FindFirstChild("SaveSettings") or Instance.new("RemoteEvent")
saveSettingsRemote.Name = "SaveSettings"
saveSettingsRemote.Parent = ReplicatedStorage
saveSettingsRemote.OnServerEvent:Connect(function(player, requested)
    if type(requested) ~= "table" or not sessionData[player] or os.clock() - (lastSettingsAt[player] or 0) < 0.5 then
        return
    end
    lastSettingsAt[player] = os.clock()
    local clean = {}
    for name, expectedType in SETTING_TYPES do
        local value = requested[name]
        if typeof(value) == expectedType then
            if expectedType == "number" then
                value = math.clamp(value, 0, 1)
                if value ~= value then -- NaN
                    value = 1
                end
            end
            clean[name] = value
            player:SetAttribute(name, value)
        end
    end
    sessionData[player].settings = clean
end)
------------------------------------------------------------ wiring
local saveAllHook = ServerStorage:FindFirstChild("PlayerDataSaveAll") or Instance.new("BindableFunction")
saveAllHook.Name = "PlayerDataSaveAll"
saveAllHook.Parent = ServerStorage
saveAllHook.OnInvoke = function() -- save + release every player (used by /update before teleporting)
    local pending = 0
    for _, player in Players:GetPlayers() do
        if isLoaded[player] then
            pending += 1
            task.spawn(function()
                pcall(snapshot, player, true)
                pcall(saveData, player, true)
                isLoaded[player] = nil -- lock released: no further saves from this server
                pending -= 1
            end)
        end
    end
    local startedAt = os.clock()
    while pending > 0 and os.clock() - startedAt < 20 do
        task.wait(0.2)
    end
    return pending == 0
end
local saveNowHook = ServerStorage:FindFirstChild("PlayerDataSaveNow") or Instance.new("BindableFunction")
saveNowHook.Name = "PlayerDataSaveNow"
saveNowHook.Parent = ServerStorage
saveNowHook.OnInvoke = function(player) -- returns true only once the player's items are restored AND the save landed
    if not isLoaded[player] or not (restoreState[player] and restoreState[player].all) then
        return false
    end
    pcall(snapshot, player, false)
    return saveData(player, false) == true
end
local snapshotHook = ServerStorage:FindFirstChild("PlayerDataSnapshot") or Instance.new("BindableFunction")
snapshotHook.Name = "PlayerDataSnapshot"
snapshotHook.Parent = ServerStorage
snapshotHook.OnInvoke = function(player)
    pcall(snapshot, player, true)
    return true
end

-- QuestService stores its progress inside this save (field "quests").
if QuestService and QuestService.Persistence then
    QuestService.Persistence.Load = function(player)
        waitFor(function()
            return player:GetAttribute("DataLoaded") or not player.Parent
        end, 30)
        return sessionData[player] and sessionData[player].quests or nil
    end
    QuestService.Persistence.Save = function(player, questData)
        if sessionData[player] then
            sessionData[player].quests = questData
        end
    end
end

-- Remembers what the character was holding, so a final snapshot after the character is gone still saves it.
local function watchCharacter(player)
    player.CharacterRemoving:Connect(function(character)
        local heldRecords = {}
        for _, tool in character:GetChildren() do
            local record = serializeTool(tool)
            if record then
                table.insert(heldRecords, record)
            end
        end
        lastHeldTools[player] = heldRecords
    end)
end
Players.PlayerAdded:Connect(function(player)
    watchCharacter(player)
    onJoin(player)
end)
for _, player in Players:GetPlayers() do
    task.spawn(function()
        watchCharacter(player)
        onJoin(player)
    end)
end
Players.PlayerRemoving:Connect(onLeave)

-- Autosave loop (refreshes the session lock)
task.spawn(function()
    while true do
        task.wait(AUTOSAVE_INTERVAL)
        for _, player in Players:GetPlayers() do
            if isLoaded[player] and not hasFinalSnapshot[player] then
                pcall(snapshot, player, false)
                task.spawn(saveData, player, false)
            end
        end
    end
end)

-- Shutdown: final snapshot + save + lock release for everyone, waiting up to 25 s.
game:BindToClose(function()
    if not store then
        return
    end
    local pending = 0
    for _, player in Players:GetPlayers() do
        if isLoaded[player] then
            pending += 1
            task.spawn(function()
                if not hasFinalSnapshot[player] then
                    pcall(snapshot, player, true)
                end
                saveData(player, true)
                pending -= 1
            end)
        end
    end
    local startedAt = os.clock()
    while pending > 0 and os.clock() - startedAt < 25 do
        task.wait(0.2)
    end
end)
