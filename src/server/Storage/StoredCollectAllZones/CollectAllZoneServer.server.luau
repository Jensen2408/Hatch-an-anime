-- ServerStorage.StoredCollectAllZones.CollectAllZoneServer  (server Script, PARKED: Disabled in default.project.json
-- and stored in ServerStorage, so it never runs).
-- Collect-all pad in front of each temple (Adam, Oct 16). Stand on your own plot's pad to
-- collect every MoneyStand you own at once. The label shows the total waiting.
-- Server-authoritative polling (every 0.15 s): no client remotes are trusted. Pays out leaderstats.Cash, bumps the
-- CollectIncome quest, sets TutorialIncomeCollected and fires ReplicatedStorage.MoneyCollected (owner, firstStand, total).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local function formatShort(amount)
    amount = math.floor(amount or 0)
    for _, unit in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
        if amount >= unit[1] then
            return (string.format("%.1f", amount / unit[1]):gsub("%.0$", "")) .. unit[2]
        end
    end
    return tostring(amount)
end

local function getOwnedStands(ownerUserId)
    local list = {}
    if ownerUserId == 0 then
        return list
    end
    for _, stand in CollectionService:GetTagged("MoneyStand") do
        if stand:GetAttribute("OwnerUserId") == ownerUserId then
            table.insert(list, stand)
        end
    end
    return list
end

local function isInsidePad(pad, pos)
    local localPosition = pad.CFrame:PointToObjectSpace(pos)
    return math.abs(localPosition.X) <= pad.Size.X / 2 + 0.5
        and math.abs(localPosition.Z) <= pad.Size.Z / 2 + 0.5
        and localPosition.Y >= -0.5
        and localPosition.Y <= 7
end

local lastCollectAt = {} -- [zone] = os.clock() of its last payout (1 s cooldown)
task.spawn(function()
    local tickCount = 0
    while true do
        task.wait(0.15)
        tickCount += 1
        for _, zone in CollectionService:GetTagged("CollectAllZone") do
            local plot = zone.Parent
            local pad = zone:FindFirstChild("Pad")
            if not (plot and pad) then
                continue
            end
            local ownerUserId = plot:GetAttribute("OwnerUserId") or 0
            local stands = getOwnedStands(ownerUserId)
            local owner = ownerUserId ~= 0 and Players:GetPlayerByUserId(ownerUserId)
            local character = owner and owner.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if
                rootPart
                and humanoid
                and humanoid.Health > 0
                and isInsidePad(pad, rootPart.Position)
                and os.clock() - (lastCollectAt[zone] or 0) >= 1
            then
                local total = 0
                for _, stand in stands do
                    local stored = stand:GetAttribute("Stored") or 0
                    if stored > 0 then
                        stand:SetAttribute("Stored", 0)
                        total += stored
                    end
                end
                if total > 0 then
                    lastCollectAt[zone] = os.clock()
                    local leaderstats = owner:FindFirstChild("leaderstats")
                    local cash = leaderstats and leaderstats:FindFirstChild("Cash")
                    if cash then
                        cash.Value += total
                        pcall(function()
                            require(game.ServerScriptService.GameMenu.QuestService).Increment(owner, "CollectIncome", 1)
                        end)
                        owner:SetAttribute("TutorialIncomeCollected", true)
                        local remote = game.ReplicatedStorage:FindFirstChild("MoneyCollected")
                        if remote and stands[1] then
                            pcall(remote.FireClient, remote, owner, stands[1], total)
                        end
                    end
                end
            end
            -- refresh the pad label every 3rd poll (~0.45 s)
            if tickCount % 3 == 0 then
                local waitingTotal = 0
                for _, stand in stands do
                    waitingTotal += stand:GetAttribute("Stored") or 0
                end
                local collectTag = pad:FindFirstChild("CollectAllTag")
                if collectTag then
                    collectTag.Enabled = ownerUserId ~= 0
                    collectTag.Amount.Text = "$" .. formatShort(waitingTotal)
                end
            end
        end
    end
end)
