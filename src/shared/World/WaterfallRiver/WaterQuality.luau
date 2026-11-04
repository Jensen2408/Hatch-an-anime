-- ReplicatedStorage.WaterfallRiver.WaterQuality (client)
-- Whether the local player sees Simple Water: flat water whose textures still slide, no wave geometry, no ripple
-- sheen layer, and fewer updates (RiverWater, WaterfallCurtain). The player attribute SimpleWater (saved with the other
-- settings, toggled from the Settings panel in MusicSettings) decides. Until the player has chosen, low graphics
-- quality (Roblox levels 1-3) starts on Simple Water; Automatic and 4+ start on detailed water.
local WaterQuality = {}

function WaterQuality.DefaultSimple()
    local ok, level = pcall(function()
        return UserSettings().GameSettings.SavedQualityLevel.Value
    end)
    return ok and level >= 1 and level <= 3
end

function WaterQuality.IsSimple(player)
    local chosen = player:GetAttribute("SimpleWater")
    if type(chosen) == "boolean" then
        return chosen
    end
    return WaterQuality.DefaultSimple()
end

return WaterQuality
