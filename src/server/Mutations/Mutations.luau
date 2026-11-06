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
    ServerStorage.BrainrotModels.<id>:GetAttribute("DesignName")). A character with no pack model (Gold,
    and every tier of the v2 roster) is the base model tinted with Mutations.Tint[tier] instead.
  * Auras:  ServerStorage.MutationAuras.<tier>

Public fields (consumed by PlayerDataService, HatchGoo, InventoryService, EggCharacterRewards, ...):
  Order, Odds, Theme (optional, nil = "Halloween"), Roll, Model, AddAura, Tint, Textures, RainbowTag.
  v2 characters: Model clones ServerStorage.V2MutationModels.<tier>.<V2Move>, built in edit mode by BuildModels from
  Textures (recoloured colour map, same normal map). Rainbow copies carry the tag RainbowTag and
  StarterPlayerScripts.RainbowMutationClient cycles their colour.
]]
local ServerStorage = game:GetService("ServerStorage")

local Mutations = {}
Mutations.Order = { "Silver", "Gold", "Diamond", "Rainbow" } -- common -> rarest
Mutations.Odds = { Silver = 100, Gold = 500, Diamond = 2000, Rainbow = 5000 } -- 1 in N
-- Texture tint for characters without a pack model (SurfaceAppearance.Color multiplies the colour map)
Mutations.Tint = {
    Silver = Color3.fromRGB(205, 215, 235),
    Gold = Color3.fromRGB(255, 196, 60),
    Diamond = Color3.fromRGB(140, 225, 255),
    Rainbow = Color3.fromRGB(255, 150, 230),
}

