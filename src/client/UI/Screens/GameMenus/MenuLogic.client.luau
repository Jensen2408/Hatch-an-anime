-- StarterGui.GameMenus.MenuLogic (LocalScript)
-- Opens/closes the four ForgeGUI panels and fills them with live data from
-- ServerScriptService.GameMenu (GetState / Action / Changed remotes).
-- All positions below are fractions of each panel image, so they scale with it.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = script.Parent
local dim = gui:WaitForChild("Dim")
local side = gui:WaitForChild("SideButtons")
-- Modal panels must cover HUDs from other ScreenGuis, including Settings.
local hudDisplayOrder = gui.DisplayOrder
local function updateOverlayOrder()
    gui.DisplayOrder = dim.Visible and math.max(60, hudDisplayOrder) or hudDisplayOrder
end
dim:GetPropertyChangedSignal("Visible"):Connect(updateOverlayOrder)
updateOverlayOrder()
-- Use the safe area's height as well as width: wide phones are still short.
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
local SHOP_PHONE_WIDTH = 680
local closing -- panel playing its close tween
local sideScale = Instance.new("UIScale")
sideScale.Name = "ResponsiveScale"
sideScale.Parent = side
local function layoutMenus()
    local v = gui.AbsoluteSize
    if v.X <= 0 or v.Y <= 0 then
        return
    end
    -- The ScreenGui sits inside the safe insets (top bar / notch), so the dim backdrop must reach
    -- past them or the screen edges stay undimmed on phones.
    local cam = workspace.CurrentCamera
    if cam then
        local tl, br = game:GetService("GuiService"):GetGuiInset()
        local extra = cam.ViewportSize - v
        local left, top = math.min(tl.X, extra.X), math.min(tl.Y, extra.Y)
        local right, bottom = math.max(0, extra.X - left), math.max(0, extra.Y - top)
        dim.AnchorPoint = Vector2.new(0, 0)
        dim.Position = UDim2.fromOffset(-left, -top)
        dim.Size = UDim2.new(1, left + right, 1, top + bottom)
    end
    local compact = math.min(v.X, v.Y) < 600
    local s = compact and math.min(1, v.X / 600, v.Y / 560) or 1
    -- Phone buttons are 20% smaller; desktop keeps its original size.
    sideScale.Scale = compact and math.clamp(v.Y * 0.15, 44, 52) / 92 or s
    side.AnchorPoint = compact and Vector2.new(0, 0) or Vector2.new(0, 0.5)
    side.Position = compact and UDim2.fromOffset(10, v.X < v.Y and 82 or 48) or UDim2.new(0, 16, 0.5, 0)
    for _, name in { "Plot", "Index", "Quests", "VipShop" } do
        local panel = gui:FindFirstChild(name)
        if panel then
            local ratio = panel.UIAspectRatioConstraint.AspectRatio
            local width = math.min(1000, v.X * 0.86, (v.Y - 32) * ratio)
            -- The shop is laid out in pixels, so on phones it is built at a fixed design width
            -- and shrunk with its UIScale ("Fit") instead of squeezing the panel.
            local design = (compact and name == "VipShop") and SHOP_PHONE_WIDTH or nil
            if design then
                width = math.min(width, v.X * 0.8, (v.Y - 48) * ratio)
            end
            local fit = design and width / design or 1
            local w = design or width
            panel.Size = UDim2.fromOffset(math.max(1, w), math.max(1, w / ratio))
            panel:SetAttribute("Fit", fit)
            if panel.Visible and panel ~= closing then
                panel.UIScale.Scale = fit
            end
        end
    end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutMenus)
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutMenus)
end
layoutMenus()
local remotes = RS:WaitForChild("GameMenu"):WaitForChild("Remotes")
local GetState, Action, Changed =
    remotes:WaitForChild("GetState"), remotes:WaitForChild("Action"), remotes:WaitForChild("Changed")
local Config = require(RS.GameMenu.Config)
local UISound = require(RS:WaitForChild("UISound"))

-- ADD STUDS: put the stud pattern inside any frame.   addStuds(frame, size, strength)
--   size = stud size in pixels (smaller = smaller studs) · strength: 0 = strong, 1 = invisible
local function addStuds(frame, size, strength)
    do
        return
    end
    local im = Instance.new("ImageLabel")
    im.Name = "StudPattern"
    im.BackgroundTransparency = 1
    im.Image = "rbxassetid://95251902376685"
    im.ScaleType = Enum.ScaleType.Tile
    im.TileSize = UDim2.fromOffset(size or 18, size or 18)
    im.ImageTransparency = strength or 0.5
    im.Size = UDim2.fromScale(1, 1)
    im.ZIndex = frame.ZIndex
    local c = frame:FindFirstChildOfClass("UICorner")
    if c then
        c:Clone().Parent = im
    end
    im.Parent = frame
    return im
end
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local INK = Color3.fromRGB(17, 23, 26) -- Check-UI outline
local CREAM = Color3.fromRGB(42, 31, 74) -- recessed card (Figma night)
local GREEN = Color3.fromRGB(67, 220, 78)
local GREY = Color3.fromRGB(122, 129, 145)
local RARITY = {
    Common = Color3.fromRGB(150, 155, 165),
    Uncommon = Color3.fromRGB(70, 180, 70),
    Rare = Color3.fromRGB(60, 130, 230),
    Epic = Color3.fromRGB(150, 80, 220),
    Legendary = Color3.fromRGB(235, 175, 30),
}

local FX = {
    rays = "rbxthumb://type=Asset&id=110993746998606&w=420&h=420",
    glow = "rbxthumb://type=Asset&id=85372533044428&w=420&h=420",
    sparkle = "rbxthumb://type=Asset&id=87376394612367&w=420&h=420",
    star = "rbxthumb://type=Asset&id=81892896754419&w=420&h=420",
}
local TIER = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in props do
        o[k] = v
    end
    o.Parent = parent
    return o
end
local function box(parent, cx, cy, w, h, props)
    props = props or {}
    local class = props.Class or "Frame"
    props.Class = nil
    props.AnchorPoint = Vector2.new(0.5, 0.5)
    props.Position = UDim2.fromScale(cx, cy)
    props.Size = UDim2.fromScale(w, h)
    props.BackgroundTransparency = props.BackgroundTransparency or 1
    props.BorderSizePixel = 0
    props.ZIndex = props.ZIndex or 7
    return new(class, props, parent)
end
local function text(parent, str, color, props)
    props = props or {}
    local l = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = props.Size or UDim2.fromScale(1, 1),
        Position = props.Position or UDim2.new(),
        AnchorPoint = props.AnchorPoint or Vector2.new(),
        FontFace = FONT,
        Text = str,
        TextColor3 = color or INK,
        TextScaled = true,
        TextWrapped = true,
        TextXAlignment = props.X or Enum.TextXAlignment.Center,
        ZIndex = props.ZIndex or 8,
    }, parent)
    do
        local c = l.TextColor3
        if 0.299 * c.R + 0.587 * c.G + 0.114 * c.B < 0.42 then
            l.TextColor3 = Color3.new(1, 1, 1)
        end
    end -- readable on dark cards
    new("UITextSizeConstraint", { MaxTextSize = props.Max or 22 }, l)
    new("UIStroke", { Color = INK, Thickness = math.max(props.Stroke or 0, 1.6) }, l)
    return l
end
local function button(parent, cx, cy, w, h, label, color)
    local b = box(parent, cx, cy, w, h, {
        Class = "TextButton",
        BackgroundTransparency = 0,
        BackgroundColor3 = color or GREEN,
        Text = "",
        AutoButtonColor = true,
        ZIndex = 8,
    })
    new("UIStroke", {
        Color = Color3.new(1, 1, 1),
        Thickness = 3,
        LineJoinMode = Enum.LineJoinMode.Round,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, b)
    new("UICorner", { CornerRadius = UDim.new(0, 10) }, b) -- v2
    local st = new("ImageLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = "rbxassetid://132561191216691",
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(22, 22),
        ZIndex = 8,
    }, b)
    new(
        "UIGradient",
        { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)) },
        b
    )
    do
        local bv = new("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0, 6),
            ZIndex = 8,
        }, b)
        new("UICorner", { CornerRadius = UDim.new(0, 10) }, bv)
        local gl = new("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.7,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 8, 0, 4),
            Size = UDim2.new(1, -16, 0, 4),
            ZIndex = 8,
        }, b)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, gl)
    end -- 3D bevel + shine
    text(b, label, Color3.new(1, 1, 1), {
        Stroke = 2,
        ZIndex = 9,
        Size = UDim2.fromScale(0.85, 0.7),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
    })
    b.Activated:Connect(function()
        UISound.Play("Click")
    end)
    b.MouseEnter:Connect(function()
        UISound.Play("Hover")
    end)
    return b
end
local function clear(layer)
    for _, c in layer:GetChildren() do
        c:Destroy()
    end
end
-- CLEAN SKIN (Check-UI style + square studs): solid canvas, themed header, 2-tier divider, 3D close button.
local STUDS = "rbxassetid://132561191216691"
local SKINS = {
    Index = {
        title = "INDEX",
        grad = { Color3.fromRGB(59, 120, 255), Color3.fromRGB(11, 42, 156) },
        top = Color3.fromRGB(180, 240, 255),
        div = Color3.fromRGB(0, 50, 110),
    },
    Quests = {
        title = "QUESTS",
        grad = { Color3.fromRGB(67, 220, 78), Color3.fromRGB(11, 122, 27) },
        top = Color3.fromRGB(224, 255, 176),
        div = Color3.fromRGB(37, 96, 0),
    },
    VipShop = workspace:GetAttribute("HalloweenMode") and {
        title = "HALLOWEEN SHOP",
        grad = { Color3.fromRGB(255, 170, 30), Color3.fromRGB(240, 90, 0) },
        top = Color3.fromRGB(255, 225, 160),
        div = Color3.fromRGB(130, 50, 0),
    } or {
        title = "SHOP",
        grad = { Color3.fromRGB(255, 201, 63), Color3.fromRGB(163, 92, 0) },
        top = Color3.fromRGB(255, 200, 225),
        div = Color3.fromRGB(125, 0, 18),
    },
    Plot = {
        title = "MY TEMPLE",
        grad = { Color3.fromRGB(255, 74, 74), Color3.fromRGB(179, 0, 15) },
        top = Color3.fromRGB(255, 200, 225),
        div = Color3.fromRGB(125, 0, 18),
    },
}
local function studLayer(f, size, transp)
    local im = new("ImageLabel", {
        Name = "Studs",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = STUDS,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(size, size),
        ImageTransparency = transp or 0,
        ZIndex = f.ZIndex,
    }, f)
    local c = f:FindFirstChildOfClass("UICorner")
    if c then
        c:Clone().Parent = im
    end
    return im
end
local function skinPanel(panel)
    local th = SKINS[panel.Name]
    if not th or panel:FindFirstChild("CleanSkin") then
        return
    end
    panel.ImageTransparency = 1
    new("Frame", {
        Name = "CleanBase",
        BackgroundColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 10),
        Size = UDim2.fromScale(1, 1),
        ZIndex = 0,
    }, panel) -- hard shadow
    local skin = new(
        "Frame",
        { Name = "CleanSkin", BackgroundColor3 = Color3.fromRGB(59, 88, 102), Size = UDim2.fromScale(1, 1), ZIndex = 1 },
        panel
    )
    new("UIStroke", {
        Color = Color3.new(1, 1, 1),
        Thickness = 5,
        LineJoinMode = Enum.LineJoinMode.Miter,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, skin)
    skin.BackgroundColor3 = Color3.new(1, 1, 1)
    new(
        "UIGradient",
        { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(47, 35, 87), Color3.fromRGB(20, 13, 43)) },
        skin
    )
    studLayer(skin, 30, 0.6) -- quiet body texture so content reads first
    -- header
    local head = new("Frame", {
        Name = "Header",
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0.15, 0),
        ZIndex = 2,
    }, skin)
    new("UIGradient", { Rotation = 90, Color = ColorSequence.new(th.grad[1], th.grad[2]) }, head)
    studLayer(head, 30, 0)
    local t = new("TextLabel", {
        BackgroundTransparency = 1,
        Text = th.title,
        FontFace = FONT,
        TextScaled = true,
        TextColor3 = Color3.new(1, 1, 1),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.52),
        Size = UDim2.fromScale(0.6, 0.62),
        ZIndex = 4,
    }, head)
    new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 4 }, t)
    -- 2-tier shadow divider
    new("Frame", {
        BackgroundColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0.15, 0),
        Size = UDim2.new(1, 0, 0, 4),
        ZIndex = 3,
    }, skin)
    -- 3D beveled square close button (restyles the existing Close so its click still works)
    local cb = panel:FindFirstChild("Close")
    if cb then
        for _, c in cb:GetChildren() do
            if not c:IsA("UIScale") then
                c:Destroy()
            end
        end
        cb.AnchorPoint = Vector2.new(0.5, 0.5)
        cb.Position = UDim2.new(1, -30, 0.075, 0)
        cb.Size = UDim2.fromOffset(42, 42)
        cb.Text = ""
        cb.BackgroundColor3 = Color3.new(0, 0, 0)
        cb.AutoButtonColor = false
        cb.ZIndex = 25
        new(
            "UIStroke",
            { Color = Color3.new(0, 0, 0), Thickness = 2.8, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
            cb
        )
        local face = new("Frame", {
            Name = "Face",
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, -5),
            ZIndex = 26,
        }, cb)
        face.BackgroundColor3 = Color3.fromRGB(232, 48, 48)
        local inner = new("Frame", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, -2, 1, -2),
            ZIndex = 27,
        }, face)

        local x = new("TextLabel", {
            BackgroundTransparency = 1,
            Text = "X",
            FontFace = FONT,
            TextSize = 30,
            TextColor3 = Color3.new(1, 1, 1),
            Size = UDim2.fromScale(1, 1),
            ZIndex = 28,
        }, face)
        new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 3 }, x)
        local sc = cb:FindFirstChildOfClass("UIScale") or new("UIScale", {}, cb)
        cb.MouseEnter:Connect(function()
            TweenService:Create(sc, TweenInfo.new(0.08), { Scale = 1.08 }):Play()
        end)
        cb.MouseLeave:Connect(function()
            TweenService:Create(sc, TweenInfo.new(0.08), { Scale = 1 }):Play()
        end)
        cb.MouseButton1Down:Connect(function()
            TweenService:Create(sc, TweenInfo.new(0.05), { Scale = 0.92 }):Play()
        end)
    end
end
local function layerOf(panel)
    return panel:FindFirstChild("Live")
        or new("Frame", { Name = "Live", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 7 }, panel)
end

