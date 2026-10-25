-- GameMenus.ShopMenuComponent  (ModuleScript, client)
-- Draws the Shop menu (Figma "01 Shop", tabs FEATURED / BOOSTS / PASSES / CASH / DAILY) from a view model
-- with the StudUI kit. Display only: MenuLogic (RENDER.VipShop) reads ShopRemote "State", formats prices and
-- passes the purchases as callbacks. Live countdowns tick here while the view exists.
--
--   StudCanvas (1160x730, UIScale = panel width / 1160)
--   ├── Shadow, Plate, Header (+ Close art)   Panel + Header/orange
--   ├── Tab_FEATURED .. Tab_DAILY             Tab/Selected, Tab/Default (+ "!" alert on DAILY)
--   └── Page                                  the selected tab's cards
--
--   local view = ShopMenuComponent.new(panel, layer, model)
--   view:Destroy()
--
-- model = {
--   title, tab, onTab(tab),
--   icons = { crown, coin, hatch, money2x, hatch2x, chest },
--   limited = { name, text, art?, eggModel?, endsAt (os.clock), price, onBuy }?,
--   vip = { text, perks, price, owned, onBuy },
--   boosts = { { title, shortText, text, icon, price, activeEnds? (os.clock), duration, onBuy } x2 },
--   starter = { title, text, price, owned, onBuy },
--   money = { value, level, maxLevel, price, maxed, onBuy },
--   cash = { { amount, text, badge?, badgeColor?, price, onBuy } x3 },
--   daily = { days = { { label, icon, value, valueColor, state = "claimed" | "today" | "locked", last } },
--             ready, claimText, nextEnds (os.clock), onClaim },
-- }
local RunService = game:GetService("RunService")

local Kit = game:GetService("ReplicatedStorage"):WaitForChild("StudKit")
local Config = require(script.Parent:WaitForChild("ShopMenuConfig"))
local StudUI = require(Kit:WaitForChild("StudUI"))
local Theme = require(Kit:WaitForChild("StudTheme"))

local Colors = Theme.Colors
local label, centered = StudUI.label, StudUI.centered

local ShopMenuComponent = {}
ShopMenuComponent.__index = ShopMenuComponent

