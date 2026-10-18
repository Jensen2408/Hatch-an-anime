--[[ ServerScriptService.Construction.ConstructionService  (ModuleScript, server)
Authoritative upgrade construction. It owns:
  • construction locks per plot
  • the final model state (applied immediately on the server; clients only animate cosmetically)
  • collision / prompt suppression while building
  • completion, cancellation and recovery

How clients see it: the final model is in Workspace from the first frame, tagged "Constructing".
Each animated part carries Cx_* attributes (batch index, previous state). Clients hide those parts the
moment they replicate (LocalTransparencyModifier, which doesn't replicate) and animate them in.
Nobody ever sees a fully-built server model and an animated copy at the same time.

API
  local Construction = require(game.ServerScriptService.Construction.ConstructionService)
  local ok, modelOrErr = Construction.Upgrade({
      key = plotId .. ":temple",      -- lock key (one construction at a time per key)
      owner = player,                 -- purchasing player (gets the camera shake); may be nil
      kind = "Temple" | "Incubator",
      parent = plotFolder,            -- where the structure lives
      oldModel = currentModel,        -- nil for a first build
      template = templateModel,       -- the next level's template (never modified)
      pivot = targetPivotCFrame,      -- where the finished structure must sit
      mode = "auto" | "incremental" | "replace",
      onComplete = function(model) end, -- runs once construction has fully finished
  })
  Construction.IsBusy(key) -> bool
  Construction.Cancel(key)          -- finish instantly (plot reset, owner left, etc.)
]]
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Construction"):WaitForChild("ConstructionConfig"))
local TAG = "Constructing"

local Service = {}
local active = {} -- [key] = job

---------------------------------------------------------------- identity + diff
local function round(v, s)
    return math.floor(v / s + 0.5) * s
end
local function relPath(inst, root)
    local parts = {}
    local cur = inst
    while cur and cur ~= root do
        table.insert(parts, 1, cur.Name)
        cur = cur.Parent
    end
    return table.concat(parts, "/")
end
-- Stable id: explicit BuildId attribute, else path + rounded local position + size (handles repeated names)
local function partId(part, root, rootCF)
    local explicit = part:GetAttribute("BuildId")
    if explicit then
        return tostring(explicit), true
    end
    local lp = rootCF:PointToObjectSpace(part.Position)
    local s = part.Size
    return string.format(
        "%s|%.2f,%.2f,%.2f|%.2f,%.2f,%.2f",
        relPath(part, root),
        round(lp.X, 0.05),
        round(lp.Y, 0.05),
        round(lp.Z, 0.05),
        round(s.X, 0.05),
        round(s.Y, 0.05),
        round(s.Z, 0.05)
    ),
        false
end
local function index(model)
    local root = model:GetPivot()
    local map = {}
    for _, d in model:GetDescendants() do
        if d:IsA("BasePart") then
            local id, explicit = partId(d, model, root)
            if map[id] then
                id ..= "#" .. tostring(#d:GetFullName()) .. tostring(d)
            end
            map[id] = { part = d, explicit = explicit }
        end
    end
    return map
end
local function sameLook(a, b)
    return a.Color == b.Color and a.Material == b.Material and a.Transparency == b.Transparency and a.Size == b.Size
end

---------------------------------------------------------------- staging
local function stageOf(part, model, kind, relY, height)
    local role = part:GetAttribute("BuildRole")
    if type(role) == "number" then
        return math.clamp(math.floor(role), 1, 6)
    end
    if type(role) == "string" and Config.RoleStage[role] then
        return Config.RoleStage[role]
    end
    local kw = Config.Keywords[kind] or Config.Keywords.Temple
    local cur = part
    while cur and cur ~= model do
        local n = cur.Name:lower()
        for _, entry in kw do
            for _, word in entry[2] do
                if n:find(word, 1, true) then
                    return entry[1]
                end
            end
        end
        cur = cur.Parent
    end
    return 1 + math.clamp(math.floor(relY / math.max(height, 1) * 5.99), 0, 5) -- height fallback
end

-- assigns Cx_Batch (1..n) to each part in `animated`; returns n
local function assignBatches(model, animated, kind)
    local pivot = model:GetPivot()
    local cf, size = model:GetBoundingBox()
    local bottom = cf.Position.Y - size.Y / 2
    local buckets, keys = {}, {}
    for _, part in animated do
        local relY = part.Position.Y - part.Size.Y / 2 - bottom
        local stage = stageOf(part, model, kind, relY, size.Y)
        local band = math.floor(math.max(relY, 0) / Config.WaveBand)
        local lx = pivot:PointToObjectSpace(part.Position).X
        local side = (stage == 1 or math.abs(lx) < 0.75) and 0 or (lx < 0 and 1 or 2)
        local key = stage * 10000 + band * 10 + side
        if not buckets[key] then
            buckets[key] = {}
            table.insert(keys, key)
        end
        table.insert(buckets[key], part)
    end
    table.sort(keys, function(a, b)
        local sa, sb = a // 10000, b // 10000
        if sa ~= sb then
            return sa < sb
        end
        local ba, bb = (a % 10000) // 10, (b % 10000) // 10
        if ba ~= bb then
            return ba < bb
        end
        -- alternate left/right per band so assembly reads as deliberate
        local flip = ba % 2 == 1
        local xa, xb = a % 10, b % 10
        if flip then
            return xa > xb
        end
        return xa < xb
    end)
    -- merge adjacent buckets down to MaxBatches
    local groups = {}
    for _, k in keys do
        table.insert(groups, { stage = k // 10000, parts = buckets[k] })
    end
    while #groups > Config.MaxBatches do
        local bestI, bestN = 1, math.huge
        for i = 1, #groups - 1 do
            if groups[i].stage == groups[i + 1].stage or #groups > Config.MaxBatches * 1.5 then
                local n = #groups[i].parts + #groups[i + 1].parts
                if n < bestN then
                    bestN, bestI = n, i
                end
            end
        end
        if bestN == math.huge then
            bestI = 1
        end
        for _, p in groups[bestI + 1].parts do
            table.insert(groups[bestI].parts, p)
        end
        table.remove(groups, bestI + 1)
    end
    for i, g in groups do
        for _, p in g.parts do
            p:SetAttribute("Cx_Batch", i)
            p:SetAttribute("Cx_Stage", g.stage)
        end
    end
    return #groups
end

---------------------------------------------------------------- collision / prompts while building
local function suppress(job, part)
    if part:GetAttribute("Cx_OrigCollide") == nil then
        part:SetAttribute("Cx_OrigCollide", part.CanCollide)
        part:SetAttribute("Cx_OrigQuery", part.CanQuery)
        part:SetAttribute("Cx_OrigTouch", part.CanTouch)
    end
    part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
    table.insert(job.suppressed, part)
end
local function disablePrompts(job, model)
    for _, d in model:GetDescendants() do
        if d:IsA("ProximityPrompt") or d:IsA("ClickDetector") then
            if d:IsA("ProximityPrompt") then
                if d.Enabled then
                    d.Enabled = false
                    table.insert(job.prompts, d)
                end
            else
                if d.MaxActivationDistance > 0 then
                    d:SetAttribute("Cx_OrigDist", d.MaxActivationDistance)
                    d.MaxActivationDistance = 0
                    table.insert(job.prompts, d)
                end
            end
        end
    end
end
local function clearAttrs(inst)
    for name in inst:GetAttributes() do
        if name:sub(1, 3) == "Cx_" then
            inst:SetAttribute(name, nil)
        end
    end
end

local function finish(job, reason)
    if job.done then
        return
    end
    job.done = true
    if job.retireThread then
        task.cancel(job.retireThread)
    end
    if job.finishThread then
        task.cancel(job.finishThread)
    end
    for _, p in job.retiring do
        if p.Parent then
            p:Destroy()
        end
    end
    if job.oldModel and job.oldModel ~= job.model and job.oldModel.Parent then
        job.oldModel:Destroy()
    end
    for _, part in job.suppressed do
        if part.Parent then
            part.CanCollide = part:GetAttribute("Cx_OrigCollide") ~= false
            part.CanQuery = part:GetAttribute("Cx_OrigQuery") ~= false
            part.CanTouch = part:GetAttribute("Cx_OrigTouch") ~= false
        end
    end
    for _, d in job.prompts do
        if d.Parent then
            if d:IsA("ProximityPrompt") then
                d.Enabled = true
            else
                d.MaxActivationDistance = d:GetAttribute("Cx_OrigDist") or 32
                d:SetAttribute("Cx_OrigDist", nil)
            end
        end
    end
    local model = job.model
    if model and model.Parent then
        for _, d in model:GetDescendants() do
            if d:IsA("BasePart") then
                clearAttrs(d)
            end
        end
        clearAttrs(model)
        if reason ~= "complete" then
            model:SetAttribute("ConstructionCancelled", true) -- clients snap to the final state
            task.delay(2, function()
                if model.Parent then
                    model:SetAttribute("ConstructionCancelled", nil)
                end
            end)
        end
        CollectionService:RemoveTag(model, TAG)
        if job.parent then
            job.parent:SetAttribute("Constructing", nil)
        end
    end
    active[job.key] = nil
    if job.onComplete and model and model.Parent then
        task.spawn(job.onComplete, model, reason)
    end
end

---------------------------------------------------------------- public
function Service.IsBusy(key)
    return active[key] ~= nil
end

function Service.Cancel(key)
    local job = active[key]
    if job then
        finish(job, "cancelled")
    end
end

function Service.Upgrade(o)
    assert(o.key and o.template and o.parent, "Upgrade needs key, template and parent")
    if active[o.key] then
        return false, "Construction already running"
    end
    local kind = Config.Kinds[o.kind] and o.kind or "Temple"
    local job = {
        key = o.key,
        kind = kind,
        parent = o.parent,
        oldModel = o.oldModel,
        onComplete = o.onComplete,
        suppressed = {},
        prompts = {},
        retiring = {},
    }
    active[o.key] = job -- lock first

    local ok, err = pcall(function()
        local pivot = o.pivot or (o.oldModel and o.oldModel:GetPivot()) or o.template:GetPivot()
        local fresh = o.template:Clone()
        fresh:PivotTo(pivot)
        for _, d in fresh:GetDescendants() do
            if d:IsA("BasePart") then
                d.Anchored = true
            end
        end

        -- decide mode
        local mode = o.mode or "auto"
        local oldMap, newMap
        if o.oldModel then
            oldMap, newMap = index(o.oldModel), index(fresh)
            if mode == "auto" then
                local matched, total = 0, 0
                for id in newMap do
                    total += 1
                    if oldMap[id] then
                        matched += 1
                    end
                end
                for id in oldMap do
                    if not newMap[id] then
                        total += 1
                    end
                end
                mode = (total > 0 and matched / total >= Config.ReplaceBelowOverlap) and "incremental" or "replace"
            end
        else
            mode = "replace"
        end
        job.mode = mode

        local model, animated = nil, {}
        if mode == "incremental" then
            -- mutate the existing model in place: unchanged parts never move
            model = o.oldModel
            fresh.Parent = nil
            for id, entry in newMap do
                local old = oldMap[id]
                local new = entry.part
                if old then
                    local op = old.part
                    if op.CFrame ~= new.CFrame or not sameLook(op, new) then
                        op:SetAttribute("Cx_FromCF", op.CFrame)
                        op:SetAttribute("Cx_FromSize", op.Size)
                        op.CFrame, op.Size = new.CFrame, new.Size
                        op.Color, op.Material, op.Transparency = new.Color, new.Material, new.Transparency
                        table.insert(animated, op)
                    end
                else
                    -- added: recreate its parent chain in the old model, then move the part across
                    local path = string.split(relPath(new.Parent, fresh), "/")
                    local dest = model
                    if new.Parent ~= fresh then
                        for _, seg in path do
                            if seg ~= "" then
                                local nxt = dest:FindFirstChild(seg)
                                if not nxt then
                                    nxt = Instance.new("Model")
                                    nxt.Name = seg
                                    nxt.Parent = dest
                                end
                                dest = nxt
                            end
                        end
                    end
                    new.Parent = dest
                    table.insert(animated, new)
                end
            end
            for id, entry in oldMap do
                if not newMap[id] then
                    entry.part:SetAttribute("Cx_Retire", true)
                    suppress(job, entry.part)
                    table.insert(job.retiring, entry.part)
                end
            end
            fresh:Destroy()
        else
            model = fresh
            for _, d in model:GetDescendants() do
                if d:IsA("BasePart") then
                    table.insert(animated, d)
                end
            end
            if o.oldModel then
                for _, d in o.oldModel:GetDescendants() do
                    if d:IsA("BasePart") then
                        d:SetAttribute("Cx_Retire", true)
                        suppress(job, d)
                        table.insert(job.retiring, d)
                    end
                end
                o.oldModel:SetAttribute("Cx_RetireOnly", true)
                CollectionService:AddTag(o.oldModel, TAG)
            end
        end
        job.model = model

        local n = assignBatches(model, animated, kind)
        for _, p in animated do
            suppress(job, p)
        end
        disablePrompts(job, model)
        local tl = Config.Timeline(kind, n, mode == "replace" and o.oldModel ~= nil)
        local start = workspace:GetServerTimeNow()
        local id = HttpService:GenerateGUID(false)
        for _, m in { model, o.oldModel } do
            if m then
                m:SetAttribute("Cx_Id", id)
                m:SetAttribute("Cx_Start", start)
                m:SetAttribute("Cx_Kind", kind)
                m:SetAttribute("Cx_Batches", n)
                m:SetAttribute("Cx_Replace", mode == "replace" and o.oldModel ~= nil)
                m:SetAttribute("Cx_Owner", o.owner and o.owner.UserId or 0)
            end
        end
        o.parent:SetAttribute("Constructing", true)
        CollectionService:AddTag(model, TAG) -- tag BEFORE parenting so clients hide parts on arrival
        if model.Parent ~= o.parent then
            model.Parent = o.parent
        end

        if #job.retiring > 0 then
            job.retireThread = task.delay(tl.retireEnd + 0.1, function()
                job.retireThread = nil
                for _, p in job.retiring do
                    if p.Parent then
                        p:Destroy()
                    end
                end
                job.retiring = {}
                if job.oldModel and job.oldModel ~= model and job.oldModel.Parent then
                    job.oldModel:Destroy()
                end
            end)
        end
        job.finishThread = task.delay(tl.lockInEnd, function()
            job.finishThread = nil
            finish(job, "complete")
        end)
    end)

    if not ok then
        warn("[Construction] upgrade failed, restoring:", err)
        -- recovery: if the new model never got parented, the old one is untouched
        if job.model and job.model ~= o.oldModel and job.model.Parent and o.oldModel and o.oldModel.Parent then
            job.model:Destroy()
            job.model = o.oldModel
        end
        job.oldModel = nil
        finish(job, "failed")
        return false, tostring(err)
    end
    return true, job.model
end

-- safety: if a plot/model disappears mid-build, release its lock
game:GetService("RunService").Heartbeat:Connect(function()
    for _, job in active do
        if job.model and not job.model:IsDescendantOf(workspace) then
            finish(job, "removed")
        end
    end
end)

return Service
