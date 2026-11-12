--[[ ServerScriptService.Mutations (ModuleScript, server only)
Rolled on every hatch. A mutation is a tier name ("Silver" | "Gold" | "Diamond" | "Rainbow" | "Molten") or nil (no mutation).

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
Mutations.Order = { "Silver", "Gold", "Diamond", "Rainbow", "Molten" } -- common -> rarest
Mutations.Odds = { Silver = 100, Gold = 500, Diamond = 2000, Rainbow = 5000, Molten = 10000 } -- 1 in N
-- Texture tint for characters without a pack model (SurfaceAppearance.Color multiplies the colour map)
Mutations.Tint = {
    Silver = Color3.fromRGB(205, 215, 235),
    Gold = Color3.fromRGB(255, 196, 60),
    Diamond = Color3.fromRGB(140, 225, 255),
    Rainbow = Color3.fromRGB(255, 150, 230),
    Molten = Color3.fromRGB(87, 61, 55),
}

-- Recoloured colour maps per v2 character (key = the model's V2Move attribute), made from each character's own
-- atlas by ModelRecreation/V2PerCharacterAtlas/tools/mutation_textures.js (vault, 2026-11-05): luminance mapped onto
-- a silver / gold / icy-diamond ramp; Rainbow is a bright pearl map that RainbowMutationClient multiplies by a cycling
-- RGB colour (models tagged "RainbowMutation"). The normal map is left as it is. Characters missing here fall back
-- to Mutations.Tint.
Mutations.Textures = {
    Asta = { Silver = 80618303946533, Gold = 129409575417294, Diamond = 98518544903959, Rainbow = 121545275589673 },
    Asuka = { Silver = 88622255906351, Gold = 77653850112648, Diamond = 115435673147627, Rainbow = 132131501528605 },
    Bakugo = { Silver = 98145408082497, Gold = 90095912620894, Diamond = 118883558201934, Rainbow = 72014898373337 },
    Byakuya = { Silver = 87433926275992, Gold = 107682502301111, Diamond = 70451439017789, Rainbow = 88638875782628 },
    CosmicOracle = { Silver = 130700262595061, Gold = 110408845643611, Diamond = 97947368727197, Rainbow = 127571999280654 },
    Deku = { Silver = 113049056539287, Gold = 137992019558719, Diamond = 106288625071426, Rainbow = 127446582342636 },
    Denji = { Silver = 127937283650398, Gold = 130845701740912, Diamond = 84749233733036, Rainbow = 98862906884739 },
    Eren = { Silver = 71639056450800, Gold = 101077552518472, Diamond = 126740537089305, Rainbow = 134798023266037 },
    Erza = { Silver = 94158934047120, Gold = 77507352318474, Diamond = 119495861223718, Rainbow = 94613786066948 },
    Genos = { Silver = 118038473801535, Gold = 74691496565469, Diamond = 116072636272333, Rainbow = 120996080347548 },
    Gojo = { Silver = 115642479443721, Gold = 70515956797625, Diamond = 105750389380238, Rainbow = 139097454221719 },
    Goku = { Silver = 109249824538871, Gold = 134497604851070, Diamond = 84407621549495, Rainbow = 82338372648192 },
    HinataCourt = { Silver = 130019106320917, Gold = 90635264119968, Diamond = 126812125599009, Rainbow = 87830978578009 },
    HinataHyuga = { Silver = 122262514063871, Gold = 137562053111902, Diamond = 81850002626525, Rainbow = 102385981795956 },
    Ichigo = { Silver = 117176946269367, Gold = 100413110369043, Diamond = 79664583317470, Rainbow = 133688163026377 },
    Isagi = { Silver = 93260888034474, Gold = 135991864853894, Diamond = 113021225535733, Rainbow = 133282689225979 },
    Itadori = { Silver = 116366245910198, Gold = 70384401630467, Diamond = 97174625556657, Rainbow = 85649377916568 },
    Kakashi = { Silver = 139145568369058, Gold = 111253473585549, Diamond = 77756764842246, Rainbow = 99008644796357 },
    Kuroko = { Silver = 75781497126819, Gold = 127918714083133, Diamond = 79591573359864, Rainbow = 88208503235111 },
    Lelouch = { Silver = 112347718707331, Gold = 125094025604888, Diamond = 95138093560774, Rainbow = 76123272628304 },
    Levi = { Silver = 83776740613353, Gold = 76188647382418, Diamond = 122616316475564, Rainbow = 98475780452116 },
    Lucy = { Silver = 101802397944055, Gold = 101366329630421, Diamond = 90699648043377, Rainbow = 99484116255681 },
    Luffy = { Silver = 101445605824651, Gold = 137423609162119, Diamond = 75783734337665, Rainbow = 120901306602173 },
    Makima = { Silver = 108130084473451, Gold = 140481186007116, Diamond = 106020323326727, Rainbow = 126156578680823 },
    Mikasa = { Silver = 118486326579451, Gold = 94879022877733, Diamond = 119662038724779, Rainbow = 133406185283006 },
    MoonGoddess = { Silver = 83879832362675, Gold = 83061378728827, Diamond = 91633112462190, Rainbow = 87648676758167 },
    Nami = { Silver = 72545573034148, Gold = 109118496512068, Diamond = 95940499688786, Rainbow = 97706485183010 },
    Naruto = { Silver = 108721108950225, Gold = 112972540108931, Diamond = 110245959761838, Rainbow = 86801154764017 },
    Natsu = { Silver = 119138330878682, Gold = 76421404621621, Diamond = 139887962214985, Rainbow = 96174930910306 },
    Nezuko = { Silver = 75965650107402, Gold = 128817650772267, Diamond = 120504103300237, Rainbow = 112116827140401 },
    Noelle = { Silver = 131157949823149, Gold = 102786072412129, Diamond = 112040783865831, Rainbow = 99122046378593 },
    Piccolo = { Silver = 98901050490859, Gold = 138523453762541, Diamond = 132409587196085, Rainbow = 87022004169873 },
    Power = { Silver = 97812926974550, Gold = 116016697150590, Diamond = 100003179543798, Rainbow = 138234984470746 },
    Rukia = { Silver = 107493253317695, Gold = 76556354580004, Diamond = 106737021324477, Rainbow = 115742684981775 },
    Saitama = { Silver = 101092872704368, Gold = 127101224135838, Diamond = 81290226525878, Rainbow = 138222943435474 },
    Sasuke = { Silver = 93717223010098, Gold = 77600045148250, Diamond = 135558629038809, Rainbow = 98507715434049 },
    Shinji = { Silver = 74406210700630, Gold = 120676428603478, Diamond = 140699768408578, Rainbow = 83356141055556 },
    Sukuna = { Silver = 87389598003891, Gold = 127233143355746, Diamond = 130325051125856, Rainbow = 140275021279482 },
    SunGod = { Silver = 133836032949312, Gold = 93821751426762, Diamond = 76798930483121, Rainbow = 136102942872796 },
    Tanjiro = { Silver = 83392903628166, Gold = 80440561102949, Diamond = 78733131288976, Rainbow = 80917671991823 },
    Tatsumaki = { Silver = 114614527598250, Gold = 89637763244717, Diamond = 83682756099242, Rainbow = 100547709842265 },
    Todoroki = { Silver = 125328087778698, Gold = 136329384815272, Diamond = 111118610733365, Rainbow = 78853280441803 },
    Vegeta = { Silver = 134069232811987, Gold = 108846212038263, Diamond = 110931829755698, Rainbow = 93036836839791 },
    Yuno = { Silver = 105588344230912, Gold = 98981548229014, Diamond = 71798650338575, Rainbow = 83454127844862 },
    Zenitsu = { Silver = 87362260536077, Gold = 105913672995210, Diamond = 81386481022895, Rainbow = 86405626269091 },
    Zoro = { Silver = 77356376238748, Gold = 72667401733162, Diamond = 90358548241826, Rainbow = 122673521546761 },
}
Mutations.RainbowTag = "RainbowMutation"

local rng = Random.new()
local MOLTEN_VOLCANO_ODDS = 1000

function Mutations.Roll(luck)
    luck = math.max(1, luck or 1)
    for i = #Mutations.Order, 1, -1 do -- rarest first
        local tier = Mutations.Order[i]
        local odds = Mutations.Odds[tier]
        if tier == "Molten" and typeof(workspace:GetAttribute("VolcanoStart")) == "number" then
            odds = MOLTEN_VOLCANO_ODDS
        end
        if rng:NextNumber() < luck / odds then
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

-- Probe the underlying image URIs. ContentProvider does not preload a SurfaceAppearance itself.
local ContentProvider = game:GetService("ContentProvider")
local mapChecks = {}
-- 2026-11-08: the server cannot preload images (PreloadAsync never finishes there), so the 8 s timeout below marked
-- every map as failed and turned every mutated character into a flat-coloured silhouette. The check only runs where
-- images can actually be loaded; on the server the textures are kept.
local CAN_PRELOAD = not game:GetService("RunService"):IsServer()
local function checkMutationMaps(appearance, part, tint)
    if not CAN_PRELOAD then
        return
    end
    local function useFallback()
        if appearance.Parent == part then
            appearance:Destroy()
            part.TextureID = ""
            part.Material = Enum.Material.SmoothPlastic
            part.MaterialVariant = ""
            part.Color = tint
        end
    end
    for _, content in {
        appearance.ColorMapContent,
        appearance.NormalMapContent,
        appearance.RoughnessMapContent,
        appearance.MetalnessMapContent,
    } do
        local uri = content.Uri
        if not uri or uri == "" then
            continue
        end
        local check = mapChecks[uri]
        if check ~= true then
            if not check then
                check = setmetatable({}, { __mode = "k" })
                mapChecks[uri] = check
                local function finish(success)
                    if mapChecks[uri] ~= check then
                        return
                    end
                    -- Retry transient failures for subsequent models.
                    mapChecks[uri] = success or nil
                    if not success then
                        for _, fallback in check do
                            fallback()
                        end
                    end
                end
                task.delay(8, finish, false)
                task.defer(function()
                    local probe = Instance.new("Decal")
                    probe.ColorMapContent = Content.fromUri(uri)
                    local loaded = false
                    local ok = pcall(function()
                        ContentProvider:PreloadAsync({ probe }, function(_, status)
                            loaded = status == Enum.AssetFetchStatus.Success
                        end)
                    end)
                    probe:Destroy()
                    finish(ok and loaded)
                end)
            end
            check[appearance] = useFallback
        end
    end
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
        local tint = Mutations.Tint[tier]
        if tint then
            for _, appearance in clone:GetDescendants() do
                local part = appearance.Parent
                if appearance:IsA("SurfaceAppearance") and part:IsA("MeshPart") then
                    checkMutationMaps(appearance, part, tint)
                end
            end
        end
    end
    return clone
end

local function createMoltenAura(size)
    local aura = Instance.new("Part")
    aura.Size = Vector3.new(math.max(size.X * .66, .2), math.max(size.Y * .7, .2), math.max(size.Z * .66, .2))
    local flames = Instance.new("ParticleEmitter")
    flames.Name = "MoltenFlames"
    flames.Texture = "rbxasset://textures/particles/fire_main.dds"
    flames.Color = ColorSequence.new(Color3.fromRGB(255, 215, 92), Color3.fromRGB(244, 53, 10))
    flames.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, .45),
        NumberSequenceKeypoint.new(.3, .9),
        NumberSequenceKeypoint.new(1, .15),
    })
    flames.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, .3),
        NumberSequenceKeypoint.new(.55, .42),
        NumberSequenceKeypoint.new(1, 1),
    })
    flames.Lifetime = NumberRange.new(.4, .8)
    flames.Speed = NumberRange.new(1.3, 3.5)
    flames.Acceleration = Vector3.new(0, 5, 0)
    flames.SpreadAngle = Vector2.new(22, 22)
    flames.LightEmission = .75
    flames.Rate = 14
    flames.LightInfluence = 0
    flames.ZOffset = .2

    local embers = flames:Clone()
    embers.Name = "MoltenEmbers"
    embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    embers.Size = NumberSequence.new(.24, .05)
    embers.Lifetime = NumberRange.new(.6, 1.4)
    embers.Speed = NumberRange.new(2, 5)
    embers.Rate = 11
    for _, side in { -1, 1 } do
        local vent = Instance.new("Attachment")
        vent.Name = "MoltenVent"
        vent.Position = Vector3.new(size.X * .48 * side, -size.Y * .08, 0)
        vent.Parent = aura
        flames:Clone().Parent = vent
        embers:Clone().Parent = vent
    end
    flames:Destroy()
    embers:Destroy()

    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 104, 29)
    light.Brightness = .65
    light.Range = 8
    light.Parent = aura
    return aura
end

-- aura welded to the model's centre (works on anchored displays and on held tools)
function Mutations.AddAura(model, tier)
    if not tier then
        return
    end
    local auraTemplate = ServerStorage:FindFirstChild("MutationAuras")
        and ServerStorage.MutationAuras:FindFirstChild(tier)
    if not auraTemplate and tier ~= "Molten" then
        return
    end
    local oldAura = model:FindFirstChild("RarityAura")
    if oldAura then
        oldAura:Destroy()
    end
    local boundsCFrame, boundsSize = model:GetBoundingBox()
    local aura = auraTemplate and auraTemplate:Clone() or createMoltenAura(boundsSize)
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
