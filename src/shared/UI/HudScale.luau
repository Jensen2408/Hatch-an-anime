-- ReplicatedStorage.HudScale  (ModuleScript, client)
-- One scale for the whole HUD on every screen: phones and tablets get the desktop layout, only smaller. Each piece
-- keeps its desktop position and size and multiplies them by HudScale.For(screenSize), where screenSize is the
-- AbsoluteSize of a ScreenGui inside the safe area, so every piece gets the same value.
local HudScale = {}

HudScale.Reference = Vector2.new(1280, 600) -- the smallest screen that shows the HUD at full size
HudScale.Min = 0.45 -- keeps text readable on the narrowest screens (portrait phones)

function HudScale.For(screenSize)
    local reference = HudScale.Reference
    return math.clamp(math.min(screenSize.X / reference.X, screenSize.Y / reference.Y), HudScale.Min, 1)
end

return HudScale
