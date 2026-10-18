--[[ ReplicatedStorage.CharacterEconomy  (ModuleScript, shared)
Power + income maths for every character. The server rolls Power (Roll) and stamps it onto the
character as attributes (Apply); everyone else reads it back (Read) and shows it (Format / Label).

  Attributes written by Apply: Power, PowerVersion, BasePower, RollQuality, BaseIncomePerSecond,
  IncomePerSecond, PowerRolled. Mutation (Silver/Gold/Diamond/Rainbow) multiplies income.
]]
local Economy = {}

-- Income per second at base Power, per character id (base Power = BaseIncome * 100).
Economy.BaseIncome = {
    Pirate = 5,
    Shinobi = 12,
    Power = 25,
    Hero = 60,
    Slayer = 125,
    Curse = 250,
    Soul = 600,
    Titan = 1200,
    Magic = 2500,
    Academy = 8000,
    Devil = 20000,
    Guild = 50000,
    Sports = 150000,
    Mecha = 400000,
    God = 1000000,
    Unknown = 10000000,
}
-- Saved as attribute PowerVersion. Power saved under version nil/1 used the old 1..100 scale (see Read).
Economy.Version = 3
-- Power ceiling is separate from cash. Existing valid Power values are retained.
Economy.MaxPower = 1e18
-- Multiplier on the chance of every non-Ordinary band: rarer characters roll big less often.
Economy.RarityLuck = {
    Pirate = 1,
    Shinobi = 1,
    Power = 1,
    Hero = 0.85,
    Slayer = 0.85,
    Curse = 0.85,
    Soul = 0.65,
    Titan = 0.65,
    Magic = 0.65,
    Academy = 0.45,
    Devil = 0.45,
    Guild = 0.45,
    Sports = 0.25,
    Mecha = 0.25,
    God = 0.25,
    Unknown = 0.25,
}
-- Roll-quality bands, lowest first. Weight = percent chance (band 1's weight is recomputed in RollWeights);
-- Min/Max = Power multiplier range over base Power. Order is a contract (ranks used by other modules).
Economy.Bands = {
    { Name = "Ordinary", Weight = 95, Min = 1, Max = 1.2, Color = Color3.fromRGB(218, 225, 239) },
    { Name = "Strong", Weight = 4.5, Min = 1.2, Max = 3, Color = Color3.fromRGB(125, 238, 183) },
    { Name = "Exceptional", Weight = 0.45, Min = 3, Max = 10, Color = Color3.fromRGB(112, 188, 255) },
    { Name = "Jackpot", Weight = 0.045, Min = 10, Max = 100, Color = Color3.fromRGB(206, 143, 255) },
    { Name = "Ultra", Weight = 0.0045, Min = 100, Max = 1000, Color = Color3.fromRGB(255, 213, 101) },
    { Name = "Cosmic", Weight = 0.0005, Min = 1000, Max = 1e12, Color = Color3.fromRGB(255, 153, 217) },
}

-- Per-band percent weights for this character: bands 2+ scaled by RarityLuck, band 1 takes the rest of 100.
function Economy.RollWeights(id)
    assert(Economy.BaseIncome[id], "Unknown character type")
    local luckFactor = Economy.RarityLuck[id] or 1
    local weights = {}
    local bonusWeight = 0
    for i = 2, #Economy.Bands do
        weights[i] = Economy.Bands[i].Weight * luckFactor
        bonusWeight += weights[i]
    end
    weights[1] = 100 - bonusWeight
    return weights
end

local defaultRandom = Random.new() -- used by Roll when no rng is passed

function Economy.BasePower(id)
    local baseIncome = Economy.BaseIncome[id]
    assert(baseIncome, "Unknown character type")
    return baseIncome * 100
end

function Economy.Income(id, power)
    assert(Economy.BaseIncome[id], "Unknown character type")
    assert(type(power) == "number" and power == power and power >= 1 and power <= Economy.MaxPower, "Invalid power")
    -- Universal power-to-income curve; higher Power always earns at least as much.
    -- Growth softens above 100M Power; giant rolls stay valuable without runaway income.
    local rate = (id == "Unknown" or power <= 100000000) and power / 100 or 1000000 * (power / 100000000) ^ 0.4 -- Limited Unknown skips the soft cap
    return math.max(1, math.floor(rate + 0.5))
end

-- Highest band whose Min multiplier the Power reaches (Ordinary if none).
function Economy.Quality(id, power)
    local ratio = power / Economy.BasePower(id)
    for i = #Economy.Bands, 1, -1 do
        if ratio >= Economy.Bands[i].Min then
            return Economy.Bands[i]
        end
    end
    return Economy.Bands[1]
end

-- Server roll: pick a band by weight, then a multiplier inside it. The multiplier is log-uniform with a
-- squared random, so results cluster toward the band's Min.
function Economy.Roll(id, rng)
    local basePower = Economy.BasePower(id)
    rng = rng or defaultRandom
    local weights = Economy.RollWeights(id)
    local roll = rng:NextNumber(0, 100)
    local cumulative = 0
    local chosen = Economy.Bands[1]
    for i, band in ipairs(Economy.Bands) do
        cumulative += weights[i]
        if roll < cumulative then
            chosen = band
            break
        end
    end
    local skew = rng:NextNumber() ^ 2
    local multiplier = chosen.Min * (chosen.Max / chosen.Min) ^ skew
    local power = math.clamp(math.floor(basePower * multiplier + 0.5), 1, Economy.MaxPower)
    return { Power = power, IncomePerSecond = Economy.Income(id, power), RollQuality = chosen.Name }
end

Economy.MutationMult = { Silver = 1.5, Gold = 2, Diamond = 3, Rainbow = 5 }
local function mutationMultiplier(object)
    local mutation = object and object:GetAttribute("Mutation")
    return (mutation and Economy.MutationMult[mutation]) or 1
end

-- Reads the stats stored on a character instance, or nil if its Power attribute is missing/invalid.
-- Legacy Power (PowerVersion nil or 1, values 1..100) is converted to the current scale on the fly.
function Economy.Read(object, id)
    local power = object and object:GetAttribute("Power")
    if type(power) == "number" and power == power and power >= 1 and power <= Economy.MaxPower and power % 1 == 0 then
        if
            (object:GetAttribute("PowerVersion") == nil or object:GetAttribute("PowerVersion") == 1)
            and power <= 100
        then
            power = math.floor(Economy.BasePower(id) * (0.5 + power * 0.05) + 0.5)
        end
        return {
            Power = power,
            IncomePerSecond = math.floor(Economy.Income(id, power) * mutationMultiplier(object) + 0.5),
            RollQuality = Economy.Quality(id, power).Name,
        }
    end
    return nil
end

-- Server only: stamps rolled stats onto the character as attributes (see header for the list).
function Economy.Apply(object, id, stats)
    assert(
        type(stats) == "table"
            and type(stats.Power) == "number"
            and stats.Power % 1 == 0
            and stats.Power >= 1
            and stats.Power <= Economy.MaxPower,
        "Invalid character power"
    )
    object:SetAttribute("Power", stats.Power)
    object:SetAttribute("PowerVersion", Economy.Version)
    object:SetAttribute("BasePower", Economy.BasePower(id))
    object:SetAttribute("RollQuality", Economy.Quality(id, stats.Power).Name)
    object:SetAttribute("BaseIncomePerSecond", Economy.BaseIncome[id])
    object:SetAttribute(
        "IncomePerSecond",
        math.floor(Economy.Income(id, stats.Power) * mutationMultiplier(object) + 0.5)
    )
    object:SetAttribute("PowerRolled", true)
end

-- Short number with up to 2 decimals: 1500 -> "1.5K", 2000000 -> "2M". A value that rounds to 1000 of a
-- unit is re-formatted with the next larger unit.
function Economy.Format(n)
    local units =
        { { 1000000000000000, "Qa" }, { 1000000000000, "T" }, { 1000000000, "B" }, { 1000000, "M" }, { 1000, "K" } }
    for i, unit in ipairs(units) do
        if n >= unit[1] then
            local value = math.floor(n / unit[1] * 100 + 0.5) / 100
            if value >= 1000 and i > 1 then
                return Economy.Format(math.floor(n / units[i - 1][1] * 100 + 0.5) / 100 * units[i - 1][1])
            end
            local text = string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
            return text .. unit[2]
        end
    end
    return tostring(math.floor(n + 0.5))
end

function Economy.Color(power, id)
    if id then
        return Economy.Quality(id, power).Color
    end
    return Color3.fromRGB(218, 225, 239)
end

-- Legacy plain-text "PowerInfo" billboard under a model (Power + income). preview = egg not hatched yet,
-- so it shows the base income instead of rolled stats. Replaces any previous one.
function Economy.Label(model, id, stats, preview)
    local existingLabel = model:FindFirstChild("PowerInfo")
    if existingLabel then
        existingLabel:Destroy()
    end
    local anchorPart = model:FindFirstChildWhichIsA("BasePart", true)
    if not anchorPart then
        return
    end
    local boxCFrame, boxSize = model:GetBoundingBox()
    local attachment = anchorPart:FindFirstChild("CharacterPowerAnchor") or Instance.new("Attachment")
    attachment.Name = "CharacterPowerAnchor"
    -- Just above the bottom of the model's bounding box.
    attachment.Position =
        anchorPart.CFrame:PointToObjectSpace(boxCFrame.Position - Vector3.new(0, boxSize.Y * 0.5 - 0.25, 0))
    attachment.Parent = anchorPart
    local gui = Instance.new("BillboardGui")
    gui.Name = "PowerInfo"
    gui.Adornee = attachment
    gui.Size = UDim2.fromOffset(210, 48)
    gui.MaxDistance = 65
    gui.AlwaysOnTop = true
    gui.LightInfluence = 0
    gui.Parent = model
    local function addLine(name, text, offsetY, color)
        local label = Instance.new("TextLabel")
        label.Name = name
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, 0, 0, 23)
        label.Position = UDim2.fromOffset(0, offsetY)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 15
        label.TextColor3 = color
        label.TextStrokeTransparency = 0.1
        label.TextStrokeColor3 = Color3.fromRGB(13, 16, 22)
        label.Text = text
        label.Parent = gui
        return label
    end
    addLine(
        "Power",
        preview and "POWER • RANDOM ON HATCH"
            or ("POWER " .. Economy.Format(stats.Power) .. " • " .. Economy.Quality(id, stats.Power).Name),
        0,
        preview and Color3.fromRGB(219, 226, 239) or Economy.Color(stats.Power, id)
    )
    addLine(
        "Income",
        (preview and "BASE $" .. Economy.Format(Economy.BaseIncome[id]) or "$" .. Economy.Format(stats.IncomePerSecond))
            .. "/sec",
        23,
        Color3.fromRGB(132, 241, 166)
    )
end
return Economy
