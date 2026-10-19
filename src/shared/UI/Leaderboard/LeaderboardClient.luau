--[[ ReplicatedStorage.Leaderboard.LeaderboardClient  (ModuleScript, started by StarterPlayerScripts.LeaderboardClientStart)
One controller for every board in the map and the expanded screen:
  • holds the shared state (tab, scope) and a cache of server snapshots per tab + scope
  • puts an Active SurfaceGui on each tagged board's Screen part (in PlayerGui, so input works)
  • opens the larger ScreenGui from the board's "Open leaderboard" ProximityPrompt
  • polls the server only while a board is near the camera or the expanded view is open

Network: Shared.<Config.RemoteName> (RemoteFunction, created by LeaderboardService).
  InvokeServer(statId, scope) -> snapshot table (see LeaderboardView:Render) or { status = "busy" } when
  the server-side rate limit is hit. The server is authoritative; nothing the client sends is stored.
Gamepad: while the expanded view is open, B closes, L1/R1 cycle tabs and Y toggles scope
  (ContextActionService priority 3000, so they win over other bindings).
]]
-- ===== 1. Setup =====
-- Declared first (before the services) only for historical reasons; it has no dependencies.
local function isClickOnPanel(dimmer, input)
    -- true if the click landed on any visible part of a panel (anything in this ScreenGui that isn't the dim)
    if not (input and input.Position) then
        return false
    end
    local playerGui = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local layerCollector = dimmer:FindFirstAncestorWhichIsA("LayerCollector")
    for _, guiObject in playerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y) do
        if
            guiObject ~= dimmer
            and layerCollector
            and guiObject:IsDescendantOf(layerCollector)
            and not guiObject:IsDescendantOf(dimmer)
        then
            return true
        end
    end
    return false
end
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local UISound = require(game:GetService("ReplicatedStorage"):WaitForChild("UISound"))

local Shared = script.Parent
local Config = require(Shared:WaitForChild("LeaderboardConfig"))
local View = require(Shared:WaitForChild("LeaderboardView"))

local ClientConfig = Config.Client
local Theme = Config.Theme
local player = Players.LocalPlayer

local Client = {}

local state = { tab = Config.Stats[1].Id, scope = "Server" }
local cache = {} -- ["Cash|Server"] = { snapshot, fetchedAt, failed }
local inflightFetches = {} -- [cacheKey] = true while an InvokeServer for that key is running
local boards = {} -- [Model] = { screen, gui, view, prompt, conn }
local expanded = nil -- { gui, shell, view, model, conns }
local snapshotRemote = nil
local started = false
local callbacks -- { onTab, onScope, onClose }, set by Client.Start and shared by every view

local function currentKey()
    return state.tab .. "|" .. state.scope
end

local function renderState()
    local cacheEntry = cache[currentKey()]
    local phase = "ready"
    if not (cacheEntry and cacheEntry.snapshot) then
        phase = (cacheEntry and cacheEntry.failed) and "error" or "loading"
    end
    return {
        tab = state.tab,
        scope = state.scope,
        snapshot = cacheEntry and cacheEntry.snapshot,
        phase = phase,
        localUserId = player.UserId,
        localName = player.Name,
        localDisplayName = player.DisplayName,
    }
end

local function forEachView(callback)
    for _, board in boards do
        if board.view then
            callback(board.view)
        end
    end
    if expanded and expanded.view then
        callback(expanded.view)
    end
end

local function render()
    local viewState = renderState()
    forEachView(function(view)
        view:Render(viewState)
    end)
end

-- ===== 2. Data (fetch + staleness) =====
-- One request per tab + scope at a time. A "busy" (rate-limited) reply counts as a failure, so the
-- RetryAfterError interval applies and the last good snapshot stays on screen.
local function fetch(tab, scope)
    local key = tab .. "|" .. scope
    if inflightFetches[key] or not snapshotRemote then
        return
    end
    inflightFetches[key] = true
    task.spawn(function()
        local invokeOk, result = pcall(snapshotRemote.InvokeServer, snapshotRemote, tab, scope)
        inflightFetches[key] = nil
        local cacheEntry = cache[key] or {}
        cache[key] = cacheEntry
        cacheEntry.fetchedAt = os.clock()
        if invokeOk and type(result) == "table" and result.status ~= "busy" then
            cacheEntry.snapshot = result
            cacheEntry.failed = false
        else
            cacheEntry.failed = true -- keep showing the last good snapshot, if any
        end
        if key == currentKey() then
            render()
        end
    end)
