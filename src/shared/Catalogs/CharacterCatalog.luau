--[[ ReplicatedStorage.CharacterCatalog  (ModuleScript, shared)
Static catalogue of every hatchable character: id, display name, asset (model) name, rarity, shop price,
rarity colour and menu image. Also owns the river spawn roll (BuildSpawnPool) and the legacy plain-text
"CharacterInfo" billboard.

  Catalog.Order      array of entries in catalogue order (15 regular + the Limited "Unknown")
  Catalog.ById[id]   the same entries keyed by Id
  Entry fields: Id, Name, AssetName, Order, Rarity, RarityRank, Price, Color, image (+ Limited on Unknown)
]]
local Catalog = {}

-- Display text only; model IDs and artwork keys retain their existing names.
-- Player-facing names (Adam, Oct 16): hint at the anime each one references.
local RENAME = {
    TideCaptain = "Straw Captain",
    MoonRunner = "Leaf Runner",
    SunForger = "Solar Warrior",
    SproutGuard = "Emerald Hero",
    LanternWarden = "Ember Slayer",
    DuskWeaver = "Infinity Sage",
    AshDuelist = "Soul Reaper",
    SkyScout = "Titan Shifter",
    RuneSmith = "Clover Knight",
}
Catalog.Rename = RENAME

-- Player-facing name for an asset/design name: an explicit RENAME wins, otherwise CamelCase is split
-- into words ("StarScholar" -> "Star Scholar").
function Catalog.DisplayName(name)
    if RENAME[tostring(name)] then
        return RENAME[tostring(name)]
    end
    return (tostring(name):gsub("(%l)(%u)", "%1 %2"):gsub("(%u)(%u%l)", "%1 %2"))
end

-- The arrays below are parallel (index i = one character) and every 3 consecutive characters share a
-- rarity tier. Order matters: it is the catalogue order, the tier grouping and the entry's Order field.
local CHARACTER_IDS = {
    "Pirate",
    "Shinobi",
    "Power",
    "Hero",
    "Slayer",
    "Curse",
    "Soul",
    "Titan",
    "Magic",
    "Academy",
    "Devil",
    "Guild",
    "Sports",
    "Mecha",
    "God",
}
local ASSET_NAMES = {
    "TideCaptain",
    "MoonRunner",
    "SunForger",
    "SproutGuard",
    "LanternWarden",
    "DuskWeaver",
    "AshDuelist",
    "SkyScout",
    "RuneSmith",
    "StarScholar",
    "CopperImp",
    "FrostNomad",
    "CometStriker",
    "PrismSentinel",
    "DawnOracle",
}
local PRICES = {
    0,
    750,
    3000,
    20000,
    40000,
    100000,
    400000,
    750000,
    2000000,
    12000000,
    35000000,
    100000000,
    600000000,
    1500000000,
    5000000000,
} -- economy v4 (Oct 15): ~1 min common → ~1 h legendary payback
local RARITY_NAMES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" } -- index = tier
local RARITY_COLORS = {
    Color3.fromRGB(190, 195, 205),
    Color3.fromRGB(109, 225, 132),
    Color3.fromRGB(98, 172, 255),
    Color3.fromRGB(197, 126, 255),
    Color3.fromRGB(255, 207, 92),
}

-- Percent chance per rarity, shared by all eggs within that rarity.
Catalog.SpawnChances = { Common = 70, Uncommon = 22, Rare = 6.5, Epic = 1.3, Legendary = 0.2 }

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

Catalog.Order = {}
Catalog.ById = {}

for i, id in ipairs(CHARACTER_IDS) do
    local tier = math.ceil(i / 3)
    local entry = {
        Id = id,
        Name = Catalog.DisplayName(ASSET_NAMES[i]),
        AssetName = ASSET_NAMES[i],
        Order = i,
        Rarity = RARITY_NAMES[tier],
        RarityRank = tier,
        Price = PRICES[i],
        Color = RARITY_COLORS[tier],
    }
    table.insert(Catalog.Order, entry)
    Catalog.ById[id] = entry
end
-- LIMITED: Unknown (from the 199 R$ Unknown Egg only; never spawns on the river)
do
    local unknownEntry = {
        Id = "Unknown",
        Name = "Unknown",
        Order = 16,
        Rarity = "Limited",
        RarityRank = 6,
        Price = 0,
        Color = Color3.fromRGB(255, 60, 90),
        Limited = true,
    }
    table.insert(Catalog.Order, unknownEntry)
    Catalog.ById.Unknown = unknownEntry
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

-- Menu portrait per asset name (stored as entry.image). Unknown has no AssetName and no image.
local MENU_IMAGES = {
    ["AshDuelist"] = "rbxassetid://86519861962600",
    ["CometStriker"] = "rbxassetid://96416272941728",
    ["CopperImp"] = "rbxassetid://112987882831167",
    ["DawnOracle"] = "rbxassetid://77906939709813",
    ["DuskWeaver"] = "rbxassetid://99801009246682",
    ["FrostNomad"] = "rbxassetid://119820320826727",
    ["LanternWarden"] = "rbxassetid://74677117609190",
    ["MoonRunner"] = "rbxassetid://126333199801308",
    ["PrismSentinel"] = "rbxassetid://87083032561086",
    ["RuneSmith"] = "rbxassetid://139172704925469",
    ["SkyScout"] = "rbxassetid://126336500094509",
    ["SproutGuard"] = "rbxassetid://76887827944280",
    ["StarScholar"] = "rbxassetid://81810975929521",
    ["SunForger"] = "rbxassetid://138059275161423",
    ["TideCaptain"] = "rbxassetid://126909405621214",
}
for _, entry in Catalog.Order do
    entry.image = MENU_IMAGES[entry.AssetName or entry.Name]
end
return Catalog
