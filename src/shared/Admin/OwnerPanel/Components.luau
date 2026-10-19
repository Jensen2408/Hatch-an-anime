--[[ ReplicatedStorage.OwnerPanel.Components  (ModuleScript)
Small UI builders for the legacy v2 owner panel (Make, Round, Border, Label, Button, Disable, Input, Stack, Card,
Grid, Format). Only the other legacy modules in this folder require it; StudPanel is self-contained.
Buttons honour the "DisabledReason" attribute (set by Disable): hover tween and Activated are suppressed.
]]
local Theme = require(script.Parent.Theme)
local TweenService = game:GetService("TweenService")
local Components = {}
-- Creates `class`, applies props, then parents it (parent last).
function Components.Make(class, props, parent)
    local instance = Instance.new(class)
    for key, value in props do
        instance[key] = value
    end
    instance.Parent = parent
    return instance
end
function Components.Round(instance, radius)
    Components.Make("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, instance)
end
function Components.Border(instance)
    Components.Make("UIStroke", { Color = Theme.Border, Thickness = 1 }, instance)
end
function Components.Label(parent, text, size, color)
    return Components.Make("TextLabel", {
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = color or Theme.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = size or 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        Size = UDim2.new(1, 0, 0, 32),
    }, parent)
end
function Components.Button(parent, text, onActivated, color)
    local button = Components.Make("TextButton", {
        Text = text,
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        TextColor3 = Theme.Text,
        BackgroundColor3 = color or Theme.Card,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 44),
    }, parent)
    Components.Round(button, 10)
    Components.Border(button)
    button.MouseEnter:Connect(function()
        if button:GetAttribute("DisabledReason") == nil then
            TweenService:Create(button, TweenInfo.new(0.15), { BackgroundColor3 = color or Theme.Border }):Play()
        end
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.15), { BackgroundColor3 = color or Theme.Card }):Play()
    end)
    if onActivated then
        button.Activated:Connect(function()
            if not button:GetAttribute("DisabledReason") then
                onActivated(button)
            end
        end)
    end
    return button
end
function Components.Disable(button, reason)
    button:SetAttribute("DisabledReason", reason)
    button.Interactable = not reason
    button.TextTransparency = reason and 0.55 or 0
    if reason then
        local reasonLabel = Components.Label(button.Parent, reason, 12, Theme.Muted)
        reasonLabel.Size = UDim2.new(1, 0, 0, 28)
    end
end
function Components.Input(parent, hint)
    local textBox = Components.Make("TextBox", {
        PlaceholderText = hint,
        Text = "",
        ClearTextOnFocus = false,
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        TextColor3 = Theme.Text,
        PlaceholderColor3 = Theme.Muted,
        BackgroundColor3 = Theme.Input,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 44),
    }, parent)
    Components.Round(textBox)
    Components.Border(textBox)
    Components.Make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, textBox)
    return textBox
end
function Components.Stack(parent, pad)
    return Components.Make(
        "UIListLayout",
        { Padding = UDim.new(0, pad or 12), SortOrder = Enum.SortOrder.LayoutOrder },
        parent
    )
end
function Components.Card(parent, title, color)
    local card = Components.Make("Frame", {
        BackgroundColor3 = color or Theme.Card,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    }, parent)
    Components.Round(card, 14)
    Components.Border(card)
    Components.Make("UIPadding", {
        PaddingTop = UDim.new(0, 16),
        PaddingBottom = UDim.new(0, 16),
        PaddingLeft = UDim.new(0, 16),
        PaddingRight = UDim.new(0, 16),
    }, card)
    Components.Stack(card, 12)
    if title then
        local titleLabel = Components.Label(card, title, 16)
        titleLabel.LayoutOrder = -100
    end
    return card
end
-- _width is unused (pre-existing parameter, kept for callers).
function Components.Grid(parent, columns, _width)
    local grid = Components.Make(
        "Frame",
        { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y },
        parent
    )
    Components.Make("UIGridLayout", {
        CellSize = UDim2.new(1 / columns, -(columns - 1) * 12 / columns, 0, 124),
        CellPadding = UDim2.fromOffset(12, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, grid)
    return grid
end
-- 1234 -> "1.23K", 1e6 -> "1M" (trailing zeros stripped); below 1000 it floors.
function Components.Format(value)
    value = tonumber(value) or 0
    for _, unit in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
        if value >= unit[1] then
            return (string.format("%.2f", value / unit[1]):gsub("0+$", ""):gsub("%.$", "")) .. unit[2]
        end
    end
    return tostring(math.floor(value))
end
return Components