local toast = new("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -110),
    Size = UDim2.new(1, -32, 0, 40),
    BackgroundColor3 = CREAM,
    FontFace = FONT,
    TextScaled = true,
    TextColor3 = Color3.new(1, 1, 1),
    Visible = false,
    ZIndex = 20,
}, gui)
new("UIStroke", { Color = INK, Thickness = 1.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, toast)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, toast)
new("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, toast)
new("UIPadding", {
    PaddingLeft = UDim.new(0, 12),
    PaddingRight = UDim.new(0, 12),
    PaddingTop = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),
}, toast)
new("UISizeConstraint", { MaxSize = Vector2.new(420, 40) }, toast)
local toastId = 0
local function say(msg)
    if not msg or msg == "" then
        return
    end
    toastId += 1
    local my = toastId
    toast.Text = msg
    toast.Visible = true
    task.delay(2.2, function()
        if toastId == my then
            toast.Visible = false
        end
    end)
end
local refresh
local actionBusy = false
local function act(name, args)
    if actionBusy then
        return false
    end
    actionBusy = true
    local ok, res, msg = pcall(function()
        return Action:InvokeServer(name, args)
    end)
    actionBusy = false
    if not ok then
        say("Server error")
        return false
    end
    say(msg)
    if res then
        if name and name:find("Claim") then
            UISound.Play("Claim")
        elseif name and (name:find("Upgrade") or name:find("Unlock") or name:find("Buy")) then
            UISound.Play("Purchase")
        end
        if refresh then
            refresh()
        end
    end
    return res
end
local function fetch(section)
    for attempt = 1, 3 do
        local ok, data = pcall(function()
            return GetState:InvokeServer(section)
        end)
        if not ok or type(data) ~= "table" then
            return nil, "Couldn't load"
        end
        if not data.error then
            return data
        end
        if data.error ~= "Please wait a moment." then
            return nil, data.error
        end
        task.wait(0.06 * attempt)
    end
    return nil, "Couldn't refresh. Please reopen the menu."
end

local RENDER = {}

local EDGE_C, CARD_C, CELL_C = Color3.fromRGB(150, 120, 230), Color3.fromRGB(42, 31, 74), Color3.fromRGB(53, 40, 98)
local function accentOf(inst)
    while inst and inst.Parent ~= gui do
        inst = inst.Parent
    end
    local th = inst and SKINS[inst.Name]
    return th and th.grad[1] or Color3.fromRGB(255, 196, 60)
end
local function card(parent, cx, cy, w, h, color, r, z)
    local f =
        box(parent, cx, cy, w, h, { BackgroundTransparency = 0, BackgroundColor3 = color or CARD_C, ZIndex = z or 6 })
    new("UIStroke", {
        Color = Color3.new(1, 1, 1),
        Thickness = 3,
        Transparency = 0,
        LineJoinMode = Enum.LineJoinMode.Round,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, f)
    new("UICorner", { CornerRadius = UDim.new(0, 10) }, f) -- v2
    new(
        "UIGradient",
        { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(165, 160, 185)) },
        f
    ) -- figma: lighter top, darker base
    new("ImageLabel", {
        Name = "Studs",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = "rbxassetid://132561191216691",
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(22, 22),
        ImageTransparency = 0.72,
        ZIndex = f.ZIndex,
    }, f)
    if parent:GetAttribute("Inner") then -- main cards: accent strip in the menu colour
        new("Frame", {
            Name = "Accent",
            BackgroundColor3 = accentOf(parent),
            BorderSizePixel = 0,
            Size = UDim2.new(0, 6, 1, 0),
            ZIndex = f.ZIndex,
        }, f)
    end
    return f
end
local function innerOf(L)
    local b = box(L, 0.5, 0.58, 0.9, 0.72)
    b:SetAttribute("Inner", true)
    return b
end

-- ===== UI v3 (Figma "Index v3 · Seasons" / "Quest v3") =====
local W3, K3 = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local GI = {
    Book = "rbxassetid://104286530759848",
    Scroll = "rbxassetid://79414603176573",
    Key = "rbxassetid://86826769942442",
    Trophy = "rbxassetid://93664136134324",
    Medal = "rbxassetid://115933046975719",
    Clock = "rbxassetid://112731802177209",
    Diamond = "rbxassetid://125953814573772",
    Gem = "rbxassetid://139683651057323",
    Chest = "rbxassetid://108828180161951",
    Hatch = "EGG",
    Boost = "rbxassetid://115300000098827",
    Money = "rbxassetid://91503030293166",
    Crown = "rbxassetid://132384741215584",
    ShopCrown = "rbxassetid://132384741215584",
    Starter = "rbxassetid://89561259739700",
    Coins = "rbxassetid://125162321561970",
    Plot = "rbxassetid://77749732102580",
    Index = "rbxassetid://101507685468144",
    Quest = "rbxassetid://81682814875935",
    Cash = "rbxassetid://113092821462846",
}
local function gicon(parent, img, cx, cy, s, z)
    if img == "EGG" then -- the real Limited (Unknown) egg model, framed in a small viewport
        local vp = new("ViewportFrame", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(cx, cy),
            Size = UDim2.fromScale(s, s),
            SizeConstraint = Enum.SizeConstraint.RelativeYY,
            ZIndex = z or 12,
            Ambient = Color3.fromRGB(210, 210, 230),
            LightColor = Color3.fromRGB(255, 245, 225),
            LightDirection = Vector3.new(-1, -1, -1),
        }, parent)
        local SM = RS:FindFirstChild("ShopSystem") and RS.ShopSystem:FindFirstChild("ShopModels")
        local src = SM and SM:FindFirstChild("UnknownEgg")
        if src then
            local egg = src:Clone()
            egg.Parent = vp
            local cf, size = egg:GetBoundingBox()
            egg:PivotTo(CFrame.new(-cf.Position) * egg:GetPivot())
            local cam = new("Camera", { FieldOfView = 30 }, vp)
            vp.CurrentCamera = cam
            cam.CFrame = CFrame.lookAt(Vector3.new(0, size.Y * 0.05, -size.Magnitude * 1.55), Vector3.zero)
        end
        return vp
    end
    local im = new("ImageLabel", {
        BackgroundTransparency = 1,
        Image = img,
        ScaleType = Enum.ScaleType.Fit,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(cx, cy),
        Size = UDim2.fromScale(s, s),
        SizeConstraint = Enum.SizeConstraint.RelativeYY,
        ZIndex = z or 12,
    }, parent)
    return im
end
local function v3card(parent, cx, cy, w, h, color, z)
    local f = box(parent, cx, cy, w, h, { BackgroundTransparency = 0, BackgroundColor3 = color, ZIndex = z or 8 })
    new("UICorner", { CornerRadius = UDim.new(0, 10) }, f)
    new("UIStroke", {
        Color = W3,
        Thickness = 3,
        LineJoinMode = Enum.LineJoinMode.Round,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, f)
    new("UIGradient", { Rotation = 90, Color = ColorSequence.new(W3, Color3.fromRGB(170, 165, 190)) }, f)
    new("ImageLabel", {
        Name = "Studs",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = STUDS,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(22, 22),
        ImageTransparency = 0.7,
        ZIndex = f.ZIndex,
    }, f)
    return f
end
local function v3tab(parent, cx, cy, w, h, label, color, on, onClick, sub, img)
    local b = v3card(parent, cx, cy, w, h, on and color or Color3.fromRGB(53, 40, 98), 9)
    b = b -- frame; clickable overlay
    local hit =
        new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 14 }, b)
    if img then
        local ic = gicon(b, img, 0.13, 0.5, 0.9, 13)
        if on then
            TweenService:Create(
                ic,
                TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { Rotation = 8 }
            ):Play()
        end
    end
    text(b, label, W3, {
        Stroke = 2,
        Max = 20,
        Size = UDim2.fromScale(img and 0.66 or 0.9, sub and 0.5 or 0.62),
        Position = UDim2.fromScale(img and 0.6 or 0.5, sub and 0.36 or 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ZIndex = 12,
    })
    if sub then
        text(b, sub, Color3.fromRGB(230, 225, 255), {
            Max = 12,
            Size = UDim2.fromScale(0.9, 0.3),
            Position = UDim2.fromScale(0.5, 0.78),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 12,
        })
    end
    local st = b:FindFirstChildOfClass("UIStroke")
    if on then
        TweenService:Create(
            st,
            TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Thickness = 4.5 }
        ):Play()
    end
    if onClick then
        local sc = new("UIScale", {}, b)
        hit.MouseEnter:Connect(function()
            UISound.Play("Hover")
            TweenService:Create(sc, TweenInfo.new(0.1), { Scale = 1.05 }):Play()
        end)
        hit.MouseLeave:Connect(function()
            TweenService:Create(sc, TweenInfo.new(0.1), { Scale = 1 }):Play()
        end)
        hit.Activated:Connect(function()
            UISound.Play("Click")
            onClick()
        end)
    else
        b.BackgroundTransparency = 0.35
    end
    return b
end
local function setHeader(panel, title, c1, c2)
    local skin = panel:FindFirstChild("CleanSkin")
    local head = skin and skin:FindFirstChild("Header")
    if not head then
        return
    end
    local g = head:FindFirstChildOfClass("UIGradient")
    if g then
        g.Color = ColorSequence.new(c1, c2)
    end
    local t = head:FindFirstChildOfClass("TextLabel")
    if t then
        t.Text = title
    end
