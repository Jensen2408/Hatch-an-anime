-- Feedback button (right side) + window. Sends to ReplicatedStorage.SendFeedback.
local Players = game:GetService("Players")
local TS = game:GetService("TweenService")
local UISound = require(game:GetService("ReplicatedStorage"):WaitForChild("UISound"))
local remote = game.ReplicatedStorage:WaitForChild("SendFeedback")
local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
local F = Font.new("rbxasset://fonts/families/FredokaOne.json")
local INK = Color3.fromRGB(17, 23, 26)
local STUDS = "rbxassetid://132561191216691"
local function new(c, p, par)
    local o = Instance.new(c)
    for k, v in pairs(p) do
        o[k] = v
    end
    o.Parent = par
    return o
end
local function round(o, r)
    new("UICorner", { CornerRadius = UDim.new(0, r) }, o)
end
local function ink(o, t)
    new("UIStroke", { Color = INK, Thickness = t or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function txt(par, s, size, props)
    local l = new("TextLabel", {
        BackgroundTransparency = 1,
        Text = s,
        FontFace = F,
        TextSize = size,
        TextColor3 = Color3.new(1, 1, 1),
        TextWrapped = true,
        Size = UDim2.fromScale(1, 1),
    }, par)
    new("UIStroke", { Color = INK, Thickness = size >= 20 and 2.5 or 1.6 }, l)
    if props then
        for k, v in pairs(props) do
            l[k] = v
        end
    end
    return l
end
local function btn3d(par, label, col, size, pos, anchor)
    local b = new("TextButton", {
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = col,
        Size = size,
        Position = pos,
        AnchorPoint = anchor or Vector2.new(0.5, 0.5),
    }, par)
    round(b, 10)
    ink(b, 3)
    local st = new("ImageLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = STUDS,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(22, 22),
    }, b)
    round(st, 10)
    local bv = new("Frame", {
        BackgroundColor3 = Color3.new(),
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 6),
    }, b)
    round(bv, 10)
    local gl = new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.7,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 8, 0, 4),
        Size = UDim2.new(1, -16, 0, 4),
    }, b)
    round(gl, 99)
    local l = txt(b, label, 18, { Size = UDim2.new(1, -8, 1, -6) })
    local sc = new("UIScale", {}, b)
    b.MouseEnter:Connect(function()
        TS:Create(sc, TweenInfo.new(0.08), { Scale = 1.06 }):Play()
    end)
    b.MouseLeave:Connect(function()
        TS:Create(sc, TweenInfo.new(0.08), { Scale = 1 }):Play()
    end)
    b.MouseButton1Down:Connect(function()
        TS:Create(sc, TweenInfo.new(0.05), { Scale = 0.94 }):Play()
    end)
    b.MouseButton1Up:Connect(function()
        TS:Create(sc, TweenInfo.new(0.1), { Scale = 1 }):Play()
    end)
    return b, l
end
local gui = new(
    "ScreenGui",
    { Name = "FeedbackUI", ResetOnSpawn = false, DisplayOrder = 55, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets },
    pg
)
local open, openLabel = btn3d(
    gui,
    "💬 FEEDBACK",
    Color3.fromRGB(88, 101, 242),
    UDim2.fromOffset(150, 46),
    UDim2.new(1, -12, 0.5, 90),
    Vector2.new(1, 0.5)
)
open.Name = "FeedbackButton"
local function layoutFeedbackButton()
    local view = gui.AbsoluteSize
    if view.X <= 0 or view.Y <= 0 then
        return
    end
    local compact = math.min(view.X, view.Y) < 600
    if compact then
        -- Keep the lower-right touch-control area free in either orientation.
        open.AnchorPoint = Vector2.new(1, 0)
        open.Size = UDim2.fromOffset(100, 40)
        open.Position = UDim2.new(1, -10, 0, view.X >= view.Y and 8 or 150)
        openLabel.TextSize = 14
    else
        open.AnchorPoint = Vector2.new(1, 0)
        open.Size = UDim2.fromOffset(168, 53)
        open.Position = UDim2.new(1, -12, 0, 16)
        openLabel.TextSize = 18
    end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutFeedbackButton)
