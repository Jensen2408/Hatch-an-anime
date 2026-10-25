-- GameMenus.QuestMenuComponent  (ModuleScript, client)
-- Draws the Quests menu (Figma "04 Quests") from a view model with the StudKit pieces. Display only:
-- MenuLogic (RENDER.Quests) reads the quest state and passes Claim / Claim all as callbacks.
--
--   StudCanvas
--   ├── Shadow, Plate, Header (+ Close art)   Panel + Header/green
--   ├── Tab_<period> x3 (+ red ready count)   Tab/Selected, Tab/Default
--   ├── List (ScrollingFrame)                 QuestRow per quest
--   └── ResetText, ClaimAll                   footer
--
-- model = {
--   tabs = { { key, label, selected, ready, onActivate } x3 },
--   quests = { { title, text, icon, progress (0..1), count, reward?, rewardIcon?, state = "claimable" |
--                "active" | "claimed", onActivate } },
--   resetEndsAt? (os.clock), claimAll = { text, enabled, onActivate }, emptyText,
-- }
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = ReplicatedStorage:WaitForChild("StudKit")
local StudUI = require(Kit:WaitForChild("StudUI"))
local Theme = require(Kit:WaitForChild("StudTheme"))
local Config = require(script.Parent:WaitForChild("QuestMenuConfig"))

local Colors = Theme.Colors
local label, centered = StudUI.label, StudUI.centered

local QuestMenuComponent = {}
QuestMenuComponent.__index = QuestMenuComponent

local BUTTONS = {
    claimable = { Text = "CLAIM", Color = Colors.Green },
    active = { Text = "GO", Color = Colors.Blue },
    claimed = { Text = "DONE", Color = Colors.Disabled },
}

local function image(parent, name, source, r)
    if not source or source == "" then
        return
    end
    local picture = Instance.new("ImageLabel")
    picture.Name = name
    picture.BackgroundTransparency = 1
    picture.Image = source
    picture.ScaleType = Enum.ScaleType.Fit
    picture.ZIndex = parent.ZIndex + 1
    StudUI.rect(picture, r)
    picture.Parent = parent
end

-- 12:45:30 (days fold into hours)
local function formatHms(seconds)
    seconds = math.max(0, math.floor(seconds))
    return string.format("%d:%02d:%02d", seconds // 3600, (seconds // 60) % 60, seconds % 60)
end

-- QuestRow: icon tile, title + description, progress + count, reward chip, CLAIM / GO / DONE
local function questRow(parent, i, quest, y)
    local style = Config.Row
    local claimable = quest.state == "claimable"
    local row, stroke = StudUI.card(
        parent,
        "Quest" .. i,
        { 0, y, style.Size.X, style.Size.Y },
        quest.state == "claimed" and Colors.Panel or Colors.Panel2,
        style.Radius,
        claimable and Colors.Green or Colors.Ink
    )
    if claimable then
        stroke.Thickness = style.ClaimableBorder
    end
    local tile = StudUI.plate(
        row,
        "IconTile",
        style.IconRect,
        quest.state == "claimed" and Colors.Green or Colors.Blue,
        style.IconRadius,
        Colors.Ink
    )
    if quest.state == "claimed" then
        label(
            tile,
            "Check",
            "✓",
            { 0, 0, style.IconRect[3], style.IconRect[4] },
            56,
            Colors.White,
            centered({
                display = true,
            })
        )
    else
        image(tile, "Icon", quest.icon, { 8, 8, style.IconRect[3] - 16, style.IconRect[4] - 16 })
    end
    label(row, "Title", quest.title, style.TitleRect, style.TitleSize, Colors.White, { display = true })
    label(row, "Text", quest.text, style.TextRect, style.TextSize, Colors.Muted)
    StudUI.progress(row, "Progress", style.ProgressRect, quest.progress, claimable and Colors.Green or Colors.Blue)
    label(row, "Count", quest.count, style.CountRect, style.CountSize, Colors.White)
    if quest.reward then
        local chip = StudUI.plate(row, "Reward", style.RewardRect, Colors.Ink, 10)
        image(chip, "Icon", quest.rewardIcon, style.RewardIconRect)
        label(chip, "Text", quest.reward, quest.rewardIcon and style.RewardTextRect or {
            8,
            style.RewardTextRect[2],
            style.RewardRect[3] - 16,
            style.RewardTextRect[4],
        }, style.RewardSize, Colors.Gold, centered({ display = true }))
    end
    local button = BUTTONS[quest.state]
    StudUI.button(row, "Action", style.ButtonRect, button.Color, button.Text, {
        enabled = quest.state ~= "claimed",
        onActivate = quest.onActivate,
    })
end

function QuestMenuComponent.new(panel, layer, model)
    local self = setmetatable({ model = model, alive = true }, QuestMenuComponent)
    self.canvas, self.stopCanvas = StudUI.newCanvas(panel, layer)
    local z = StudUI.shell(self.canvas, Colors.Green, Config.Title)

    local tabs = Config.Tabs
    for i, tabModel in model.tabs do
        local tab = StudUI.tab(
            self.canvas,
            "Tab_" .. tabModel.key,
            { tabs.Xs[i], tabs.Y, tabs.Width, tabs.Height },
            tabModel.label,
            tabModel.selected,
            tabModel.onActivate,
            z
        )
        if tabModel.ready > 0 then
            StudUI.badge(tab, "Ready", tabs.Badge, tostring(tabModel.ready), Colors.Red, tab.ZIndex + 4)
        end
    end

    local list = Config.List
    local r = list.Rect
    if #model.quests == 0 then
        label(self.canvas, "Empty", model.emptyText, Config.EmptyRect, 28, Colors.Muted, centered({ zIndex = z }))
    else
        local scroller = StudUI.scroller(self.canvas, "List", r, z)
        for i, quest in model.quests do
            questRow(scroller, i, quest, (i - 1) * list.RowStep)
        end
        StudUI.setScrollHeight(scroller, (#model.quests - 1) * list.RowStep + Config.Row.Size.Y)
    end

    local footer = Config.Footer
    if model.resetEndsAt then
        local resetText = label(self.canvas, "ResetText", "", footer.TextRect, footer.TextSize, Colors.White, {
            zIndex = z,
        })
        local function update()
            resetText.Text = "Resets in " .. formatHms(model.resetEndsAt - os.clock())
        end
        update()
        task.spawn(function()
            while self.alive do
                task.wait(1)
                if self.alive then
                    update()
                end
            end
        end)
    end
    StudUI.button(self.canvas, "ClaimAll", footer.ButtonRect, Colors.Green, model.claimAll.text, {
        enabled = model.claimAll.enabled,
        onActivate = model.claimAll.onActivate,
        zIndex = z,
    })
    return self
end

function QuestMenuComponent:Destroy()
    self.alive = false
    self.stopCanvas()
    self.canvas:Destroy()
end

return QuestMenuComponent