end
local function hms(sec)
    sec = math.max(0, math.floor(sec))
    local d = sec // 86400
    return (d > 0 and (d .. "d ") or "")
        .. string.format("%02d:%02d:%02d", (sec // 3600) % 24, (sec // 60) % 60, sec % 60)
end

local indexSeason = workspace:GetAttribute("HalloweenMode") and "Halloween" or "Original"
local indexFilter, indexSel = "All", nil
RENDER.Index = function(panel)
    local data, err = fetch("index")
    local L = layerOf(panel)
    clear(L)
    if not data then
        text(box(L, 0.5, 0.5, 0.6, 0.08), err)
        return
    end
    local HW = indexSeason == "Halloween"
    local ORANGE = Color3.fromRGB(255, 140, 30)
    if HW then
        setHeader(panel, "HALLOWEEN INDEX", Color3.fromRGB(255, 160, 40), Color3.fromRGB(200, 60, 0))
    else
        setHeader(panel, "INDEX", SKINS.Index.grad[1], SKINS.Index.grad[2])
    end
    local inner = box(L, 0.5, 0.575, 0.94, 0.79)
    local chars = {}
    for i, c in data.catalog.characters do
        if i <= 15 then
            table.insert(chars, c)
        end
    end
    local found = 0
    for _, c in chars do
        if data.discovered[c.id] == true then
            found += 1
        end
    end
    -- season tabs
    local live = workspace:GetAttribute("HalloweenMode") == true
    v3tab(inner, 0.09, 0.045, 0.17, 0.085, "ORIGINAL", Color3.fromRGB(60, 120, 240), not HW, function()
        indexSeason = "Original"
        RENDER.Index(panel)
    end, #chars .. " characters", GI.Book)
    local ht = v3tab(inner, 0.275, 0.045, 0.19, 0.085, "🎃 HALLOWEEN", ORANGE, HW, function()
        indexSeason = "Halloween"
        RENDER.Index(panel)
    end, live and "LIVE EVENT" or "event ended")
    if live then
        local tag = v3card(ht, 0.92, -0.12, 0.3, 0.42, Color3.fromRGB(230, 40, 60), 15)
        text(tag, "LIVE", W3, {
            Stroke = 1.5,
            Max = 13,
            Size = UDim2.fromScale(0.9, 0.8),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 16,
        })
        local ts = new("UIScale", {}, tag)
        TweenService
            :Create(
                ts,
                TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { Scale = 1.12 }
            )
            :Play()
    end
    v3tab(inner, 0.46, 0.045, 0.16, 0.085, "🔒 WINTER", Color3.fromRGB(40, 36, 70), false, nil, "coming soon")
    local endsAt = workspace:GetAttribute("HalloweenEndsAt")
    if HW then
        local tp = v3card(inner, 0.87, 0.045, 0.26, 0.075, Color3.fromRGB(110, 50, 190), 9)
        local tl = text(
            tp,
            typeof(endsAt) == "number" and ("⏳ ENDS IN " .. hms(endsAt - os.time())) or "⏳ LIMITED EVENT",
            Color3.fromRGB(255, 220, 120),
            {
                Stroke = 2,
                Max = 18,
                Size = UDim2.fromScale(0.92, 0.7),
                Position = UDim2.fromScale(0.5, 0.5),
                AnchorPoint = Vector2.new(0.5, 0.5),
                ZIndex = 12,
            }
        )
        if typeof(endsAt) == "number" then
            task.spawn(function()
                while tl.Parent and panel.Visible do
                    tl.Text = "⏳ ENDS IN " .. hms(endsAt - os.time())
                    task.wait(1)
                end
            end)
        end
    end
    -- progress strip
    local ps = v3card(inner, 0.5, 0.155, 1, 0.1, HW and Color3.fromRGB(70, 30, 80) or Color3.fromRGB(33, 24, 69), 8)
    if HW then
        ps:FindFirstChildOfClass("UIStroke").Color = ORANGE
    end
    text(
        ps,
        HW and "HALLOWEEN SET" or "DISCOVERED",
        HW and Color3.fromRGB(255, 190, 110) or Color3.fromRGB(195, 180, 230),
        {
            Max = 14,
            Size = UDim2.fromScale(0.16, 0.36),
            Position = UDim2.fromScale(0.015, 0.1),
            X = Enum.TextXAlignment.Left,
            ZIndex = 10,
        }
    )
    text(ps, found .. " / " .. #chars, W3, {
        Stroke = 2,
        Max = 26,
        Size = UDim2.fromScale(0.12, 0.5),
        Position = UDim2.fromScale(0.015, 0.44),
        X = Enum.TextXAlignment.Left,
        ZIndex = 10,
    })
    local track = new("Frame", {
        BackgroundColor3 = Color3.fromRGB(13, 10, 20),
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.15, 0.32),
        Size = UDim2.fromScale(0.58, 0.36),
        ZIndex = 10,
    }, ps)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
    new("UIStroke", { Color = W3, Thickness = 2 }, track)
    local fill = new("Frame", {
        BackgroundColor3 = W3,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(math.max(found / math.max(#chars, 1), 0.03), 1),
        ZIndex = 11,
    }, track)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
    new("UIGradient", {
        Color = HW and ColorSequence.new(Color3.fromRGB(255, 210, 60), Color3.fromRGB(255, 100, 0))
            or ColorSequence.new(Color3.fromRGB(130, 255, 110), Color3.fromRGB(40, 190, 60)),
    }, fill)
    local rw = v3card(ps, 0.865, 0.5, 0.24, 0.6, HW and ORANGE or Color3.fromRGB(255, 214, 72), 10)
    gicon(rw, GI.Trophy, 0.1, 0.5, 1.1, 13)
    text(
        rw,
        found >= #chars and "   SET COMPLETE!" or ("     " .. (#chars - found) .. " left to find"),
        found >= #chars and W3 or INK,
        {
            Max = 16,
            Size = UDim2.fromScale(0.92, 0.7),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 12,
        }
    )
    -- rarity filters
    local FILTERS = { "All", "Common", "Uncommon", "Rare", "Epic", "Legendary" }
    local fx = 0
    for _, f in FILTERS do
        local w = 0.05 + #f * 0.0075
        local on = indexFilter == f
        local col = f == "All" and W3 or RARITY[f]
        local t = v3card(inner, fx + w / 2, 0.24, w, 0.05, on and col or Color3.fromRGB(53, 40, 98), 9)
        text(t, string.upper(f), (on and f == "All") and INK or W3, {
            Max = 13,
            Size = UDim2.fromScale(0.9, 0.75),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 12,
        })
        local hit =
            new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 14 }, t)
        hit.Activated:Connect(function()
            UISound.Play("Click")
            indexFilter = f
            RENDER.Index(panel)
        end)
        fx += w + 0.008
    end
    -- grid
    local shown = {}
    for _, c in chars do
        if indexFilter == "All" or c.rarity == indexFilter then
            table.insert(shown, c)
        end
    end
    if not indexSel then
        for _, c in chars do
            if data.discovered[c.id] == true then
                indexSel = c.id
            end
        end
    end
    local grid = box(inner, 0.34, 0.635, 0.68, 0.72)
    for i, c in shown do
        local got = data.discovered[c.id] == true
        local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
        local ce = card(
            grid,
            0.1 + col * 0.2,
            0.165 + row * 0.335,
            0.185,
            0.31,
            got and (RARITY[c.rarity] or CELL_C) or Color3.fromRGB(28, 22, 46),
            0.18,
            7
        )
        if got then
            local rc = RARITY[c.rarity] or GREY
            local light = rc:Lerp(W3, 0.55)
            local tier = TIER[c.rarity] or 6
            ce.ClipsDescendants = true
            local rays = new("ImageLabel", {
                Name = "Rays",
                BackgroundTransparency = 1,
                Image = FX.rays,
                ImageColor3 = light,
                ImageTransparency = tier >= 3 and 0.45 or 0.7,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.45),
                Size = UDim2.fromScale(1.5, 1.5),
                SizeConstraint = Enum.SizeConstraint.RelativeXX,
                ZIndex = 7,
            }, ce)
            TweenService:Create(
                rays,
                TweenInfo.new(24, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
                { Rotation = 360 }
            ):Play()
            new("ImageLabel", {
                Name = "Glow",
                BackgroundTransparency = 1,
                Image = FX.glow,
                ImageColor3 = light,
                ImageTransparency = 0.25,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.46),
                Size = UDim2.fromScale(0.9, 0.9),
                SizeConstraint = Enum.SizeConstraint.RelativeYY,
                ZIndex = 7,
            }, ce)
            for k, p in { { 0.12, 0.3 }, { 0.88, 0.42 }, { 0.18, 0.66 }, { 0.84, 0.7 }, { 0.72, 0.18 } } do
                if k > tier then
                    break
                end
                local sp = new("ImageLabel", {
                    BackgroundTransparency = 1,
                    Image = FX.sparkle,
                    ImageColor3 = k % 2 == 0 and W3 or light,
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromScale(p[1], p[2]),
                    Size = UDim2.fromOffset(k % 2 == 0 and 9 or 13, k % 2 == 0 and 9 or 13),
                    ZIndex = 10,
                }, ce)
                TweenService
                    :Create(
                        sp,
                        TweenInfo.new(0.9 + k * 0.17, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                        { ImageTransparency = 0.8 }
                    )
                    :Play()
            end
            if c.image and c.image ~= "" then
                new("ImageLabel", {
                    BackgroundTransparency = 1,
                    Image = c.image,
                    ScaleType = Enum.ScaleType.Fit,
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromScale(0.5, 0.42),
                    Size = UDim2.fromScale(1.3, 0.7),
                    ZIndex = 9,
                }, ce)
            end
            local nb = new("Frame", {
                BackgroundColor3 = Color3.fromRGB(13, 10, 20),
                BackgroundTransparency = 0.45,
                BorderSizePixel = 0,
                AnchorPoint = Vector2.new(0.5, 1),
                Position = UDim2.new(0.5, 0, 1, -5),
                Size = UDim2.fromScale(0.9, 0.19),
                ZIndex = 10,
            }, ce)
            new("UICorner", { CornerRadius = UDim.new(0, 6) }, nb)
            text(nb, c.name, W3, {
                Stroke = 1.5,
                Max = 15,
                Size = UDim2.fromScale(0.94, 0.8),
                Position = UDim2.fromScale(0.5, 0.5),
                AnchorPoint = Vector2.new(0.5, 0.5),
                ZIndex = 11,
            })
            if HW then
                text(ce, "🎃", W3, {
                    Max = 18,
                    Size = UDim2.fromScale(0.22, 0.16),
                    Position = UDim2.fromScale(0.03, 0.03),
                    ZIndex = 12,
                })
            end
            if indexSel == c.id then
                local st = ce:FindFirstChildOfClass("UIStroke")
                st.Color = HW and ORANGE or Color3.fromRGB(255, 214, 72)
                TweenService:Create(
                    st,
                    TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                    { Thickness = 5 }
                ):Play()
            end
            local hit = new(
                "TextButton",
                { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 15 },
                ce
            )
            local cs = new("UIScale", {}, ce)
            hit.MouseEnter:Connect(function()
                UISound.Play("Hover")
                TweenService:Create(cs, TweenInfo.new(0.1), { Scale = 1.05 }):Play()
            end)
            hit.MouseLeave:Connect(function()
                TweenService:Create(cs, TweenInfo.new(0.1), { Scale = 1 }):Play()
            end)
            hit.Activated:Connect(function()
                UISound.Play("Click")
                indexSel = c.id
                RENDER.Index(panel)
            end)
        else
            if c.image and c.image ~= "" then
                new("ImageLabel", {
                    BackgroundTransparency = 1,
                    Image = c.image,
                    ImageColor3 = K3,
                    ImageTransparency = 0.15,
                    ScaleType = Enum.ScaleType.Fit,
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromScale(0.5, 0.42),
                    Size = UDim2.fromScale(1.15, 0.7),
                    ZIndex = 8,
                }, ce)
            else
                text(ce, "?", GREY, {
                    Size = UDim2.fromScale(0.5, 0.45),
                    Position = UDim2.fromScale(0.5, 0.36),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    ZIndex = 8,
                })
            end
            text(ce, "???", RARITY[c.rarity] or GREY, {
                Stroke = 1.5,
                Max = 15,
                Size = UDim2.fromScale(0.7, 0.18),
                Position = UDim2.fromScale(0.5, 0.86),
                AnchorPoint = Vector2.new(0.5, 0.5),
                ZIndex = 9,
            })
        end
    end
    -- detail panel
    local sel
    for _, c in chars do
        if c.id == indexSel then
            sel = c
        end
    end
    local rc = sel and (RARITY[sel.rarity] or GREY) or Color3.fromRGB(53, 40, 98)
    local det = v3card(inner, 0.85, 0.635, 0.3, 0.72, HW and Color3.fromRGB(255, 150, 40) or rc, 8)
    if sel then
        det.ClipsDescendants = true
        local rays = new("ImageLabel", {
            BackgroundTransparency = 1,
            Image = FX.rays,
            ImageColor3 = W3,
            ImageTransparency = 0.6,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.32),
            Size = UDim2.fromScale(1.6, 1.6),
            SizeConstraint = Enum.SizeConstraint.RelativeXX,
            ZIndex = 9,
        }, det)
        TweenService
            :Create(
                rays,
                TweenInfo.new(20, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
                { Rotation = 360 }
            )
            :Play()
        local tag = v3card(det, 0.24, 0.06, 0.38, 0.06, Color3.fromRGB(226, 66, 60), 12)
        text(tag, string.upper(sel.rarity or "?"), W3, {
            Stroke = 1.5,
            Max = 14,
            Size = UDim2.fromScale(0.9, 0.8),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 13,
        })
        if HW then
            local ev = v3card(det, 0.76, 0.06, 0.4, 0.06, Color3.fromRGB(110, 40, 190), 12)
            text(ev, "👻 EVENT", W3, {
                Stroke = 1.5,
                Max = 14,
                Size = UDim2.fromScale(0.9, 0.8),
                Position = UDim2.fromScale(0.5, 0.5),
                AnchorPoint = Vector2.new(0.5, 0.5),
                ZIndex = 13,
            })
        end
        if sel.image and sel.image ~= "" then
            local im = new("ImageLabel", {
                BackgroundTransparency = 1,
                Image = sel.image,
                ScaleType = Enum.ScaleType.Fit,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.33),
                Size = UDim2.fromScale(0.95, 0.4),
                ZIndex = 11,
            }, det)
            TweenService:Create(
                im,
                TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { Position = UDim2.fromScale(0.5, 0.31) }
            ):Play()
        end
        text(det, sel.name, W3, {
            Stroke = 2.5,
            Max = 30,
            Size = UDim2.fromScale(0.92, 0.09),
            Position = UDim2.fromScale(0.5, 0.6),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 12,
        })
        local info = v3card(det, 0.5, 0.76, 0.9, 0.17, Color3.fromRGB(33, 24, 69), 11)
        text(info, sel.obtain or "", Color3.fromRGB(215, 210, 240), {
            Max = 14,
            Size = UDim2.fromScale(0.92, 0.45),
            Position = UDim2.fromScale(0.5, 0.3),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 13,
        })
        local own = data.owned and data.owned[sel.id] or 0
        text(info, "OWNED: " .. own, Color3.fromRGB(120, 255, 120), {
            Stroke = 1.5,
            Max = 18,
            Size = UDim2.fromScale(0.9, 0.35),
            Position = UDim2.fromScale(0.5, 0.75),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 13,
        })
        text(det, sel.description or "", W3, {
            Max = 13,
            Size = UDim2.fromScale(0.9, 0.08),
            Position = UDim2.fromScale(0.5, 0.92),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 12,
        })
    else
        text(det, "Hatch eggs to discover characters!", W3, {
            Stroke = 2,
            Max = 20,
            Size = UDim2.fromScale(0.85, 0.2),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 12,
        })
    end
end

local questTab = "Daily"
RENDER.Quests = function(panel)
    local data, err = fetch("quests")
    local L = layerOf(panel)
    clear(L)
    if not data then
        text(box(L, 0.5, 0.5, 0.6, 0.08), err)
        return
    end
    local inner = box(L, 0.5, 0.575, 0.94, 0.79)
    local TABS = {
        { "Daily", "DAILY", Color3.fromRGB(255, 190, 40), GI.Clock },
        { "Weekly", "WEEKLY", Color3.fromRGB(255, 120, 40), GI.Chest },
        { "Monthly", "MILESTONES", Color3.fromRGB(150, 100, 230), GI.Trophy },
    }
    for i, t in TABS do
        local ready = 0
        for _, q in data.list or {} do
            if q.period == t[1] and q.progress >= q.target and not q.claimed then
                ready += 1
            end
        end
        local tb = v3tab(inner, 0.1 + (i - 1) * 0.21, 0.05, 0.195, 0.085, t[2], t[3], questTab == t[1], function()
            if questTab ~= t[1] then
                questTab = t[1]
                RENDER.Quests(panel)
            end
        end, nil, t[4])
        if ready > 0 then
            local bd = v3card(tb, 0.97, 0.08, 0.17, 0.5, Color3.fromRGB(230, 40, 60), 15)
            text(bd, tostring(ready), W3, {
                Stroke = 1.5,
                Max = 14,
                Size = UDim2.fromScale(0.9, 0.85),
                Position = UDim2.fromScale(0.5, 0.5),
                AnchorPoint = Vector2.new(0.5, 0.5),
                ZIndex = 16,
            })
        end
    end
    local endsAt = data.ends and data.ends[questTab]
    local tp = v3card(inner, 0.86, 0.05, 0.28, 0.07, Color3.fromRGB(20, 14, 40), 9)
    gicon(tp, GI.Clock, 0.08, 0.5, 0.9, 13)
    local tl = text(tp, "", Color3.fromRGB(255, 214, 72), {
        Stroke = 1.5,
        Max = 16,
        Size = UDim2.fromScale(0.92, 0.7),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ZIndex = 12,
    })
    if endsAt then
        local off = (data.serverTime or os.time()) - os.time()
        task.spawn(function()
            while tl.Parent and panel.Visible do
                tl.Text = "      New quests in " .. hms(endsAt - (os.time() + off))
                task.wait(1)
            end
        end)
    end
    local list = {}
    for _, q in data.list or {} do
        if q.period == questTab then
            table.insert(list, q)
        end
    end
    table.sort(list, function(a, b)
        local ac, bc = a.claimed and 1 or 0, b.claimed and 1 or 0
        if ac ~= bc then
            return ac < bc
        end
        local ad, bd = (a.progress >= a.target) and 0 or 1, (b.progress >= b.target) and 0 or 1
        if ad ~= bd then
            return ad < bd
        end
        return (a.order or 0) < (b.order or 0)
    end)
    if #list == 0 then
        text(box(inner, 0.5, 0.5, 0.8, 0.1), "No quests here right now", GREY)
        return
    end
    local n = math.max(#list, 5)
    local rowH = 0.84 / n
    for i, q in list do
        local done = q.progress >= q.target
        local claimable = done and not q.claimed
        local y = 0.13 + (i - 0.5) * rowH
        local row = v3card(
            inner,
            0.5,
            y,
            1,
            rowH * 0.88,
            claimable and Color3.fromRGB(40, 150, 60)
                or q.claimed and Color3.fromRGB(45, 42, 62)
                or Color3.fromRGB(42, 31, 74),
            8
        )
        if claimable then
            local st = row:FindFirstChildOfClass("UIStroke")
            st.Color = Color3.fromRGB(150, 255, 120)
            TweenService:Create(
                st,
                TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { Thickness = 5 }
            ):Play()
        end
        local tl2 = string.lower(q.title or "")
        local em = tl2:find("hatch") and "🥚"
            or tl2:find("discover") and "📖"
            or tl2:find("steal") and "🦹"
            or tl2:find("place") and "🐾"
            or tl2:find("upgrade") and "⭐"
            or tl2:find("cash") and "💰"
            or "⭐"
        local icon = v3card(row, 0.045, 0.5, 0.06, 0.8, q.claimed and GREEN or Color3.fromRGB(70, 140, 255), 10)
        new("UIAspectRatioConstraint", { AspectRatio = 1 }, icon)
        local qimg = (tl2:find("hatch") or tl2:find("egg")) and GI.Hatch
            or tl2:find("discover") and GI.Book
            or (tl2:find("place") or tl2:find("upgrade") or tl2:find("temple") or tl2:find("slot")) and GI.Plot
            or (tl2:find("cash") or tl2:find("income") or tl2:find("earn")) and GI.Coins
            or tl2:find("steal") and GI.Chest
            or GI.Scroll
        if q.claimed then
            text(icon, "✓", W3, {
                Stroke = 2,
                Max = 34,
                Size = UDim2.fromScale(0.85, 0.85),
                Position = UDim2.fromScale(0.5, 0.5),
                AnchorPoint = Vector2.new(0.5, 0.5),
                ZIndex = 12,
            })
        else
            local qi = gicon(icon, qimg, 0.5, 0.5, 0.92, 12)
            if claimable and qi:IsA("ImageLabel") then
                TweenService:Create(
                    qi,
                    TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                    { Rotation = 10 }
                ):Play()
            end
        end
        text(row, q.title or "", W3, {
            Stroke = 2,
            Max = 22,
            Size = UDim2.fromScale(0.4, 0.4),
            Position = UDim2.fromScale(0.1, 0.1),
            X = Enum.TextXAlignment.Left,
            ZIndex = 11,
        })
        text(row, q.description or "", Color3.fromRGB(205, 200, 230), {
            Max = 14,
            Size = UDim2.fromScale(0.4, 0.3),
            Position = UDim2.fromScale(0.1, 0.55),
            X = Enum.TextXAlignment.Left,
            ZIndex = 11,
        })
        local track = new("Frame", {
            BackgroundColor3 = Color3.fromRGB(13, 10, 20),
            BorderSizePixel = 0,
            Position = UDim2.fromScale(0.52, 0.14),
            Size = UDim2.fromScale(0.26, 0.32),
            ZIndex = 10,
        }, row)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
        new("UIStroke", { Color = W3, Thickness = 2 }, track)
        local f = new("Frame", {
            BackgroundColor3 = W3,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(math.clamp(q.progress / q.target, 0.04, 1), 1),
            ZIndex = 11,
        }, track)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
        new("UIGradient", {
            Color = done and ColorSequence.new(Color3.fromRGB(130, 255, 110), Color3.fromRGB(40, 190, 60))
                or ColorSequence.new(Color3.fromRGB(255, 210, 60), Color3.fromRGB(255, 140, 0)),
        }, f)
        text(track, math.min(q.progress, q.target) .. " / " .. q.target, W3, { Stroke = 1.5, Max = 14, ZIndex = 12 })
        local rw = q.reward and (q.reward.cash and ("     $" .. Config.Short(q.reward.cash)) or q.reward.label) or nil
        if rw then
            local chip = v3card(row, 0.585, 0.73, 0.13, 0.32, Color3.fromRGB(20, 14, 40), 10)
            text(chip, rw, Color3.fromRGB(120, 255, 120), {
                Stroke = 1.5,
                Max = 14,
                Size = UDim2.fromScale(0.9, 0.8),
                Position = UDim2.fromScale(0.5, 0.5),
                AnchorPoint = Vector2.new(0.5, 0.5),
                ZIndex = 12,
            })
            if q.reward.cash then
                gicon(chip, GI.Coins, 0.2, 0.5, 1.1, 13)
            end
        end
        local label = q.claimed and "DONE" or claimable and "CLAIM" or "GO"
        local b = button(
            row,
            0.9,
            0.5,
            0.16,
            0.66,
            label,
            q.claimed and GREY or claimable and GREEN or Color3.fromRGB(60, 120, 240)
        )
        b.ZIndex = 12
        if claimable then
            local bs = new("UIScale", {}, b)
            TweenService:Create(
                bs,
                TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { Scale = 1.06 }
            ):Play()
            b.Activated:Connect(function()
                act("Claim", { id = q.id })
            end)
        elseif not q.claimed then
            b.Activated:Connect(function()
                say(q.description or q.title)
            end)
        else
            b.AutoButtonColor = false
        end
    end
end

RENDER.VipShop = function(panel)
    -- Shop v3 (Figma "Shop v3 FX"): sidebar that jumps to sections, one scrolling page, glowing cards.
    local L = layerOf(panel)
    clear(L)
    local SR = game:GetService("ReplicatedStorage"):FindFirstChild("ShopSystem")
    local remote = SR and SR:FindFirstChild("ShopRemote")
    local SC = SR and require(SR.ShopConfig)
    if not remote then
        text(box(L, 0.5, 0.5, 0.6, 0.08), "Shop is loading…")
        return
    end
    local ok, st = remote:InvokeServer("State")
    if not ok then
        text(box(L, 0.5, 0.5, 0.6, 0.08), tostring(st))
        return
    end
    local TS = game:GetService("TweenService")
    local RunS = game:GetService("RunService")
    local K, W1 = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
    local function c3(r, g, b)
        return Color3.fromRGB(r, g, b)
    end
    local PINK, GOLD, GREEN, BLUE, PURP, RED =
        c3(226, 66, 150), c3(248, 188, 44), c3(70, 190, 70), c3(60, 120, 235), c3(150, 90, 230), c3(226, 52, 60)
    local ICON = table.clone(SC.Icons or {})
    local SPARK = FX.sparkle
    local function corner(o, r)
        new("UICorner", { CornerRadius = UDim.new(0, r or 12) }, o)
    end
    local function lbl(parent, s, size, color, props)
        local l = new("TextLabel", {
            BackgroundTransparency = 1,
            Text = s,
            FontFace = FONT,
            TextSize = size,
            TextColor3 = color or W1,
            ZIndex = 14,
            Size = UDim2.new(1, 0, 0, size + 6),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
        }, parent)
        if props then
            for k, v in props do
                if k ~= "NoStroke" then
                    l[k] = v
                end
            end
        end
        if not (props and props.NoStroke) then
            new("UIStroke", { Color = K, Thickness = size >= 24 and 3 or 2, LineJoinMode = Enum.LineJoinMode.Round }, l)
        end
        return l
    end
    local function studs(f, t, tile)
        return new("ImageLabel", {
            Name = "Studs",
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = STUDS,
            ScaleType = Enum.ScaleType.Tile,
            TileSize = UDim2.fromOffset(tile or 24, tile or 24),
            ImageTransparency = t or 0.55,
            ZIndex = f.ZIndex,
        }, f)
    end
    _G.__shopPrices = _G.__shopPrices or {}
    local function live(id, pass, fallback)
        if not id or id == 0 then
            return fallback
        end
        local k = (pass and "p" or "d") .. id
        if _G.__shopPrices[k] == nil then -- never block the shop on a price lookup: show the config price now, the live one next open
            _G.__shopPrices[k] = false
            task.spawn(function()
                local ok2, info = pcall(
                    game:GetService("MarketplaceService").GetProductInfo,
                    game:GetService("MarketplaceService"),
                    id,
                    pass and Enum.InfoType.GamePass or Enum.InfoType.Product
                )
                _G.__shopPrices[k] = ok2 and info and info.PriceInRobux or false
            end)
        end
        return _G.__shopPrices[k] or fallback
    end
    local function price(key, pass)
        local id = pass and SC.GamePasses[key] or SC.Products[key]
        return "R$ " .. tostring(live(id, pass, SC.Prices[key]) or "?")
    end
    local function hms(s)
        s = math.max(0, math.floor(s))
        return string.format("%d:%02d:%02d", s // 3600, (s // 60) % 60, s % 60)
    end

    -- glowing studded card; returns face
    local function card(parent, color, size, pos, z)
        local holder = new(
            "Frame",
            { BackgroundTransparency = 1, Size = size, Position = pos or UDim2.new(), ZIndex = z or 9 },
            parent
        )
        local shadow = new("Frame", {
            BackgroundColor3 = K,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 6),
            Size = UDim2.fromScale(1, 1),
            ZIndex = holder.ZIndex,
        }, holder)
        corner(shadow, 14)
        local face = new("Frame", {
            Name = "Face",
            BackgroundColor3 = W1,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            ZIndex = holder.ZIndex + 1,
            ClipsDescendants = true,
        }, holder)
        corner(face, 14)
        new("UIGradient", { Rotation = 90, Color = ColorSequence.new(color:Lerp(W1, 0.12), color:Lerp(K, 0.22)) }, face)
        studs(face, 0.5)
        local sk = new("UIStroke", { Color = W1, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, face)
        local glow = new("ImageLabel", {
            Name = "Glow",
            BackgroundTransparency = 1,
            Image = FX.glow,
            ImageColor3 = color,
            ImageTransparency = 0.55,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, 60, 1, 60),
            ZIndex = holder.ZIndex - 1,
        }, holder)
        return face, holder, sk, glow
    end
    local function floaters(face, n, tint)
        for i = 1, n do
            local sp = new("ImageLabel", {
                BackgroundTransparency = 1,
                Image = SPARK,
                AnchorPoint = Vector2.new(0.5, 0.5),
                ImageColor3 = tint or W1,
                ImageTransparency = 1,
                ZIndex = face.ZIndex + 4,
            }, face)
            task.spawn(function()
                task.wait(math.random() * 2)
                while sp.Parent do
                    local sz = math.random(8, 15)
                    sp.Size = UDim2.fromOffset(sz, sz)
                    local x = 0.06 + math.random() * 0.88
                    sp.Position = UDim2.fromScale(x, 0.15 + math.random() * 0.75)
                    sp.ImageTransparency = 1
                    sp.Rotation = 0
                    TS:Create(sp, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { ImageTransparency = 0.1, Rotation = 45 })
                        :Play()
                    task.wait(0.6)
                    TS:Create(sp, TweenInfo.new(0.7, Enum.EasingStyle.Sine), { ImageTransparency = 1, Rotation = 90 })
                        :Play()
                    task.wait(0.8 + math.random() * 1.6)
                end
            end)
        end
    end
    local function burst()
        local host = new(
            "Frame",
            { Name = "BuyBurst", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 60 },
            L
        )
        local ring = new("ImageLabel", {
            BackgroundTransparency = 1,
            Image = FX.glow,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(40, 40),
            ImageColor3 = GOLD,
            ZIndex = 60,
        }, host)
        TS:Create(
            ring,
            TweenInfo.new(0.5, Enum.EasingStyle.Quad),
            { Size = UDim2.fromOffset(520, 520), ImageTransparency = 1 }
        ):Play()
        for i = 1, 24 do
            local coin = i % 3 ~= 0 and ICON.Coins
            local p = new("ImageLabel", {
                BackgroundTransparency = 1,
                Image = coin or SPARK,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(coin and 34 or 22, coin and 34 or 22),
                ScaleType = Enum.ScaleType.Fit,
                ZIndex = 61,
            }, host)
            local a = (i / 24) * math.pi * 2
            local d = 0.18 + math.random() * 0.2
            TS:Create(p, TweenInfo.new(0.6, Enum.EasingStyle.Quart), {
                Position = UDim2.fromScale(0.5 + math.cos(a) * d, 0.5 + math.sin(a) * d * 1.4),
                Rotation = math.random(-200, 200),
            }):Play()
            task.delay(0.55, function()
                if p.Parent then
                    TS:Create(p, TweenInfo.new(0.45), { ImageTransparency = 1 }):Play()
                end
            end)
        end
        task.delay(1.3, function()
            host:Destroy()
        end)
    end
    local function act2(action, ...)
        local r, msg = remote:InvokeServer(action, ...)
        if msg then
            say(msg)
        end
        if r then
            UISound.Play(
                (action and (string.find(action, "Buy") or string.find(action, "Purchase"))) and "Purchase" or "Claim"
            )
            pcall(burst)
        end
        RENDER.VipShop(panel)
    end
    -- green studded buy button with shine sweep
    local function buy(parent, label, size, pos, onClick, opts)
        opts = opts or {}
        local col = opts.color or GREEN
        local holder = new("Frame", {
            BackgroundTransparency = 1,
            Size = size,
            Position = pos,
            AnchorPoint = opts.anchor or Vector2.new(0, 0),
            ZIndex = parent.ZIndex + 2,
        }, parent)
        local base = new("Frame", {
            BackgroundColor3 = K,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 5),
            Size = UDim2.fromScale(1, 1),
            ZIndex = holder.ZIndex,
        }, holder)
        corner(base, 10)
        local face = new("TextButton", {
            BackgroundColor3 = W1,
            Text = "",
            AutoButtonColor = false,
            Size = UDim2.fromScale(1, 1),
            ZIndex = holder.ZIndex + 1,
            ClipsDescendants = true,
        }, holder)
        corner(face, 10)
        local enabled = opts.disabled ~= true
        local fc = enabled and col or c3(120, 128, 150)
        new("UIGradient", { Rotation = 90, Color = ColorSequence.new(fc:Lerp(W1, 0.25), fc:Lerp(K, 0.15)) }, face)
        studs(face, 0.55, 20)
        new("UIStroke", { Color = W1, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, face)
        new("Frame", {
            BackgroundColor3 = W1,
            BackgroundTransparency = 0.65,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(8, 4),
            Size = UDim2.new(1, -16, 0, 4),
            ZIndex = face.ZIndex + 1,
        }, face)
        lbl(
            face,
            label,
            opts.textSize or 20,
            W1,
            { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = face.ZIndex + 3 }
        )
        if enabled then
            local sh = new(
                "Frame",
                { BackgroundColor3 = W1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = face.ZIndex + 2 },
                face
            )
            local g = new("UIGradient", {
                Rotation = 20,
                Offset = Vector2.new(-1.2, 0),
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(0.42, 1),
                    NumberSequenceKeypoint.new(0.5, 0.45),
                    NumberSequenceKeypoint.new(0.58, 1),
                    NumberSequenceKeypoint.new(1, 1),
                }),
            }, sh)
            task.spawn(function()
                while sh.Parent do
                    g.Offset = Vector2.new(-1.2, 0)
                    TS:Create(g, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Offset = Vector2.new(1.2, 0) }):Play()
                    task.wait(2.6 + math.random())
                end
            end)
            local hs = new("UIScale", {}, holder)
            if opts.pulse then
                TS:Create(
                    hs,
                    TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                    { Scale = 1.04 }
                ):Play()
            end
            face.MouseEnter:Connect(function()
                UISound.Play("Hover")
                if not opts.pulse then
                    TS:Create(hs, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1.05 }):Play()
                end
            end)
            face.MouseLeave:Connect(function()
                if not opts.pulse then
                    TS:Create(hs, TweenInfo.new(0.1), { Scale = 1 }):Play()
                end
            end)
            face.MouseButton1Down:Connect(function()
                face.Position = UDim2.fromOffset(0, 3)
            end)
            face.MouseButton1Up:Connect(function()
                face.Position = UDim2.new()
            end)
            face.Activated:Connect(function()
                UISound.Play("Click")
                if onClick then
                    onClick()
                end
            end)
        end
        return face, holder
    end
    local function tag(parent, s, color, pos, anchor, textColor)
        local t = new("Frame", {
            AnchorPoint = anchor or Vector2.new(1, 0),
            Position = pos,
            Size = UDim2.fromOffset(0, 26),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = color,
            ZIndex = parent.ZIndex + 6,
        }, parent)
        corner(t, 8)
        new("UIStroke", { Color = K, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, t)
        new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, t)
        lbl(t, s, 14, textColor or W1, {
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            ZIndex = t.ZIndex + 1,
            TextXAlignment = Enum.TextXAlignment.Center,
            NoStroke = textColor ~= nil,
        })
        return t
    end
    local function icon(parent, img, pos, size, z, bob)
        if not img or img == "" then
            return
        end
        local im = new("ImageLabel", {
            BackgroundTransparency = 1,
            Image = img,
            ScaleType = Enum.ScaleType.Fit,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = pos,
            Size = size,
            ZIndex = z or parent.ZIndex + 3,
        }, parent)
        if bob then
            TS:Create(
                im,
                TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { Position = pos - UDim2.fromOffset(0, 5) }
            ):Play()
        end
        return im
    end

    -- ===== layout: sidebar + scrolling page =====
    local skin = new(
        "Frame",
        { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6, ClipsDescendants = true },
        L
    )
    local side = new("Frame", {
        Name = "ShopTabs",
        BackgroundColor3 = c3(20, 13, 43),
        BackgroundTransparency = 0.1,
        Position = UDim2.new(0.018, 0, 0.15, 16),
        Size = UDim2.new(0.18, 0, 0.85, -32),
        ZIndex = 9,
    }, skin)
    corner(side, 12)
    new("UIStroke", { Color = W1, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, side)
    new("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    }, side)
    new(
        "UIPadding",
        { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) },
        side
    )
    local sf = new("ScrollingFrame", {
        Position = UDim2.new(0.215, 0, 0.15, 10),
        Size = UDim2.new(0.77, 0, 0.85, -20),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 6,
        ScrollBarImageColor3 = c3(150, 120, 230),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ZIndex = 9,
    }, skin)
    new("UIListLayout", { Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder }, sf)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 12),
        PaddingBottom = UDim.new(0, 24),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 16),
    }, sf)
    local sections = {}
    local order = 0
    local function heading(s, key)
        order += 1
        local h = lbl(sf, s, 24, W1, { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 30), ZIndex = 12 })
        sections[key] = h
        return h
    end
    local function row(h)
        order += 1
        return new(
            "Frame",
            { BackgroundTransparency = 1, LayoutOrder = order, Size = UDim2.new(1, 0, 0, h), ZIndex = 10 },
            sf
        )
    end

    -- ===== FEATURED: limited deal =====
    local LD = SC.LimitedDeal
    sections.FEATURED = row(0)
    if LD then
        local r = row(250)
        local face, _, sk = card(r, PINK, UDim2.fromScale(1, 1))
        sk.Thickness = 5
        local sg = new("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, GOLD),
                ColorSequenceKeypoint.new(0.33, W1),
                ColorSequenceKeypoint.new(0.66, c3(255, 90, 200)),
                ColorSequenceKeypoint.new(1, c3(90, 220, 255)),
            }),
        }, sk)
        TS:Create(sg, TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 }):Play()
        tag(face, "🔥 LIMITED DEAL", RED, UDim2.fromOffset(14, 12), Vector2.new(0, 0))
        local eggBox = new("Frame", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.2, 0, 0.56, 0),
            Size = UDim2.fromOffset(190, 190),
            ZIndex = face.ZIndex + 1,
        }, face)
        -- soft halo behind the egg: two breathing glows + a slow ring of sparkles (replaces the hard rays)
        local halo = new("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(1.55, 1.55),
            BackgroundTransparency = 1,
            Image = FX.glow,
            ImageColor3 = c3(255, 160, 230),
            ImageTransparency = 0.15,
            ZIndex = eggBox.ZIndex,
        }, eggBox)
        TS:Create(
            halo,
            TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Size = UDim2.fromScale(1.75, 1.75), ImageTransparency = 0.35 }
        ):Play()
        local core = new("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.52),
            Size = UDim2.fromScale(1.05, 1.05),
            BackgroundTransparency = 1,
            Image = FX.glow,
            ImageColor3 = c3(255, 250, 215),
            ImageTransparency = 0,
            ZIndex = eggBox.ZIndex,
        }, eggBox)
        TS:Create(
            core,
            TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { ImageTransparency = 0.25 }
        ):Play()
        core.Size = UDim2.fromScale(1.3, 1.3)
        for _, sz in { 1.15, 0.95 } do
            new("ImageLabel", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.52),
                Size = UDim2.fromScale(sz, sz),
                BackgroundTransparency = 1,
                Image = FX.glow,
                ImageColor3 = c3(255, 255, 240),
                ZIndex = eggBox.ZIndex,
            }, eggBox)
        end -- stacked so the dark egg has a bright light behind it
        local ring = new("Frame", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(1.3, 1.3),
            ZIndex = eggBox.ZIndex,
        }, eggBox)
        for k = 1, 8 do
            local a = k / 8 * math.pi * 2
            local sp = new("ImageLabel", {
                BackgroundTransparency = 1,
                Image = FX.sparkle,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5 + math.cos(a) * 0.5, 0.5 + math.sin(a) * 0.5),
                Size = UDim2.fromOffset(k % 2 == 0 and 12 or 18, k % 2 == 0 and 12 or 18),
                ImageColor3 = k % 2 == 0 and W1 or c3(255, 225, 140),
                ZIndex = eggBox.ZIndex + 2,
            }, ring)
            TS:Create(
                sp,
                TweenInfo.new(0.7 + k * 0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { ImageTransparency = 0.8 }
            ):Play()
        end
        TS:Create(ring, TweenInfo.new(14, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
            :Play()
        local vp = new("ViewportFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            ZIndex = eggBox.ZIndex + 1,
            Ambient = c3(255, 255, 255),
            LightColor = c3(255, 255, 255),
            LightDirection = Vector3.new(-0.4, -0.6, -1),
        }, eggBox) -- bright so the dark egg reads
        local src = SR:FindFirstChild("ShopModels") and SR.ShopModels:FindFirstChild(LD.key)
        if src then
            local egg = src:Clone()
            egg.Parent = vp
            local cf, size = egg:GetBoundingBox()
            egg:PivotTo(CFrame.new(-cf.Position) * egg:GetPivot())
            local cam = new("Camera", { FieldOfView = 40 }, vp)
            vp.CurrentCamera = cam
            cam.CFrame = CFrame.lookAt(Vector3.new(0, size.Y * 0.08, -size.Magnitude * 1.2), Vector3.zero)
            local b0 = egg:GetPivot()
            local t0 = os.clock()
            local conn
            conn = RunS.RenderStepped:Connect(function()
                if not vp.Parent then
                    conn:Disconnect()
                    return
                end
                local t = os.clock() - t0
                egg:PivotTo(CFrame.new(0, math.sin(t * 2) * 0.25, 0) * CFrame.Angles(0, t * 0.9, 0) * b0)
            end)
        end
        local info = new("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0.4, 0, 0, 22),
            Size = UDim2.new(0.57, 0, 1, -30),
            ZIndex = face.ZIndex + 1,
        }, face)
        lbl(info, LD.name, 38, W1, { Size = UDim2.new(1, 0, 0, 44) })
        lbl(info, LD.text, 16, c3(255, 225, 240), { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 46) })
        -- countdown boxes
        local cd = new("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 78),
            Size = UDim2.new(1, 0, 0, 64),
            ZIndex = info.ZIndex,
        }, info)
        new("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, cd)
        local nums = {}
        for i, unit in { "DAYS", "HRS", "MIN", "SEC" } do
            local b = new("Frame", {
                LayoutOrder = i,
                BackgroundColor3 = c3(20, 14, 40),
                Size = UDim2.fromOffset(66, 64),
                ZIndex = cd.ZIndex + 1,
            }, cd)
            corner(b, 10)
            new("UIStroke", { Color = W1, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
            nums[i] = lbl(b, "00", 28, GOLD, {
                Size = UDim2.new(1, 0, 0, 38),
                Position = UDim2.fromOffset(0, 2),
                TextXAlignment = Enum.TextXAlignment.Center,
                ZIndex = b.ZIndex + 1,
            })
            lbl(b, unit, 11, c3(200, 190, 230), {
                Size = UDim2.new(1, 0, 0, 16),
                Position = UDim2.fromOffset(0, 42),
                TextXAlignment = Enum.TextXAlignment.Center,
                ZIndex = b.ZIndex + 1,
                NoStroke = true,
            })
        end
        task.spawn(function()
            while nums[1].Parent and panel.Visible do
                local s = math.max(0, LD.endsAt - os.time())
                nums[1].Text = string.format("%02d", s // 86400)
                nums[2].Text = string.format("%02d", (s // 3600) % 24)
                nums[3].Text = string.format("%02d", (s // 60) % 60)
                nums[4].Text = string.format("%02d", s % 60)
                task.wait(1)
            end
        end)
        local id = SC.Products[LD.key]
        buy(
            info,
            SC.Prices[LD.key] and ("BUY  R$ " .. live(id, false, SC.Prices[LD.key])) or "SOON",
            UDim2.fromOffset(260, 58),
            UDim2.new(1, -4, 1, -8),
            function()
                act2("Buy", LD.key)
            end,
            { anchor = Vector2.new(1, 1), textSize = 24, pulse = true }
        )
        floaters(face, 9, c3(255, 235, 160))
    end

    -- ===== BOOSTS =====
    heading("BOOSTS", "BOOSTS")
    local br = row(160)
    local function boostCard(i, n, title, desc, key, color, img, untilT, pass, owned)
        local face = card(br, color, UDim2.new(1 / n, -10, 1, 0), UDim2.new((i - 1) / n, 5, 0, 0))
        icon(face, img, UDim2.new(0, 56, 0.5, -8), UDim2.fromOffset(84, 84), nil, true)
        lbl(
            face,
            title,
            22,
            W1,
            { Position = UDim2.fromOffset(108, 12), Size = UDim2.new(1, -116, 0, 28), TextScaled = true }
        )
        local dl = lbl(
            face,
            desc,
            13,
            c3(240, 240, 255),
            { Position = UDim2.fromOffset(108, 42), Size = UDim2.new(1, -116, 0, 34), NoStroke = true }
        )
        if untilT and untilT > st.serverTime then
            local tr = new("Frame", {
                BackgroundColor3 = c3(13, 10, 20),
                Position = UDim2.fromOffset(108, 84),
                Size = UDim2.new(1, -124, 0, 16),
                ZIndex = face.ZIndex + 2,
            }, face)
            corner(tr, 8)
            new("UIStroke", { Color = W1, Thickness = 2 }, tr)
            local f = new(
                "Frame",
                { BackgroundColor3 = W1, BorderSizePixel = 0, Size = UDim2.fromScale(0.5, 1), ZIndex = tr.ZIndex + 1 },
                tr
            )
            corner(f, 8)
            new("UIGradient", { Color = ColorSequence.new(c3(150, 255, 120), c3(60, 200, 60)) }, f)
            local al =
                lbl(face, "", 13, W1, { Position = UDim2.fromOffset(108, 104), Size = UDim2.new(1, -116, 0, 18) })
            local t0 = os.clock()
            task.spawn(function()
                while al.Parent and panel.Visible do
                    local left = untilT - (st.serverTime + os.clock() - t0)
                    f.Size = UDim2.fromScale(math.clamp(left / ((SC.BoostMinutes or 30) * 60), 0.03, 1), 1)
                    al.Text = left > 0 and ("ACTIVE " .. hms(left)) or "ENDED"
                    task.wait(1)
                end
            end)
        end
        buy(
            face,
            owned and "OWNED" or price(key, pass),
            UDim2.fromOffset(140, 44),
            UDim2.new(1, -14, 1, -14),
            (not owned) and function()
                act2("Buy", key)
            end or nil,
            { anchor = Vector2.new(1, 1), disabled = owned, textSize = 18 }
        )
        floaters(face, 3)
        return dl
    end
    boostCard(
        1,
        3,
        "2× MONEY",
        SC.BoostMinutes .. " min of double cash",
        "Money2x",
        GREEN,
        ICON.Money2x,
        st.money2xUntil
    )
    boostCard(2, 3, "2× HATCH", "Eggs hatch twice as fast", "Hatch2x", GOLD, ICON.Hatch2x, st.hatch2xUntil)
    boostCard(
        3,
        3,
        "STARTER PACK",
        "$" .. Config.Short(SC.StarterPack.cash) .. " + " .. SC.StarterPack.boostMinutes .. " min 2× money & hatch",
        "StarterPack",
        PURP,
        ICON.StarterPack,
        nil,
        true,
        st.starter
    )

    -- ===== PASSES: VIP + money multiplier =====
    heading("PASSES", "PASSES")
    local pr = row(170)
    do
        local face = card(pr, PURP, UDim2.new(0.5, -8, 1, 0), UDim2.fromScale(0, 0))
        icon(face, ICON.Crown, UDim2.new(0, 70, 0.5, 0), UDim2.fromOffset(110, 110), nil, true)
        lbl(face, "VIP", 34, GOLD, { Position = UDim2.fromOffset(136, 12), Size = UDim2.new(1, -144, 0, 40) })
        lbl(
            face,
            "Crown + gold chat tag\n+10% cash · 2× daily cash",
            14,
            c3(235, 225, 255),
            { Position = UDim2.fromOffset(136, 54), Size = UDim2.new(1, -144, 0, 40), NoStroke = true }
        )
        buy(
            face,
            st.vip and "OWNED" or price("VIP", true),
            UDim2.fromOffset(170, 50),
            UDim2.new(1, -14, 1, -14),
            (not st.vip) and function()
                act2("Buy", "VIP")
            end or nil,
            { anchor = Vector2.new(1, 1), disabled = st.vip, color = GOLD, textSize = 20 }
        )
        floaters(face, 4, c3(255, 230, 140))
    end
    do
        local lvl = st.moneyLevel or 0
        local cur = lvl > 0 and SC.MoneyLevels[lvl].mult or 1
        local nxt = SC.MoneyLevels[lvl + 1]
        local face = card(pr, GREEN, UDim2.new(0.5, -8, 1, 0), UDim2.new(0.5, 8, 0, 0))
        icon(face, ICON.Coins, UDim2.new(0, 64, 0.5, -6), UDim2.fromOffset(96, 96), nil, true)
        lbl(
            face,
            "MONEY MULTIPLIER",
            20,
            W1,
            { Position = UDim2.fromOffset(124, 12), Size = UDim2.new(1, -132, 0, 26) }
        )
        lbl(
            face,
            nxt and (cur .. "×  →  " .. nxt.mult .. "×") or (cur .. "×  MAXED!"),
            28,
            c3(200, 255, 170),
            { Position = UDim2.fromOffset(124, 42), Size = UDim2.new(1, -132, 0, 34) }
        )
        local pips = new("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(124, 82),
            Size = UDim2.new(1, -132, 0, 16),
            ZIndex = face.ZIndex + 2,
        }, face)
        new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }, pips)
        for i = 1, #SC.MoneyLevels do
            local p = new("Frame", {
                BackgroundColor3 = i <= lvl and GOLD or c3(30, 60, 30),
                Size = UDim2.fromOffset(14, 14),
                ZIndex = pips.ZIndex,
            }, pips)
            corner(p, 4)
            new("UIStroke", { Color = K, Thickness = 1.5 }, p)
        end
        if nxt then
            buy(
                face,
                nxt.productId == 0 and "SOON" or ("R$ " .. live(nxt.productId, false, nxt.robux)),
                UDim2.fromOffset(150, 46),
                UDim2.new(1, -14, 1, -14),
                function()
                    act2("BuyMoneyLevel")
                end,
                { anchor = Vector2.new(1, 1), textSize = 20 }
            )
        end
        floaters(face, 3)
    end

    -- ===== CASH PACKS =====
    heading("CASH PACKS", "CASH")
    local cr = row(210)
    local keys = { "CashSmall", "CashMedium", "CashLarge" }
    local function rbx(k)
        return tonumber(live(SC.Products[k], false, SC.Prices[k])) or SC.Prices[k] or 1
    end
    local baseRate = (SC.CashPacks.CashSmall or 1) / math.max(rbx("CashSmall"), 1)
    for i, k in keys do
        local col = ({ BLUE, GOLD, BLUE })[i]
        local face, _, sk, gl = card(cr, col, UDim2.new(1 / 3, -10, 1, 0), UDim2.new((i - 1) / 3, 5, 0, 0))
        local amount = SC.CashPacks[k] or 0
        local n = ({ 1, 3, 6 })[i]
        for c = 1, n do
            icon(
                face,
                ICON.Coins,
                UDim2.new(0.5, (c - (n + 1) / 2) * 22, 0, 60 - (c % 2) * 8),
                UDim2.fromOffset(46, 46),
                face.ZIndex + 3 + c
            )
        end
        lbl(face, "$" .. Config.Short(amount), 32, c3(150, 255, 120), {
            Position = UDim2.fromOffset(0, 96),
            Size = UDim2.new(1, 0, 0, 38),
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        local rate = amount / math.max(rbx(k), 1)
        local bonus = math.floor((rate / baseRate - 1) * 100 + 0.5)
        if i == 2 then
            tag(face, "MOST POPULAR", RED, UDim2.new(1, -10, 0, 10))
            sk.Color = c3(255, 90, 100)
            TS:Create(
                sk,
                TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { Thickness = 5 }
            ):Play()
            gl.ImageColor3 = c3(255, 90, 100)
        elseif bonus > 0 then
            tag(face, "+" .. bonus .. "% MORE", GOLD, UDim2.new(1, -10, 0, 10), nil, K)
        end
        buy(
            face,
            SC.Products[k] == 0 and "SOON" or price(k),
            UDim2.new(1, -28, 0, 50),
            UDim2.new(0.5, 0, 1, -14),
            function()
                act2("Buy", k)
            end,
            { anchor = Vector2.new(0.5, 1), textSize = 22 }
        )
        floaters(face, 3 + i, c3(255, 240, 160))
    end

    -- ===== DAILY REWARDS =====
    heading("DAILY REWARDS", "DAILY")
    local d = st.daily
    local dr = row(220)
    local df = card(dr, BLUE, UDim2.fromScale(1, 1))
    for i, r in SC.Daily do
        local claimed = (i < d.day) or (i == d.day and not d.ready)
        local today = i == d.day and d.ready
        local col = today and GOLD or (i == 7 and RED or c3(42, 31, 74))
        local t = card(df, col, UDim2.new(1 / 7, -10, 0, 128), UDim2.new((i - 1) / 7, 5, 0, 16), df.ZIndex + 1)
        lbl(t, "DAY " .. i, 14, W1, {
            Position = UDim2.fromOffset(0, 6),
            Size = UDim2.new(1, 0, 0, 18),
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        local key = r.kind == "cash" and "Coins"
            or r.kind == "mystery" and (ICON.Chalice and "Chalice" or "Chest")
            or r.boost
        icon(t, ICON[key], UDim2.new(0.5, 0, 0, 54), UDim2.fromOffset(44, 44), nil, today)
        lbl(
            t,
            r.label or ("$" .. Config.Short(r.amount)),
            13,
            r.kind == "cash" and c3(150, 255, 120) or c3(230, 200, 255),
            {
                Position = UDim2.fromOffset(2, 80),
                Size = UDim2.new(1, -4, 0, 28),
                TextXAlignment = Enum.TextXAlignment.Center,
            }
        )
        lbl(t, claimed and "✓" or (today and "READY" or "🔒"), 13, claimed and GREEN or W1, {
            Position = UDim2.new(0, 0, 1, -22),
            Size = UDim2.new(1, 0, 0, 18),
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        if today then
            local s2 = t:FindFirstChildOfClass("UIStroke")
            if s2 then
                TS:Create(
                    s2,
                    TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                    { Thickness = 5 }
                ):Play()
            end
        end
    end
    if d.ready then
        buy(df, "CLAIM DAY " .. d.day, UDim2.fromOffset(260, 46), UDim2.new(0.5, 0, 1, -12), function()
            act2("ClaimDaily")
        end, { anchor = Vector2.new(0.5, 1), textSize = 20, pulse = true })
    else
        local nl = lbl(df, "Next reward in " .. hms(d.nextIn), 17, c3(220, 225, 255), {
            Position = UDim2.new(0, 0, 1, -40),
            Size = UDim2.new(1, 0, 0, 24),
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        local endAt = os.clock() + d.nextIn
        task.spawn(function()
            while nl.Parent and panel.Visible do
                nl.Text = "Next reward in " .. hms(endAt - os.clock())
                task.wait(1)
            end
        end)
    end

    -- ===== sidebar tabs: jump to a section =====
    local TABS = {
        { "FEATURED", ICON.Fire or ICON.StarterPack, PINK },
        { "BOOSTS", ICON.Money2x, GREEN },
        { "PASSES", ICON.Crown, PURP },
        { "CASH", ICON.Coins, GOLD },
        { "DAILY", ICON.Chest, BLUE },
    }
    local tabFaces = {}
    local function setActive(name)
        for n, f in tabFaces do
            local on = n == name
            f.face.BackgroundColor3 = on and f.color or c3(53, 40, 98)
            f.stroke.Thickness = on and 4 or 2.5
        end
    end
    for i, tdef in TABS do
        local h = new("TextButton", {
            LayoutOrder = i,
            Text = "",
            AutoButtonColor = false,
            BackgroundColor3 = c3(53, 40, 98),
            Size = UDim2.new(1, 0, 0, 58),
            ZIndex = 11,
        }, side)
        corner(h, 10)
        studs(h, 0.65, 20)
        local s2 = new("UIStroke", { Color = W1, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, h)
        icon(h, tdef[2], UDim2.new(0, 28, 0.5, 0), UDim2.fromOffset(38, 38), 13)
        lbl(h, tdef[1], 16, W1, { Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -56, 1, 0), ZIndex = 13 })
        tabFaces[tdef[1]] = { face = h, stroke = s2, color = tdef[3] }
        if tdef[1] == "DAILY" and d.ready then
            local b = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(1, -6, 0, 6),
                Size = UDim2.fromOffset(24, 24),
                BackgroundColor3 = RED,
                ZIndex = 15,
            }, h)
            corner(b, 12)
            new("UIStroke", { Color = W1, Thickness = 2 }, b)
            lbl(
                b,
                "!",
                16,
                W1,
                { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 16 }
            )
            local bs = new("UIScale", {}, b)
            TS:Create(
                bs,
                TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { Scale = 1.2 }
            ):Play()
        end
        local sc = new("UIScale", {}, h)
        h.MouseEnter:Connect(function()
            UISound.Play("Hover")
            TS:Create(sc, TweenInfo.new(0.1), { Scale = 1.05 }):Play()
        end)
        h.MouseLeave:Connect(function()
            TS:Create(sc, TweenInfo.new(0.1), { Scale = 1 }):Play()
        end)
        h.Activated:Connect(function()
            UISound.Play("Click")
            local target = sections[tdef[1]]
            if target then
                local y = target.AbsolutePosition.Y - sf.AbsolutePosition.Y + sf.CanvasPosition.Y - 8
                TS:Create(
                    sf,
                    TweenInfo.new(0.35, Enum.EasingStyle.Quad),
                    { CanvasPosition = Vector2.new(0, math.max(0, y)) }
                ):Play()
            end
            setActive(tdef[1])
        end)
    end
    setActive("FEATURED")
    sf:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        local best, bestY = "FEATURED", -math.huge
        for _, tdef in TABS do
            local s = sections[tdef[1]]
            if s then
                local y = s.AbsolutePosition.Y - sf.AbsolutePosition.Y
                if y <= 40 and y > bestY then
                    best, bestY = tdef[1], y
                end
            end
        end
        setActive(best)
    end)
end

local plotPage = "overview" -- "overview" | "upgrades"
local SLOT_PRICES =
    { 0, 250, 2500, 25000, 150000, 750000, 5000000, 25000000, 150000000, 750000000, 3000000000, 15000000000 }

local function myPlot()
    for _, p in workspace.Plots:GetChildren() do
        if p:GetAttribute("OwnerUserId") == player.UserId then
            return p
        end
    end
end

-- page switch tab on top of the panel
local function tabs(L, panel)
    local bar = box(L, 0.5, 0.235, 0.9, 0.065)
    bar.Name = "PlotTabs"
    local function tab(x, label, page)
        local on = plotPage == page
        local b =
            button(bar, x, 0.5, 0.48, 1, label, on and Color3.fromRGB(214, 52, 45) or Color3.fromRGB(150, 120, 100))
        b.Name = page == "upgrades" and "UpgradesTab" or "OverviewTab"
        b.Activated:Connect(function()
            if plotPage ~= page then
                plotPage = page
                RENDER.Plot(panel)
            end
        end)
    end
    tab(0.25, "OVERVIEW", "overview")
    tab(0.75, "UPGRADES", "upgrades")
end

local function overview(L, data)
    local plot = myPlot()
    local placed, stored, income = {}, 0, 0
    for _, it in data.items or {} do
        if it.state == "placed" then
            table.insert(placed, it)
            income += it.income or 0
        else
            stored += 1
        end
    end
    local level = data.level or 1
    local cap = data.availableSlots or level * 12
    local unlocked = data.unlocked or 0
    local RED = Color3.fromRGB(188, 57, 44)
    local MUTED = Color3.fromRGB(170, 195, 205)
    local PAPER = Color3.fromRGB(34, 58, 70)
    local sheet = box(L, 0.5, 0.615, 0.9, 0.65, { BackgroundTransparency = 0, BackgroundColor3 = CREAM, ZIndex = 7 })
    sheet.Name = "PlotContent"
    new("UICorner", { CornerRadius = UDim.new(0, 14) }, sheet)
    local scroll = new("ScrollingFrame", {
        Name = "Sections",
        Size = UDim2.new(1, -8, 1, -8),
        Position = UDim2.fromOffset(4, 4),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Color3.fromRGB(75, 125, 145),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ZIndex = 8,
    }, sheet)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 5),
        PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 8),
    }, scroll)
    new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
    local order = 0
    local function section(name, height)
        order += 1
        local f = new("Frame", {
            Name = name,
            LayoutOrder = order,
            Size = UDim2.new(1, 0, 0, height),
            BackgroundColor3 = PAPER,
            BorderSizePixel = 0,
            ZIndex = 8,
        }, scroll)
        new("UIStroke", {
            Color = Color3.new(0, 0, 0),
            Thickness = 3,
            LineJoinMode = Enum.LineJoinMode.Miter,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, f)
        new("Frame", {
            Name = "Accent",
            BackgroundColor3 = SKINS.Plot.grad[1],
            BorderSizePixel = 0,
            Size = UDim2.new(0, 6, 1, 0),
            ZIndex = 9,
        }, f)
        return f
    end
    local function label(parent, str, x, y, w, h, size, color)
        return text(parent, str, color or INK, {
            Position = UDim2.new(x, 0, 0, y),
            Size = UDim2.new(w, 0, 0, h),
            X = Enum.TextXAlignment.Left,
            Max = size,
            ZIndex = 10,
        })
    end
    local function action(parent, name, x, y, w, h, labelText, color, callback)
        local b = new("TextButton", {
            Name = name,
            AnchorPoint = Vector2.new(0, 0),
            Position = UDim2.new(x, 0, 0, y),
            Size = UDim2.new(w, 0, 0, h),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 10,
        }, parent)
        new("UIStroke", {
            Color = Color3.new(0, 0, 0),
            Thickness = 2.5,
            LineJoinMode = Enum.LineJoinMode.Miter,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, b)
        local t = text(
            b,
            labelText,
            Color3.new(1, 1, 1),
            { Position = UDim2.new(0, 7, 0, 4), Size = UDim2.new(1, -14, 1, -8), Max = 16, ZIndex = 11 }
        )
        b.MouseEnter:Connect(function()
            UISound.Play("Hover")
            TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.1) })
                :Play()
        end)
        b.MouseLeave:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = color }):Play()
        end)
        if callback then
            b.Activated:Connect(function()
                UISound.Play("Click")
                callback()
            end)
        else
            b.Interactable = false
        end
        return b
    end
    local hero = section("TempleSummary", 86)
    label(hero, "TEMPLE  /  LEVEL " .. level, 0.035, 12, 0.59, 25, 23)
    label(
        hero,
        level >= 3 and "Your temple is fully upgraded" or "Unlock every slot to open the next floor",
        0.035,
        44,
        0.59,
        25,
        14,
        MUTED
    )
    action(
        hero,
        "UpgradeTemple",
        0.66,
        23,
        0.305,
        40,
        level >= 3 and "MAX LEVEL"
            or data.canUpgrade and ("UPGRADE $" .. Config.Short(
                require(game.ReplicatedStorage.UpgradePrices).Temple[level + 1]
            ))
            or unlocked .. " / " .. cap .. " SLOTS",
        data.canUpgrade and RED or Color3.fromRGB(70, 92, 104),
        level < 3
                and function()
                    if data.canUpgrade then
                        act("UpgradeTemple")
                    else
                        say("Unlock all " .. cap .. " slots to open the next floor")
                    end
                end
            or nil
    )
    local stats = section("Stats", 58)
    for i, v in
        {
            { title = "INCOME / SEC", value = "$" .. Config.Short(income), color = Color3.fromRGB(60, 137, 65) },
            { title = "CHARACTERS PLACED", value = #placed .. " / " .. unlocked },
            { title = "IN BACKPACK", value = tostring(stored) },
        }
    do
        local x = 0.035 + (i - 1) * 0.325
        label(stats, v.title, x, 7, 0.3, 17, 11, MUTED)
        label(stats, v.value, x, 25, 0.3, 25, 22, v.color)
    end
    local incubators = section("Incubators", 150)
    label(incubators, "INCUBATORS", 0.035, 10, 0.8, 24, 18)
    local chambers = plot and plot:FindFirstChild("Chambers")
    local count = chambers and #chambers:GetChildren() or 0
    for i = 1, 3 do
        local x = 0.035 + (i - 1) * 0.325
        local f = new("Frame", {
            Name = "Incubator" .. i,
            Position = UDim2.new(x, 0, 0, 43),
            Size = UDim2.new(0.305, 0, 0, 95),
            BackgroundColor3 = Color3.fromRGB(40, 66, 80),
            BorderSizePixel = 0,
            ZIndex = 9,
        }, incubators)
        new("UICorner", { CornerRadius = UDim.new(0, 8) }, f)
        local chamber = chambers and chambers:FindFirstChild("Chamber" .. i)
        local lv = chamber and (chamber:GetAttribute("UpgradeLevel") or 1)
        label(f, "#" .. i .. (lv and "   LEVEL " .. lv or "   LOCKED"), 0.07, 6, 0.88, 20, 15)
        local status = chamber and tostring(chamber:GetAttribute("Status") or "Ready")
            or (i == count + 1 and "Expand your hatchery" or "Buy the previous incubator")
        label(f, status, 0.07, 29, 0.88, 18, 12, MUTED)
        if chamber then
            action(
                f,
                "UpgradeIncubator" .. i,
                0.07,
                55,
                0.86,
                31,
                lv < 3
                        and ("UPGRADE $" .. Config.Short(
                            require(game.ReplicatedStorage.UpgradePrices).IncubatorLevel[lv + 1]
                        ))
                    or "MAX LEVEL",
                lv < 3 and RED or MUTED,
                lv < 3
                        and function()
                            act("UpgradeIncubator", { index = i })
                        end
                    or nil
            )
        elseif i == count + 1 then
            action(
                f,
                "AddIncubator",
                0.07,
                55,
                0.86,
                31,
                "+ ADD $" .. Config.Short(require(game.ReplicatedStorage.UpgradePrices).AddIncubator[i]),
                Color3.fromRGB(70, 151, 74),
                function()
                    act("AddIncubator")
                end
            )
        end
    end
    local slots = section("CharacterSlots", 168)
    label(slots, "CHARACTER SLOTS", 0.035, 10, 0.6, 24, 18)
    label(slots, unlocked .. " / " .. cap .. " unlocked", 0.67, 12, 0.3, 20, 14, MUTED)
    local nextPrice
    for i = 1, cap do
        local sl = plot and plot.Slots:FindFirstChild(string.format("Slot%02d", i))
        if sl and not sl:GetAttribute("Unlocked") then
            nextPrice = sl:GetAttribute("UnlockPrice")
            break
        end
    end
    local track = new("Frame", {
        Position = UDim2.new(0.035, 0, 0, 43),
        Size = UDim2.new(0.93, 0, 0, 6),
        BackgroundColor3 = Color3.fromRGB(20, 30, 36),
        BorderSizePixel = 0,
        ZIndex = 9,
    }, slots)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
    local fill = new("Frame", {
        Size = UDim2.fromScale(math.clamp(unlocked / cap, 0, 1), 1),
        BackgroundColor3 = Color3.fromRGB(91, 163, 80),
        BorderSizePixel = 0,
        ZIndex = 10,
    }, track)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
    label(
        slots,
        #placed .. " working  ·  " .. math.max(0, unlocked - #placed) .. " empty",
        0.035,
        56,
        0.53,
        22,
        15,
        MUTED
    )
    action(
        slots,
        "UnlockSlot",
        0.60,
        56,
        0.365,
        34,
        nextPrice and "UNLOCK  $" .. Config.Short(nextPrice) or "ALL UNLOCKED",
        nextPrice and Color3.fromRGB(70, 151, 74) or MUTED,
        nextPrice and function()
            act("UnlockSlot")
        end or nil
    )
    local list = new("ScrollingFrame", {
        Name = "PlacedCharacters",
        Position = UDim2.new(0.035, 0, 0, 101),
        Size = UDim2.new(0.93, 0, 0, 55),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        ScrollingDirection = Enum.ScrollingDirection.X,
        ZIndex = 9,
    }, slots)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, list)
    table.sort(placed, function(a, b)
        return (a.income or 0) > (b.income or 0)
    end)
    if #placed == 0 then
        label(list, "Place a character to start earning cash.", 0, 7, 1, 28, 14, MUTED)
    else
        for i, it in placed do
            local f = new("Frame", {
                Name = "Character" .. i,
                LayoutOrder = i,
                Size = UDim2.fromOffset(145, 46),
                BackgroundColor3 = Color3.fromRGB(40, 66, 80),
                BorderSizePixel = 0,
                ZIndex = 10,
            }, list)
            new("UICorner", { CornerRadius = UDim.new(0, 7) }, f)
            label(f, it.name, 0.06, 3, 0.88, 20, 14, RARITY[it.rarity] or INK)
            label(f, "$" .. Config.Short(it.income or 0) .. "/sec", 0.06, 24, 0.88, 16, 12, Color3.fromRGB(60, 137, 65))
        end
    end
    local footer = section("QuickActions", 48)
    label(footer, "Put your strongest characters to work", 0.035, 10, 0.59, 28, 14, MUTED)
    action(footer, "EquipBest", 0.66, 7, 0.305, 34, "EQUIP BEST", Color3.fromRGB(66, 126, 177), function()
        act("EquipBest")
    end)
    task.defer(function()
        if scroll.Parent then
            scroll.CanvasPosition = Vector2.zero
        end
    end)
end

local function upgrades(L, data)
    -- cover the baked overview art inside the panel with one clean cream sheet
    local sheet = box(
        L,
        0.5,
        0.57,
        0.9,
        0.55,
        { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(26, 44, 52), ZIndex = 7 }
    )
    new("UICorner", { CornerRadius = UDim.new(0.06, 0) }, sheet)
    new("UIStroke", { Color = Color3.fromRGB(205, 170, 120), Thickness = 2 }, sheet)
    local cover = box(
        L,
        0.496,
        0.887,
        0.27,
        0.105,
        { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(26, 44, 52), ZIndex = 7 }
    )
    new("UICorner", { CornerRadius = UDim.new(0.4, 0) }, cover)
    text(cover, "Upgrades work from anywhere on your plot", Color3.fromRGB(150, 115, 90), {
        Size = UDim2.fromScale(0.95, 0.42),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Max = 14,
    })
    local function row(y, title)
        local r = box(
            sheet,
            0.5,
            y,
            0.94,
            0.27,
            { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(34, 58, 70), ZIndex = 8 }
        )
        new("UICorner", { CornerRadius = UDim.new(0.2, 0) }, r)
        text(r, title, Color3.fromRGB(200, 60, 45), {
            Size = UDim2.fromScale(0.24, 0.32),
            Position = UDim2.fromScale(0.02, 0.06),
            X = Enum.TextXAlignment.Left,
            ZIndex = 9,
            Max = 18,
        })
        return r
    end
    local plot = myPlot()

    -- TEMPLE
    local t = row(0.17, "TEMPLE")
    t.Name = "TempleUpgrades"
    local lv = data.level or 1
    for i = 1, 3 do
        local pip = box(t, 0.06 + i * 0.075, 0.66, 0.06, 0.36, {
            BackgroundTransparency = 0,
            BackgroundColor3 = i <= lv and Color3.fromRGB(235, 175, 30) or Color3.fromRGB(50, 70, 80),
            ZIndex = 9,
        })
        new("UICorner", { CornerRadius = UDim.new(0.3, 0) }, pip)
        new("UIStroke", { Color = INK, Thickness = 2 }, pip)
    end
    text(t, "Level " .. lv .. " / 3", INK, {
        Size = UDim2.fromScale(0.3, 0.4),
        Position = UDim2.fromScale(0.33, 0.45),
        X = Enum.TextXAlignment.Left,
        ZIndex = 9,
    })
    if lv < 3 then
        local allowed = data.canUpgrade == true
        local cost = require(game.ReplicatedStorage.UpgradePrices).Temple[lv + 1]
        local b = button(
            t,
            0.84,
            0.5,
            0.26,
            0.62,
            allowed and ("UPGRADE • $" .. Config.Short(cost)) or "BUY ALL SLOTS",
            allowed and Color3.fromRGB(214, 52, 45) or Color3.fromRGB(70, 92, 104)
        )
        b.Interactable = allowed
        if not allowed then
            text(
                t,
                "Buy every current slot first",
                Color3.fromRGB(150, 90, 60),
                { Size = UDim2.fromScale(0.5, 0.22), Position = UDim2.fromScale(0.3, 0.06), ZIndex = 9, Max = 13 }
            )
        end
        b.Activated:Connect(function()
            act("UpgradeTemple")
        end)
    else
        text(
            t,
            "MAX",
            Color3.fromRGB(235, 175, 30),
            { Stroke = 2, Size = UDim2.fromScale(0.2, 0.5), Position = UDim2.fromScale(0.74, 0.25), ZIndex = 9 }
        )
    end

    -- INCUBATORS
    local ir = row(0.5, "INCUBATORS")
    ir.Name = "IncubatorUpgrades"
    local chambers = plot and plot:FindFirstChild("Chambers")
    local count = chambers and #chambers:GetChildren() or 0
    for i = 1, 3 do
        local c = chambers and chambers:FindFirstChild("Chamber" .. i)
        local card = box(
            ir,
            0.36 + (i - 1) * 0.215,
            0.62,
            0.2,
            0.62,
            { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(26, 44, 52), ZIndex = 9 }
        )
        new("UICorner", { CornerRadius = UDim.new(0.2, 0) }, card)
        new("UIStroke", { Color = Color3.fromRGB(205, 170, 120), Thickness = 2 }, card)
        if c then
            local l = c:GetAttribute("UpgradeLevel") or 1
            text(card, "#" .. i .. "  LV " .. l, INK, {
                Size = UDim2.fromScale(0.38, 0.5),
                Position = UDim2.fromScale(0.04, 0.25),
                X = Enum.TextXAlignment.Left,
                ZIndex = 10,
                Max = 16,
            })
            if l < 3 then
                local b = button(card, 0.71, 0.5, 0.52, 0.72, "UPGRADE", Color3.fromRGB(214, 52, 45))
                b.ZIndex = 10
                b.Activated:Connect(function()
                    act("UpgradeIncubator", { index = i })
                end)
            else
                text(card, "MAX", Color3.fromRGB(235, 175, 30), {
                    Stroke = 1.5,
                    Size = UDim2.fromScale(0.35, 0.5),
                    Position = UDim2.fromScale(0.6, 0.25),
                    ZIndex = 10,
                })
            end
        elseif i == count + 1 then
            local b = button(card, 0.5, 0.5, 0.8, 0.7, "+ ADD INCUBATOR", GREEN)
            b.Activated:Connect(function()
                act("AddIncubator")
            end)
        else
            text(card, "LOCKED", GREY, {
                Size = UDim2.fromScale(0.6, 0.45),
                Position = UDim2.fromScale(0.5, 0.5),
                AnchorPoint = Vector2.new(0.5, 0.5),
                ZIndex = 10,
            })
        end
    end

    -- CHARACTER SLOTS
    local sr = row(0.83, "CHARACTER SLOTS")
    local unlocked, nextPrice = 0, nil
    local cap = data.availableSlots or (lv * 12)
    for i = 1, cap do
        local s = plot and plot.Slots:FindFirstChild(string.format("Slot%02d", i))
        local on = s and s:GetAttribute("Unlocked")
        if on then
            unlocked += 1
        elseif not nextPrice then
            nextPrice = s and s:GetAttribute("UnlockPrice") or SLOT_PRICES[i]
        end
        local pip = box(
            sr,
            0.05 + i * (0.516 / cap),
            0.68,
            (0.408 / cap),
            0.34,
            { BackgroundTransparency = 0, BackgroundColor3 = on and GREEN or Color3.fromRGB(50, 70, 80), ZIndex = 9 }
        )
        new("UICorner", { CornerRadius = UDim.new(0.3, 0) }, pip)
        new("UIStroke", { Color = INK, Thickness = 1.5 }, pip)
    end
    text(
        sr,
        "FLOOR " .. lv,
        Color3.fromRGB(150, 90, 60),
        { Size = UDim2.fromScale(0.13, 0.25), Position = UDim2.fromScale(0.6, 0.12), ZIndex = 9, Max = 13 }
    )
    text(
        sr,
        unlocked .. " / " .. cap,
        INK,
        { Size = UDim2.fromScale(0.13, 0.4), Position = UDim2.fromScale(0.6, 0.45), ZIndex = 9 }
    )
    if nextPrice then
        local b = button(sr, 0.86, 0.5, 0.24, 0.62, "UNLOCK • $" .. Config.Short(nextPrice), GREEN)
        b.Activated:Connect(function()
            act("UnlockSlot")
        end)
    else
        text(
            sr,
            "ALL UNLOCKED",
            Color3.fromRGB(235, 175, 30),
            { Stroke = 2, Size = UDim2.fromScale(0.24, 0.45), Position = UDim2.fromScale(0.74, 0.28), ZIndex = 9 }
        )
    end
end

RENDER.Plot = function(panel)
    local data, err = fetch("plot")
    local L = layerOf(panel)
    clear(L)
    -- figma window art replaces the old skin
    for _, n in { "CleanSkin", "CleanBase" } do
        local x = panel:FindFirstChild(n)
        if x then
            x.Visible = false
        end
    end
    local art = panel:FindFirstChild("FigmaWindow")
        or new("ImageLabel", {
            Name = "FigmaWindow",
            BackgroundTransparency = 1,
            Image = "rbxassetid://85782174721137",
            Size = UDim2.fromScale(1, 1),
            ScaleType = Enum.ScaleType.Stretch,
            ZIndex = 2,
        }, panel)
    local cb = panel:FindFirstChild("Close")
    if cb then
        cb.AnchorPoint = Vector2.new(0.5, 0.5)
        cb.Position = UDim2.fromScale(0.951, 0.064)
        cb.Size = UDim2.fromScale(0.058, 0.088)
        cb.BackgroundTransparency = 1
        for _, c in cb:GetDescendants() do
            if c:IsA("GuiObject") then
                c.Visible = false
            elseif c:IsA("UIStroke") then
                c.Enabled = false
            end
        end
        cb.ZIndex = 30
    end
    if not data then
        text(box(L, 0.5, 0.5, 0.6, 0.08), err)
        return
    end
    local PX = Font.new("rbxasset://fonts/families/Bangers.json")
    local PF = FONT
    local K = Color3.new(0, 0, 0)
    local function card(cx, cy, w, h, col, z)
        local f = box(L, cx, cy, w, h, { BackgroundTransparency = 0, BackgroundColor3 = col, ZIndex = z or 8 })
        f:SetAttribute("NoSkin", true)
        new("UICorner", { CornerRadius = UDim.new(0.08, 0) }, f)
        new("UIStroke", { Color = K, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
        new("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = "rbxassetid://132561191216691",
            ScaleType = Enum.ScaleType.Tile,
            TileSize = UDim2.fromOffset(26, 26),
            ImageTransparency = 0.55,
            ZIndex = f.ZIndex,
        }, f)
        return f
    end
    local function t(parent, str, x, y, w, h, max, col, align)
        local l = new("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(x, y),
            Size = UDim2.fromScale(w, h),
            Text = str,
            FontFace = PF,
            TextScaled = true,
            TextColor3 = col or Color3.new(1, 1, 1),
            TextXAlignment = align or Enum.TextXAlignment.Left,
            ZIndex = parent.ZIndex + 2,
        }, parent)
        new("UITextSizeConstraint", { MaxTextSize = max or 30 }, l)
        new("UIStroke", { Color = K, Thickness = 2 }, l)
        return l
    end
    local plot = myPlot()
    local UP = require(game.ReplicatedStorage.UpgradePrices)
    local placed, income = {}, 0
    for _, it in data.items or {} do
        if it.state == "placed" then
            table.insert(placed, it)
            income += it.income or 0
        end
    end
    local level, cap, unlocked = data.level or 1, data.availableSlots or 12, data.unlocked or 0
    local chambers = plot and plot:FindFirstChild("Chambers")
    local nInc = chambers and #chambers:GetChildren() or 0
    -- stat cards
    local stats = {
        { "INCOME", "$" .. Config.Short(income) .. "/s", Color3.fromRGB(70, 200, 70) },
        { "SLOTS", #placed .. " / " .. unlocked, Color3.fromRGB(40, 110, 230) },
        { "TEMPLE", "Lv. " .. level, Color3.fromRGB(240, 170, 30) },
        { "INCUBATORS", nInc .. " / 3", Color3.fromRGB(240, 70, 150) },
    }
    for i, s in stats do
        local c = card(0.035 + (i - 1) * 0.245 + 0.1075, 0.21, 0.215, 0.12, s[3])
        t(c, s[1], 0.06, 0.08, 0.8, 0.3, 16)
        t(c, s[2], 0.06, 0.38, 0.9, 0.52, 36)
    end
    -- slots grid
    local grid = box(
        L,
        0.265,
        0.615,
        0.45,
        0.64,
        { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(120, 120, 128), ZIndex = 7 }
    )
    new("UICorner", { CornerRadius = UDim.new(0.03, 0) }, grid)
    new("UIStroke", { Color = Color3.fromRGB(60, 60, 70), Thickness = 2 }, grid)
    t(grid, "SLOTS", 0.04, 0.02, 0.4, 0.08, 20)
    local slotsF = plot and plot:FindFirstChild("Slots")
    for i = 1, 12 do
        local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
        local cell = box(
            grid,
            0.14 + col * 0.24,
            0.27 + row * 0.305,
            0.21,
            0.28,
            { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(46, 36, 92), ZIndex = 8 }
        )
        new("UICorner", { CornerRadius = UDim.new(0.08, 0) }, cell)
        new(
            "UIStroke",
            { Color = Color3.new(1, 1, 1), Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
            cell
        )
        local it = placed[i]
        local slot = slotsF and slotsF:FindFirstChild(string.format("Slot%02d", i))
        if it then
            if it.image and it.image ~= "" then
                new("ImageLabel", {
                    BackgroundTransparency = 1,
                    Image = it.image,
                    ScaleType = Enum.ScaleType.Fit,
                    Position = UDim2.fromScale(0.1, 0.04),
                    Size = UDim2.fromScale(0.8, 0.7),
                    ZIndex = 9,
                }, cell)
            end
            t(
                cell,
                "$" .. Config.Short(it.income or 0) .. "/s",
                0.05,
                0.74,
                0.9,
                0.22,
                14,
                Color3.fromRGB(110, 255, 110),
                Enum.TextXAlignment.Center
            )
        elseif i <= unlocked then
            cell.BackgroundColor3 = Color3.fromRGB(60, 50, 110)
            t(cell, "EMPTY", 0.05, 0.4, 0.9, 0.22, 14, Color3.fromRGB(190, 180, 230), Enum.TextXAlignment.Center)
        else
            cell.BackgroundColor3 = Color3.fromRGB(110, 110, 118)
            t(cell, "🔒", 0.2, 0.12, 0.6, 0.45, 40, Color3.new(1, 1, 1), Enum.TextXAlignment.Center)
            local price = slot and slot:GetAttribute("UnlockPrice")
            t(
                cell,
                price and ("$" .. Config.Short(price)) or "LOCKED",
                0.05,
                0.72,
                0.9,
                0.22,
                14,
                Color3.fromRGB(255, 210, 60),
                Enum.TextXAlignment.Center
            )
        end
    end
    -- upgrade rows
    local nextSlot, nextPrice
    for i = 1, cap do
        local sl = slotsF and slotsF:FindFirstChild(string.format("Slot%02d", i))
        if sl and not sl:GetAttribute("Unlocked") then
            nextSlot, nextPrice = i, sl:GetAttribute("UnlockPrice")
            break
        end
    end
    local lv1 = chambers
            and chambers:FindFirstChild("Chamber1")
            and (chambers.Chamber1:GetAttribute("UpgradeLevel") or 1)
        or 1
    local rows = {
        {
            "Temple Upgrade",
            level >= 3 and "Max level" or ("Lv. " .. level .. " → " .. (level + 1) .. " · unlock all slots first"),
            level >= 3 and nil or UP.Temple[level + 1],
            level / 3,
            Color3.fromRGB(240, 170, 30),
            "UpgradeTemple",
            level < 3 and data.canUpgrade,
        },
        {
            "Unlock Slot",
            nextSlot and ("Slot " .. nextSlot .. " · +1 character") or "Floor full",
            nextPrice,
            unlocked / math.max(cap, 1),
            Color3.fromRGB(40, 110, 230),
            "UnlockSlot",
            nextSlot ~= nil,
        },
        {
            "Incubator Speed",
            lv1 >= 3 and "Max level" or ("Lv. " .. lv1 .. " → " .. (lv1 + 1) .. " · faster hatching"),
            lv1 < 3 and UP.IncubatorLevel[lv1 + 1] or nil,
            lv1 / 3,
            Color3.fromRGB(70, 200, 70),
            "UpgradeIncubator",
            lv1 < 3,
        },
        {
            "More Incubators",
            nInc >= 3 and "All 3 built" or (nInc .. " → " .. (nInc + 1) .. " · hatch more at once"),
            nInc < 3 and UP.AddIncubator[nInc + 1] or nil,
            nInc / 3,
            Color3.fromRGB(150, 90, 230),
            "AddIncubator",
            nInc < 3,
        },
    }
    for i, r in rows do
        local row = box(
            L,
            0.74,
            0.21 + i * 0.16 + 0.02,
            0.45,
            0.145,
            { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(40, 30, 80), ZIndex = 7 }
        )
        new("UICorner", { CornerRadius = UDim.new(0.08, 0) }, row)
        new("UIStroke", { Color = K, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, row)
        new("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = "rbxassetid://132561191216691",
            ScaleType = Enum.ScaleType.Tile,
            TileSize = UDim2.fromOffset(26, 26),
            ImageTransparency = 0.7,
            ZIndex = 7,
        }, row)
        t(row, r[1], 0.04, 0.1, 0.6, 0.32, 24)
        t(row, r[2], 0.04, 0.44, 0.6, 0.2, 13, Color3.fromRGB(200, 195, 230))
        local bar = new("Frame", {
            BackgroundColor3 = Color3.fromRGB(20, 15, 40),
            BorderSizePixel = 0,
            Position = UDim2.fromScale(0.04, 0.72),
            Size = UDim2.fromScale(0.6, 0.14),
            ZIndex = 9,
        }, row)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, bar)
        new("UIStroke", { Color = K, Thickness = 1.5 }, bar)
        local fill = new("Frame", {
            BackgroundColor3 = r[5],
            BorderSizePixel = 0,
            Size = UDim2.fromScale(math.clamp(r[4], 0.05, 1), 1),
            ZIndex = 10,
        }, bar)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
        local can = r[7] and r[3] ~= nil
        local b = new("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.fromScale(0.96, 0.5),
            Size = UDim2.fromScale(0.28, 0.66),
            BackgroundColor3 = can and Color3.fromRGB(70, 200, 70) or Color3.fromRGB(110, 110, 118),
            Text = "",
            AutoButtonColor = false,
            ZIndex = 10,
        }, row)
        new("UICorner", { CornerRadius = UDim.new(0.12, 0) }, b)
        new("UIStroke", { Color = K, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
        new("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = "rbxassetid://132561191216691",
            ScaleType = Enum.ScaleType.Tile,
            TileSize = UDim2.fromOffset(22, 22),
            ImageTransparency = 0.45,
            ZIndex = 10,
        }, b)
        t(
            b,
            r[3] and ("$" .. Config.Short(r[3])) or "MAX",
            0.06,
            0.15,
            0.88,
            0.7,
            26,
            Color3.new(1, 1, 1),
            Enum.TextXAlignment.Center
        )
        b.MouseEnter:Connect(function()
            UISound.Play("Hover")
            TweenService:Create(b, TweenInfo.new(0.1), { Size = UDim2.fromScale(0.3, 0.7) }):Play()
        end)
        b.MouseLeave:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.1), { Size = UDim2.fromScale(0.28, 0.66) }):Play()
        end)
        b.Activated:Connect(function()
            if not can then
                say(
                    r[3]
                            and (r[1] == "Temple Upgrade" and "Unlock all " .. cap .. " slots first" or "Not available yet")
                        or "Already maxed"
                )
                return
            end
            UISound.Play("Click")
            act(r[6], { index = 1 })
        end)
    end
    panel:SetAttribute("Page", "figma")
