-- GameMenus.ShopMenuComponent  (ModuleScript, client)
-- Draws the Shop menu from the "Halloween Shop" mockup art (ShopMenuConfig / ShopAtlas): the background (panel,
-- header, tab row) and one page image per tab (FEATURED: the mockup's own; the others GPT Image art in its
-- style) with the live texts, level pips and hit-boxes on top. Display only: MenuLogic (RENDER.VipShop) reads ShopRemote "State", formats prices
-- and passes the purchases as callbacks. Live countdowns tick here while the view exists.
--
--   ShopCanvas (1092x679 mockup pixels, UIScale = panel width / 1092)
--   ├── Background
--   ├── Tab_FEATURED .. Tab_DAILY     tab art + icon + label + hit-box (+ "!" alert on DAILY)
--   └── Page                          the tab's page image (FEATURED: the mockup's) + the live texts
--
--   local view = ShopMenuComponent.new(panel, layer, model)
--   view:Destroy()
--
-- model = {
--   tab, onTab(tab),
--   limited = { name, text, eggModel?, endsAt (os.clock), price, onBuy }?,
--   vip = { text, perks, price, owned, onBuy },
--   boosts = { { title, shortText, text, price, activeEnds? (os.clock), duration, onBuy } x2 },
--   starter = { title, text, price, owned, onBuy },
--   money = { value, level, maxLevel, levelText, price, maxed, onBuy },
--   hatch = { value, level, maxLevel, price, maxed, onBuy },   -- HATCH SPEED (cash levels), BOOSTS tab
--   cash = { { amount, text, badge?, price, onBuy } x3 },
--   daily = { days = { { label, kind, value, valueColor, state = "claimed" | "today" | "locked", last } },
--             ready, claimText, nextEnds (os.clock), onClaim },
-- }
local RunService = game:GetService("RunService")

local Config = require(script.Parent:WaitForChild("ShopMenuConfig"))
local Atlas = require(script.Parent:WaitForChild("ShopAtlas"))

local CANVAS = Atlas.Canvas
local Z = 10 -- base ZIndex; layers above it
local ShopMenuComponent = {}
ShopMenuComponent.__index = ShopMenuComponent
ShopMenuComponent.AspectRatio = CANVAS.X / CANVAS.Y

