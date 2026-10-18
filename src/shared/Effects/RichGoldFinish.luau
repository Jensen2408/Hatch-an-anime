local Finish = {}
function Finish.Apply(model)
    for _, p in model:GetDescendants() do
        if p:IsA("BasePart") and p.Transparency < 1 and not p:FindFirstAncestor("GoldFX") then
            p.Color = Color3.fromRGB(255, 211, 45)
            p.Material = Enum.Material.Metal
            p.Reflectance = 0.45
            local sa = p:FindFirstChildOfClass("SurfaceAppearance")
            if sa then
                sa.Color = Color3.fromRGB(255, 231, 115)
            end
        end
    end
    model:SetAttribute("GoldFinish", "RichGold")
end
return Finish
