-- StarterPlayerScripts.HatchFXClientStart  (LocalScript)
-- Bootstrap only: starts the client half of the HatchFX egg-opening effect
-- (ReplicatedStorage.HatchFX.HatchFXClient), which watches "Hatching"-tagged incubators.
require(game:GetService("ReplicatedStorage"):WaitForChild("HatchFX"):WaitForChild("HatchFXClient")).Start()
