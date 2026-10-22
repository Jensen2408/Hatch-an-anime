--[[ StarterPlayerScripts.FeedbackClient (LocalScript)
Top-right HUD + feedback window. Builds the "FeedbackUI" ScreenGui in PlayerGui:
  TopRightHUD      ReplicatedStorage.TopRightHUD component: Backpack counter + FeedbackButton (opens the window)
  dimmer (TextButton, full screen) > window: header, close X, BUG / IDEA / OTHER picker, text box, SEND, status line
Remote: ReplicatedStorage.SendFeedback (RemoteFunction, server: FeedbackService)
  InvokeServer(kind, text) -> ok, message. The server re-validates, trims to 500 characters, filters the text and
  enforces the cooldown; the 500-character limit here is only for the player's benefit.
Backpack counter = "characters placed on the plot's stands / stands on the plot", from the CharacterInventory
  snapshot (InventoryRequest "Fetch" once, then every InventoryEvent "Snapshot" the server pushes on change).
Sounds: UISound "Open" / "Close" (the dimmer is UISoundMuted so its click does not play the default sound).
]]

-- ===== 1. Services, remotes, constants =====
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UISound = require(game:GetService("ReplicatedStorage"):WaitForChild("UISound"))
local sendFeedbackRemote = game.ReplicatedStorage:WaitForChild("SendFeedback")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local INK = Color3.fromRGB(17, 23, 26)
local STUDS = "rbxassetid://132561191216691"
local SEND_TIMEOUT_SECONDS = 20 -- the SEND button gives up (and can be pressed again) if the server never answers

-- ===== 2. UI primitives =====
local function create(className, props, parent)
    local instance = Instance.new(className)
    for key, value in pairs(props) do
        instance[key] = value
    end
    instance.Parent = parent
    return instance
end
local function addCorner(target, radius)
    create("UICorner", { CornerRadius = UDim.new(0, radius) }, target)
end
local function addInkStroke(target, thickness)
    create(
        "UIStroke",
        { Color = INK, Thickness = thickness or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
        target
    )
end
local function createLabel(parent, text, size, props)
    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Text = text,
        FontFace = FONT,
        TextSize = size,
        TextColor3 = Color3.new(1, 1, 1),
        TextWrapped = true,
        Size = UDim2.fromScale(1, 1),
    }, parent)
    create("UIStroke", { Color = INK, Thickness = size >= 20 and 2.5 or 1.6 }, label)
    if props then
        for key, value in pairs(props) do
            label[key] = value
        end
    end
    return label
end
local function createButton3D(parent, labelText, color, size, position, anchorPoint)
    local button = create("TextButton", {
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = color,
        Size = size,
        Position = position,
        AnchorPoint = anchorPoint or Vector2.new(0.5, 0.5),
    }, parent)
    addCorner(button, 10)
    addInkStroke(button, 3)
    local studs = create("ImageLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = STUDS,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(22, 22),
    }, button)
    addCorner(studs, 10)
    local bevel = create("Frame", {
        BackgroundColor3 = Color3.new(),
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 6),
    }, button)
    addCorner(bevel, 10)
    local gloss = create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.7,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 8, 0, 4),
        Size = UDim2.new(1, -16, 0, 4),
    }, button)
    addCorner(gloss, 99)
    local label = createLabel(button, labelText, 18, { Size = UDim2.new(1, -8, 1, -6) })
    local hoverScale = create("UIScale", {}, button)
    button.MouseEnter:Connect(function()
        TweenService:Create(hoverScale, TweenInfo.new(0.08), { Scale = 1.06 }):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(hoverScale, TweenInfo.new(0.08), { Scale = 1 }):Play()
    end)
    button.MouseButton1Down:Connect(function()
        TweenService:Create(hoverScale, TweenInfo.new(0.05), { Scale = 0.94 }):Play()
    end)
    button.MouseButton1Up:Connect(function()
        TweenService:Create(hoverScale, TweenInfo.new(0.1), { Scale = 1 }):Play()
    end)
    return button, label
end
-- raise a button and everything drawn inside it to the same ZIndex
local function setZIndexDeep(root, zIndex)
    root.ZIndex = zIndex
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("GuiObject") then
            descendant.ZIndex = zIndex
        end
    end
end

