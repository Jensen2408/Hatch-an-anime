local function __clickOnPanel(dimObj, input)
    -- true if the click landed on any visible part of a panel (anything in this ScreenGui that isn't the dim)
    if not (input and input.Position) then
        return false
    end
    local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local root = dimObj:FindFirstAncestorWhichIsA("LayerCollector")
    for _, o in pg:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y) do
        if o ~= dimObj and root and o:IsDescendantOf(root) and not o:IsDescendantOf(dimObj) then
            return true
        end
    end
    return false
end
--[[ ReplicatedStorage.Leaderboard.LeaderboardClient  (ModuleScript, started by StarterPlayerScripts.LeaderboardClientStart)
One controller for every board in the map and the expanded screen:
  • holds the shared state (tab, scope) and a cache of server snapshots per tab + scope
  • puts an Active SurfaceGui on each tagged board's Screen part (in PlayerGui, so input works)
  • opens the larger ScreenGui from the board's "Open leaderboard" ProximityPrompt
  • polls the server only while a board is near the camera or the expanded view is open
]]
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

local C = Config.Client
local T = Config.Theme
local player = Players.LocalPlayer

local Client = {}

local state = { tab = Config.Stats[1].Id, scope = "Server" }
local cache = {} -- ["Cash|Server"] = { snapshot, fetchedAt, failed }
local inflight = {}
local boards = {} -- [Model] = { screen, gui, view, prompt, conn }
local expanded = nil -- { gui, shell, view, model, conns }
local remote = nil
local started = false
local callbacks

local function currentKey()
    return state.tab .. "|" .. state.scope
end

local function renderState()
    local c = cache[currentKey()]
    local phase = "ready"
    if not (c and c.snapshot) then
        phase = (c and c.failed) and "error" or "loading"
    end
    return {
        tab = state.tab,
        scope = state.scope,
        snapshot = c and c.snapshot,
        phase = phase,
        localUserId = player.UserId,
        localName = player.Name,
        localDisplayName = player.DisplayName,
    }
end

local function eachView(fn)
    for _, board in boards do
        if board.view then
            fn(board.view)
        end
    end
    if expanded and expanded.view then
        fn(expanded.view)
    end
end

local function render()
    local s = renderState()
    eachView(function(view)
        view:Render(s)
    end)
end

---------------------------------------------------------------- data
local function fetch(tab, scope)
    local key = tab .. "|" .. scope
    if inflight[key] or not remote then
        return
    end
    inflight[key] = true
    task.spawn(function()
        local ok, result = pcall(remote.InvokeServer, remote, tab, scope)
        inflight[key] = nil
        local c = cache[key] or {}
        cache[key] = c
        c.fetchedAt = os.clock()
        if ok and type(result) == "table" and result.status ~= "busy" then
            c.snapshot = result
            c.failed = false
        else
            c.failed = true -- keep showing the last good snapshot, if any
        end
        if key == currentKey() then
            render()
        end
    end)
end

local function refreshIfStale()
    local c = cache[currentKey()]
    local interval = state.scope == "Global" and C.PollGlobal or C.PollServer
    if c and c.failed then
        interval = C.RetryAfterError
    end
    if c and c.snapshot and c.snapshot.status == "loading" then
        interval = 2
    end
    if not c or os.clock() - (c.fetchedAt or 0) >= interval then
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

local function isActive()
    if expanded then
        return true
    end
    local camera = workspace.CurrentCamera
    local from = camera and camera.CFrame.Position
    if not from then
        return false
    end
    for _, board in boards do
        if board.screen and board.screen.Parent and (board.screen.Position - from).Magnitude <= C.ActiveDistance then
            return true
        end
    end
    return false
end

---------------------------------------------------------------- expanded screen
local ROOF = 24 -- px of tile roof above the shell

local function panelLayout()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local inset = GuiService:GetGuiInset()
    local width = math.floor(math.min(C.PanelMaxWidth, viewport.X - 24))
    local height = math.floor(math.min(C.PanelMaxHeight, viewport.Y - inset.Y - 20))
    local compact = height < C.CompactBelowHeight or width < C.CompactBelowWidth
    local center = Vector2.new(viewport.X / 2, inset.Y + (viewport.Y - inset.Y) / 2)
    if compact and viewport.X - 2 * C.CompactCornerReserve >= C.CompactBelowWidth then
        -- landscape phones: take the full height and keep clear of the corner buttons instead of the top bar
        width = math.floor(math.min(C.PanelMaxWidth, viewport.X - 2 * C.CompactCornerReserve))
        height = math.floor(math.min(C.PanelMaxHeight, viewport.Y - 16))
        center = viewport / 2
    end
    -- leave room for the tile roof that sits on top of the shell
    height -= ROOF
    center += Vector2.new(0, ROOF / 2)
    return width, height, center, compact
