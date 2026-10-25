-- ReplicatedStorage.StudKit.StudToast  (ModuleScript, client)
-- Figma "10 Notifications": Toast cards (600x82) stacked bottom-center, newest at the bottom. Each toast has
-- a colored kind tile (info / success / error), the message and disappears after a few seconds; at most
-- StudTheme.Toast.Max stay on screen.
--
--   local toasts = StudToast.new(screenGui)
--   toasts:Show("Not enough money", "error")   -- kind: "info" (default) | "success" | "error"
local TweenService = game:GetService("TweenService")

local Kit = script.Parent
local Theme = require(Kit:WaitForChild("StudTheme"))
local StudUI = require(Kit:WaitForChild("StudUI"))

local Colors = Theme.Colors
local Style = Theme.Toast

local KINDS = {
    info = { Color = Colors.Blue, Glyph = "i" },
    success = { Color = Colors.Green, Glyph = "✓" },
    error = { Color = Colors.Red, Glyph = "!" },
}

local StudToast = {}
StudToast.__index = StudToast

function StudToast.new(screenGui)
    local self = setmetatable({ gui = screenGui, order = 0, live = {} }, StudToast)
    local holder = Instance.new("Frame")
    holder.Name = "Toasts"
    holder.BackgroundTransparency = 1
    holder.AnchorPoint = Vector2.new(0.5, 1)
    holder.Position = UDim2.new(0.5, 0, 1, -Style.BottomOffset)
    holder.Size = UDim2.fromOffset(Style.Size.X, (Style.Size.Y + Style.Gap) * Style.Max)
    holder.ZIndex = Style.ZIndex
    holder:SetAttribute("NoSkin", true)
    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Vertical
    list.VerticalAlignment = Enum.VerticalAlignment.Bottom
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, Style.Gap)
    list.Parent = holder
    local scale = Instance.new("UIScale")
    scale.Parent = holder
    local function fit()
        scale.Scale = math.clamp(screenGui.AbsoluteSize.Y / Style.ScreenHeight, Style.MinScale, Style.MaxScale)
    end
    fit()
    screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
    holder.Parent = screenGui
    self.holder = holder
    return self
end

function StudToast:_remove(toast)
    local index = table.find(self.live, toast)
    if not index then
        return
    end
    table.remove(self.live, index)
    local shrink = TweenService:Create(toast:FindFirstChildOfClass("UIScale"), TweenInfo.new(0.15), { Scale = 0 })
    shrink.Completed:Once(function()
        toast:Destroy()
    end)
    shrink:Play()
end

function StudToast:Show(message, kind)
    if not message or message == "" then
        return
    end
    local style = KINDS[kind or "info"] or KINDS.info
    self.order += 1
    local toast =
        StudUI.card(self.holder, "Toast", { 0, 0, Style.Size.X, Style.Size.Y }, Colors.Panel2, Style.Radius, Colors.Ink)
    toast.LayoutOrder = self.order
    local tile = StudUI.plate(toast, "Kind", Style.IconRect, style.Color, Style.IconRadius, Colors.Ink)
    StudUI.label(
        tile,
        "Glyph",
        style.Glyph,
        { 0, 0, Style.IconRect[3], Style.IconRect[4] },
        Style.GlyphSize,
        Colors.White,
        StudUI.centered({ display = true })
    )
    StudUI.label(toast, "Message", message, Style.TextRect, Style.TextSize, Colors.White, { wrap = true })
    local pop = Instance.new("UIScale")
    pop.Scale = 0.6
    pop.Parent = toast
    TweenService:Create(pop, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()

    table.insert(self.live, toast)
    while #self.live > Style.Max do
        self:_remove(self.live[1])
    end
    task.delay(Style.Duration, function()
        self:_remove(toast)
    end)
    return toast
end

return StudToast
