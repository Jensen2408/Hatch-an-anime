-- StarterPlayerScripts.TempleLOD (client only): level of detail for the plot temples (workspace.Plots.*.Temple).
-- Distant temples keep their whole structure (roof tiers, rafters, posts, walls, floors, steps) and only drop
-- detail that is too small or too dim to read from far away, so they never turn into blobs the way Roblox's
-- StreamingMesh impostors do.
--
-- Level of detail, from the camera to the nearest point of the temple's bounding box:
--   LOD 0  < LOD1_DISTANCE  everything
--   LOD 1  < LOD2_DISTANCE  lights parked (38 PointLights per temple), interior ceiling lanterns, Halloween candles /
--                           webs / spider and parts under 2 studs hidden
--   LOD 2  beyond           also the Halloween string-light bulbs and parts under 4 studs hidden; parts under 8 studs
--                           stop casting shadows; and the temple is swapped for its proxy (ReplicatedStorage.TempleProxy):
--                           one vertex-coloured MeshPart with the tile quads merged into large rectangles, ~260 draw
--                           calls and ~20k triangles down to 1 part and a few thousand. Parts without baked proxy data
--                           stay as they are. The proxy is built the first time a temple reaches LOD 2 and rebuilt
--                           (after PROXY_SETTLE seconds) when the temple changes (upgrade, build animation, theme).
-- Low graphics quality (Roblox levels 1-3) pulls both distances in.
--
-- Everything here is local and reversible:
--   parts   LocalTransparencyModifier = 1 (Transparency itself is left to the server), CastShadow restored from a cache
--   lights  parented to nil while parked, never Enabled: the server's TempleOccupancy owns Enabled (claimed plots
--           light up), and its changes still replicate to a parked light, so it comes back in the right state
-- Temples are replaced on upgrade (PlotManager / ConstructionService) and parts arrive during the build animation,
-- so new temples and new parts are classified as they appear.
local LOD1_DISTANCE = 140
local LOD2_DISTANCE = 300
local HYSTERESIS = 12 -- studs a temple must move back inside a boundary before it gains detail again
local LOW_QUALITY_SCALE = 0.65
local UPDATE_INTERVAL = 0.25

local FINE_SIZE = 2 -- largest dimension below which a part is hidden from LOD 1
local SMALL_SIZE = 4 -- ... from LOD 2
local SHADOW_SIZE = 8 -- ... below which a part stops casting shadows at LOD 2

local PROXY_SETTLE = 3 -- seconds a temple must go unchanged before its proxy is (re)built

local camera = workspace.CurrentCamera
local plots = workspace:WaitForChild("Plots")
local temples = {} -- [Model] = { model, level, bucket, shadowCast, lightParent, cframe, half, boundsDirty, connections,
--                                proxy, proxyActive, proxyBuilding, changedAt }

local TempleProxy
do
    local module = game:GetService("ReplicatedStorage"):WaitForChild("TempleProxy", 10)
    local ok, result = pcall(function()
        return module and require(module)
    end)
    TempleProxy = ok and result or nil
end
local proxyFolder = Instance.new("Folder")
proxyFolder.Name = "TempleLODProxies"
proxyFolder.Parent = workspace

local function qualityScale()
    local ok, level = pcall(function()
        return UserSettings().GameSettings.SavedQualityLevel.Value
    end)
    return (ok and level >= 1 and level <= 3) and LOW_QUALITY_SCALE or 1
end

