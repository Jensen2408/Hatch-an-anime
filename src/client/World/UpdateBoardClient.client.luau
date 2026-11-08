--[[ StarterPlayerScripts.UpdateBoardClient  (LocalScript)
The little signs beside every plot (Workspace.UpdateSigns, screens tagged "UpdateSignScreen") show only the NEXT
item in ReplicatedStorage.UpcomingConfig: its picture, "NEXT UPDATE" and the time left. When that time passes,
the next item takes over.
Tapping a screen opens Roblox's "Join Event / Notify Me" popup for the item's EventId (live game only).
A small JOIN GROUP button sits top right on the HUD for players not in the group yet.
Each SurfaceGui lives in PlayerGui with Adornee = a sign's Screen part, so the screen can be tapped.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local SocialService = game:GetService("SocialService")
local GroupService = game:GetService("GroupService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("UpcomingConfig"))
local HudScale = require(ReplicatedStorage:WaitForChild("HudScale"))

local GROUP_ID = Config.GroupId or 251149752
local TAG = "UpdateSignScreen"
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")

local function now()
    return workspace:GetServerTimeNow()
end

local function make(className, props, parent)
    local inst = Instance.new(className)
    for k, v in props do
        inst[k] = v
    end
    inst.Parent = parent
    return inst
end

local function text(parent, str, size, y)
    local l = make("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        FontFace = FONT,
        Text = str,
        TextSize = size,
        TextColor3 = Color3.new(1, 1, 1),
        Position = UDim2.fromScale(0.5, y),
        Size = UDim2.new(1, -40, 0, size + 10),
        ZIndex = 3,
    }, parent)
    make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = size // 10 }, l)
    return l
end

-- the next item that hasn't happened yet
local function nextItem()
    local best
    for _, item in ipairs(Config.Items) do
        if item.Time > now() and (not best or item.Time < best.Time) then
            best = item
        end
    end
    return best
end

local function timeLeft(item)
    local left = math.max(0, math.floor(item.Time - now()))
    local d, h, m, s = left // 86400, (left // 3600) % 24, (left // 60) % 60, left % 60
    if d > 0 then
        return string.format("%dd %dh %dm", d, h, m)
    end
    return string.format("%dh %dm %ds", h, m, s)
end

local current
local busy = false
local function promptNotify()
    if busy or not (current and current.EventId) then
        return
    end
    busy = true
    local ok, err = pcall(function()
        SocialService:PromptRsvpToEventAsync(current.EventId)
    end)
    if not ok then
        warn("[UpdateSign] Notify popup only works in the live game:", err)
    end
    busy = false
end

-- ===== One SurfaceGui per sign screen =====
local screens = {} -- [Screen part] = { gui, picture, countdown }
local function drawScreen(s)
    s.picture.Image = current and (current.BoardImage or current.Image) or ""
    s.countdown.Text = current and timeLeft(current) or "SOON!"
end

local function attach(screenPart)
    if screens[screenPart] or not screenPart:IsA("BasePart") then
        return
    end
    local gui = make("SurfaceGui", {
        Name = "UpdateSignScreen",
        Adornee = screenPart,
        Face = Enum.NormalId.Front,
        SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
        PixelsPerStud = 980 / screenPart.Size.X,
        LightInfluence = 0,
        MaxDistance = 150,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, playerGui)
    local root = make("TextButton", { -- the whole screen is the tap area
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = Color3.fromRGB(10, 10, 16),
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ClipsDescendants = true,
    }, gui)
    local picture = make("ImageLabel", {
        BackgroundTransparency = 1,
        ScaleType = Enum.ScaleType.Crop,
        Size = UDim2.fromScale(1, 1),
    }, root)
    local band = make("Frame", { -- soft dark band behind the text only, the picture stays bright
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromScale(1, 0.8),
        ZIndex = 2,
    }, root)
    make("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.3, 0.6),
            NumberSequenceKeypoint.new(0.7, 0.6),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, band)
    text(root, "NEXT UPDATE", 165, 0.34)
    local countdown = text(root, "", 150, 0.68)
    root.Activated:Connect(function()
        task.spawn(promptNotify)
    end)
    local s = { gui = gui, picture = picture, countdown = countdown }
    screens[screenPart] = s
    drawScreen(s)
end

local function detach(screenPart)
    local s = screens[screenPart]
    if s then
        s.gui:Destroy()
        screens[screenPart] = nil
    end
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(attach)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(detach)
for _, part in CollectionService:GetTagged(TAG) do
    attach(part)
end

-- ===== Small JOIN GROUP button on the HUD (top right, hidden once in the group) =====
local hud = make("ScreenGui", {
    Name = "CommunityButton",
    ResetOnSpawn = false,
    ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 5,
}, playerGui)
local holder = make("Frame", {
    AnchorPoint = Vector2.new(1, 0),
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -14, 0, 92),
    Size = UDim2.fromOffset(176, 52),
    Visible = false,
}, hud)
local scale = make("UIScale", {}, holder)
local joinButton = make("TextButton", {
    Text = "",
    AutoButtonColor = false,
    BackgroundColor3 = Color3.fromRGB(60, 205, 80),
    BorderSizePixel = 0,
    Size = UDim2.fromScale(1, 1),
}, holder)
make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Miter }, joinButton)
local icon = make("ImageLabel", {
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
    Image = "rbxthumb://type=GroupIcon&id=" .. GROUP_ID .. "&w=150&h=150",
    Position = UDim2.fromOffset(8, 8),
    Size = UDim2.fromOffset(36, 36),
}, joinButton)
make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2 }, icon)
local joinLabel = make("TextLabel", {
    BackgroundTransparency = 1,
    FontFace = FONT,
    Text = "JOIN GROUP",
    TextSize = 21,
    TextColor3 = Color3.new(1, 1, 1),
    Position = UDim2.fromOffset(48, 0),
    Size = UDim2.new(1, -52, 1, 0),
}, joinButton)
make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2 }, joinLabel)

local function fit()
    scale.Scale = HudScale.For(hud.AbsoluteSize)
end
hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

local function checkGroup()
    local ok, inGroup = pcall(function()
        return player:IsInGroupAsync(GROUP_ID)
    end)
    if not ok then
        ok, inGroup = pcall(player.IsInGroup, player, GROUP_ID)
    end
    holder.Visible = not (ok and inGroup)
end
task.spawn(checkGroup)
local joining = false
joinButton.Activated:Connect(function()
    if joining then
        return
    end
    joining = true
    pcall(function()
        GroupService:PromptJoinAsync(GROUP_ID)
    end)
    checkGroup()
    joining = false
end)

-- ===== Loop: countdown every second; the next item takes over when one is out =====
while true do
    current = nextItem()
    for _, s in screens do
        drawScreen(s)
    end
    task.wait(1)
end
