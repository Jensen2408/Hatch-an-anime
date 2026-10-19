--[[ ServerScriptService.Leaderboard.LeaderboardChampions  (Script)
Global Cash and Eggs Hatched podiums. Avatar failures never remove a winner's identity.

Podiums are children of boards tagged Config.Tag, named "Podium<rank>" (or with a PodiumRank attribute),
optionally with a PodiumStat attribute, a PlaqueFace part and a ChampionSpot attachment. Each podium
shows the GLOBAL top entry for its rank (LeaderboardService.GetGlobalTop) as a plaque plus a
humanoid avatar dummy, and mirrors the winner into ChampionUserId / ChampionUsername / ChampionValue /
AvatarStatus / AvatarError attributes. Refreshes on LeaderboardService.GlobalUpdated and every
Config.Champions.Refresh seconds. In Studio, a "ChampionsStudioPreview" BindableFunction under this
script can inject fake entries.
]]
-- ===== 1. Setup =====
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Leaderboard")
local Config = require(Shared:WaitForChild("LeaderboardConfig"))
local Format = require(Shared:WaitForChild("LeaderboardFormat"))
local Service = require(script.Parent:WaitForChild("LeaderboardService"))

local ChampionsConfig = Config.Champions
local _RANK_WORD = { "1ST", "2ND", "3RD" } -- unused

-- [Podium Model] = { stat, rank, podium, spot (Attachment), title, sub, entry, status, isPreview,
--                    dummy, token, userId, loading, avatarStatus, nextAttempt }
-- `token` is bumped on every clear/spawn so a late avatar response for an old winner is discarded.
local spots = {}
local preview = nil -- Studio-only { [statId] = entries }; plaques explicitly label the preview
local stopped = false
local connections = {}
local refresh
local refreshQueued = false
-- Coalesces bursts (several podiums added, GlobalUpdated for every stat) into one deferred refresh.
local function queueRefresh()
    if stopped or refreshQueued then
        return
    end
    refreshQueued = true
    task.defer(function()
        refreshQueued = false
        if not stopped then
            refresh()
        end
    end)
end

-- ===== 2. Champion dummies =====
local function clearDummy(state)
    state.token += 1
    state.userId = nil
    state.loading = false
    if state.dummy then
        state.dummy:Destroy()
    end
    state.dummy = nil
end

local function playIdle(model)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end
    -- Instance.new(class, parent) is deprecated; kept as-is to preserve behaviour.
    local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
    local animation = Instance.new("Animation")
    animation.AnimationId = humanoid.RigType == Enum.HumanoidRigType.R15 and ChampionsConfig.IdleAnimationR15
        or ChampionsConfig.IdleAnimationR6
    local ok, track = pcall(animator.LoadAnimation, animator, animation)
    if ok and track then
        track.Looped = true
        track:Play(0)
    end
end

-- Billboard over the dummy's head; its texts are filled in by updateIdentity.
local function createChampionTag(model, _entry, rank)
    local head = model:FindFirstChild("Head")
    if not head then
        return
    end
    local gui = Instance.new("BillboardGui")
    gui.Name = "ChampionTag"
    gui.Size = UDim2.fromOffset(240, 76)
    gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
    gui.MaxDistance = 90
    gui.LightInfluence = 0
    gui.Parent = head
    local displayNameLabel = Instance.new("TextLabel")
    displayNameLabel.Name = "DisplayName"
    displayNameLabel.BackgroundTransparency = 1
    displayNameLabel.Size = UDim2.new(1, 0, 0, 28)
    displayNameLabel.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
    displayNameLabel.TextSize = 24
    displayNameLabel.TextColor3 = Color3.fromRGB(255, 244, 220)
    displayNameLabel.TextStrokeColor3 = Color3.fromRGB(74, 54, 44)
    displayNameLabel.TextStrokeTransparency = 0
    displayNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    displayNameLabel.Parent = gui
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "Value"
    valueLabel.BackgroundTransparency = 1
    valueLabel.Position = UDim2.fromOffset(0, 28)
    valueLabel.Size = UDim2.new(1, 0, 0, 22)
    valueLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
    valueLabel.TextSize = 18
    valueLabel.TextColor3 = rank == 1 and Color3.fromRGB(255, 214, 96) or Color3.fromRGB(226, 232, 240)
    valueLabel.TextStrokeColor3 = Color3.fromRGB(74, 54, 44)
    valueLabel.TextStrokeTransparency = 0
    valueLabel.Parent = gui
    local usernameLabel = valueLabel:Clone()
    usernameLabel.Name = "Username"
    usernameLabel.Position = UDim2.fromOffset(0, 50)
    usernameLabel.TextSize = 14
    usernameLabel.TextColor3 = Color3.fromRGB(255, 244, 220)
    usernameLabel.Parent = gui
    return gui
