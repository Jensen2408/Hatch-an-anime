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

local ConstructionService = {}
local active = {} -- [key] = job

---------------------------------------------------------------- identity + diff
local function roundTo(value, step)
    return math.floor(value / step + 0.5) * step
end
local function relPath(instance, root)
    local names = {}
    local current = instance
    while current and current ~= root do
        table.insert(names, 1, current.Name)
        current = current.Parent
    end
    return table.concat(names, "/")
end
-- Stable id: explicit BuildId attribute, else path + rounded local position + size (handles repeated names)
local function partId(part, root, rootCF)
    local explicit = part:GetAttribute("BuildId")
    if explicit then
        return tostring(explicit), true
    end
    local localPos = rootCF:PointToObjectSpace(part.Position)
    local size = part.Size
    return string.format(
        "%s|%.2f,%.2f,%.2f|%.2f,%.2f,%.2f",
        relPath(part, root),
        roundTo(localPos.X, 0.05),
        roundTo(localPos.Y, 0.05),
        roundTo(localPos.Z, 0.05),
        roundTo(size.X, 0.05),
        roundTo(size.Y, 0.05),
        roundTo(size.Z, 0.05)
    ),
        false
end
local function indexParts(model)
    local rootCFrame = model:GetPivot()
    local partsById = {}
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") then
            local id, explicit = partId(descendant, model, rootCFrame)
            if partsById[id] then
                id ..= "#" .. tostring(#descendant:GetFullName()) .. tostring(descendant)
            end
            partsById[id] = { part = descendant, explicit = explicit }
        end
    end
    return partsById
end
local function sameLook(partA, partB)
    return partA.Color == partB.Color
        and partA.Material == partB.Material
        and partA.Transparency == partB.Transparency
        and partA.Size == partB.Size
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
    local keywordGroups = Config.Keywords[kind] or Config.Keywords.Temple
    local current = part
    while current and current ~= model do
        local lowerName = current.Name:lower()
        for _, entry in keywordGroups do
            for _, word in entry[2] do
                if lowerName:find(word, 1, true) then
                    return entry[1]
                end
            end
        end
        current = current.Parent
    end
    return 1 + math.clamp(math.floor(relY / math.max(height, 1) * 5.99), 0, 5) -- height fallback
end

-- assigns Cx_Batch (1..n) to each part in `animated`; returns n
local function assignBatches(model, animated, kind)
    local pivot = model:GetPivot()
    local boxCFrame, size = model:GetBoundingBox()
    local bottom = boxCFrame.Position.Y - size.Y / 2
    local buckets, bucketKeys = {}, {}
    for _, part in animated do
        local relY = part.Position.Y - part.Size.Y / 2 - bottom
        local stage = stageOf(part, model, kind, relY, size.Y)
        local band = math.floor(math.max(relY, 0) / Config.WaveBand)
        local localX = pivot:PointToObjectSpace(part.Position).X
        local side = (stage == 1 or math.abs(localX) < 0.75) and 0 or (localX < 0 and 1 or 2)
        -- bucket key packs (stage, height band, side) so sorting keys orders the build: stage, then band, then side
        local bucketKey = stage * 10000 + band * 10 + side
        if not buckets[bucketKey] then
            buckets[bucketKey] = {}
            table.insert(bucketKeys, bucketKey)
        end
        table.insert(buckets[bucketKey], part)
    end
    table.sort(bucketKeys, function(keyA, keyB)
        local stageA, stageB = keyA // 10000, keyB // 10000
        if stageA ~= stageB then
            return stageA < stageB
        end
        local bandA, bandB = (keyA % 10000) // 10, (keyB % 10000) // 10
        if bandA ~= bandB then
            return bandA < bandB
        end
        -- alternate left/right per band so assembly reads as deliberate
        local flip = bandA % 2 == 1
        local sideA, sideB = keyA % 10, keyB % 10
        if flip then
            return sideA > sideB
        end
        return sideA < sideB
    end)
    -- merge adjacent buckets down to MaxBatches
    local groups = {}
    for _, bucketKey in bucketKeys do
        table.insert(groups, { stage = bucketKey // 10000, parts = buckets[bucketKey] })
    end
    while #groups > Config.MaxBatches do
        local bestIndex, bestSize = 1, math.huge
        for i = 1, #groups - 1 do
            if groups[i].stage == groups[i + 1].stage or #groups > Config.MaxBatches * 1.5 then
                local mergedSize = #groups[i].parts + #groups[i + 1].parts
                if mergedSize < bestSize then
                    bestSize, bestIndex = mergedSize, i
                end
            end
        end
        if bestSize == math.huge then
            bestIndex = 1
        end
        for _, part in groups[bestIndex + 1].parts do
            table.insert(groups[bestIndex].parts, part)
        end
        table.remove(groups, bestIndex + 1)
    end
    for i, group in groups do
        for _, part in group.parts do
            part:SetAttribute("Cx_Batch", i)
            part:SetAttribute("Cx_Stage", group.stage)
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
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("ProximityPrompt") or descendant:IsA("ClickDetector") then
            if descendant:IsA("ProximityPrompt") then
                if descendant.Enabled then
                    descendant.Enabled = false
                    table.insert(job.prompts, descendant)
                end
            else
                if descendant.MaxActivationDistance > 0 then
                    descendant:SetAttribute("Cx_OrigDist", descendant.MaxActivationDistance)
                    descendant.MaxActivationDistance = 0
                    table.insert(job.prompts, descendant)
                end
            end
        end
    end
end
local function clearConstructionAttrs(instance)
    for name in instance:GetAttributes() do
        if name:sub(1, 3) == "Cx_" then
            instance:SetAttribute(name, nil)
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
    for _, part in job.retiring do
        if part.Parent then
            part:Destroy()
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
    for _, control in job.prompts do
        if control.Parent then
            if control:IsA("ProximityPrompt") then
                control.Enabled = true
            else
                control.MaxActivationDistance = control:GetAttribute("Cx_OrigDist") or 32
                control:SetAttribute("Cx_OrigDist", nil)
            end
        end
    end
    local model = job.model
    if model and model.Parent then
        for _, control in model:GetDescendants() do
            if control:IsA("BasePart") then
                clearConstructionAttrs(control)
            end
        end
        clearConstructionAttrs(model)
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
function ConstructionService.IsBusy(key)
    return active[key] ~= nil
end

function ConstructionService.Cancel(key)
    local job = active[key]
    if job then
        finish(job, "cancelled")
    end
end

function ConstructionService.Upgrade(options)
    assert(options.key and options.template and options.parent, "Upgrade needs key, template and parent")
    if active[options.key] then
        return false, "Construction already running"
    end
    local kind = Config.Kinds[options.kind] and options.kind or "Temple"
    local job = {
        key = options.key,
        kind = kind,
        parent = options.parent,
        oldModel = options.oldModel,
        onComplete = options.onComplete,
        suppressed = {},
        prompts = {},
        retiring = {},
    }
    active[options.key] = job -- lock first

    local ok, err = pcall(function()
        local pivot = options.pivot or (options.oldModel and options.oldModel:GetPivot()) or options.template:GetPivot()
        local fresh = options.template:Clone()
        fresh:PivotTo(pivot)
        for _, descendant in fresh:GetDescendants() do
            if descendant:IsA("BasePart") then
                descendant.Anchored = true
            end
        end

        -- decide mode
        local mode = options.mode or "auto"
        local oldMap, newMap
        if options.oldModel then
            oldMap, newMap = indexParts(options.oldModel), indexParts(fresh)
            if mode == "auto" then
                local matched, total = 0, 0
                for partKey in newMap do
                    total += 1
                    if oldMap[partKey] then
                        matched += 1
                    end
                end
                for partKey in oldMap do
                    if not newMap[partKey] then
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
            model = options.oldModel
            fresh.Parent = nil
            for partKey, entry in newMap do
                local oldEntry = oldMap[partKey]
                local newPart = entry.part
                if oldEntry then
                    local oldPart = oldEntry.part
                    if oldPart.CFrame ~= newPart.CFrame or not sameLook(oldPart, newPart) then
                        oldPart:SetAttribute("Cx_FromCF", oldPart.CFrame)
                        oldPart:SetAttribute("Cx_FromSize", oldPart.Size)
                        oldPart.CFrame, oldPart.Size = newPart.CFrame, newPart.Size
                        oldPart.Color, oldPart.Material, oldPart.Transparency =
                            newPart.Color, newPart.Material, newPart.Transparency
                        table.insert(animated, oldPart)
                    end
                else
                    -- added: recreate its parent chain in the old model, then move the part across
                    local path = string.split(relPath(newPart.Parent, fresh), "/")
                    local destination = model
                    if newPart.Parent ~= fresh then
                        for _, segment in path do
                            if segment ~= "" then
                                local child = destination:FindFirstChild(segment)
                                if not child then
                                    child = Instance.new("Model")
                                    child.Name = segment
                                    child.Parent = destination
                                end
                                destination = child
                            end
                        end
                    end
                    newPart.Parent = destination
                    table.insert(animated, newPart)
                end
            end
            for partKey, entry in oldMap do
                if not newMap[partKey] then
                    entry.part:SetAttribute("Cx_Retire", true)
                    suppress(job, entry.part)
                    table.insert(job.retiring, entry.part)
                end
            end
            fresh:Destroy()
        else
            model = fresh
            for _, descendant in model:GetDescendants() do
                if descendant:IsA("BasePart") then
                    table.insert(animated, descendant)
                end
            end
            if options.oldModel then
                for _, descendant in options.oldModel:GetDescendants() do
                    if descendant:IsA("BasePart") then
                        descendant:SetAttribute("Cx_Retire", true)
                        suppress(job, descendant)
                        table.insert(job.retiring, descendant)
                    end
                end
                options.oldModel:SetAttribute("Cx_RetireOnly", true)
                CollectionService:AddTag(options.oldModel, TAG)
            end
        end
        job.model = model

        local batchCount = assignBatches(model, animated, kind)
        for _, part in animated do
            suppress(job, part)
        end
        disablePrompts(job, model)
        local timeline = Config.Timeline(kind, batchCount, mode == "replace" and options.oldModel ~= nil)
        local startTime = workspace:GetServerTimeNow()
        local constructionId = HttpService:GenerateGUID(false)
        for _, target in { model, options.oldModel } do
            if target then
                target:SetAttribute("Cx_Id", constructionId)
                target:SetAttribute("Cx_Start", startTime)
                target:SetAttribute("Cx_Kind", kind)
                target:SetAttribute("Cx_Batches", batchCount)
                target:SetAttribute("Cx_Replace", mode == "replace" and options.oldModel ~= nil)
                target:SetAttribute("Cx_Owner", options.owner and options.owner.UserId or 0)
            end
        end
        options.parent:SetAttribute("Constructing", true)
        CollectionService:AddTag(model, TAG) -- tag BEFORE parenting so clients hide parts on arrival
        if model.Parent ~= options.parent then
            model.Parent = options.parent
        end

        if #job.retiring > 0 then
            job.retireThread = task.delay(timeline.retireEnd + 0.1, function()
                job.retireThread = nil
                for _, part in job.retiring do
                    if part.Parent then
                        part:Destroy()
                    end
                end
                job.retiring = {}
                if job.oldModel and job.oldModel ~= model and job.oldModel.Parent then
                    job.oldModel:Destroy()
                end
            end)
        end
        job.finishThread = task.delay(timeline.lockInEnd, function()
            job.finishThread = nil
            finish(job, "complete")
        end)
    end)

    if not ok then
        warn("[Construction] upgrade failed, restoring:", err)
        -- recovery: if the new model never got parented, the old one is untouched
        if
            job.model
            and job.model ~= options.oldModel
            and job.model.Parent
            and options.oldModel
            and options.oldModel.Parent
        then
            job.model:Destroy()
            job.model = options.oldModel
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

return ConstructionService
