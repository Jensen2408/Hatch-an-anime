-- ReplicatedStorage.QuestsHUD.QuestsComponent  (ModuleScript, client)
-- The collapsible quest tracker. Builds its instances once (rows come from a fixed pool of QuestsConfig.MaxRows)
-- and afterwards only changes text, fill widths, visibility and the collapse tween. Display only: the quest data
-- comes from the server through FigmaSkin's tracker loop (GameMenu GetState "quests").
-- Every image is a piece of one atlas (QuestsConfig.Pieces), drawn at its own pixel size: no stretching.
-- Its ScreenGui uses Sibling ZIndexBehavior: children draw above their parent, later siblings above earlier.
--
--   QuestsHUD (Frame, UIScale)
--   ├── HeaderImage
--   ├── CollapsibleContent (ClipsDescendants)
--   │   └── QuestRow1..N (card piece; the last shown row uses the piece with the bottom border):
--   │       DescriptionText, ProgressTrack > FillClip > ProgressFill, ProgressText
--   ├── FooterImage (bottom border, pinned to the bottom; covers the same pixels of the last card)
--   └── HeaderButton (TextButton, transparent, covers the header): TitleText, ChevronIcon
--
--   local hud = QuestsComponent.new(screenGui)
--   hud:SetQuests({ { id = "place2", title = "Place 2 characters", progress = 1, target = 2 }, ... })
--   hud:UpdateQuest("place2", 2, 2)
--   hud:ToggleExpanded() / hud:SetExpanded(false)
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent:WaitForChild("QuestsConfig"))

local QuestsComponent = {}
QuestsComponent.__index = QuestsComponent

local Pieces = Config.Pieces
local W = Config.Width
local HEADER_HEIGHT = Pieces.Header[4]
local PITCH = Pieces.Card[4]
local TRACK_WIDTH = Config.Rows.Track[3]

local function boxPlace(instance, box)
    instance.Position = UDim2.fromOffset(box[1], box[2])
    instance.Size = UDim2.fromOffset(box[3], box[4])
end

local function newFrame(name, parent)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Parent = parent
    return frame
end

local function setPiece(image, piece)
    image.ImageRectOffset = Vector2.new(piece[1], piece[2])
    image.ImageRectSize = Vector2.new(piece[3], piece[4])
    image.Size = UDim2.fromOffset(piece[3], piece[4])
end

-- one atlas piece at its own pixel size
local function newPiece(name, piece, parent)
    local image = Instance.new("ImageLabel")
    image.Name = name
    image.BackgroundTransparency = 1
    image.Image = Config.Atlas
    setPiece(image, piece)
    image.Parent = parent
    return image
end

-- white text with a dark outline; long text shrinks to fit its box, never grows past maxSize
local function newText(name, box, alignment, maxSize, strokeThickness, parent)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.FontFace = Config.Font
    label.TextColor3 = Config.Colors.Text
    label.TextXAlignment = alignment
    label.TextScaled = true
    boxPlace(label, box)
    local limit = Instance.new("UITextSizeConstraint")
    limit.MaxTextSize = maxSize
    limit.Parent = label
    local stroke = Instance.new("UIStroke")
    stroke.Color = Config.Colors.TextStroke
    stroke.Thickness = strokeThickness
    stroke.LineJoinMode = Enum.LineJoinMode.Round
    stroke.Parent = label
    label.Parent = parent
    return label
end

-- every row but the last is a card + gap piece; the last one also carries the bottom border
local function contentHeight(rowCount)
    if rowCount <= 0 then
        return 0
    end
    return (rowCount - 1) * PITCH + Pieces.LastCard[4]
end

-- width of the clipped fill: 0 hides it, 1 shows the whole bar with both round ends
local function fillWidth(ratio)
    return ratio >= 1 and TRACK_WIDTH or math.floor(TRACK_WIDTH * ratio + 0.5)
end

function QuestsComponent:_buildRow(index, parent)
    local rows = Config.Rows
    local row = newPiece("QuestRow" .. index, Pieces.Card, parent)
    row.Position = UDim2.fromOffset(0, (index - 1) * PITCH)
    row.Visible = false
    local description = newText(
        "DescriptionText",
        rows.Description,
        Enum.TextXAlignment.Left,
        rows.DescriptionSize,
        Config.Stroke.Description,
        row
    )
    description.TextTruncate = Enum.TextTruncate.AtEnd
    local track = newPiece("ProgressTrack", Pieces.Track, row)
    boxPlace(track, rows.Track)
    -- the full bar sits in a clip frame, so a partial bar ends straight like the mockup's
    local clip = newFrame("FillClip", track)
    clip.ClipsDescendants = true
    clip.Size = UDim2.fromOffset(0, rows.Track[4])
    newPiece("ProgressFill", Pieces.Fill, clip)
    local count =
        newText("ProgressText", rows.Count, Enum.TextXAlignment.Right, rows.CountSize, Config.Stroke.Count, row)
    return { Frame = row, Description = description, Fill = clip, Count = count, Ratio = nil, QuestId = nil }
end

