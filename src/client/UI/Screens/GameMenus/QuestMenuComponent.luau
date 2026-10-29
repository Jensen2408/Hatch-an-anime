-- GameMenus.QuestMenuComponent  (ModuleScript, client)
-- Draws the Quests menu from the MenuArt art (window background with the footer, tab / row / button pieces).
-- Display only: MenuLogic (RENDER.Quests) reads the quest state and passes Claim / Claim all as callbacks.
--
--   StudCanvas (1160 x 730, UIScale = panel width / 1160)
--   ├── Background                            header, Close X, footer (reset strip + CLAIM ALL button)
--   ├── Tab_<period> x3 (+ red ready count)
--   ├── List (ScrollingFrame)                 one row per quest
--   └── ResetText, ClaimAll                   footer texts / hit-box
--
-- model = {
--   tabs = { { key, label, selected, ready, onActivate } x3 },
--   quests = { { title, text, icon, progress (0..1), count, reward?, rewardIcon?, state = "claimable" |
--                "active" | "claimed", onActivate } },
--   resetEndsAt? (os.clock), claimAll = { text, enabled, onActivate }, emptyText,
-- }
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StudUI = require(ReplicatedStorage:WaitForChild("StudKit"):WaitForChild("StudUI"))
local Theme = require(ReplicatedStorage.StudKit:WaitForChild("StudTheme"))
local MenuArt = require(ReplicatedStorage:WaitForChild("MenuArt"):WaitForChild("MenuArt"))
local Config = require(script.Parent:WaitForChild("QuestMenuConfig"))

local Colors = MenuArt.Colors
local CENTER = Enum.TextXAlignment.Center
local Z = 10

local QuestMenuComponent = {}
QuestMenuComponent.__index = QuestMenuComponent

local BUTTONS = {
    claimable = { Text = "CLAIM", Piece = "ButtonGreen" },
    active = { Text = "GO", Piece = "ButtonBlue" },
    claimed = { Text = "DONE", Piece = "ButtonGrey" },
}

local function image(parent, name, source, r, zIndex)
    if not source or source == "" then
        return
    end
    local picture = MenuArt.new("ImageLabel", name, parent, zIndex)
    picture.Image = source
    picture.ScaleType = Enum.ScaleType.Fit
    MenuArt.rect(picture, r)
end

