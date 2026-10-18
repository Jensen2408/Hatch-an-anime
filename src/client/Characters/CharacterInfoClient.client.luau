--[[ StarterPlayerScripts.CharacterInfoClient  (LocalScript)
Floating name / rarity / POWER / $ per second over every character:
  • held in a player's hand  (Tool with CharacterId; label sits over the held character)
  • placed on a temple slot   (tag FloatingCharacter)
  • standing in the incubator after hatching (tag HatchRewardDisplay)
Display only. Reads server-set attributes through ReplicatedStorage.CharacterInfo.Adapter.
Each label = an Attachment "CharacterLabelRoot" in workspace.Terrain + a BillboardGui "CharacterInfoLabel"
in PlayerGui (card built by CharacterInfo.Style). Anchors follow the rendered model at RenderPriority.Last.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local characterInfoFolder = ReplicatedStorage:WaitForChild("CharacterInfo")
local Adapter = require(characterInfoFolder:WaitForChild("Adapter"))
local Style = require(characterInfoFolder:WaitForChild("Style"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- pixel layout (scaled to the stud width below) + how high above the model it floats
-- studs = billboard width; lift = studs above the model top; fade = { _, MaxDistance }; d = Style.Card layout
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
    local connections = pending[model]
    if connections then
        pending[model] = nil
        for _, connection in connections do
            connection:Disconnect()
        end
    end
end
-- Placed models must have all DisplayPartCount parts streamed in; others just need at least one part.
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
    local boxCFrame, size = model:GetBoundingBox()
    local half = size * 0.5
    -- world-space half height of the rotated bounding box
    local extent = math.abs(boxCFrame.RightVector.Y) * half.X
        + math.abs(boxCFrame.UpVector.Y) * half.Y
        + math.abs(boxCFrame.LookVector.Y) * half.Z
    local top = boxCFrame.Position.Y + extent
    local head = holder and holder:FindFirstChild("Head")
    if head then
        top = math.max(top, head.Position.Y + head.Size.Y / 2)
    end
    return Vector3.new(boxCFrame.Position.X, top + lift, boxCFrame.Position.Z)
end

local function hideOldLabels(model)
    for _, name in Adapter.OldLabels or {} do
        local old = model:FindFirstChild(name)
        if old and old:IsA("BillboardGui") then
            old.Enabled = false
        end
    end
end

-- model = the visual Model; source = where the stats attributes live (the Tool for held characters).
-- If stats or geometry are not there yet, retries on the relevant signals instead of polling.
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
    local kindConfig = KINDS[kind]
    hideOldLabels(model)
    local holder = kind == "Held" and source.Parent or nil
    local anchor = Style.make("Attachment", { Name = "CharacterLabelRoot" }, workspace.Terrain)
    anchor.WorldPosition = labelPosition(model, kindConfig.lift, holder)
    Style.make("ObjectValue", { Name = "CharacterModel", Value = model }, anchor)
    local billboard = Style.make("BillboardGui", {
        Name = "CharacterInfoLabel",
        Adornee = anchor,
        LightInfluence = 0,
        AlwaysOnTop = kind == "Held",
        ResetOnSpawn = false,
        Size = UDim2.new(kindConfig.studs, 0, kindConfig.studs * kindConfig.d.h / kindConfig.d.w, 0),
        StudsOffsetWorldSpace = Vector3.zero,
        SizeOffset = Vector2.new(0, 0.5), -- bottom of the text sits at the offset point
        MaxDistance = kindConfig.fade[2],
    }, playerGui)
    local group = Style.make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, billboard)
    local inner = Style.make("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(kindConfig.d.w, kindConfig.d.h),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
    }, group) -- centred: scaling keeps it in the middle
    local uiScale = Style.make("UIScale", {}, inner)
    local ui = Style.Card(inner, kindConfig.d)
    local labelState = {
        bb = billboard,
        group = group,
        ui = ui,
        scale = uiScale,
        model = model,
        anchor = anchor,
        kind = kind,
        holder = holder,
        conns = {},
        appear = true,
    }
    labels[model] = labelState
    local function refresh(first)
        local latest = Adapter.Read(source)
        if not latest then
            return
        end
        local wasExceptional = ui.pgrad.Enabled
        Style.Apply(ui, latest)
        -- celebrate only on the first show or when a refresh turns the label exceptional
        if latest.exceptional and (first or not wasExceptional) then
            Style.Celebrate(ui, Adapter.ReducedMotion())
        end
    end
    for _, attributeName in Adapter.Watched() do
        table.insert(
            labelState.conns,
            source:GetAttributeChangedSignal(attributeName):Connect(function()
                refresh(false)
            end)
        )
    end
    refresh(true)
    -- fit the pixel layout into the stud-sized billboard
    local function fit()
        uiScale.Scale = math.max(0.01, billboard.AbsoluteSize.X / kindConfig.d.w)
    end
    table.insert(labelState.conns, billboard:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
    fit()
end

local function remove(model)
    clearPending(model)
    local labelState = labels[model]
    if not labelState then
        return
    end
    for _, connection in labelState.conns do
        connection:Disconnect()
    end
    labelState.bb:Destroy()
    labelState.anchor:Destroy()
    labels[model] = nil
end

---------------------------------------------------------------- placed + hatched models
for tag, kind in Adapter.ModelTags do
    for _, model in CollectionService:GetTagged(tag) do
        task.spawn(add, model, kind)
    end
    CollectionService:GetInstanceAddedSignal(tag):Connect(function(model)
        task.defer(add, model, kind)
    end) -- also fires when streamed in
    CollectionService:GetInstanceRemovedSignal(tag):Connect(remove) -- pickup / streamed out / collected
end

---------------------------------------------------------------- held in a hand (any player)
local function heldModel(tool)
    return tool:FindFirstChild("Character") or tool:FindFirstChildWhichIsA("Model")
end
local function watchCharacter(character)
    local function equip(child)
        if not child:IsA("Tool") then
            return
        end
        -- other players' tools replicate in pieces: wait for the id and the held model to arrive
        task.spawn(function()
            local startTime = os.clock()
            while child.Parent == character and not Adapter.IsCharacterTool(child) and os.clock() - startTime < 5 do
                task.wait(0.1)
            end
            if child.Parent ~= character or not Adapter.IsCharacterTool(child) then
                return
            end
            local model = heldModel(child) or child:WaitForChild("Character", 5)
            if model and child.Parent == character then
                add(model, "Held", child)
            end
        end)
    end
    for _, child in character:GetChildren() do
        equip(child)
    end
    character.ChildAdded:Connect(equip)
    character.ChildRemoved:Connect(function(child) -- unequip / drop / place
        if child:IsA("Tool") then
            local model = heldModel(child)
            if model then
                remove(model)
            end
        end
    end)
end
local function watchPlayer(otherPlayer)
    otherPlayer.CharacterAdded:Connect(watchCharacter)
    if otherPlayer.Character then
        watchCharacter(otherPlayer.Character)
    end
end
for _, otherPlayer in Players:GetPlayers() do
    watchPlayer(otherPlayer)
end
Players.PlayerAdded:Connect(watchPlayer)

---------------------------------------------------------------- Follow the final rendered pose, including showcase spins and hatch/hand animation.
RunService:BindToRenderStep("CharacterInfoAnchors", Enum.RenderPriority.Last.Value, function()
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end
    local cameraPosition = camera.CFrame.Position
    for model, labelState in labels do
        if not model:IsDescendantOf(workspace) or not labelState.anchor.Parent then
            remove(model)
        else
            local kindConfig = KINDS[labelState.kind]
            -- skip the bounding-box work when the label is hidden anyway (25 stud margin)
            if (model:GetPivot().Position - cameraPosition).Magnitude < kindConfig.fade[2] + 25 then
                labelState.anchor.WorldPosition = labelPosition(model, kindConfig.lift, labelState.holder)
            end
            -- MaxDistance already hides it past fade[2]; a small pop-in the first time it shows
            if labelState.appear and labelState.bb.AbsoluteSize.X > 1 then
                labelState.appear = false
                if not Adapter.ReducedMotion() then
                    local fullScale = labelState.scale.Scale
                    labelState.scale.Scale = fullScale * 0.85
                    TweenService
                        :Create(labelState.scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = fullScale })
                        :Play()
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