-- 1:02:03
local function formatHms(seconds)
    seconds = math.max(0, math.floor(seconds))
    return string.format("%d:%02d:%02d", seconds // 3600, (seconds // 60) % 60, seconds % 60)
end

-- 12d 12h 28m (the mockup's timer); under a day: 12h 28m 05s
local function formatDhm(seconds)
    seconds = math.max(0, math.floor(seconds))
    local days, hours, minutes = seconds // 86400, (seconds // 3600) % 24, (seconds // 60) % 60
    if days > 0 then
        return string.format("%dd %dh %02dm", days, hours, minutes)
    end
    return string.format("%dh %02dm %02ds", hours, minutes, seconds % 60)
end

local function rect(instance, r)
    instance.Position = UDim2.fromOffset(r[1], r[2])
    instance.Size = UDim2.fromOffset(r[3], r[4])
end

local function new(className, name, parent, zIndex)
    local instance = Instance.new(className)
    instance.Name = name
    if instance:IsA("GuiObject") then
        instance.BackgroundTransparency = 1
        instance.BorderSizePixel = 0
        instance.ZIndex = zIndex or Z
    end
    instance.Parent = parent
    return instance
end

-- one atlas piece at its own size, top-left at `position` (the atlas is stored at mockup size)
local function piece(parent, name, pieceName, position, zIndex)
    local r = Atlas.Pieces[pieceName]
    local image = new("ImageLabel", name, parent, zIndex)
    image.Image = Config.Pieces
    image.ImageRectOffset = Vector2.new(r[1], r[2])
    image.ImageRectSize = Vector2.new(r[3], r[4])
    image.Position = UDim2.fromOffset(position.X, position.Y)
    image.Size = UDim2.fromOffset(r[3], r[4])
    return image
end

local function sliced(parent, name, pieceName, r, margin, zIndex)
    local image = piece(parent, name, pieceName, Vector2.zero, zIndex)
    local size = Atlas.Pieces[pieceName]
    image.ScaleType = Enum.ScaleType.Slice
    image.SliceCenter = Rect.new(margin, margin, size[3] - margin, size[4] - margin)
    rect(image, r)
    return image
end

local function label(parent, name, text, r, size, color, zIndex, options)
    options = options or {}
    local textLabel = new("TextLabel", name, parent, zIndex)
    textLabel.FontFace = Config.Font
    textLabel.Text = text
    textLabel.TextColor3 = color or Config.White
    textLabel.TextXAlignment = options.alignX or Enum.TextXAlignment.Center
    textLabel.TextWrapped = options.wrap == true
    textLabel.TextScaled = true
    local limit = Instance.new("UITextSizeConstraint")
    limit.MaxTextSize = size
    limit.Parent = textLabel
    rect(textLabel, r)
    local thickness = options.stroke or 3
    if thickness > 0 then
        local stroke = Instance.new("UIStroke")
        stroke.Color = Config.Stroke
        stroke.Thickness = thickness
        stroke.LineJoinMode = Enum.LineJoinMode.Round
        stroke.Parent = textLabel
    end
    return textLabel
end

local function hitBox(parent, name, r, onActivate, zIndex)
    local button = new("TextButton", name, parent, zIndex)
    button.Text = ""
    button.AutoButtonColor = false
    rect(button, r)
    if onActivate then
        button.Activated:Connect(onActivate)
    end
    return button
end

-- a button drawn by the page image: its text and hit-box (+ a dark veil when it cannot be pressed)
local function button(parent, name, r, text, size, enabled, onActivate, zIndex)
    if not enabled then
        local veil = new("Frame", name .. "Veil", parent, zIndex)
        veil.BackgroundTransparency = Config.DisabledShade
        veil.BackgroundColor3 = Color3.new(0, 0, 0)
        rect(veil, r)
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = veil
    end
    label(parent, name .. "Text", text, { r[1] + 8, r[2] + 2, r[3] - 16, r[4] - 6 }, size, Config.White, zIndex + 1)
    hitBox(parent, name .. "Hit", r, enabled and onActivate or nil, zIndex + 2)
end

-- Calls update(secondsLeft) now and then every second while the view lives
function ShopMenuComponent:_tick(endsAt, update)
    update(endsAt - os.clock())
    task.spawn(function()
        while self.alive do
            task.wait(1)
            if self.alive then
                update(endsAt - os.clock())
            end
        end
    end)
end

-- Boost description, replaced by a live "ACTIVE 0:12:34" while the boost runs
function ShopMenuComponent:_boostText(text, boost, idleText)
    if not boost.activeEnds then
        text.Text = idleText
        return
    end
    self:_tick(boost.activeEnds, function(secondsLeft)
        text.Text = secondsLeft > 0 and ("ACTIVE " .. formatHms(secondsLeft)) or idleText
    end)
end

-- the limited egg model spinning on the pedestal
function ShopMenuComponent:_egg(eggModel, r)
    local viewport = new("ViewportFrame", "Egg", self.page, Z + 2)
    rect(viewport, r)
    viewport.Ambient = Color3.fromRGB(200, 190, 230)
    viewport.LightColor = Color3.new(1, 1, 1)
    viewport.LightDirection = Vector3.new(-0.4, -0.6, -1)
    local egg = eggModel:Clone()
    egg.Parent = viewport
    local boundsCFrame, boundsSize = egg:GetBoundingBox()
    egg:PivotTo(CFrame.new(-boundsCFrame.Position) * egg:GetPivot())
    local camera = Instance.new("Camera")
    camera.FieldOfView = 40
    camera.CFrame = CFrame.lookAt(Vector3.new(0, boundsSize.Y * 0.08, -boundsSize.Magnitude * 1.25), Vector3.zero)
    camera.Parent = viewport
    viewport.CurrentCamera = camera
    local basePivot, spinStart = egg:GetPivot(), os.clock()
    local spin
    spin = RunService.RenderStepped:Connect(function()
        if not (self.alive and viewport.Parent) then
            spin:Disconnect()
            return
        end
        if not self.panel.Visible then
            return
        end
        local elapsed = os.clock() - spinStart
        egg:PivotTo(CFrame.new(0, math.sin(elapsed * 2) * 0.2, 0) * CFrame.Angles(0, elapsed * 0.9, 0) * basePivot)
    end)
end

-- ===== FEATURED: the mockup's page, live texts on top =====
function ShopMenuComponent:_featured()
    local model, style = self.model, Config.Page
    local image = new("ImageLabel", "FeaturedArt", self.page, Z + 1)
    image.Image = Config.Featured
    rect(image, Atlas.Content)

    local limited = model.limited
    if limited then
        if limited.eggModel then
            self:_egg(limited.eggModel, style.Egg)
        end
        local timer =
            label(self.page, "Timer", "", style.Timer.Rect, style.Timer.Size, Config.White, Z + 3, { stroke = 2 })
        self:_tick(limited.endsAt, function(secondsLeft)
            timer.Text = secondsLeft > 0 and formatDhm(secondsLeft) or "ENDED"
        end)
        label(self.page, "Title", string.upper(limited.name), style.Title.Rect, style.Title.Size, Config.White, Z + 3, {
            stroke = 4,
        })
        sliced(self.page, "SubtitlePill", "PillDark", style.Subtitle.Pill, Config.PillSlice, Z + 2)
        label(self.page, "Subtitle", limited.text, style.Subtitle.Rect, style.Subtitle.Size, Config.Muted, Z + 3, {
            stroke = 2,
        })
        label(self.page, "BuyText", "BUY • " .. limited.price, style.Buy.Text, style.Buy.Size, Config.White, Z + 3, {
            stroke = 4,
        })
        hitBox(self.page, "Buy", style.Buy.Hit, limited.onBuy, Z + 4)
    end

    local vip = model.vip
    label(
        self.page,
        "VipPrice",
        vip.owned and "OWNED" or vip.price,
        style.Vip.Text,
        style.Vip.Size,
        Config.White,
        Z + 3
    )
    hitBox(self.page, "VipBuy", style.Vip.Hit, not vip.owned and vip.onBuy or nil, Z + 4)

    for i, boost in model.boosts do
        local spec = style.Boosts[i]
        if spec then
            local text =
                label(self.page, "BoostText" .. i, "", spec.Text, spec.TextSize, Config.White, Z + 3, { stroke = 2 })
            self:_boostText(text, boost, boost.shortText)
            label(self.page, "BoostPrice" .. i, boost.price, spec.Price, spec.PriceSize, Config.White, Z + 3)
            hitBox(self.page, "BoostBuy" .. i, spec.Hit, boost.onBuy, Z + 4)
        end
    end

    local starter, spec = model.starter, style.Starter
    label(self.page, "StarterText", starter.text, spec.Text, spec.TextSize, Config.White, Z + 3, { stroke = 2 })
    label(
        self.page,
        "StarterPrice",
        starter.owned and "OWNED" or starter.price,
        spec.Price,
        spec.PriceSize,
        Config.White,
        Z + 3
    )
    hitBox(self.page, "StarterBuy", spec.Hit, not starter.owned and starter.onBuy or nil, Z + 4)
end

-- the tab's page image (BOOSTS / PASSES / CASH / DAILY)
function ShopMenuComponent:_pageArt(tab)
    local image = new("ImageLabel", "PageArt", self.page, Z + 1)
    image.Image = Config.PageArt[tab]
    rect(image, Config.PageArt.Rect)
end

-- level squares on a dark track (so the page art behind them never shows through the gaps)
local function pips(parent, x, y, size, gap, level, maxLevel, zIndex)
    local pad = Config.PipTrack.Padding
    local track = new("Frame", "PipTrack", parent, zIndex)
    track.BackgroundTransparency = 0
    track.BackgroundColor3 = Config.PipTrack.Color
    rect(track, { x - pad, y - pad, maxLevel * size + (maxLevel - 1) * gap + pad * 2, size + pad * 2 })
    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(0, 8)
    trackCorner.Parent = track
    local trackStroke = Instance.new("UIStroke")
    trackStroke.Color = Config.Stroke
    trackStroke.Thickness = 2
    trackStroke.Parent = track
    for i = 1, maxLevel do
        local pip = new("Frame", "Pip" .. i, parent, zIndex + 1)
        pip.BackgroundTransparency = 0
        pip.BackgroundColor3 = i <= level and Config.Gold or Config.PipTrack.Empty
        rect(pip, { x + (i - 1) * (size + gap), y, size, size })
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 5)
        corner.Parent = pip
        local stroke = Instance.new("UIStroke")
        stroke.Color = Config.Stroke
        stroke.Thickness = 2
        stroke.Parent = pip
    end
end

local LEFT = Enum.TextXAlignment.Left

local function shade(parent, transparency)
    local veil = new("Frame", "Shade", parent, parent.ZIndex)
    veil.BackgroundTransparency = transparency
    veil.BackgroundColor3 = Color3.new(0, 0, 0)
    veil.Size = UDim2.fromScale(1, 1)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = veil
    return veil
end

-- ===== BOOSTS =====
function ShopMenuComponent:_boostsPage()
    self:_pageArt("BOOSTS")
    local style, page = Config.Boosts, self.page
    for i, boost in self.model.boosts do
        local spec = style.Cards[i]
        if spec then
            label(page, "Title" .. i, boost.title, spec.Title, style.TitleSize, Config.White, Z + 2, {
                alignX = LEFT,
                stroke = 4,
            })
            label(page, "Text" .. i, boost.text, spec.Text, style.TextSize, Config.White, Z + 2, {
                alignX = LEFT,
                wrap = true,
                stroke = 2,
            })
            local timer = label(page, "Timer" .. i, "", spec.Timer, style.TimerSize, Config.Gold, Z + 2, {
                alignX = LEFT,
                stroke = 2,
            })
            self:_boostText(timer, boost, "Not active")
            button(page, "Buy" .. i, spec.Button, boost.price, style.ButtonSize, true, boost.onBuy, Z + 2)
        end
    end

    local hatchStyle, hatch = style.Hatch, self.model.hatch
    label(page, "HatchTitle", "HATCH SPEED", hatchStyle.Title, hatchStyle.TitleSize, Config.White, Z + 2, {
        alignX = LEFT,
    })
    label(
        page,
        "HatchValue",
        hatch.value .. "  ·  permanent",
        hatchStyle.Value,
        hatchStyle.ValueSize,
        Config.Gold,
        Z + 2,
        {
            alignX = LEFT,
            stroke = 2,
        }
    )
    local p = hatchStyle.Pips
    pips(page, p.X, p.Y, p.Size, p.Gap, hatch.level, hatch.maxLevel, Z + 2)
    button(page, "HatchBuy", hatchStyle.Button, hatch.price, 34, not hatch.maxed, hatch.onBuy, Z + 2)

    local starterStyle, starter = style.Starter, self.model.starter
    label(page, "StarterTitle", starter.title, starterStyle.Title, starterStyle.TitleSize, Config.White, Z + 2, {
        alignX = LEFT,
    })
    label(page, "StarterText", starter.text, starterStyle.Text, starterStyle.TextSize, Config.White, Z + 2, {
        alignX = LEFT,
        stroke = 2,
    })
    local starterPrice = starter.owned and "OWNED" or starter.price
    button(page, "StarterBuy", starterStyle.Button, starterPrice, 34, not starter.owned, starter.onBuy, Z + 2)
end

-- ===== PASSES =====
function ShopMenuComponent:_passesPage()
    self:_pageArt("PASSES")
    local style, model, page = Config.Passes, self.model, self.page
    local vipStyle, vip = style.Vip, model.vip
    label(page, "VipTitle", "VIP", vipStyle.Title, vipStyle.TitleSize, Config.White, Z + 2, { stroke = 5 })
    label(
        page,
        "VipText",
        vip.perks,
        vipStyle.Text,
        vipStyle.TextSize,
        Config.White,
        Z + 2,
        { wrap = true, stroke = 2 }
    )
    local vipPrice = vip.owned and "OWNED" or vip.price
    button(page, "VipBuy", vipStyle.Button, vipPrice, style.ButtonSize, not vip.owned, vip.onBuy, Z + 2)

    local moneyStyle, money = style.Money, model.money
    label(page, "MoneyTitle", "MONEY MULTIPLIER", moneyStyle.Title, moneyStyle.TitleSize, Config.White, Z + 2, {
        stroke = 4,
    })
    label(page, "MoneyValue", money.value, moneyStyle.Value, moneyStyle.ValueSize, Config.Gold, Z + 2, { stroke = 4 })
    local p = moneyStyle.Pips
    local rowWidth = money.maxLevel * p.Size + (money.maxLevel - 1) * p.Gap
    pips(page, p.CentreX - rowWidth / 2, p.Y, p.Size, p.Gap, money.level, money.maxLevel, Z + 2)
    label(page, "MoneyLevel", money.levelText, moneyStyle.Level, moneyStyle.LevelSize, Config.White, Z + 2, {
        stroke = 2,
    })
    local moneyPrice = money.maxed and "MAXED" or money.price
    button(page, "MoneyBuy", moneyStyle.Button, moneyPrice, style.ButtonSize, not money.maxed, money.onBuy, Z + 2)
end

-- ===== CASH =====
function ShopMenuComponent:_cashPage()
    self:_pageArt("CASH")
    local style, page = Config.Cash, self.page
    for i, pack in self.model.cash do
        local spec = style.Cards[i]
        if spec then
            if pack.badge and spec.Badge then
                local b = spec.Badge
                local badgeRect = { b[1] + 6, b[2] + 4, b[3] - 12, b[4] - 8 }
                label(page, "Badge" .. i, pack.badge, badgeRect, style.BadgeSize, Config.White, Z + 3, { stroke = 2 })
            end
            label(page, "Amount" .. i, pack.amount, spec.Amount, style.AmountSize, Config.White, Z + 2, { stroke = 4 })
            label(page, "Text" .. i, pack.text, spec.Text, style.TextSize, Config.White, Z + 2, { stroke = 2 })
            button(page, "Buy" .. i, spec.Button, pack.price, style.ButtonSize, pack.onBuy ~= nil, pack.onBuy, Z + 2)
        end
    end
end

-- ===== DAILY =====
function ShopMenuComponent:_dailyPage()
    self:_pageArt("DAILY")
    local style, daily, page = Config.Daily, self.model.daily, self.page
    label(page, "Intro", style.IntroText, style.Intro, style.IntroSize, Config.White, Z + 2)
    for i, day in daily.days do
        local r = style.Cards[i]
        if r then
            local card = new("Frame", "Day" .. i, page, Z + 2)
            rect(card, r)
            if day.state == "claimed" then
                shade(card, style.ClaimedShade)
            elseif day.state == "today" then
                local frame = new("Frame", "Today", card, Z + 2)
                frame.Size = UDim2.fromScale(1, 1)
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0, 12)
                corner.Parent = frame
                local stroke = Instance.new("UIStroke")
                stroke.Color = style.TodayStroke.Color
                stroke.Thickness = style.TodayStroke.Thickness
                stroke.Parent = frame
            end
            label(card, "Day", day.label, style.Day, style.DaySize, Config.White, Z + 3, { alignX = LEFT })
            local valueRect = { 10, r[4] - style.ValueBottom, r[3] - 20, 30 }
            label(card, "Value", day.value, valueRect, style.ValueSize, day.valueColor or Config.White, Z + 3)
            local m = style.Mark
            local markRect = { r[3] - m[1], m[2], m[3], m[4] }
            if day.state == "claimed" then
                label(card, "Mark", "✓", markRect, style.MarkSize, Config.Green, Z + 3)
            elseif day.state == "locked" then
                label(card, "Mark", "🔒", markRect, style.MarkSize - 6, Config.White, Z + 3, { stroke = 0 })
            end
        end
    end
    if daily.ready then
        button(page, "Claim", style.Button, daily.claimText, style.ButtonSize, true, daily.onClaim, Z + 2)
        label(page, "Next", "Your reward is ready!", style.Next, style.NextSize, Config.Gold, Z + 2, { alignX = LEFT })
    else
        button(page, "Claim", style.Button, "CLAIMED", style.ButtonSize, false, nil, Z + 2)
        local nextLabel = label(page, "Next", "", style.Next, style.NextSize, Config.White, Z + 2, { alignX = LEFT })
        self:_tick(daily.nextEnds, function(secondsLeft)
            nextLabel.Text = "Next reward in " .. formatHms(secondsLeft)
        end)
    end
