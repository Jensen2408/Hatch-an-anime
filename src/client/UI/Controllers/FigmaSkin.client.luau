-- FigmaSkin: restyles the code-built menu content to the Figma "Hatch an Anime – Game UI" design.
-- Only colours/decoration change (no layout, no click logic): dark teal rows -> night purple studded blocks
-- with a white edge, bars -> ink, scroll bars -> purple. Covers Plot / Index / Quests / Shop, the egg bag and settings.
local Players = game:GetService("Players")
local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
local STUDS = "rbxassetid://132561191216691"
local NIGHT, NIGHT2, INK = Color3.fromRGB(42, 31, 74), Color3.fromRGB(53, 40, 98), Color3.fromRGB(13, 10, 20)

local function lum(c)
    return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end
-- the old teal/slate family: dark, and blue >= red (purple from Figma is left alone because it's already styled)
local function isOldDark(c)
    return lum(c) < 0.42 and c.B >= c.R and c.G >= c.R * 0.9 and not (c.R > c.G and c.B > c.G)
end

local function decorate(f, light)
    if f:GetAttribute("FS") then
        return
    end
    f:SetAttribute("FS", true)
    local sz = f.AbsoluteSize
    local c = f.BackgroundColor3
    if sz.Y <= 30 and sz.X > sz.Y * 3 then -- progress tracks / thin bars
        f.BackgroundColor3 = INK
        return
    end
    f.BackgroundColor3 = light and ((sz.X > 250 and sz.Y > 200) and NIGHT or NIGHT2)
        or (lum(c) < 0.16 and NIGHT or NIGHT2)
    if sz.X < 50 or sz.Y < 36 then
        return
    end
    if not f:FindFirstChildOfClass("UIGradient") then
        local g = Instance.new("UIGradient")
        g.Rotation = 90
        g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 165, 190))
        g.Parent = f
    end
    if not f:FindFirstChild("Studs") and not f:IsA("ScrollingFrame") then
        local im = Instance.new("ImageLabel")
        im.Name = "Studs"
        im.BackgroundTransparency = 1
        im.Size = UDim2.fromScale(1, 1)
        im.Image = STUDS
        im.ScaleType = Enum.ScaleType.Tile
        im.TileSize = UDim2.fromOffset(22, 22)
        im.ImageTransparency = 0.74
        im.ZIndex = f.ZIndex
        im.Active = false
        local cr = f:FindFirstChildOfClass("UICorner")
        if cr then
            cr:Clone().Parent = im
        end
        im.Parent = f
    end
    local st = f:FindFirstChildOfClass("UIStroke")
    if st and st.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
        st.Color = Color3.new(1, 1, 1)
        st.Transparency = 0.2
    end
end

local function studButton(b)
    if b:GetAttribute("FS") then
        return
    end
    local sz = b.AbsoluteSize
    if sz.X < 40 or sz.Y < 22 or b.BackgroundTransparency > 0.4 then
        return
    end
    if b:FindFirstAncestor("SideButtons") or b.Name == "Close" or b:FindFirstAncestor("Close") then
        return
    end
    b:SetAttribute("FS", true)
    if isOldDark(b.BackgroundColor3) then
        b.BackgroundColor3 = NIGHT2
    end
    if not b:FindFirstChild("Studs") then
        local im = Instance.new("ImageLabel")
        im.Name = "Studs"
        im.BackgroundTransparency = 1
        im.Size = UDim2.fromScale(1, 1)
        im.Image = STUDS
        im.ScaleType = Enum.ScaleType.Tile
        im.TileSize = UDim2.fromOffset(20, 20)
        im.ImageTransparency = 0.55
        im.ZIndex = b.ZIndex
        im.Active = false
        local cr = b:FindFirstChildOfClass("UICorner")
        if cr then
            cr:Clone().Parent = im
        end
        im.Parent = b
    end
    if not b:FindFirstChildOfClass("UIGradient") then
        local g = Instance.new("UIGradient")
        g.Rotation = 90
        g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(185, 185, 185))
        g.Parent = b
    end
    local hasBorder = false
    for _, st in b:GetChildren() do
        if st:IsA("UIStroke") and st.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
            hasBorder = true
            st.Color = Color3.new(0, 0, 0)
            st.Thickness = math.max(st.Thickness, 3)
        end
    end
    if not hasBorder then
        local st = Instance.new("UIStroke")
        st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        st.Thickness = 3
        st.LineJoinMode = Enum.LineJoinMode.Miter
        st.Parent = b
    end
