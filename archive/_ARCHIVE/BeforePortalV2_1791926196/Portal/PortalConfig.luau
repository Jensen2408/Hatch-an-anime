--[[ ReplicatedStorage.Portal.PortalConfig  (ModuleScript, shared)
Every size, colour and timing for the Summon Gate. Server and clients read the same table.
]]
local C = {}
local rgb = Color3.fromRGB

C.Tag = "AnimePortal"        -- built portals get this tag (client animates them)
C.SpotTag = "PortalSpot"     -- tag a Part with this; a portal is built standing on it, facing its Front

C.Palette = {
	Lacquer = rgb(232, 69, 44), LacquerDark = rgb(157, 41, 37), Gold = rgb(255, 211, 107),
	Ink = rgb(29, 20, 32), Stone = rgb(176, 162, 146), StoneDark = rgb(122, 110, 100),
	Rope = rgb(214, 182, 120), Paper = rgb(255, 248, 234), LanternGlow = rgb(255, 196, 120),
}
C.IdleColor = rgb(186, 110, 255) -- vortex colour when nobody is coming through
C.RarityColor = {
	Common = rgb(214, 219, 228), Uncommon = rgb(120, 214, 96), Rare = rgb(70, 150, 255),
	Epic = rgb(186, 110, 255), Legendary = rgb(255, 196, 64),
}

C.Opening = Vector2.new(8.4, 9.8) -- portal surface width x height (studs)
C.GroundY = 0.6                   -- top of the stone slab (characters walk on this)

-- emerge timeline (seconds)
C.Surge = 1.0        -- vortex spins up and shifts to the rarity colour before anyone appears
C.WalkSpeed = 4.2    -- studs/sec (matches CharacterAnimator "Walk" stride)
C.StartBehind = 2.6  -- character starts this far behind the surface (fully hidden)
C.WalkOut = 5.5      -- stops this far in front of the surface
C.Wave = 1.6         -- waves at the player after stepping out
C.FadeBand = 0.9     -- studs over which a body part fades in as it crosses the surface
C.GlowFade = 1.0     -- energy outline fades this long after the body is fully out
C.EndAnimation = "Idle"

C.EffectsDistance = 160 -- beyond this, clients pause the vortex/particles
C.PixelsPerStud = 40

-- Sound slots. Leave "" = silent. Only paste IDs you've checked in the Creator Store.
C.Sounds = { Hum = "", Surge = "", Whoosh = "", Arrive = "" }
C.Volume = 0.6
C.SoundGroupName = "SFX"
C.MuteAttribute = "SFXMuted"
C.ReducedMotionAttribute = "ReducedMotion"

function C.Color(rarity) return C.RarityColor[rarity or ""] or C.IdleColor end
function C.WalkTime() return (C.StartBehind + C.WalkOut) / C.WalkSpeed end
function C.Total() return C.Surge + C.WalkTime() + C.Wave end

return C
