--[[ ServerScriptService.GameMenu.QuestService  (ModuleScript, server)
Server-authoritative quest progress. Other server scripts report progress:
  local Quests = require(game.ServerScriptService.GameMenu.QuestService)
  Quests.Increment(player, "HatchEgg", 1)   -- only after a hatch has really completed
Progress is SESSION-ONLY until you connect Persistence below.
(In this game PlayerDataService overrides QuestService.Persistence.Load/Save and stores the table in the main
save as field "quests"; Load yields until the save is loaded, Increment calls before that are ignored.)

Public API:
  QuestService.Changed      BindableEvent, fired with (player) whenever progress / claims change
  QuestService.Increment(player, objective, amount?)
  QuestService.Snapshot(player) -> { serverTime, ends = { Daily, Weekly, Monthly }, list = { questRow... } }
  QuestService.Claim(player, questId, grant) -> ok, message
  QuestService.Persistence  { Load(player) -> table?, Save(player, questData) }
Quest definitions and period keys come from ReplicatedStorage.GameMenu.Config (Quests, PeriodKey, PeriodEnds).
No remotes; GameMenuServer exposes Snapshot / Claim to the client.
]]
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("GameMenu"):WaitForChild("Config"))

local QuestService = { Changed = Instance.new("BindableEvent") }
local questData = {} -- [player] = { [questId] = { key = periodKey, progress = n, claimed = bool } }
local claiming = {} -- [player] = true while a grant callback runs

-- Persistence adapter: replace these two with your DataStore / ProfileService calls.
QuestService.Persistence = {
    Load = function(_player)
        return nil
    end, -- return the saved table or nil
    Save = function(_player, _questData) end, -- called on leave + after claims
}

-- Returns the player's progress row for a quest, resetting it when the quest period rolled over.
-- nil while the player's data is not loaded.
local function getQuestRow(player, quest)
    local currentTime = os.time()
    local playerQuests = questData[player]
    if not playerQuests then
        return nil
    end
    local questRow = playerQuests[quest.id]
    local periodKey = Config.PeriodKey(quest.period, currentTime)
    if not questRow or questRow.key ~= periodKey then
        questRow = { key = periodKey, progress = 0, claimed = false }
        playerQuests[quest.id] = questRow
    end -- period rolled over
    return questRow
end

function QuestService.Increment(player, objective, amount)
    if not questData[player] then
        return
    end
    amount = tonumber(amount) or 1
    local changed = false
    for _, quest in Config.Quests do
        if quest.objective == objective then
            local questRow = getQuestRow(player, quest)
            if questRow and not questRow.claimed and questRow.progress < quest.target then
                questRow.progress = math.min(quest.target, questRow.progress + amount)
                changed = true
            end
        end
    end
    if changed then
        QuestService.Changed:Fire(player)
    end
end

function QuestService.Snapshot(player)
    local now = os.time()
    local snapshot = { serverTime = now, ends = {}, list = {} }
    for _, period in { "Daily", "Weekly", "Monthly" } do
        snapshot.ends[period] = Config.PeriodEnds(period, now)
    end
    for _, quest in Config.Quests do
        local questRow = getQuestRow(player, quest)
        if questRow then
            table.insert(snapshot.list, {
                id = quest.id,
                period = quest.period,
                order = quest.order,
                title = quest.title,
                description = quest.description,
                target = quest.target,
                progress = questRow.progress,
                claimed = questRow.claimed,
                reward = quest.reward,
            })
        end
    end
    return snapshot
end

-- grant(player, reward) must return true only if the reward was actually given
function QuestService.Claim(player, questId, grant)
    if claiming[player] then
        return false, "Claim in progress"
    end
    local quest
    for _, candidate in Config.Quests do
        if candidate.id == questId then
            quest = candidate
        end
    end
    if not quest then
        return false, "Unknown quest"
    end
    local questRow = getQuestRow(player, quest)
    if not questRow then
        return false, "Not loaded"
    end
    if questRow.claimed then
        return false, "Already claimed"
    end
    if questRow.progress < quest.target then
        return false, "Not finished yet"
    end
    claiming[player] = true
    questRow.claimed = true -- mark first so repeated clicks can't double-pay
    local ok, granted = pcall(grant, player, quest.reward)
    claiming[player] = nil
    if not ok or granted ~= true then
        questRow.claimed = false
        return false, "Reward failed, try again"
    end
    QuestService.Persistence.Save(player, questData[player])
    QuestService.Changed:Fire(player)
    return true, "Claimed"
end

Players.PlayerAdded:Connect(function(player)
    questData[player] = QuestService.Persistence.Load(player) or {}
end)
for _, player in Players:GetPlayers() do
    questData[player] = questData[player] or {}
end
Players.PlayerRemoving:Connect(function(player)
    if questData[player] then
        QuestService.Persistence.Save(player, questData[player])
    end
    questData[player] = nil
    claiming[player] = nil
end)

return QuestService
