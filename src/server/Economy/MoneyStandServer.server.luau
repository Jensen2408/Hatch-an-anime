--[[ ServerScriptService.MoneyStandServer  (Script)
Owner-only, server-validated money collection for every stand tagged "MoneyStand".

Each stand Model needs:
  • Plate        (Part, the movable pressure plate; the server never moves it)
  • Display      (Part with SurfaceGui "Screen" > TextLabel "Amount" + "Status"), built by MoneyStandBuilder
  • Attributes   OwnerUserId (number), Stored (number), IncomePerSecond (number, optional)

Your existing earning system can write Stored directly. Set Config.BuiltInIncome = false to stop this script accruing it.

Network authority: the server alone decides when a stand is collected (10 Hz position check of the owner's
HumanoidRootPart against the plate). Clients cannot request a collection; nothing is read from the client.

Remote contract:
  • ReplicatedStorage.MoneyCollected (RemoteEvent, created here if missing)
      server -> owner only: FireClient(owner, standModel, amount)   amount = 0 means "stand was empty"

Side effects of a successful collection: leaderstats.Cash += amount, QuestService.Increment(player, "CollectIncome", 1),
and the tutorial attributes TutorialIncomeCollected / TutorialTourStage on the player.
]]
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = {
    Tag = "MoneyStand",
    BuiltInIncome = false, -- adds IncomePerSecond to Stored once a second
    Cooldown = 0.8, -- seconds between collections per stand
    ZonePadding = 0.6, -- studs around the plate's footprint
    ZoneHeight = 6, -- studs above the plate that still count as "standing on it"
    CurrencyStat = "Cash", -- leaderstats value that receives the money
}

-- Replace this to route money through your own economy module.
local function awardCurrency(player, amount)
    local leaderstats = player:FindFirstChild("leaderstats")
    local stat = leaderstats and leaderstats:FindFirstChild(Config.CurrencyStat)
    if stat then
        stat.Value += amount
        require(game.ServerScriptService.GameMenu.QuestService).Increment(player, "CollectIncome", 1)
        return true
    end
    warn("[MoneyStand] no leaderstats." .. Config.CurrencyStat .. " for " .. player.Name)
    return false
end

local moneyCollectedRemote = ReplicatedStorage:FindFirstChild("MoneyCollected") or Instance.new("RemoteEvent")
moneyCollectedRemote.Name = "MoneyCollected"
moneyCollectedRemote.Parent = ReplicatedStorage

local stands = {} -- [standModel] = { model, plate, lastCollect (os.clock) }

local function isInPlateZone(plate, position)
    local relative = plate.CFrame:PointToObjectSpace(position)
    local halfX, halfZ = plate.Size.X / 2 + Config.ZonePadding, plate.Size.Z / 2 + Config.ZonePadding
    return math.abs(relative.X) <= halfX
        and math.abs(relative.Z) <= halfZ
        and relative.Y >= -0.5
        and relative.Y <= Config.ZoneHeight
end

local function addStand(model)
    if stands[model] or not model:IsA("Model") then
        return
    end
    local plate = model:WaitForChild("Plate", 10)
    if not plate then
        warn("[MoneyStand] " .. model:GetFullName() .. " has no Plate")
        return
    end
    stands[model] = { model = model, plate = plate, lastCollect = 0 }
    if model:GetAttribute("Stored") == nil then
        model:SetAttribute("Stored", 0)
    end
    model:SetAttribute("Pressed", false)
end
local function removeStand(model)
    stands[model] = nil
end

for _, model in CollectionService:GetTagged(Config.Tag) do
    task.spawn(addStand, model)
end
CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(addStand)
CollectionService:GetInstanceRemovedSignal(Config.Tag):Connect(removeStand)

-- presence check (10 Hz). A position check on the server is harder to spoof than Touched, and it can't double-fire.
task.spawn(function()
    while true do
        task.wait(0.1)
        local now = os.clock()
        for model, standState in stands do
            if not model.Parent then
                stands[model] = nil
                continue
            end
            local owner = Players:GetPlayerByUserId(model:GetAttribute("OwnerUserId") or 0)
            local rootPart = owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = owner and owner.Character and owner.Character:FindFirstChildOfClass("Humanoid")
            local isOnPlate = rootPart ~= nil
                and humanoid ~= nil
                and humanoid.Health > 0
                and isInPlateZone(standState.plate, rootPart.Position)
            if model:GetAttribute("Pressed") ~= isOnPlate then
                -- collect only on the rising edge (step on), never while standing still
                model:SetAttribute("Pressed", isOnPlate)
                if isOnPlate and now - standState.lastCollect >= Config.Cooldown then
                    standState.lastCollect = now
                    local stored = model:GetAttribute("Stored") or 0
                    local amount = math.floor(stored)
                    if amount >= 1 then
                        model:SetAttribute("Stored", stored - amount) -- clear first so nothing can be collected twice
                        if awardCurrency(owner, amount) then
                            if model.Parent:GetAttribute("Occupied") and owner:GetAttribute("TutorialDataReady") then
                                owner:SetAttribute("TutorialIncomeCollected", true)
                                if not owner:GetAttribute("TutorialTourStage") then
                                    owner:SetAttribute("TutorialTourStage", 9)
                                end
                            end
                            moneyCollectedRemote:FireClient(owner, model, amount) -- only the owner sees their pickup
                        else
                            model:SetAttribute("Stored", (model:GetAttribute("Stored") or 0) + amount) -- refund on failure
                        end
                    else
                        moneyCollectedRemote:FireClient(owner, model, 0) -- "empty" feedback, owner only
                    end
                end
            end
        end
    end
end)

if Config.BuiltInIncome then
    task.spawn(function()
        while true do
            task.wait(1)
            for model in stands do
                local rate = model:GetAttribute("IncomePerSecond")
                if rate and rate > 0 and (model:GetAttribute("OwnerUserId") or 0) ~= 0 then
                    model:SetAttribute("Stored", (model:GetAttribute("Stored") or 0) + rate)
                end
            end
        end
    end)
end
