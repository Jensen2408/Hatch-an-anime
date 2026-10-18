local library = game.ServerStorage:WaitForChild("BrainrotModels")
local Catalog = require(game.ReplicatedStorage.CharacterCatalog)
local Economy = require(game.ReplicatedStorage.CharacterEconomy)
local Mutations = require(script.Parent:WaitForChild("Mutations"))
local Rewards = {}
function Rewards.Resolve(tool, source)
    if tool and tool:GetAttribute("GoldVariant") then
        return game.ServerStorage.FutureUpdateContent.Characters:FindFirstChild("Golden Pirate"), "Pirate"
    end
    local kind = (tool and tool:GetAttribute("EggType"))
        or source:GetAttribute("EggType")
        or (tool and tool.Name)
        or "Pirate"
    kind = tostring(kind):gsub("[Ee]gg", ""):gsub("^%s+", ""):gsub("%s+$", "")

    local model = library:FindFirstChild(kind)
    if model and model:IsA("Model") and model:GetAttribute("CharacterId") then
        return model, kind
    end
    return nil, kind
end
function Rewards.Tool(template, id, stats, mutation)
    stats = stats or Economy.Read(template, id) or Economy.Roll(id)
    if mutation == nil and not template:GetAttribute("Golden") then
        mutation = Mutations.Roll()
    end
    if mutation == false then
        mutation = nil
    end
    local mutated = mutation and Mutations.Model(id, mutation, template)
    if mutated then
        template = mutated
    end
    local tool = Instance.new("Tool")
    if mutation then
        tool:SetAttribute("Mutation", mutation)
    end
    tool.Name = id .. " Character"
    tool.ToolTip = "Hatched " .. id .. " • Place on your temple plate"
    tool.CanBeDropped = false
    if template:GetAttribute("Golden") then
        tool:SetAttribute("GoldVariant", true)
        tool:SetAttribute("Golden", true)
        tool.Name = "Golden Pirate Character"
    end
    tool:SetAttribute("BrainrotId", id)
    tool:SetAttribute("CharacterId", id)
    tool:SetAttribute("Hatched", true)
    local entry = Catalog.ById[id]
    if entry then
        Catalog.Stamp(tool, entry)
        tool.ToolTip = entry.Name .. " • " .. entry.Rarity .. " • " .. Catalog.FormatPrice(entry.Price)
    end
    Economy.Apply(tool, id, stats)
    if mutation then
        tool.Name = mutation .. " " .. tool.Name
    end
    if entry then
        tool.ToolTip = entry.Name
            .. " • "
            .. entry.Rarity
            .. " • Power "
            .. Economy.Format(stats.Power)
            .. " • $"
            .. Economy.Format(stats.IncomePerSecond)
            .. "/sec"
    end
    local visual = template:Clone()
    visual.Name = "Character"
    local _, bounds = visual:GetBoundingBox()
    visual:ScaleTo(visual:GetScale() * 6 / math.max(bounds.Y, 0.01))
    local box = visual:GetBoundingBox()
    visual:PivotTo(visual:GetPivot() - box.Position)
    visual.Parent = tool
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.one
    handle.Transparency = 1
    handle.CanCollide = false
    handle.CanTouch = false
    handle.Massless = true
    handle.Parent = tool
    for _, p in visual:GetDescendants() do
        if p:IsA("BasePart") then
            p.Anchored = false
            p.CanCollide = false
            p.CanTouch = false
            p.CanQuery = false
            p.Massless = true
            local w = Instance.new("WeldConstraint")
            w.Part0 = handle
            w.Part1 = p
            w.Parent = handle
        elseif p:IsA("BaseScript") or p:IsA("ProximityPrompt") or p:IsA("BillboardGui") then
            p:Destroy()
        end
    end
    if mutation then
        visual:SetAttribute("Mutation", mutation)
    end
    Economy.Apply(visual, id, stats)
    if mutation then
        Mutations.AddAura(visual, mutation)
    end
    if mutated then
        mutated:Destroy()
    end
    tool.Grip = CFrame.new(0, -0.35, 0) * CFrame.Angles(0, math.pi, 0)
    return tool
end
return Rewards