-- 12:45:30 (days fold into hours)
local function formatHms(seconds)
    seconds = math.max(0, math.floor(seconds))
    return string.format("%d:%02d:%02d", seconds // 3600, (seconds // 60) % 60, seconds % 60)
end

-- one quest: card (+ glow while claimable), icon tile, title + description, progress + count, reward, button
local function questRow(parent, i, quest, y)
    local style = Config.Row
    local list = Config.List
    local claimable, claimed = quest.state == "claimable", quest.state == "claimed"
    local row = MenuArt.new("Frame", "Quest" .. i, parent, Z + 1)
    MenuArt.rect(row, { list.X, y, style.Size.X, style.Size.Y })
    local card = MenuArt.piece(row, "Card", "RowCard", { 0, 0 }, Z + 1)
    if claimed then
        card.ImageColor3 = style.ClaimedTint
    end
    if claimable then
        local o = style.GlowOutset
        MenuArt.piece(row, "Glow", "RowGlow", { -o.X, -o.Y }, Z + 2)
    end
    local icon = style.IconRect
    MenuArt.piece(row, "IconTile", "IconTile", icon, Z + 2)
    local inset = style.IconInset
    if claimed then
        MenuArt.label(row, "Check", "✓", icon, 60, Colors.White, Z + 3, { alignX = CENTER })
    else
        image(
            row,
            "Icon",
            quest.icon,
            { icon[1] + inset, icon[2] + inset, icon[3] - inset * 2, icon[4] - inset * 2 },
            Z + 3
        )
    end
    MenuArt.label(row, "Title", quest.title, style.TitleRect, style.TitleSize, Colors.White, Z + 3)
    MenuArt.label(row, "Text", quest.text, style.TextRect, style.TextSize, Colors.Muted, Z + 3, { stroke = 2 })
    local track = style.TrackRect
    MenuArt.piece(row, "Track", "Track", track, Z + 2, 9)
    local progress = math.clamp(quest.progress or 0, 0, 1)
    if progress > 0 then
        local clip = MenuArt.new("Frame", "FillClip", row, Z + 3)
        clip.ClipsDescendants = true
        MenuArt.rect(clip, { track[1] + 1, track[2] + 1, (track[3] - 2) * progress, track[4] - 2 })
        MenuArt.piece(clip, "Fill", "Fill", { 0, 0, track[3] - 2, track[4] - 2 }, Z + 3, 8)
    end
    MenuArt.label(row, "Count", quest.count, style.CountRect, style.CountSize, Colors.White, Z + 3, { stroke = 2 })
    if quest.reward then
        local pill = style.RewardRect
        MenuArt.piece(row, "Reward", "RewardPill", pill, Z + 2)
        local hasIcon = quest.rewardIcon ~= nil
        if hasIcon then
            local r = style.RewardIconRect
            image(row, "RewardIcon", quest.rewardIcon, { pill[1] + r[1], pill[2] + r[2], r[3], r[4] }, Z + 3)
        end
        local t = style.RewardTextRect
        local textRect = hasIcon and { pill[1] + t[1], pill[2] + t[2], t[3], t[4] }
            or { pill[1] + 8, pill[2] + t[2], pill[3] - 16, t[4] }
        MenuArt.label(
            row,
            "RewardText",
            quest.reward,
            textRect,
            style.RewardSize,
            Colors.Gold,
            Z + 3,
            { alignX = CENTER }
        )
    end
    local button, b = BUTTONS[quest.state], style.ButtonRect
    MenuArt.piece(row, "Action", button.Piece, b, Z + 2)
    MenuArt.label(
        row,
        "ActionText",
        button.Text,
        { b[1] + 8, b[2] + 6, b[3] - 16, b[4] - 14 },
        style.ButtonSize,
        Colors.White,
        Z + 3,
        {
            alignX = CENTER,
        }
    )
    MenuArt.hitBox(row, "ActionHit", b, not claimed and quest.onActivate or nil, Z + 4)
end

function QuestMenuComponent.new(panel, layer, model)
    local self = setmetatable({ model = model, alive = true }, QuestMenuComponent)
    self.canvas, self.stopCanvas = StudUI.newCanvas(panel, layer)
    MenuArt.useClose(panel, Theme.CanvasSize, Config.Close)
    MenuArt.background(self.canvas, "Quests", nil, Z)

    local tabs = Config.Tabs
    for i, tabModel in model.tabs do
        local r = tabs.Rects[i]
        if r then
            MenuArt.piece(self.canvas, "TabArt_" .. tabModel.key, tabModel.selected and "TabOn" or "TabOff", r, Z + 1)
            MenuArt.label(
                self.canvas,
                "TabText_" .. tabModel.key,
                tabModel.label,
                { r[1] + 8, r[2] + 8, r[3] - 16, r[4] - 18 },
                tabs.LabelSize,
                Colors.White,
                Z + 2,
                {
                    alignX = CENTER,
                }
            )
            MenuArt.hitBox(self.canvas, "Tab_" .. tabModel.key, r, tabModel.onActivate, Z + 4)
            if tabModel.ready > 0 then
                local badge = tabs.Badge
                local br = { r[1] + r[3] - badge.Right, r[2] + badge.Top, badge.Width, badge.Height }
                MenuArt.piece(self.canvas, "Ready", "Badge", br, Z + 3)
                MenuArt.label(
                    self.canvas,
                    "ReadyText",
                    tostring(tabModel.ready),
                    { br[1], br[2] + 2, br[3], br[4] - 6 },
                    badge.TextSize,
                    Colors.White,
                    Z + 4,
                    {
                        alignX = CENTER,
                        stroke = 2,
                    }
                )
            end
        end
    end

    local list = Config.List
    local r = list.Rect
    if #model.quests == 0 then
        MenuArt.label(
            self.canvas,
            "Empty",
            model.emptyText,
            Config.EmptyRect,
            32,
            Colors.Muted,
            Z + 1,
            { alignX = CENTER }
        )
    else
        local scroller = MenuArt.new("ScrollingFrame", "List", self.canvas, Z + 1)
        MenuArt.rect(scroller, r)
        scroller.ScrollingDirection = Enum.ScrollingDirection.Y
        scroller.ScrollBarThickness = 6
        scroller.ScrollBarImageColor3 = Colors.Muted
        for i, quest in model.quests do
            questRow(scroller, i, quest, list.Top + (i - 1) * list.RowStep)
        end
        local height = list.Top + (#model.quests - 1) * list.RowStep + Config.Row.Size.Y + list.BottomPad
        scroller.CanvasSize = UDim2.fromOffset(0, height)
    end

    local footer = Config.Footer
    if model.resetEndsAt then
        local resetText =
            MenuArt.label(self.canvas, "ResetText", "", footer.TextRect, footer.TextSize, Colors.White, Z + 1)
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
    local b = footer.ButtonRect
    if not model.claimAll.enabled then
        MenuArt.veil(self.canvas, b, Z + 1)
    end
    MenuArt.label(
        self.canvas,
        "ClaimAllText",
        model.claimAll.text,
        { b[1] + 10, b[2] + 8, b[3] - 20, b[4] - 18 },
        footer.ButtonSize,
        Colors.White,
        Z + 2,
        {
            alignX = CENTER,
        }
    )
    MenuArt.hitBox(self.canvas, "ClaimAll", b, model.claimAll.enabled and model.claimAll.onActivate or nil, Z + 3)
    return self
end

function QuestMenuComponent:Destroy()
    self.alive = false
    self.stopCanvas()
    self.canvas:Destroy()
end

return QuestMenuComponent
