-- ServerStorage.RestoreSurfaceAppearances (ModuleScript; Studio command-bar tool, returns the number restored)
-- require(game.ServerStorage.RestoreSurfaceAppearances)() puts back the SurfaceAppearances + RenderFidelity removed by the Oct 15 memory cleanup
return function()
    local restoredCount = 0
    for _, root in ipairs({ workspace, game.ServerStorage }) do
        for _, part in ipairs(root:GetDescendants()) do
            if
                part:IsA("BasePart")
                and part:GetAttribute("SA_Color") ~= nil
                and not part:FindFirstChildOfClass("SurfaceAppearance")
            then
                local surfaceAppearance = Instance.new("SurfaceAppearance")
                surfaceAppearance.ColorMap = part:GetAttribute("SA_Color")
                surfaceAppearance.NormalMap = part:GetAttribute("SA_Normal")
                surfaceAppearance.MetalnessMap = part:GetAttribute("SA_Metal")
                surfaceAppearance.RoughnessMap = part:GetAttribute("SA_Rough")
                -- SA_Alpha / SA_Tint may be missing or invalid; skip them rather than abort the restore
                pcall(function()
                    surfaceAppearance.AlphaMode = Enum.AlphaMode[part:GetAttribute("SA_Alpha")]
                    surfaceAppearance.Color = part:GetAttribute("SA_Tint")
                end)
                surfaceAppearance.Parent = part
                restoredCount += 1
            end
            if part:IsA("MeshPart") and part:GetAttribute("OldRenderFidelity") then
                pcall(function()
                    part.RenderFidelity = Enum.RenderFidelity[part:GetAttribute("OldRenderFidelity")]
                end)
            end
        end
    end
    return restoredCount
end
