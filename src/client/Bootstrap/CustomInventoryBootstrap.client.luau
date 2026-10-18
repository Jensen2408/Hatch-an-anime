--[[ ReplicatedFirst.CustomInventoryBootstrap  (LocalScript)
Disables Roblox's tool slots (CoreGui Backpack): the game uses its own hotbar + Inventory (GameHUD).
No remotes. The pcall covers SetCoreGuiEnabled failing before the CoreGui is ready.
]]
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local function hideBackpack()
    pcall(function()
        if StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack) then
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
        end
    end)
end
hideBackpack()
-- Re-checked every frame: respawns and cinematics can restore all CoreGui.
RunService:BindToRenderStep("CustomInventoryHideBackpack", Enum.RenderPriority.Last.Value, hideBackpack)