end

local function refreshIfStale()
    local cacheEntry = cache[currentKey()]
    local interval = state.scope == "Global" and ClientConfig.PollGlobal or ClientConfig.PollServer
    if cacheEntry and cacheEntry.failed then
        interval = ClientConfig.RetryAfterError
    end
    -- the server answers "loading" until its first refresh has run: ask again soon
    if cacheEntry and cacheEntry.snapshot and cacheEntry.snapshot.status == "loading" then
        interval = 2
    end
    if not cacheEntry or os.clock() - (cacheEntry.fetchedAt or 0) >= interval then
        fetch(state.tab, state.scope)
    end
end

local function setTab(id)
    if id == state.tab or not Config.StatById[id] then
        return
    end
    state.tab = id
    render()
    refreshIfStale()
end

local function setScope(scope)
    if scope == state.scope then
        return
    end
    state.scope = scope
    render()
    refreshIfStale()
end

local function cycleTab(step)
    local index = 1
    for i, stat in Config.Stats do
        if stat.Id == state.tab then
            index = i
        end
    end
    index = (index - 1 + step) % #Config.Stats + 1
    setTab(Config.Stats[index].Id)
end

local function rootPosition()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return root and root.Position
end

-- Polling only happens while something can show the data: the expanded view, or a board near the camera.
local function isActive()
    if expanded then
        return true
    end
    local camera = workspace.CurrentCamera
    local cameraPosition = camera and camera.CFrame.Position
    if not cameraPosition then
        return false
    end
    for _, board in boards do
        if
            board.screen
            and board.screen.Parent
            and (board.screen.Position - cameraPosition).Magnitude <= ClientConfig.ActiveDistance
        then
            return true
        end
    end
    return false
end

-- ===== 3. Expanded screen =====
local ROOF_HEIGHT = 24 -- px of tile roof above the shell

local function panelLayout()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local inset = GuiService:GetGuiInset()
    local width = math.floor(math.min(ClientConfig.PanelMaxWidth, viewport.X - 24))
    local height = math.floor(math.min(ClientConfig.PanelMaxHeight, viewport.Y - inset.Y - 20))
    local compact = height < ClientConfig.CompactBelowHeight or width < ClientConfig.CompactBelowWidth
    local center = Vector2.new(viewport.X / 2, inset.Y + (viewport.Y - inset.Y) / 2)
    if compact and viewport.X - 2 * ClientConfig.CompactCornerReserve >= ClientConfig.CompactBelowWidth then
        -- landscape phones: take the full height and keep clear of the corner buttons instead of the top bar
        width = math.floor(math.min(ClientConfig.PanelMaxWidth, viewport.X - 2 * ClientConfig.CompactCornerReserve))
        height = math.floor(math.min(ClientConfig.PanelMaxHeight, viewport.Y - 16))
        center = viewport / 2
    end
    -- leave room for the tile roof that sits on top of the shell
    height -= ROOF_HEIGHT
    center += Vector2.new(0, ROOF_HEIGHT / 2)
    return width, height, center, compact
end

local function usingGamepad()
    local lastInputType = UserInputService:GetLastInputType()
    return lastInputType.Name:sub(1, 7) == "Gamepad"
end

-- Wraps a callback as a ContextActionService handler that fires on press and always sinks the input.
local function sinkAction(callback)
    return function(_, inputState)
        if inputState == Enum.UserInputState.Begin then
            callback()
        end
        return Enum.ContextActionResult.Sink
    end
end

