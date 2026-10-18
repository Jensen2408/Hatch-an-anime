--[[ ReplicatedStorage.Construction.ConstructionConfig  (ModuleScript, shared by server + client)
All tuning lives here. The server and clients compute the SAME timeline from these values,
so nothing timing-related has to be replicated except a start time and a batch count.
]]
local C = {}

C.Kinds = {
	Temple = {
		Retire = 0.6,          -- replacement mode only: old structure sinks away first
		Anticipation = 0.25,
		Foundation = 0.6,      -- time budget for stage-1 batches
		Assembly = 2.4,        -- time budget for every other batch
		BatchMove = 0.42,      -- how long one batch takes to travel into place
		LockIn = 0.4,
		Clear = 0.5,
		RiseDistance = 3.0,    -- foundation rises from this far below its final position
		UpperRise = 2.2,       -- upper batches start this far below their final position
		Lateral = 0.6,         -- max sideways start offset (studs)
		Tilt = 5,              -- max start rotation (degrees)
		Mechanical = false,
	},
	Incubator = {
		Retire = 0.45,
		Anticipation = 0.2,
		Foundation = 0.45,
		Assembly = 1.5,
		BatchMove = 0.34,
		LockIn = 0.35,
		Clear = 0.45,
		RiseDistance = 1.6,
		UpperRise = 1.4,
		Lateral = 0.4,
		Tilt = 4,
		Mechanical = true,     -- adds click sounds on placement
	},
}

C.WaveBand = 2.0            -- studs: parts within the same height band (and stage) move together
C.MaxBatches = 22           -- batches are merged down to this many (performance + readability)
C.MinSpacing = 0.06         -- seconds between batch starts, at minimum
C.ReplaceBelowOverlap = 0.35 -- "auto" mode: if fewer than 35% of parts match, do a full replacement

C.Effects = {
	DustDensity = 1.0,       -- 0..2 multiplier on every dust emit count
	MaxDustPerConstruction = 3, -- emitters per construction (reused for every puff)
	CameraShake = 1.0,       -- 0 disables. Only the purchasing player is shaken.
	SweepStrength = 1.0,     -- final light sweep + edge accent (0 disables)
	Volume = 0.6,
	AnimateDistance = 320,   -- beyond this the client snaps straight to the final state
	EffectsDistance = 180,   -- beyond this dust / sweep are skipped
	Quality = "Auto",        -- "Auto" | "High" | "Low"
}

-- Sound slots. Leave "" to stay silent; paste your own verified rbxassetid:// IDs.
C.Sounds = {
	Rumble = "",        -- low rumble at anticipation
	Place = "",         -- soft stone/block placement (throttled)
	Click = "",         -- mechanical click (incubators)
	Impact = "",        -- final grounded thud
}
C.PlaceSoundGap = 0.12      -- min seconds between placement sounds per construction

-- Name keywords → stage (1 = first). Checked against the part name and its ancestors' names.
-- Put attribute BuildRole = "Foundation" | "Support" | "Wall" | "Upper" | "Roof" | "Detail" (or a number 1-6) to override.
C.RoleStage = { Foundation = 1, Support = 2, Wall = 3, Mechanism = 3, Upper = 4, Frame = 4, Roof = 5, Detail = 6 }
C.Keywords = {
	Temple = {
		{ 1, { "foundation", "stair", "step", "base", "floor", "plinth", "deck", "ground", "platform" } },
		{ 2, { "pillar", "column", "post", "support", "leg", "pier" } },
		{ 3, { "wall", "beam", "panel", "door", "frame", "rail" } },
		{ 4, { "upper", "header", "bracket", "lintel", "kasagi", "shimaki" } },
		{ 5, { "roof", "eave", "ridge", "tier", "cap", "gable" } },
		{ 6, { "trim", "lantern", "light", "glow", "finial", "jewel", "detail", "ornament", "emblem", "sign", "glass" } },
	},
	Incubator = {
		{ 1, { "base", "plinth", "deck", "platform", "foot", "floor" } },
		{ 2, { "support", "pocket", "post", "pillar", "column", "endstop" } },
		{ 3, { "reservoir", "tank", "pipe", "manifold", "elbow", "flange", "riser", "indicator" } },
		{ 4, { "frame", "track", "header", "wall", "back", "ceiling", "beam" } },
		{ 5, { "roof", "kasagi", "shimaki", "eave", "ridge", "cap", "crown" } },
		{ 6, { "glass", "trim", "jade", "light", "lantern", "band", "jewel", "finial", "egganchor" } },
	},
}

-- Shared timeline. phaseOffset = Retire time (replacement only).
function C.Timeline(kind, batchCount, replace)
	local k = C.Kinds[kind] or C.Kinds.Temple
	local n = math.max(1, batchCount)
	local t0 = (replace and k.Retire or 0) + k.Anticipation
	local budget = k.Foundation + k.Assembly - k.BatchMove
	local spacing = math.max(C.MinSpacing, budget / math.max(1, n - 1))
	local landed = t0 + (n - 1) * spacing + k.BatchMove
	return {
		retireEnd = replace and k.Retire or 0,
		buildStart = t0,
		spacing = spacing,
		batchStart = function(i) return t0 + (i - 1) * spacing end, -- i is 1-based
		landed = landed,
		lockInEnd = landed + k.LockIn,
		total = landed + k.LockIn + k.Clear,
	}
end

return C
