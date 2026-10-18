local CS = game:GetService("CollectionService")
local templates = game.ServerStorage:WaitForChild("MoneyStandPlotTemplates")
-- locked (but buyable-floor) slots show a grey, see-through ghost of the podium
local GHOST = Color3.fromRGB(62, 62, 66) -- dark grey
local function ghostOf(template)
    local g = template:Clone()
    g.Name = "LockedGhost"
    for _, d in g:GetDescendants() do
        if
            d:IsA("BasePart")
            and (d.Name == "Display" or d.Name == "Display_Trim" or d.Name == "Post" or d.Name == "Post_Foot")
        then
            d:Destroy() -- no display sign on locked ghosts
        elseif d:IsA("BasePart") then
            d.Color = GHOST
            d.Material = Enum.Material.SmoothPlastic
            d.MaterialVariant = ""
            d.CastShadow = false
            d.CanCollide = false
            d.CanQuery = false
            d.CanTouch = false
            if d.Transparency < 1 then
                d.Transparency = math.max(d.Transparency, 0.78)
            end
            if d:IsA("MeshPart") then
                d.TextureID = ""
            end
        elseif d:IsA("Decal") or d:IsA("Texture") then
            d:Destroy()
        elseif
            d:IsA("LuaSourceContainer")
            or d:IsA("ProximityPrompt")
            or d:IsA("ClickDetector")
            or d:IsA("BillboardGui")
            or d:IsA("SurfaceGui")
            or d:IsA("Light")
            or d:IsA("ParticleEmitter")
            or d:IsA("Sound")
            or d:IsA("SurfaceAppearance")
        then
            d:Destroy()
        end
    end
    return g
end
local function setup(plot)
    local function refresh()
        local owner = plot:GetAttribute("OwnerUserId") or 0
        local folder = templates:FindFirstChild(plot.Name)
        for _, slot in plot.Slots:GetChildren() do
            local stand = slot:FindFirstChild("MoneyStand")
            local ghost = slot:FindFirstChild("LockedGhost")
            local wantGhost = owner ~= 0
                and slot:GetAttribute("Unlocked") ~= true
                and slot:GetAttribute("Available") ~= false
            if wantGhost and not ghost then
                local template = folder and folder:FindFirstChild(slot.Name)
                if template then
                    ghostOf(template).Parent = slot
                end
            elseif not wantGhost and ghost then
                ghost:Destroy()
            end
            if owner == 0 or slot:GetAttribute("Unlocked") ~= true then
                if stand then
                    CS:RemoveTag(stand, "MoneyStand")
                    stand:Destroy()
                end
            else
                if not stand then
                    local template = folder and folder:FindFirstChild(slot.Name)
                    if template then
                        stand = template:Clone()
                        stand.Name = "MoneyStand"
                        stand:SetAttribute("OwnerUserId", owner)
                        stand:SetAttribute("Stored", 0)
                        stand:SetAttribute("IncomePerSecond", 0)
                        stand:SetAttribute("Pressed", false)
                        stand.Parent = slot
                        CS:AddTag(stand, "MoneyStand")
                    end
                elseif stand:GetAttribute("OwnerUserId") ~= owner then
                    stand:SetAttribute("OwnerUserId", owner)
                    stand:SetAttribute("Stored", 0)
                    stand:SetAttribute("IncomePerSecond", 0)
                    stand:SetAttribute("Pressed", false)
                end
            end
        end
    end
    for _, slot in plot.Slots:GetChildren() do
        slot:GetAttributeChangedSignal("Unlocked"):Connect(refresh)
        slot:GetAttributeChangedSignal("Available"):Connect(refresh)
    end
    plot:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
    refresh()
end
for _, plot in workspace.Plots:GetChildren() do
    setup(plot)
end
workspace.Plots.ChildAdded:Connect(setup)
