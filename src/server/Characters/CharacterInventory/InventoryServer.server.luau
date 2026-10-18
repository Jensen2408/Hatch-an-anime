-- ServerScriptService.CharacterInventory.InventoryServer  (Script)
-- Boot script: starts the character inventory service (creates its remotes and starts the snapshot loop).
require(script.Parent:WaitForChild("InventoryService")).Init()
