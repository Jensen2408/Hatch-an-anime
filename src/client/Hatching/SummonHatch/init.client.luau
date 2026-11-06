--[[ StarterPlayerScripts.SummonHatch  (LocalScript)
Plays the summon-room hatch animation (RollFx) for the player who pressed Hatch. The server owns the result, timing and
reward; this only draws.

Remotes (made by ServerScriptService.SummonHatchServer):
  ReplicatedStorage.SummonHatchCue   server -> owner  ("Play", payload)  payload: see SummonHatchServer.Play
  ReplicatedStorage.SummonHatchDone  owner -> server  (token)  once the animation has ended and the world is back
The egg and character copies arrive in PlayerGui.SummonHatchAssets.<token> (only this player gets them).
Summons queue: a second hatch that finishes while one is playing waits for it.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local RollFx = require(script.RollFx)
local SummonUi = require(script.SummonUi)

local player = Players.LocalPlayer
local cue = ReplicatedStorage:WaitForChild("SummonHatchCue")
local done = ReplicatedStorage:WaitForChild("SummonHatchDone")
local queue = {}
local running = false

-- Waits (briefly) for the payload's models to replicate into PlayerGui.SummonHatchAssets.<token>.
local function assetsOf(payload)
    local root = player:WaitForChild("PlayerGui"):WaitForChild("SummonHatchAssets", 10)
    local folder = root and root:WaitForChild(payload.token, 10)
    if not folder then
        return false
    end
    payload.egg = folder:WaitForChild("Egg", 10)
    payload.character = folder:WaitForChild("Character", 10)
    return payload.egg ~= nil and payload.character ~= nil
end

-- Undoes what RollFx.play may already have changed when it errors before its cleanup thread starts.
local function rescue()
    RunService:UnbindFromRenderStep("SummonHatchCam")
    ContextActionService:UnbindAction("SummonHatchLock")
    for _, name in { "SummonHatchFx" } do
        local leftover = workspace:FindFirstChild(name)
        if leftover then
            leftover:Destroy()
        end
    end
    local grade = Lighting:FindFirstChild("SummonHatchGrade")
    if grade then
        grade:Destroy()
    end
    local gui = player.PlayerGui:FindFirstChild(SummonUi.GuiName)
    if gui then
        gui:Destroy()
    end
    SummonUi.setHud(true)
    local cam = workspace.CurrentCamera
    cam.CameraType = Enum.CameraType.Custom
    cam.FieldOfView = 70
    pcall(function()
        require(player.PlayerScripts:WaitForChild("PlayerModule")):GetControls():Enable()
    end)
    RollFx.busy = false
end

local function pump()
    if running then
        return
    end
    local payload = table.remove(queue, 1)
    if not payload then
        return
    end
    running = true
    task.spawn(function()
        local ready = assetsOf(payload)
        local function finish()
            done:FireServer(payload.token)
            running = false
            pump()
        end
        if not ready then
            warn("[SummonHatch] assets for " .. tostring(payload.characterId) .. " never arrived; skipping the summon")
            finish()
            return
        end
        local ok, err = pcall(RollFx.play, payload, finish)
        if not ok then
            -- failed while setting up (before its own cleanup thread existed): put the player's view back by hand
            warn("[SummonHatch] could not start: " .. tostring(err))
            rescue()
            finish()
        end
    end)
end

cue.OnClientEvent:Connect(function(action, payload)
    if action == "Play" and type(payload) == "table" and type(payload.token) == "string" then
        -- set at once: the incubator's HatchFX starts right after this cue and stays silent for the owner on it
        player:SetAttribute("SummonHatchActive", true)
        table.insert(queue, payload)
        pump()
    end
end)

local K = require(script.FxKit)
K.preload()
require(script.Sfx).preload()