function QuestsComponent.new(parent)
    local self = setmetatable({}, QuestsComponent)
    local headerConfig = Config.Header
    local root = newFrame("QuestsHUD", nil)
    self.Scale = Instance.new("UIScale")
    self.Scale.Parent = root
    newPiece("HeaderImage", Pieces.Header, root)

    -- rows live below the header; the clip frame's height is what collapses
    local content = newFrame("CollapsibleContent", root)
    content.ClipsDescendants = true
    content.Position = UDim2.fromOffset(0, HEADER_HEIGHT)
    content.Size = UDim2.fromOffset(W, 0)
    self.Rows = {}
    for index = 1, Config.MaxRows do
        self.Rows[index] = self:_buildRow(index, content)
    end

    local footer = newPiece("FooterImage", Pieces.Footer, root)
    footer.AnchorPoint = Vector2.new(0, 1)
    footer.Position = UDim2.fromScale(0, 1)

    -- the whole header is the toggle
    local header = Instance.new("TextButton")
    header.Name = "HeaderButton"
    header.BackgroundTransparency = 1
    header.Text = ""
    header.AutoButtonColor = false
    header.Size = UDim2.fromOffset(W, HEADER_HEIGHT)
    header.Parent = root
    local title = newText(
        "TitleText",
        headerConfig.Title,
        Enum.TextXAlignment.Left,
        headerConfig.TitleSize,
        Config.Stroke.Title,
        header
    )
    title.Text = "QUESTS"
    local chevron = newPiece("ChevronIcon", Pieces.Chevron, header)
    boxPlace(chevron, headerConfig.Chevron)

    self.Root, self.Header, self.Chevron, self.Content = root, header, chevron, content
    self.IsExpanded = true
    self.RowCount = 0
    self.Tweens = {}
    header.Activated:Connect(function()
        self:ToggleExpanded()
    end)
    self:_applyHeight(false)
    root.Parent = parent
    return self
end

-- Root and clip heights for the current state; animated = tween, else snap. A running tween is replaced.
function QuestsComponent:_applyHeight(animated)
    local rowsHeight = self.IsExpanded and contentHeight(self.RowCount) or 0
    local rootHeight = HEADER_HEIGHT + (rowsHeight > 0 and rowsHeight or Pieces.Footer[4])
    local goals = {
        [self.Content] = { Size = UDim2.fromOffset(W, rowsHeight) },
        [self.Root] = { Size = UDim2.fromOffset(W, rootHeight) },
        [self.Chevron] = { Rotation = self.IsExpanded and 0 or 180 }, -- down = expanded, up = collapsed
    }
    for instance, goal in goals do
        if self.Tweens[instance] then
            self.Tweens[instance]:Cancel()
            self.Tweens[instance] = nil
        end
        if animated then
            local tween = TweenService:Create(
                instance,
                TweenInfo.new(Config.CollapseTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                goal
            )
            self.Tweens[instance] = tween
            tween:Play()
        else
            for property, value in goal do
                instance[property] = value
            end
        end
    end
end

function QuestsComponent:SetExpanded(expanded)
    if self.IsExpanded == expanded then
        return
    end
    self.IsExpanded = expanded
    self:_applyHeight(true)
end

function QuestsComponent:ToggleExpanded()
    self:SetExpanded(not self.IsExpanded)
end

function QuestsComponent:_setRow(row, current, target)
    local ratio = math.clamp(current / math.max(target, 1), 0, 1)
    row.Count.Text = string.format("%s/%s", QuestsComponent.FormatCount(current), QuestsComponent.FormatCount(target))
    if row.Ratio == ratio then
        return
    end
    local goal = { Size = UDim2.fromOffset(fillWidth(ratio), Config.Rows.Track[4]) }
    if row.FillTween then
        row.FillTween:Cancel()
    end
    if row.Ratio == nil then -- first value for this row: no animation
        row.Fill.Size = goal.Size
    else
        row.FillTween = TweenService:Create(row.Fill, TweenInfo.new(Config.FillTime, Enum.EasingStyle.Quad), goal)
        row.FillTween:Play()
    end
    row.Ratio = ratio
end

-- 1500 -> "1.5K" (truncated), small numbers as they are
function QuestsComponent.FormatCount(amount)
    amount = math.floor(amount)
    for _, unit in { { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
        if amount >= unit[1] then
            return string.format("%g", math.floor(amount / unit[1] * 10) / 10) .. unit[2]
        end
    end
    return tostring(amount)
end

-- Shows these quests (in order, at most MaxRows): { { id, title, progress, target }, ... }. Rows are reused;
-- a row keeps its fill when the same quest stays in the same slot, so progress animates instead of jumping.
function QuestsComponent:SetQuests(quests)
    local count = math.min(#quests, Config.MaxRows)
    for index, row in self.Rows do
        local quest = quests[index]
        if index <= count and quest then
            if row.QuestId ~= quest.id then
                row.QuestId = quest.id
                row.Ratio = nil
            end
            setPiece(row.Frame, index == count and Pieces.LastCard or Pieces.Card)
            row.Description.Text = quest.title or ""
            self:_setRow(row, quest.progress or 0, quest.target or 1)
            row.Frame.Visible = true
        else
            row.QuestId = nil
            row.Ratio = nil
            row.Frame.Visible = false
        end
    end
    if count ~= self.RowCount then
        self.RowCount = count
        self:_applyHeight(true)
    end
end

-- Updates one shown quest's progress (no-op if it is not shown).
function QuestsComponent:UpdateQuest(questId, current, target)
    for _, row in self.Rows do
        if row.QuestId == questId then
            self:_setRow(row, current, target)
            return
        end
    end
end

function QuestsComponent:SetVisible(visible)
    self.Root.Visible = visible
end

function QuestsComponent:Destroy()
    self.Root:Destroy()
end

return QuestsComponent
