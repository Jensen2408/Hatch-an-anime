--[[ ReplicatedStorage.CharacterCatalog  (ModuleScript, shared)
Static catalogue of every egg and hatchable character, built from ReplicatedStorage.EggDropConfig (rarity colour and
rank are added here). Also owns the river spawn roll (BuildSpawnPool), the hatch roll (RollCharacter) and the legacy
plain-text "CharacterInfo" billboard.

  Catalog.Eggs        array of egg entries (15 river eggs + the Limited "Unknown")
  Catalog.Characters  array of character entries, egg by egg
  Catalog.EggById[id] / Catalog.CharacterById[id]
  Catalog.ById[id]    either of them: egg and character ids never clash
  Catalog.LegacyCharacters[oldId]  characters used to share their egg's id: that id -> the egg's main character
  Egg fields: Id, Name, Order, Rarity, RarityRank, Price, Color, Limited?, Characters
  Character fields: Id, Name, Order, Rarity, RarityRank, Price (its egg's), Color, Limited?, Egg, Chance, Move, image?
]]
local DropConfig = require(script.Parent:WaitForChild("EggDropConfig"))

local Catalog = {}

-- Player-facing name for an id / design name: CamelCase is split into words ("StarScholar" -> "Star Scholar").
function Catalog.DisplayName(name)
    return (tostring(name):gsub("(%l)(%u)", "%1 %2"):gsub("(%u)(%u%l)", "%1 %2"))
end

local RARITY_RANKS = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Limited = 6 }
local RARITY_COLORS = {
    Common = Color3.fromRGB(190, 195, 205),
    Uncommon = Color3.fromRGB(109, 225, 132),
    Rare = Color3.fromRGB(98, 172, 255),
    Epic = Color3.fromRGB(197, 126, 255),
    Legendary = Color3.fromRGB(255, 207, 92),
    Limited = Color3.fromRGB(255, 60, 90),
}

-- Percent chance per rarity, shared by all eggs within that rarity.
Catalog.SpawnChances = { Common = 70, Uncommon = 22, Rare = 6.5, Epic = 1.3, Legendary = 0.5 }