end

local open
for _, c in gui:GetChildren() do
    if c:IsA("ImageLabel") then
        c.Visible = false
    end
end
dim.Visible = false

local refreshRunning = false
local refreshPending = false
refresh = function()
    refreshPending = true
    if refreshRunning then
        return
    end
    refreshRunning = true
    task.spawn(function()
        repeat
            refreshPending = false
            local current = open
            if current and RENDER[current.Name] then
                local ok, err = pcall(RENDER[current.Name], current)
                if not ok then
                    warn("[GameMenus] refresh failed:", err)
                end
            end
            if refreshPending then
                task.wait(0.06)
            end
        until not refreshPending
        refreshRunning = false
    end)
end
local function close()
    if not open then
        return
    end
    local p = open
    open = nil
    UISound.Play("Close")
    closing = p
    TweenService:Create(
        p.UIScale,
        TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Scale = 0.85 * (p:GetAttribute("Fit") or 1) }
    ):Play()
    task.delay(0.15, function()
        if closing == p then
            closing = nil
        end
        if open ~= p then
            p.Visible = false
        end
        if not open then
            dim.Visible = false
        end
    end)
end
local function show(p)
    if open == p then
        close()
        return
    end
    if open then
        open.Visible = false
    end
    skinPanel(p)
    open = p
    p.Visible = true
    dim.Visible = true
    if closing == p then
        closing = nil
    end
    local fit = p:GetAttribute("Fit") or 1
    p.UIScale.Scale = 0.85 * fit
    TweenService:Create(p.UIScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = fit }):Play()
    UISound.Play("Open")
    refresh()
