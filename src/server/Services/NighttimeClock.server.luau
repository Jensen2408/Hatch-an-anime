-- NighttimeClock (server Script, ServerScriptService)
-- Drives NighttimeService: republishes the night-cycle workspace attributes every 0.1 s.
local NighttimeService = require(script.Parent.NighttimeService)

while true do
    NighttimeService.Update(workspace:GetServerTimeNow())
    task.wait(0.1)
end
