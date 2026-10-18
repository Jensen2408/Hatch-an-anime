--[[ ServerScriptService.EggSteal.EggStealServer  (Script, Disabled in the project file - steal system is OFF)
Starts the steal system. Keep EggStealService as a sibling ModuleScript.
Optional hooks, e.g.:
  local EggStealService = require(script.Parent.EggStealService)
  EggStealService.OnSecured = function(thief, info, victim) end
]]
local EggStealService = require(script.Parent:WaitForChild("EggStealService"))
EggStealService.Init()
