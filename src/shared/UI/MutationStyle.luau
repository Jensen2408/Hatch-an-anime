--[[ ReplicatedStorage.MutationStyle (ModuleScript, client) - 2026-11-08
One look for every mutation tag in the game (egg labels, character plates, hotbar, drop banner).
Each tier has its own colours and they MOVE:
  Silver / Gold / Diamond / Molten  their metal (or lava) colour with a bright shine band sweeping across, over and over
  Rainbow                  every colour, slowly turning round
  MutationStyle.Paint(obj, tier)        adds a moving UIGradient to a Frame, TextLabel or UIStroke
  MutationStyle.Badge(parent, tier, p)  builds a ready tag: studded-looking pill, black outline, "✦ GOLD"
  MutationStyle.Color(tier)             the plain main colour (for things that cannot take a gradient)
One Heartbeat loop drives every gradient; gradients that leave the game are dropped automatically. ]]
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local MS = {}
local function hex(s) return Color3.fromHex(s) end

-- { base top, base bottom, shine }
MS.Tiers = {
    Silver = { hex("E9EEF6"), hex("9AA6BA"), hex("FFFFFF") },
    Gold = { hex("FFD84A"), hex("F59A00"), hex("FFF6B8") },
    Diamond = { hex("8FEAFF"), hex("2AA8FF"), hex("F2FDFF") },
    Molten = { hex("FF7832"), hex("782210"), hex("FFE178") }, -- glowing lava (2026-11-08)
}
MS.Rainbow = { hex("FF3B3B"), hex("FF9F1C"), hex("FFE53B"), hex("3BFF6E"), hex("3BC8FF"), hex("9B5BFF"), hex("FF3BD6") }
MS.Order = { "Silver", "Gold", "Diamond", "Rainbow" }

function MS.Color(tier)
    if tier == "Rainbow" then return MS.Rainbow[6] end
    local t = MS.Tiers[tier]
    return t and t[1] or MS.Tiers.Gold[1]
end

local function rainbowSequence()
    local keys, n = {}, #MS.Rainbow
    for i, c in MS.Rainbow do
        table.insert(keys, ColorSequenceKeypoint.new((i - 1) / n, c))
    end
    table.insert(keys, ColorSequenceKeypoint.new(1, MS.Rainbow[1]))
    return ColorSequence.new(keys)
end
local function metalSequence(t, phase)
    -- base gradient with a narrow bright band at `phase` (0..1); band clamped inside the range
    local a, b, s = t[1], t[2], t[3]
    local function base(x) return a:Lerp(b, x) end
    local w = 0.09
    if phase > 1 or phase < 0 then
        return ColorSequence.new(base(0), base(1)) -- between sweeps: plain metal
    end
    local p = math.clamp(phase, w + 0.001, 1 - w - 0.001)
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0, base(0)),
        ColorSequenceKeypoint.new(p - w, base(p - w)),
        ColorSequenceKeypoint.new(p, s),
        ColorSequenceKeypoint.new(p + w, base(p + w)),
        ColorSequenceKeypoint.new(1, base(1)),
    })
end

local live = setmetatable({}, { __mode = "k" }) -- [UIGradient] = { tier, speed, seed }
local running = false
local function start()
    if running then return end
    running = true
    RunService.Heartbeat:Connect(function()
        local now = os.clock()
        local calm = GuiService.ReducedMotionEnabled
        for g, info in live do
            if not g.Parent then
                live[g] = nil
            elseif info.tier == "Rainbow" then
                g.Rotation = calm and 0 or (now * 70 + info.seed) % 360
            else
                -- shine sweeps left to right every ~1.8 s, then waits a moment
                local cycle = ((now + info.seed) % 2.4) / 1.8
                local phase = calm and 0.5 or (cycle <= 1 and cycle or 1.2)
                g.Color = metalSequence(MS.Tiers[info.tier], phase)
            end
        end
    end)
end

function MS.Paint(obj, tier)
    if not obj then return nil end
    local old = obj:FindFirstChild("MutationShine")
    if old then old:Destroy() end
    if not (tier == "Rainbow" or MS.Tiers[tier]) then return nil end
    local g = Instance.new("UIGradient")
    g.Name = "MutationShine"
    if tier == "Rainbow" then
        g.Color = rainbowSequence()
    else
        g.Rotation = 20
        g.Color = metalSequence(MS.Tiers[tier], 0.5)
    end
    if obj:IsA("GuiObject") and not obj:IsA("TextLabel") and not obj:IsA("TextButton") then
        obj.BackgroundColor3 = Color3.new(1, 1, 1) -- the gradient multiplies the background colour
    elseif obj:IsA("UIStroke") then
        obj.Color = Color3.new(1, 1, 1)
    end
    g.Parent = obj
    live[g] = { tier = tier, seed = math.random() * 3 }
    start()
    return g
end