-- ===== 3. Top-right HUD: Backpack counter + Feedback button =====
local gui = create("ScreenGui", {
    Name = "FeedbackUI",
    ResetOnSpawn = false,
    DisplayOrder = 55,
    ScreenInsets = Enum.ScreenInsets.None, -- full screen first, so the phone check sees the real screen size
    IgnoreGuiInset = true,
}, playerGui)
local TopRightHUD = game.ReplicatedStorage:WaitForChild("TopRightHUD")
local TopRightConfig = require(TopRightHUD:WaitForChild("TopRightConfig"))
local TimeConfig = require(game.ReplicatedStorage:WaitForChild("TimeHUD"):WaitForChild("TimeConfig"))
local topRight = require(TopRightHUD:WaitForChild("TopRightComponent")).new(gui)
local openButton = topRight.FeedbackButton
-- the whole HUD is scaled as one piece and kept in the top-right corner. Anchored at its centre (like the cash
-- panel) so the UIScale shrink can't shift the visible panel away from the corner.
-- Desktop: the gui ignores the top-bar inset like GameHUD's NightBar, so the counter frame's top edge lines up
-- with the night timer's (TimeConfig.TopMargin from the screen top; the backpack icon pokes out above it).
local function layoutTopRight()
    local compact = math.min(gui.AbsoluteSize.X, gui.AbsoluteSize.Y) < TopRightConfig.CompactBreakpoint
    gui.ScreenInsets = compact and Enum.ScreenInsets.CoreUISafeInsets or Enum.ScreenInsets.None
    local view = gui.AbsoluteSize
    if view.X <= 0 or view.Y <= 0 then
        return
    end
    local scale = compact and TopRightConfig.Scale.Compact or TopRightConfig.Scale.Desktop
    local rootSize = topRight.Root.Size
    local width, height = rootSize.X.Offset * scale, rootSize.Y.Offset * scale
    -- phones: same spots as the old button (top-right; portrait drops below the cash panel)
    local right, top = 12, 0
    if compact then
        right, top = 10, view.X >= view.Y and 8 or 150
    else
        local iconOverhang = (TopRightConfig.Boxes.CounterBackground[2] - TopRightConfig.RefBounds[2])
            * TopRightConfig.Unit
            * scale
        top = TimeConfig.TopMargin - iconOverhang
    end
    topRight.Scale.Scale = scale
    topRight.Root.AnchorPoint = Vector2.new(0.5, 0.5)
    topRight.Root.Position = UDim2.new(1, -(right + width / 2), 0, top + height / 2)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutTopRight)
layoutTopRight()

-- Backpack counter: characters placed on the plot's stands / all stands on the plot (locked ones included)
local function applySnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return
    end
    local capacity = snapshot.capacity or {}
    topRight:SetCapacity(capacity.placed or 0, capacity.total or 0)
end
task.spawn(function()
    local inventoryFolder = game.ReplicatedStorage:WaitForChild("CharacterInventory")
    inventoryFolder:WaitForChild("InventoryEvent").OnClientEvent:Connect(function(kind, payload)
        if kind == "Snapshot" then
            applySnapshot(payload)
        end
    end)
    -- the first snapshot; the server rate-limits requests ("Busy"), so retry a few times
    local inventoryRequest = inventoryFolder:WaitForChild("InventoryRequest")
    for attempt = 1, 5 do
        local ok, response = pcall(inventoryRequest.InvokeServer, inventoryRequest, "Fetch")
        if ok and type(response) == "table" and response.ok then
            applySnapshot(response.snapshot)
            return
        end
        task.wait(attempt)
    end
end)
-- ===== 4. Window =====
local dimmer = create("TextButton", {
    Text = "",
    AutoButtonColor = false,
    BackgroundColor3 = Color3.new(),
    BackgroundTransparency = 0.45,
    Size = UDim2.fromScale(1, 1),
    Visible = false,
    ZIndex = 5,
}, gui)
dimmer:SetAttribute("UISoundMuted", true)
local window = create("Frame", {
    BackgroundColor3 = Color3.fromRGB(59, 88, 102),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(460, 400),
    ZIndex = 6,
}, dimmer)
addCorner(window, 22)
addInkStroke(window, 3.5)
create("ImageLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    Image = STUDS,
    ScaleType = Enum.ScaleType.Tile,
    TileSize = UDim2.fromOffset(30, 30),
    ImageTransparency = 0.35,
    ZIndex = 6,
}, window)
local windowScale = create("UIScale", {}, window)
local function refitWindow()
    local viewport = gui.AbsoluteSize
    windowScale.Scale = math.max(0.1, math.min((viewport.X - 24) / 460, (viewport.Y - 24) / 400, 1.1))
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refitWindow)
refitWindow()
local header =
    create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 62), ZIndex = 7 }, window)
addCorner(header, 20)
create(
    "UIGradient",
    { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(120, 135, 255), Color3.fromRGB(70, 80, 220)) },
    header
)
create("ImageLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    Image = STUDS,
    ScaleType = Enum.ScaleType.Tile,
    TileSize = UDim2.fromOffset(26, 26),
    ImageTransparency = 0.1,
    ZIndex = 7,
}, header)
createLabel(header, "FEEDBACK", 30, { ZIndex = 8 })
create("Frame", {
    BackgroundColor3 = Color3.new(),
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, 62),
    Size = UDim2.new(1, 0, 0, 3),
    ZIndex = 7,
}, window)
local closeButton =
    createButton3D(window, "X", Color3.fromRGB(255, 40, 70), UDim2.fromOffset(40, 40), UDim2.new(1, -30, 0, 31))