end
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
    close()
end)
Changed.OnClientEvent:Connect(refresh)
do
    local lr = gui:FindFirstChild("LocalRefresh") or Instance.new("BindableEvent")
    lr.Name = "LocalRefresh"
    lr.Parent = gui
    lr.Event:Connect(function()
        if refresh then
            refresh()
        end
    end)
end
do
    local om = gui:FindFirstChild("OpenMenu") or Instance.new("BindableEvent")
    om.Name = "OpenMenu"
    om.Parent = gui
    om.Event:Connect(function(name)
        local p = gui:FindFirstChild(name)
        if p and open ~= p then
            show(p)
        end
    end)
end

for _, b in side:GetChildren() do
    if b:IsA("GuiButton") then
        local panel = gui:WaitForChild(b:GetAttribute("Panel"))
        panel:WaitForChild("Close").Activated:Connect(close)
        local s = b:FindFirstChildOfClass("UIScale")
        b.MouseEnter:Connect(function()
            UISound.Play("Hover")
            if s then
                TweenService:Create(s, TweenInfo.new(0.12), { Scale = 1.08 }):Play()
            end
        end)
        b.MouseLeave:Connect(function()
            if s then
                TweenService:Create(s, TweenInfo.new(0.12), { Scale = 1 }):Play()
            end
        end)
        local face = b:FindFirstChild("Face", true)
        if face then
            b.MouseButton1Down:Connect(function()
                TweenService:Create(face, TweenInfo.new(0.06), { Position = UDim2.new(0.5, 0, 0, 9) }):Play()
            end)
            local function up()
                TweenService
                    :Create(face, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 4) })
                    :Play()
            end
            b.MouseButton1Up:Connect(up)
            b.MouseLeave:Connect(up)
        end
        b.Activated:Connect(function()
            UISound.Play("Click")
            show(panel)
        end)
    end
