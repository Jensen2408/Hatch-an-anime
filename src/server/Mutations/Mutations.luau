-- Mutations: rolled on every hatch. Model swap + rarity aura + income multiplier (multiplier lives in RS.CharacterEconomy).
-- Models: ServerStorage.UpdatePack_Mutations (pack names via BrainrotModels.<id>.DesignName). Gold has no model in the pack: base model tinted gold.
-- Auras: ServerStorage.MutationAuras.<Tier>
local SS = game:GetService("ServerStorage")
local M = {}
M.Order = { "Silver", "Gold", "Diamond", "Rainbow" }
M.Odds = { Silver = 100, Gold = 500, Diamond = 2000, Rainbow = 5000 } -- 1 in N
local rng = Random.new()

function M.Roll(luck)
    luck = math.max(1, luck or 1)
    for i = #M.Order, 1, -1 do -- rarest first
        local tier = M.Order[i]
        if rng:NextNumber() < luck / M.Odds[tier] then
            return tier
        end
    end
    return nil
end

local function packModel(id, tier)
    local base = SS.BrainrotModels:FindFirstChild(id)
    local design = base and base:GetAttribute("DesignName")
    if not design then
        return nil
    end
    -- Halloween pack first (set M.Theme = "" to go back to the normal pack)
    for _, theme in { M.Theme or "Halloween", "" } do
        local pack = SS:FindFirstChild(theme ~= "" and ("UpdatePack_Mutations_" .. theme) or "UpdatePack_Mutations")
        local set = pack and pack:FindFirstChild("Characters_" .. tier)
        local found = set
            and set:FindFirstChild(
                design .. (theme ~= "" and ("_" .. theme) or "") .. "_" .. tier .. "_Character",
                true
            )
        if found then
            return found
        end
    end
    return nil
end

-- returns a fresh clone ready to use, or nil (caller keeps base)
function M.Model(id, tier, base)
    if not tier then
        return nil
    end
    local m = packModel(id, tier)
    local c
    if m then
        c = m:Clone()
        for _, d in c:GetDescendants() do
            if d.Name == "RarityFX" or d.Name == "Aura" or d.Name == "RarityAura" then
                d:Destroy()
            end
        end
        for k, v in (base and base:GetAttributes() or {}) do
            c:SetAttribute(k, v)
        end
    elseif tier == "Gold" and base then
        c = base:Clone()
        local gold = Color3.fromRGB(255, 196, 60)
        for _, p in c:GetDescendants() do
            if p:IsA("SurfaceAppearance") then
                pcall(function()
                    p.Color = gold
                end)
            elseif p:IsA("BasePart") then
                p.Color = p.Color:Lerp(gold, 0.7)
                if p.Material ~= Enum.Material.Neon then
                    p.Material = Enum.Material.Metal
                end
                p.Reflectance = 0.15
            end
        end
    end
    if c then
        c:SetAttribute("Mutation", tier)
    end
    return c
end

-- aura welded to the model's centre (works on anchored displays and on held tools)
function M.AddAura(model, tier)
    if not tier then
        return
    end
    local tmpl = SS:FindFirstChild("MutationAuras") and SS.MutationAuras:FindFirstChild(tier)
    if not tmpl then
        return
    end
    local old = model:FindFirstChild("RarityAura")
    if old then
        old:Destroy()
    end
    local cf = model:GetBoundingBox()
    local a = tmpl:Clone()
    a.Name = "RarityAura"
    a.CanCollide = false
    a.CanQuery = false
    a.CanTouch = false
    a.Massless = true
    a.Transparency = 1
    a.CFrame = CFrame.new(cf.Position)
    local anchor
    for _, p in model:GetDescendants() do
        if p:IsA("BasePart") then
            anchor = p
            break
        end
    end
    if anchor and not anchor.Anchored then
        a.Anchored = false
        local w = Instance.new("WeldConstraint")
        w.Part0 = anchor
        w.Part1 = a
        w.Parent = a
    else
        a.Anchored = true
    end
    a.Parent = model
end

return M
