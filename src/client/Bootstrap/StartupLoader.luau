-- Startup readiness and bounded content loading. No gameplay data is created here.
local M = {}
local CP = game:GetService("ContentProvider")
local RS = game:GetService("ReplicatedStorage")
local HTTP = game:GetService("HttpService")
local PROPERTIES = {
    MeshPart = { "MeshId", "TextureID" },
    SpecialMesh = { "MeshId", "TextureId" },
    Decal = { "Texture" },
    Texture = { "Texture" },
    ImageLabel = { "Image" },
    ImageButton = { "Image" },
    Sound = { "SoundId" },
    Animation = { "AnimationId" },
    ParticleEmitter = { "Texture" },
    Beam = { "Texture" },
    Trail = { "Texture" },
    SurfaceAppearance = { "ColorMap", "MetalnessMap", "NormalMap", "RoughnessMap" },
    MaterialVariant = { "ColorMap", "MetalnessMap", "NormalMap", "RoughnessMap" },
    Sky = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp", "SunTextureId", "MoonTextureId" },
}
function M.Collect(roots)
    local seen, ids = {}, {}
    local function scan(v)
        for _, prop in PROPERTIES[v.ClassName] or {} do
            local ok, id = pcall(function()
                return v[prop]
            end)
            if ok and type(id) == "string" and id ~= "" and not seen[id] then
                seen[id] = true
                table.insert(ids, {
                    id = id,
                    kind = prop == "MeshId" and "Mesh"
                        or (prop == "SoundId" and "Sound" or (prop == "AnimationId" and "Animation" or "Image")),
                })
            end
        end
    end
    for _, root in roots do
        if root then
            scan(root)
            for _, v in root:GetDescendants() do
                scan(v)
            end
        end
    end
    return ids
end
-- Each pass has a wall-clock budget, including requests that never return.
-- Assets are requested in batches (one PreloadAsync call per batch) instead of one request per asset.
local function numId(id)
    return (tostring(id):match("%d+")) or tostring(id)
