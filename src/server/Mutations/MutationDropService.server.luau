-- MutationDropService (server Script, ServerScriptService)
-- Guaranteed mutation egg in the river every INTERVAL seconds. The board by the river counts down to it
-- (MutationDropBoardClient).
-- Change the timer: set this script's attribute "IntervalSeconds" (default 600 = 10 min). It is re-read for
-- every new drop, so a live change applies from the next scheduled drop.
-- Workspace attributes written (server authority):
--   NextMutationDropAt  (server time of the next drop)
--   PendingMutationDrop (tier waiting to be spawned in the river; consumed once by PirateEggFreeConveyor)
--   LastMutationDrop / LastMutationDropAt (tier + server time of the last drop, for the board)
local INTERVAL = script:GetAttribute("IntervalSeconds") or 600
local WEIGHTS = { Silver = 60, Gold = 25, Diamond = 11, Rainbow = 4 } -- which tier the guaranteed drop is

local rng = Random.new()

local function pickTier()
    local totalWeight = 0
    for _, weight in WEIGHTS do
        totalWeight += weight
    end
    local roll = rng:NextNumber(0, totalWeight)
    for _, tier in { "Silver", "Gold", "Diamond", "Rainbow" } do
        roll -= WEIGHTS[tier]
        if roll <= 0 then
            return tier
        end
    end
    return "Silver"
end

local function nextDropAt()
    return workspace:GetServerTimeNow() + (script:GetAttribute("IntervalSeconds") or INTERVAL)
end

workspace:SetAttribute("NextMutationDropAt", nextDropAt())
while true do
    task.wait(1)
    if workspace:GetServerTimeNow() >= workspace:GetAttribute("NextMutationDropAt") then
        local tier = pickTier()
        workspace:SetAttribute("PendingMutationDrop", tier)
        workspace:SetAttribute("LastMutationDrop", tier)
        workspace:SetAttribute("LastMutationDropAt", workspace:GetServerTimeNow())
        workspace:SetAttribute("NextMutationDropAt", nextDropAt())
    end
end
