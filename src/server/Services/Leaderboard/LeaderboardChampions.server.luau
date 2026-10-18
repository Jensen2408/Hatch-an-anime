-- Global Cash and Eggs Hatched podiums. Avatar failures never remove a winner's identity.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Leaderboard")
local Config = require(Shared:WaitForChild("LeaderboardConfig"))
local Format = require(Shared:WaitForChild("LeaderboardFormat"))
local Service = require(script.Parent:WaitForChild("LeaderboardService"))

local C = Config.Champions
local RANK_WORD = { "1ST", "2ND", "3RD" }

local spots = {} -- [Podium Model] = { rank, spot (Attachment), title, sub, entry, dummy, token, userId }
local preview = nil -- Studio-only { [statId] = entries }; plaques explicitly label the preview
local stopped = false
local connections = {}
local refresh
local refreshQueued = false
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

---------------------------------------------------------------- dummies
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
    local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
    local animation = Instance.new("Animation")
    animation.AnimationId = humanoid.RigType == Enum.HumanoidRigType.R15 and C.IdleAnimationR15 or C.IdleAnimationR6
    local ok, track = pcall(animator.LoadAnimation, animator, animation)
    if ok and track then
        track.Looped = true
        track:Play(0)
    end
end

local function billboard(model, entry, rank)
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
    local name = Instance.new("TextLabel")
    name.Name = "DisplayName"
    name.BackgroundTransparency = 1
    name.Size = UDim2.new(1, 0, 0, 28)
    name.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
    name.TextSize = 24
    name.TextColor3 = Color3.fromRGB(255, 244, 220)
    name.TextStrokeColor3 = Color3.fromRGB(74, 54, 44)
    name.TextStrokeTransparency = 0
    name.TextTruncate = Enum.TextTruncate.AtEnd
    name.Parent = gui
    local value = Instance.new("TextLabel")
    value.Name = "Value"
    value.BackgroundTransparency = 1
    value.Position = UDim2.fromOffset(0, 28)
    value.Size = UDim2.new(1, 0, 0, 22)
    value.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
    value.TextSize = 18
    value.TextColor3 = rank == 1 and Color3.fromRGB(255, 214, 96) or Color3.fromRGB(226, 232, 240)
    value.TextStrokeColor3 = Color3.fromRGB(74, 54, 44)
    value.TextStrokeTransparency = 0
    value.Parent = gui
    local user = value:Clone()
    user.Name = "Username"
    user.Position = UDim2.fromOffset(0, 50)
    user.TextSize = 14
    user.TextColor3 = Color3.fromRGB(255, 244, 220)
    user.Parent = gui
    return gui
end

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