end

local function usingGamepad()
    local last = UserInputService:GetLastInputType()
    return last.Name:sub(1, 7) == "Gamepad"
end

local function sink(fn)
    return function(_, inputState)
        if inputState == Enum.UserInputState.Begin then
            fn()
        end
        return Enum.ContextActionResult.Sink
    end
end

local function buildExpandedView(e)
    local width, height, center, compact = panelLayout()
    e.shell.Size = UDim2.fromOffset(width, height)
    e.shell.Position = UDim2.fromOffset(center.X, center.Y)
    if e.view and e.compact == compact then
        return
    end
    if e.view then
        e.view:Destroy()
    end
    e.compact = compact
    e.view = View.new(e.screen, compact and "Compact" or "Screen", callbacks)
    e.view:Render(renderState())
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

    local dim = Instance.new("TextButton")
    dim.Name = "Dim"
    dim:SetAttribute("UISoundMuted", true)
    dim.Size = UDim2.fromScale(1, 1)
    dim.BackgroundColor3 = Color3.new(0, 0, 0)
    dim.BackgroundTransparency = 1
    dim.Text = ""
    dim.AutoButtonColor = false
    dim.Selectable = false
    dim.Parent = gui

    -- the shell mirrors the shrine board: wood frame under a tile roof with upturned eaves and a gold
    -- crest, a gold top bevel, gold studs, and a gold-trimmed screen
    local shell = Instance.new("Frame")
    shell.Name = "Shell"
    shell.AnchorPoint = Vector2.new(0.5, 0.5)
    shell.BackgroundColor3 = T.Frame
    shell.BorderSizePixel = 0
    shell.Active = true
    shell.Parent = gui
    Instance.new("UICorner", shell).CornerRadius = UDim.new(0, 12)
    local scale = Instance.new("UIScale")
    scale.Scale = 0.96
    scale.Parent = shell
    local bevel = Instance.new("Frame")
    bevel.Name = "Bevel"
    bevel.Position = UDim2.fromOffset(12, 2)
    bevel.Size = UDim2.new(1, -24, 0, 2)
    bevel.BackgroundColor3 = T.Bevel
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
        stud.BackgroundColor3 = T.Stud
        stud.BorderSizePixel = 0
        stud.Parent = studs
    end

    local function plain(name, parent, color, size, position)
        local f = Instance.new("Frame")
        f.Name = name
        f.BackgroundColor3 = color
        f.BorderSizePixel = 0
        f.Size = size
        f.Position = position
        f.Parent = parent
        return f
    end
    -- tile roof: wider than the shell, a darker eave strip, upturned tips, a ridge and a gold crest
    local roof = plain("Roof", shell, T.Roof, UDim2.new(1, 28, 0, ROOF), UDim2.fromOffset(-14, -ROOF + 2))
    roof.Active = true -- clicks on the roof do not fall through to the dim and close the view
    Instance.new("UICorner", roof).CornerRadius = UDim.new(0, 5)
    plain("Eave", roof, T.RoofEdge, UDim2.new(1, -8, 0, 4), UDim2.new(0, 4, 1, -4))
    plain("Gold", roof, T.Gold, UDim2.new(1, -40, 0, 2), UDim2.fromOffset(20, 4)).BackgroundTransparency = 0.25
    for _, side in { 0, 1 } do
        local tip =
            plain("EaveTip", roof, T.Roof, UDim2.fromOffset(22, 8), UDim2.new(side, side == 0 and -6 or -16, 0, -2))
        tip.Rotation = side == 0 and -16 or 16
        Instance.new("UICorner", tip).CornerRadius = UDim.new(0, 3)
    end
    local ridge = plain("Ridge", roof, T.RoofEdge, UDim2.new(0.56, 0, 0, 7), UDim2.new(0.22, 0, 0, -6))
    Instance.new("UICorner", ridge).CornerRadius = UDim.new(0, 3)
    local crest = plain("Crest", roof, T.FrameDark, UDim2.fromOffset(22, 22), UDim2.new(0.5, -11, 0, 1))
    crest.Rotation = 45
    crest.ZIndex = 2
    local crestRim = Instance.new("UIStroke")
    crestRim.Color = T.Gold
    crestRim.Thickness = 2
    crestRim.Parent = crest
    local sun = plain("Sun", crest, T.Gold, UDim2.fromOffset(10, 10), UDim2.fromOffset(6, 6))
    sun.ZIndex = 3
    Instance.new("UICorner", sun).CornerRadius = UDim.new(1, 0)

    local screen = Instance.new("Frame")
    screen.Name = "Screen"
    screen.Position = UDim2.fromOffset(8, 16)
    screen.Size = UDim2.new(1, -16, 1, -24)
    screen.BackgroundColor3 = T.Screen
    screen.BorderSizePixel = 0
    screen.ClipsDescendants = true
    screen.Parent = shell
    Instance.new("UICorner", screen).CornerRadius = UDim.new(0, 7)
    local trim = Instance.new("UIStroke")
    trim.Color = T.Trim
    trim.Thickness = 2
    trim.Transparency = 0.15
    trim.Parent = screen

    local e = { gui = gui, shell = shell, screen = screen, model = model, conns = {} }
    expanded = e
    buildExpandedView(e)
    gui.Parent = player:WaitForChild("PlayerGui")
    UISound.Play("Open")

    TweenService:Create(dim, TweenInfo.new(0.16), { BackgroundTransparency = 0.45 }):Play()
    TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
        :Play()

    table.insert(
        e.conns,
        dim.Activated:Connect(function(input)
            if __clickOnPanel(dim, input) then
                return
            end
            Client.Close()
        end)
    )
    local camera = workspace.CurrentCamera
    if camera then
        table.insert(
            e.conns,
            camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
                if expanded == e then
                    buildExpandedView(e)
                end
            end)
        )
    end

    local board = model and boards[model]
    if board and board.prompt then
        board.prompt.Enabled = false
    end

    ContextActionService:BindActionAtPriority("LeaderboardClose", sink(Client.Close), false, 3000, Enum.KeyCode.ButtonB)
    ContextActionService:BindActionAtPriority(
        "LeaderboardPrevTab",
        sink(function()
            cycleTab(-1)
        end),
        false,
        3000,
        Enum.KeyCode.ButtonL1
    )
    ContextActionService:BindActionAtPriority(
        "LeaderboardNextTab",
        sink(function()
            cycleTab(1)
        end),
        false,
        3000,
        Enum.KeyCode.ButtonR1
    )
    ContextActionService:BindActionAtPriority(
        "LeaderboardScope",
        sink(function()
            setScope(state.scope == "Server" and "Global" or "Server")
        end),
        false,
        3000,
        Enum.KeyCode.ButtonY
    )

    if usingGamepad() then
        GuiService.SelectedObject = e.view:DefaultSelection()
    end
    refreshIfStale()
