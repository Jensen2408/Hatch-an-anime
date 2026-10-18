--[[ ReplicatedStorage.CharacterInventory.InventoryClient  (ModuleScript)
Client controller: holds the latest server snapshot plus local view choices (search, filters, sort,
selection), sends action requests, and drives the HUD button, the inventory panel and the reveal.

Presentation only. The snapshot is replaced wholesale by whatever the server sends; the client never
edits an item's Power, income or state itself. While a request is in flight every action button is
disabled, so one press = one request.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("CharacterInventory")
local Config = require(Shared:WaitForChild("InventoryConfig"))
local Format = require(Shared:WaitForChild("InventoryFormat"))
local Model = require(Shared:WaitForChild("InventoryModel"))
local Style = require(Shared:WaitForChild("InventoryStyle"))
local View = require(Shared:WaitForChild("InventoryView"))
local HatchReveal = require(Shared:WaitForChild("HatchReveal"))

local T = Config.Theme
local F = Config.Fonts
local make, text = Style.Make, Style.Text
local player = Players.LocalPlayer

local Client = {}

local state = {
    status = "loading", -- loading | ready | error
    items = {},
    byId = {},
    capacity = nil,
    multiplier = 1,
    allowStore = true,
    search = "",
    rarities = {},
    sort = "Power",
    ascending = false,
    selectedId = nil,
    pinnedId = nil,
    pending = nil,
    alive = false,
    inputHint = "",
}
Client.State = state

local remote, gui, revealGui, hud, view, reveal
local isOpen = false
local stepConn
local layoutKey

---------------------------------------------------------------- helpers
local function reducedMotion()
    return player:GetAttribute("ReducedMotion") == true
end

local function lastInputKind()
    local t = UserInputService:GetLastInputType()
    if t.Name:find("Gamepad") then
        return "Gamepad"
    end
    if t == Enum.UserInputType.Touch then
        return "Touch"
    end
    return "Keyboard"
end

-- The usable screen area: the ScreenGui's own size already excludes the Roblox top bar and the
-- device safe area (notches, rounded corners).
local function viewportSize()
    if gui and gui.AbsoluteSize.X > 0 then
        return gui.AbsoluteSize
    end
    local cam = workspace.CurrentCamera
    return (cam and cam.ViewportSize or Vector2.new(1280, 720)) - GuiService:GetGuiInset()
end

local function chooseLayout()
    local v = viewportSize()
    local L = Config.Layout
    if v.X < L.CompactBelowWidth or v.Y < L.CompactBelowHeight then
        return "Compact", "Dense"
    end
    -- toolbar width inside the shell and page: full rarity names + sort buttons, full names, or short names
    local inner = math.min(L.PanelMaxWidth, v.X - L.Margin * 2) - 40
    return "Wide", inner >= 1060 and "Full" or (inner >= 900 and "Roomy" or "Dense")
end

local function hintText()
    local kind = lastInputKind()
    if kind == "Gamepad" then
        return "B  Close     X  Place best     Y  Sort     LB / RB  Rarity"
    end
    if kind == "Keyboard" then
        return "Esc  Close"
    end
    return ""
end

local render -- forward

---------------------------------------------------------------- snapshot
local function apply(snap)
    if type(snap) ~= "table" or type(snap.items) ~= "table" then
        return
    end
    state.items = snap.items
    state.byId = {}
    for _, item in snap.items do
        state.byId[item.id] = item
    end
    state.capacity = snap.capacity
    state.multiplier = tonumber(snap.multiplier) or 1
    state.allowStore = snap.allowStore == true
    state.status = "ready"
    if state.selectedId and not state.byId[state.selectedId] then
        state.selectedId = nil
    end
    if state.pinnedId and not state.byId[state.pinnedId] then
        state.pinnedId = nil
    end
    render()
end

local function fetch()
    for attempt = 1, math.huge do
        local ok, res = pcall(remote.InvokeServer, remote, "Fetch")
        if ok and type(res) == "table" and res.ok and res.snapshot then
            apply(res.snapshot)
            return
        end
        if #state.items == 0 then
            state.status = "error"
            render()
        end
        task.wait(math.min(2 * attempt, 10))
    end
end

---------------------------------------------------------------- actions
local DONE = { Place = "Placed", Store = "Stored in backpack", Hold = "Holding", PutAway = "Put away" }

local function request(action, id)
    if state.pending then
        return
    end
    state.pending = { action = action, id = id }
    render()
    task.spawn(function()
        local ok, res = pcall(remote.InvokeServer, remote, action, { id = id })
        state.pending = nil
        if ok and type(res) == "table" then
            if res.snapshot then
                apply(res.snapshot)
            else
                render()
            end
            if view then
                if res.ok then
                    view:Toast(res.message or DONE[action] or "Done", res.code == "NoChange" and nil or "ok")
                else
                    view:Toast(res.message or "That didn't work. Try again.", "error")
                end
            end
        else
            render()
            if view then
                view:Toast("Connection hiccup. Try again.", "error")
            end
        end
    end)
end

---------------------------------------------------------------- HUD button
local function buildHud()
    local b = make("TextButton", {
        Name = "InventoryButton",
        AutoButtonColor = false,
        Text = "",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 12, 0.5, 0),
        Size = UDim2.fromOffset(138, 58),
        Selectable = true,
    }, gui)
    local shell = Style.Shell(b, { Size = UDim2.fromScale(1, 1) }, 10)
    shell.Active = false
    local face = Style.Page(shell, 4, 6, 4, 4, 7)
    local icon = make(
        "Frame",
        { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 10), Size = UDim2.fromOffset(28, 28) },
        face
    )
    local brick = make("Frame", { BorderSizePixel = 0, BackgroundColor3 = T.Gold, Size = UDim2.fromScale(1, 1) }, icon)
    Style.Corner(brick, 4)
    Style.Stroke(brick, T.GoldLo, 1)
    for i = 0, 3 do
        local s = make("Frame", {
            BorderSizePixel = 0,
            BackgroundColor3 = T.GoldHi,
            Size = UDim2.fromOffset(8, 8),
            Position = UDim2.fromOffset(4 + (i % 2) * 12, 4 + (i // 2) * 12),
        }, brick)
        Style.Corner(s, 2)
        Style.Stroke(s, T.GoldLo, 1, 0.3)
    end
    text(face, {
        Text = "BEST POWER",
        FontFace = F.Bold,
        TextSize = 9,
        TextColor3 = T.PageMuted,
        Position = UDim2.fromOffset(44, 7),
        Size = UDim2.new(1, -52, 0, 11),
    })
    local value = text(face, {
        Name = "Value",
        Text = "—",
        FontFace = F.Heavy,
        TextSize = 20,
        TextColor3 = T.PageText,
        Position = UDim2.fromOffset(44, 18),
        Size = UDim2.new(1, -52, 0, 24),
        TextTruncate = Enum.TextTruncate.None,
    })
    local key = Style.Chip(face, Config.Input.ToggleKey.Name, T.Chip, {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -5, 0, 5),
        TextColor3 = T.ButtonText,
        TextSize = 9,
        Size = UDim2.fromOffset(0, 14),
    })
    local scale = make("UIScale", { Scale = 1 }, b)
    b.MouseEnter:Connect(function()
        TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.03 }):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
    end)
    b.Activated:Connect(function()
        Client.Toggle()
    end)
    hud = { button = b, value = value, key = key }