local function spawnDummy(state, entry)
    clearDummy(state)
    local token = state.token
    local uid = entry.u
    state.userId = uid
    state.loading = true
    state.avatarStatus = "loading"
    state.nextAttempt = os.clock() + (C.AvatarRetry or 60)
    updateIdentity(state)

    local function current()
        return not stopped
            and spots[state.podium] == state
            and state.podium.Parent
            and state.token == token
            and state.entry
            and state.entry.u == uid
    end
    local function failed(message)
        if not current() then
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
                .. uid
                .. ": "
                .. tostring(message)
        )
    end
    -- A yielded avatar request must not leave this spot stuck in "loading" forever.
    task.delay(C.AvatarTimeout or 20, function()
        if current() and state.loading then
            failed("Avatar request timed out")
            state.token += 1 -- discard a late response; a later refresh may retry
        end
    end)
    task.spawn(function()
        local model
        local ok, err = pcall(function()
            -- Async is the supported API. A description-based attempt recovers some outfit failures.
            local loaded, result = pcall(Players.CreateHumanoidModelFromUserIdAsync, Players, uid)
            if not loaded then
                if not current() then
                    return
                end
                local description = Players:GetHumanoidDescriptionFromUserIdAsync(uid)
                result = Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
                description:Destroy()
            end
            model = result
            if not current() then
                return
            end
            local humanoid = model and model:FindFirstChildOfClass("Humanoid")
            local root = model and model:FindFirstChild("HumanoidRootPart")
            assert(humanoid and root, "Avatar has no Humanoid or root")
            model.Name = "Champion" .. state.rank
            model:SetAttribute("ChampionUserId", uid)
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
            model:ScaleTo(C.Scale)
            local lift
            if humanoid.RigType == Enum.HumanoidRigType.R15 then
                lift = humanoid.HipHeight + root.Size.Y / 2
            else
                local leg = model:FindFirstChild("Left Leg")
                lift = root.Size.Y / 2 + (leg and leg.Size.Y or 2 * C.Scale)
            end
            -- Use the root transform explicitly; an avatar's model pivot may differ.
            local desiredRoot = state.spot.WorldCFrame * CFrame.new(0, lift, 0)
            model:PivotTo(desiredRoot * root.CFrame:Inverse() * model:GetPivot())
            billboard(model, state.entry, state.rank)
            if not current() then
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
            failed(err)
        elseif model and not current() then
            model:Destroy()
        end
    end)
end

refresh = function()
    local snapshots = {}
    for _, state in spots do
        if not snapshots[state.stat] then
            if preview then
                snapshots[state.stat] = { status = "ok", entries = preview[state.stat] or {} }
            else
                local status, top = Service.GetGlobalTop(state.stat, C.Count)
                snapshots[state.stat] = { status = status, entries = top }
            end
        end
        local snap = snapshots[state.stat]
        local entry = snap.entries[state.rank]
        state.status = snap.status
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

---------------------------------------------------------------- podium discovery
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
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromScale(0, 0.08)
    title.Size = UDim2.fromScale(1, 0.36)
    title.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
    title.TextScaled = true
    title.TextColor3 = Color3.fromRGB(255, 214, 96)
    title.Parent = plate
    local sub = Instance.new("TextLabel")
    sub.Name = "Sub"
    sub.BackgroundTransparency = 1
    sub.Position = UDim2.fromScale(0.04, 0.48)
    sub.Size = UDim2.fromScale(0.92, 0.46)
    sub.TextWrapped = true
    sub.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
    sub.TextScaled = true
    sub.TextColor3 = Color3.fromRGB(240, 226, 196)
    sub.Parent = plate
    return title, sub
end

local function addPodium(podium)
    if not podium:IsA("Model") or spots[podium] then
        return
    end
    local rank = tonumber(podium:GetAttribute("PodiumRank")) or tonumber(podium.Name:match("^Podium(%d+)$"))
    local stat = podium:GetAttribute("PodiumStat") or C.Stat
    if not rank or rank % 1 ~= 0 or rank < 1 or rank > C.Count or not Config.StatById[stat] then
        return
    end
    local face = podium:FindFirstChild("PlaqueFace")
    local spot = podium:FindFirstChild("ChampionSpot", true)
    if not face or not spot or not spot:IsA("Attachment") then
        return
    end
    local old = face:FindFirstChild("ChampionPlaque")
    if old then
        old:Destroy()
    end
    local title, sub = makePlaque(face)
    spots[podium] = { stat = stat, rank = rank, podium = podium, spot = spot, title = title, sub = sub, token = 0 }
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
for _, board in CollectionService:GetTagged(Config.Tag) do
    addBoard(board)
end
table.insert(connections, CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(addBoard))
table.insert(connections, CollectionService:GetInstanceRemovedSignal(Config.Tag):Connect(removeBoard))
table.insert(connections, Service.GlobalUpdated.Event:Connect(queueRefresh))

if RunService:IsStudio() then
    local hook = Instance.new("BindableFunction")
    hook.Name = "ChampionsStudioPreview"
    hook.OnInvoke = function(list)
        -- Legacy array or {Cash = entries, Hatches = entries}. Never exists outside Studio.
        preview = list and (list[1] and { [C.Stat] = list } or list) or nil
        refresh()
        return true
    end
    hook.Parent = script
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
while not stopped do
    task.wait(C.Refresh)
    if stopped then
        break
    end
    local ok, err = pcall(refresh)
    if not ok then
        warn("[LeaderboardChampions] " .. tostring(err))
    end
end
