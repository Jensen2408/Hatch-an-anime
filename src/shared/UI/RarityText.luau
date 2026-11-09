--[[ ReplicatedStorage.RarityText (ModuleScript, client) - 2026-11-09
Floating world text with no plate behind it: the letters themselves carry a moving colour flow per rarity
(Mythic = magma, Cosmic = galaxy, Legendary = gold ...) or per mutation (Rainbow, Molten, Diamond ...),
and the top tiers throw a few small embers up past the word.
  RarityText.Apply(label, theme, sparks?)  theme = rarity or mutation name; nil / unknown = plain text again
Server-built labels opt in with the CollectionService tag "RarityText" + attributes RarityTheme, RaritySparks.
One Heartbeat loop builds one ColorSequence per theme and hands it to every label of that theme.
Reduced motion keeps the colours and stops the movement. Used by EggLabel, CharacterInfo.Style, HeldEggLabel. ]]
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local CollectionService = game:GetService("CollectionService")

local RarityText = {}
local function c(r, g, b)
    return Color3.fromRGB(r, g, b)
end
-- colors: a loop of colours that drags across the letters. speed = loops per second, span = how much of the
-- loop is on the word at once, rot = gradient angle, spin = degrees per second (galaxy / rainbow turn).
RarityText.Themes = {
    Common = { colors = { c(255, 255, 255), c(176, 188, 206), c(255, 255, 255), c(140, 152, 172) }, speed = 0.22, span = 0.7, rot = 20 },
    Uncommon = { colors = { c(190, 255, 80), c(20, 225, 70), c(245, 255, 140), c(0, 200, 110) }, speed = 0.28, span = 0.7, rot = 20 },
    Rare = { colors = { c(80, 225, 255), c(20, 120, 255), c(215, 250, 255), c(0, 95, 235) }, speed = 0.3, span = 0.7, rot = 20 },
    Epic = { colors = { c(215, 90, 255), c(255, 110, 235), c(150, 60, 255), c(255, 215, 255) }, speed = 0.32, span = 0.7, rot = 20 },
    Legendary = { colors = { c(255, 232, 50), c(255, 150, 0), c(255, 255, 215), c(255, 190, 10) }, speed = 0.36, span = 0.75, rot = 25, sparks = true },
    Mythic = { colors = { c(255, 50, 20), c(255, 150, 0), c(255, 244, 100), c(255, 95, 0), c(200, 10, 10) }, speed = 0.42, span = 0.8, rot = 60, sparks = true },
    Cosmic = { colors = { c(70, 255, 230), c(60, 130, 255), c(195, 90, 255), c(255, 100, 215), c(130, 255, 255) }, speed = 0.3, span = 0.9, rot = 0, spin = 45, sparks = true },
    Secret = { colors = { c(255, 255, 255), c(255, 25, 55), c(255, 110, 130), c(215, 0, 45) }, speed = 0.5, span = 0.8, rot = 20, sparks = true },
    -- mutations
    Silver = { colors = { c(255, 255, 255), c(170, 185, 210), c(240, 246, 255), c(120, 135, 160) }, speed = 0.4, span = 0.7, rot = 20, sparks = true },
    Gold = { colors = { c(255, 236, 90), c(255, 160, 0), c(255, 255, 220), c(225, 130, 0) }, speed = 0.4, span = 0.75, rot = 25, sparks = true },
    Diamond = { colors = { c(150, 245, 255), c(30, 140, 255), c(240, 255, 255), c(90, 200, 255) }, speed = 0.45, span = 0.7, rot = 30, sparks = true },
    Rainbow = { colors = { c(255, 70, 90), c(255, 170, 40), c(255, 240, 70), c(70, 230, 120), c(70, 150, 255), c(210, 90, 255) }, speed = 0.4, span = 1, rot = 0, spin = 60, sparks = true },
    Molten = { colors = { c(255, 70, 0), c(255, 200, 40), c(255, 250, 170), c(255, 120, 0), c(170, 15, 0) }, speed = 0.5, span = 0.8, rot = 70, sparks = true },
}

