-- ReplicatedStorage.RichGoldFinish  (ModuleScript, shared)
-- Static gold paint for a character model: every visible part (except the GoldFX extras) becomes gold
-- metal and its SurfaceAppearance is tinted. Marks the model with attribute GoldFinish = "RichGold".
-- GoldCharacterFX calls this before adding its animated effects.
local Finish = {}
function Finish.Apply(model)
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") and part.Transparency < 1 and not part:FindFirstAncestor("GoldFX") then
            part.Color = Color3.fromRGB(255, 211, 45)
            part.Material = Enum.Material.Metal
            part.Reflectance = 0.45
            local surfaceAppearance = part:FindFirstChildOfClass("SurfaceAppearance")
            if surfaceAppearance then
                surfaceAppearance.Color = Color3.fromRGB(255, 231, 115)
            end
        end
    end
    model:SetAttribute("GoldFinish", "RichGold")
end
return Finish
