--[[ StarterPlayerScripts.RiverEggCarryClient  (LocalScript)
Shows the StolenEggBanner ("carry it home") while the local player carries a river egg back to their base.

Remote: ReplicatedStorage.RiverEggCarryState (server -> client, fired by RiverEggCarryService):
  ("Stolen", { basePosition, id, eggType, name, rarity, price })   carry started -> Banner.Show
  (state, { id })                                                   carry ended   -> Banner.Resolve(state)
Player attributes RiverEggCarryId / RiverEggCarryBase / RiverEggCarryType mirror the state so the banner is
restored after a respawn / late script start.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Banner = require(ReplicatedStorage:WaitForChild("StolenEggBanner"))
Banner.Start()
local currentCarryId -- id of the carry the banner is showing, nil when none
local function recoverFromAttributes()
    local carryId = player:GetAttribute("RiverEggCarryId")
    local basePosition = player:GetAttribute("RiverEggCarryBase")
    if carryId and typeof(basePosition) == "Vector3" then
        currentCarryId = carryId
        Banner.Show(basePosition, { eggType = player:GetAttribute("RiverEggCarryType") })
    end
end
ReplicatedStorage:WaitForChild("RiverEggCarryState").OnClientEvent:Connect(function(state, data)
    if state == "Stolen" then
        currentCarryId = data.id
        Banner.Show(data.basePosition, data)
    elseif currentCarryId and (not data or data.id == currentCarryId) then
        -- end of the carry we are showing ("Secured" / "Cancelled" / "Dropped"); stale ids are ignored
        currentCarryId = nil
        Banner.Resolve(state)
    end
end)
player:GetAttributeChangedSignal("RiverEggCarryId"):Connect(recoverFromAttributes)
player:GetAttributeChangedSignal("RiverEggCarryBase"):Connect(recoverFromAttributes)
recoverFromAttributes()