end

local function renderHud()
    if not hud then
        return
    end
    local best = Model.Strongest(state.items)
    hud.value.Text = state.status ~= "ready" and "…" or (best and Format.Short(best.power) or "—")
    hud.value.TextColor3 = (best and best.qualityRank >= Config.NotableRank) and best.qualityColor or T.PageText
    hud.key.Visible = lastInputKind() == "Keyboard"
    hud.button.Visible = not isOpen -- the panel covers that spot while it is open
end

---------------------------------------------------------------- view
local callbacks = {}
function callbacks.onSelect(id)
    state.selectedId = id
    render()
    if view and view.mode == "Compact" and id and lastInputKind() == "Gamepad" then
        GuiService.SelectedObject = view.d.primary.Visible and view.d.primary or view.d.back
    end
end
function callbacks.onAction(action, id)
    request(action, id)
end
function callbacks.onSearch(s)
    state.search = s
    render()
end
function callbacks.onRarity(r)
    if r == nil then
        state.rarities = {}
    elseif state.rarities[r] then
        state.rarities[r] = nil
    else
        state.rarities[r] = true
    end
    render()
end
function callbacks.onSort(id)
    if id == nil then
        local i = 1
        for k, s in Config.Sorts do
            if s.Id == state.sort then
                i = k
            end
        end
        state.sort = Config.Sorts[i % #Config.Sorts + 1].Id
        state.ascending = false
    elseif state.sort == id then
        state.ascending = not state.ascending
    else
        state.sort, state.ascending = id, false
    end
    render()
end
function callbacks.onPin(id)
    state.pinnedId = state.pinnedId ~= id and id or nil
    render()
end
function callbacks.onClearFilters()
    state.search = ""
    state.rarities = {}
    render()
end
function callbacks.onClose()
    Client.Close()
end

local function ensureView()
    local mode, density = chooseLayout()
    local key = mode .. density
    if view and layoutKey ~= key then
        view:Destroy()
        view = nil
    end
    if not view then
        view = View.new(gui, mode, density, callbacks)
        layoutKey = key
    end
    view:SetSize(viewportSize())
    view.root.Visible = isOpen
end

render = function()
    state.inputHint = hintText()
    state.serverNow = workspace:GetServerTimeNow()
    renderHud()
    if view and isOpen then
        view:Render(state)
    end
end

---------------------------------------------------------------- open / close / input
local function sink(fn)
    return function(_, inputState)
        if inputState == Enum.UserInputState.Begin then
            fn()
        end
        return Enum.ContextActionResult.Sink
    end
end

local function cycleRarity(dir)
    local list = { false }
    for _, r in Config.Rarities do
        table.insert(list, r)
    end
    local current = 1
    local only = next(state.rarities)
    if only and next(state.rarities, only) == nil then
        for i, r in list do
            if r == only then
                current = i
            end
        end
    end
    local nextIndex = (current - 1 + dir) % #list + 1
    state.rarities = list[nextIndex] and { [list[nextIndex]] = true } or {}
    render()
end

function Client.Open()
    if true then
        return
    end -- Retired UI; the new GUI owns inventory presentation.
    if isOpen then
        return
    end
    isOpen = true
    ensureView()
    view.root.Visible = true
    view.scale.Scale = 0.97
    TweenService:Create(view.scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
        :Play()
    render()
    ContextActionService:BindActionAtPriority("InventoryClose", sink(Client.Close), false, 3000, Enum.KeyCode.ButtonB)
    ContextActionService:BindActionAtPriority(
        "InventoryBest",
        sink(function()
            if view and Style.Enabled(view.bestButton) then
                request("PlaceBest")
            end
        end),
        false,
        3000,
        Enum.KeyCode.ButtonX
    )
    ContextActionService:BindActionAtPriority(
        "InventorySort",
        sink(function()
            callbacks.onSort(nil)
        end),
        false,
        3000,
        Enum.KeyCode.ButtonY
    )
    ContextActionService:BindActionAtPriority(
        "InventoryPrevRarity",
        sink(function()
            cycleRarity(-1)
        end),
        false,
        3000,
        Enum.KeyCode.ButtonL1
    )
    ContextActionService:BindActionAtPriority(
        "InventoryNextRarity",
        sink(function()
            cycleRarity(1)
        end),
        false,
        3000,
        Enum.KeyCode.ButtonR1
    )
    if lastInputKind() == "Gamepad" then
        task.defer(function()
            if isOpen and view then
                GuiService.SelectedObject = view:FirstSelectable()
            end
        end)
    end
    local pulse = 0
    stepConn = RunService.RenderStepped:Connect(function(dt)
        if not view then
            return
        end
        view:Step(dt, reducedMotion())
        if state.status == "loading" then
            pulse += dt
            view:SetLoadingPulse(reducedMotion() and 0.2 or (0.15 + 0.25 * (0.5 + 0.5 * math.sin(pulse * 3))))
        end
    end)
end

function Client.Close()
    if not isOpen then
        return
    end
    isOpen = false
    for _, name in { "InventoryClose", "InventoryBest", "InventorySort", "InventoryPrevRarity", "InventoryNextRarity" } do
        ContextActionService:UnbindAction(name)
    end
    if stepConn then
        stepConn:Disconnect()
        stepConn = nil
    end
    local selected = GuiService.SelectedObject
    if selected and view and selected:IsDescendantOf(view.root) then
        GuiService.SelectedObject = nil
    end
    if view then
        view.search:ReleaseFocus()
        view.root.Visible = false
    end
    renderHud()
end

function Client.Toggle()
    if isOpen then
        Client.Close()
    else
        Client.Open()
    end
end

-- Opens the panel with a specific item selected (for other systems, e.g. a "view" button).
function Client.Show(itemId)
    state.selectedId = itemId
    Client.Open()
    render()
end

---------------------------------------------------------------- start
function Client.Start()
    remote = Shared:WaitForChild(Config.RemoteName)
    local event = Shared:WaitForChild(Config.EventName)
    local playerGui = player:WaitForChild("PlayerGui")

    gui = make("ScreenGui", {
        Name = "CharacterInventory",
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        DisplayOrder = 46, -- above MusicSettingsUI (45)
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, playerGui)
    pcall(function()
        gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
    end)
    revealGui = make("ScreenGui", {
        Name = "CharacterReveal",
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        DisplayOrder = 170,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, playerGui)
    reveal = HatchReveal.new(revealGui)
    -- Old inventory HUD retired; hatch reveals remain active.
    render()

    event.OnClientEvent:Connect(function(kind, payload)
        if kind == "Snapshot" then
            if not state.pending then
                apply(payload)
            end -- the request's own answer arrives right after
        elseif kind == "Reveal" and type(payload) == "table" and type(payload.power) == "number" then
            -- Old cream hatch reveal retired; the 3D reveal stays visible.
        end
    end)

    local function track(char)
        local hum = char:WaitForChild("Humanoid", 10)
        state.alive = hum ~= nil and hum.Health > 0
        render()
        if hum then
            hum.Died:Connect(function()
                state.alive = false
                render()
            end)
        end
    end
    player.CharacterAdded:Connect(track)
    if player.Character then
        task.spawn(track, player.Character)
    end
    player.CharacterRemoving:Connect(function()
        state.alive = false
        render()
    end)

    -- Inventory toggle retired.

    local lastKind = lastInputKind()
    UserInputService.LastInputTypeChanged:Connect(function()
        local kind = lastInputKind()
        if kind ~= lastKind then
            lastKind = kind
            render()
        end
    end)
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if isOpen then
            ensureView()
            render()
        else
            renderHud()
        end
    end)
    -- "Acquired 5m ago" stays honest while the panel is open
    task.spawn(function()
        while true do
            task.wait(30)
            if isOpen then
                render()
            end
        end
    end)

    task.spawn(fetch)
    -- load the portrait meshes once, so cards never show half-loaded characters
    task.spawn(function()
        local folder = Shared:WaitForChild(Config.PortraitFolder, 30)
        local ContentProvider = game:GetService("ContentProvider")
        if folder then
            pcall(ContentProvider.PreloadAsync, ContentProvider, { folder })
        end
    end)
end

return Client
