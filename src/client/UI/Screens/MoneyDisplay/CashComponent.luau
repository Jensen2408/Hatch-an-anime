-- MoneyDisplay.CashComponent  (ModuleScript, client)
-- Builds the Cash UI once and updates only its text afterwards. Display only: it does not read or change the
-- economy. MoneyLogic feeds it the replicated Cash value and the income per second.
--
--   CashUI (Frame, UIScale)
--   ├── MainBackground (ImageLabel)
--   │   ├── CoinIcon (ImageLabel)
--   │   └── CashAmount (TextLabel, + black outline copies)
--   └── IncomePanel (ImageLabel)
--       └── IncomeText (TextLabel, + black outline copies)
--
--   local cash = CashComponent.new(screenGui)
--   cash:SetCash(4200000)   --> "$4.2M"
--   cash:SetIncome(25)      --> "+$25 / sec"
--   cash:SetVisible(true)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent:WaitForChild("CashConfig"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("CharacterInventory"):WaitForChild("InventoryFormat"))

local CashComponent = {}
CashComponent.__index = CashComponent

-- 1000 -> "$1K", 4200000 -> "$4.2M" (InventoryFormat.Short truncates, never rounds up)
function CashComponent.FormatCash(value)
    return "$" .. NumberFormat.Short(value)
end

local function newImage(name, image, layout, zIndex, parent)
    local label = Instance.new("ImageLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.Image = image
    label.ScaleType = Enum.ScaleType.Fit -- never distort the pixel art
    label.ResampleMode = Enum.ResamplerMode.Pixelated
    label.AnchorPoint = layout.AnchorPoint or Vector2.zero
    label.Position = layout.Position
    label.Size = layout.Size
    label.ZIndex = zIndex
    label.Parent = parent
    return label
end

local function newText(name, layout, color, zIndex, parent)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.FontFace = Config.Font
    label.TextScaled = true -- shrinks long values instead of clipping them
    label.TextColor3 = color
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.AnchorPoint = layout.AnchorPoint or Vector2.zero
    label.Position = layout.Position
    label.Size = layout.Size
    label.ZIndex = zIndex
    label.Parent = parent
    return label
end

-- Black copies of `label` at integer pixel offsets: the 8 directions at `thickness`, plus a drop shadow row
-- `shadow` pixels further down. Same size as the label, so TextScaled picks the same text size for every copy.
local function addPixelOutline(label, outline)
    local copies = {}
    local thickness, shadow = outline.Thickness, outline.Shadow
    local offsets = {}
    for dy = -1, 1 do
        for dx = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                table.insert(offsets, Vector2.new(dx * thickness, dy * thickness))
            end
        end
    end
    if shadow > 0 then
        for dx = -1, 1 do
            table.insert(offsets, Vector2.new(dx * thickness, thickness + shadow))
        end
    end
    for _, offset in offsets do
        local copy = Instance.new("TextLabel")
        copy.Name = "Outline"
        copy.BackgroundTransparency = 1
        copy.FontFace = label.FontFace
        copy.TextScaled = true
        copy.TextColor3 = Config.Colors.Outline
        copy.TextXAlignment = label.TextXAlignment
        copy.TextYAlignment = label.TextYAlignment
        copy.Position = UDim2.fromOffset(offset.X, offset.Y)
        copy.Size = UDim2.fromScale(1, 1)
        copy.ZIndex = label.ZIndex - 1 -- below the label (MoneyDisplay uses Global ZIndexBehavior)
        copy.Parent = label
        table.insert(copies, copy)
    end
    return copies
end

local function setText(label, copies, text)
    if label.Text == text then
        return
    end
    label.Text = text
    for _, copy in copies do
        copy.Text = text
    end
end

function CashComponent.new(parent)
    local self = setmetatable({}, CashComponent)
    local root = Instance.new("Frame")
    root.Name = "CashUI"
    root.BackgroundTransparency = 1
    root.Size = UDim2.fromOffset(Config.RootSize.X, Config.RootSize.Y)
    self.Scale = Instance.new("UIScale")
    self.Scale.Parent = root

    local z = Config.ZIndex
    local mainBackground =
        newImage("MainBackground", Config.Assets.MainBackground, Config.MainBackground, z.MainBackground, root)
    newImage("CoinIcon", Config.Assets.Coin, Config.Coin, z.Coin, mainBackground)
    self.CashAmount = newText("CashAmount", Config.CashAmount, Config.Colors.CashAmount, z.CashAmount, mainBackground)
    self.CashAmountOutline = addPixelOutline(self.CashAmount, Config.Outline.CashAmount)

    local incomePanel = newImage("IncomePanel", Config.Assets.IncomePanel, Config.IncomePanel, z.IncomePanel, root)
    self.IncomeText = newText("IncomeText", Config.IncomeText, Config.Colors.IncomeText, z.IncomeText, incomePanel)
    self.IncomeTextOutline = addPixelOutline(self.IncomeText, Config.Outline.IncomeText)

    self.Root = root
    self:SetCash(0)
    self:SetIncome(0)
    root.Parent = parent
    return self
end

function CashComponent:SetCash(value)
    setText(self.CashAmount, self.CashAmountOutline, CashComponent.FormatCash(value))
end

function CashComponent:SetIncome(perSecond)
    setText(self.IncomeText, self.IncomeTextOutline, "+" .. CashComponent.FormatCash(perSecond) .. Config.IncomeSuffix)
end

function CashComponent:SetVisible(visible)
    self.Root.Visible = visible
end

function CashComponent:Destroy()
    self.Root:Destroy()
end

return CashComponent