end

-- Writes the podium attributes, plaque texts and (if present) the head tag from state.entry.
local function updateIdentity(state)
    local entry = state.entry
    local podium = state.podium
    podium:SetAttribute("ChampionUserId", entry and entry.u or nil)
    podium:SetAttribute("ChampionUsername", entry and entry.n or nil)
    podium:SetAttribute("ChampionValue", entry and entry.v or nil)
    podium:SetAttribute("AvatarStatus", state.avatarStatus or "none")
    local stat = Config.StatById[state.stat]
    state.title.Text = (state.isPreview and "STUDIO PREVIEW · " or "") .. "#" .. state.rank .. " " .. stat.Tab
    if entry then
        local username = entry.n and ("@" .. entry.n) or ("User " .. tostring(entry.u))
        state.sub.Text = username .. " · " .. Format.Value(stat.Kind, entry.v or 0)
        if state.avatarStatus == "unavailable" then
            state.sub.Text ..= "\nAvatar unavailable · retrying"
        elseif state.avatarStatus == "loading" then
            state.sub.Text ..= "\nLoading avatar..."
        elseif state.status == "stale" then
            state.sub.Text ..= "\nLast saved global ranking"
        end
    else
        state.sub.Text = state.status == "loading" and "Loading global rankings..."
            or state.status == "unavailable" and "Global data unavailable"
            or "Awaiting a champion"
    end
    local tag = state.dummy and state.dummy:FindFirstChild("ChampionTag", true)
    if tag and entry then
        tag.DisplayName.Text = entry.d or entry.n or ("User " .. entry.u)
        tag.Username.Text = entry.n and ("@" .. entry.n) or ("User " .. entry.u)
        tag.Value.Text = Format.Value(stat.Kind, entry.v or 0)
    end
end

