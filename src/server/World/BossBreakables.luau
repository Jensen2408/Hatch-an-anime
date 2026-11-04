--[[ ServerScriptService.BossBreakables  (ModuleScript, server only)
The standard "bosses break things" system. Any Model or BasePart tagged "BossBreakable" (CollectionService) can be
smashed by a boss, and comes back after the event.

For a boss service (see BossEventService):
  Breakables.Touch(cframe, size, fromPosition?) -> number broken
      call it every server tick with the boss's body box (world CFrame + full size). Every unbroken tagged prop with a
      part inside the box breaks: its parts are unanchored, stop colliding (so they never block or hit players), tumble
      outward from `fromPosition` (the collapse spreads out from the contact point), fade and are destroyed.
  Breakables.RestoreAll(delaySeconds?)
      once the boss is gone, every broken prop is put back from its pristine copy and pops in (fades in, then collides
      again). BossEventService calls it BossConfig.BreakRespawnSeconds after the event ends.
  Breakables.BrokenCount() -> number

Making something breakable (Studio, saved in the place): CollectionService:AddTag(instance, "BossBreakable"), e.g.
Workspace.Map.Scenery.RiverBridge01 / RiverBridge02. Registration happens at server start and when a tag is added; a
pristine copy of each is kept in ServerStorage.BossBreakableStash (not replicated). Props carry a BreakId attribute, which
survives the clone so a restored prop is recognised as the same one.
Players standing on a prop when it breaks fall with it - that is intended.
]]
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local TAG = "BossBreakable"
local FADE_AFTER = 2.2 -- seconds after breaking before the pieces fade
local FADE_SECONDS = 0.8
local SPREAD_SECONDS_PER_STUD = 0.012 -- the collapse spreads out from the contact point

local Breakables = {}
local entries = {} -- [BreakId] = { inst, stash, parent, broken }

local stashFolder = ServerStorage:FindFirstChild("BossBreakableStash")
if not stashFolder then
    stashFolder = Instance.new("Folder")
    stashFolder.Name = "BossBreakableStash"
    stashFolder.Parent = ServerStorage
end

local function partsOf(inst)
    local parts = {}
    if inst:IsA("BasePart") then
        table.insert(parts, inst)
    end
    for _, descendant in inst:GetDescendants() do
        if descendant:IsA("BasePart") then
            table.insert(parts, descendant)
        end
    end
    return parts
end

local function register(inst)
    if not (inst:IsA("Model") or inst:IsA("BasePart")) or not inst:IsDescendantOf(workspace) then
        return
    end
    local id = inst:GetAttribute("BreakId")
    if id and entries[id] then
        entries[id].inst = inst -- a restored copy
        return
    end
    id = id or HttpService:GenerateGUID(false)
    inst:SetAttribute("BreakId", id)
    local stash = inst:Clone()
    stash.Parent = stashFolder
    entries[id] = { inst = inst, stash = stash, parent = inst.Parent, broken = false }
end

local function ownerId(part)
    local current = part
    while current and current ~= workspace do
        local id = current:GetAttribute("BreakId")
        if id then
            return id
        end
        current = current.Parent
    end
    return nil
end

local function breakEntry(entry, fromPosition)
    local inst = entry.inst
    entry.broken = true
    local parts = partsOf(inst)
    for _, descendant in inst:GetDescendants() do
        if descendant:IsA("WeldConstraint") or descendant:IsA("Weld") or descendant:IsA("ManualWeld") then
            descendant:Destroy()
        end
    end
    for _, part in parts do
        part.CanCollide = false -- debris never blocks or hits a player
        part.CanTouch = false
        part.CanQuery = false
        local offset = part.Position - fromPosition
        local flat = Vector3.new(offset.X, 0, offset.Z)
        local away = flat.Magnitude > 0.1 and flat.Unit or Vector3.xAxis
        task.delay(math.min(offset.Magnitude * SPREAD_SECONDS_PER_STUD, 0.7), function()
            if part.Parent then
                part.Anchored = false
                part.AssemblyLinearVelocity = away * math.random(6, 22) + Vector3.new(0, math.random(8, 24), 0)
                part.AssemblyAngularVelocity = Vector3.new(math.random(-5, 5), math.random(-5, 5), math.random(-5, 5))
            end
        end)
    end
    task.delay(FADE_AFTER, function()
        for _, part in parts do
            if part.Parent then
                TweenService:Create(part, TweenInfo.new(FADE_SECONDS), { Transparency = 1 }):Play()
            end
        end
        task.wait(FADE_SECONDS + 0.1)
        if inst.Parent then
            inst:Destroy()
        end
    end)
end

-- Breaks every unbroken breakable that has a part inside the box. Returns how many broke.
function Breakables.Touch(cframe, size, fromPosition)
    local live = {}
    for _, entry in entries do
        if not entry.broken and entry.inst and entry.inst.Parent then
            table.insert(live, entry.inst)
        end
    end
    if #live == 0 then
        return 0
    end
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = live
    local hits = workspace:GetPartBoundsInBox(cframe, size, params)
    local brokenNow, seen = 0, {}
    for _, part in hits do
        local id = ownerId(part)
        local entry = id and entries[id]
        if entry and not seen[id] and not entry.broken then
            seen[id] = true
            breakEntry(entry, fromPosition or cframe.Position)
            brokenNow += 1
        end
    end
    return brokenNow
end

-- Puts every broken prop back (after `delaySeconds`), fading in.
function Breakables.RestoreAll(delaySeconds)
    task.delay(delaySeconds or 0, function()
        for _, entry in entries do
            if entry.broken then
                entry.broken = false
                if entry.inst and entry.inst.Parent then
                    entry.inst:Destroy() -- any leftover pieces
                end
                local copy = entry.stash:Clone()
                local saved = {}
                for _, part in partsOf(copy) do
                    saved[part] = { transparency = part.Transparency, canCollide = part.CanCollide, canTouch = part.CanTouch, canQuery = part.CanQuery }
                    part.Transparency = 1
                    part.CanCollide = false
                    part.CanTouch = false
                end
                copy.Parent = entry.parent
                entry.inst = copy
                for part, original in saved do
                    TweenService:Create(part, TweenInfo.new(0.8), { Transparency = original.transparency }):Play()
                end
                task.delay(0.9, function()
                    for part, original in saved do
                        if part.Parent then
                            part.CanCollide = original.canCollide
                            part.CanTouch = original.canTouch
                            part.CanQuery = original.canQuery
                        end
                    end
                end)
            end
        end
    end)
end

function Breakables.BrokenCount()
    local n = 0
    for _, entry in entries do
        if entry.broken then
            n += 1
        end
    end
    return n
end

for _, inst in CollectionService:GetTagged(TAG) do
    register(inst)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(register)

return Breakables