end

-- TileIcons: use the object-only icons once they're set in ReplicatedStorage.GameMenuImages
local imgs = RS:FindFirstChild("GameMenuImages")
if imgs then
    for _, b in side:GetChildren() do
        if b:IsA("GuiButton") then
            local ic = b:FindFirstChild("Icon", true)
            local sh = b:FindFirstChild("IconShadow", true)
            local function upd()
                local v = imgs:GetAttribute("Tile" .. b.Name)
                if ic and v and v ~= "" then
                    ic.Image = v
                    if sh then
                        sh.Image = v
                    end
                end
            end
            imgs:GetAttributeChangedSignal("Tile" .. b.Name):Connect(upd)
            upd()
        end
    end
end

task.defer(function()
    local SR = RS:FindFirstChild("ShopSystem")
    local ok, SC = pcall(function()
        return require(SR.ShopConfig)
    end)
    if not ok then
        return
    end
    _G.__shopPrices = _G.__shopPrices or {}
    local MPS = game:GetService("MarketplaceService")
    local function warm(id, pass)
        if not id or id == 0 then
            return
        end
        local k = (pass and "p" or "d") .. id
        if _G.__shopPrices[k] ~= nil then
            return
        end
        _G.__shopPrices[k] = false
        task.spawn(function()
            local ok2, info =
                pcall(MPS.GetProductInfo, MPS, id, pass and Enum.InfoType.GamePass or Enum.InfoType.Product)
            _G.__shopPrices[k] = ok2 and info and info.PriceInRobux or false
        end)
    end
    for _, id in SC.Products do
        warm(id)
    end
    for _, id in SC.GamePasses do
        warm(id, true)
    end
    for _, lv in SC.MoneyLevels or {} do
        warm(lv.productId)
    end
end)
