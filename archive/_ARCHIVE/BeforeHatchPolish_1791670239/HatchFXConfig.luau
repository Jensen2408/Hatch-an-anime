--[[ ReplicatedStorage.HatchFX.HatchFXConfig  (ModuleScript, shared)
Every timing, colour and slot for the hatch animation. Server and clients read the same table,
so the server's wait times and the client's animation always line up.
]]
local C = {}
C.UseExistingCharacterInfo = true
local rgb = Color3.fromRGB

-- seconds from hatch start (ordinary roll). Jackpot+ inserts ExtraBeat before Tension.
C.T = { Twitch = 0.55, Build = 0.8, Crack = 2.3, Tension = 3.4, Break = 3.8, Settle = 4.5, End = 5.5 }
C.ExtraBeat = 0.6
C.LabelHold = 3.0 -- seconds the name / rarity / Power / income label stays after End

-- reveal colour comes from CHARACTER RARITY only
C.RarityColor = {
	Common = rgb(214, 219, 228), Uncommon = rgb(120, 214, 96), Rare = rgb(70, 150, 255),
	Epic = rgb(186, 110, 255), Legendary = rgb(255, 196, 64),
}
-- intensity comes from POWER-ROLL QUALITY only (server attribute "HatchRoll"). Unknown/missing = Ordinary.
C.RollLevel = { Ordinary = 1, Strong = 2, Exceptional = 2, Jackpot = 3, Ultra = 3, Cosmic = 3 }
C.Burst = { 16, 26, 36 }        -- burst particles per level
C.Light = { 4, 6, 8 }           -- PointLight brightness at the break, per level
C.JackpotAccent = rgb(255, 236, 170)

C.ShardTravel = 1.6   -- studs upper shards travel before fading (stays inside the chamber)
C.ShardLife = 0.55
C.RingMax = 4.5       -- shock ring max diameter (studs)
C.CrackWidth = 0.06   -- crack thickness relative to egg height (0.06 = 6%)
C.CameraShake = 1.0   -- owner only; 0 disables
C.EffectsDistance = 140 -- beyond this, clients skip particles/shards (reveal still happens)

-- names of incubator parts that brighten during the hatch (substring match)
C.MachineGlowNames = { "Jade", "Backlight", "Indicator", "Liquid" }

-- Sound slots. Leave "" = silent. Only paste IDs you've checked in the Creator Store.
C.Sounds = { Hum = "", Twitch = "", Shake = "", Crack = "", Reveal = "", Settle = "" }
C.Volume = 0.6
C.SoundGroupName = "SFX"          -- uses SoundService.SFX if present (your volume slider)
C.MuteAttribute = "SFXMuted"      -- player attribute that silences hatch sounds
C.ReducedMotionAttribute = "ReducedMotion"

function C.Level(roll) return C.RollLevel[roll or ""] or 1 end
-- per-hatch timeline (extra beat for jackpot+)
function C.Timeline(roll)
	local x = C.Level(roll) >= 3 and C.ExtraBeat or 0
	local T = C.T
	return { Twitch = T.Twitch, Build = T.Build, Crack = T.Crack, Hold = T.Tension, Tension = T.Tension + x,
		Break = T.Break + x, Settle = T.Settle + x, End = T.End + x }
end

local U = { { 1e18, "Qi" }, { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
function C.Short(n)
	return require(game.ReplicatedStorage.CharacterInventory.InventoryFormat).Short(n)
end
function C.LegacyShort(n)
	n = tonumber(n) or 0
	for _, u in U do
		if math.abs(n) >= u[1] then
			local v = n / u[1]
			local s = v < 10 and ("%.2f"):format(v) or v < 100 and ("%.1f"):format(v) or tostring(math.floor(v + 0.5))
			if s:find("%.") then s = s:gsub("0+$", ""):gsub("%.$", "") end
			return s .. u[2]
		end
	end
	return tostring(math.floor(n + 0.5))
end

return C
