-- MoneyDisplay.CashConfig  (ModuleScript, client)
-- Every number for the Cash UI (CashComponent) lives here. Layout values were measured from the cash mockup
-- (1920x819 canvas) and are fractions, so the whole UI scales as one piece with UIScale (see MoneyLogic).
-- Each image keeps its own aspect ratio: sizes below were derived from the uploaded PNGs, not stretched to fit.
local CashConfig = {}

-- Uploaded Roblox images (cropped to their content, transparent background)
CashConfig.Assets = {
    MainBackground = "rbxassetid://88212690753588", -- background-1: purple studded plate (1024x318)
    IncomePanel = "rbxassetid://96738946257660", -- background-2: dark income pill (1024x226)
    Coin = "rbxassetid://74648427411854", -- coin, black pixel outline included (997x1010)
}

-- Press Start 2P ships with Roblox (built-in font family, no upload needed)
CashConfig.Font = Font.new("rbxasset://fonts/families/PressStart2P.json")

-- Root container, in pixels before UIScale; 330x141 has the mockup's 1920:819 aspect ratio
CashConfig.RootSize = Vector2.new(330, 141)
CashConfig.Scale = { Desktop = 0.68, Compact = 0.46 } -- UIScale; "compact" = shortest screen side < 600 px
CashConfig.CompactBreakpoint = 600

-- Fractions of the root (CashUI)
CashConfig.MainBackground = {
    Position = UDim2.fromScale(0.0453, 0.0647),
    Size = UDim2.fromScale(0.9104, 0.663), -- 1748x543 on the mockup = the PNG's 3.22 aspect
}
CashConfig.IncomePanel = {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.fromScale(0.5, 0.6662), -- overlaps the plate's bottom edge like the mockup
    Size = UDim2.fromScale(0.6436, 0.333), -- 1236x273 on the mockup = the PNG's 4.53 aspect
}
-- Fractions of MainBackground
CashConfig.Coin = {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.1707, 0.446),
    Size = UDim2.fromScale(0.2453, 0.7998), -- 429x434 on the mockup = the PNG's aspect
}
CashConfig.CashAmount = {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.628, 0.464),
    Size = UDim2.fromScale(0.56, 0.6),
}
-- Fractions of IncomePanel
CashConfig.IncomeText = {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.49),
    Size = UDim2.fromScale(0.64, 0.7), -- width-limited: the text spans 41 % of the mockup width, like the mockup
}

CashConfig.Colors = {
    CashAmount = Color3.fromRGB(255, 255, 255),
    IncomeText = Color3.fromRGB(92, 246, 56), -- sampled from the mockup
    Outline = Color3.fromRGB(0, 0, 0),
}

-- Pixel outline = black copies of the label at integer pixel offsets (8 directions) plus a short drop
-- shadow below. Pixels are root pixels (before UIScale).
CashConfig.Outline = {
    CashAmount = { Thickness = 4, Shadow = 2 },
    IncomeText = { Thickness = 2, Shadow = 1 },
}

-- MoneyDisplay uses Global ZIndexBehavior, so these order every piece of the Cash UI
CashConfig.ZIndex = {
    MainBackground = 1,
    Coin = 2,
    CashAmount = 4, -- its outline copies sit at CashAmount - 1
    IncomePanel = 5,
    IncomeText = 7, -- its outline copies sit at IncomeText - 1
}

CashConfig.IncomeSuffix = " / sec"

return CashConfig
