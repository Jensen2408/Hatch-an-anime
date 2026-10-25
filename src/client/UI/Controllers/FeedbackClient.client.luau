--[[ StarterPlayerScripts.FeedbackClient (LocalScript)
Top-right HUD + feedback window. Builds the "FeedbackUI" ScreenGui in PlayerGui:
  TopRightHUD      ReplicatedStorage.TopRightHUD component: Backpack counter + FeedbackButton (opens the window)
  dimmer (TextButton, full screen) > Window: Figma "05 Feedback" drawn by ReplicatedStorage.FeedbackMenu
  (FeedbackComponent / FeedbackConfig): header + Close, BUG / IDEA / OTHER tabs, text box, counter, SEND, note
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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UISound = require(ReplicatedStorage:WaitForChild("UISound"))
local StudUI = require(ReplicatedStorage:WaitForChild("StudKit"):WaitForChild("StudUI"))
local FeedbackComponent = require(ReplicatedStorage:WaitForChild("FeedbackMenu"):WaitForChild("FeedbackComponent"))
local sendFeedbackRemote = ReplicatedStorage:WaitForChild("SendFeedback")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
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
-- ===== 4. Window (Figma "05 Feedback", drawn by ReplicatedStorage.FeedbackMenu.FeedbackComponent) =====
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
    Name = "Window",
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    ZIndex = 6,
    Active = true,
}, dimmer)
local windowScale = create("UIScale", {}, window)
local function refitWindow()
    StudUI.fitPanel(window, gui.AbsoluteSize)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refitWindow)
refitWindow()

-- ===== 5. Open / close and sending =====
local feedbackView
local function setWindowOpen(isOpen)
    if dimmer.Visible ~= isOpen then
        UISound.Play(isOpen and "Open" or "Close")
    end
    dimmer.Visible = isOpen
    if isOpen then
        feedbackView:Reset()
        windowScale.Scale = 0.85
        TweenService:Create(windowScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
    end
end
feedbackView = FeedbackComponent.new(window, {
    onClose = function()
        setWindowOpen(false)
    end,
    -- ok = the invoke itself did not error; success / message come from FeedbackService.
    -- The invoke runs in its own thread so a server that never answers can't lock SEND forever.
    onSend = function(kind, message)
        local result
        task.spawn(function()
            result = table.pack(pcall(sendFeedbackRemote.InvokeServer, sendFeedbackRemote, kind, message))
        end)
        local startedAt = os.clock()
        while not result and os.clock() - startedAt < SEND_TIMEOUT_SECONDS do
            task.wait(0.1)
        end
        if not result then
            return false, "Couldn't send. Try again later."
        end
        local ok, success, reply = result[1], result[2], result[3]
        if ok and success then
            task.delay(1.5, function()
                setWindowOpen(false)
            end)
            return true, reply
        end
        return false, ok and tostring(reply) or "Couldn't send. Try again."
    end,
})
openButton.Activated:Connect(function()
    setWindowOpen(true)
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