-- A finished tag: white-faced pill painted with the tier, black outline, white "✦ TIER" with a black outline.
-- p (optional): { size = text size (16), font = Font, autoX = true }
function MS.Badge(parent, tier, p)
    p = p or {}
    local size = p.size or 16
    local pill = Instance.new("Frame")
    pill.Name = "MutationTag"
    pill.BorderSizePixel = 0
    pill.Size = UDim2.fromOffset(0, size + 8)
    pill.AutomaticSize = Enum.AutomaticSize.X
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, math.floor((size + 8) * 0.3))
    corner.Parent = pill
    local ink = Instance.new("UIStroke")
    ink.Name = "Outline"
    ink.Thickness = 2.5
    ink.Color = Color3.new(0, 0, 0)
    ink.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    ink.Parent = pill
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = pill
    local word = Instance.new("TextLabel")
    word.Name = "Word"
    word.BackgroundTransparency = 1
    word.Size = UDim2.fromScale(0, 1)
    word.AutomaticSize = Enum.AutomaticSize.X
    word.FontFace = p.font or Font.new("rbxasset://fonts/families/FredokaOne.json")
    word.TextSize = size
    word.TextColor3 = Color3.new(1, 1, 1)
    word.Text = "✦ " .. string.upper(tostring(tier))
    word.ZIndex = (p.z or 4) + 1
    local st = Instance.new("UIStroke")
    st.Thickness = math.max(2, size * 0.14)
    st.Color = Color3.new(0, 0, 0)
    st.LineJoinMode = Enum.LineJoinMode.Bevel
    st.Parent = word
    word.Parent = pill
    pill.ZIndex = p.z or 4
    MS.Paint(pill, tier)
    pill.Parent = parent
    return pill, word
end

-- 2026-11-10: the plate-free mutation tag used on egg and character labels: a small gem icon in the tier's
-- moving metal colours, then the tier word carrying its colour flow (ReplicatedStorage.RarityText).
-- Nothing sits behind it, so it never covers the text next to it. p (optional): { size = text size (16), z = ZIndex }
-- Returns the row Frame (AutomaticSize X; centre it with AnchorPoint 0.5). MS.SetTag(row, tier) re-themes it.
function MS.Tag(parent, tier, p)
    p = p or {}
    local size = p.size or 16
    local z = p.z or 4
    local row = Instance.new("Frame")
    row.Name = "MutationTag"
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Size = UDim2.fromOffset(0, size + 6)
    row.AutomaticSize = Enum.AutomaticSize.X
    row.ZIndex = z
    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Horizontal
    list.VerticalAlignment = Enum.VerticalAlignment.Center
    list.Padding = UDim.new(0, math.floor(size * 0.3))
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = row
    local slot = Instance.new("Frame") -- unrotated box, so the list measures the icon correctly
    slot.Name = "Icon"
    slot.BackgroundTransparency = 1
    slot.Size = UDim2.fromOffset(size, size)
    slot.LayoutOrder = 1
    slot.ZIndex = z
    slot.Parent = row
    local gem = Instance.new("Frame")
    gem.Name = "Gem"
    gem.AnchorPoint = Vector2.new(0.5, 0.5)
    gem.Position = UDim2.fromScale(0.5, 0.5)
    gem.Size = UDim2.fromScale(0.64, 0.64)
    gem.Rotation = 45
    gem.BorderSizePixel = 0
    gem.ZIndex = z
    local gemCorner = Instance.new("UICorner")
    gemCorner.CornerRadius = UDim.new(0.18, 0)
    gemCorner.Parent = gem
    local gemInk = Instance.new("UIStroke")
    gemInk.Name = "Outline"
    gemInk.Thickness = math.max(2, size * 0.14)
    gemInk.Color = Color3.new(0, 0, 0)
    gemInk.LineJoinMode = Enum.LineJoinMode.Round
    gemInk.Parent = gem
    local glint = Instance.new("Frame")
    glint.Name = "Glint"
    glint.AnchorPoint = Vector2.new(0.5, 0.5)
    glint.Position = UDim2.fromScale(0.3, 0.5)
    glint.Size = UDim2.fromScale(0.22, 0.5)
    glint.BackgroundColor3 = Color3.new(1, 1, 1)
    glint.BackgroundTransparency = 0.25
    glint.BorderSizePixel = 0
    glint.ZIndex = z + 1
    local glintCorner = Instance.new("UICorner")
    glintCorner.CornerRadius = UDim.new(1, 0)
    glintCorner.Parent = glint
    glint.Parent = gem
    gem.Parent = slot
    local word = Instance.new("TextLabel")
    word.Name = "Word"
    word.BackgroundTransparency = 1
    word.Size = UDim2.fromScale(0, 1)
    word.AutomaticSize = Enum.AutomaticSize.X
    word.FontFace = p.font or Font.new("rbxasset://fonts/families/FredokaOne.json")
    word.TextSize = size
    word.TextColor3 = Color3.new(1, 1, 1)
    word.LayoutOrder = 2
    word.ZIndex = z + 1
    local st = Instance.new("UIStroke")
    st.Name = "UIStroke"
    st.Thickness = math.max(2.5, size * 0.17)
    st.Color = Color3.new(0, 0, 0)
    st.LineJoinMode = Enum.LineJoinMode.Bevel
    st.Parent = word
    word.Parent = row
    row.Parent = parent
    MS.SetTag(row, tier)
    return row, word
end

function MS.SetTag(row, tier)
    local word = row:FindFirstChild("Word")
    local slot = row:FindFirstChild("Icon")
    local gem = slot and slot:FindFirstChild("Gem")
    if not (word and gem) then return end
    if row:GetAttribute("Tier") == tier then return end
    row:SetAttribute("Tier", tier)
    word.Text = string.upper(tostring(tier or ""))
    MS.Paint(gem, tier)
    local flowed = false
    local module = game:GetService("ReplicatedStorage"):FindFirstChild("RarityText")
    if module then
        local ok, RarityText = pcall(require, module)
        flowed = ok and RarityText and RarityText.Apply(word, tier, false) == true
    end
    if not flowed then
        word.TextColor3 = MS.Color(tier)
    end
end

return MS
