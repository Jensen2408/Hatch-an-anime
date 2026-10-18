--[[ ServerScriptService.CharacterSize  (Script)
Scales every player's avatar once per spawn, after its appearance has loaded.
Multiplier comes from this script's "SizeMultiplier" attribute (default 1.2). The avatar model is marked
with "SizeApplied" so the same character is never scaled twice.
]]
local Players = game:GetService("Players")

local DEFAULT_SIZE_MULTIPLIER = 1.2

local function scaleCharacter(character)
    if character:GetAttribute("SizeApplied") then
        return
    end
    local multiplier = script:GetAttribute("SizeMultiplier") or DEFAULT_SIZE_MULTIPLIER
    character:ScaleTo(character:GetScale() * multiplier)
    character:SetAttribute("SizeApplied", true)
end

local function setupPlayer(player)
    player.CharacterAppearanceLoaded:Connect(scaleCharacter)
    if player.Character and player:HasAppearanceLoaded() then
        scaleCharacter(player.Character)
    end
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do
    setupPlayer(player)
end