local function hasAncestorNamed(instance, root, prefix)
    local parent = instance.Parent
    while parent and parent ~= root do
        if string.sub(parent.Name, 1, #prefix) == prefix then
            return true
        end
        parent = parent.Parent
    end
    return false
end

local function setPartHidden(part, hidden)
    part.LocalTransparencyModifier = hidden and 1 or 0
end

local function setShadowCut(state, part, cut)
    if cut then
        if state.shadowCast[part] == nil then
            state.shadowCast[part] = part.CastShadow
        end
        part.CastShadow = false
    elseif state.shadowCast[part] ~= nil then
        part.CastShadow = state.shadowCast[part]
        state.shadowCast[part] = nil
    end
end

local function setLightParked(state, light, parked)
    if parked then
        if state.lightParent[light] == nil and light.Parent then
            state.lightParent[light] = light.Parent
            light.Parent = nil
        end
    else
        local parent = state.lightParent[light]
        if parent then
            state.lightParent[light] = nil
            if parent:IsDescendantOf(state.model) or parent == state.model then
                -- pcall: the server may have destroyed the light while it was parked (Parent is then locked)
                pcall(function()
                    light.Parent = parent
                end)
            end
        end
    end
end

local function coveredByProxy(state, part)
    return state.proxyActive and state.proxy.covered[part] == true
end

-- Applies `level` to one classified instance.
local function applyOne(state, instance, level)
    local bucket = state.bucket[instance]
    if bucket == "light" then
        setLightParked(state, instance, level >= 1)
    elseif bucket == "fine" then
        setPartHidden(instance, level >= 1 or coveredByProxy(state, instance))
    elseif bucket == "small" then
        setPartHidden(instance, level >= 2 or coveredByProxy(state, instance))
    elseif bucket == "shadow" then
        setShadowCut(state, instance, level >= 2)
        setPartHidden(instance, coveredByProxy(state, instance))
    end
end

-- Shows the proxy instead of the parts it covers, or the parts again.
local function setProxyActive(state, active)
    active = active and state.proxy ~= nil
    if (state.proxyActive or false) == active then
        return
    end
    state.proxyActive = active
    for _, part in state.proxy.parts do
        part.Parent = active and proxyFolder or nil
    end
    for part in pairs(state.proxy.covered) do
        if part.Parent then
            if state.bucket[part] then
                applyOne(state, part, state.level)
            else
                setPartHidden(part, active)
            end
        end
    end
end

local function dropProxy(state)
    if state.proxy then
        setProxyActive(state, false)
        TempleProxy.Destroy(state.proxy)
        state.proxy = nil
    end
end

-- The temple changed (parts added / removed, theme): the proxy is stale.
local function templeChanged(state)
    state.changedAt = os.clock()
    state.proxyVersion = (state.proxyVersion or 0) + 1
    dropProxy(state)
end

local function ensureProxy(state)
    if not TempleProxy or state.proxy or state.proxyBuilding or os.clock() - (state.changedAt or 0) < PROXY_SETTLE then
        return
    end
    state.proxyBuilding = true
    local version = state.proxyVersion or 0
    task.spawn(function()
        local ok, proxy = pcall(TempleProxy.Build, state.model)
        state.proxyBuilding = false
        if not ok then
            warn("[TempleLOD] proxy build failed:", proxy)
            state.changedAt = os.clock() + 30 -- don't retry every tick
            return
        end
        if temples[state.model] ~= state or (state.proxyVersion or 0) ~= version then
            TempleProxy.Destroy(proxy) -- the temple changed or went away while building
            return
        end
        state.proxy = proxy
        if state.level >= 2 then
            setProxyActive(state, true)
        end
    end)
end

local function classify(state, instance)
    if state.bucket[instance] then
        return
    end
    local model = state.model
    local bucket
    if instance:IsA("Light") then
        bucket = "light"
    elseif instance:IsA("BasePart") then
        local size = instance.Size
        local largest = math.max(size.X, size.Y, size.Z)
        local decor = model:FindFirstChild("HalloweenDecor")
        if decor and instance:IsDescendantOf(decor) then
            bucket = hasAncestorNamed(instance, decor, "StringLights") and "small" or "fine"
        elseif hasAncestorNamed(instance, model, "CeilingLantern") or largest < FINE_SIZE then
            bucket = "fine"
        elseif largest < SMALL_SIZE then
            bucket = "small"
        elseif largest < SHADOW_SIZE then
            bucket = "shadow"
        end
    end
    if bucket then
        state.bucket[instance] = bucket
        applyOne(state, instance, state.level)
    end
end

local function applyLevel(state, level)
    if state.level == level then
        return
    end
    state.level = level
    for instance in pairs(state.bucket) do
        applyOne(state, instance, level)
    end
end

local function refreshBounds(state)
    state.boundsDirty = false
    local ok, cframe, size = pcall(state.model.GetBoundingBox, state.model)
    if ok then
        state.cframe, state.half = cframe, size / 2
    end
end

-- Distance from the camera to the nearest point of the temple's (oriented) bounding box.
local function distanceTo(state, point)
    if state.boundsDirty then
        refreshBounds(state)
    end
    if not state.cframe then
        return math.huge
    end
    local localPoint = state.cframe:PointToObjectSpace(point)
    local half = state.half
    local outside = Vector3.new(
        math.max(math.abs(localPoint.X) - half.X, 0),
        math.max(math.abs(localPoint.Y) - half.Y, 0),
        math.max(math.abs(localPoint.Z) - half.Z, 0)
    )
    return outside.Magnitude
end

local function unregister(model)
    local state = temples[model]
    if not state then
        return
    end
    temples[model] = nil
    for _, connection in state.connections do
        connection:Disconnect()
    end
    dropProxy(state)
    applyLevel(state, 0)
    -- Lights whose temple went away while parked would otherwise linger outside the DataModel.
    for light in pairs(state.lightParent) do
        pcall(light.Destroy, light)
    end
end

local function register(model)
    if temples[model] or not model:IsA("Model") then
        return
    end
    local state = {
        model = model,
        level = 0,
        bucket = {},
        shadowCast = {},
        lightParent = {},
        boundsDirty = true,
        connections = {},
    }
    temples[model] = state
    for _, descendant in model:GetDescendants() do
        classify(state, descendant)
    end
    table.insert(
        state.connections,
        model.DescendantAdded:Connect(function(descendant)
            state.boundsDirty = true
            classify(state, descendant)
            if not descendant:IsA("Light") then -- lights come back from parking; they are not in the proxy
                templeChanged(state)
            end
        end)
    )
    table.insert(
        state.connections,
        model.DescendantRemoving:Connect(function(descendant)
            if state.lightParent[descendant] then
                return -- our own parking, not a removal
            end
            state.bucket[descendant] = nil
            state.shadowCast[descendant] = nil
            if not descendant:IsA("Light") then
                templeChanged(state)
            end
        end)
    )
    table.insert(
        state.connections,
        model:GetAttributeChangedSignal("TempleAppearance"):Connect(function()
            templeChanged(state)
        end)
    )
    table.insert(
        state.connections,
        model.AncestryChanged:Connect(function()
            if not model:IsDescendantOf(workspace) then
                unregister(model)
            end
        end)
    )
end

local function watchPlot(plot)
    for _, child in plot:GetChildren() do
        if child.Name == "Temple" then
            register(child)
        end
    end
    plot.ChildAdded:Connect(function(child)
        if child.Name == "Temple" then
            register(child)
        end
    end)
end

for _, plot in plots:GetChildren() do
    watchPlot(plot)
end
plots.ChildAdded:Connect(watchPlot)

while true do
    task.wait(UPDATE_INTERVAL)
    camera = workspace.CurrentCamera or camera
    if camera then
        local scale = qualityScale()
        local near, far = LOD1_DISTANCE * scale, LOD2_DISTANCE * scale
        local point = camera.CFrame.Position
        for _, state in pairs(temples) do
            local distance = distanceTo(state, point)
            local level = state.level
            -- Losing detail happens at the boundary; gaining it back needs HYSTERESIS studs more.
            if distance > far then
                level = 2
            elseif distance > near then
                level = (level == 2 and distance > far - HYSTERESIS) and 2 or 1
            else
                level = (level >= 1 and distance > near - HYSTERESIS) and 1 or 0
            end
            applyLevel(state, level)
            if level >= 2 then
                ensureProxy(state)
                setProxyActive(state, true)
            else
                setProxyActive(state, false)
            end
        end
        -- debug: StarterPlayerScripts.TempleLOD attributes
        local active, triangles = 0, 0
        for _, state in pairs(temples) do
            if state.proxyActive then
                active += 1
                triangles += state.proxy.triangles
            end
        end
        script:SetAttribute("ProxiesActive", active)
        script:SetAttribute("ProxyTriangles", triangles)
    end
end
