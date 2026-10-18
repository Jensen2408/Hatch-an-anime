--[[ StarterPlayerScripts.OwnerPanelClient (LocalScript)
Stud-style Owner / Admin panel. Opens with F8, /owner (owner) or /admin (any staff).
UI lives in ReplicatedStorage.OwnerPanel.StudPanel. The server re-checks every action.
]]
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local folder = RS:WaitForChild("OwnerPanel")
local Remote = folder:WaitForChild("Action")
local StudPanel = require(folder:WaitForChild("StudPanel"))
local api, gui
local function build()
    if gui then
        gui:Destroy()
        gui = nil
        api = nil
    end
    local role = player:GetAttribute("PanelRole")
    if role ~= "Owner" and role ~= "Admin" then
        return
    end
    gui = Instance.new("ScreenGui")
    gui.Name = "OwnerPanel"
    gui.ResetOnSpawn = false
    gui.Enabled = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 50
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = player:WaitForChild("PlayerGui")
    api = StudPanel.Build(gui, {
        role = role,
        userId = player.UserId,
        userName = player.Name,
        invoke = function(action, args)
            return Remote:InvokeServer(action, args)
        end,
    })
end
build()
player:GetAttributeChangedSignal("PanelRole"):Connect(build)
UIS.InputBegan:Connect(function(i, gp)
    if gp or not api then
        return
    end
    if i.KeyCode == Enum.KeyCode.F8 then
        api.toggle()
    elseif i.KeyCode == Enum.KeyCode.Escape and gui.Enabled then
        api.close()
    end
end)
RS:WaitForChild("OwnerPanelOpen").OnClientEvent:Connect(function()
    if api then
        api.open()
    end
end)
player.Chatted:Connect(function(msg)
    local m = msg:lower():gsub("%s+", "")
    if m == "/admin" then
        if api then
            api.open()
        end
    elseif m == "/owner" and player:GetAttribute("PanelRole") == "Owner" then
        if api then
            api.open()
        end
    end
end)
Players.PlayerAdded:Connect(function()
    if api then
        api.refresh()
    end
end)
Players.PlayerRemoving:Connect(function()
    if api then
        task.wait()
        api.refresh()
    end
end)
