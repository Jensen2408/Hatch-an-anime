--[[ ServerScriptService.UpgradeEffects  (ModuleScript, server)
"Ground-rise" construction effect used when a temple / chamber model is swapped for its upgraded version.

UpgradeEffects.Play(opts) -> Model?   (yields for the build duration + 0.2 s)
  opts.swap(prepare)   required. Builds the new model, calls prepare(newModel) before it is visible and
                       returns the new model (or nil to abort).
  opts.anchor          BasePart whose Y position is the "ground" the parts rise from.
  opts.radius          number, copied to the BuildRadius attribute.
  opts.palette         UpgradeEffects.Palettes.Temple or .Chamber (Chamber uses name-based build phases).
  opts.ownerUserId     optional, copied to BuildOwner.
  opts.isValid()       optional; returning false aborts before anything happens.
  opts.oldModel        currently ignored (part retention is disabled by `if false and ...`).

Replication contract: the model gets the "UpgradeAssembly" tag plus Build* / UnderConstruction attributes and each
animated part gets ConstructionDelay / ConstructionFinal, so clients (UpgradeCameraShake) can render the same
animation locally. The server also tweens the parts itself.
No remotes. Note: no active script in src/ requires this module at the moment (only archived versions do).
]]
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local UpgradeEffects = {}
UpgradeEffects.Palettes =
    { Temple = { glow = Color3.fromRGB(255, 196, 84) }, Chamber = { glow = Color3.fromRGB(214, 238, 160) } }

-- Identity key of a part (class, look, size, CFrame), used to match old parts to new ones.
local function partSignature(part)
    local values = { part.ClassName, tostring(part.Color), part.Material.Name }
    for _, component in { part.Size.X, part.Size.Y, part.Size.Z, part.CFrame:GetComponents() } do
        table.insert(values, string.format("%.2f", component))
    end
    if part:IsA("MeshPart") then
        table.insert(values, part.MeshId)
        table.insert(values, part.TextureID)
    end
    return table.concat(values, "|")
end