local STEPS = 8
local function sample(colors, u)
    local n = #colors
    local x = (u % 1) * n
    local i = math.floor(x)
    return colors[i % n + 1]:Lerp(colors[(i + 1) % n + 1], x - i)
end
local function sequence(theme, t)
    local points = table.create(STEPS + 1)
    for i = 0, STEPS do
        points[i + 1] = ColorSequenceKeypoint.new(i / STEPS, sample(theme.colors, i / STEPS * theme.span - t * theme.speed))
    end
    return ColorSequence.new(points)
end

-- every flow gradient carries the tag FLOW and the attribute Theme, so clones and server-built copies animate too
-- (a weak table keyed by Instance drops its entries: the Luau wrapper is collected while the instance lives)
local FLOW = "RarityFlowGradient"
local loop, clock = nil, 0
local function startLoop()
    if loop then
        return
    end
    loop = RunService.Heartbeat:Connect(function(dt)
        clock += dt
        if clock < 1 / 30 or GuiService.ReducedMotionEnabled then
            return
        end
        clock = 0
        local t = os.clock()
        local made = {}
        for _, gradient in CollectionService:GetTagged(FLOW) do
            local label = gradient.Parent
            local name = gradient:GetAttribute("Theme")
            local theme = name and RarityText.Themes[name]
            if label and theme then
                made[name] = made[name] or sequence(theme, t)
                gradient.Color = made[name]
                if theme.spin then
                    gradient.Rotation = (theme.rot + t * theme.spin) % 360
                end
                local sparks = label:FindFirstChild("RaritySparks")
                if sparks then
                    for index, spark in sparks:GetChildren() do
                        local p = (t * 0.55 + index * 0.27) % 1
                        spark.Position = UDim2.fromScale((index * 0.29 + 0.08) % 1, 0.95 - p * 1.1)
                        spark.BackgroundTransparency = p * p
                        spark.Rotation = 45 + p * 180
                    end
                end
            end
        end
    end)
end

function RarityText.Apply(label, themeName, sparks)
    for _, name in { "RarityFlow", "RaritySparks" } do
        local old = label:FindFirstChild(name)
        if old then
            old:Destroy()
        end
    end
    local theme = themeName and RarityText.Themes[themeName]
    if not theme then
        return false
    end
    label.TextColor3 = Color3.new(1, 1, 1)
    local gradient = Instance.new("UIGradient")
    gradient.Name = "RarityFlow"
    gradient.Rotation = theme.rot
    gradient.Color = sequence(theme, 0)
    gradient:SetAttribute("Theme", themeName)
    gradient:AddTag(FLOW)
    gradient.Parent = label
    local folder
    if sparks ~= false and theme.sparks then
        folder = Instance.new("Frame")
        folder.Name = "RaritySparks"
        folder.BackgroundTransparency = 1
        folder.Size = UDim2.fromScale(1, 1)
        folder.ZIndex = label.ZIndex + 1
        for index = 1, 4 do
            local spark = Instance.new("Frame")
            spark.AnchorPoint = Vector2.new(0.5, 0.5)
            spark.Size = UDim2.fromOffset(4 + index % 2 * 2, 4 + index % 2 * 2)
            spark.BorderSizePixel = 0
            spark.BackgroundColor3 = theme.colors[(index - 1) % #theme.colors + 1]
            spark.BackgroundTransparency = 1
            spark.ZIndex = folder.ZIndex
            spark.Parent = folder
        end
        folder.Parent = label
    end
    startLoop()
    return true
end

-- labels built on the server (the egg held over a player's head) opt in with a tag
if RunService:IsClient() then
    startLoop()
    local function tagged(label)
        if label:IsA("TextLabel") then
            RarityText.Apply(label, label:GetAttribute("RarityTheme"), label:GetAttribute("RaritySparks") == true)
        end
    end
    CollectionService:GetInstanceAddedSignal("RarityText"):Connect(tagged)
    for _, label in CollectionService:GetTagged("RarityText") do
        task.spawn(tagged, label)
    end
end

return RarityText
