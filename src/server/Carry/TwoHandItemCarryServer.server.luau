-- ServerScriptService.TwoHandItemCarryServer (Script): boots TwoHandItemCarryService (two-hand carry visuals
-- for egg / character Tools) and swallows the DropHeldItem remote.
local TwoHandItemCarryService = require(script.Parent.TwoHandItemCarryService)
TwoHandItemCarryService.Init()
-- Player dropping (F key / Drop button) is turned off on purpose.
-- Old handler + DropHeldItemClient are in ServerStorage._ARCHIVE.BeforeNoDrop_1792078437-- (Deaths/steals still drop items through their own code.)
-- DropHeldItem is a place-owned RemoteEvent; the empty handler keeps client fires from queueing up unhandled.
game.ReplicatedStorage.DropHeldItem.OnServerEvent:Connect(function() end)