function UpgradeEffects.Play(opts)
    if opts.isValid and not opts.isValid() then
        return
    end
    -- [signature] = { oldPart, ... }. Retention of identical old parts is disabled (`if false`), so this stays empty.
    local oldParts = {}
    if false and opts.oldModel then
        for _, part in opts.oldModel:GetDescendants() do
            if part:IsA("BasePart") then
                local key = partSignature(part)
                oldParts[key] = oldParts[key] or {}
                table.insert(oldParts[key], part)
            end
        end
    end
    -- records: one entry per animated part; controls: [prompt/light/gui/clickDetector] = original state
    local records, controls = {}, {}
    local duration = 3.4
    local function prepare(model)
        model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
        model:SetAttribute("UnderConstruction", true)
        model:SetAttribute("BuildDuration", duration)
        model:SetAttribute("BuildGround", opts.anchor.Position.Y)
        model:SetAttribute("BuildOwner", opts.ownerUserId or 0)
        model:SetAttribute("BuildRadius", opts.radius)
        model:SetAttribute("BuildKind", opts.palette == UpgradeEffects.Palettes.Temple and "Temple" or "Chamber")
        local retained = 0
        for _, part in model:GetDescendants() do
            if part:IsA("BasePart") then
                local bucket = oldParts[partSignature(part)]
                local original = bucket and table.remove(bucket)
                if original then
                    original.Parent = part.Parent
                    part:Destroy()
                    retained += 1
                else
                    part.Anchored = true
                    table.insert(records, {
                        part = part,
                        cf = part.CFrame,
                        collide = part.CanCollide,
                        volume = part.Size.X * part.Size.Y * part.Size.Z,
                    })
                end
            end
        end
        table.sort(records, function(recordA, recordB)
            -- Structural masses (volume >= 15) before trim; height breaks ties.
            local aIsStructural, bIsStructural = recordA.volume >= 15, recordB.volume >= 15
            if aIsStructural ~= bIsStructural then
                return aIsStructural
            end
            if math.abs(recordA.cf.Y - recordB.cf.Y) > 0.05 then
                return recordA.cf.Y < recordB.cf.Y
            end
            return recordA.volume > recordB.volume
        end)
        local box, size = model:GetBoundingBox()
        model:SetAttribute("BuildFootprint", Vector3.new(size.X, 0, size.Z))
        model:SetAttribute("BuildCenter", Vector3.new(box.X, opts.anchor.Position.Y, box.Z))
        local _riseDistance = math.max(3, box.Y + size.Y * 0.5 - opts.anchor.Position.Y + 0.5)
        for i, record in records do
            local layer =
                math.floor(math.clamp((record.cf.Y - (box.Y - size.Y * 0.5)) / math.max(size.Y, 1), 0, 1) * 12)
            record.delay = layer / 12 * 1.8 + (i % 5) * 0.016
            record.travel = record.volume >= 15 and 1.02 or 0.72
            if record.volume < 15 then
                record.delay += 0.2
            end
            if opts.palette == UpgradeEffects.Palettes.Chamber then
                -- chamber parts are phased by their own + ancestor names (base -> pipes -> glass -> roof)
                local category = record.part.Name:lower()
                local ancestor = record.part.Parent
                while ancestor and ancestor ~= model do
                    category = category .. " " .. ancestor.Name:lower()
                    ancestor = ancestor.Parent
                end
                local phase = 0.65
                if category:find("base", 1, true) or category:find("platform", 1, true) then
                    phase = 0
                elseif
                    category:find("roof", 1, true)
                    or category:find("crown", 1, true)
                    or category:find("eave", 1, true)
                then
                    phase = 1.65
                elseif category:find("glass", 1, true) then
                    phase = 1.1
                elseif
                    category:find("pipe", 1, true)
                    or category:find("tank", 1, true)
                    or category:find("reservoir", 1, true)
                then
                    phase = 0.9
                end
                record.delay = phase
                    + math.clamp((record.cf.Y - opts.anchor.Position.Y) / math.max(size.Y, 1), 0, 1) * 0.18
                record.travel = phase == 0 and 1.05 or 0.85
            end
            record.seat = opts.palette == UpgradeEffects.Palettes.Chamber and 0.08
                or (record.volume >= 15 and 0.2 or 0.1)
            record.part:SetAttribute("ConstructionDelay", record.delay)
            record.part:SetAttribute("ConstructionFinal", record.cf)
            local part = record.part
            -- half the part's vertical extent in world space, so it starts fully below ground
            local extent = (
                math.abs(part.CFrame.RightVector.Y) * part.Size.X
                + math.abs(part.CFrame.UpVector.Y) * part.Size.Y
                + math.abs(part.CFrame.LookVector.Y) * part.Size.Z
            ) * 0.5
            local depth = math.max(2, record.cf.Y + extent - opts.anchor.Position.Y + 0.5)
            local side = (i % 2 == 0 and 1 or -1)
            if opts.palette == UpgradeEffects.Palettes.Chamber then
                part.CFrame = record.cf - Vector3.new(0, depth, 0)
            else
                part.CFrame = (record.cf - Vector3.new(side * 0.22, depth, 0))
                    * CFrame.Angles(0, math.rad(side * 1.5), 0)
            end
            part.CanCollide = false
        end
        -- disable interaction / lights while under construction; restored after the build
        for _, instance in model:GetDescendants() do
            if
                instance:IsA("ProximityPrompt")
                or instance:IsA("Light")
                or instance:IsA("BillboardGui")
                or instance:IsA("SurfaceGui")
            then
                controls[instance] = instance.Enabled
                instance.Enabled = false
            elseif instance:IsA("ClickDetector") then
                controls[instance] = instance.MaxActivationDistance
                instance.MaxActivationDistance = 0
            end
        end
        model:SetAttribute("BuildNewParts", #records)
        model:SetAttribute("BuildRetainedParts", retained)
    end
    local model = opts.swap(prepare)
    if not model then
        return
    end
    local start = workspace:GetServerTimeNow() + 0.2
    model:SetAttribute("BuildStart", start)
    CollectionService:AddTag(model, "UpgradeAssembly")
    local tweens = {}
    for _, record in records do
        task.delay(0.2 + record.delay, function()
            if not model.Parent or not record.part.Parent then
                return
            end
            -- rise slightly past the final position, then "seat" down into it
            local tween = TweenService:Create(
                record.part,
                TweenInfo.new(record.travel, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                { CFrame = record.cf + Vector3.new(0, record.seat, 0) }
            )
            table.insert(tweens, tween)
            tween:Play()
            task.delay(record.travel, function()
                if not model.Parent or not record.part.Parent then
                    return
                end
                local seat = TweenService:Create(
                    record.part,
                    TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                    { CFrame = record.cf }
                )
                table.insert(tweens, seat)
                seat:Play()
            end)
        end)
    end
    task.wait(duration + 0.2)
    -- snap everything to its final state, whatever the tweens reached
    for _, tween in tweens do
        tween:Cancel()
    end
    if model.Parent then
        for _, record in records do
            if record.part.Parent then
                record.part.CFrame = record.cf
                record.part.CanCollide = record.collide
            end
        end
        for instance, state in controls do
            if instance.Parent then
                if instance:IsA("ClickDetector") then
                    instance.MaxActivationDistance = state
                else
                    instance.Enabled = state
                end
            end
        end
        model:SetAttribute("UnderConstruction", false)
        CollectionService:RemoveTag(model, "UpgradeAssembly")
    end
    return model
end

return UpgradeEffects
