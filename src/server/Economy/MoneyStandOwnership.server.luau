--[[ ServerScriptService.MoneyStandOwnership  (Script)
Spawns / removes the per-slot "MoneyStand" models on every plot so they always match plot ownership
and slot unlock state. Runs only on the server; clients never create stands.

Inputs (attributes, written by the plot / slot systems):
  • Plot   OwnerUserId (number, 0 = unowned)
  • Slot   Unlocked (bool), Available (bool, false = slot is hidden on this plot floor)

Templates: ServerStorage.MoneyStandPlotTemplates.<PlotName>.<SlotName> (a Model per slot).

Outputs:
  • Slot.MoneyStand   clone of the template, tagged "MoneyStand" (picked up by MoneyStandServer / MoneyStandClient)
                      with attributes OwnerUserId, Stored = 0, IncomePerSecond = 0, Pressed = false.
  • Slot.LockedGhost  grey, non-interactive preview of the stand on locked-but-buyable slots.
No remotes.

Note: selene reports `if_same_then_else` in buildLockedGhost because three branches all call :Destroy().
They are kept separate on purpose (different reasons to strip the instance); merging them is not worth a
bytecode change.
]]
local CollectionService = game:GetService("CollectionService")

local standTemplates = game.ServerStorage:WaitForChild("MoneyStandPlotTemplates")

-- locked (but buyable-floor) slots show a grey, see-through ghost of the podium
local GHOST_COLOR = Color3.fromRGB(62, 62, 66) -- dark grey

-- Clones a stand template into an inert, see-through "LockedGhost" (no sign, no scripts/prompts/lights/sounds).
local function buildLockedGhost(template)
    local ghost = template:Clone()
    ghost.Name = "LockedGhost"
    for _, descendant in ghost:GetDescendants() do
        if
            descendant:IsA("BasePart")
            and (
                descendant.Name == "Display"
                or descendant.Name == "Display_Trim"
                or descendant.Name == "Post"
                or descendant.Name == "Post_Foot"
            )
        then
            descendant:Destroy() -- no display sign on locked ghosts
        elseif descendant:IsA("BasePart") then
            descendant.Color = GHOST_COLOR
            descendant.Material = Enum.Material.SmoothPlastic
            descendant.MaterialVariant = ""
            descendant.CastShadow = false
            descendant.CanCollide = false
            descendant.CanQuery = false
            descendant.CanTouch = false
            if descendant.Transparency < 1 then
                descendant.Transparency = math.max(descendant.Transparency, 0.78)
            end
            if descendant:IsA("MeshPart") then
                descendant.TextureID = ""
            end
        elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
            descendant:Destroy()
        elseif
            descendant:IsA("LuaSourceContainer")
            or descendant:IsA("ProximityPrompt")
            or descendant:IsA("ClickDetector")
            or descendant:IsA("BillboardGui")
            or descendant:IsA("SurfaceGui")
            or descendant:IsA("Light")
            or descendant:IsA("ParticleEmitter")
            or descendant:IsA("Sound")
            or descendant:IsA("SurfaceAppearance")
        then
            descendant:Destroy()
        end
    end
    return ghost
end

local function setupPlot(plot)
    -- Reconciles every slot of this plot with the current owner + Unlocked/Available attributes.
    local function refresh()
        local ownerUserId = plot:GetAttribute("OwnerUserId") or 0
        local plotTemplates = standTemplates:FindFirstChild(plot.Name)
        for _, slot in plot.Slots:GetChildren() do
            local stand = slot:FindFirstChild("MoneyStand")
            local ghost = slot:FindFirstChild("LockedGhost")
            local wantGhost = ownerUserId ~= 0
                and slot:GetAttribute("Unlocked") ~= true
                and slot:GetAttribute("Available") ~= false
            if wantGhost and not ghost then
                local template = plotTemplates and plotTemplates:FindFirstChild(slot.Name)
                if template then
                    buildLockedGhost(template).Parent = slot
                end
            elseif not wantGhost and ghost then
                ghost:Destroy()
            end
            if ownerUserId == 0 or slot:GetAttribute("Unlocked") ~= true then
                if stand then
                    CollectionService:RemoveTag(stand, "MoneyStand")
                    stand:Destroy()
                end
            else
                if not stand then
                    local template = plotTemplates and plotTemplates:FindFirstChild(slot.Name)
                    if template then
                        stand = template:Clone()
                        stand.Name = "MoneyStand"
                        stand:SetAttribute("OwnerUserId", ownerUserId)
                        stand:SetAttribute("Stored", 0)
                        stand:SetAttribute("IncomePerSecond", 0)
                        stand:SetAttribute("Pressed", false)
                        stand.Parent = slot
                        CollectionService:AddTag(stand, "MoneyStand")
                    end
                elseif stand:GetAttribute("OwnerUserId") ~= ownerUserId then
                    -- plot changed hands while the stand survived: reset it so the new owner can't collect old cash
                    stand:SetAttribute("OwnerUserId", ownerUserId)
                    stand:SetAttribute("Stored", 0)
                    stand:SetAttribute("IncomePerSecond", 0)
                    stand:SetAttribute("Pressed", false)
                end
            end
        end
    end
    -- Only slots present at setup time are watched; slots added later are not (they still refresh on owner change).
    for _, slot in plot.Slots:GetChildren() do
        slot:GetAttributeChangedSignal("Unlocked"):Connect(refresh)
        slot:GetAttributeChangedSignal("Available"):Connect(refresh)
    end
    plot:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
    refresh()
end

for _, plot in workspace.Plots:GetChildren() do
    setupPlot(plot)
end
workspace.Plots.ChildAdded:Connect(setupPlot)