end

local function fix(d)
    if d:GetAttribute("NoSkin") or (d.Parent and d.Parent:GetAttribute("NoSkin")) then
        return
    end
    if d:IsA("TextButton") or d:IsA("ImageButton") then
        task.defer(function()
            if d.Parent then
                studButton(d)
            end
        end)
        return
    end
    if d:IsA("TextLabel") and d.BackgroundTransparency < 0.5 and isOldDark(d.BackgroundColor3) then
        d.BackgroundColor3 = NIGHT2
    end
    if d:IsA("ScrollingFrame") then
        d.ScrollBarImageColor3 = Color3.fromRGB(168, 102, 255)
    end
    if
        (d:IsA("Frame") or d:IsA("ScrollingFrame"))
        and d.BackgroundTransparency < 0.5
        and d.Name ~= "CleanBase"
        and d.Name ~= "Accent"
        and d.Name ~= "RarityBar"
    then
        if isOldDark(d.BackgroundColor3) then
            task.defer(function()
                if d.Parent then
                    decorate(d)
                end
            end)
        end
    end
end
-- Settings panel is the old cream style: light fills -> night purple, dark text -> white with outline
local function fixLight(d)
    if
        d:IsA("GuiObject")
        and not d:IsA("ImageLabel")
        and d.BackgroundTransparency < 0.5
        and lum(d.BackgroundColor3) > 0.7
        and (function(c)
            return math.max(c.R, c.G, c.B) - math.min(c.R, c.G, c.B) < 0.3
        end)(d.BackgroundColor3)
        and not (d:IsA("TextButton") and d.Text == "X")
    then
        if d:IsA("Frame") then
            task.defer(function()
                if d.Parent then
                    decorate(d, true)
                end
            end)
        else
            d.BackgroundColor3 = NIGHT2
        end
    end
    if
        (d:IsA("TextLabel") or d:IsA("TextButton"))
        and lum(d.TextColor3) < 0.4
        and not (d:IsA("TextButton") and d.Text == "X")
    then
        local muted = d.TextSize > 0 and d.TextSize < 15
        d.TextColor3 = muted and Color3.fromRGB(195, 180, 230) or Color3.new(1, 1, 1)
        if not muted and not d:FindFirstChildOfClass("UIStroke") then
            local st = Instance.new("UIStroke")
            st.Thickness = 1.6
            st.Color = INK
            st.Parent = d
        end
    end
end
local function watchLight(p)
    for _, d in p:GetDescendants() do
        fixLight(d)
    end
    p.DescendantAdded:Connect(fixLight)
end
local function watchPanel(p)
    for _, d in p:GetDescendants() do
        fix(d)
    end
    p.DescendantAdded:Connect(fix)
end
-- ===== HUD pieces (figma buttons, currency pill, night banner) =====
local BTN_ART = {
    bag = "rbxthumb://type=Asset&id=134923907419001&w=420&h=420",
    gear = "rbxthumb://type=Asset&id=106364506867782&w=420&h=420",
}
local function studImg(parent, tile, transp, z)
    local im = Instance.new("ImageLabel")
    im.Name = "Studs"
    im.BackgroundTransparency = 1
    im.Size = UDim2.fromScale(1, 1)
    im.Image = STUDS
    im.ScaleType = Enum.ScaleType.Tile
    im.TileSize = UDim2.fromOffset(tile, tile)
    im.ImageTransparency = transp
    im.ZIndex = z or parent.ZIndex
    local cr = parent:FindFirstChildOfClass("UICorner")
    if cr then
        cr:Clone().Parent = im
    end
    im.Parent = parent
    return im
