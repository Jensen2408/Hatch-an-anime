--[[ ReplicatedStorage.CharacterInventory.InventoryFormat  (ModuleScript)
One number style everywhere in the inventory and the hatch reveal:

	850   12.5K   4.2M   1.8B   7.4T   100T   2.5Qa

Short values are truncated (never rounded up), so a card never shows more Power than the
character really has. The details panel always shows the exact value as well.
]]
local Format = {}

local SUFFIX = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
local EXACT_LIMIT = 2 ^ 53 -- integers above this cannot be represented exactly

function Format.Short(n)
    n = tonumber(n) or 0
    if n ~= n then
        return "?"
    end
    local sign = n < 0 and "-" or ""
    n = math.abs(n)
    if n == math.huge then
        return sign .. "∞"
    end
    if n < 1000 then
        return sign .. tostring(math.floor(n))
    end
    local tier = math.floor(math.log10(n) / 3)
    tier = math.min(tier, #SUFFIX) -- Dc is the last suffix, not a balance cap.
    local value = n / 1000 ^ tier
    -- floating point can land just under a boundary (999.99999 → next tier)
    if value >= 999.9999 and tier < #SUFFIX then
        tier += 1
        value = n / 1000 ^ tier
    end
    -- below 100: one truncated decimal, dropped when it is .0 ("12.5K", "4M"); otherwise whole units
    if value < 100 then
        local truncated = math.floor(value * 10 + 1e-9) / 10
        local text = truncated % 1 == 0 and string.format("%d", truncated) or string.format("%.1f", truncated)
        return sign .. text .. SUFFIX[tier]
    end
    return sign .. string.format("%.0f", math.floor(value + 1e-9)) .. SUFFIX[tier]
end

-- 123456789 → "123,456,789". Prefixed with ≈ when the value is beyond exact integer precision.
function Format.Exact(n)
    n = tonumber(n) or 0
    if n ~= n or n == math.huge then
        return Format.Short(n)
    end
    local digits = string.format("%.0f", math.floor(math.abs(n)))
    digits = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return (n < 0 and "-" or "") .. (math.abs(n) >= EXACT_LIMIT and "≈" or "") .. digits
end

function Format.Money(n)
    return "$" .. Format.Short(n)
end
function Format.Rate(n)
    return "$" .. Format.Short(n) .. "/s"
end

-- Signed difference, e.g. "+3.2B" / "-850" / "±0"
function Format.Delta(difference, money)
    if difference == 0 then
        return "±0"
    end
    return (difference > 0 and "+" or "-") .. (money and "$" or "") .. Format.Short(math.abs(difference))
end

-- Relative difference: "+41%", "-12%", "×24" for very large gaps.
function Format.Relative(new, old)
    if not old or old <= 0 then
        return ""
    end
    local ratio = new / old
    if ratio >= 10 then
        return "×" .. Format.Short(ratio)
    end
    local percent = (ratio - 1) * 100
    if math.abs(percent) < 0.5 then
        return "same"
    end
    -- rounded half away from zero
    return string.format("%+d%%", percent > 0 and math.floor(percent + 0.5) or math.ceil(percent - 0.5))
end

-- "×2.4 base" style multiplier, one decimal below 100.
function Format.Multiplier(power, base)
    if not base or base <= 0 then
        return ""
    end
    local multiplier = power / base
    if multiplier < 100 then
        return string.format("×%.1f", math.floor(multiplier * 10) / 10)
    end
    return "×" .. Format.Short(multiplier)
end

-- "just now" under 45 s, then rounded minutes, then whole hours / days.
function Format.Ago(seconds)
    seconds = math.max(0, seconds or 0)
    if seconds < 45 then
        return "just now"
    end
    if seconds < 3600 then
        return math.floor(seconds / 60 + 0.5) .. "m ago"
    end
    if seconds < 86400 then
        return math.floor(seconds / 3600) .. "h ago"
    end
    return math.floor(seconds / 86400) .. "d ago"
end

return Format
