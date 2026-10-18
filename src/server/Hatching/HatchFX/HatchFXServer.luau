--[[ HatchFXServer (ServerScriptService.HatchFX ModuleScript)
Server half of the egg-opening effect. It does not animate anything itself: it publishes the
hatch to clients through attributes / ObjectValues on the incubator and the "Hatching" tag,
then times when the reward character appears, when the egg is removed and when the job ends.
Timings come from ReplicatedStorage.HatchFX.HatchFXConfig.Timeline(roll, rarity).

API:
  Service.Play(options) -> (true, token) | (false, reason)
    options: incubator, egg, character (required); owner, characterParent, displayCFrame,
             rarity, roll, power, income, name, closeGlass, openGlass, onComplete(character, cancelled)
  Service.Cancel(incubator)      ends a hatch now; the character still ends up in the world
  Service.IsBusy(incubator) / Service.IsPlayerBusy(player)
  Service.Hooks                  default glass / display placement, used when options omit them

Replicated contract (read by the HatchFX client): attributes HatchToken (set last, "" when done),
HatchStart, HatchRarity, HatchRoll, HatchPower, HatchIncome, HatchName, HatchOwner;
ObjectValues HatchEgg / HatchCharacter; player attribute HatchOpeningBusy.
--]]
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("HatchFX"):WaitForChild("HatchFXConfig"))

local TAG = "Hatching"
local Service = {}
local activeJobs = {} -- [incubator] = job
local playerJobs = {} -- [player] = job (one opening per player at a time)

-- Adapter: connect your glass doors here. Default tries the IncubatorController module from earlier.
local IncubatorController
pcall(function()
    IncubatorController = require(
        ServerScriptService:FindFirstChild("IncubatorController", true)
            or game.ReplicatedStorage:FindFirstChild("IncubatorController", true)
    )
end)
local controllers = setmetatable({}, { __mode = "k" }) -- [incubator] = controller, weak so removed models can be collected
local function getController(incubator)
    if not IncubatorController then
        return nil
    end
    controllers[incubator] = controllers[incubator] or IncubatorController.new(incubator)
    return controllers[incubator]
end

Service.Hooks = {
    CloseGlass = function(incubator)
        local controller = getController(incubator)
        if controller then
            task.spawn(controller.Close, controller, 0.5)
        end
    end,
    OpenGlass = function(incubator)
        local controller = getController(incubator)
        if controller then
            task.spawn(controller.Open, controller, 0.7)
        end
    end,
    -- where the character stands: platform top, facing the walkway (incubator front = LookVector)
    DisplayCFrame = function(incubator, character)
        local anchor = incubator:FindFirstChild("EggAnchor", true)
        local base = anchor and (anchor:IsA("BasePart") and anchor.CFrame or anchor:GetPivot()) or incubator:GetPivot()
        local _, size = character:GetBoundingBox()
        local facing = incubator:GetPivot().Rotation
        return CFrame.new(base.Position) * facing * CFrame.new(0, size.Y / 2, 0)
    end,
}

-- Anchors every part of `model` for the effect and remembers the original physics flags in `store`.
local function lock(model, store)
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") then
            store[part] = { part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery }
            part.Anchored, part.CanCollide, part.CanTouch = true, false, false
            part.CanQuery = true -- enable surface raycasts
        end
    end
end
local function unlock(store)
    for part, flags in store do
        if part.Parent then
            part.Anchored, part.CanCollide, part.CanTouch = flags[1], flags[2], flags[3]
            part.CanQuery = flags[4]
        end
    end
end

local function clearAttrs(incubator)
    for _, attributeName in
        {
            "HatchToken",
            "HatchStart",
            "HatchRarity",
            "HatchRoll",
            "HatchPower",
            "HatchIncome",
            "HatchName",
            "HatchOwner",
        }
    do
        incubator:SetAttribute(attributeName, nil)
    end
    for _, childName in { "HatchEgg", "HatchCharacter" } do
        local child = incubator:FindFirstChild(childName)
        if child then
            child:Destroy()
        end
    end
    CollectionService:RemoveTag(incubator, TAG)
end