end
-- swap a code-drawn button for the figma art, keeping the button (clicks) and named extras (badge)
local function artButton(btn, art, keep)
    if btn:GetAttribute("FS") then
        return
    end
    btn:SetAttribute("FS", true)
    for _, c in btn:GetChildren() do
        if c:IsA("GuiObject") and not (keep and keep[c.Name]) then
            c.Visible = false
        elseif c:IsA("UIStroke") then
            c.Enabled = false
        end
    end
    btn.BackgroundTransparency = 1
    local im = Instance.new("ImageLabel")
    im.Name = "FigmaArt"
    im.BackgroundTransparency = 1
    im.Image = art
    im.Size = UDim2.fromScale(1, 1)
    im.ScaleType = Enum.ScaleType.Fit
    im.ResampleMode = Enum.ResamplerMode.Default
    im.ZIndex = btn.ZIndex
    im.Active = false
    im.Parent = btn
    for name in keep or {} do
        local k = btn:FindFirstChild(name)
        if k and k:IsA("GuiObject") then
            k.ZIndex = btn.ZIndex + 2
        end
    end
end
local function skinBag(gui)
    local rb = gui:WaitForChild("RightButtons", 15)
    local bag = rb and rb:WaitForChild("BagButton", 15)
    if not bag then
        return
    end
    bag.Size = UDim2.fromOffset(74, 77)
    local badge
    for _, c in bag:GetChildren() do
        if c:IsA("TextLabel") and c.Text ~= "BACKPACK" then
            badge = c
        end
    end
    if badge then
        badge.Name = "Badge"
    end
    artButton(bag, BTN_ART.bag, { Badge = true })
end
local function skinGear(gui)
    for _, hold in gui:GetChildren() do
        if hold:IsA("Frame") and hold.Name ~= "Panel" then
            local face = hold:FindFirstChildWhichIsA("TextButton")
            if not face then
                continue
            end
            hold.Size = UDim2.fromOffset(74, 77)
            for _, c in hold:GetChildren() do
                if c ~= face and c:IsA("GuiObject") then
                    c.Visible = false
                end
            end
            face.Size = UDim2.fromScale(1, 1)
            artButton(face, BTN_ART.gear)
        end
    end
end
local function skinMoney(gui)
    local m = gui:WaitForChild("Money", 15)
    if not m or m:GetAttribute("FS") then
        return
    end
    m:SetAttribute("FS", true)
    m.ImageTransparency = 1
    local pill = Instance.new("Frame")
    pill.Name = "FigmaPill"
    pill.ZIndex = 0
    pill.Position = UDim2.fromScale(0.13, 0.22)
    pill.Size = UDim2.fromScale(0.84, 0.56)
    pill.BackgroundColor3 = Color3.new(1, 1, 1)
    pill.BorderSizePixel = 0
    local g = Instance.new("UIGradient")
    g.Rotation = 90
    g.Color = ColorSequence.new(Color3.fromRGB(47, 35, 87), Color3.fromRGB(20, 13, 43))
    g.Parent = pill
    local cr = Instance.new("UICorner")
    cr.CornerRadius = UDim.new(0, 12)
    cr.Parent = pill
    local st = Instance.new("UIStroke")
    st.Color = Color3.new(1, 1, 1)
    st.Thickness = 4
    st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    st.Parent = pill
    pill.Parent = m
    studImg(pill, 22, 0.6, 0)
    local shadow = Instance.new("Frame")
    shadow.Name = "FigmaShadow"
    shadow.ZIndex = -1
    shadow.BorderSizePixel = 0
    shadow.BackgroundColor3 = Color3.new(0, 0, 0)
    shadow.Position = pill.Position + UDim2.fromOffset(0, 6)
    shadow.Size = pill.Size
    local cr2 = cr:Clone()
    cr2.Parent = shadow
    shadow.Parent = m
    local amt = m:FindFirstChild("Amount", true)
    if amt then
        amt.TextColor3 = Color3.fromRGB(125, 255, 107)
    end
