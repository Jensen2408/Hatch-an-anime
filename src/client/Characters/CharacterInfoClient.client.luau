--[[ StarterPlayerScripts.CharacterInfoClient  (LocalScript)
Floating name / rarity / POWER / $ per second over every character:
  • held in a player's hand  (Tool with CharacterId; label sits over the held character)
  • placed on a temple slot   (tag FloatingCharacter)
  • standing in the incubator after hatching (tag HatchRewardDisplay)
Display only. Reads server-set attributes through ReplicatedStorage.CharacterInfo.Adapter.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:WaitForChild("CharacterInfo")
local Adapter = require(folder:WaitForChild("Adapter"))
local S = require(folder:WaitForChild("Style"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- pixel layout (scaled to the stud width below) + how high above the model it floats
local KINDS = {
    Placed = {
        studs = 6,
        lift = 0.9,
        fade = { 45, 60 },
        d = {
            w = 228,
            h = 112,
            nameSize = 19,
            rarSize = 13,
            powLabel = 11,
            powerSize = 20,
            incSize = 16,
            stroke = 2.5,
            gap = 1,
        },
    },
    Hatch = {
        studs = 4.5,
        lift = 0.5,
        fade = { 45, 60 },
        d = {
            w = 228,
            h = 112,
            nameSize = 19,
            rarSize = 13,
            powLabel = 11,
            powerSize = 20,
            incSize = 16,
            stroke = 2.5,
            gap = 1,
        },
    },
    Held = {
        studs = 4.5,
        lift = 0.6,
        fade = { 35, 50 },
        d = {
            w = 228,
            h = 112,
            nameSize = 19,
            rarSize = 13,
            powLabel = 11,
            powerSize = 20,
            incSize = 16,
            stroke = 2.5,
            gap = 1,
        },
    },
}

local labels = {} -- model -> state
local pending = {} -- model -> connections waiting for stats and complete geometry
local function clearPending(model)
    local conns = pending[model]
    if conns then
        pending[model] = nil
        for _, c in conns do
            c:Disconnect()
        end
    end
end
local function geometryReady(model, kind)
    local expected = kind == "Placed" and model:GetAttribute("DisplayPartCount") or nil
    local count = 0
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") then
            count += 1
        end
    end
    return count > 0 and (not expected or count >= expected)
end

-- One local, nonphysical root per label. It lives outside the character so it cannot
-- affect its bounds, pivot, physics, or podium placement.
local function labelPosition(model, lift, holder)
    local cf, size = model:GetBoundingBox()
    local half = size * 0.5
    local extent = math.abs(cf.RightVector.Y) * half.X
        + math.abs(cf.UpVector.Y) * half.Y
        + math.abs(cf.LookVector.Y) * half.Z
    local top = cf.Position.Y + extent
    local head = holder and holder:FindFirstChild("Head")
    if head then
        top = math.max(top, head.Position.Y + head.Size.Y / 2)
    end
    return Vector3.new(cf.Position.X, top + lift, cf.Position.Z)
end

local function hideOldLabels(model)
    for _, name in Adapter.OldLabels or {} do
        local old = model:FindFirstChild(name)
        if old and old:IsA("BillboardGui") then
            old.Enabled = false
        end
    end
end

local add
add = function(model, kind, source)
    source = source or model
    if labels[model] or not model:IsA("Model") then
        return
    end
    local data = Adapter.Read(source)
    if not data or not geometryReady(model, kind) then
        if not pending[model] then
            local function retry()
                if model:IsDescendantOf(workspace) then
                    add(model, kind, source)
                end
            end
            pending[model] = {
                source:GetAttributeChangedSignal(Adapter.Attr.Power):Connect(retry),
                model.DescendantAdded:Connect(retry),
                model:GetAttributeChangedSignal("DisplayPartCount"):Connect(retry),
                model.AncestryChanged:Connect(function()
                    if not model:IsDescendantOf(workspace) then
                        clearPending(model)
                    end
                end),
            }
        end
        return
    end
    clearPending(model)
    local k = KINDS[kind]
    hideOldLabels(model)
    local holder = kind == "Held" and source.Parent or nil
    local anchor = S.make("Attachment", { Name = "CharacterLabelRoot" }, workspace.Terrain)
    anchor.WorldPosition = labelPosition(model, k.lift, holder)
    S.make("ObjectValue", { Name = "CharacterModel", Value = model }, anchor)
    local bb = S.make("BillboardGui", {
        Name = "CharacterInfoLabel",
        Adornee = anchor,
        LightInfluence = 0,
        AlwaysOnTop = kind == "Held",
        ResetOnSpawn = false,
        Size = UDim2.new(k.studs, 0, k.studs * k.d.h / k.d.w, 0),
        StudsOffsetWorldSpace = Vector3.zero,
        SizeOffset = Vector2.new(0, 0.5), -- bottom of the text sits at the offset point
        MaxDistance = k.fade[2],
    }, playerGui)
    local group = S.make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, bb)
    local inner = S.make("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(k.d.w, k.d.h),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
    }, group) -- centred: scaling keeps it in the middle
    local sc = S.make("UIScale", {}, inner)
    local ui = S.Card(inner, k.d)
    local st = {
        bb = bb,
        group = group,
        ui = ui,
        scale = sc,
        model = model,
        anchor = anchor,
        kind = kind,
        holder = holder,
        conns = {},
        appear = true,
    }
    labels[model] = st
    local function upd(first)
        local d = Adapter.Read(source)
        if not d then
            return
        end
        local was = ui.pgrad.Enabled
        S.Apply(ui, d)
        if d.exceptional and (first or not was) then
            S.Celebrate(ui, Adapter.ReducedMotion())
        end
    end
    for _, a in Adapter.Watched() do
        table.insert(
            st.conns,
            source:GetAttributeChangedSignal(a):Connect(function()
                upd(false)
            end)
        )
    end
    upd(true)
    -- fit the pixel layout into the stud-sized billboard
    local function fit()
        sc.Scale = math.max(0.01, bb.AbsoluteSize.X / k.d.w)
    end
    table.insert(st.conns, bb:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
    fit()
end

local function remove(model)
    clearPending(model)
    local st = labels[model]
    if not st then
        return
    end
    for _, c in st.conns do
        c:Disconnect()
    end
    st.bb:Destroy()
    st.anchor:Destroy()
    labels[model] = nil
end

---------------------------------------------------------------- placed + hatched models
for tag, kind in Adapter.ModelTags do
    for _, m in CollectionService:GetTagged(tag) do
        task.spawn(add, m, kind)
    end
    CollectionService:GetInstanceAddedSignal(tag):Connect(function(m)
        task.defer(add, m, kind)
    end) -- also fires when streamed in
    CollectionService:GetInstanceRemovedSignal(tag):Connect(remove) -- pickup / streamed out / collected
end

---------------------------------------------------------------- held in a hand (any player)
local function heldModel(tool)
    return tool:FindFirstChild("Character") or tool:FindFirstChildWhichIsA("Model")
end
local function watchCharacter(char)
    local function equip(child)
        if not child:IsA("Tool") then
            return
        end
        -- other players' tools replicate in pieces: wait for the id and the held model to arrive
        task.spawn(function()
            local t0 = os.clock()
            while child.Parent == char and not Adapter.IsCharacterTool(child) and os.clock() - t0 < 5 do
                task.wait(0.1)
            end
            if child.Parent ~= char or not Adapter.IsCharacterTool(child) then
                return
            end
            local m = heldModel(child) or child:WaitForChild("Character", 5)
            if m and child.Parent == char then
                add(m, "Held", child)
            end
        end)
    end
    for _, c in char:GetChildren() do
        equip(c)
    end
    char.ChildAdded:Connect(equip)
    char.ChildRemoved:Connect(function(child) -- unequip / drop / place
        if child:IsA("Tool") then
            local m = heldModel(child)
            if m then
                remove(m)
            end
        end
    end)
end
local function watchPlayer(p)
    p.CharacterAdded:Connect(watchCharacter)
    if p.Character then
        watchCharacter(p.Character)
    end
end
for _, p in Players:GetPlayers() do
    watchPlayer(p)
end
Players.PlayerAdded:Connect(watchPlayer)

---------------------------------------------------------------- Follow the final rendered pose, including showcase spins and hatch/hand animation.
RunService:BindToRenderStep("CharacterInfoAnchors", Enum.RenderPriority.Last.Value, function()
    local cam = workspace.CurrentCamera
    if not cam then
        return
    end
    local cp = cam.CFrame.Position
    for model, st in labels do
        if not model:IsDescendantOf(workspace) or not st.anchor.Parent then
            remove(model)
        else
            local k = KINDS[st.kind]
            if (model:GetPivot().Position - cp).Magnitude < k.fade[2] + 25 then
                st.anchor.WorldPosition = labelPosition(model, k.lift, st.holder)
            end
            -- MaxDistance already hides it past fade[2]; a small pop-in the first time it shows
            if st.appear and st.bb.AbsoluteSize.X > 1 then
                st.appear = false
                if not Adapter.ReducedMotion() then
                    local full = st.scale.Scale
                    st.scale.Scale = full * 0.85
                    TweenService:Create(st.scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = full }):Play()
                end
            end
        end
    end
end)

script.Destroying:Connect(function()
    RunService:UnbindFromRenderStep("CharacterInfoAnchors")
    for model in labels do
        remove(model)
    end
    for model in pending do
        clearPending(model)
    end
end)