-- Loads the winner's avatar asynchronously. Every step re-checks isCurrent(): the podium may have been
-- removed, the winner may have changed, or the request may have timed out meanwhile.
local function spawnDummy(state, entry)
    clearDummy(state)
    local token = state.token
    local userId = entry.u
    state.userId = userId
    state.loading = true
    state.avatarStatus = "loading"
    state.nextAttempt = os.clock() + (ChampionsConfig.AvatarRetry or 60)
    updateIdentity(state)

    local function isCurrent()
        return not stopped
            and spots[state.podium] == state
            and state.podium.Parent
            and state.token == token
            and state.entry
            and state.entry.u == userId
    end
    local function failAvatar(message)
        if not isCurrent() then
            return
        end
        state.loading = false
        if state.dummy then
            state.dummy:Destroy()
            state.dummy = nil
        end
        state.avatarStatus = "unavailable"
        state.podium:SetAttribute("AvatarError", tostring(message):sub(1, 400))
        updateIdentity(state)
        warn(
            "[LeaderboardChampions] "
                .. state.stat
                .. " #"
                .. state.rank
                .. " user "
                .. userId
                .. ": "
                .. tostring(message)
        )
    end
    -- A yielded avatar request must not leave this spot stuck in "loading" forever.
    task.delay(ChampionsConfig.AvatarTimeout or 20, function()
        if isCurrent() and state.loading then
            failAvatar("Avatar request timed out")
            state.token += 1 -- discard a late response; a later refresh may retry
        end
    end)
    task.spawn(function()
        local model
        local ok, err = pcall(function()
            -- Async is the supported API. A description-based attempt recovers some outfit failures.
            local loaded, result = pcall(Players.CreateHumanoidModelFromUserIdAsync, Players, userId)
            if not loaded then
                if not isCurrent() then
                    return
                end
                local description = Players:GetHumanoidDescriptionFromUserIdAsync(userId)
                result = Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
                description:Destroy()
            end
            model = result
            if not isCurrent() then
                return
            end
            local humanoid = model and model:FindFirstChildOfClass("Humanoid")
            local root = model and model:FindFirstChild("HumanoidRootPart")
            assert(humanoid and root, "Avatar has no Humanoid or root")
            model.Name = "Champion" .. state.rank
            model:SetAttribute("ChampionUserId", userId)
            model:SetAttribute("ChampionStat", state.stat)
            humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
            humanoid.BreakJointsOnDeath = false
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            humanoid.MaxHealth, humanoid.Health = 1000000, 1000000
            root.Anchored = true
            for _, part in model:GetDescendants() do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                    part.CanTouch = false
                    part.CanQuery = false
                elseif part:IsA("BaseScript") then
                    part:Destroy()
                end
            end
            model:ScaleTo(ChampionsConfig.Scale)
            local lift
            if humanoid.RigType == Enum.HumanoidRigType.R15 then
                lift = humanoid.HipHeight + root.Size.Y / 2
            else
                local leg = model:FindFirstChild("Left Leg")
                lift = root.Size.Y / 2 + (leg and leg.Size.Y or 2 * ChampionsConfig.Scale)
            end
            -- Use the root transform explicitly; an avatar's model pivot may differ.
            local desiredRoot = state.spot.WorldCFrame * CFrame.new(0, lift, 0)
            model:PivotTo(desiredRoot * root.CFrame:Inverse() * model:GetPivot())
            createChampionTag(model, state.entry, state.rank)
            if not isCurrent() then
                return
            end
            model.Parent = state.podium
            state.dummy = model
            state.loading = false
            state.avatarStatus = "ready"
            state.podium:SetAttribute("AvatarError", nil)
            updateIdentity(state) -- use latest score/name, including updates during the avatar request
            playIdle(model)
        end)
        if not ok then
            if model then
                model:Destroy()
            end
            failAvatar(err)
        elseif model and not isCurrent() then
            model:Destroy()
        end
    end)
end

-- Rebuilds every podium from one GetGlobalTop call per stat (or the Studio preview data).
-- A new avatar is requested when the winner changed, or after AvatarRetry when the last attempt failed.
refresh = function()
    local snapshots = {}
    for _, state in spots do
        if not snapshots[state.stat] then
            if preview then
                snapshots[state.stat] = { status = "ok", entries = preview[state.stat] or {} }
            else
                local status, top = Service.GetGlobalTop(state.stat, ChampionsConfig.Count)
                snapshots[state.stat] = { status = status, entries = top }
            end
        end
        local snapshot = snapshots[state.stat]
        local entry = snapshot.entries[state.rank]
        state.status = snapshot.status
        state.isPreview = preview ~= nil
        state.entry = entry
        if entry and type(entry.u) == "number" and entry.u > 0 then
            if
                state.userId ~= entry.u
                or (not state.loading and not state.dummy and os.clock() >= (state.nextAttempt or 0))
            then
                spawnDummy(state, entry)
            end
        else
            clearDummy(state)
            state.avatarStatus = "none"
        end
        updateIdentity(state)
    end
end

