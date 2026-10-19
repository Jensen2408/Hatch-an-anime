-- ReplicatedStorage.FirstHatchGuide (ModuleScript, shared)
-- Shared objective selection. The server remains responsible for rewards and completion.
--
-- Guide.Steps: ordered tutorial objectives (title/body/marker text shown to the player).
-- Guide.Resolve(player) -> stepIndex, target?, note?, revealing?
--   stepIndex  1..12 into Guide.Steps, or 13 once the tutorial is completed.
--   target     Instance the arrows/marker should point at (may be nil).
--   note       optional override for the step body text.
--   revealing  true while a hatch reveal is playing (step 5).
-- It is a pure read of attributes/instances; it never writes state.
local Guide = {}
Guide.Steps = {
    {
        title = "Collect your first egg",
        body = "Follow the arrows to a FREE river egg. Use Collect when you are close.",
        marker = "FREE EGG",
    },
    {
        title = "Bring your egg home",
        body = "Follow the arrows back to your temple to secure the egg.",
        marker = "YOUR TEMPLE",
    },
    {
        title = "Load your incubator",
        body = "Equip the egg from your hotbar, then use Insert egg at the chamber.",
        marker = "INSERT EGG",
    },
    {
        title = "Let your egg incubate",
        body = "Your egg is getting ready. The timer above the chamber shows how long is left.",
        marker = "INCUBATING",
    },
    { title = "Hatch your egg", body = "Your egg is ready! Use Hatch on your incubator.", marker = "HATCH HERE" },
    {
        title = "Collect your character",
        body = "Use Collect character at the open incubator.",
        marker = "COLLECT CHARACTER",
    },
    {
        title = "Place your character",
        body = "Equip the character, then use Place character on your first empty podium.",
        marker = "PLACE HERE",
    },
    {
        title = "Collect your first earnings",
        body = "Step onto the cash plate in front of your character to collect its earnings.",
        marker = "COLLECT CASH",
    },
    {
        title = "Open your Plot menu",
        body = "You can grow your temple with upgrades. Press Plot to see how.",
        marker = "",
    },
    { title = "Go to Upgrades", body = "Choose Upgrades in your Plot menu.", marker = "" },
    {
        title = "Grow your temple",
        body = "This is where you unlock slots and add temple floors. Take a look, then press NEXT.",
        marker = "",
    },
    {
        title = "Expand your incubators",
        body = "Add more incubators to hatch more eggs at once, or upgrade the incubators you own.",
        marker = "",
    },
}
-- Returns the plot whose "OwnerUserId" attribute matches the player, or nil.
function Guide.Plot(player)
    local plots = workspace:FindFirstChild("Plots")
    if plots then
        for _, plot in plots:GetChildren() do
            if plot:GetAttribute("OwnerUserId") == player.UserId then
                return plot
            end
        end
    end
end
-- First Tool in the Backpack, then the Character, that satisfies predicate.
local function findTool(player, predicate)
    for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
        if container then
            for _, item in container:GetChildren() do
                if item:IsA("Tool") and predicate(item) then
                    return item
                end
            end
        end
    end
