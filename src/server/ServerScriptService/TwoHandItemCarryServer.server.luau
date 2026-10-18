local Carry=require(script.Parent.TwoHandItemCarryService)
Carry.Init()
-- Player dropping (F key / Drop button) is turned off on purpose.
-- Old handler + DropHeldItemClient are in ServerStorage._ARCHIVE.BeforeNoDrop_1792078437-- (Deaths/steals still drop items through their own code.)
game.ReplicatedStorage.DropHeldItem.OnServerEvent:Connect(function() end)
