local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local pending = {}
RS.HatchCameraReady.OnServerEvent:Connect(function(player, token)
    local p = pending[player]
    if p and token == p.token then
        p.ready = true
    end
end)
local Gate = {}
function Gate.Focus(player, chamber, home, duration)
    local p = { token = game.HttpService:GenerateGUID(false) }
    pending[player] = p
    RS.CinematicHatchCue:FireClient(player, "Start", chamber, home, duration, 0.2, p.token)
    local deadline = os.clock() + 8
    while not p.ready and os.clock() < deadline and player.Parent == Players and chamber:IsDescendantOf(workspace) do
        task.wait()
    end
    if pending[player] == p then
        pending[player] = nil
    end
    return p.ready == true
end
return Gate