setZIndexDeep(closeButton, 9)
createLabel(
    window,
    "Found a bug or have an idea? Tell the devs!",
    17,
    { Position = UDim2.fromOffset(16, 74), Size = UDim2.new(1, -32, 0, 24), ZIndex = 7 }
)
-- ===== 5. Kind picker, text box, SEND =====
-- the selected kind's button gets a white outline, the others ink
local selectedKind = "Bug"
local kindButtons = {}
for i, kindDef in ipairs({
    { "Bug", "🐞 BUG", Color3.fromRGB(237, 66, 69) },
    { "Idea", "💡 IDEA", Color3.fromRGB(87, 242, 135) },
    { "Other", "💬 OTHER", Color3.fromRGB(255, 184, 40) },
}) do
    local button = createButton3D(
        window,
        kindDef[2],
        kindDef[3],
        UDim2.new(1 / 3, -14, 0, 42),
        UDim2.new((i - 0.5) / 3, 0, 0, 128)
    )
    setZIndexDeep(button, 7)
    kindButtons[kindDef[1]] = button
    button.Activated:Connect(function()
        selectedKind = kindDef[1]
        for kindName, kindButton in pairs(kindButtons) do
            kindButton:FindFirstChildOfClass("UIStroke").Color = kindName == selectedKind and Color3.new(1, 1, 1) or INK
        end
    end)
end
kindButtons.Bug:FindFirstChildOfClass("UIStroke").Color = Color3.new(1, 1, 1)
local textBox = create("TextBox", {
    BackgroundColor3 = Color3.fromRGB(26, 44, 52),
    Text = "",
    PlaceholderText = "Write here (max 500 letters)…",
    PlaceholderColor3 = Color3.fromRGB(150, 170, 180),
    TextColor3 = Color3.new(1, 1, 1),
    FontFace = FONT,
    TextSize = 18,
    TextWrapped = true,
    MultiLine = true,
    ClearTextOnFocus = false,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    Position = UDim2.fromOffset(16, 160),
    Size = UDim2.new(1, -32, 0, 150),
    ZIndex = 7,
}, window)
addCorner(textBox, 12)
addInkStroke(textBox, 2.5)
create(
    "UIPadding",
    { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8) },
    textBox
)
textBox:GetPropertyChangedSignal("Text"):Connect(function()
    if #textBox.Text > 500 then
        textBox.Text = textBox.Text:sub(1, 500)
    end
end)
local sendButton, sendLabel =
    createButton3D(window, "SEND", Color3.fromRGB(92, 192, 70), UDim2.fromOffset(200, 52), UDim2.new(0.5, 0, 1, -40))
setZIndexDeep(sendButton, 7)
local statusLabel =
    createLabel(window, "", 15, { Position = UDim2.new(0, 16, 1, -96), Size = UDim2.new(1, -32, 0, 20), ZIndex = 7 })

-- ===== 6. Open / close and sending =====
local function setWindowOpen(isOpen)
    if dimmer.Visible ~= isOpen then
        UISound.Play(isOpen and "Open" or "Close")
    end
    dimmer.Visible = isOpen
    if isOpen then
        statusLabel.Text = ""
        -- leftover: refitWindow overwrites this scale immediately, so the * 0.9 has no visible effect
        windowScale.Scale = windowScale.Scale * 0.9
        refitWindow()
    end
end
openButton.Activated:Connect(function()
    setWindowOpen(true)
end)
closeButton.Activated:Connect(function()
    setWindowOpen(false)
end)
local function __clickOnPanel(dimObj, input)
    -- true if the click landed on any visible part of a panel (anything in this ScreenGui that isn't the dim)
    if not (input and input.Position) then
        return false
    end
    local localPlayerGui = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local root = dimObj:FindFirstAncestorWhichIsA("LayerCollector")
    for _, guiObject in localPlayerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y) do
        if guiObject ~= dimObj and root and guiObject:IsDescendantOf(root) and not guiObject:IsDescendantOf(dimObj) then
            return true
        end
    end
    return false
end
dimmer.Activated:Connect(function(input)
    if __clickOnPanel(dimmer, input) then
        return
    end
    setWindowOpen(false)
end)
window.Active = true
local isSending = false
sendButton.Activated:Connect(function()
    if isSending then
        return
    end
    isSending = true
    sendLabel.Text = "..."
    statusLabel.Text = ""
    -- ok = the invoke itself did not error; success / message come from FeedbackService.
    -- The invoke runs in its own thread so a server that never answers can't lock the button forever.
    local result
    local kind, text = selectedKind, textBox.Text
    task.spawn(function()
        result = table.pack(pcall(sendFeedbackRemote.InvokeServer, sendFeedbackRemote, kind, text))
    end)
    local startedAt = os.clock()
    while not result and os.clock() - startedAt < SEND_TIMEOUT_SECONDS do
        task.wait(0.1)
    end
    isSending = false
    sendLabel.Text = "SEND"
    if not result then
        statusLabel.Text = "Couldn't send. Try again later."
        return
    end
    local ok, success, message = result[1], result[2], result[3]
    if ok and success then
        textBox.Text = ""
        statusLabel.Text = message
        task.delay(1.5, function()
            setWindowOpen(false)
        end)
    else
        statusLabel.Text = ok and tostring(message) or "Couldn't send. Try again."
    end
end)
