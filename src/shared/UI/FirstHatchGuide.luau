-- Shared objective selection. The server remains responsible for rewards and completion.
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
        body = "Unlock all slots on your current floor, then upgrade your temple to add another floor.",
        marker = "",
    },
    {
        title = "Expand your incubators",
        body = "Add more incubators to hatch more eggs at once, or upgrade the incubators you own.",
        marker = "",
    },
}
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
local function tool(player, predicate)
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
    table.sort(ordered, function(a, b)
        return a.Name < b.Name
    end)
    local occupied, empty
    for _, slot in ordered do
        if slot:GetAttribute("Occupied") then
            local stand = slot:FindFirstChild("MoneyStand")
            if
                stand and (not occupied or (stand:GetAttribute("Stored") or 0) > (occupied:GetAttribute("Stored") or 0))
            then
                occupied = stand
            end
        elseif slot:GetAttribute("Unlocked") and not empty then
            empty = slot
        end
    end
    if occupied then
        return 8, occupied:FindFirstChild("Plate")
    end
    local character = tool(player, function(t)
        return t:GetAttribute("BrainrotId") ~= nil or t:GetAttribute("Hatched") == true
    end)
    if character then
        local stand = empty and empty:FindFirstChild("MoneyStand")
        return 7,
            (stand and stand:FindFirstChild("CharacterSlot")) or (empty and empty:FindFirstChild("Platform")),
            not empty and "Unlock an empty podium to place your character." or nil
    end
    local chambers = plot:FindFirstChild("Chambers")
    local best, bestStep, ready
    if chambers then
        for _, ch in chambers:GetChildren() do
            if not ch:GetAttribute("UnderConstruction") then
                local status = ch:GetAttribute("Status")
                local step = ({
                    AwaitingPickup = 6,
                    Loaded = 5,
                    HatchReveal = 5,
                    Revealing = 5,
                    Incubating = 4,
                    Loading = 4,
                })[status]
                if step and (not bestStep or step > bestStep) then
                    best, bestStep = ch, step
                end
                if status == "Ready" and not ready then
                    ready = ch
                end
            end
        end
    end
    if best then
        local target = best:FindFirstChild("EggPickupAnchor", true) or best:FindFirstChild("HatchButton", true)
        local status = best:GetAttribute("Status")
        if status == "HatchReveal" or status == "Revealing" then
            return 5, target, nil, true
        end
        local note
        if bestStep == 4 then
            local ends = best:GetAttribute("CycleEnd")
            if ends then
                note = "Ready in "
                    .. math.max(0, math.ceil(ends - workspace:GetServerTimeNow()))
                    .. "s. You can explore while you wait."
            end
        end
        return bestStep, target, note
    end
    local egg = tool(player, function(t)
        return t:GetAttribute("EggType") ~= nil
            and not t:GetAttribute("CharacterId")
            and not t:GetAttribute("BrainrotId")
            and not t:GetAttribute("Incubating")
    end)
    if egg then
        if egg:GetAttribute("ReturningToBase") then
            return 2, plot:FindFirstChild("PlotSpawn")
        end
        return 3,
            ready and ready:FindFirstChild("HatchButton", true),
            not ready and "Your incubator is preparing. It will be ready shortly." or nil
    end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local eggs = workspace:FindFirstChild("LocalRiverEggs") or workspace:FindFirstChild("WaterfallEggs")
    local nearest, distance = nil, math.huge
    if eggs and root then
        for _, e in eggs:GetChildren() do
            if
                e:GetAttribute("Price") == 0
                and not e:GetAttribute("Collected")
                and (e:GetAttribute("Collectible") ~= false)
            then
                local anchor = e:FindFirstChild("CollectAnchor", true)
                if anchor then
                    local d = (anchor.Position - root.Position).Magnitude
                    if d < distance then
                        nearest, distance = anchor, d
                    end
                end
            end
        end
    end
    if nearest then
        return 1, nearest
    end
    local conveyor = workspace:FindFirstChild("PirateEggConveyor")
    return 1,
        conveyor and conveyor:FindFirstChild("CollectAnchor"),
        "Head to the river and look for a FREE egg. More eggs arrive regularly."
end
return Guide