-- Ends a job exactly once (normal end, Cancel, or incubator removed).
local function finish(job, cancelled)
    if job.done then
        return
    end
    job.done = true
    if job.o.owner and playerJobs[job.o.owner] == job then
        playerJobs[job.o.owner] = nil
        job.o.owner:SetAttribute("HatchOpeningBusy", nil)
    end
    if job.ancestry then
        job.ancestry:Disconnect()
    end
    -- finish() itself may run inside one of these delayed threads; never cancel the running one.
    for _, thread in job.threads do
        if thread ~= coroutine.running() then
            pcall(task.cancel, thread)
        end
    end
    local character = job.o.character
    if character and not character.Parent then
        character.Parent = job.o.characterParent or job.o.incubator
    end -- reward always ends up in the world
    if character and character.Parent then
        character:PivotTo(job.display)
    end
    if job.o.egg and job.o.egg.Parent then
        job.o.egg:Destroy()
    end
    unlock(job.locks)
    if job.o.incubator.Parent then
        job.o.incubator:SetAttribute("HatchToken", "")
        if job.o.openGlass then
            job.o.openGlass()
        else
            Service.Hooks.OpenGlass(job.o.incubator)
        end
    end
    activeJobs[job.o.incubator] = nil
    -- Keep the label attributes a moment for the client's result label, unless a new hatch started.
    task.delay(Config.LabelHold + 0.5, function()
        if
            job.o.incubator.Parent
            and not activeJobs[job.o.incubator]
            and job.o.incubator:GetAttribute("HatchToken") == ""
        then
            clearAttrs(job.o.incubator)
        end
    end)
    if job.o.onComplete then
        task.spawn(job.o.onComplete, character, cancelled)
    end
end

function Service.Play(options)
    local incubator = options.incubator
    if not (incubator and incubator.Parent and options.character and options.egg) then
        return false, "Missing incubator, egg or character"
    end
    if activeJobs[incubator] then
        return false, "Already hatching"
    end
    if options.owner and playerJobs[options.owner] then
        return false, "Another egg is opening"
    end
    local timeline = Config.Timeline(options.roll, options.rarity)
    local job = { o = options, token = HttpService:GenerateGUID(false), threads = {}, locks = {} }
    activeJobs[incubator] = job
    if options.owner then
        playerJobs[options.owner] = job
        options.owner:SetAttribute("HatchOpeningBusy", true)
    end
    job.display = options.displayCFrame or Service.Hooks.DisplayCFrame(incubator, options.character)
    lock(options.egg, job.locks)
    lock(options.character, job.locks)
    -- The character is held out of the world until just before the shell breaks.
    options.character.Parent = nil
    options.character:PivotTo(job.display)

    incubator:SetAttribute("HatchStart", workspace:GetServerTimeNow())
    incubator:SetAttribute("HatchRarity", options.rarity or "Common")
    incubator:SetAttribute("HatchRoll", options.roll or "Ordinary")
    incubator:SetAttribute("HatchPower", tonumber(options.power) or 0)
    incubator:SetAttribute("HatchIncome", tonumber(options.income) or 0)
    incubator:SetAttribute("HatchName", options.name or options.character.Name)
    incubator:SetAttribute("HatchOwner", options.owner and options.owner.UserId or 0)
    local eggRef = Instance.new("ObjectValue")
    eggRef.Name = "HatchEgg"
    eggRef.Value = options.egg
    eggRef.Parent = incubator
    local characterRef = Instance.new("ObjectValue")
    characterRef.Name = "HatchCharacter"
    characterRef.Parent = incubator
    incubator:SetAttribute("HatchToken", job.token) -- set last: clients start when this changes
    CollectionService:AddTag(incubator, TAG)
    if options.closeGlass then
        options.closeGlass()
    else
        Service.Hooks.CloseGlass(incubator)
    end

    table.insert(
        job.threads,
        task.delay(math.max(0, timeline.Break - 0.4), function()
            options.character.Parent = options.characterParent or incubator -- arrives slightly early; clients hide it until the break
            characterRef.Value = options.character
        end)
    )
    table.insert(
        job.threads,
        task.delay(timeline.Break + 0.6, function()
            if options.egg.Parent then
                options.egg:Destroy()
            end
        end)
    )
    table.insert(
        job.threads,
        task.delay(timeline.End, function()
            finish(job, false)
        end)
    )
    job.ancestry = incubator.AncestryChanged:Connect(function()
        if not incubator:IsDescendantOf(workspace) then
            finish(job, true)
        end
    end)
    return true, job.token
end

-- Ends instantly but still leaves the awarded character in place (owner left, plot reset, etc.)
function Service.Cancel(incubator)
    local job = activeJobs[incubator]
    if job then
        finish(job, true)
    end
end
function Service.IsBusy(incubator)
    return activeJobs[incubator] ~= nil
end

function Service.IsPlayerBusy(player)
    return playerJobs[player] ~= nil
end
return Service
