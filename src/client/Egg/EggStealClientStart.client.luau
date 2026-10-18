--[[ StarterPlayer.StarterPlayerScripts.EggStealClientStart  (LocalScript)
Bootstraps the egg-steal presentation: requires ReplicatedStorage.EggSteal.EggStealClient and calls Start().
]]
require(game:GetService("ReplicatedStorage"):WaitForChild("EggSteal"):WaitForChild("EggStealClient")).Start()
