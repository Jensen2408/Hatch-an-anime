-- ReplicatedStorage.TimeHUD.TimeConfig  (ModuleScript, client)
-- Every number for the Day / Night event HUD (TimeComponent). Layout boxes are { X, Y, W, H } in pixels of the
-- mode's reference image (DAY-REFERENCE 1619 px wide, NIGHT-REFERENCE 2100 px wide, both cropped to their
-- content). TimeComponent turns them into scales, so both modes fill the same root and scale as one piece.
local TimeConfig = {}

-- Root container in pixels before UIScale (the day reference's 1619:344 aspect ratio)
TimeConfig.RootSize = Vector2.new(480, 102)
TimeConfig.Scale = { Desktop = 0.75, CompactMax = 0.55, CompactMin = 0.3 }
TimeConfig.CompactBreakpoint = 600 -- shortest screen side below this = phone layout
TimeConfig.TopMargin = 10 -- pixels from the top of the screen (desktop) / safe area (phones)

-- Press Start 2P ships with Roblox (built-in font family, no upload needed)
TimeConfig.Font = Font.new("rbxasset://fonts/families/PressStart2P.json")

-- Cards are drawn 9-slice: corners and borders keep their pixels, only the flat middle stretches.
-- SliceCenter is in the uploaded image's pixels; ImageSize is that image's size.
local function card(image, width, height)
    return {
        Image = image,
        ImageSize = Vector2.new(width, height),
        SliceCenter = Rect.new(90, 40, width - 90, height - 40),
    }
end

TimeConfig.Modes = {
    Day = {
        RefWidth = 1619,
        TitlePrefix = "DAY EVENT IN ",
        MainCard = card("rbxassetid://86659805319870", 1024, 154), -- DAY-CARD-TOP (bright blue)
        MultiplierCard = card("rbxassetid://98874051184271", 1024, 144), -- DAY-CARD (navy)
        LeftIcon = "rbxassetid://88907203136438", -- DAY-ICON (sun), used on both sides
        RightIcon = "rbxassetid://88907203136438",
        Separator = "rbxassetid://111169208709914", -- blue-edged diamond
        IconNames = { "LeftSunIcon", "RightSunIcon" },
        Boxes = {
            MainPanel = { 6, 1, 1607, 240 },
            MultiplierPanel = { 195, 192, 1229, 152 },
            LeftIcon = { 79, 56, 150, 144 },
            RightIcon = { 1390, 56, 150, 144 },
            CountdownText = { 262, 47, 1092, 130 }, -- tall enough that the title is width-limited
            MultiplierContent = { 280, 228, 1055, 62 }, -- the multiplier text span in the reference
        },
        MaxTextSize = 80, -- multiplier text, reference pixels; shrunk until the row fits MultiplierContent
        Gap = 25, -- between a multiplier and a separator, reference pixels
        SeparatorSize = 36,
        TitleDepth = Color3.fromRGB(40, 120, 240),
    },
    Night = {
        RefWidth = 2100,
        TitlePrefix = "NIGHT EVENT IN ",
        -- this look is shown during the DAY (counting down to the night): the bonus panel is hidden until night
        ShowMultipliers = false,
        MainCard = card("rbxassetid://128604161212459", 1024, 138), -- NIGHT-CARD-TOP
        MultiplierCard = card("rbxassetid://132747624547618", 1024, 133), -- NIGHT-CARD
        LeftIcon = "rbxassetid://112411971879268", -- NIGHT-ICON-LEFT (moon, star on its right)
        RightIcon = "rbxassetid://131186548306404", -- NIGHT-ICON-RIGHT (moon, star on its left)
        Separator = "rbxassetid://108700032514290", -- NIGHT-ICON-TEXT (white diamond)
        IconNames = { "LeftMoonIcon", "RightMoonIcon" },
        Boxes = {
            MainPanel = { 11, 1, 2077, 282 },
            MultiplierPanel = { 252, 237, 1596, 194 },
            LeftIcon = { 135, 75, 150, 150 },
            RightIcon = { 1814, 75, 150, 150 },
            CountdownText = { 353, 78, 1392, 130 },
            MultiplierContent = { 362, 286, 1371, 71 },
        },
        MaxTextSize = 90,
        Gap = 30,
        SeparatorSize = 44,
        TitleDepth = Color3.fromRGB(108, 48, 192),
    },
}

-- Multiplier labels, left to right. Colors sampled from the references.
TimeConfig.Multipliers = {
    { Key = "Cash", Name = "CashMultiplier", Label = "CASH", Color = Color3.fromRGB(252, 222, 0) },
    { Key = "Hatch", Name = "HatchMultiplier", Label = "HATCH", Color = Color3.fromRGB(66, 240, 248) },
    { Key = "Luck", Name = "LuckMultiplier", Label = "LUCK", Color = Color3.fromRGB(236, 72, 246) },
}
TimeConfig.MultiplierDepth = {
    Cash = Color3.fromRGB(180, 60, 0),
    Hatch = Color3.fromRGB(0, 132, 228),
    Luck = Color3.fromRGB(84, 0, 204),
}

TimeConfig.Colors = {
    Title = Color3.fromRGB(255, 255, 255),
    Outline = Color3.fromRGB(0, 0, 0),
}

-- Pixel outline = black copies of a label at integer offsets (8 directions), then a colored "depth" copy
-- `Depth` px lower (the darker bottom band in the references), then the label. Root pixels (before UIScale).
TimeConfig.Outline = {
    Title = { Thickness = 2, Depth = 2 },
    Multiplier = { Thickness = 2, Depth = 1 },
}

-- The time HUD's ScreenGui (NightBar) uses Global ZIndexBehavior; these order every layer
TimeConfig.ZIndex = {
    MainCard = 1,
    Icon = 2,
    Title = 5, -- outline copies at Title - 2, depth copy at Title - 1
    MultiplierCard = 6,
    Multiplier = 9, -- outline copies at Multiplier - 2, depth copy at Multiplier - 1
    Separator = 9,
}

return TimeConfig