end
local function skinNight(gui)
    local tab
    for _, c in gui:GetChildren() do
        if c:IsA("Frame") then
            tab = c
        end
    end
    if not tab or tab:GetAttribute("FS") then
        return
    end
    tab:SetAttribute("FS", true)
    tab.BackgroundColor3 = Color3.new(1, 1, 1)
    local g = Instance.new("UIGradient")
    g.Rotation = 90
    g.Color = ColorSequence.new(Color3.fromRGB(168, 102, 255), Color3.fromRGB(74, 21, 166))
    g.Parent = tab
    for _, st in tab:GetChildren() do
        if st:IsA("UIStroke") then
            st.Color = Color3.new(1, 1, 1)
            st.Thickness = 4
        end
    end
    local cr = tab:FindFirstChildOfClass("UICorner")
    if cr then
        cr.CornerRadius = UDim.new(0, 12)
    end
    -- figma night banner art behind the live text
    tab.BackgroundTransparency = 1
    g:Destroy()
    for _, st in tab:GetChildren() do
        if st:IsA("UIStroke") then
            st.Enabled = false
        end
    end
    local function pinSize()
        local compact = math.min(gui.AbsoluteSize.X, gui.AbsoluteSize.Y) < 600
        local night = workspace:GetAttribute("NighttimeActive") == true
        local w = UDim2.fromOffset(290, compact and 52 or (night and 124 or 90))
        if tab.Size ~= w then
            tab.Size = w
        end
    end
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(pinSize)
    workspace:GetAttributeChangedSignal("NighttimeActive"):Connect(pinSize)
    pinSize()
    tab:GetPropertyChangedSignal("Size"):Connect(pinSize)
    local art = Instance.new("ImageLabel")
    art.Name = "FigmaArt"
    art.BackgroundTransparency = 1
    art.Image = "rbxassetid://130685995376691"
    art.Size = UDim2.fromScale(1, 1)
    art.ScaleType = Enum.ScaleType.Stretch
    art.ZIndex = tab.ZIndex
    art.Parent = tab
    for _, l in tab:GetChildren() do
        if l:IsA("TextLabel") then
            l.ZIndex = tab.ZIndex + 1
            if not l:FindFirstChildOfClass("UIStroke") then
                local s2 = Instance.new("UIStroke")
                s2.Thickness = 2.2
                s2.Color = INK
                s2.Parent = l
            end
        end
    end
end

local function hook(gui)
    if gui.Name == "MoneyDisplay" then
        task.spawn(skinMoney, gui)
    end
    if gui.Name == "NightBar" then
        task.defer(skinNight, gui)
    end
    -- bag now lives in the left grid
    -- gear now lives in the left grid
    if gui.Name == "GameMenus" then
        for _, n in { "Plot", "Index", "Quests", "VipShop" } do
            local p = gui:WaitForChild(n, 10)
            if p then
                watchPanel(p)
            end
        end
    elseif gui.Name == "GameHUD" then
        local bag = gui:WaitForChild("EggBag", 10)
        if bag then
            watchPanel(bag)
        end
    elseif gui.Name == "MusicSettingsUI" then
        local p = gui:WaitForChild("Panel", 10)
        if p then
            watchPanel(p)
            watchLight(p)
        end
    end
end
for _, g in pg:GetChildren() do
    task.spawn(hook, g)
end
pg.ChildAdded:Connect(function(g)
    task.spawn(hook, g)
end)

-- ===== left menu: all 6 figma buttons (Plot, Index, Quest, Shop, Backpack, Settings) in one compact grid =====
local function thumb(id)
    return "rbxthumb://type=Asset&id=" .. id .. "&w=420&h=420"
end
local MENU_ART = {
    PlotButton = "rbxassetid://108526178271956",
    IndexButton = "rbxassetid://136158818877449",
    QuestsButton = "rbxassetid://137388884677460",
    VipShopButton = "rbxassetid://90922644817150",
    BagButton = "rbxassetid://122727444829967",
    Settings = "rbxassetid://101549876931377",
}
local function setArt(btn, art, keep)
    btn:SetAttribute("FS", nil)
    local old = btn:FindFirstChild("FigmaArt")
    if old then
        old:Destroy()
    end
    artButton(btn, art, keep)
