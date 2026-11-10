--[[ ServerScriptService.BoostService (ModuleScript, server) - custom Boost event (2026-11-08)
The admin panel starts a boost with any multiplier for any length of time, in this server:
  Cash        all income                       (BrainrotPlacement, InventoryService, money display)
  Luck        rarer river eggs                 (RiverEggSpawnScheduler rarity weights)
  Hatch       hatch speed                      (HatchGoo incubation)
  Mutation    mutation chance                  (river egg roll + hatch roll)
  RiverSpeed  eggs spawn this many times faster (PirateEggFreeConveyor spawn interval)
Each target is separate, so boosts stack with each other and with every other event (night, admin abuse, double
cash ...): the read sites multiply all of them. Starting a target again replaces its multiplier and timer.
Published workspace attributes: Boost<Target>Multiplier (nil when off) and Boost<Target>EndsAt (server time).
API: Start(target, multiplier, seconds) -> ok, message   Stop(target?) (nil = all)   List() -> { [target] = { x, endsAt } }
]]
local BoostService = {}
BoostService.Targets = { "Cash", "Luck", "Hatch", "Mutation", "RiverSpeed" }
BoostService.Labels = { Cash = "CASH", Luck = "LUCK", Hatch = "HATCH SPEED", Mutation = "MUTATION CHANCE", RiverSpeed = "RIVER SPEED" }
local MAX_MULTIPLIER = 100
local MAX_SECONDS = 4 * 3600

local active = {} -- [target] = { x, endsAt, token }

local function publish(target)
    local boost = active[target]
    workspace:SetAttribute("Boost" .. target .. "Multiplier", boost and boost.x or nil)
    workspace:SetAttribute("Boost" .. target .. "EndsAt", boost and boost.endsAt or nil)
end

function BoostService.Stop(target)
    for _, t in BoostService.Targets do
        if target == nil or t == target then
            active[t] = nil
            publish(t)
        end
    end
end

function BoostService.Start(target, multiplier, seconds)
    if not table.find(BoostService.Targets, target) then
        return false, "Pick what to boost."
    end
    multiplier = tonumber(multiplier)
    if not multiplier or multiplier ~= multiplier or multiplier < 1.1 or multiplier > MAX_MULTIPLIER then
        return false, "Multiplier must be from 1.1x to " .. MAX_MULTIPLIER .. "x."
    end
    multiplier = math.floor(multiplier * 10 + 0.5) / 10
    seconds = tonumber(seconds) or 300
    if seconds ~= seconds or seconds < 15 or seconds > MAX_SECONDS then
        return false, "Length must be 15 s to 4 hours."
    end
    local token = {}
    active[target] = { x = multiplier, endsAt = workspace:GetServerTimeNow() + seconds, token = token }
    publish(target)
    task.delay(seconds, function()
        if active[target] and active[target].token == token then
            active[target] = nil
            publish(target)
        end
    end)
    return true, multiplier .. "x " .. BoostService.Labels[target] .. " for " .. math.floor(seconds / 60 + 0.5) .. " min"
end

function BoostService.List()
    local list = {}
    for target, boost in active do
        list[target] = { x = boost.x, endsAt = boost.endsAt }
    end
    return list
end

-- read-site helper: the live multiplier for a target (1 when off)
function BoostService.Get(target)
    return workspace:GetAttribute("Boost" .. target .. "Multiplier") or 1
end

return BoostService