-- ===== 3. Podium discovery =====
local function makePlaque(face)
    local gui = Instance.new("SurfaceGui")
    gui.Name = "ChampionPlaque"
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 60
    gui.LightInfluence = 0
    gui.Parent = face
    local plate = Instance.new("Frame")
    plate.AnchorPoint = Vector2.new(0.5, 0.5)
    plate.Position = UDim2.fromScale(0.5, 0.5)
    plate.Size = UDim2.new(1, -12, 1, -12)
    plate.BackgroundColor3 = Color3.fromRGB(74, 54, 44)
    plate.Parent = gui
    Instance.new("UICorner", plate).CornerRadius = UDim.new(0, 10)
    local rim = Instance.new("UIStroke")
    rim.Color = Color3.fromRGB(196, 160, 86)
    rim.Thickness = 4
    rim.Parent = plate
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.fromScale(0, 0.08)
    titleLabel.Size = UDim2.fromScale(1, 0.36)
    titleLabel.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
    titleLabel.TextScaled = true
    titleLabel.TextColor3 = Color3.fromRGB(255, 214, 96)
    titleLabel.Parent = plate
    local subLabel = Instance.new("TextLabel")
    subLabel.Name = "Sub"
    subLabel.BackgroundTransparency = 1
    subLabel.Position = UDim2.fromScale(0.04, 0.48)
    subLabel.Size = UDim2.fromScale(0.92, 0.46)
    subLabel.TextWrapped = true
    subLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
    subLabel.TextScaled = true
    subLabel.TextColor3 = Color3.fromRGB(240, 226, 196)
    subLabel.Parent = plate
    return titleLabel, subLabel
end

local function addPodium(podium)
    if not podium:IsA("Model") or spots[podium] then
        return
    end
    local rank = tonumber(podium:GetAttribute("PodiumRank")) or tonumber(podium.Name:match("^Podium(%d+)$"))
    local stat = podium:GetAttribute("PodiumStat") or ChampionsConfig.Stat
    if not rank or rank % 1 ~= 0 or rank < 1 or rank > ChampionsConfig.Count or not Config.StatById[stat] then
        return
    end
    local face = podium:FindFirstChild("PlaqueFace")
    local spot = podium:FindFirstChild("ChampionSpot", true)
    if not face or not spot or not spot:IsA("Attachment") then
        return
    end
    local oldPlaque = face:FindFirstChild("ChampionPlaque")
    if oldPlaque then
        oldPlaque:Destroy()
    end
    local titleLabel, subLabel = makePlaque(face)
    spots[podium] =
        { stat = stat, rank = rank, podium = podium, spot = spot, title = titleLabel, sub = subLabel, token = 0 }
    podium.Destroying:Connect(function()
        local state = spots[podium]
        if state then
            clearDummy(state)
        end
        spots[podium] = nil
    end)
    queueRefresh()
end

local boards = {}
local function addBoard(board)
    if boards[board] then
        return
    end
    local conn = board.ChildAdded:Connect(function(child)
        task.defer(addPodium, child)
    end)
    boards[board] = conn
    for _, child in board:GetChildren() do
        addPodium(child)
    end
end
local function removeBoard(board)
    if boards[board] then
        boards[board]:Disconnect()
        boards[board] = nil
    end
    for podium, state in spots do
        if podium:IsDescendantOf(board) then
            clearDummy(state)
            spots[podium] = nil
        end
    end
end
-- ===== 4. Init =====
for _, board in CollectionService:GetTagged(Config.Tag) do
    addBoard(board)
end
table.insert(connections, CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(addBoard))
table.insert(connections, CollectionService:GetInstanceRemovedSignal(Config.Tag):Connect(removeBoard))
table.insert(connections, Service.GlobalUpdated.Event:Connect(queueRefresh))

if RunService:IsStudio() then
    local previewHook = Instance.new("BindableFunction")
    previewHook.Name = "ChampionsStudioPreview"
    previewHook.OnInvoke = function(list)
        -- Legacy array or {Cash = entries, Hatches = entries}. Never exists outside Studio.
        preview = list and (list[1] and { [ChampionsConfig.Stat] = list } or list) or nil
        refresh()
        return true
    end
    previewHook.Parent = script
end

script.Destroying:Connect(function()
    stopped = true
    for _, conn in connections do
        conn:Disconnect()
    end
    for board in boards do
        removeBoard(board)
    end
end)
-- Periodic refresh (also retries failed avatars); runs on this script's main thread until it is destroyed.
while not stopped do
    task.wait(ChampionsConfig.Refresh)
    if stopped then
        break
    end
    local ok, err = pcall(refresh)
    if not ok then
        warn("[LeaderboardChampions] " .. tostring(err))
    end
end