-- Recoloured colour maps per v2 character (key = the model's V2Move attribute), made from each character's own
-- atlas by ModelRecreation/V2PerCharacterAtlas/tools/mutation_textures.js (vault, 2026-11-05): luminance mapped onto
-- a silver / gold / icy-diamond ramp; Rainbow is a bright pearl map that RainbowMutationClient multiplies by a cycling
-- RGB colour (models tagged "RainbowMutation"). The normal map is left as it is. Characters missing here fall back
-- to Mutations.Tint.
Mutations.Textures = {
    Asta = { Silver = 118472631098441, Gold = 131470597517756, Diamond = 107023443392143, Rainbow = 115190295014940 },
    Asuka = { Silver = 89315342269236, Gold = 137920626065351, Diamond = 131126448441899, Rainbow = 127289084538624 },
    Bakugo = { Silver = 126255855970202, Gold = 92906716387167, Diamond = 70769943970588, Rainbow = 131623849956814 },
    Byakuya = { Silver = 93366201613078, Gold = 139754808949479, Diamond = 70395256515270, Rainbow = 123398753761016 },
    CosmicOracle = { Silver = 84585540227383, Gold = 126304797863262, Diamond = 76516416962037, Rainbow = 102225424422041 },
    Deku = { Silver = 132373553156865, Gold = 140105260210910, Diamond = 83838816381637, Rainbow = 71496500123727 },
    Denji = { Silver = 93685322879458, Gold = 95949200341847, Diamond = 90896693984039, Rainbow = 74139050498108 },
    Eren = { Silver = 97399121838811, Gold = 83995879813056, Diamond = 106616352997302, Rainbow = 130408171011682 },
    Erza = { Silver = 97690282004154, Gold = 107703613732759, Diamond = 102128791240776, Rainbow = 125387904487383 },
    Genos = { Silver = 123804745036841, Gold = 102927813168919, Diamond = 110996866549179, Rainbow = 137954963094562 },
    Gojo = { Silver = 79694592317417, Gold = 113299612427366, Diamond = 124212290580600, Rainbow = 131388819075770 },
    Goku = { Silver = 76252215252121, Gold = 126527048070561, Diamond = 105775324924717, Rainbow = 125157539112085 },
    HinataCourt = { Silver = 125098370235978, Gold = 115919018481624, Diamond = 110888984469680, Rainbow = 76366036855957 },
    HinataHyuga = { Silver = 107678785655008, Gold = 82267229175361, Diamond = 101482851763869, Rainbow = 130911112810402 },
    Ichigo = { Silver = 127944547964116, Gold = 136113411642208, Diamond = 85956122753058, Rainbow = 102588141795865 },
    Isagi = { Silver = 78414980285938, Gold = 108163954325778, Diamond = 94785351906147, Rainbow = 110547626978086 },
    Itadori = { Silver = 91400019206945, Gold = 106827026325821, Diamond = 86469546388536, Rainbow = 121770783471318 },
    Kakashi = { Silver = 129013179058677, Gold = 111873002269465, Diamond = 110949168328835, Rainbow = 100498686109113 },
    Kuroko = { Silver = 130544693248670, Gold = 140188967072598, Diamond = 136468213724124, Rainbow = 119547230350391 },
    Lelouch = { Silver = 78731191230260, Gold = 95759905572920, Diamond = 115784391892904, Rainbow = 79829420968811 },
    Levi = { Silver = 81517005870523, Gold = 111210638799504, Diamond = 79130500008746, Rainbow = 100840910174661 },
    Lucy = { Silver = 91419084213573, Gold = 99081979981334, Diamond = 111763180781357, Rainbow = 71958922203071 },
    Luffy = { Silver = 92400702124618, Gold = 139667400091304, Diamond = 140323685093897, Rainbow = 114764736913623 },
    Makima = { Silver = 132361976373537, Gold = 116298644533717, Diamond = 79731263695416, Rainbow = 103805426890369 },
    Mikasa = { Silver = 120054083963656, Gold = 137073763860970, Diamond = 76534594677830, Rainbow = 72394108702431 },
    MoonGoddess = { Silver = 100458307729723, Gold = 108937465656119, Diamond = 79951317247847, Rainbow = 136570269215694 },
    Nami = { Silver = 124054389489621, Gold = 119489452511912, Diamond = 100833367746615, Rainbow = 89622600535164 },
    Naruto = { Silver = 135262168394414, Gold = 140024399668688, Diamond = 121940665698038, Rainbow = 97479769194746 },
    Natsu = { Silver = 88776154502836, Gold = 113989159195412, Diamond = 134317488783179, Rainbow = 107413813789214 },
    Nezuko = { Silver = 136935946457251, Gold = 104225986902254, Diamond = 101623440004456, Rainbow = 137262079377929 },
    Noelle = { Silver = 113210502749968, Gold = 110916611811284, Diamond = 110986525715927, Rainbow = 111618842392273 },
    Piccolo = { Silver = 76565396997487, Gold = 96322624654201, Diamond = 100546210242989, Rainbow = 103938338489682 },
    Power = { Silver = 140243058218427, Gold = 97658942211001, Diamond = 105835626514975, Rainbow = 109832076998217 },
    Rukia = { Silver = 78904069129673, Gold = 101821297896739, Diamond = 87344275708851, Rainbow = 89890737968445 },
    Saitama = { Silver = 97632459976455, Gold = 84905184251904, Diamond = 94130077789615, Rainbow = 131308006722081 },
    Sasuke = { Silver = 72916530595743, Gold = 133719794714042, Diamond = 122627688740589, Rainbow = 102112663766638 },
    Shinji = { Silver = 82659373081448, Gold = 99173563233364, Diamond = 107402234611466, Rainbow = 138073500891807 },
    Sukuna = { Silver = 95431126703604, Gold = 136142257390236, Diamond = 73767998697875, Rainbow = 140415304799067 },
    SunGod = { Silver = 110295388565268, Gold = 100729248587191, Diamond = 91884307118458, Rainbow = 135620536567615 },
    Tanjiro = { Silver = 79059341071677, Gold = 103553891688427, Diamond = 84694376941953, Rainbow = 120815632059310 },
    Tatsumaki = { Silver = 95677836546409, Gold = 112667751216483, Diamond = 93185036511834, Rainbow = 97122516506001 },
    Todoroki = { Silver = 113023002128388, Gold = 128607735363118, Diamond = 100936317012699, Rainbow = 137123927816405 },
    Vegeta = { Silver = 92668434614682, Gold = 124978340119967, Diamond = 74618591769141, Rainbow = 118959974158484 },
    Yuno = { Silver = 131595370720088, Gold = 98751360963780, Diamond = 131975295756948, Rainbow = 111115652952210 },
    Zenitsu = { Silver = 136607727504173, Gold = 110492389568194, Diamond = 91991920463715, Rainbow = 113952152930812 },
    Zoro = { Silver = 73265779154979, Gold = 85963045781033, Diamond = 76309674239826, Rainbow = 135395598069562 },
}
Mutations.RainbowTag = "RainbowMutation"

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

-- Pre-built v2 mutation model: ServerStorage.V2MutationModels.<tier>.<V2Move> (see Mutations.BuildModels)
local function v2MutationModel(base, tier)
    local folder = ServerStorage:FindFirstChild("V2MutationModels")
    local tierFolder = folder and folder:FindFirstChild(tier)
    local move = base:GetAttribute("V2Move")
    return tierFolder and move and tierFolder:FindFirstChild(move)
end

-- Studio edit mode only (command bar): rebuilds ServerStorage.V2MutationModels from BrainrotModels + Textures.
-- Run it again after a character model changes:  require(game.ServerScriptService.Mutations).BuildModels()
-- Game scripts cannot write SurfaceAppearance maps, which is why these copies are made ahead of time.
function Mutations.BuildModels()
    local old = ServerStorage:FindFirstChild("V2MutationModels")
    if old then
        old:Destroy()
    end
    local root = Instance.new("Folder")
    root.Name = "V2MutationModels"
    local count = 0
    for _, tier in Mutations.Order do
        local tierFolder = Instance.new("Folder")
        tierFolder.Name = tier
        tierFolder.Parent = root
        for _, base in ServerStorage.BrainrotModels:GetChildren() do
            local ids = Mutations.Textures[base:GetAttribute("V2Move") or ""]
            if ids and ids[tier] then
                local copy = base:Clone()
                copy.Name = base:GetAttribute("V2Move")
                for _, descendant in copy:GetDescendants() do
                    if descendant:IsA("SurfaceAppearance") then
                        descendant.ColorMapContent = Content.fromUri("rbxassetid://" .. ids[tier])
                        descendant.Color = Color3.new(1, 1, 1)
                        descendant.RoughnessMap = "rbxassetid://103649681765181"
                        descendant.MetalnessMap = "rbxassetid://77962326736178"
                        if tier == "Rainbow" then
                            descendant.RoughnessMap = "rbxassetid://112433471951633"
                            descendant.MetalnessMap = "rbxassetid://85958816211554"
                            descendant.EmissiveMaskContent = Content.fromUri("rbxassetid://77962326736178")
                            descendant.EmissiveStrength = 0.35
                        elseif tier == "Silver" then
                            descendant.RoughnessMap = "rbxassetid://95277488348789"
                            descendant.MetalnessMap = "rbxassetid://103782747534661"
                        elseif tier == "Gold" then descendant.RoughnessMap = "rbxassetid://95277488348789"
                        elseif tier == "Diamond" then
                            descendant.RoughnessMap = "rbxassetid://112433471951633"
                            descendant.MetalnessMap = "rbxassetid://85958816211554"
                            descendant.Color = Color3.fromRGB(215, 240, 255)
                        end
                    end
                end
                if tier == "Rainbow" then
                    copy:AddTag(Mutations.RainbowTag)
                end
                copy:SetAttribute("Mutation", tier)
                copy.Parent = tierFolder
                count += 1
            end
        end
    end
    root.Parent = ServerStorage
    return count
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
    elseif base and v2MutationModel(base, tier) then
        -- v2 character: its pre-built recoloured copy (game scripts can't write SurfaceAppearance maps)
        clone = v2MutationModel(base, tier):Clone()
        for attributeName, value in base:GetAttributes() do
            clone:SetAttribute(attributeName, value)
        end
    elseif Mutations.Tint[tier] and base then
        -- no pack model and no recoloured map: tint the base model's textures in the mutation colour
        clone = base:Clone()
        local tint = Mutations.Tint[tier]
        for _, descendant in clone:GetDescendants() do
            if descendant:IsA("SurfaceAppearance") then
                -- SurfaceAppearance.Color may not be writable on every engine version
                pcall(function()
                    descendant.Color = tint
                end)
            elseif descendant:IsA("BasePart") then
                descendant.Color = descendant.Color:Lerp(tint, 0.7)
                if tier == "Gold" and descendant.Material ~= Enum.Material.Neon then
                    descendant.Material = Enum.Material.Metal
                    descendant.Reflectance = 0.15
                end
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
