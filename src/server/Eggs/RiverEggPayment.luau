--[[ ServerScriptService.RiverEggPayment  (ModuleScript, SERVER)
Charges a player for a river egg. Used by PirateEggFreeConveyor right before the egg is granted.
Payment.TryCharge(player, price) -> true | false, reason
  price must be a finite, non-negative integer (server-side value from CharacterCatalog, re-validated here).
  The reason strings are shown to the player via RiverEggPurchaseFeedback.
  No yields: the caller relies on charge + grant happening in one step.
]]
local Payment = {}

function Payment.TryCharge(player, price)
    -- price ~= price rejects NaN
    if type(price) ~= "number" or price ~= price or price < 0 or price == math.huge or price % 1 ~= 0 then
        return false, "Invalid egg price"
    end
    if price == 0 then
        return true
    end
    local leaderstats = player:FindFirstChild("leaderstats")
    local cash = leaderstats and leaderstats:FindFirstChild("Cash")
    if not cash or not (cash:IsA("IntValue") or cash:IsA("NumberValue")) then
        return false, "Cash is not ready yet"
    end
    if cash.Value < price then
        return false, "Not enough cash"
    end
    cash.Value -= price
    return true
end

return Payment