-- Re-fits the shell to the viewport; the view itself is only rebuilt when the compact layout flips.
local function buildExpandedView(panel)
    local width, height, center, compact = panelLayout()
    panel.shell.Size = UDim2.fromOffset(width, height)
    panel.shell.Position = UDim2.fromOffset(center.X, center.Y)
    if panel.view and panel.compact == compact then
        return
    end
    if panel.view then
        panel.view:Destroy()
    end
    panel.compact = compact
    panel.view = View.new(panel.screen, compact and "Compact" or "Screen", callbacks)
    panel.view:Render(renderState())
end

function Client.Open(model)
    if expanded or not started then
        return
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "LeaderboardExpanded"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 40
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local dimmer = Instance.new("TextButton")
    dimmer.Name = "Dim"
    dimmer:SetAttribute("UISoundMuted", true)
    dimmer.Size = UDim2.fromScale(1, 1)
    dimmer.BackgroundColor3 = Color3.new(0, 0, 0)
    dimmer.BackgroundTransparency = 1
    dimmer.Text = ""
    dimmer.AutoButtonColor = false
    dimmer.Selectable = false
    dimmer.Parent = gui

    -- the shell mirrors the shrine board: wood frame under a tile roof with upturned eaves and a gold
    -- crest, a gold top bevel, gold studs, and a gold-trimmed screen
    local shell = Instance.new("Frame")
    shell.Name = "Shell"
    shell.AnchorPoint = Vector2.new(0.5, 0.5)
    shell.BackgroundColor3 = Theme.Frame
    shell.BorderSizePixel = 0
    shell.Active = true
    shell.Parent = gui
    Instance.new("UICorner", shell).CornerRadius = UDim.new(0, 12)
    local openScale = Instance.new("UIScale")
    openScale.Scale = 0.96
    openScale.Parent = shell
    local bevel = Instance.new("Frame")
    bevel.Name = "Bevel"
    bevel.Position = UDim2.fromOffset(12, 2)
    bevel.Size = UDim2.new(1, -24, 0, 2)
    bevel.BackgroundColor3 = Theme.Bevel
    bevel.BackgroundTransparency = 0.45
    bevel.BorderSizePixel = 0
    bevel.Parent = shell
    local studs = Instance.new("Frame")
    studs.Name = "Studs"
    studs.BackgroundTransparency = 1
    studs.Position = UDim2.fromOffset(24, 6)
    studs.Size = UDim2.new(1, -48, 0, 6)
    studs.Parent = shell
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, 22)
    layout.Parent = studs
    for _ = 1, 12 do
        local stud = Instance.new("Frame")
        stud.Size = UDim2.fromOffset(6, 6)
        stud.BackgroundColor3 = Theme.Stud
        stud.BorderSizePixel = 0
        stud.Parent = studs
    end

    local function createPlainFrame(name, parent, color, size, position)
        local frame = Instance.new("Frame")
        frame.Name = name
        frame.BackgroundColor3 = color
        frame.BorderSizePixel = 0
        frame.Size = size
        frame.Position = position
        frame.Parent = parent
        return frame
    end
    -- tile roof: wider than the shell, a darker eave strip, upturned tips, a ridge and a gold crest
    local roof = createPlainFrame(
        "Roof",
        shell,
        Theme.Roof,
        UDim2.new(1, 28, 0, ROOF_HEIGHT),
        UDim2.fromOffset(-14, -ROOF_HEIGHT + 2)
    )
    roof.Active = true -- clicks on the roof do not fall through to the dim and close the view
    Instance.new("UICorner", roof).CornerRadius = UDim.new(0, 5)
    createPlainFrame("Eave", roof, Theme.RoofEdge, UDim2.new(1, -8, 0, 4), UDim2.new(0, 4, 1, -4))
    createPlainFrame("Gold", roof, Theme.Gold, UDim2.new(1, -40, 0, 2), UDim2.fromOffset(20, 4)).BackgroundTransparency =
        0.25
    for _, side in { 0, 1 } do
        local tip = createPlainFrame(
            "EaveTip",
            roof,
            Theme.Roof,
            UDim2.fromOffset(22, 8),
            UDim2.new(side, side == 0 and -6 or -16, 0, -2)
        )
        tip.Rotation = side == 0 and -16 or 16
        Instance.new("UICorner", tip).CornerRadius = UDim.new(0, 3)
    end
    local ridge = createPlainFrame("Ridge", roof, Theme.RoofEdge, UDim2.new(0.56, 0, 0, 7), UDim2.new(0.22, 0, 0, -6))
    Instance.new("UICorner", ridge).CornerRadius = UDim.new(0, 3)
    local crest = createPlainFrame("Crest", roof, Theme.FrameDark, UDim2.fromOffset(22, 22), UDim2.new(0.5, -11, 0, 1))
    crest.Rotation = 45
    crest.ZIndex = 2
    local crestRim = Instance.new("UIStroke")
    crestRim.Color = Theme.Gold
    crestRim.Thickness = 2
    crestRim.Parent = crest
    local sun = createPlainFrame("Sun", crest, Theme.Gold, UDim2.fromOffset(10, 10), UDim2.fromOffset(6, 6))
    sun.ZIndex = 3
    Instance.new("UICorner", sun).CornerRadius = UDim.new(1, 0)

    local screen = Instance.new("Frame")
    screen.Name = "Screen"
    screen.Position = UDim2.fromOffset(8, 16)
    screen.Size = UDim2.new(1, -16, 1, -24)
    screen.BackgroundColor3 = Theme.Screen
    screen.BorderSizePixel = 0
    screen.ClipsDescendants = true
    screen.Parent = shell
    Instance.new("UICorner", screen).CornerRadius = UDim.new(0, 7)
    local trim = Instance.new("UIStroke")
    trim.Color = Theme.Trim
    trim.Thickness = 2
    trim.Transparency = 0.15
    trim.Parent = screen

    local panel = { gui = gui, shell = shell, screen = screen, model = model, conns = {} }
    expanded = panel
    buildExpandedView(panel)
    gui.Parent = player:WaitForChild("PlayerGui")
    UISound.Play("Open")

    TweenService:Create(dimmer, TweenInfo.new(0.16), { BackgroundTransparency = 0.45 }):Play()
    TweenService:Create(openScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
        :Play()

    table.insert(
        panel.conns,
        dimmer.Activated:Connect(function(input)
            if isClickOnPanel(dimmer, input) then
                return
            end
            Client.Close()
        end)
    )
    local camera = workspace.CurrentCamera
    if camera then
        table.insert(
            panel.conns,
            camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
                if expanded == panel then
                    buildExpandedView(panel)
                end
            end)
        )
    end

    local board = model and boards[model]
    if board and board.prompt then
        board.prompt.Enabled = false
    end

    ContextActionService:BindActionAtPriority(
        "LeaderboardClose",
        sinkAction(Client.Close),
        false,
        3000,
        Enum.KeyCode.ButtonB
    )
    ContextActionService:BindActionAtPriority(
        "LeaderboardPrevTab",
        sinkAction(function()
            cycleTab(-1)
        end),
        false,
        3000,
        Enum.KeyCode.ButtonL1
    )
    ContextActionService:BindActionAtPriority(
        "LeaderboardNextTab",
        sinkAction(function()
            cycleTab(1)
        end),
        false,
        3000,
        Enum.KeyCode.ButtonR1
    )
    ContextActionService:BindActionAtPriority(
        "LeaderboardScope",
        sinkAction(function()
            setScope(state.scope == "Server" and "Global" or "Server")
        end),
        false,
        3000,
        Enum.KeyCode.ButtonY
    )

    if usingGamepad() then
        GuiService.SelectedObject = panel.view:DefaultSelection()
    end
    refreshIfStale()
