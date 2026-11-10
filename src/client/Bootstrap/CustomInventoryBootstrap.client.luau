--[[ ReplicatedFirst.CustomInventoryBootstrap  (LocalScript)
Since 2026-11-08 the game uses Roblox's default backpack (tool slots at the bottom, the backpack from the top bar).
Tool pictures come from ServerScriptService.ToolIcons. This only makes sure the backpack is on at startup and after
respawns; cinematics turn all CoreGui off and back on themselves. The pcall covers SetCoreGuiEnabled failing before
the CoreGui is ready. (Before: this hid the backpack every frame for GameHUD's custom hotbar.)
]]
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local function showBackpack()
    for _ = 1, 20 do
        if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, true) then
            return
        end
        task.wait(0.25)
    end
end
showBackpack()
Players.LocalPlayer.CharacterAdded:Connect(showBackpack)