end
task.spawn(function()
    local gm = pg:WaitForChild("GameMenus")
    local side = gm:WaitForChild("SideButtons")
    local grid = side:WaitForChild("UIGridLayout")
    for _, n in { "PlotButton", "IndexButton", "QuestsButton", "VipShopButton" } do
        local b = side:WaitForChild(n, 10)
        if b then
            local o = b:FindFirstChild("Outer")
            if o then
                o.Visible = false
            end
            setArt(b, MENU_ART[n])
        end
    end
    local order = { PlotButton = 1, IndexButton = 2, QuestsButton = 3, VipShopButton = 4 }
    for n, i in order do
        local b = side:FindFirstChild(n)
        if b then
            b.LayoutOrder = i
        end
    end
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    -- backpack (GameHUD) and settings gear (MusicSettingsUI) move into the same grid
    -- bag/gear: see FIGMA HUD LAYOUT
end)

-- ===== imported figma art: HOME bar, FEEDBACK button, money panel (live text stays on top) =====
local ART2 = {
    home = "rbxassetid://131819403885000",
    feedback = "rbxassetid://71511803471484",
    money = "rbxassetid://83828471664405",
}
task.spawn(function()
    local hud = pg:WaitForChild("GameHUD")
    local holder = hud:WaitForChild("HomeButton", 30)
    if not holder then
        return
    end
    local sh = holder:FindFirstChild("Shadow")
    if sh then
        sh.Visible = false
    end
    local hb = holder:WaitForChild("Button")
    hb.Size = UDim2.fromScale(1, 1)
    artButton(hb, ART2.home)
end)
task.spawn(function()
    local fg = pg:WaitForChild("FeedbackUI")
    local b = fg:WaitForChild("FeedbackButton", 30)
    if not b then
        return
    end
    for _, c in b:GetChildren() do
        if c:IsA("GuiObject") then
            c.Visible = false
        end
    end
    b.BackgroundTransparency = 1
    for _, c in b:GetDescendants() do
        if c:IsA("UIStroke") then
            c.Enabled = false
        end
    end
    local face = b:IsA("GuiButton") and b or b:FindFirstChildWhichIsA("GuiButton", true)
    local im = Instance.new("ImageLabel")
    im.Name = "FigmaArt"
    im.BackgroundTransparency = 1
    im.Image = ART2.feedback
    im.Size = UDim2.fromScale(1, 1)
    im.ScaleType = Enum.ScaleType.Fit
    im.ZIndex = b.ZIndex + 5
    im.Active = false
    im.Parent = b
end)
task.spawn(function()
    local md = pg:WaitForChild("MoneyDisplay")
    local m = md:WaitForChild("Money", 30)
    if not m then
        return
    end
    task.wait(0.5)
    for _, n in { "FigmaPill", "FigmaShadow", "CoinBox" } do
        local x = m:FindFirstChild(n)
        if x then
            x.Visible = false
        end
    end
    m.Image = ART2.money
    m.ImageTransparency = 0
    m.ScaleType = Enum.ScaleType.Fit
    m.Size = UDim2.fromOffset(320, 112) -- (position: see FIGMA HUD LAYOUT)
    local face = m:FindFirstChild("Face")
    if face then
        face.Position = UDim2.fromScale(0.2, 0.04)
        face.Size = UDim2.fromScale(0.76, 0.84)
        for _, n in { "Shine", "IncomeGlow" } do
            local x = face:FindFirstChild(n)
            if x then
                x.Visible = false
            end
        end
        local amt = face:FindFirstChild("Amount")
        if amt then
            amt.Position = UDim2.fromScale(0.03, 0.02)
            amt.Size = UDim2.fromScale(0.94, 0.56)
            amt.TextColor3 = Color3.fromRGB(125, 255, 107)
        end
        local inc = face:FindFirstChild("Income")
        if inc then
            inc.BackgroundTransparency = 1
            for _, x in inc:GetChildren() do
                if x:IsA("UIStroke") or x:IsA("UIGradient") then
                    x:Destroy()
                elseif x:IsA("Frame") then
                    x.Visible = false
                end
            end
            inc.AnchorPoint = Vector2.new(0.5, 0)
            inc.Position = UDim2.fromScale(0.5, 0.66)
            inc.Size = UDim2.fromScale(0.68, 0.3)
        end
    end
end)