end

function Client.Close()
    local panel = expanded
    if not panel then
        return
    end
    expanded = nil
    UISound.Play("Close")
    for _, conn in panel.conns do
        conn:Disconnect()
    end
    for _, action in { "LeaderboardClose", "LeaderboardPrevTab", "LeaderboardNextTab", "LeaderboardScope" } do
        ContextActionService:UnbindAction(action)
    end
    local selected = GuiService.SelectedObject
    if selected and selected:IsDescendantOf(panel.gui) then
        GuiService.SelectedObject = nil
    end
    local board = panel.model and boards[panel.model]
    if board and board.prompt then
        board.prompt.Enabled = true
    end
    local fade = TweenService:Create(panel.gui.Dim, TweenInfo.new(0.12), { BackgroundTransparency = 1 })
    fade.Completed:Once(function()
        if panel.view then
            panel.view:Destroy()
        end
        panel.gui:Destroy()
    end)
    panel.shell.Visible = false
    fade:Play()
end

function Client.IsOpen()
    return expanded ~= nil
end

-- ===== 4. In-world boards =====
local function attach(model)
    if boards[model] or not model:IsA("Model") then
        return
    end
    local entry = {}
    boards[model] = entry
    task.spawn(function()
        local screen = model:WaitForChild("Screen", 10)
        if not screen or boards[model] ~= entry then
            return
        end
        entry.screen = screen
        local placeholder = screen:FindFirstChild("Placeholder")
        if placeholder then
            placeholder.Enabled = false
        end -- local only; the server copy stays for Studio

        local gui = Instance.new("SurfaceGui")
        gui.Name = "LeaderboardBoard"
        gui.Adornee = screen
        gui.Face = Enum.NormalId.Front
        gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        gui.PixelsPerStud = ClientConfig.PixelsPerStud
        gui.LightInfluence = 0
        gui.MaxDistance = 160
        gui.Active = true
        gui.ResetOnSpawn = false
        gui.ClipsDescendants = true
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        entry.gui = gui
        entry.view = View.new(gui, "Board", callbacks)
        -- render the board at 2x resolution (crisp text), laid out at its original 50 px/stud size
        do
            local root = gui:FindFirstChild("Leaderboard")
            if root then
                root.Size = UDim2.fromScale(50 / ClientConfig.PixelsPerStud, 50 / ClientConfig.PixelsPerStud)
                local pixelScale = Instance.new("UIScale")
                pixelScale.Scale = ClientConfig.PixelsPerStud / 50
                pixelScale.Parent = root
            end
        end
        entry.view:Render(renderState())
        gui.Parent = player:WaitForChild("PlayerGui")

        local prompt = model:FindFirstChild("OpenLeaderboard", true)
        if prompt and prompt:IsA("ProximityPrompt") then
            entry.prompt = prompt
            entry.conn = prompt.Triggered:Connect(function(triggeringPlayer)
                if triggeringPlayer == player then
                    Client.Open(model)
                end
            end)
        end
    end)