end
function Guide.Resolve(player)
    -- Tutorial done / in the post-income plot tour (steps 9..12, server-driven via TutorialTourStage).
    if player:GetAttribute("TutorialCompleted") == true then
        return 13
    end
    if player:GetAttribute("TutorialIncomeCollected") == true then
        return math.clamp(player:GetAttribute("TutorialTourStage") or 9, 9, 12)
    end
    local plot = Guide.Plot(player)
    if not plot then
        return 1, nil, "Waiting for your temple..."
    end
    local slots = plot:FindFirstChild("Slots")
    local ordered = slots and slots:GetChildren() or {}
    table.sort(ordered, function(slotA, slotB)
        return slotA.Name < slotB.Name
    end)
    -- Step 8 points at the occupied stand holding the most stored cash; step 7 at the first unlocked empty slot.
    local richestStand, firstEmptySlot
    for _, slot in ordered do
        if slot:GetAttribute("Occupied") then
            local stand = slot:FindFirstChild("MoneyStand")
            if
                stand
                and (
                    not richestStand
                    or (stand:GetAttribute("Stored") or 0) > (richestStand:GetAttribute("Stored") or 0)
                )
            then
                richestStand = stand
            end
        elseif slot:GetAttribute("Unlocked") and not firstEmptySlot then
            firstEmptySlot = slot
        end
    end
    if richestStand then
        return 8, richestStand:FindFirstChild("Plate")
    end
    local characterTool = findTool(player, function(item)
        return item:GetAttribute("BrainrotId") ~= nil or item:GetAttribute("Hatched") == true
    end)
    if characterTool then
        local stand = firstEmptySlot and firstEmptySlot:FindFirstChild("MoneyStand")
        return 7,
            (stand and stand:FindFirstChild("CharacterSlot")) or (firstEmptySlot and firstEmptySlot:FindFirstChild(
                "Platform"
            )),
            not firstEmptySlot and "Unlock an empty podium to place your character." or nil
    end
    local chambers = plot:FindFirstChild("Chambers")
    -- The chamber furthest along (highest step) wins; a "Ready" (empty) chamber is remembered for step 3.
    local bestChamber, bestStep, readyChamber
    if chambers then
        for _, chamber in chambers:GetChildren() do
            if not chamber:GetAttribute("UnderConstruction") then
                local status = chamber:GetAttribute("Status")
                local step = ({
                    AwaitingPickup = 6,
                    Loaded = 5,
                    HatchReveal = 5,
                    Revealing = 5,
                    Incubating = 4,
                    Loading = 4,
                })[status]
                if step and (not bestStep or step > bestStep) then
                    bestChamber, bestStep = chamber, step
                end
                if status == "Ready" and not readyChamber then
                    readyChamber = chamber
                end
            end
        end
    end
    if bestChamber then
        local target = bestChamber:FindFirstChild("EggPickupAnchor", true)
            or bestChamber:FindFirstChild("HatchButton", true)
        local status = bestChamber:GetAttribute("Status")
        if status == "HatchReveal" or status == "Revealing" then
            return 5, target, nil, true
        end
        local note
        if bestStep == 4 then
            local cycleEnd = bestChamber:GetAttribute("CycleEnd")
            if cycleEnd then
                note = "Ready in "
                    .. math.max(0, math.ceil(cycleEnd - workspace:GetServerTimeNow()))
                    .. "s. You can explore while you wait."
            end
        end
        return bestStep, target, note
    end
    local eggTool = findTool(player, function(item)
        return item:GetAttribute("EggType") ~= nil
            and not item:GetAttribute("CharacterId")
            and not item:GetAttribute("BrainrotId")
            and not item:GetAttribute("Incubating")
    end)
    if eggTool then
        if eggTool:GetAttribute("ReturningToBase") then
            return 2, plot:FindFirstChild("PlotSpawn")
        end
        return 3,
            readyChamber and readyChamber:FindFirstChild("HatchButton", true),
            not readyChamber and "Your incubator is preparing. It will be ready shortly." or nil
    end
    -- Step 1: nearest free, still-collectible river egg; otherwise the pirate conveyor with a hint.
    local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local riverEggs = workspace:FindFirstChild("LocalRiverEggs") or workspace:FindFirstChild("WaterfallEggs")
    local nearestAnchor, nearestDistance = nil, math.huge
    if riverEggs and rootPart then
        for _, riverEgg in riverEggs:GetChildren() do
            if
                riverEgg:GetAttribute("Price") == 0
                and not riverEgg:GetAttribute("Collected")
                and (riverEgg:GetAttribute("Collectible") ~= false)
            then
                local anchor = riverEgg:FindFirstChild("CollectAnchor", true)
                if anchor then
                    local eggDistance = (anchor.Position - rootPart.Position).Magnitude
                    if eggDistance < nearestDistance then
                        nearestAnchor, nearestDistance = anchor, eggDistance
                    end
                end
            end
        end
    end
    if nearestAnchor then
        return 1, nearestAnchor
    end
    local conveyor = workspace:FindFirstChild("PirateEggConveyor")
    return 1,
        conveyor and conveyor:FindFirstChild("CollectAnchor"),
        "Head to the river and look for a FREE egg. More eggs arrive regularly."
end
return Guide
