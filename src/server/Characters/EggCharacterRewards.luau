--[[ ServerScriptService.EggCharacterRewards  (ModuleScript)
Turns a hatch result into a character template and builds the holdable character Tool. Server only.

API:
  Rewards.Resolve(tool?, source) -> (template: Model?, kind: string)
      Picks the character model for an egg. A golden egg tool always gives the "Golden Pirate" model
      (kind "Pirate"). Otherwise the kind comes from tool.EggType, source.EggType or the tool's name
      (with "Egg"/"egg" and surrounding spaces stripped), defaulting to "Pirate"; the template is
      ServerStorage.BrainrotModels.<kind> if it is a Model with a CharacterId.
  Rewards.Tool(template, id, stats?, mutation?) -> Tool
      stats defaults to CharacterEconomy.Read(template, id) or a fresh Economy.Roll(id).
      mutation: nil = roll one (unless the template is Golden), false = force no mutation, string = use it.
      The Tool carries BrainrotId / CharacterId / Hatched / Mutation / GoldVariant / Golden + catalog and
      economy attributes; its "Character" child is the visual welded to an invisible Handle.
]]
local brainrotModels = game.ServerStorage:WaitForChild("BrainrotModels")
local Catalog = require(game.ReplicatedStorage.CharacterCatalog)
local Economy = require(game.ReplicatedStorage.CharacterEconomy)
local Mutations = require(script.Parent:WaitForChild("Mutations"))

local DISPLAY_HEIGHT = 6 -- studs; held characters are scaled to this height

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

    local model = brainrotModels:FindFirstChild(kind)
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
    -- a mutated clone replaces the template for the visual and is destroyed at the end
    local mutatedTemplate = mutation and Mutations.Model(id, mutation, template)
    if mutatedTemplate then
        template = mutatedTemplate
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

    -- Visual: scaled copy centred on the tool origin, welded to an invisible massless Handle.
    local visual = template:Clone()
    visual.Name = "Character"
    local _, unscaledSize = visual:GetBoundingBox()
    visual:ScaleTo(visual:GetScale() * DISPLAY_HEIGHT / math.max(unscaledSize.Y, 0.01))
    local boundingBox = visual:GetBoundingBox()
    visual:PivotTo(visual:GetPivot() - boundingBox.Position)
    visual.Parent = tool
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.one
    handle.Transparency = 1
    handle.CanCollide = false
    handle.CanTouch = false
    handle.Massless = true
    handle.Parent = tool
    for _, descendant in visual:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.Anchored = false
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
            descendant.Massless = true
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = handle
            weld.Part1 = descendant
            weld.Parent = handle
        elseif descendant:IsA("BaseScript") or descendant:IsA("ProximityPrompt") or descendant:IsA("BillboardGui") then
            descendant:Destroy()
        end
    end
    if mutation then
        visual:SetAttribute("Mutation", mutation)
    end
    Economy.Apply(visual, id, stats)
    if mutation then
        Mutations.AddAura(visual, mutation)
    end
    if mutatedTemplate then
        mutatedTemplate:Destroy()
    end
    tool.Grip = CFrame.new(0, -0.35, 0) * CFrame.Angles(0, math.pi, 0)
    return tool
end

return Rewards
