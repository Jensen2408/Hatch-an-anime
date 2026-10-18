--[[ ServerScriptService.TempleOccupancy  (ModuleScript, server)
Shows/hides the "claimed plot" decoration depending on whether the plot has an owner.
Original property values are cached once per instance in attributes (ClaimTransparency, ClaimCollide,
ClaimQuery, ClaimEnabled, ClaimNeon) so hiding and showing again restores the authored look.
  TempleOccupancy.Apply(plot, claimed)      -- fence, signs, slots, chamber yard + temple lights/neon
  TempleOccupancy.ApplyPaths(plot, claimed) -- only FENCE.Ground / FENCE.Stone_Slabs
Called by PlotManager (refresh on every owner/level change and when fence pieces stream in).
]]
local TempleOccupancy = {}

-- Plot children that are only visible while the plot is claimed.
local function setClaimVisible(root, visible)
    for _, item in root:GetDescendants() do
        if item:IsA("BasePart") then
            if item:GetAttribute("ClaimTransparency") == nil then
                item:SetAttribute("ClaimTransparency", item.Transparency)
                item:SetAttribute("ClaimCollide", item.CanCollide)
                item:SetAttribute("ClaimQuery", item.CanQuery)
            end
            item.Transparency = visible and item:GetAttribute("ClaimTransparency") or 1
            item.CanCollide = visible and item:GetAttribute("ClaimCollide") or false
            item.CanQuery = visible and item:GetAttribute("ClaimQuery") or false
        elseif item:IsA("Decal") or item:IsA("Texture") then
            if item:GetAttribute("ClaimTransparency") == nil then
                item:SetAttribute("ClaimTransparency", item.Transparency)
            end
            item.Transparency = visible and item:GetAttribute("ClaimTransparency") or 1
        elseif item:IsA("SurfaceGui") or item:IsA("BillboardGui") or item:IsA("ProximityPrompt") then
            if item:GetAttribute("ClaimEnabled") == nil then
                item:SetAttribute("ClaimEnabled", item.Enabled)
            end
            item.Enabled = visible and item:GetAttribute("ClaimEnabled") or false
        end
    end
    -- The root itself (e.g. a path part). Note: CanQuery is not cached here, it simply follows `visible`.
    if root:IsA("BasePart") then
        if root:GetAttribute("ClaimTransparency") == nil then
            root:SetAttribute("ClaimTransparency", root.Transparency)
            root:SetAttribute("ClaimCollide", root.CanCollide)
        end
        root.Transparency = visible and root:GetAttribute("ClaimTransparency") or 1
        root.CanCollide = visible and root:GetAttribute("ClaimCollide") or false
        root.CanQuery = visible
    end
end

function TempleOccupancy.ApplyPaths(plot, claimed)
    local fence = plot:FindFirstChild("FENCE")
    if not fence then
        return
    end
    for _, pathName in { "Ground", "Stone_Slabs" } do
        local path = fence:FindFirstChild(pathName)
        if path then
            setClaimVisible(path, claimed)
        end
    end
end

function TempleOccupancy.Apply(plot, claimed)
    for _, child in plot:GetChildren() do
        if
            child.Name == "FENCE"
            or child.Name == "OwnerSign"
            or child.Name == "SignPost"
            or child.Name == "Slots"
            or child.Name == "ChamberYard"
            or child.Name == "AppearanceSign"
            or child.Name == "AppearanceSignPost"
        then
            setClaimVisible(child, claimed)
        end
    end
    -- Unclaimed temples go dark: lights off, neon parts become SmoothPlastic (ClaimNeon remembers them).
    for _, item in plot.Temple:GetDescendants() do
        if item:IsA("Light") then
            if item:GetAttribute("ClaimEnabled") == nil then
                item:SetAttribute("ClaimEnabled", item.Enabled)
            end
            item.Enabled = claimed and item:GetAttribute("ClaimEnabled") or false
        elseif item:IsA("BasePart") and (item.Material == Enum.Material.Neon or item:GetAttribute("ClaimNeon")) then
            item:SetAttribute("ClaimNeon", true)
            item.Material = claimed and Enum.Material.Neon or Enum.Material.SmoothPlastic
        end
    end
end

return TempleOccupancy
