-- Disable Roblox's tool slots before custom inventory dependencies load.
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
-- Also handle respawns and cinematics that restore all CoreGui.
RunService:BindToRenderStep("CustomInventoryHideBackpack", Enum.RenderPriority.Last.Value, hideBackpack)
