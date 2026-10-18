--[[ ReplicatedStorage.Leaderboard.LeaderboardFormat  (ModuleScript)
Short, fixed-width numbers so the value column stays aligned: 9,999 · 12.5K · 1.20M · 125B.
Values are always rounded DOWN, so a score never reads higher than it is.
]]
local Format = {}

-- Unused since Compact delegates to InventoryFormat; kept as-is.
local _UNITS = {
    { 1e18, "Qi" },
    { 1e15, "Qa" },
    { 1e12, "T" },
    { 1e9, "B" },
    { 1e6, "M" },
    { 1e3, "K" },
}

-- 1234567 -> "1,234,567" (floored).
function Format.Commas(n)
    local digits = string.format("%d", math.floor(n))
    local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (grouped:gsub("^,", ""))
end

-- Same number style as the inventory; InventoryFormat is required on first call, not at module load.
function Format.Compact(n)
    return require(game:GetService("ReplicatedStorage").CharacterInventory.InventoryFormat).Short(n)
end

-- kind = Stats[i].Kind in LeaderboardConfig: "money" | "rate" | anything else (plain count).
function Format.Value(kind, n)
    if kind == "money" then
        return "$" .. Format.Compact(n)
    end
    if kind == "rate" then
        return "$" .. Format.Compact(n) .. "/s"
    end
    return Format.Compact(n)
end

function Format.Age(seconds)
    seconds = math.max(0, math.floor(seconds))
    if seconds < 10 then
        return "just now"
    end
    if seconds < 60 then
        return seconds .. "s ago"
    end
    if seconds < 3600 then
        return math.floor(seconds / 60) .. "m ago"
    end
    return math.floor(seconds / 3600) .. "h ago"
end

return Format
