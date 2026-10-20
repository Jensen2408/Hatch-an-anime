-- ReplicatedStorage.TopRightHUD.TopRightComponent  (ModuleScript, client)
-- Builds the top-right HUD once and updates only its text afterwards. Display only: FeedbackClient feeds the
-- counter from the CharacterInventory snapshot and connects FeedbackButton to the feedback window.
--
--   TopRightHUD (Frame, UIScale)
--   ├── BackpackCounter (Frame)
--   │   ├── CounterBackground (Frame: LeftCap / Middle / RightCap ImageLabels)
--   │   ├── BackpackIcon (ImageLabel)
--   │   └── CapacityText (Frame: Outline TextLabels, then Fill TextLabel on top)
--   └── FeedbackButton (ImageButton, transparent click area)
--       ├── FeedbackBackground (Frame: LeftCap / Middle / RightCap ImageLabels)
--       └── FeedbackIcon (ImageLabel)
--
-- The ScreenGui may use Sibling ZIndexBehavior: every layer is ordered by ZIndex among its siblings.
--
--   local hud = TopRightComponent.new(screenGui)
--   hud:SetCapacity(8, 30)   --> "8 / 30"
--   hud:SetVisible(true)
--   hud.FeedbackButton.Activated:Connect(openFeedback)
local Config = require(script.Parent:WaitForChild("TopRightConfig"))

local TopRightComponent = {}
TopRightComponent.__index = TopRightComponent

-- `box` ({ X, Y, W, H } mockup pixels) as Position / Size scales of `parentBox`
local function place(guiObject, box, parentBox)
    guiObject.Position = UDim2.fromScale((box[1] - parentBox[1]) / parentBox[3], (box[2] - parentBox[2]) / parentBox[4])
    guiObject.Size = UDim2.fromScale(box[3] / parentBox[3], box[4] / parentBox[4])
end

local function newFrame(name, zIndex, parent)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.BackgroundTransparency = 1
    frame.ZIndex = zIndex
    frame.Parent = parent
    return frame
end

local function newImage(name, image, zIndex, parent)
    local label = Instance.new("ImageLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.Image = image
    label.ScaleType = Enum.ScaleType.Stretch -- the box already has the image's aspect (or is a slice piece)
    label.ResampleMode = Enum.ResamplerMode.Pixelated
    label.ZIndex = zIndex
    label.Parent = parent
    return label
end

-- A Frame filling `box` with the image in three pieces: both ends (Cap image pixels wide) keep the image's
-- aspect, only the flat middle stretches or squeezes to make up the box width.
local function newThreeSlice(name, image, slice, box, parentBox, zIndex, parent)
    local frame = newFrame(name, zIndex, parent)
    place(frame, box, parentBox)
    local imageSize, cap = slice.ImageSize, slice.Cap
    local capWidth = cap * (box[4] / imageSize.Y) / box[3] -- cap width as a fraction of the box
    local pieces = {
        { "LeftCap", Vector2.zero, Vector2.new(cap, imageSize.Y), 0, capWidth },
        { "Middle", Vector2.new(cap, 0), Vector2.new(imageSize.X - 2 * cap, imageSize.Y), capWidth, 1 - 2 * capWidth },
        { "RightCap", Vector2.new(imageSize.X - cap, 0), Vector2.new(cap, imageSize.Y), 1 - capWidth, capWidth },
    }
    for _, piece in pieces do
        local label = newImage(piece[1], image, 1, frame)
        label.ImageRectOffset = piece[2]
        label.ImageRectSize = piece[3]
        label.Position = UDim2.fromScale(piece[4], 0)
        label.Size = UDim2.fromScale(piece[5], 1)
    end
    return frame
end

local function newText(name, zIndex, color, offset, parent)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.FontFace = Config.Font
    label.TextScaled = false
    label.TextColor3 = color
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Position = UDim2.fromOffset(offset.X, offset.Y)
    label.Size = UDim2.fromScale(1, 1)
    label.ZIndex = zIndex
    label.Parent = parent
    return label
end

function TopRightComponent.new(parent)
    local self = setmetatable({}, TopRightComponent)
    local boxes, bounds = Config.Boxes, Config.RefBounds

    local root = newFrame("TopRightHUD", 1, nil)
    root.Size = UDim2.fromOffset(bounds[3] * Config.Unit, bounds[4] * Config.Unit)
    self.Scale = Instance.new("UIScale")
    self.Scale.Parent = root

    -- Backpack counter: background, then the backpack over its left end, then the text
    local counterBox = {
        bounds[1],
        bounds[2],
        boxes.CounterBackground[1] + boxes.CounterBackground[3] - bounds[1],
        bounds[4],
    }
    local counter = newFrame("BackpackCounter", 1, root)
    place(counter, counterBox, bounds)
    newThreeSlice(
        "CounterBackground",
        Config.Assets.CounterBackground,
        Config.Slices.CounterBackground,
        boxes.CounterBackground,
        counterBox,
        1,
        counter
    )
    local backpack = newImage("BackpackIcon", Config.Assets.Backpack, 2, counter)
    place(backpack, boxes.BackpackIcon, counterBox)

    local capacityText = newFrame("CapacityText", 3, counter)
    place(capacityText, boxes.CapacityText, counterBox)
    local outline = Config.Outline
    local offsets = {}
    for dy = -1, 1 do
        for dx = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                table.insert(offsets, Vector2.new(dx, dy) * outline.Thickness)
            end
        end
    end
    for dx = -1, 1 do
        table.insert(offsets, Vector2.new(dx * outline.Thickness, outline.Thickness + outline.Shadow))
    end
    self.TextLabels = {}
    for _, offset in offsets do
        table.insert(self.TextLabels, newText("Outline", 1, Config.Colors.Outline, offset, capacityText))
    end
    table.insert(self.TextLabels, newText("Fill", 2, Config.Colors.Text, Vector2.zero, capacityText))

    -- Feedback button: the ImageButton is only the click area; the art is drawn by its children
    local feedbackButton = Instance.new("ImageButton")
    feedbackButton.Name = "FeedbackButton"
    feedbackButton.BackgroundTransparency = 1
    feedbackButton.ImageTransparency = 1
    feedbackButton.AutoButtonColor = false
    feedbackButton.ZIndex = 2
    place(feedbackButton, boxes.FeedbackBackground, bounds)
    feedbackButton.Parent = root
    newThreeSlice(
        "FeedbackBackground",
        Config.Assets.FeedbackBackground,
        Config.Slices.FeedbackBackground,
        boxes.FeedbackBackground,
        boxes.FeedbackBackground,
        1,
        feedbackButton
    )
    local icon = newImage("FeedbackIcon", Config.Assets.FeedbackIcon, 2, feedbackButton)
    place(icon, boxes.FeedbackIcon, boxes.FeedbackBackground)

    self.Root = root
    self.FeedbackButton = feedbackButton
    self:SetCapacity(0, 0)
    root.Parent = parent
    return self
end

-- "used / max". Press Start 2P is monospaced, so text longer than "8 / 30" shrinks in proportion to stay inside
-- CapacityText.
function TopRightComponent:SetCapacity(used, max)
    local text = tostring(used) .. Config.CapacitySeparator .. tostring(max)
    local textSize = Config.RefTextSize * Config.Unit * math.min(1, Config.RefTextLength / #text)
    for _, label in self.TextLabels do
        label.Text = text
        label.TextSize = textSize
    end
end

function TopRightComponent:SetVisible(visible)
    self.Root.Visible = visible
end

function TopRightComponent:Destroy()
    self.Root:Destroy()
end

return TopRightComponent
