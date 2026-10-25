--[[ StarterPlayerScripts.FeedbackClient (LocalScript)
Feedback button (right side) + window. Builds the "FeedbackUI" ScreenGui in PlayerGui:
  FeedbackButton   opens the window (FigmaSkin hides its drawn children and lays Figma art over it)
  dimmer (TextButton, full screen) > Window: Figma "05 Feedback" drawn by ReplicatedStorage.FeedbackMenu
  (FeedbackComponent / FeedbackConfig): header + Close, BUG / IDEA / OTHER tabs, text box, counter, SEND, note
Remote: ReplicatedStorage.SendFeedback (RemoteFunction, server: FeedbackService)
  InvokeServer(kind, text) -> ok, message. The server re-validates, trims to 500 characters, filters the text and
  enforces the cooldown; the 500-character limit here is only for the player's benefit.
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
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local INK = Color3.fromRGB(17, 23, 26)
local STUDS = "rbxassetid://132561191216691"

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

-- ===== 3. Feedback button =====
local gui = create(
    "ScreenGui",
    { Name = "FeedbackUI", ResetOnSpawn = false, DisplayOrder = 55, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets },
    playerGui
)
local openButton, openLabel = createButton3D(
    gui,
    "💬 FEEDBACK",
    Color3.fromRGB(88, 101, 242),
    UDim2.fromOffset(150, 46),
    UDim2.new(1, -12, 0.5, 90),
    Vector2.new(1, 0.5)
)
openButton.Name = "FeedbackButton"
local function layoutFeedbackButton()
    local view = gui.AbsoluteSize
    if view.X <= 0 or view.Y <= 0 then
        return
    end
    local compact = math.min(view.X, view.Y) < 600
    if compact then
        -- Keep the lower-right touch-control area free in either orientation.
        openButton.AnchorPoint = Vector2.new(1, 0)
        openButton.Size = UDim2.fromOffset(100, 40)
        openButton.Position = UDim2.new(1, -10, 0, view.X >= view.Y and 8 or 150)
        openLabel.TextSize = 14
    else
        openButton.AnchorPoint = Vector2.new(1, 0)
        openButton.Size = UDim2.fromOffset(168, 53)
        openButton.Position = UDim2.new(1, -12, 0, 16)
        openLabel.TextSize = 18
    end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutFeedbackButton)
layoutFeedbackButton()
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
    -- ok = the invoke itself did not error; success / message come from FeedbackService
    onSend = function(kind, message)
        local ok, success, reply = pcall(sendFeedbackRemote.InvokeServer, sendFeedbackRemote, kind, message)
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