end
function M.Preload(ids, budget, update, fetch)
    local BATCH = 20
    fetch = fetch
        or function(batch, callback)
            local proxies = {}
            for _, asset in batch do
                local proxy
                if asset.kind == "Mesh" then
                    proxy = Instance.new("SpecialMesh")
                    proxy.MeshId = asset.id
                elseif asset.kind == "Sound" then
                    proxy = Instance.new("Sound")
                    proxy.SoundId = asset.id
                elseif asset.kind == "Animation" then
                    proxy = Instance.new("Animation")
                    proxy.AnimationId = asset.id
                else
                    proxy = Instance.new("Decal")
                    proxy.Texture = asset.id
                end
                table.insert(proxies, proxy)
            end
            local ok, err = pcall(function()
                CP:PreloadAsync(proxies, callback)
            end)
            for _, p in proxies do
                p:Destroy()
            end
            if not ok then
                error(err)
            end
        end
    local nextIndex, done, active = 1, 0, true
    local failed, threads = {}, {}
    local deadline = os.clock() + budget
    local function worker()
        while active and nextIndex <= #ids do
            local first = nextIndex
            local last = math.min(first + BATCH - 1, #ids)
            nextIndex = last + 1
            local batch, byId = {}, {}
            for i = first, last do
                table.insert(batch, ids[i])
                byId[numId(ids[i].id)] = i
                failed[i] = true
            end
            pcall(fetch, batch, function(contentId, result)
                local i = byId[numId(contentId)]
                if i and result == Enum.AssetFetchStatus.Success then
                    failed[i] = false
                end
            end)
            if not active then
                return
            end
            done += #batch
        end
    end
    for _ = 1, math.min(8, math.ceil(#ids / BATCH)) do
        table.insert(threads, task.spawn(worker))
    end
    while done < #ids and os.clock() < deadline do
        update(done, #ids)
        task.wait(0.1)
    end
    active = false
    for _, thread in threads do
        if coroutine.status(thread) ~= "dead" then
            pcall(task.cancel, thread)
        end
    end
    local retry = {}
    for i, id in ids do
        if failed[i] ~= false then
            table.insert(retry, id)
        end
    end
    update(math.min(done, #ids), #ids)
    return retry
end
function M.Ready(player)
    if not game:IsLoaded() then
        return nil, "Connecting to the game"
    end
    if player:GetAttribute("StartupSessionReady") ~= true then
        return nil,
            player:GetAttribute("WaitingForPlot") and "Waiting for an available temple" or "Preparing your session"
    end
    if RS:GetAttribute("StartupInventoryReady") ~= true then
        return nil, "Preparing your inventory"
    end
    local stats = player:FindFirstChild("leaderstats")
    if not stats or not stats:FindFirstChild("Cash") or not player:FindFirstChildOfClass("Backpack") then
        return nil, "Preparing your player data"
    end
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 or not char:FindFirstChild("HumanoidRootPart") then
        return nil, "Spawning your character"
    end
    local plots = workspace:FindFirstChild("Plots")
    if plots then
        for _, plot in plots:GetChildren() do
            if
                plot:GetAttribute("PlotId") == player:GetAttribute("PlotId")
                and plot:GetAttribute("OwnerUserId") == player.UserId
            then
                if
                    plot:FindFirstChild("Temple")
                    and plot:FindFirstChild("PlotSpawn")
                    and plot:FindFirstChild("Slots")
                then
                    return plot
                end
            end
        end
    end
    return nil, "Loading your temple"
end
function M.Run(player, gui, update)
    local T0 = os.clock()
    local function mark(k)
        player:SetAttribute("StartupT_" .. k, math.floor((os.clock() - T0) * 10) / 10)
    end
    local function waitReady()
        local deadline = os.clock() + 45
        repeat
            local plot, message = M.Ready(player)
            if plot then
                return plot
            end
            update(0.08, message)
            task.wait(0.2)
        until os.clock() >= deadline
        error("Your session is taking longer than expected. Please retry.")
    end
    local plot = waitReady()
    mark("Ready")
    update(0.15, "Loading the area around your temple")
    local streamed = not workspace.StreamingEnabled
    if workspace.StreamingEnabled then
        task.spawn(function()
            pcall(function()
                player:RequestStreamAroundAsync(plot.PlotSpawn.Position, 12)
            end)
            streamed = true
        end)
    end
    mark("Stream")
    -- essentials = what you see first: the HUD, your own temple, eggs and characters
    local seen, essential, rest = {}, {}, {}
    local function add(list, asset)
        if not seen[asset.id] then
            seen[asset.id] = true
            table.insert(list, asset)
        end
    end
    local ess = RS:FindFirstChild("StartupAssetManifestEssential")
    if ess and ess.Value ~= "" then
        for _, asset in HTTP:JSONDecode(ess.Value) do
            add(essential, asset)
        end
    end
    for _, asset in M.Collect({ gui, player:FindFirstChildOfClass("PlayerGui"), plot }) do
        add(essential, asset)
    end
    local manifest = RS:FindFirstChild("StartupAssetManifest")
    if manifest and manifest.Value ~= "" then
        for _, asset in HTTP:JSONDecode(manifest.Value) do
            add(rest, asset)
        end
    end
    for _, asset in M.Collect({ workspace, RS, game:GetService("Lighting"), game:GetService("MaterialService") }) do
        add(rest, asset)
    end
    player:SetAttribute("StartupAssetCount", #essential)
    for _, asset in rest do
        table.insert(essential, asset)
    end
    rest = {}
    local failed = M.Preload(essential, 45, function(done, total)
        update(0.2 + 0.75 * (total > 0 and done / total or 1), "Loading the world (" .. done .. "/" .. total .. ")")
    end)
    player:SetAttribute("StartupAssetFailures", #failed)
    mark("Preload")
    do
        local deadline = os.clock() + 12
        while not streamed and os.clock() < deadline do
            update(0.95, "Loading the area around your temple")
            task.wait(0.1)
        end
    end
    waitReady()
    mark("Done")
    update(1, "Ready!")
    -- everything else streams in quietly while you play
    task.spawn(function()
        task.wait(1.5)
        for _, asset in failed do
            table.insert(rest, asset)
        end
        M.Preload(rest, 180, function() end)
    end)
end

return M