end

function Client.Close()
    local e = expanded
    if not e then
        return
    end
    expanded = nil
    UISound.Play("Close")
    for _, conn in e.conns do
        conn:Disconnect()
    end
    for _, action in { "LeaderboardClose", "LeaderboardPrevTab", "LeaderboardNextTab", "LeaderboardScope" } do
        ContextActionService:UnbindAction(action)
    end
    local selected = GuiService.SelectedObject
    if selected and selected:IsDescendantOf(e.gui) then
        GuiService.SelectedObject = nil
    end
    local board = e.model and boards[e.model]
    if board and board.prompt then
        board.prompt.Enabled = true
    end
    local fade = TweenService:Create(e.gui.Dim, TweenInfo.new(0.12), { BackgroundTransparency = 1 })
    fade.Completed:Once(function()
        if e.view then
            e.view:Destroy()
        end
        e.gui:Destroy()
    end)
    e.shell.Visible = false
    fade:Play()
end

function Client.IsOpen()
    return expanded ~= nil
end

---------------------------------------------------------------- boards
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
        gui.PixelsPerStud = C.PixelsPerStud
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
                root.Size = UDim2.fromScale(50 / C.PixelsPerStud, 50 / C.PixelsPerStud)
                local sc = Instance.new("UIScale")
                sc.Scale = C.PixelsPerStud / 50
                sc.Parent = root
            end
        end
        entry.view:Render(renderState())
        gui.Parent = player:WaitForChild("PlayerGui")

        local prompt = model:FindFirstChild("OpenLeaderboard", true)
        if prompt and prompt:IsA("ProximityPrompt") then
            entry.prompt = prompt
            entry.conn = prompt.Triggered:Connect(function(who)
                if who == player then
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

---------------------------------------------------------------- start
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
        remote = Shared:WaitForChild(Config.RemoteName)
        refreshIfStale()
    end)

    -- one slow loop: poll when in view, keep "Updated 12s ago" honest, close the big view when you walk off
    task.spawn(function()
        while true do
            task.wait(1)
            if isActive() then
                refreshIfStale()
            end
            eachView(function(view)
                view:Tick()
            end)
            local e = expanded
            if e and e.model then
                local board = boards[e.model]
                local pos = rootPosition()
                if board and board.screen and pos and (board.screen.Position - pos).Magnitude > C.CloseDistance then
                    Client.Close()
                end
            end
        end
    end)
end

return Client
