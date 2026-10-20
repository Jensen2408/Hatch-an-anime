-- ReplicatedStorage.TopRightHUD.TopRightConfig  (ModuleScript, client)
-- Every number for the top-right HUD (TopRightComponent): Backpack counter + Feedback button.
-- Boxes are { X, Y, W, H } in pixels of the reference mockup (reference(5).png, 2172x724), measured from the
-- mockup and the uploaded PNGs' alpha / colour bounds. TopRightComponent turns them into scales of their parent,
-- so the whole HUD scales as one piece with a single UIScale.
local TopRightConfig = {}

-- Uploaded Roblox images: the supplied PNGs with only their transparent padding cropped, then scaled to fit
-- 1024 px (nearest neighbour) so Roblox does not resample them on upload
TopRightConfig.Assets = {
    CounterBackground = "rbxassetid://108238432905069", -- background.png (1024x272)
    Backpack = "rbxassetid://119769281748825", -- backpack.png (975x1024)
    FeedbackBackground = "rbxassetid://133554639018083", -- background-feedback.png (1024x926)
    FeedbackIcon = "rbxassetid://117457209887849", -- icon-feedback.png (906x844)
}

-- Press Start 2P ships with Roblox (built-in font family, no upload needed)
TopRightConfig.Font = Font.new("rbxasset://fonts/families/PressStart2P.json")

-- The HUD's outer bounds on the mockup (union of every piece below)
TopRightConfig.RefBounds = { 78.18, 89.33, 2054.94, 503.19 }
-- Root pixels per mockup pixel. RootSize = RefBounds size * Unit; the on-screen size comes from the UIScale.
TopRightConfig.Unit = 0.2
TopRightConfig.Scale = { Desktop = 0.58, Compact = 0.4 } -- ~238 x 58 px on desktop, ~164 x 40 px on phones
TopRightConfig.CompactBreakpoint = 600 -- shortest screen side below this = phone layout

TopRightConfig.Boxes = {
    -- the purple counter: colour frame 82..1576 x 129..572 on the mockup. The PNG is wider than the mockup's
    -- panel, so it is drawn in three pieces: both stepped ends at their own aspect, only the flat middle squeezed.
    CounterBackground = { 78.18, 125.18, 1501.64, 452.17 },
    -- uniform scale of the PNG: the orange body's centre sits on the mockup's (360, 310.5)
    BackpackIcon = { 141.86, 89.33, 436.39, 458.32 },
    -- centred on the mockup's "8 / 30" (752..1440 x 263..440); the label is wider than the text so it never clips.
    -- Press Start 2P's digits sit ~15 mockup px below the line centre, so the box is 15 px higher than the text.
    CapacityText = { 632, 186.5, 928, 300 },
    -- the blue frame: colour frame 1663..2119 x 129..579 on the mockup, three pieces like the counter
    FeedbackBackground = { 1649.38, 114.87, 483.75, 477.65 },
    -- uniform scale of the PNG: the white face's centre sits on the mockup's (1892.5, 355)
    FeedbackIcon = { 1754.07, 225.13, 277.17, 258.2 },
}

-- Three-piece images: Cap = width (uploaded image pixels) of each stepped end, kept at the image's own aspect
TopRightConfig.Slices = {
    CounterBackground = { ImageSize = Vector2.new(1024, 272), Cap = 96 },
    FeedbackBackground = { ImageSize = Vector2.new(1024, 926), Cap = 240 },
}

-- Text size in mockup pixels: "8 / 30" spans the mockup's text width (Press Start 2P is monospaced and keeps the
-- spaces). Longer values shrink so they stay inside CapacityText.
TopRightConfig.RefTextSize = 209
TopRightConfig.RefTextLength = 6 -- #"8 / 30"

TopRightConfig.Colors = {
    Text = Color3.fromRGB(255, 255, 255),
    Outline = Color3.fromRGB(0, 0, 0),
}
-- Pixel outline = black copies of the text at integer offsets (8 directions) plus a drop shadow row.
-- Root pixels (before UIScale).
TopRightConfig.Outline = { Thickness = 3, Shadow = 2 }

TopRightConfig.CapacitySeparator = " / "

return TopRightConfig
