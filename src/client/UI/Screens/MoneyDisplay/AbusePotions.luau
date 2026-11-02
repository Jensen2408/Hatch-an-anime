-- MoneyDisplay.AbusePotions  (ModuleScript, client)
-- The row of potions above the Cash UI: one potion per running admin abuse, with its multiplier and time left. Display
-- only: reads the workspace attributes AdminAbuseService writes. MoneyLogic places Root and sets Scale.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("AdminAbuseConfig"))
local CashConfig = require(script.Parent:WaitForChild("CashConfig"))

local CELL_SIZE = Vector2.new(68, 58) -- pixels before Scale
local GAP = 2
local POTION_HEIGHT = 40
local BADGE_SIZE = Vector2.new(38, 16)
local TIMER_HEIGHT = 16
local Z_INDEX = 10

local AbusePotions = {}
AbusePotions.Height = CELL_SIZE.Y

local function formatLeft(seconds)
    if seconds >= 3600 then
        return string.format("%dh%02d", seconds // 3600, seconds % 3600 // 60)
    end
    return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function newText(name, parent, layout)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.FontFace = CashConfig.Font
    label.TextScaled = true
    label.TextColor3 = CashConfig.Colors.CashAmount
    label.AnchorPoint = layout.AnchorPoint
    label.Position = layout.Position
    label.Size = layout.Size
    label.ZIndex = Z_INDEX + 2
    local outline = Instance.new("UIStroke")
    outline.Color = CashConfig.Colors.Outline
    outline.Thickness = 2
    outline.LineJoinMode = Enum.LineJoinMode.Miter
    outline.Parent = label
    label.Parent = parent
    return label
end

local function newCell(kind, order, parent)
    local cell = Instance.new("Frame")
    cell.Name = kind
    cell.BackgroundTransparency = 1
    cell.Size = UDim2.fromOffset(CELL_SIZE.X, CELL_SIZE.Y)
    cell.LayoutOrder = order
    cell.Visible = false
    local pop = Instance.new("UIScale")
    pop.Parent = cell

    local potion = Instance.new("ImageLabel")
    potion.Name = "Potion"
    potion.BackgroundTransparency = 1
    potion.Image = Config.Kinds[kind].Potion
    potion.ScaleType = Enum.ScaleType.Fit
    potion.AnchorPoint = Vector2.new(0.5, 0)
    potion.Position = UDim2.fromScale(0.5, 0)
    potion.Size = UDim2.fromOffset(CELL_SIZE.X, POTION_HEIGHT)
    potion.ZIndex = Z_INDEX
    potion.Parent = cell

    local backing = Instance.new("ImageLabel")
    backing.Name = "TimerBacking"
    backing.BackgroundTransparency = 1
    backing.Image = CashConfig.Assets.IncomePanel
    backing.ScaleType = Enum.ScaleType.Stretch
    backing.ResampleMode = Enum.ResamplerMode.Pixelated
    backing.AnchorPoint = Vector2.new(0.5, 1)
    backing.Position = UDim2.fromScale(0.5, 1)
    backing.Size = UDim2.fromOffset(CELL_SIZE.X - 2, TIMER_HEIGHT + 2)
    backing.ZIndex = Z_INDEX + 1
    backing.Parent = cell

    local multiplier = newText("Multiplier", cell, {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -2, 0, 22),
        Size = UDim2.fromOffset(BADGE_SIZE.X, BADGE_SIZE.Y),
    })
    multiplier.TextColor3 = CashConfig.Colors.IncomeText
    local timer = newText("Timer", backing, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, -10, 0, 11),
    })
    cell.Parent = parent
    return { Frame = cell, Pop = pop, Multiplier = multiplier, Timer = timer }
end

function AbusePotions.new(screenGui)
    local root = Instance.new("Frame")
    root.Name = "PotionRow"
    root.BackgroundTransparency = 1
    root.AnchorPoint = Vector2.new(0, 1)
    root.Size = UDim2.fromOffset(#Config.Order * (CELL_SIZE.X + GAP), CELL_SIZE.Y)
    local scale = Instance.new("UIScale")
    scale.Parent = root
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, GAP)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = root

    local cells = {}
    for order, kind in Config.Order do
        cells[kind] = newCell(kind, order, root)
    end

    local function update()
        local now = workspace:GetServerTimeNow()
        for kind, cell in cells do
            local value = workspace:GetAttribute("Abuse" .. kind .. "Multiplier")
            local endsAt = workspace:GetAttribute("Abuse" .. kind .. "EndsAt")
            local running = value ~= nil and endsAt ~= nil
            if running then
                cell.Multiplier.Text = "x" .. value
                cell.Timer.Text = formatLeft(math.max(0, math.ceil(endsAt - now)))
            end
            if running and not cell.Frame.Visible then
                cell.Pop.Scale = 0.4
                TweenService:Create(cell.Pop, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
            end
            cell.Frame.Visible = running
        end
    end
    for _, kind in Config.Order do
        workspace:GetAttributeChangedSignal("Abuse" .. kind .. "Multiplier"):Connect(update)
        workspace:GetAttributeChangedSignal("Abuse" .. kind .. "EndsAt"):Connect(update)
    end
    task.spawn(function()
        while true do
            update()
            task.wait(1)
        end
    end)

    root.Parent = screenGui
    return { Root = root, Scale = scale }
end

return AbusePotions
