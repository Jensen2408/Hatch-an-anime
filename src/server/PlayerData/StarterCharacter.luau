--[[ ServerScriptService.StarterCharacter  (ModuleScript, server)
New players start earning before their first hatch: a free Luffy on Slot01 with STARTER_CASH on its plate, and Slot02
unlocked for the first hatched character. Only for a save with no progress at all; saved.starterGiven stops a repeat.

Player attribute TutorialStarterStage (saved) drives FirstHatchGuide:
  "Cash"   collect the plate (guide step 0)
  "Hatch"  guide steps 1..7; collecting does not count as the tutorial's first income yet
  nil      a hatched character was placed (BrainrotPlacement): the normal tutorial carries on from step 8

  Starter.Eligible(saved) -> boolean
  Starter.Grant(player, plot) -> boolean          places the character; false leaves the old tutorial in place
  Starter.CountsAsFirstIncome(player) -> boolean  call on every collection: moves "Cash" on to "Hatch"
]]
local ServerStorage = game:GetService("ServerStorage")

local Economy = require(game:GetService("ReplicatedStorage"):WaitForChild("CharacterEconomy"))
local Rewards = require(script.Parent:WaitForChild("EggCharacterRewards"))
local TempleSlotUnlocks = require(script.Parent:WaitForChild("TempleSlotUnlocks"))

local STARTER_ID = "Luffy"
local STARTER_CASH = 300
local WAIT_SECONDS = 15 -- for the plot's slot and money stand to be ready

local Starter = {}

local function waitUntil(condition)
    local startedAt = os.clock()
    while not condition() and os.clock() - startedAt < WAIT_SECONDS do
        task.wait(0.25)
    end
    return condition()
end

function Starter.Eligible(saved)
    return not saved.starterGiven
        and not saved.tutorialCompleted
        and not saved.tutorialIncomeCollected
        and (tonumber(saved.cash) or 0) == 0
        and #(saved.tools or {}) == 0
        and #(saved.placed or {}) == 0
end

function Starter.Grant(player, plot)
    local firstSlot = plot and plot.Slots:FindFirstChild("Slot01")
    local placeInvoke = firstSlot and firstSlot.Platform:FindFirstChild("InvokePlaceCharacter")
    local backpack = player:FindFirstChildOfClass("Backpack")
    local isReady = placeInvoke
        and backpack
        and waitUntil(function()
            return firstSlot:GetAttribute("Unlocked") == true
        end)
    if not isReady or firstSlot:GetAttribute("Occupied") then
        return false
    end
    local power = Economy.BasePower(STARTER_ID)
    local stats = {
        Power = power,
        IncomePerSecond = Economy.Income(STARTER_ID, power),
        RollQuality = Economy.Quality(STARTER_ID, power).Name,
    }
    local tool = Rewards.Tool(ServerStorage.BrainrotModels[STARTER_ID], STARTER_ID, stats, false)
    tool:SetAttribute("StarterCharacter", true)
    tool.Parent = backpack
    if placeInvoke:Invoke(player, tool) ~= true then
        tool:Destroy()
        return false
    end
    local secondSlot = plot.Slots:FindFirstChild("Slot02")
    if secondSlot then
        secondSlot:SetAttribute("Unlocked", true)
    end
    TempleSlotUnlocks.Refresh(plot)
    local hasStand = waitUntil(function()
        local stand = firstSlot:FindFirstChild("MoneyStand")
        return stand and stand:GetAttribute("OwnerUserId") == player.UserId
    end)
    if hasStand then
        local stand = firstSlot.MoneyStand
        stand:SetAttribute("Stored", (stand:GetAttribute("Stored") or 0) + STARTER_CASH)
        player:SetAttribute("TutorialStarterStage", "Cash")
    else
        player.leaderstats.Cash.Value += STARTER_CASH
        player:SetAttribute("TutorialStarterStage", "Hatch")
    end
    return true
end

function Starter.CountsAsFirstIncome(player)
    local stage = player:GetAttribute("TutorialStarterStage")
    if stage == "Cash" then
        player:SetAttribute("TutorialStarterStage", "Hatch")
    end
    return stage == nil
end

return Starter
