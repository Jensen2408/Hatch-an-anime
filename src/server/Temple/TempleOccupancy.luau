local M = {}
local function visible(root, on)
    for _, v in root:GetDescendants() do
        if v:IsA("BasePart") then
            if v:GetAttribute("ClaimTransparency") == nil then
                v:SetAttribute("ClaimTransparency", v.Transparency)
                v:SetAttribute("ClaimCollide", v.CanCollide)
                v:SetAttribute("ClaimQuery", v.CanQuery)
            end
            v.Transparency = on and v:GetAttribute("ClaimTransparency") or 1
            v.CanCollide = on and v:GetAttribute("ClaimCollide") or false
            v.CanQuery = on and v:GetAttribute("ClaimQuery") or false
        elseif v:IsA("Decal") or v:IsA("Texture") then
            if v:GetAttribute("ClaimTransparency") == nil then
                v:SetAttribute("ClaimTransparency", v.Transparency)
            end
            v.Transparency = on and v:GetAttribute("ClaimTransparency") or 1
        elseif v:IsA("SurfaceGui") or v:IsA("BillboardGui") or v:IsA("ProximityPrompt") then
            if v:GetAttribute("ClaimEnabled") == nil then
                v:SetAttribute("ClaimEnabled", v.Enabled)
            end
            v.Enabled = on and v:GetAttribute("ClaimEnabled") or false
        end
    end
    if root:IsA("BasePart") then
        if root:GetAttribute("ClaimTransparency") == nil then
            root:SetAttribute("ClaimTransparency", root.Transparency)
            root:SetAttribute("ClaimCollide", root.CanCollide)
        end
        root.Transparency = on and root:GetAttribute("ClaimTransparency") or 1
        root.CanCollide = on and root:GetAttribute("ClaimCollide") or false
        root.CanQuery = on
    end
end
function M.ApplyPaths(plot, on)
    local fence = plot:FindFirstChild("FENCE")
    if not fence then
        return
    end
    for _, name in { "Ground", "Stone_Slabs" } do
        local path = fence:FindFirstChild(name)
        if path then
            visible(path, on)
        end
    end
end
function M.Apply(plot, on)
    for _, v in plot:GetChildren() do
        if
            v.Name == "FENCE"
            or v.Name == "OwnerSign"
            or v.Name == "SignPost"
            or v.Name == "Slots"
            or v.Name == "ChamberYard"
            or v.Name == "AppearanceSign"
            or v.Name == "AppearanceSignPost"
        then
            visible(v, on)
        end
    end
    for _, v in plot.Temple:GetDescendants() do
        if v:IsA("Light") then
            if v:GetAttribute("ClaimEnabled") == nil then
                v:SetAttribute("ClaimEnabled", v.Enabled)
            end
            v.Enabled = on and v:GetAttribute("ClaimEnabled") or false
        elseif v:IsA("BasePart") and (v.Material == Enum.Material.Neon or v:GetAttribute("ClaimNeon")) then
            v:SetAttribute("ClaimNeon", true)
            v.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
        end
    end
end
return M
