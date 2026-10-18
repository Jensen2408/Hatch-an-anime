-- EggLabelsClient (LocalScript, client): boots the floating river-egg labels.
-- All logic lives in ReplicatedStorage.EggLabel; Start() is idempotent and yields on PlayerGui.
require(game:GetService("ReplicatedStorage"):WaitForChild("EggLabel")).Start()
