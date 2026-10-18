-- Guaranteed mutation egg in the river every INTERVAL seconds. The board by the river counts down to it.
-- Change the timer: set this script's attribute "IntervalSeconds" (default 600 = 10 min).
local INTERVAL = script:GetAttribute("IntervalSeconds") or 600
local WEIGHTS = { Silver = 60, Gold = 25, Diamond = 11, Rainbow = 4 } -- which tier the guaranteed drop is
local rng = Random.new()
local function pick()
    local total = 0
    for _, w in WEIGHTS do
        total += w
    end
    local r = rng:NextNumber(0, total)
    for _, t in { "Silver", "Gold", "Diamond", "Rainbow" } do
        r -= WEIGHTS[t]
        if r <= 0 then
            return t
        end
    end
    return "Silver"
end
local function nextAt()
    return workspace:GetServerTimeNow() + (script:GetAttribute("IntervalSeconds") or INTERVAL)
end
workspace:SetAttribute("NextMutationDropAt", nextAt())
while true do
    task.wait(1)
    if workspace:GetServerTimeNow() >= workspace:GetAttribute("NextMutationDropAt") then
        local tier = pick()
        workspace:SetAttribute("PendingMutationDrop", tier)
        workspace:SetAttribute("LastMutationDrop", tier)
        workspace:SetAttribute("LastMutationDropAt", workspace:GetServerTimeNow())
        workspace:SetAttribute("NextMutationDropAt", nextAt())
    end
end
