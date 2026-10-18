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
    Common = rgb(214, 219, 228),
    Uncommon = rgb(120, 214, 96),
    Rare = rgb(70, 150, 255),
    Epic = rgb(186, 110, 255),
    Legendary = rgb(255, 196, 64),
}
-- intensity comes from POWER-ROLL QUALITY only (server attribute "HatchRoll"). Unknown/missing = Ordinary.
C.RollLevel = { Ordinary = 1, Strong = 2, Exceptional = 2, Jackpot = 3, Ultra = 3, Cosmic = 3 }
C.Burst = { 16, 26, 36 } -- burst particles per level
C.Light = { 4, 6, 8 } -- PointLight brightness at the break, per level
C.JackpotAccent = rgb(255, 236, 170)

C.ShardTravel = 1.6 -- studs upper shards travel before fading (stays inside the chamber)
C.ShardLife = 0.55
C.RingMax = 4.5 -- shock ring max diameter (studs)
C.CrackWidth = 0.06 -- crack thickness relative to egg height (0.06 = 6%)
C.CameraShake = 1.0 -- owner only; 0 disables
C.EffectsDistance = 140 -- beyond this, clients skip particles/shards (reveal still happens)

-- names of incubator parts that brighten during the hatch (substring match)
C.MachineGlowNames = { "Jade", "Backlight", "Indicator", "Liquid" }

-- Sound slots. Tuned for suspenseful, organic anime egg hatching (subtle quiet build, no loud spaceship engine)
C.Sounds = {
    Hum = "rbxassetid://9116732713", -- Metallic Glow Constant Distant Pulsing Hum 1 (ProSoundEffects)
    Twitch = "rbxassetid://75223491475310", -- Singluar Maraca Shake (surraas, 0.23s gentle egg wobble rattle)
    Shake = "rbxassetid://75223491475310", -- Singluar Maraca Shake (surraas, 0.23s gentle egg wobble rattle)
    Crack = "rbxassetid://9113959343", -- Crack Egg Crunchy 11 (ProSoundEffects, 1.02s crunchy shell snap)
    Reveal = "rbxassetid://71491555548135", -- Skybound_Gacha_GlowUp (N4W1N, 1.91s anime gacha reveal fanfare)
    Settle = "rbxassetid://4612374036", -- bling_big_diamond_pickup (thienbao2109, 2.01s sparkling diamond settle)
}
C.SlotVolumes = {
    Hum = 0.22, -- Subtle suspenseful sci-fi build-up hum
    Twitch = 0.20,
    Shake = 0.18, -- Soft gentle wobble, NOT loud!
    Crack = 0.42, -- Crisp crunchy eggshell fracture
    Reveal = 0.58, -- Rewarding anime gacha glow
    Settle = 0.45, -- Sparkling chime resolve
}
C.Volume = 0.45
C.SoundGroupName = "SFX" -- uses SoundService.SFX if present (your volume slider)
C.MuteAttribute = "SFXMuted" -- player attribute that silences hatch sounds
C.ReducedMotionAttribute = "ReducedMotion"

function C.Level(roll)
    return C.RollLevel[roll or ""] or 1
end
-- per-hatch timeline (extra beat for jackpot+)
C.RarityDuration = { Common = 1, Uncommon = 1.2, Rare = 1.45, Epic = 1.8, Legendary = 2.2 }
function C.Timeline(roll, rarity)
    local scale = C.RarityDuration[rarity or "Common"] or 1
    local extra = C.Level(roll) >= 3 and C.ExtraBeat or 0
    local function at(t)
        return 0.75 + math.max(0, t - 0.75) * scale
    end
    return {
        Twitch = 0.78,
        Build = 1.0,
        Crack = at(2.3),
        Hold = at(3.4),
        Tension = at(3.4) + extra,
        Break = at(3.8) + extra,
        Settle = at(3.8) + extra + 0.7,
        End = at(3.8) + extra + 1.7,
    }
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
            if s:find("%.") then
                s = s:gsub("0+$", ""):gsub("%.$", "")
            end
            return s .. u[2]
        end
    end
    return tostring(math.floor(n + 0.5))
end

return C