end

local PAGES = {
    FEATURED = ShopMenuComponent._featured,
    BOOSTS = ShopMenuComponent._boostsPage,
    PASSES = ShopMenuComponent._passesPage,
    CASH = ShopMenuComponent._cashPage,
    DAILY = ShopMenuComponent._dailyPage,
}

function ShopMenuComponent:_buildTabs()
    local tabs = Config.Tabs
    for _, key in tabs.Keys do
        local spec = tabs[key]
        local r = spec.Rect
        local selected = self.model.tab == key
        sliced(self.canvas, "TabArt_" .. key, selected and "TabOn" or "TabOff", r, tabs.Slice, Z + 1)
        piece(self.canvas, "TabIcon_" .. key, spec.Icon[1], Vector2.new(spec.Icon[2], spec.Icon[3]), Z + 2)
        piece(self.canvas, "TabLabel_" .. key, spec.Label[1], Vector2.new(spec.Label[2], spec.Label[3]), Z + 2)
        hitBox(self.canvas, "Tab_" .. key, r, function()
            self.model.onTab(key)
        end, Z + 4)
        if key == "DAILY" and self.model.daily.ready then
            local alert = tabs.Alert
            local dot = new("Frame", "Alert", self.canvas, Z + 3)
            dot.BackgroundTransparency = 0
            dot.BackgroundColor3 = alert.Color
            rect(dot, { r[1] + r[3] - alert.Size + alert.Inset, r[2] - alert.Inset, alert.Size, alert.Size })
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0.5, 0)
            corner.Parent = dot
            local stroke = Instance.new("UIStroke")
            stroke.Color = Config.White
            stroke.Thickness = 2
            stroke.Parent = dot
            label(dot, "Mark", "!", { 0, 0, alert.Size, alert.Size }, 22, Config.White, Z + 4, { stroke = 0 })
        end
    end
