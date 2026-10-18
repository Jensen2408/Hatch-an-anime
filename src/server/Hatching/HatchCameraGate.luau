--[[ HatchCameraGate (ServerScriptService ModuleScript)
Hands the hatch camera to the owner's client and waits until the client confirms it is focused,
so the HatchFX reveal does not start while the camera is still flying in.

  Gate.Focus(player, chamber, home, duration) -> boolean (true = client confirmed in time)

Remotes:
  ReplicatedStorage.CinematicHatchCue  server -> client  ("Start", chamber, home, duration, 0.2, token)
  ReplicatedStorage.HatchCameraReady   client -> server  (token)
Waits at most 8 s; callers hatch anyway when it returns false (see HatchGoo).
--]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local pendingByPlayer = {} -- [player] = { token = string, ready = boolean? }

-- Only the token of the latest Focus call for that player counts.
ReplicatedStorage.HatchCameraReady.OnServerEvent:Connect(function(player, token)
    local request = pendingByPlayer[player]
    if request and token == request.token then
        request.ready = true
    end
end)

local Gate = {}

function Gate.Focus(player, chamber, home, duration)
    local request = { token = game.HttpService:GenerateGUID(false) }
    pendingByPlayer[player] = request
    ReplicatedStorage.CinematicHatchCue:FireClient(player, "Start", chamber, home, duration, 0.2, request.token)
    local deadline = os.clock() + 8
    while
        not request.ready
        and os.clock() < deadline
        and player.Parent == Players
        and chamber:IsDescendantOf(workspace)
    do
        task.wait()
    end
    -- A newer Focus call may have replaced this request meanwhile; leave that one alone.
    if pendingByPlayer[player] == request then
        pendingByPlayer[player] = nil
    end
    return request.ready == true
end

return Gate
