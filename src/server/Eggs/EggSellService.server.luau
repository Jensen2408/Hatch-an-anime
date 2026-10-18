-- EggSellService: sells an egg Tool from the player's own backpack/hand for cash. Server decides the price.
-- Price = 40% of the egg's shop price; free eggs sell for $0. Limited, golden and owner-test eggs can't be sold.
-- (Current code: those special eggs are sellable but pay $0 - see sellPriceOf.)
--
-- Runtime: ServerScriptService.EggSellService (Script). Creates ReplicatedStorage.SellEgg (RemoteFunction) and
-- sets ReplicatedStorage attribute "EggSellReady" once the handler is about to be bound.
-- Remote contract: SellEgg:InvokeServer(action, tool)
--   "Quote", tool  -> price | nil                (read-only, no rate limit)
--   "Sell", tool   -> true, total, count | false, reason
--   "SellAll"      -> true, total, count | false, reason   (every sellable Tool in backpack + character)
-- Network authority: the client only names the action and Tool. The server checks the Tool is parented to the
-- caller's Backpack/Character, computes the price from CharacterCatalog itself, and rate-limits sells to 1 per 0.15 s.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage:WaitForChild("CharacterCatalog"))
local remote = ReplicatedStorage:FindFirstChild("SellEgg") or Instance.new("RemoteFunction")
remote.Name = "SellEgg"
remote.Parent = ReplicatedStorage
local SELL_RATE = 0.4 -- eggs sell for 40% of their shop price
local lastSellAt = {} -- [Player] = os.clock() of the last Sell/SellAll request
local function sellPriceOf(tool)
    if not (tool and tool:IsA("Tool")) then
        return nil
    end
    local eggType = tool:GetAttribute("EggType")
    if type(eggType) ~= "string" then
        return nil
    end
    if tool:GetAttribute("CharacterId") then
        return nil
    end -- characters are sold through CharacterInventory
    -- every egg can be sold now; eggs without a normal price (owner/test, golden, limited, unknown) just sell for $0
    if tool:GetAttribute("OwnerSpawned") or tool:GetAttribute("GoldVariant") or tool:GetAttribute("UnknownEgg") then
        return 0
    end
    local entry = Catalog.ById[eggType]
    if not entry or entry.Limited then
        return 0
    end
    local price = entry.Price or 0
    if price <= 0 then
        return 0
    end -- allow clearing free eggs without awarding cash
    return math.floor(price * SELL_RATE)
end
ReplicatedStorage:SetAttribute("EggSellReady", true)
local function owns(player, tool)
    return tool.Parent == player:FindFirstChildOfClass("Backpack") or tool.Parent == player.Character
end
remote.OnServerInvoke = function(player, action, tool)
    if action == "Quote" then
        if typeof(tool) ~= "Instance" or not owns(player, tool) then
            return nil
        end
        return sellPriceOf(tool)
    end
    if os.clock() - (lastSellAt[player] or 0) < 0.15 then
        return false, "Slow down"
    end
    lastSellAt[player] = os.clock()
    local cash = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Cash")
    if not cash then
        return false, "Not ready"
    end
    local candidates = {}
    if action == "Sell" and typeof(tool) == "Instance" then
        candidates = { tool }
    elseif action == "SellAll" then
        for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
            if container then
                for _, child in container:GetChildren() do
                    table.insert(candidates, child)
                end
            end
        end
    else
        return false, "Bad request"
    end
    local total, soldCount = 0, 0
    for _, candidate in candidates do
        -- ownership is re-checked for every item, so a client-supplied Tool from someone else is ignored
        if typeof(candidate) == "Instance" and candidate.Parent and owns(player, candidate) then
            local price = sellPriceOf(candidate)
            if price then
                candidate:Destroy()
                total += price
                soldCount += 1
            end
        end
    end
    if soldCount == 0 then
        return false, "Nothing to sell"
    end
    cash.Value += total
    return true, total, soldCount
end
Players.PlayerRemoving:Connect(function(player)
    lastSellAt[player] = nil
end)