layoutFeedbackButton()
-- window
local dim = new("TextButton", {
    Text = "",
    AutoButtonColor = false,
    BackgroundColor3 = Color3.new(),
    BackgroundTransparency = 0.45,
    Size = UDim2.fromScale(1, 1),
    Visible = false,
    ZIndex = 5,
}, gui)
dim:SetAttribute("UISoundMuted", true)
local win = new("Frame", {
    BackgroundColor3 = Color3.fromRGB(59, 88, 102),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(460, 400),
    ZIndex = 6,
}, dim)
round(win, 22)
ink(win, 3.5)
new("ImageLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    Image = STUDS,
    ScaleType = Enum.ScaleType.Tile,
    TileSize = UDim2.fromOffset(30, 30),
    ImageTransparency = 0.35,
    ZIndex = 6,
}, win)
local fit = new("UIScale", {}, win)
local function refit()
    local v = gui.AbsoluteSize
    fit.Scale = math.max(0.1, math.min((v.X - 24) / 460, (v.Y - 24) / 400, 1.1))
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
refit()
local head = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 62), ZIndex = 7 }, win)
round(head, 20)
new(
    "UIGradient",
    { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(120, 135, 255), Color3.fromRGB(70, 80, 220)) },
    head
)
new("ImageLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    Image = STUDS,
    ScaleType = Enum.ScaleType.Tile,
    TileSize = UDim2.fromOffset(26, 26),
    ImageTransparency = 0.1,
    ZIndex = 7,
}, head)
txt(head, "FEEDBACK", 30, { ZIndex = 8 })
new("Frame", {
    BackgroundColor3 = Color3.new(),
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, 62),
    Size = UDim2.new(1, 0, 0, 3),
    ZIndex = 7,
}, win)
local x = btn3d(win, "X", Color3.fromRGB(255, 40, 70), UDim2.fromOffset(40, 40), UDim2.new(1, -30, 0, 31))
x.ZIndex = 9
for _, d in ipairs(x:GetDescendants()) do
    if d:IsA("GuiObject") then
        d.ZIndex = 9
    end
end
txt(
    win,
    "Found a bug or have an idea? Tell the devs!",
    17,
    { Position = UDim2.fromOffset(16, 74), Size = UDim2.new(1, -32, 0, 24), ZIndex = 7 }
)
local kind = "Bug"
local kb = {}
for i, k in ipairs({
    { "Bug", "🐞 BUG", Color3.fromRGB(237, 66, 69) },
    { "Idea", "💡 IDEA", Color3.fromRGB(87, 242, 135) },
    { "Other", "💬 OTHER", Color3.fromRGB(255, 184, 40) },
}) do
    local b = btn3d(win, k[2], k[3], UDim2.new(1 / 3, -14, 0, 42), UDim2.new((i - 0.5) / 3, 0, 0, 128))
    b.ZIndex = 7
    for _, d in ipairs(b:GetDescendants()) do
        if d:IsA("GuiObject") then
            d.ZIndex = 7
        end
    end
    kb[k[1]] = b
    b.Activated:Connect(function()
        kind = k[1]
        for n, bb in pairs(kb) do
            bb:FindFirstChildOfClass("UIStroke").Color = n == kind and Color3.new(1, 1, 1) or INK
        end
    end)
end
kb.Bug:FindFirstChildOfClass("UIStroke").Color = Color3.new(1, 1, 1)
local box = new("TextBox", {
    BackgroundColor3 = Color3.fromRGB(26, 44, 52),
    Text = "",
    PlaceholderText = "Write here (max 500 letters)…",
    PlaceholderColor3 = Color3.fromRGB(150, 170, 180),
    TextColor3 = Color3.new(1, 1, 1),
    FontFace = F,
    TextSize = 18,
    TextWrapped = true,
    MultiLine = true,
    ClearTextOnFocus = false,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    Position = UDim2.fromOffset(16, 160),
    Size = UDim2.new(1, -32, 0, 150),
    ZIndex = 7,
}, win)
round(box, 12)
ink(box, 2.5)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8) }, box)
box:GetPropertyChangedSignal("Text"):Connect(function()
    if #box.Text > 500 then
        box.Text = box.Text:sub(1, 500)
    end
end)
local send, sendL =
    btn3d(win, "SEND", Color3.fromRGB(92, 192, 70), UDim2.fromOffset(200, 52), UDim2.new(0.5, 0, 1, -40))
send.ZIndex = 7
for _, d in ipairs(send:GetDescendants()) do
    if d:IsA("GuiObject") then
        d.ZIndex = 7
    end
end
local status = txt(win, "", 15, { Position = UDim2.new(0, 16, 1, -96), Size = UDim2.new(1, -32, 0, 20), ZIndex = 7 })
local function show(on)
    if dim.Visible ~= on then
        UISound.Play(on and "Open" or "Close")
    end
    dim.Visible = on
    if on then
        status.Text = ""
        fit.Scale = fit.Scale * 0.9
        refit()
    end
end
open.Activated:Connect(function()
    show(true)
end)
x.Activated:Connect(function()
    show(false)
end)
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
dim.Activated:Connect(function(input)
    if __clickOnPanel(dim, input) then
        return
    end
    show(false)
end)
win.Active = true
local busy = false
send.Activated:Connect(function()
    if busy then
        return
    end
    busy = true
    sendL.Text = "..."
    local ok, res, msg = pcall(remote.InvokeServer, remote, kind, box.Text)
    busy = false
    sendL.Text = "SEND"
    if ok and res then
        box.Text = ""
        status.Text = msg
        task.delay(1.5, function()
            show(false)
        end)
    else
        status.Text = ok and tostring(msg) or "Couldn't send. Try again."
    end
end)
