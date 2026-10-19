--[[ StarterPlayerScripts.OwnerPanelClient (LocalScript)
Stud-style Owner / Admin panel. Opens with F8, /owner (owner) or /admin (any staff).
UI lives in ReplicatedStorage.OwnerPanel.StudPanel. The server re-checks every action.
The panel is (re)built from the "PanelRole" attribute (set by AdminRoles); non-staff never get a GUI. That attribute
only hides UI: OwnerPanelServer checks AdminRoles on every OwnerPanel.Action invoke.
Remotes: OwnerPanel.Action (via StudPanel's invoke callback), OwnerPanelOpen (server asks to open the panel).
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local panelFolder = ReplicatedStorage:WaitForChild("OwnerPanel")
local actionRemote = panelFolder:WaitForChild("Action")
local StudPanel = require(panelFolder:WaitForChild("StudPanel"))
local panelApi, panelGui
-- Destroys any previous panel, then builds a fresh one if this player is staff.
local function buildPanel()
    if panelGui then
        panelGui:Destroy()
        panelGui = nil
        panelApi = nil
    end
    local role = player:GetAttribute("PanelRole")
    if role ~= "Owner" and role ~= "Admin" then
        return
    end
    panelGui = Instance.new("ScreenGui")
    panelGui.Name = "OwnerPanel"
    panelGui.ResetOnSpawn = false
    panelGui.Enabled = false
    panelGui.IgnoreGuiInset = true
    panelGui.DisplayOrder = 50
    panelGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    panelGui.Parent = player:WaitForChild("PlayerGui")
    panelApi = StudPanel.Build(panelGui, {
        role = role,
        userId = player.UserId,
        userName = player.Name,
        invoke = function(action, args)
            return actionRemote:InvokeServer(action, args)
        end,
    })
end
buildPanel()
-- Rebuild when an admin is added / removed while in game.
player:GetAttributeChangedSignal("PanelRole"):Connect(buildPanel)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not panelApi then
        return
    end
    if input.KeyCode == Enum.KeyCode.F8 then
        panelApi.toggle()
    elseif input.KeyCode == Enum.KeyCode.Escape and panelGui.Enabled then
        panelApi.close()
    end
end)
ReplicatedStorage:WaitForChild("OwnerPanelOpen").OnClientEvent:Connect(function()
    if panelApi then
        panelApi.open()
    end
end)
-- Legacy chat fallback. selene if_same_then_else (pre-existing): both branches open the panel; kept as-is.
player.Chatted:Connect(function(message)
    local command = message:lower():gsub("%s+", "")
    if command == "/admin" then
        if panelApi then
            panelApi.open()
        end
    elseif command == "/owner" and player:GetAttribute("PanelRole") == "Owner" then
        if panelApi then
            panelApi.open()
        end
    end
end)
Players.PlayerAdded:Connect(function()
    if panelApi then
        panelApi.refresh()
    end
end)
Players.PlayerRemoving:Connect(function()
    if panelApi then
        task.wait()
        panelApi.refresh()
    end
end)
