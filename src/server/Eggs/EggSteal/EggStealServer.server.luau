--[[ ServerScriptService.EggSteal.EggStealServer  (Script)
Starts the steal system. Keep EggStealService as a sibling ModuleScript.
Optional hooks, e.g.:
  local Service = require(script.Parent.EggStealService)
  Service.OnSecured = function(thief, info, victim) end
]]
local Service = require(script.Parent:WaitForChild("EggStealService"))
Service.Init()
