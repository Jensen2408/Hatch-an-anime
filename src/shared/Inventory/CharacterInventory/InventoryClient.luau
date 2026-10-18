--[[ ReplicatedStorage.CharacterInventory.InventoryClient  (ModuleScript)
Client controller: holds the latest server snapshot plus local view choices (search, filters, sort,
selection), sends action requests, and drives the HUD button, the inventory panel and the reveal.

Presentation only. The snapshot is replaced wholesale by whatever the server sends; the client never
edits an item's Power, income or state itself. While a request is in flight every action button is
disabled, so one press = one request.

Network (ReplicatedStorage.CharacterInventory, contract in InventoryService's header):
  RemoteFunction Config.RemoteName: ("Fetch") on start (retried with backoff), (action, { id }) per press.
  RemoteEvent Config.EventName: "Snapshot" pushes are applied unless a request is in flight; "Reveal" is
  currently ignored.
Current state of the UI: the panel, its HUD button and the toggle key are retired (Client.Open returns
immediately and buildHud is never called); Start still creates both ScreenGuis, fetches the snapshot and
keeps `state` up to date. Entry point: StarterPlayerScripts.CharacterInventoryStart calls Client.Start().
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

local Theme = Config.Theme
local Fonts = Config.Fonts
local make, text = Style.Make, Style.Text
local player = Players.LocalPlayer

local Client = {}

-- Latest server snapshot + local view choices. Exposed as Client.State and handed to View:Render.
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

local remote, gui, revealGui, hud, view, _reveal
local isOpen = false
local stepConnection -- RenderStepped while the panel is open
local layoutKey -- mode .. density of the current view; a change rebuilds it

---------------------------------------------------------------- helpers
local function reducedMotion()
    return player:GetAttribute("ReducedMotion") == true
end

-- "Gamepad" | "Touch" | "Keyboard" (mouse counts as keyboard).
local function lastInputKind()
    local inputType = UserInputService:GetLastInputType()
    if inputType.Name:find("Gamepad") then
        return "Gamepad"
    end
    if inputType == Enum.UserInputType.Touch then
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
    local camera = workspace.CurrentCamera
    return (camera and camera.ViewportSize or Vector2.new(1280, 720)) - GuiService:GetGuiInset()
end

-- Returns (mode, density) for View.new: "Compact"/"Wide" and "Full"/"Roomy"/"Dense".
local function chooseLayout()
    local viewport = viewportSize()
    local layout = Config.Layout
    if viewport.X < layout.CompactBelowWidth or viewport.Y < layout.CompactBelowHeight then
        return "Compact", "Dense"
    end
    -- toolbar width inside the shell and page: full rarity names + sort buttons, full names, or short names
    local innerWidth = math.min(layout.PanelMaxWidth, viewport.X - layout.Margin * 2) - 40
    return "Wide", innerWidth >= 1060 and "Full" or (innerWidth >= 900 and "Roomy" or "Dense")
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

local render -- forward declaration (assigned below, after ensureView)

---------------------------------------------------------------- snapshot
-- Replaces the client's copy with a server snapshot; drops a selection / pin whose item is gone.
local function apply(snapshot)
    if type(snapshot) ~= "table" or type(snapshot.items) ~= "table" then
        return
    end
    state.items = snapshot.items
    state.byId = {}
    for _, item in snapshot.items do
        state.byId[item.id] = item
    end
    state.capacity = snapshot.capacity
    state.multiplier = tonumber(snapshot.multiplier) or 1
    state.allowStore = snapshot.allowStore == true
    state.status = "ready"
    if state.selectedId and not state.byId[state.selectedId] then
        state.selectedId = nil
    end
    if state.pinnedId and not state.byId[state.pinnedId] then
        state.pinnedId = nil
    end
    render()
end

-- Retries forever (2 s, 4 s, ... capped at 10 s) until the first snapshot arrives.
local function fetch()
    for attempt = 1, math.huge do
        local ok, response = pcall(remote.InvokeServer, remote, "Fetch")
        if ok and type(response) == "table" and response.ok and response.snapshot then
            apply(response.snapshot)
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
-- Fallback success toasts when the server reply has no message.
local DONE_MESSAGES = { Place = "Placed", Store = "Stored in backpack", Hold = "Holding", PutAway = "Put away" }

-- One request at a time: ignored while another is pending. The reply's snapshot (if any) is applied
-- and a toast shows the outcome.
local function request(action, id)
    if state.pending then
        return
    end
    state.pending = { action = action, id = id }
    render()
    task.spawn(function()
        local ok, response = pcall(remote.InvokeServer, remote, action, { id = id })
        state.pending = nil
        if ok and type(response) == "table" then
            if response.snapshot then
                apply(response.snapshot)
            else
                render()
            end
            if view then
                if response.ok then
                    view:Toast(
                        response.message or DONE_MESSAGES[action] or "Done",
                        response.code == "NoChange" and nil or "ok"
                    )
                else
                    view:Toast(response.message or "That didn't work. Try again.", "error")
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
-- Retired (never called): "BEST POWER" button at the left edge that toggled the panel.
local function _buildHud()
    local hudButton = make("TextButton", {
        Name = "InventoryButton",
        AutoButtonColor = false,
        Text = "",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 12, 0.5, 0),
        Size = UDim2.fromOffset(138, 58),
        Selectable = true,
    }, gui)
    local shell = Style.Shell(hudButton, { Size = UDim2.fromScale(1, 1) }, 10)
    shell.Active = false
    local face = Style.Page(shell, 4, 6, 4, 4, 7)
    local icon = make(
        "Frame",
        { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 10), Size = UDim2.fromOffset(28, 28) },
        face
    )
    local brick =
        make("Frame", { BorderSizePixel = 0, BackgroundColor3 = Theme.Gold, Size = UDim2.fromScale(1, 1) }, icon)
    Style.Corner(brick, 4)
    Style.Stroke(brick, Theme.GoldLo, 1)
    for i = 0, 3 do -- 2x2 studs on the brick icon
        local stud = make("Frame", {
            BorderSizePixel = 0,
            BackgroundColor3 = Theme.GoldHi,
            Size = UDim2.fromOffset(8, 8),
            Position = UDim2.fromOffset(4 + (i % 2) * 12, 4 + (i // 2) * 12),
        }, brick)
        Style.Corner(stud, 2)
        Style.Stroke(stud, Theme.GoldLo, 1, 0.3)
    end
    text(face, {
        Text = "BEST POWER",
        FontFace = Fonts.Bold,
        TextSize = 9,
        TextColor3 = Theme.PageMuted,
        Position = UDim2.fromOffset(44, 7),
        Size = UDim2.new(1, -52, 0, 11),
    })
    local value = text(face, {
        Name = "Value",
        Text = "—",
        FontFace = Fonts.Heavy,
        TextSize = 20,
        TextColor3 = Theme.PageText,
        Position = UDim2.fromOffset(44, 18),
        Size = UDim2.new(1, -52, 0, 24),
        TextTruncate = Enum.TextTruncate.None,
    })
    local key = Style.Chip(face, Config.Input.ToggleKey.Name, Theme.Chip, {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -5, 0, 5),
        TextColor3 = Theme.ButtonText,
        TextSize = 9,
        Size = UDim2.fromOffset(0, 14),
    })
    local scale = make("UIScale", { Scale = 1 }, hudButton)
    hudButton.MouseEnter:Connect(function()
        TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.03 }):Play()
    end)
    hudButton.MouseLeave:Connect(function()
        TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
    end)
    hudButton.Activated:Connect(function()
        Client.Toggle()
    end)
    hud = { button = hudButton, value = value, key = key }
end

local function renderHud()
    if not hud then
        return
    end
    local best = Model.Strongest(state.items)
    hud.value.Text = state.status ~= "ready" and "…" or (best and Format.Short(best.power) or "—")
    hud.value.TextColor3 = (best and best.qualityRank >= Config.NotableRank) and best.qualityColor or Theme.PageText
    hud.key.Visible = lastInputKind() == "Keyboard"
    hud.button.Visible = not isOpen -- the panel covers that spot while it is open
end

---------------------------------------------------------------- view
-- Intents from InventoryView (contract: View.new(..., callbacks)). Each one updates `state` and re-renders.
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
function callbacks.onSearch(searchText)
    state.search = searchText
    render()
end
-- nil = "ALL" (clear the filter); otherwise toggles that rarity.
function callbacks.onRarity(rarity)
    if rarity == nil then
        state.rarities = {}
    elseif state.rarities[rarity] then
        state.rarities[rarity] = nil
    else
        state.rarities[rarity] = true
    end
    render()
end
-- nil = cycle to the next sort (descending); the active sort id flips the direction; another id selects it.
function callbacks.onSort(id)
    if id == nil then
        local currentIndex = 1
        for index, sort in Config.Sorts do
            if sort.Id == state.sort then
                currentIndex = index
            end
        end
        state.sort = Config.Sorts[currentIndex % #Config.Sorts + 1].Id
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

-- Creates the view, or rebuilds it when the layout (mode + density) changed, then sizes it.
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
-- ContextActionService handler that runs `callback` on press and always sinks the input.
local function sink(callback)
    return function(_, inputState)
        if inputState == Enum.UserInputState.Begin then
            callback()
        end
        return Enum.ContextActionResult.Sink
    end
end

-- Gamepad LB / RB: steps through ALL -> each single rarity -> ALL. A multi-rarity filter counts as ALL.
local function cycleRarity(direction)
    local list = { false } -- false = ALL
    for _, rarity in Config.Rarities do
        table.insert(list, rarity)
    end
    local current = 1
    local only = next(state.rarities)
    if only and next(state.rarities, only) == nil then
        for i, rarity in list do
            if rarity == only then
                current = i
            end
        end
    end
    local nextIndex = (current - 1 + direction) % #list + 1
    state.rarities = list[nextIndex] and { [list[nextIndex]] = true } or {}
    render()
end

function Client.Open()
    if true then
        return
    end -- Retired UI; the new GUI owns inventory presentation. Everything below is unreachable.
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
    stepConnection = RunService.RenderStepped:Connect(function(dt)
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
    if stepConnection then
        stepConnection:Disconnect()
        stepConnection = nil
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
    _reveal = HatchReveal.new(revealGui)
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

    -- state.alive gates every action (Model.Actions / PLACE BEST).
    local function track(character)
        local humanoid = character:WaitForChild("Humanoid", 10)
        state.alive = humanoid ~= nil and humanoid.Health > 0
        render()
        if humanoid then
            humanoid.Died:Connect(function()
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
