-- GameMenus.LeftMenuComponent  (ModuleScript, client)
-- Builds the left menu out of the uploaded button art and handles its hover / press feedback. It does not
-- know what the buttons do: MenuLogic connects them (Buttons[key].Activated) to the existing actions.
--
--   LeftMenu (Frame, AnchorPoint and Position set by MenuLogic)
--   ├── UIScale
--   └── MenuContainer
--       ├── HomeButton (ImageButton)
--       └── MenuGrid (UIGridLayout, 2 columns)
--           ├── PlotButton, IndexButton, QuestsButton, ShopButton, DailyButton, SettingsButton
--
--   local menu = LeftMenuComponent.new(gameMenusGui)
--   menu.Buttons.Plot.Activated:Connect(...)
--   menu:SetButtonPx(98)   -- on-screen width of one square button
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent:WaitForChild("LeftMenuConfig"))

local LeftMenuComponent = {}
LeftMenuComponent.__index = LeftMenuComponent

local FEEDBACK_TWEEN = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function newImageButton(name, image, parent)
    local button = Instance.new("ImageButton")
    button.Name = name
    button.BackgroundTransparency = 1
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Image = image
    button.ScaleType = Enum.ScaleType.Fit -- keeps the art's own aspect ratio
    -- the art is shown far below its source size, so smooth (mipmapped) sampling stays sharper than nearest
    button.ResampleMode = Enum.ResamplerMode.Default
    button.Parent = parent
    -- hover / press feedback: a small scale change, nothing else
    local scale = Instance.new("UIScale")
    scale.Parent = button
    local hovered = false
    local function tweenTo(value)
        TweenService:Create(scale, FEEDBACK_TWEEN, { Scale = value }):Play()
    end
    button.MouseEnter:Connect(function()
        hovered = true
        tweenTo(Config.HoverScale)
    end)
    button.MouseLeave:Connect(function()
        hovered = false
        tweenTo(1)
    end)
    button.MouseButton1Down:Connect(function()
        tweenTo(Config.PressScale)
    end)
    button.MouseButton1Up:Connect(function()
        tweenTo(hovered and Config.HoverScale or 1)
    end)
    return button
end

function LeftMenuComponent.new(parent)
    local self = setmetatable({}, LeftMenuComponent)
    local root = Instance.new("Frame")
    root.Name = "LeftMenu"
    root.BackgroundTransparency = 1
    root.Size = UDim2.fromOffset(Config.Size.X, Config.Size.Y)
    self.Scale = Instance.new("UIScale")
    self.Scale.Parent = root

    local container = Instance.new("Frame")
    container.Name = "MenuContainer"
    container.BackgroundTransparency = 1
    container.Size = UDim2.fromScale(1, 1)
    container.Parent = root

    self.Buttons = {}
    local home = newImageButton("HomeButton", Config.Assets.Home, container)
    home.Position = UDim2.fromOffset(Config.Home.Position.X, Config.Home.Position.Y)
    home.Size = UDim2.fromOffset(Config.Home.Size.X, Config.Home.Size.Y)
    self.Buttons.Home = home

    local grid = Instance.new("Frame")
    grid.Name = "MenuGrid"
    grid.BackgroundTransparency = 1
    grid.Position = UDim2.fromOffset(0, Config.GridTop)
    grid.Size = UDim2.new(1, 0, 1, -Config.GridTop)
    grid.Parent = container
    local layout = Instance.new("UIGridLayout")
    layout.CellSize = UDim2.fromOffset(Config.CellSize.X, Config.CellSize.Y)
    layout.CellPadding = UDim2.fromOffset(Config.CellPadding.X, Config.CellPadding.Y)
    layout.FillDirectionMaxCells = 2
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = grid
    for index, entry in Config.Grid do
        local button = newImageButton(entry.Name, Config.Assets[entry.Key], grid)
        button.LayoutOrder = index
        self.Buttons[entry.Key] = button
    end

    self.Root = root
    root.Parent = parent
    return self
end

-- Shrinks the whole menu so one square button is `pixels` wide on screen.
function LeftMenuComponent:SetButtonPx(pixels)
    self.Scale.Scale = pixels / Config.CellSize.X
end

function LeftMenuComponent:SetVisible(visible)
    self.Root.Visible = visible
end

function LeftMenuComponent:Destroy()
    self.Root:Destroy()
end

return LeftMenuComponent