end

function ShopMenuComponent.new(panel, layer, model)
    local self = setmetatable({ model = model, panel = panel, alive = true }, ShopMenuComponent)
    for _, name in { "CleanSkin", "CleanBase", "FigmaWindow" } do
        local child = panel:FindFirstChild(name)
        if child and child:IsA("GuiObject") then
            child.Visible = false
        end
    end
    -- the panel's own Close button becomes an invisible hit-box over the drawn X
    local closeButton = panel:FindFirstChild("Close")
    if closeButton then
        local close = Config.Close
        closeButton.AnchorPoint = Vector2.zero
        closeButton.Position = UDim2.fromScale(close[1] / CANVAS.X, close[2] / CANVAS.Y)
        closeButton.Size = UDim2.fromScale(close[3] / CANVAS.X, close[4] / CANVAS.Y)
        closeButton.BackgroundTransparency = 1
        closeButton.ZIndex = 30
        for _, descendant in closeButton:GetDescendants() do
            if descendant:IsA("GuiObject") then
                descendant.Visible = false
            elseif descendant:IsA("UIStroke") then
                descendant.Enabled = false
            end
        end
        if closeButton:IsA("ImageButton") then
            closeButton.ImageTransparency = 1
        elseif closeButton:IsA("TextButton") then
            closeButton.TextTransparency = 1
        end
    end

    local canvas = new("Frame", "ShopCanvas", nil, Z)
    canvas.AnchorPoint = Vector2.new(0.5, 0.5)
    canvas.Position = UDim2.fromScale(0.5, 0.5)
    canvas.Size = UDim2.fromOffset(CANVAS.X, CANVAS.Y)
    local scale = Instance.new("UIScale")
    scale.Parent = canvas
    local function fit()
        scale.Scale = math.max(panel.Size.X.Offset, 1) / CANVAS.X
    end
    fit()
    self.sizeConnection = panel:GetPropertyChangedSignal("Size"):Connect(fit)
    self.canvas = canvas

    local background = new("ImageLabel", "Background", canvas, Z)
    background.Image = Config.Background
    background.Size = UDim2.fromScale(1, 1)
    self:_buildTabs()
    local page = new("Frame", "Page", canvas, Z)
    page.Size = UDim2.fromScale(1, 1)
    page:SetAttribute("NoSkin", true)
    self.page = page
    PAGES[model.tab](self)
    canvas.Parent = layer
    return self
end

function ShopMenuComponent:Destroy()
    self.alive = false
    self.sizeConnection:Disconnect()
    self.canvas:Destroy()
end

return ShopMenuComponent
