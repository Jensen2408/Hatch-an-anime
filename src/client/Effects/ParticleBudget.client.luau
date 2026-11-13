-- StarterPlayerScripts.ParticleBudget (client only): every ParticleEmitter in the workspace shows fewer particles.
-- A flat cut on Rate, the same at every distance (no particle LOD). Low graphics quality (Roblox levels 1-3) cuts
-- deeper.
--
-- Other scripts keep owning their emitters: whenever anyone else sets Rate (server replication, the Arena / Volcano /
-- portal / Gold FX scripts, ...), that value becomes the new base and is cut again. Our own writes are told apart by
-- value, so this works with deferred signals. The unscaled base is kept in the attribute ParticleBudgetBase for
-- scripts that cache an emitter's Rate (WaterfallCurtain), so the cut never compounds.
-- Opt out per emitter with the attribute FullParticleRate = true.
-- :Emit() bursts are not affected (they don't go through Rate).
local RATE_SCALE = 0.5
local LOW_QUALITY_RATE_SCALE = 0.3

-- [ParticleEmitter] = { base, written }. Weak keys and kept across reparenting, so an emitter that leaves and comes
-- back is not re-read at its already-cut Rate (that would compound the cut).
local tracked = setmetatable({}, { __mode = "k" })

local function qualityScale()
    local ok, level = pcall(function()
        return UserSettings().GameSettings.SavedQualityLevel.Value
    end)
    return (ok and level >= 1 and level <= 3) and LOW_QUALITY_RATE_SCALE or RATE_SCALE
end
local scale = qualityScale()

local function write(emitter, entry)
    local value = entry.base * scale
    entry.written = value
    if emitter.Rate ~= value then
        emitter.Rate = value
    end
end

local function track(emitter)
    if tracked[emitter] or not emitter:IsA("ParticleEmitter") or emitter:GetAttribute("FullParticleRate") then
        return
    end
    local entry = { base = emitter.Rate }
    tracked[emitter] = entry
    emitter:SetAttribute("ParticleBudgetBase", entry.base)
    emitter:GetPropertyChangedSignal("Rate"):Connect(function()
        local rate = emitter.Rate
        if entry.written and math.abs(rate - entry.written) < 1e-4 then
            return -- our own write
        end
        entry.base = rate
        emitter:SetAttribute("ParticleBudgetBase", rate)
        write(emitter, entry)
    end)
    write(emitter, entry)
end

for _, descendant in workspace:GetDescendants() do
    track(descendant)
end
workspace.DescendantAdded:Connect(track)

-- Follow the graphics quality slider.
while true do
    task.wait(2)
    local newScale = qualityScale()
    if newScale ~= scale then
        scale = newScale
        for emitter, entry in pairs(tracked) do
            write(emitter, entry)
        end
    end
end
