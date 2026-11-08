-- ReplicatedStorage.StudKit.StudToast  (ModuleScript, client)
-- Game messages ("Go to your plot to unlock", "Not enough money" ...) in the Folk Stud look (2026-11-07): a candy slab
-- per message (coral = error, leaf = success, azure = info) with a black outline, faint studs, a light sweep and a hard
-- shadow, a FOLK icon breaking out over its left end, and the words in Fredoka with a black outline. Stacked
-- bottom-centre, newest at the bottom; at most StudTheme.Toast.Max stay on screen. Same API as before:
--
--   local toasts = StudToast.new(screenGui)
--   toasts:Show("Not enough money", "error")   -- kind: "info" (default) | "success" | "error"
-- Old version: ServerStorage._ARCHIVE.StudToast_BeforeFolk_2026-11-07
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Kit = script.Parent
local Theme = require(Kit:WaitForChild("StudTheme"))
local M = require(ReplicatedStorage:WaitForChild("FolkStudUI"))
local H = M.H

local Style = Theme.Toast
local W, TH = Style.Size.X, Style.Size.Y   -- 600 x 82

-- FOLK Icon Pack, 256 px (assets\ui\stud\up\i_warn / i_check / i_info)
local KINDS = {
    info = { pal = M.COLOR.azure, icon = "rbxassetid://129678499568475" },
    success = { pal = M.COLOR.leaf, icon = "rbxassetid://128694588334272" },
    error = { pal = M.COLOR.coral, icon = "rbxassetid://93462464183428" },
}

local StudToast = {}
StudToast.__index = StudToast

-- SharpUI squares corners and mitres strokes on anything without NoSkin; every piece opts out before it is parented
local function optOut(root)
    root:SetAttribute("NoSkin", true)
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("GuiObject") then d:SetAttribute("NoSkin", true) end
    end
end

function StudToast.new(screenGui)
    local self = setmetatable({ gui = screenGui, order = 0, live = {} }, StudToast)
    local holder = Instance.new("Frame")
    holder.Name = "Toasts"
    holder.BackgroundTransparency = 1
    holder.AnchorPoint = Vector2.new(0.5, 1)
    holder.Position = UDim2.new(0.5, 0, 1, -Style.BottomOffset)
    holder.Size = UDim2.fromOffset(W + 40, (TH + Style.Gap) * Style.Max)
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
    M.animate(holder, { sounds = false })   -- floats, wiggles and light sweeps on every toast
    self.holder = holder
    return self
end

function StudToast:_remove(toast)
    local index = table.find(self.live, toast)
    if not index then
        return
    end
    table.remove(self.live, index)
    local shrink = TweenService:Create(toast:FindFirstChildOfClass("UIScale"), TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
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
    local Z = Style.ZIndex
    self.order += 1

    -- the layout slot; the slab, shadow and icon sit inside it
    local toast = H.new("Frame", { Name = "Toast", BackgroundTransparency = 1, Size = UDim2.fromOffset(W, TH), LayoutOrder = self.order, ZIndex = Z }, nil)
    H.shadow(toast, "Slab", 0, 0, W, TH, 16, Z)
    local slab = H.rect(toast, "Slab", 0, 0, W, TH, 16, Z + 1, H.WHITE)
    H.grad(slab, style.pal[1], style.pal[2])
    H.ink(slab, 4)
    H.studs(slab, Vector2.new(48, 48), 0.74, 16, Z + 1)
    H.shine(slab, 16, Z + 2)

    -- the icon breaks out over the left end
    local icon = H.sticker(toast, "Icon", style.icon, 30, TH / 2 - 2, 84, Z + 4)
    icon:SetAttribute("Wiggle", 6)

    local label = H.new("TextLabel", { Name = "Message", BackgroundTransparency = 1, FontFace = M.FONT, Text = message, TextColor3 = H.WHITE,
        TextScaled = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(84, 10),
        Size = UDim2.fromOffset(W - 84 - 18, TH - 24), ZIndex = Z + 5 }, toast)
    H.new("UITextSizeConstraint", { MaxTextSize = 30, MinTextSize = 14 }, label)
    H.new("UIStroke", { Name = "UIStroke", Thickness = 3.7, Color = H.BLACK, LineJoinMode = Enum.LineJoinMode.Bevel }, label)

    local pop = Instance.new("UIScale")
    pop.Scale = 0.6
    pop.Parent = toast
    optOut(toast)
    toast.Parent = self.holder
    TweenService:Create(pop, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()

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