-- 1:02:03
local function formatHms(seconds)
    seconds = math.max(0, math.floor(seconds))
    return string.format("%d:%02d:%02d", seconds // 3600, (seconds // 60) % 60, seconds % 60)
end

-- 12d 12h 28m (the limited art's timer format); under a day: 12h 28m 05s
local function formatDhm(seconds)
    seconds = math.max(0, math.floor(seconds))
    local days, hours, minutes = seconds // 86400, (seconds // 3600) % 24, (seconds // 60) % 60
    if days > 0 then
        return string.format("%dd %dh %02dm", days, hours, minutes)
    end
    return string.format("%dh %02dm %02ds", hours, minutes, seconds % 60)
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

local function icon(parent, name, image, r)
    if not image or image == "" then
        return
    end
    local iconImage = Instance.new("ImageLabel")
    iconImage.Name = name
    iconImage.BackgroundTransparency = 1
    iconImage.Image = image
    iconImage.ScaleType = Enum.ScaleType.Fit
    iconImage.ZIndex = parent.ZIndex + 1
    StudUI.rect(iconImage, r)
    iconImage.Parent = parent
    return iconImage
end

-- Card placed on the page at canvas rect r
function ShopMenuComponent:_card(name, r, color, radius, borderColor)
    return StudUI.card(self.page, name, r, color, radius, borderColor, nil, self.zContent)
end

-- Price button that turns into a grey "OWNED" when the item is owned
local function buyButton(parent, r, item, labelSize)
    return StudUI.button(parent, "Buy", r, Colors.Green, item.owned and "OWNED" or item.price, {
        enabled = not item.owned,
        onActivate = item.onBuy,
        labelSize = labelSize,
    })
end

-- Limited deal: the art (or the spinning egg model until the art is uploaded), LIMITED badge, live timer
function ShopMenuComponent:_limitedArt(card, limited, style)
    local art = style.ArtRect
    if limited.art then
        local image = icon(card, "Art", limited.art, art)
        image.ScaleType = Enum.ScaleType.Crop
        local artCorner = Instance.new("UICorner")
        artCorner.CornerRadius = UDim.new(0, 8)
        artCorner.Parent = image
    else
        local stage = StudUI.plate(card, "Art", art, Colors.Ink, 8)
        StudUI.studs(stage, 8)
        if limited.eggModel then
            local viewport = Instance.new("ViewportFrame")
            viewport.Name = "Egg"
            viewport.BackgroundTransparency = 1
            viewport.Size = UDim2.fromScale(1, 1)
            viewport.ZIndex = stage.ZIndex + 1
            viewport.Ambient = Color3.new(1, 1, 1)
            viewport.LightColor = Color3.new(1, 1, 1)
            viewport.LightDirection = Vector3.new(-0.4, -0.6, -1)
            local egg = limited.eggModel:Clone()
            egg.Parent = viewport
            local boundsCFrame, boundsSize = egg:GetBoundingBox()
            egg:PivotTo(CFrame.new(-boundsCFrame.Position) * egg:GetPivot())
            local camera = Instance.new("Camera")
            camera.FieldOfView = 40
            camera.CFrame =
                CFrame.lookAt(Vector3.new(0, boundsSize.Y * 0.08, -boundsSize.Magnitude * 1.2), Vector3.zero)
            camera.Parent = viewport
            viewport.CurrentCamera = camera
            viewport.Parent = stage
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
                egg:PivotTo(
                    CFrame.new(0, math.sin(elapsed * 2) * 0.25, 0) * CFrame.Angles(0, elapsed * 0.9, 0) * basePivot
                )
            end)
        end
    end
    StudUI.badge(card, "Badge", style.BadgeRect, style.BadgeText, Colors.Purple, card.ZIndex + 3)
    local timer = StudUI.plate(card, "Timer", style.TimerRect, Colors.Ink, style.TimerRadius, nil, card.ZIndex + 3)
    local r = style.TimerRect
    local timerText = label(
        timer,
        "Text",
        "",
        { 8, 4, r[3] - 16, r[4] - 8 },
        style.TimerSize,
        Colors.White,
        centered({
            display = true,
        })
    )
    self:_tick(limited.endsAt, function(secondsLeft)
        timerText.Text = secondsLeft > 0 and formatDhm(secondsLeft) or "ENDED"
    end)
end

-- ===== FEATURED (Figma "01 Shop") =====
function ShopMenuComponent:_featured()
    local model, featured = self.model, Config.Featured

    local limited = model.limited
    if limited then
        local style = featured.Limited
        local card = self:_card("Limited", style.Rect, Colors.Purple, style.Radius, Colors.Muted)
        self:_limitedArt(card, limited, style)
        label(card, "Title", limited.name, style.TitleRect, style.TitleSize, Colors.White, centered({ display = true }))
        label(card, "Text", limited.text, style.TextRect, style.TextSize, Colors.Muted, centered())
        StudUI.button(card, "Buy", style.ButtonRect, Colors.Green, "BUY · " .. limited.price, {
            onActivate = limited.onBuy,
        })
    end

    local vipStyle = featured.Vip
    local vip = self:_card("Vip", vipStyle.Rect, Colors.Purple, vipStyle.Radius, Colors.Muted)
    icon(vip, "Icon", model.icons.crown, vipStyle.IconRect)
    label(vip, "Title", "VIP", vipStyle.TitleRect, vipStyle.TitleSize, Colors.White, { display = true })
    label(vip, "Text", model.vip.text, vipStyle.TextRect, vipStyle.TextSize, Colors.Muted)
    buyButton(vip, vipStyle.ButtonRect, model.vip)

    local boostStyle = featured.Boost
    for i, boost in model.boosts do
        local card = self:_card(
            "Boost" .. i,
            boostStyle.Rects[i],
            i == 1 and Colors.Green or Colors.Gold,
            boostStyle.Radius,
            Colors.Ink
        )
        icon(card, "Icon", boost.icon, boostStyle.IconRect)
        label(card, "Title", boost.title, boostStyle.TitleRect, boostStyle.TitleSize, Colors.White, { stroke = 2 })
        local text = label(card, "Text", "", boostStyle.TextRect, boostStyle.TextSize, Colors.White, { stroke = 1.5 })
        self:_boostText(text, boost, boost.shortText)
        StudUI.button(card, "Buy", boostStyle.ButtonRect, Colors.Green, boost.price, { onActivate = boost.onBuy })
    end

    self:_starter(featured.Starter.Rect, featured.Starter.ButtonRect)
end

-- Boost description, replaced by a live "ACTIVE 0:12:34" while the boost runs
function ShopMenuComponent:_boostText(text, boost, idleText, bar)
    if not boost.activeEnds then
        text.Text = idleText
        return
    end
    self:_tick(boost.activeEnds, function(secondsLeft)
        text.Text = secondsLeft > 0 and ("ACTIVE " .. formatHms(secondsLeft)) or idleText
        if bar then
            bar(secondsLeft / boost.duration)
        end
    end)
end

function ShopMenuComponent:_starter(r, buttonRect)
    local style = Config.Featured.Starter
    local starter = self.model.starter
    local card = self:_card("Starter", r, Colors.Gold, style.Radius, Colors.Ink)
    -- text spans up to the button, so the wide BOOSTS row gets the room as well
    local function leftOfButton(rect)
        return { rect[1], rect[2], buttonRect[1] - rect[1] - 16, rect[4] }
    end
    label(card, "Title", starter.title, leftOfButton(style.TitleRect), style.TitleSize, Colors.Ink, {
        display = true,
        stroke = 0, -- ink text on gold: no outline (Figma)
    })
    label(card, "Text", starter.text, leftOfButton(style.TextRect), style.TextSize, Colors.Ink)
    buyButton(card, buttonRect, starter)
end

-- ===== BOOSTS =====
function ShopMenuComponent:_boostsPage()
    local style = Config.Boosts
    for i, boost in self.model.boosts do
        local card =
            self:_card("Boost" .. i, style.Rects[i], i == 1 and Colors.Green or Colors.Gold, style.Radius, Colors.Ink)
        icon(card, "Icon", boost.icon, style.IconRect)
        label(card, "Title", boost.title, style.TitleRect, style.TitleSize, Colors.White, centered({ display = true }))
        label(card, "Text", boost.text, style.TextRect, style.TextSize, Colors.White, centered({ stroke = 1.5 }))
        local _, setBar = StudUI.progress(card, "Timer", style.TimerBarRect, 0, Colors.Green)
        local timerText = label(
            card,
            "TimerText",
            "",
            style.TimerTextRect,
            style.TimerTextSize,
            Colors.White,
            centered({
                stroke = 1.5,
            })
        )
        self:_boostText(timerText, boost, "Not active", setBar)
        StudUI.button(card, "Buy", style.ButtonRect, Colors.Green, boost.price, { onActivate = boost.onBuy })
    end
    self:_starter(style.StarterRect, style.StarterButtonRect)
end

-- ===== PASSES =====
function ShopMenuComponent:_passesPage()
    local style, model = Config.Passes, self.model
    local vip = self:_card("Vip", style.Rects[1], Colors.Purple, style.Radius, Colors.Muted)
    icon(vip, "Icon", model.icons.crown, style.IconRect)
    label(vip, "Title", "VIP", style.TitleRect, style.TitleSize, Colors.White, centered({ display = true }))
    label(vip, "Text", model.vip.perks, style.TextRect, style.TextSize, Colors.Muted, centered({ wrap = true }))
    buyButton(vip, style.ButtonRect, model.vip)

    local money = model.money
    local card = self:_card("MoneyMultiplier", style.Rects[2], Colors.Green, style.Radius, Colors.Ink)
    icon(card, "Icon", model.icons.coin, style.IconRect)
    label(
        card,
        "Title",
        "MONEY MULTIPLIER",
        style.MultTitleRect,
        style.MultTitleSize,
        Colors.White,
        centered({
            display = true,
        })
    )
    label(card, "Value", money.value, style.ValueRect, style.ValueSize, Colors.White, centered({ display = true }))
    local pips = style.Pips
    local rowWidth = money.maxLevel * pips.Size + (money.maxLevel - 1) * pips.Gap
    local x0 = (style.Rects[2][3] - rowWidth) / 2
    for i = 1, money.maxLevel do
        StudUI.plate(
            card,
            "Pip" .. i,
            { x0 + (i - 1) * (pips.Size + pips.Gap), pips.Y, pips.Size, pips.Size },
            i <= money.level and Colors.Gold or Colors.Ink,
            pips.Radius,
            Colors.Ink
        )
    end
    label(card, "Level", money.levelText, style.LevelRect, style.LevelSize, Colors.White, centered({ stroke = 1.5 }))
    StudUI.button(card, "Buy", style.ButtonRect, Colors.Green, money.maxed and "MAXED" or money.price, {
        enabled = not money.maxed,
        onActivate = money.onBuy,
    })
end

-- ===== CASH =====
function ShopMenuComponent:_cashPage()
    local style = Config.Cash
    for i, pack in self.model.cash do
        local r = { style.X + (i - 1) * (style.Width + style.Gap), style.Y, style.Width, style.Height }
        local card = self:_card("Cash" .. i, r, Colors[style.Colors[i]], style.Radius, Colors.Ink)
        local area, size = style.IconArea, style.IconSizes[i]
        icon(card, "Icon", self.model.icons.coin, {
            area[1] + (area[3] - size) / 2,
            area[2] + (area[4] - size) / 2,
            size,
            size,
        })
        if pack.badge then
            StudUI.badge(card, "Badge", style.BadgeRect, pack.badge, pack.badgeColor, card.ZIndex + 3)
        end
        label(
            card,
            "Amount",
            pack.amount,
            style.AmountRect,
            style.AmountSize,
            Colors.White,
            centered({ display = true })
        )
        label(card, "Text", pack.text, style.TextRect, style.TextSize, Colors.White, centered({ stroke = 1.5 }))
        StudUI.button(card, "Buy", style.ButtonRect, Colors.Green, pack.price, {
            enabled = pack.onBuy ~= nil,
            onActivate = pack.onBuy or function() end,
        })
    end
end

-- ===== DAILY (Figma "07 Daily" day cards) =====
function ShopMenuComponent:_dailyPage()
    local style, daily = Config.Daily, self.model.daily
    label(self.page, "Intro", style.Intro, style.IntroRect, style.IntroSize, Colors.White, {
        zIndex = self.zContent,
    })
    local stepX, stepY = style.CardSize.X + style.Gap.X, style.CardSize.Y + style.Gap.Y
    for i, day in daily.days do
        local column, row = (i - 1) % style.Columns, (i - 1) // style.Columns
        local color = day.state == "today" and Colors.Orange or day.last and Colors.Purple or Colors.Panel2
        local borderColor = day.state == "today" and Colors.White
            or day.state == "claimed" and Colors.Green
            or Colors.Muted
        local card, stroke = self:_card(
            "Day" .. i,
            { style.X + column * stepX, style.Y + row * stepY, style.CardSize.X, style.CardSize.Y },
            color,
            style.Radius,
            borderColor
        )
        if day.state == "today" then
            stroke.Thickness = 4
        end
        label(card, "Day", day.label, style.DayRect, style.DaySize, Colors.White, centered({ display = true }))
        icon(card, "Icon", day.icon, style.IconRect)
        label(card, "Value", day.value, style.ValueRect, style.ValueSize, day.valueColor, centered({ display = true }))
        if day.state == "claimed" then
            label(card, "Mark", "✓", style.MarkRect, style.MarkSize, Colors.Green, centered({ display = true }))
        elseif day.state == "locked" then
            label(card, "Mark", "🔒", style.MarkRect, style.MarkSize - 6, Colors.White, centered())
        end
    end
    if daily.ready then
        StudUI.button(self.page, "Claim", style.ButtonRect, Colors.Green, daily.claimText, {
            onActivate = daily.onClaim,
            zIndex = self.zContent,
        })
        label(self.page, "Next", "Your reward is ready!", style.NextRect, style.NextSize, Colors.Gold, {
            zIndex = self.zContent,
        })
    else
        StudUI.button(self.page, "Claim", style.ButtonRect, Colors.Green, "CLAIMED", {
            enabled = false,
            onActivate = function() end,
            zIndex = self.zContent,
        })
        local nextLabel = label(self.page, "Next", "", style.NextRect, style.NextSize, Colors.White, {
            zIndex = self.zContent,
        })
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
    for i, key in tabs.Keys do
        local r = { tabs.X + (i - 1) * (tabs.Width + tabs.Gap), tabs.Y, tabs.Width, tabs.Height }
        local tab = StudUI.tab(self.canvas, "Tab_" .. key, r, key, self.model.tab == key, function()
            self.model.onTab(key)
        end, self.zContent)
        if key == "DAILY" and self.model.daily.ready then
            local alert = tabs.Alert
            local dot = StudUI.plate(
                tab,
                "Alert",
                { r[3] - alert.Size + alert.Inset, -alert.Inset, alert.Size, alert.Size },
                Colors.Red,
                alert.Size / 2,
                Colors.White,
                tab.ZIndex + 4
            )
            label(dot, "Mark", "!", { 0, 0, alert.Size, alert.Size }, 18, Colors.White, centered({ display = true }))
        end
    end
end

function ShopMenuComponent.new(panel, layer, model)
    local self = setmetatable({ model = model, panel = panel, alive = true }, ShopMenuComponent)
    self.canvas, self.stopCanvas = StudUI.newCanvas(panel, layer)
    self.zContent = StudUI.shell(self.canvas, Colors.Orange, model.title)
    self:_buildTabs()
    -- page holder: same size as the canvas, so page rects are canvas rects
    local page = Instance.new("Frame")
    page.Name = "Page"
    page.BackgroundTransparency = 1
    page.Size = UDim2.fromScale(1, 1)
    page.ZIndex = self.zContent - 1
    page:SetAttribute("NoSkin", true)
    page.Parent = self.canvas
    self.page = page
    PAGES[model.tab](self)
    return self
end

function ShopMenuComponent:Destroy()
    self.alive = false
    self.stopCanvas()
    self.canvas:Destroy()
end

return ShopMenuComponent