end

local function detach(model)
    local entry = boards[model]
    if not entry then
        return
    end
    boards[model] = nil
    if expanded and expanded.model == model then
        Client.Close()
    end
    if entry.conn then
        entry.conn:Disconnect()
    end
    if entry.view then
        entry.view:Destroy()
    end
    if entry.gui then
        entry.gui:Destroy()
    end
end

-- ===== 5. Start =====
function Client.Start()
    if started then
        return
    end
    started = true
    callbacks = { onTab = setTab, onScope = setScope, onClose = Client.Close }

    for _, model in CollectionService:GetTagged(Config.Tag) do
        attach(model)
    end
    CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(attach)
    CollectionService:GetInstanceRemovedSignal(Config.Tag):Connect(detach) -- destroyed or streamed out

    task.spawn(function()
        snapshotRemote = Shared:WaitForChild(Config.RemoteName)
        refreshIfStale()
    end)

    -- one slow loop: poll when in view, keep "Updated 12s ago" honest, close the big view when you walk off
    task.spawn(function()
        while true do
            task.wait(1)
            if isActive() then
                refreshIfStale()
            end
            forEachView(function(view)
                view:Tick()
            end)
            local panel = expanded
            if panel and panel.model then
                local board = boards[panel.model]
                local characterPosition = rootPosition()
                if
                    board
                    and board.screen
                    and characterPosition
                    and (board.screen.Position - characterPosition).Magnitude > ClientConfig.CloseDistance
                then
                    Client.Close()
                end
            end
        end
    end)
end

return Client
