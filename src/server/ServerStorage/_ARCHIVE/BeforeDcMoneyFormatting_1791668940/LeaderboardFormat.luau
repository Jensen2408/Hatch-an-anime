--[[ ReplicatedStorage.Leaderboard.LeaderboardFormat  (ModuleScript)
Short, fixed-width numbers so the value column stays aligned: 9,999 · 12.5K · 1.20M · 125B.
Values are always rounded DOWN, so a score never reads higher than it is.
]]
local Format = {}

local UNITS = {
	{ 1e18, "Qi" }, { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" },
}

function Format.Commas(n)
	local s = string.format("%d", math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function Format.Compact(n)
	n = math.max(0, math.floor(tonumber(n) or 0))
	if n < 100000 then return Format.Commas(n) end
	for _, unit in UNITS do
		if n >= unit[1] then
			local v = n / unit[1]
			if v >= 100 then return string.format("%d%s", math.floor(v + 1e-9), unit[2]) end
			if v >= 10 then return string.format("%.1f%s", math.floor(v * 10 + 1e-6) / 10, unit[2]) end
			return string.format("%.2f%s", math.floor(v * 100 + 1e-6) / 100, unit[2])
		end
	end
	return Format.Commas(n)
end

function Format.Value(kind, n)
	if kind == "money" then return "$" .. Format.Compact(n) end
	if kind == "rate" then return "$" .. Format.Compact(n) .. "/s" end
	return Format.Compact(n)
end

function Format.Age(seconds)
	seconds = math.max(0, math.floor(seconds))
	if seconds < 10 then return "just now" end
	if seconds < 60 then return seconds .. "s ago" end
	if seconds < 3600 then return math.floor(seconds / 60) .. "m ago" end
	return math.floor(seconds / 3600) .. "h ago"
end

return Format
