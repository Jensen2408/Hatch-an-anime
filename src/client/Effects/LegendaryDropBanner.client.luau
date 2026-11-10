-- LegendaryDropBanner (LocalScript, StarterPlayerScripts)
-- Gold banner at the top of the screen whenever a Legendary egg enters the river. Watches the workspace attribute
-- LastLegendaryAt (written by RiverEggSpawnScheduler); the river board shows the countdown to the next one.
-- 2026-11-10: drawn by ReplicatedStorage.EventUI, so it is the same banner as the other events and queues with them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventUI = require(ReplicatedStorage:WaitForChild("EventUI"))

local SHOW_SECONDS = 4

workspace:GetAttributeChangedSignal("LastLegendaryAt"):Connect(function()
    EventUI.announce({
        title = "LEGENDARY EGG!",
        text = "A Legendary egg is in the river - grab it!",
        theme = "eggrush",
        icon = EventUI.ICON.eggGold,
        seconds = SHOW_SECONDS,
        sound = "Purchase",
    })
end)
