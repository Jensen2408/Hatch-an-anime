--[[ ReplicatedStorage.Portal.PortalConfig  (ModuleScript, shared)
Every size, colour and timing for the Summon Gate. Server and clients read the same table.
]]
local Config = {}
local rgb = Color3.fromRGB

Config.Tag = "AnimePortal" -- built portals get this tag (client animates them)
Config.SpotTag = "PortalSpot" -- tag a Part with this; a portal is built standing on it, facing its Front

Config.Palette = {
    Lacquer = rgb(232, 69, 44),
    LacquerDark = rgb(157, 41, 37),
    Gold = rgb(255, 211, 107),
    Ink = rgb(29, 20, 32),
    Stone = rgb(176, 162, 146),
    StoneDark = rgb(122, 110, 100),
    Rope = rgb(214, 182, 120),
    Paper = rgb(255, 248, 234),
    LanternGlow = rgb(255, 196, 120),
}
Config.IdleColor = rgb(186, 110, 255) -- vortex colour when nobody is coming through
Config.RarityColor = {
    Common = rgb(214, 219, 228),
    Uncommon = rgb(120, 214, 96),
    Rare = rgb(70, 150, 255),
    Epic = rgb(186, 110, 255),
    Legendary = rgb(255, 196, 64),
}

Config.Opening = Vector2.new(8.4, 9.8) -- portal surface width x height (studs)
Config.GroundY = 0.6 -- top of the stone slab (characters walk on this)

-- emerge timeline (seconds)
Config.Surge = 1.0 -- vortex spins up and shifts to the rarity colour before anyone appears
Config.WalkSpeed = 4.2 -- studs/sec (matches CharacterAnimator "Walk" stride)
Config.StartBehind = 2.6 -- character starts this far behind the surface (fully hidden)
Config.WalkOut = 5.5 -- stops this far in front of the surface
Config.Wave = 1.6 -- waves at the player after stepping out
Config.FadeBand = 0.9 -- studs over which a body part fades in as it crosses the surface
Config.GlowFade = 1.0 -- energy outline fades this long after the body is fully out
Config.EndAnimation = "Idle"

-- Swirl textures (upload roblox/Portal/textures/*.png as IMAGES, paste the image IDs). Empty = ring-only fallback.
Config.Textures = { Swirl = "rbxassetid://122451384681960", Core = "rbxassetid://85831756159535" }
Config.SwirlSpeed = 63 -- deg/sec at idle (x3.4 during surge)

Config.EffectsDistance = 160 -- beyond this, clients pause the vortex/particles
Config.PixelsPerStud = 40

-- Sound slots. Leave "" = silent. Only paste IDs you've checked in the Creator Store.
Config.Sounds = { Hum = "", Surge = "", Whoosh = "", Arrive = "" }
Config.Volume = 0.6
Config.SoundGroupName = "SFX"
Config.MuteAttribute = "SFXMuted"
Config.ReducedMotionAttribute = "ReducedMotion"

function Config.Color(rarity)
    return Config.RarityColor[rarity or ""] or Config.IdleColor
end
function Config.WalkTime()
    return (Config.StartBehind + Config.WalkOut) / Config.WalkSpeed
end
function Config.Total()
    return Config.Surge + Config.WalkTime() + Config.Wave
end

return Config
