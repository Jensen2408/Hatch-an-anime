--[[ ReplicatedFirst.StartupLoader  (ModuleScript)
Startup readiness and bounded content loading. No gameplay data is created here.
Required by the LoadingScreen LocalScript (client, before the game has loaded) and by
ServerScriptService.StartupAssetManifest (server, Collect only).

Public API (shape is a contract; keep it stable):
  StartupLoader.Collect(roots) -> { { id: string, kind: "Mesh" | "Sound" | "Animation" | "Image" } }
  StartupLoader.Preload(assets, budgetSeconds, update(done, total), fetch?) -> failedAssets
  StartupLoader.Ready(player) -> plot | (nil, statusMessage)
  StartupLoader.Run(player, loadingGui, update(progress01, message))  -- yields until the player can play

Manifest contract (written by the server script StartupAssetManifest, read in Run):
  ReplicatedStorage.StartupAssetManifestEssential  JSON list from Collect, preloaded first
  ReplicatedStorage.StartupAssetManifest           JSON list from Collect, everything else
Readiness attributes read in Ready: Player.StartupSessionReady / WaitingForPlot / PlotId,
ReplicatedStorage.StartupInventoryReady, Plot.PlotId / OwnerUserId.
Timing attributes written in Run: Player.StartupT_Ready / _Stream / _Preload / _Done,
StartupAssetCount, StartupAssetFailures (diagnostics only).
]]
local StartupLoader = {}
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
-- ===== 1. Asset discovery =====
-- Content-ID properties scanned per class.
local CONTENT_ID_PROPERTIES = {
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
function StartupLoader.Collect(roots)
    local seen, assets = {}, {}
    local function scanInstance(instance)
        for _, prop in CONTENT_ID_PROPERTIES[instance.ClassName] or {} do
            local readOk, contentId = pcall(function()
                return instance[prop]
            end)
            if readOk and type(contentId) == "string" and contentId ~= "" and not seen[contentId] then
                seen[contentId] = true
                table.insert(assets, {
                    id = contentId,
                    kind = prop == "MeshId" and "Mesh"
                        or (prop == "SoundId" and "Sound" or (prop == "AnimationId" and "Animation" or "Image")),
                })
            end
        end
    end
    for _, root in roots do
        if root then
            scanInstance(root)
            for _, descendant in root:GetDescendants() do
                scanInstance(descendant)
            end
        end
    end
    return assets
end
-- ===== 2. Batched preloading =====
-- Each pass has a wall-clock budget, including requests that never return.
-- Assets are requested in batches (one PreloadAsync call per batch) instead of one request per asset.
-- The PreloadAsync callback's content ID may be formatted differently from the manifest entry,
-- so batch entries are matched by their numeric part.
local function numericAssetId(id)
    return (tostring(id):match("%d+")) or tostring(id)
end
function StartupLoader.Preload(assets, budget, update, fetch)
    local BATCH_SIZE = 20
    -- Optional `fetch` override; the default wraps each entry in a throwaway proxy instance for PreloadAsync.
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
                ContentProvider:PreloadAsync(proxies, callback)
            end)
            for _, proxyInstance in proxies do
                proxyInstance:Destroy()
            end
            if not ok then
                error(err)
            end
        end
    -- Up to 8 workers pull batches from a shared cursor. An asset counts as failed until its callback
    -- reports Success. When the budget runs out the workers are cancelled and every unconfirmed asset
    -- is returned so the caller can retry it later.
    local nextIndex, completedCount, isActive = 1, 0, true
    local failedByIndex, workerThreads = {}, {}
    local deadline = os.clock() + budget
    local function worker()
        while isActive and nextIndex <= #assets do
            local firstIndex = nextIndex
            local lastIndex = math.min(firstIndex + BATCH_SIZE - 1, #assets)
            nextIndex = lastIndex + 1
            local batch, indexByNumericId = {}, {}
            for i = firstIndex, lastIndex do
                table.insert(batch, assets[i])
                indexByNumericId[numericAssetId(assets[i].id)] = i
                failedByIndex[i] = true
            end
            pcall(fetch, batch, function(contentId, fetchStatus)
                local assetIndex = indexByNumericId[numericAssetId(contentId)]
                if assetIndex and fetchStatus == Enum.AssetFetchStatus.Success then
                    failedByIndex[assetIndex] = false
                end
            end)
            if not isActive then
                return
            end
            completedCount += #batch
        end
    end
    for _ = 1, math.min(8, math.ceil(#assets / BATCH_SIZE)) do
        table.insert(workerThreads, task.spawn(worker))
    end
    while completedCount < #assets and os.clock() < deadline do
        update(completedCount, #assets)
        task.wait(0.1)
    end
    isActive = false
    for _, thread in workerThreads do
        if coroutine.status(thread) ~= "dead" then
            pcall(task.cancel, thread)
        end
    end
    local retryList = {}
    for i, asset in assets do
        if failedByIndex[i] ~= false then
            table.insert(retryList, asset)
        end
    end
    update(math.min(completedCount, #assets), #assets)
    return retryList
end
-- ===== 3. Readiness =====
-- Returns the player's plot once the server-side session, inventory, leaderstats, character and plot
-- are all present; otherwise nil plus the status line shown on the loading screen.
function StartupLoader.Ready(player)
    if not game:IsLoaded() then
        return nil, "Connecting to the game"
    end
    if player:GetAttribute("StartupSessionReady") ~= true then
        return nil,
            player:GetAttribute("WaitingForPlot") and "Waiting for an available temple" or "Preparing your session"
    end
    if ReplicatedStorage:GetAttribute("StartupInventoryReady") ~= true then
        return nil, "Preparing your inventory"
    end
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats or not leaderstats:FindFirstChild("Cash") or not player:FindFirstChildOfClass("Backpack") then
        return nil, "Preparing your player data"
    end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 or not character:FindFirstChild("HumanoidRootPart") then
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
-- ===== 4. Full startup sequence =====
-- Order matters: wait ready -> request streaming -> preload essentials then the rest (45 s budget) ->
-- wait for streaming (12 s) -> wait ready again -> background retry of failures (180 s budget).
function StartupLoader.Run(player, gui, update)
    local runStartedAt = os.clock()
    local function markTiming(stageName)
        player:SetAttribute("StartupT_" .. stageName, math.floor((os.clock() - runStartedAt) * 10) / 10)
    end
    -- Polls Ready for up to 45 s; the error is caught by LoadingScreen, which then closes anyway.
    local function waitReady()
        local deadline = os.clock() + 45
        repeat
            local plot, message = StartupLoader.Ready(player)
            if plot then
                return plot
            end
            update(0.08, message)
            task.wait(0.2)
        until os.clock() >= deadline
        error("Your session is taking longer than expected. Please retry.")
    end
    local plot = waitReady()
    markTiming("Ready")
    update(0.15, "Loading the area around your temple")
    -- Streaming runs in parallel with the preload; it is only awaited (max 12 s) after the preload.
    local isStreamed = not workspace.StreamingEnabled
    if workspace.StreamingEnabled then
        task.spawn(function()
            pcall(function()
                player:RequestStreamAroundAsync(plot.PlotSpawn.Position, 12)
            end)
            isStreamed = true
        end)
    end
    markTiming("Stream")
    -- essentials = what you see first: the HUD, your own temple, eggs and characters
    local seenIds, essentialAssets, deferredAssets = {}, {}, {}
    local function addUnique(list, asset)
        if not seenIds[asset.id] then
            seenIds[asset.id] = true
            table.insert(list, asset)
        end
    end
    local essentialManifest = ReplicatedStorage:FindFirstChild("StartupAssetManifestEssential")
    if essentialManifest and essentialManifest.Value ~= "" then
        for _, asset in HttpService:JSONDecode(essentialManifest.Value) do
            addUnique(essentialAssets, asset)
        end
    end
    for _, asset in StartupLoader.Collect({ gui, player:FindFirstChildOfClass("PlayerGui"), plot }) do
        addUnique(essentialAssets, asset)
    end
    local manifest = ReplicatedStorage:FindFirstChild("StartupAssetManifest")
    if manifest and manifest.Value ~= "" then
        for _, asset in HttpService:JSONDecode(manifest.Value) do
            addUnique(deferredAssets, asset)
        end
    end
    for _, asset in
        StartupLoader.Collect({
            workspace,
            ReplicatedStorage,
            game:GetService("Lighting"),
            game:GetService("MaterialService"),
        })
    do
        addUnique(deferredAssets, asset)
    end
    player:SetAttribute("StartupAssetCount", #essentialAssets)
    -- One preload pass over essentials followed by the rest, so essentials are requested first.
    for _, asset in deferredAssets do
        table.insert(essentialAssets, asset)
    end
    deferredAssets = {}
    local failedAssets = StartupLoader.Preload(essentialAssets, 45, function(loadedCount, totalCount)
        update(
            0.2 + 0.75 * (totalCount > 0 and loadedCount / totalCount or 1),
            "Loading the world (" .. loadedCount .. "/" .. totalCount .. ")"
        )
    end)
    player:SetAttribute("StartupAssetFailures", #failedAssets)
    markTiming("Preload")
    do
        local deadline = os.clock() + 12
        while not isStreamed and os.clock() < deadline do
            update(0.95, "Loading the area around your temple")
            task.wait(0.1)
        end
    end
    waitReady()
    markTiming("Done")
    update(1, "Ready!")
    -- Assets that failed or ran out of budget are retried quietly while you play.
    task.spawn(function()
        task.wait(1.5)
        for _, asset in failedAssets do
            table.insert(deferredAssets, asset)
        end
        StartupLoader.Preload(deferredAssets, 180, function() end)
    end)
end

return StartupLoader
