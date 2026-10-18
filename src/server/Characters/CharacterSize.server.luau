local Players=game:GetService("Players")
local function scale(character)
 if character:GetAttribute("SizeApplied") then return end
 local multiplier=script:GetAttribute("SizeMultiplier") or 1.2
 character:ScaleTo(character:GetScale()*multiplier)
 character:SetAttribute("SizeApplied",true)
end
local function setup(player)
 player.CharacterAppearanceLoaded:Connect(scale)
 if player.Character and player:HasAppearanceLoaded() then scale(player.Character) end
end
Players.PlayerAdded:Connect(setup)
for _,player in Players:GetPlayers() do setup(player) end
