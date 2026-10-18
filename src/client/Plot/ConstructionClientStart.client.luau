-- StarterPlayerScripts.ConstructionClientStart  (LocalScript)
-- Boots the cosmetic construction animator (ReplicatedStorage.Construction.ConstructionClient), which animates
-- models the server tags "Constructing" (see ServerScriptService.Construction.ConstructionService).
require(game:GetService("ReplicatedStorage"):WaitForChild("Construction"):WaitForChild("ConstructionClient")).Start()
