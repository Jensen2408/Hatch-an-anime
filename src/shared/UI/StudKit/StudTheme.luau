-- ReplicatedStorage.StudKit.StudTheme  (ModuleScript, client)
-- Shared tokens of the Figma UI kit "Hatch an Anime • Screens & Components" (variables --haa-color-*,
-- components Panel / Header / Close / Button / Tab / Badge / Progress / Toggle / Input / Toast). Used by
-- StudUI, StudToast and the screen configs. All sizes are Figma pixels on the 1160x730 panel canvas.
-- Toggle / Input / Toast internals could not be read from Figma (MCP quota), so only their outer sizes
-- (Toggle 86x44, Input 58 tall, Toast 600x82) come from the file; the inside follows the kit's other pieces.
local StudTheme = {}

-- Panel shell: 1160x721 plate + 9 px hard shadow below it
StudTheme.CanvasSize = Vector2.new(1160, 730)

StudTheme.Assets = {
    -- Figma "Stud texture • shared bitmap" (30x30 tile, also kept at assets/ui/plot/stud_texture.png).
    -- TODO: upload assets/ui/plot/stud_texture.png and put its id here; until then this is the menus'
    -- existing stud tile.
    StudTexture = "rbxassetid://132561191216691",
    StudTile = 30,
    StudTransparency = 0.35, -- Figma opacity 65 %
}

-- Figma: Lilita One (titles, buttons, values) and Nunito ExtraBold (labels). Lilita One is not a Roblox
-- built-in font, so titles use Fredoka One like the rest of GameMenus.
StudTheme.Fonts = {
    Display = Font.new("rbxasset://fonts/families/FredokaOne.json"),
    Body = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold),
}

-- Figma variables (--haa-color-*)
StudTheme.Colors = {
    Ink = Color3.fromRGB(12, 9, 27),
    Panel = Color3.fromRGB(36, 28, 73),
    Panel2 = Color3.fromRGB(52, 35, 94),
    Muted = Color3.fromRGB(196, 190, 216),
    White = Color3.fromRGB(255, 255, 255),
    Red = Color3.fromRGB(239, 61, 72),
    Green = Color3.fromRGB(56, 219, 69),
    Orange = Color3.fromRGB(247, 148, 36),
    Gold = Color3.fromRGB(255, 201, 74),
    Blue = Color3.fromRGB(20, 142, 236),
    Purple = Color3.fromRGB(102, 50, 185),
    Disabled = Color3.fromRGB(98, 98, 113),
}

-- Outline under Display text (the Figma render draws Lilita One labels with a dark edge)
StudTheme.TextStroke = { Title = 3, Display = 2 }
StudTheme.Border = 2

-- Rect = { x, y, w, h } in canvas pixels
StudTheme.Panel = { Rect = { 0, 0, 1160, 721 }, ShadowOffset = 9, Radius = 16, PlateRadius = 14 }

StudTheme.Header = {
    Rect = { 0, 0, 1160, 88 },
    Radius = 10,
    TitleSize = 44,
    TitleRect = { 90, 14, 980, 60 },
    Close = { Rect = { 1090, 16, 56, 56 }, GlyphSize = 40 },
}

-- Button (Figma "Button / green" etc., 200x56): ink base 5 px lower than the face, white highlight line,
-- face drops 5 px while pressed
StudTheme.Button = {
    Radius = 8,
    FaceRadius = 7,
    BaseDrop = 5,
    PressDrop = 5,
    HighlightInset = 6,
    HighlightHeight = 3,
    LabelSize = 24,
}

StudTheme.Tab = { Radius = 8, LabelSize = 24 }

-- Figma "Badge" (120x30, purple, white border)
StudTheme.Badge = { Radius = 8, LabelSize = 17 }

StudTheme.Progress = { Inset = 3 }
StudTheme.Slider = { KnobGrow = 12, HitPad = 12 }
StudTheme.Toggle = { Size = Vector2.new(86, 44), KnobInset = 5 }
StudTheme.Input = { Radius = 10, TextSize = 24, Padding = 16 }
StudTheme.ScrollBar = 8
StudTheme.ScrollPadding = 10 -- room around scrolled cards (borders, selected outlines, pressed buttons)

-- Figma "Toast" as stacked in "10 Notifications" (600x82, 26 px apart); screen-space, scaled to the screen
-- height (ScreenHeight px = scale 1, clamped to MinScale..MaxScale)
StudTheme.Toast = {
    Size = Vector2.new(600, 82),
    Radius = 12,
    IconRect = { 14, 14, 54, 54 },
    IconRadius = 10,
    GlyphSize = 34,
    TextRect = { 84, 8, 500, 66 },
    TextSize = 24,
    Gap = 26,
    Max = 4,
    Duration = 2.6,
    BottomOffset = 110,
    ScreenHeight = 1000,
    MinScale = 0.45,
    MaxScale = 0.85,
    ZIndex = 20,
}

-- Base ZIndex (above the panel's Live layer, below the Close hit-box at 30)
StudTheme.ZIndex = 8

return StudTheme