-- ===== FIGMA HUD LAYOUT: night top-left, money top-centre, small Backpack/Settings under the grid, quests + daily on the right =====
local IMG_DAILY, IMG_QUEST = "rbxassetid://77807427401832", "rbxassetid://76790067314566"
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local function lbl(parent, t, size, color, props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.FontFace = FONT
    l.Text = t
    l.TextSize = size
    l.TextColor3 = color or Color3.new(1, 1, 1)
    l.TextXAlignment = Enum.TextXAlignment.Left
    for k, v in props or {} do
        l[k] = v
    end
    local s = Instance.new("UIStroke")
    s.Thickness = 2
    s.Color = INK
    s.Parent = l
    l.Parent = parent
    return l
end
-- night banner -> top-left (keep its own up/down animation)
task.spawn(function()
    local nb = pg:WaitForChild("NightBar")
    task.wait(1)
    local tab
    for _, x in nb:GetChildren() do
        if x:IsA("Frame") then
            tab = x
        end
    end
    if not tab then
        return
    end
    local function pinX()
        local compact = math.min(nb.AbsoluteSize.X, nb.AbsoluteSize.Y) < 600
        nb.ScreenInsets = compact and Enum.ScreenInsets.CoreUISafeInsets or Enum.ScreenInsets.None
        local want = compact and UDim2.new(0, 10 + tab.AbsoluteSize.X / 2, 0, tab.AbsoluteSize.Y)
            or UDim2.new(0, 16 + tab.AbsoluteSize.X / 2, tab.Position.Y.Scale, tab.Position.Y.Offset)
        if tab.Position ~= want then
            tab.Position = want
        end
    end
    nb:GetPropertyChangedSignal("AbsoluteSize"):Connect(pinX)
    tab:GetPropertyChangedSignal("AbsoluteSize"):Connect(pinX)
    pinX()
    tab:GetPropertyChangedSignal("Position"):Connect(pinX)
end)
-- MoneyLogic owns cash positioning so the skin cannot fight safe-area layout.
-- small Backpack + Settings row under the 2x2 grid
task.spawn(function()
    local gm = pg:WaitForChild("GameMenus")
    local side = gm:WaitForChild("SideButtons")
    local row = Instance.new("Frame")
    row.Name = "SmallButtons"
    row.BackgroundTransparency = 1
    row.Size = UDim2.fromOffset(140, 65)
    row.Parent = gm
    local ll = Instance.new("UIListLayout")
    ll.FillDirection = Enum.FillDirection.Horizontal
    ll.Padding = UDim.new(0, 10)
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Parent = row
    local rowScale = Instance.new("UIScale")
    rowScale.Name = "ResponsiveScale"
    rowScale.Parent = row
    local function place()
        local compact = math.min(gm.AbsoluteSize.X, gm.AbsoluteSize.Y) < 600
        local p, sz = side.AbsolutePosition, side.AbsoluteSize
        row.Position =
            UDim2.fromOffset(p.X - gm.AbsolutePosition.X, p.Y - gm.AbsolutePosition.Y + sz.Y + (compact and 6 or 10))
        row.Size = compact and UDim2.fromOffset(190, 92) or UDim2.fromOffset(140, 65)
        rowScale.Scale = compact and sz.X / 190 or 1
        ll.Padding = UDim.new(0, compact and 6 or 10)
        for _, child in row:GetChildren() do
            if child:IsA("GuiObject") then
                child.Size = compact and UDim2.fromOffset(92, 92) or UDim2.fromOffset(62, 65)
                local phone = child:FindFirstChild("PhoneScale")
                if phone then
                    phone.Scale = 1
                end
            end
        end
    end
    row.ChildAdded:Connect(function()
        task.defer(place)
    end)
    gm:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
    side:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
    side:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
    place()
    local bag = pg:WaitForChild("GameHUD"):WaitForChild("RightButtons"):WaitForChild("BagButton", 15)
    if bag then
        bag.Parent = row
        bag.LayoutOrder = 1
        bag.Size = UDim2.fromOffset(62, 65)
        setArt(bag, MENU_ART.BagButton, { Badge = true })
        for _, x in bag:GetChildren() do
            if x:IsA("TextLabel") and x.Text ~= "BACKPACK" then
                x.Name = "Badge"
                x.ZIndex = 30
                x.Visible = x.Visible
            end
        end
        bag.ZIndex = 20
    end
    local ms = pg:WaitForChild("MusicSettingsUI")
    for _, hold in ms:GetChildren() do
        if hold:IsA("Frame") and hold.Name ~= "Panel" and hold:FindFirstChildWhichIsA("TextButton") then
            hold.Parent = row
            hold.LayoutOrder = 2
            hold.Size = UDim2.fromOffset(62, 65)
            local face = hold:FindFirstChildWhichIsA("TextButton")
            for _, x in hold:GetChildren() do
                if x:IsA("GuiObject") and x ~= face then
                    x.Visible = false
                end
            end
            face.Size = UDim2.fromScale(1, 1)
            face.Position = UDim2.new()
            setArt(hold:FindFirstChildWhichIsA("TextButton"), MENU_ART.Settings)
            break
        end
    end
end)
-- right side: live quest tracker + daily button
task.spawn(function()
    local gui = Instance.new("ScreenGui")
    gui.Name = "QuestTrackerUI"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 40
    gui.Parent = pg
    local panel = Instance.new("ImageLabel")
    panel.Name = "Quests"
    panel.BackgroundTransparency = 1
    panel.Image = IMG_QUEST
    panel.AnchorPoint = Vector2.new(1, 0.5)
    panel.Position = UDim2.new(1, -16, 0.5, -40)
    panel.Size = UDim2.fromOffset(300, 198)
    panel.Parent = gui
    Instance.new("UIScale", panel).Scale = 0.82
    lbl(panel, "QUESTS", 26, nil, { Position = UDim2.fromOffset(16, 8), Size = UDim2.fromOffset(200, 32) })
    local COLORS = { Color3.fromRGB(67, 220, 78), Color3.fromRGB(255, 201, 63), Color3.fromRGB(59, 120, 255) }
    local rows = {}
    for i = 1, 3 do
        local y = 44 + (i - 1) * 48
        local name = lbl(panel, "", 15, nil, { Position = UDim2.fromOffset(16, y), Size = UDim2.fromOffset(260, 18) })
        local track = Instance.new("Frame")
        track.BackgroundColor3 = Color3.fromRGB(13, 10, 20)
        track.BackgroundTransparency = 0
        local ts = Instance.new("UIStroke")
        ts.Color = Color3.fromRGB(110, 95, 160)
        ts.Thickness = 1.5
        ts.Parent = track
        track.BorderSizePixel = 0
        track.Position = UDim2.fromOffset(16, y + 21)
        track.Size = UDim2.fromOffset(196, 12)
        track.Parent = panel
        local cr = Instance.new("UICorner")
        cr.CornerRadius = UDim.new(1, 0)
        cr.Parent = track
        local fill = Instance.new("Frame")
        fill.BackgroundColor3 = COLORS[i]
        fill.BorderSizePixel = 0
        fill.Size = UDim2.fromScale(0, 1)
        fill.Parent = track
        cr:Clone().Parent = fill
        local val = lbl(panel, "", 15, Color3.fromRGB(255, 227, 107), {
            Position = UDim2.fromOffset(220, y + 16),
            Size = UDim2.fromOffset(66, 20),
            TextXAlignment = Enum.TextXAlignment.Right,
        })
        rows[i] = { name = name, fill = fill, val = val }
    end
    local function short(n)
        for _, u in { { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
            if n >= u[1] then
                return string.format("%g", math.floor(n / u[1] * 10) / 10) .. u[2]
            end
        end
        return tostring(math.floor(n))
    end
    local remotes = game:GetService("ReplicatedStorage"):WaitForChild("GameMenu"):WaitForChild("Remotes")
    local GetState, Changed = remotes:WaitForChild("GetState"), remotes:WaitForChild("Changed")
    local busy = false
    local function update()
        if busy then
            return
        end
        busy = true
        local ok, data = pcall(function()
            return GetState:InvokeServer("quests")
        end)
        busy = false
        if not ok or type(data) ~= "table" or data.error then
            return
        end
        local list = {}
        for _, q in data.list or {} do
            if not q.claimed then
                table.insert(list, q)
            end
        end
        table.sort(list, function(a, b)
            return (a.progress / math.max(a.target, 1)) > (b.progress / math.max(b.target, 1))
        end)
        for i, r in rows do
            local q = list[i]
            r.name.Text = q and q.title or ""
            r.val.Text = q and (short(math.min(q.progress, q.target)) .. "/" .. short(q.target)) or ""
            r.fill.Size = UDim2.fromScale(q and math.clamp(q.progress / math.max(q.target, 1), 0, 1) or 0, 1)
            r.fill.Parent.Visible = q ~= nil
        end
    end
    Changed.OnClientEvent:Connect(function()
        task.delay(0.3, update)
    end)
    task.spawn(function()
        while gui.Parent do
            update()
            task.wait(8)
        end
    end)
    -- daily button -> opens the shop (daily rewards live there)
    local daily = Instance.new("ImageButton")
    daily.Name = "Daily"
    daily.BackgroundTransparency = 1
    daily.Image = IMG_DAILY
    daily.AnchorPoint = Vector2.new(1, 0)
    daily.Position = UDim2.new(1, -16, 0.5, 50)
    daily.Size = UDim2.fromOffset(90, 94)
    daily.Parent = gui
    local sc = Instance.new("UIScale")
    sc.Parent = daily
    local function layoutTracker()
        local v = gui.AbsoluteSize
        local compact = math.min(v.X, v.Y) < 600
        local landscape = v.X >= v.Y
        panel.Visible = not compact or (landscape and v.X >= 600)
        panel.AnchorPoint = compact and Vector2.new(1, 0) or Vector2.new(1, 0.5)
        panel.Position = compact and UDim2.new(1, -10, 0, 62) or UDim2.new(1, -16, 0.5, -40)
        panel:FindFirstChildOfClass("UIScale").Scale = compact and 0.55 or 0.82
        daily.Size = compact and UDim2.fromOffset(48, 50) or UDim2.fromOffset(90, 94)
        daily.Position = compact and UDim2.new(1, -118, 0, landscape and 6 or 146) or UDim2.new(1, -16, 0.5, 50)
    end
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutTracker)
    layoutTracker()
    local TS = game:GetService("TweenService")
    daily.MouseEnter:Connect(function()
        TS:Create(sc, TweenInfo.new(0.12), { Scale = 1.08 }):Play()
    end)
    daily.MouseLeave:Connect(function()
        TS:Create(sc, TweenInfo.new(0.12), { Scale = 1 }):Play()
    end)
    daily.Activated:Connect(function()
        local om = pg.GameMenus:FindFirstChild("OpenMenu")
        if om then
            om:Fire("VipShop")
        end
    end)
end)

-- ===== size + smoothness pass =====
task.spawn(function()
    local TS = game:GetService("TweenService")
    local gm = pg:WaitForChild("GameMenus")
    local side = gm:WaitForChild("SideButtons")
    local grid = side:WaitForChild("UIGridLayout")
    grid.CellSize = UDim2.fromOffset(92, 92)
    grid.CellPadding = UDim2.fromOffset(6, 6)
    side.Size = UDim2.fromOffset(190, 190)
    local function smooth(b)
        if not b:IsA("GuiButton") or b:GetAttribute("Smooth") then
            return
        end
        b:SetAttribute("Smooth", true)
        local sc = b:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", b)
        local fast = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        b.MouseEnter:Connect(function()
            TS:Create(sc, fast, { Scale = 1.06 }):Play()
        end)
        b.MouseLeave:Connect(function()
            TS:Create(sc, fast, { Scale = 1 }):Play()
        end)
        b.MouseButton1Down:Connect(function()
            TS:Create(sc, TweenInfo.new(0.07), { Scale = 0.93 }):Play()
        end)
        b.MouseButton1Up:Connect(function()
            TS:Create(sc, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1.06 }):Play()
        end)
    end
    task.wait(3)
    local row = gm:FindFirstChild("SmallButtons")
    if row then
        for _, d in row:GetDescendants() do
            smooth(d)
        end
    end
    local hb = pg:FindFirstChild("GameHUD") and pg.GameHUD:FindFirstChild("HomeButton")
    if hb then
        for _, d in hb:GetDescendants() do
            smooth(d)
        end
    end
end)
