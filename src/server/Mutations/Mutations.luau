--[[ ServerScriptService.Mutations (ModuleScript, server only)
Rolled on every hatch. A mutation is a tier name ("Silver" | "Gold" | "Diamond" | "Rainbow") or nil (no mutation).

Mutation model:
  * Roll(luck)            -> tier | nil. Each tier is an independent "1 in Odds[tier] / luck" check, rarest first,
                             so the first (rarest) tier that passes wins. luck < 1 is clamped to 1.
  * Model(id, tier, base) -> a fresh mutated clone (Mutation attribute set, base attributes copied) or nil
                             (caller keeps the base model).
  * AddAura(model, tier)  -> welds/anchors a "RarityAura" part from ServerStorage.MutationAuras.<tier>.
  The income multiplier per tier is NOT here: it lives in ReplicatedStorage.CharacterEconomy.

Assets:
  * Models: ServerStorage.UpdatePack_Mutations[_<Theme>].Characters_<tier> (pack model names come from
    ServerStorage.BrainrotModels.<id>:GetAttribute("DesignName")). Gold has no model in the pack:
    the base model is tinted gold instead.
  * Auras:  ServerStorage.MutationAuras.<tier>

Public fields (consumed by PlayerDataService, HatchGoo, InventoryService, EggCharacterRewards, ...):
  Order, Odds, Theme (optional, nil = "Halloween"), Roll, Model, AddAura.
]]
local ServerStorage = game:GetService("ServerStorage")

local Mutations = {}
Mutations.Order = { "Silver", "Gold", "Diamond", "Rainbow" } -- common -> rarest
Mutations.Odds = { Silver = 100, Gold = 500, Diamond = 2000, Rainbow = 5000 } -- 1 in N

local rng = Random.new()

function Mutations.Roll(luck)
    luck = math.max(1, luck or 1)
    for i = #Mutations.Order, 1, -1 do -- rarest first
        local tier = Mutations.Order[i]
        if rng:NextNumber() < luck / Mutations.Odds[tier] then
            return tier
        end
    end
    return nil
end

-- Finds the pack model for character `id` in mutation `tier` (themed pack first, then the normal pack).
local function findPackModel(id, tier)
    local baseModel = ServerStorage.BrainrotModels:FindFirstChild(id)
    local designName = baseModel and baseModel:GetAttribute("DesignName")
    if not designName then
        return nil
    end
    -- Halloween pack first (set Mutations.Theme = "" to go back to the normal pack)
    for _, theme in { Mutations.Theme or "Halloween", "" } do
        local pack =
            ServerStorage:FindFirstChild(theme ~= "" and ("UpdatePack_Mutations_" .. theme) or "UpdatePack_Mutations")
        local tierFolder = pack and pack:FindFirstChild("Characters_" .. tier)
        local found = tierFolder
            and tierFolder:FindFirstChild(
                designName .. (theme ~= "" and ("_" .. theme) or "") .. "_" .. tier .. "_Character",
                true
            )
        if found then
            return found
        end
    end
    return nil
end

-- returns a fresh clone ready to use, or nil (caller keeps base)
function Mutations.Model(id, tier, base)
    if not tier then
        return nil
    end
    local packModel = findPackModel(id, tier)
    local clone
    if packModel then
        clone = packModel:Clone()
        -- pack models ship with their own rarity FX; AddAura supplies the mutation aura instead
        for _, descendant in clone:GetDescendants() do
            if descendant.Name == "RarityFX" or descendant.Name == "Aura" or descendant.Name == "RarityAura" then
                descendant:Destroy()
            end
        end
        for attributeName, value in (base and base:GetAttributes() or {}) do
            clone:SetAttribute(attributeName, value)
        end
    elseif tier == "Gold" and base then
        clone = base:Clone()
        local gold = Color3.fromRGB(255, 196, 60)
        for _, descendant in clone:GetDescendants() do
            if descendant:IsA("SurfaceAppearance") then
                -- SurfaceAppearance.Color may not be writable on every engine version
                pcall(function()
                    descendant.Color = gold
                end)
            elseif descendant:IsA("BasePart") then
                descendant.Color = descendant.Color:Lerp(gold, 0.7)
                if descendant.Material ~= Enum.Material.Neon then
                    descendant.Material = Enum.Material.Metal
                end
                descendant.Reflectance = 0.15
            end
        end
    end
    if clone then
        clone:SetAttribute("Mutation", tier)
    end
    return clone
end

-- aura welded to the model's centre (works on anchored displays and on held tools)
function Mutations.AddAura(model, tier)
    if not tier then
        return
    end
    local auraTemplate = ServerStorage:FindFirstChild("MutationAuras")
        and ServerStorage.MutationAuras:FindFirstChild(tier)
    if not auraTemplate then
        return
    end
    local oldAura = model:FindFirstChild("RarityAura")
    if oldAura then
        oldAura:Destroy()
    end
    local boundsCFrame = model:GetBoundingBox()
    local aura = auraTemplate:Clone()
    aura.Name = "RarityAura"
    aura.CanCollide = false
    aura.CanQuery = false
    aura.CanTouch = false
    aura.Massless = true
    aura.Transparency = 1
    aura.CFrame = CFrame.new(boundsCFrame.Position)
    -- weld to the first part when the model is physically simulated (held tool); otherwise just anchor
    local anchorPart
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") then
            anchorPart = descendant
            break
        end
    end
    if anchorPart and not anchorPart.Anchored then
        aura.Anchored = false
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = anchorPart
        weld.Part1 = aura
        weld.Parent = aura
    else
        aura.Anchored = true
    end
    aura.Parent = model
end

return Mutations