-- Builds the river spawn roll from egg templates. Two-step roll: pick a rarity bucket by its
-- SpawnChances weight (only rarities with at least one released template take part), then a uniformly
-- random template inside it. Templates with attribute ReleaseEnabled == false are skipped.
-- Returns roll(random: Random) -> template.
function Catalog.BuildSpawnPool(templates)
    local buckets = {}
    for _, template in ipairs(templates) do
        local entry = Catalog.ById[template.Name]
        if entry and template:GetAttribute("ReleaseEnabled") ~= false then
            local bucket = buckets[entry.Rarity] or {}
            buckets[entry.Rarity] = bucket
            table.insert(bucket, template)
        end
    end
    local pool = {}
    local totalWeight = 0
    for _, rarity in ipairs({ "Common", "Uncommon", "Rare", "Epic", "Legendary" }) do
        local bucket = buckets[rarity]
        local weight = Catalog.SpawnChances[rarity] or 0
        if bucket and #bucket > 0 and weight > 0 then
            totalWeight += weight
            table.insert(pool, { Items = bucket, Weight = weight })
        end
    end
    assert(totalWeight > 0, "No released eggs have a configured spawn rarity")
    return function(random)
        local roll = random:NextNumber(0, totalWeight)
        local cumulative = 0
        for _, bucket in ipairs(pool) do
            cumulative += bucket.Weight
            if roll < cumulative then
                return bucket.Items[random:NextInteger(1, #bucket.Items)]
            end
        end
        -- Floating-point fallthrough (roll == totalWeight): use the last bucket.
        local items = pool[#pool].Items
        return items[random:NextInteger(1, #items)]
    end
end

Catalog.Eggs = {}
Catalog.Characters = {}
Catalog.EggById = {}
Catalog.CharacterById = {}
Catalog.ById = {}
Catalog.LegacyCharacters = {}

for eggOrder, egg in DropConfig.Eggs do
    local eggEntry = {
        Id = egg.Id,
        Name = egg.Id .. " Egg",
        Order = eggOrder,
        Rarity = egg.Rarity,
        RarityRank = RARITY_RANKS[egg.Rarity],
        Price = egg.Price,
        Color = RARITY_COLORS[egg.Rarity],
        Limited = egg.Limited,
        Characters = egg.Characters,
    }
    table.insert(Catalog.Eggs, eggEntry)
    Catalog.EggById[egg.Id] = eggEntry
    Catalog.ById[egg.Id] = eggEntry
    Catalog.LegacyCharacters[egg.Id] = egg.Characters[1].Id
    for _, character in egg.Characters do
        local entry = {
            Id = character.Id,
            Name = character.Name,
            Order = #Catalog.Characters + 1,
            Rarity = egg.Rarity,
            RarityRank = RARITY_RANKS[egg.Rarity],
            Price = egg.Price,
            Color = RARITY_COLORS[egg.Rarity],
            Limited = egg.Limited,
            Egg = egg.Id,
            EggType = egg.Id,
            Chance = character.Chance,
            Weight = character.Chance,
            Move = character.Move,
        }
        table.insert(Catalog.Characters, entry)
        Catalog.CharacterById[character.Id] = entry
        Catalog.ById[character.Id] = entry
    end
end
Catalog.Order = Catalog.Characters

function Catalog.CharacterId(id)
    return (Catalog.CharacterById[id] and id) or Catalog.LegacyCharacters[id]
end

function Catalog.EggOf(id)
    local char = Catalog.CharacterById[id]
    if char then
        return char.Egg
    end
    return Catalog.EggById[id] and id or nil
end

-- Picks the character an egg hatches, by each character's Chance. nil for an id that isn't an egg.
local defaultRandom = Random.new()
function Catalog.RollCharacter(eggId, random)
    local egg = Catalog.EggById[eggId]
    if not egg then
        return nil
    end
    local roll = (random or defaultRandom):NextNumber(0, 100)
    for _, character in egg.Characters do
        roll -= character.Chance
        if roll < 0 then
            return character.Id
        end
    end
    return egg.Characters[1].Id
end

-- 1234567 -> "$1,234,567"; 0 -> "FREE".
function Catalog.FormatPrice(amount)
    if amount == 0 then
        return "FREE"
    end
    local digits = tostring(amount)
    local result = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return "$" .. result
end

-- Copies the catalogue stats onto an instance as attributes.
function Catalog.Stamp(object, entry)
    for _, key in ipairs({ "Rarity", "RarityRank", "Price", "Order" }) do
        object:SetAttribute(key, entry[key])
    end
    object:SetAttribute("DesignName", entry.Name)
end

-- Legacy plain-text billboard (name / rarity / price) above a model; replaces any previous one.
-- The CharacterInfo UI hides it locally on clients (CharacterInfo.Adapter.OldLabels).
function Catalog.Label(model, entry)
    local existingLabel = model:FindFirstChild("CharacterInfo")
    if existingLabel then
        existingLabel:Destroy()
    end
    local anchorPart = model:FindFirstChildWhichIsA("BasePart", true)
    if not anchorPart then
        return
    end
    local boxCFrame, boxSize = model:GetBoundingBox()
    local gui = Instance.new("BillboardGui")
    gui.Name = "CharacterInfo"
    gui.Adornee = anchorPart
    gui.Size = UDim2.fromOffset(210, 72)
    gui.MaxDistance = 75
    gui.AlwaysOnTop = false
    -- Offset from the adornee part to just above the top of the model's bounding box.
    gui.StudsOffsetWorldSpace = boxCFrame.Position + Vector3.new(0, boxSize.Y / 2 + 0.7, 0) - anchorPart.Position
    gui.Parent = model
    local function addLine(text, offsetY, color, fontSize)
        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, 0, 0, 24)
        label.Position = UDim2.fromOffset(0, offsetY)
        label.Text = text
        label.TextColor3 = color
        label.Font = Enum.Font.GothamBold
        label.TextSize = fontSize
        label.TextStrokeColor3 = Color3.fromRGB(15, 17, 22)
        label.TextStrokeTransparency = 0.15
        label.Parent = gui
    end
    addLine(entry.Name, 0, Color3.fromRGB(245, 245, 250), 17)
    addLine(entry.Rarity, 24, entry.Color, 16)
    addLine(Catalog.FormatPrice(entry.Price), 48, Color3.fromRGB(255, 223, 143), 16)
end

return Catalog
