--[[ Client presentation for the river boss: shared one-way route, walk/slam/crawl,
HUD and effects. Damage comes exclusively from server-validated WoodenBat swings.
Slam damage and launch also run on the server. ]]
-- ===== 1. Services, modules =====
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local folder = ReplicatedStorage:WaitForChild("BossEvent")
local Config = require(folder:WaitForChild("BossConfig"))
local Builder = require(folder:WaitForChild("VoxelBossBuilder"))
local fxEvent = folder:WaitForChild("Fx")

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local THEME = {
    lacquer = Color3.fromRGB(98, 70, 56),
    post = Color3.fromRGB(74, 54, 44),
    cream = Color3.fromRGB(222, 198, 156),
    gold = Color3.fromRGB(196, 160, 86),
    hp = Color3.fromRGB(200, 60, 50),
    hpLow = Color3.fromRGB(240, 150, 60),
}
local SINK_DEPTH = 18
local EGG_HEIGHT = 6

local function ease(x)
    x = math.clamp(x, 0, 1)
    return x * x * (3 - 2 * x)
end
local function lerp(a, b, k)
    return a + (b - a) * k
end
local function playSound(id, position, speed, volume)
    local holder = Instance.new("Part")
    holder.Anchored = true
    holder.CanCollide = false
    holder.CanQuery = false
    holder.CanTouch = false
    holder.Transparency = 1
    holder.Size = Vector3.one
    holder.Position = position
    holder.Parent = workspace
    local sound = Instance.new("Sound")
    sound.SoundId = id
    sound.PlaybackSpeed = speed or 1
    sound.Volume = volume or 1
    sound.RollOffMaxDistance = 260
    sound.Parent = holder
    sound:Play()
    Debris:AddItem(holder, 3)
end
local SOUND_STEP = "rbxasset://sounds/action_jump_land.mp3"
local SOUND_SPLASH = "rbxasset://sounds/impact_water.mp3"
local SOUND_HIT = "rbxasset://sounds/collide.wav"

-- ===== 2. HUD =====
local gui = Instance.new("ScreenGui")
gui.Name = "BossEventHUD"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local function make(className, props, parent)
    local instance = Instance.new(className)
    for key, value in props do
        instance[key] = value
    end
    instance.Parent = parent
    return instance
end
local function label(parent, props)
    local base = {
        BackgroundTransparency = 1,
        FontFace = FONT,
        TextColor3 = THEME.cream,
        TextScaled = false,
        TextXAlignment = Enum.TextXAlignment.Left,
    }
    for key, value in props do
        base[key] = value
    end
    return make("TextLabel", base, parent)
end

local panel = make("Frame", {
    Name = "Panel",
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 6),
    Size = UDim2.new(0.92, 0, 0, 104),
    BackgroundColor3 = THEME.lacquer,
    Visible = false,
}, gui)
make("UISizeConstraint", { MaxSize = Vector2.new(520, 104) }, panel)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, panel)
make("UIStroke", { Color = THEME.gold, Thickness = 2 }, panel)
make("UIPadding", {
    PaddingLeft = UDim.new(0, 12),
    PaddingRight = UDim.new(0, 12),
    PaddingTop = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),
}, panel)
local titleLabel = label(panel, {
    Size = UDim2.new(1, -70, 0, 24),
    Text = "RIVER BOSS",
    TextSize = 22,
    TextColor3 = THEME.gold,
})
make("UIStroke", { Color = THEME.post, Thickness = 1.5 }, titleLabel)
local timerLabel = label(panel, {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, 0, 0, 0),
    Size = UDim2.new(0, 70, 0, 24),
    Text = "",
    TextSize = 20,
    TextXAlignment = Enum.TextXAlignment.Right,
})
local barBack = make("Frame", {
    Position = UDim2.new(0, 0, 0, 28),
    Size = UDim2.new(1, 0, 0, 22),
    BackgroundColor3 = THEME.post,
}, panel)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, barBack)
local barFill = make("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = THEME.hp }, barBack)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, barFill)
local hpLabel = label(barBack, {
    Size = UDim2.new(1, 0, 1, 0),
    Text = "",
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 2,
})
make("UIStroke", { Color = THEME.post, Thickness = 1.5 }, hpLabel)
local infoLabel = label(panel, {
    Position = UDim2.new(0, 0, 0, 54),
    Size = UDim2.new(1, 0, 0, 18),
    Text = "Guarding a " .. Config.RewardMutation .. " " .. Config.RewardEggType .. " Egg  •  Swing your bat to attack!",
    TextSize = 14,
    TextTruncate = Enum.TextTruncate.AtEnd,
})
local topLabel = label(panel, {
    Position = UDim2.new(0, 0, 0, 74),
    Size = UDim2.new(1, 0, 0, 18),
    Text = "",
    TextSize = 14,
    TextColor3 = THEME.gold,
    TextTruncate = Enum.TextTruncate.AtEnd,
})
local stunLabel = label(gui, {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.32, 0),
    Size = UDim2.new(0, 300, 0, 50),
    Text = "STUNNED!",
    TextSize = 40,
    TextColor3 = THEME.hpLow,
    TextXAlignment = Enum.TextXAlignment.Center,
    Visible = false,
})
make("UIStroke", { Color = THEME.post, Thickness = 3 }, stunLabel)

local function formatTime(seconds)
    seconds = math.max(0, math.ceil(seconds))
    return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function refreshHud(now)
    local active = workspace:GetAttribute("BossActive") == true
    local state = workspace:GetAttribute("BossState")
    local nextAt = workspace:GetAttribute("BossNextAt")
    if active and state == "Walking" then
        panel.Visible = true
        panel.Size = UDim2.new(0.92, 0, 0, 104)
        titleLabel.Text = "RIVER BOSS"
        local hp, maxHp = workspace:GetAttribute("BossHP") or 0, workspace:GetAttribute("BossMaxHP") or 1
        barBack.Visible, infoLabel.Visible, topLabel.Visible = true, true, true
        barFill.Size = UDim2.new(math.clamp(hp / maxHp, 0, 1), 0, 1, 0)
        barFill.BackgroundColor3 = hp / maxHp < 0.25 and THEME.hpLow or THEME.hp
        hpLabel.Text = hp .. " / " .. maxHp .. " HP"
        timerLabel.Text = formatTime((workspace:GetAttribute("BossEndsAt") or now) - now)
    elseif not active and nextAt and nextAt - now <= Config.WarnSeconds then
        panel.Visible = true
        panel.Size = UDim2.new(0.92, 0, 0, 38)
        titleLabel.Text = "RIVER BOSS RISES IN"
        barBack.Visible, infoLabel.Visible, topLabel.Visible = false, false, false
        timerLabel.Text = formatTime(nextAt - now)
    else
        panel.Visible = false
    end
end
local function refreshTop()
    local ok, rows = pcall(HttpService.JSONDecode, HttpService, workspace:GetAttribute("BossTop") or "[]")
    local parts = {}
    if ok and type(rows) == "table" then
        for i, row in rows do
            table.insert(parts, i .. ". " .. tostring(row.name) .. "  " .. tostring(row.damage))
        end
    end
    topLabel.Text = #parts > 0 and ("Top damage:  " .. table.concat(parts, "   ")) or "Top damage wins the egg!"
end
workspace:GetAttributeChangedSignal("BossTop"):Connect(refreshTop)
refreshTop()

-- ===== 3. Effects =====
local effects = Instance.new("Folder")
effects.Name = "BossEventFX"
effects.Parent = workspace

local function splash(position, count, power)
    for _ = 1, count do
        local cube = Instance.new("Part")
        cube.Size = Vector3.one * (math.random(5, 12) / 10)
        cube.Color = Color3.fromRGB(150, 220, 255):Lerp(Color3.new(1, 1, 1), math.random())
        cube.Material = Enum.Material.SmoothPlastic
        cube.Transparency = 0.2
        cube.CanCollide = false
        cube.CanQuery = false
        cube.CanTouch = false
        cube.CFrame = CFrame.new(position + Vector3.new(math.random(-4, 4), 1, math.random(-4, 4)))
        cube.Parent = effects
        local angle = math.random() * math.pi * 2
        cube.AssemblyLinearVelocity = Vector3.new(math.cos(angle) * power, power * (1 + math.random()), math.sin(angle) * power)
        Debris:AddItem(cube, 1.4)
    end
end

local function ring(position, fromDiameter, toDiameter, color, seconds)
    local disc = Instance.new("Part")
    disc.Shape = Enum.PartType.Cylinder
    disc.Anchored = true
    disc.CanCollide = false
    disc.CanQuery = false
    disc.CanTouch = false
    disc.Material = Enum.Material.Neon
    disc.Color = color
    disc.Transparency = 0.25
    disc.Size = Vector3.new(0.4, fromDiameter, fromDiameter)
    disc.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
    disc.Parent = effects
    local tween = TweenService:Create(disc, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.4, toDiameter, toDiameter),
        Transparency = 1,
    })
    tween:Play()
    Debris:AddItem(disc, seconds + 0.1)
end

local function shakeCamera(strength, seconds)
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end
    task.spawn(function()
        local started = os.clock()
        while os.clock() - started < seconds do
            local fade = 1 - (os.clock() - started) / seconds
            humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
                * strength
                * fade
            RunService.RenderStepped:Wait()
        end
        humanoid.CameraOffset = Vector3.zero
    end)
end

local function floatText(position, text, color)
    local anchor = Instance.new("Part")
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.CanQuery = false
    anchor.CanTouch = false
    anchor.Transparency = 1
    anchor.Size = Vector3.one
    anchor.Position = position
    anchor.Parent = effects
    local billboard = make("BillboardGui", {
        Size = UDim2.new(0, 90, 0, 40),
        AlwaysOnTop = true,
        LightInfluence = 0,
    }, anchor)
    local text_ = label(billboard, {
        Size = UDim2.new(1, 0, 1, 0),
        Text = text,
        TextSize = 30,
        TextColor3 = color,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    make("UIStroke", { Color = THEME.post, Thickness = 2 }, text_)
    TweenService:Create(anchor, TweenInfo.new(0.8), { Position = position + Vector3.new(0, 5, 0) }):Play()
    TweenService:Create(text_, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
    Debris:AddItem(anchor, 0.9)
end

-- ===== 4. The boss model =====
local boss = nil -- { model, rig, parts = {}, egg, eggPivotOffset, highlight, lastSlam, lastStep, epoch, slamField }

-- Slam warning field: a grid of thin tiles laid on whatever ground is under the slam radius (grass banks as well as
-- the river bed), built once when a slam starts. A cell only appears where a player standing on it would be hit
-- (the server checks the horizontal radius and SlamVerticalRange around the boss's feet).
local FIELD_STEP = 4
local FIELD_RED = Color3.fromRGB(255, 60, 50)

local function destroySlamField(owner)
    if owner and owner.slamField then
        owner.slamField.folder:Destroy()
        owner.slamField = nil
    end
end

local function buildSlamField(feet)
    local ignore = { effects }
    if boss then
        table.insert(ignore, boss.model)
        if boss.egg then
            table.insert(ignore, boss.egg)
        end
    end
    for _, other in Players:GetPlayers() do
        if other.Character then
            table.insert(ignore, other.Character)
        end
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore
    local fieldFolder = Instance.new("Folder")
    fieldFolder.Name = "SlamField"
    local tiles = {}
    local radius, origin = Config.SlamRadius, feet.Position
    local highest, lowest = Config.SlamVerticalRange - 3, -(Config.SlamVerticalRange + 3) -- ground height vs the feet
    for gx = -radius + FIELD_STEP / 2, radius, FIELD_STEP do
        for gz = -radius + FIELD_STEP / 2, radius, FIELD_STEP do
            local dist = math.sqrt(gx * gx + gz * gz)
            if dist <= radius then
                local hit = workspace:Raycast(origin + Vector3.new(gx, 30, gz), Vector3.new(0, -70, 0), params)
                local rel = hit and hit.Position.Y - origin.Y
                if hit and rel <= highest and rel >= lowest then
                    local up = hit.Normal
                    local right = up:Cross(Vector3.zAxis)
                    right = right.Magnitude > 0.01 and right.Unit or Vector3.xAxis
                    local tile = Instance.new("Part")
                    tile.Size = Vector3.new(FIELD_STEP - 0.4, 0.25, FIELD_STEP - 0.4)
                    tile.CFrame = CFrame.fromMatrix(hit.Position + up * 0.2, right, up)
                    tile.Anchored = true
                    tile.CanCollide = false
                    tile.CanQuery = false
                    tile.CanTouch = false
                    tile.CastShadow = false
                    tile.Material = Enum.Material.Neon
                    tile.Color = FIELD_RED
                    tile.Transparency = 0.66
                    tile.Parent = fieldFolder
                    table.insert(tiles, { part = tile, dist = dist, edge = dist > radius - FIELD_STEP })
                end
            end
        end
    end
    fieldFolder.Parent = effects
    return { folder = fieldFolder, tiles = tiles }
end

local function updateSlamField(field)
    local pulse = math.sin(os.clock() * 14) * 0.1
    for _, tile in field.tiles do
        tile.part.Transparency = (tile.edge and 0.3 or 0.66) + pulse
    end
end

-- The fists land: a bright wave runs out across the same tiles, then they fade.
local function impactSlamField(owner)
    local field = owner.slamField
    if not field then
        return
    end
    owner.slamField = nil
    for _, tile in field.tiles do
        task.delay(tile.dist / Config.SlamRadius * 0.4, function()
            if tile.part.Parent then
                tile.part.Color = Color3.fromRGB(255, 235, 200)
                tile.part.Transparency = 0.15
                TweenService:Create(tile.part, TweenInfo.new(0.35), { Transparency = 1 }):Play()
            end
        end)
    end
    Debris:AddItem(field.folder, 1.2)
end

local function despawn()
    if boss then
        boss.model:Destroy()
        if boss.egg then
            boss.egg:Destroy()
        end
        destroySlamField(boss)
        boss = nil
    end
end

local function spawnBoss()
    despawn()
    local model, rig = Builder.Build()
    model.Name = "VoxelOni_Local"
    model.Parent = workspace
    local parts, offsets, groupOf = {}, {}, {}
    for groupName, group in rig.Groups do
        for _, entry in group.Parts do
            table.insert(parts, entry.Part)
            table.insert(offsets, entry.Offset)
            table.insert(groupOf, groupName)
        end
    end
    local highlight = make("Highlight", {
        FillColor = Color3.new(1, 1, 1),
        FillTransparency = 1, -- (the hit flash tweens this)
        -- every boss gets this black outline (house style for bosses): it keeps the big voxel silhouette readable against the map
        OutlineColor = Color3.new(0, 0, 0),
        OutlineTransparency = 0,
        DepthMode = Enum.HighlightDepthMode.Occluded,
    }, model)
    local egg
    local template = folder:FindFirstChild("RareEgg")
    if template then
        egg = template:Clone()
        local _, size = egg:GetBoundingBox()
        egg:ScaleTo(egg:GetScale() * EGG_HEIGHT / math.max(size.Y, 0.01))
        local light = Instance.new("PointLight")
        light.Range = 16
        light.Brightness = 3
        local first = egg:FindFirstChildWhichIsA("BasePart", true)
        if first then
            light.Parent = first
        end
        egg.Parent = workspace
    end
    boss = {
        model = model,
        rig = rig,
        parts = parts,
        offsets = offsets,
        groupOf = groupOf,
        cframes = table.create(#parts),
        egg = egg,
        eggCenterOffset = egg and egg:GetPivot():ToObjectSpace((egg:GetBoundingBox())) or CFrame.new(),
        highlight = highlight,
        epoch = workspace:GetAttribute("BossEpoch"),
        lastHp = workspace:GetAttribute("BossHP"),
    }
end

-- Joint angles for one frame. Returns { bob, pitch, roll, head, armL, armR, legL, legR }.
local function animate(phase, distance, slamTime, t)
    local phi = distance / Config.StrideStuds * math.pi * 2
    local swing = math.sin(phi)
    local pose = {
        bob = math.abs(math.cos(phi)) * 0.7 - 0.35,
        pitch = -0.06,
        roll = swing * 0.04,
        head = 0,
        headYaw = math.sin(phi * 0.5) * 0.08,
        armL = -swing * 0.35,
        armR = swing * 0.35,
        legL = swing * 0.45,
        legR = -swing * 0.45,
    }
    if phase == "emerge" then
        local k = t / Config.EmergeSeconds
        local roar = ease((k - 0.5) * 2)
        pose.bob, pose.roll, pose.legL, pose.legR = 0, 0, 0, 0
        pose.armL, pose.armR = roar * 2.4, roar * 2.4
        pose.pitch, pose.head = roar * 0.15, roar * 0.3
    elseif phase == "crawl" or phase == "exited" then
        local k = ease((slamTime or 0) * 4)
        pose.pitch = lerp(-0.06, -1.25, k)
        pose.bob = lerp(pose.bob, -2 + math.abs(swing) * 0.3, k)
        pose.armL, pose.armR = 1.15 + swing * 0.35, 1.15 - swing * 0.35
        pose.legL, pose.legR = -0.9 - swing * 0.25, -0.9 + swing * 0.25
        pose.head, pose.headYaw, pose.roll = k * 0.65, 0, 0
    elseif phase == "slam" then
        local raise, impact = Config.SlamImpactAt - 0.45, Config.SlamImpactAt -- arms stay up while the field shows
        local arms, pitch, bob
        if slamTime < raise then
            local k = ease(slamTime / raise)
            arms, pitch, bob = lerp(0, 2.7, k), lerp(-0.06, 0.12, k), 0
        elseif slamTime < impact then
            local k = ((slamTime - raise) / (impact - raise)) ^ 2
            arms, pitch, bob = lerp(2.7, 0.5, k), lerp(0.12, -0.35, k), lerp(0, -1.5, k)
        else
            local k = ease((slamTime - impact) / (Config.SlamSeconds - impact))
            arms, pitch, bob = lerp(0.5, 0, k), lerp(-0.35, -0.06, k), lerp(-1.5, 0, k)
        end
        pose.armL, pose.armR, pose.pitch, pose.bob = arms, arms, pitch, bob
        pose.legL, pose.legR, pose.roll, pose.headYaw = 0, 0, 0, 0
        pose.head = slamTime < raise and 0.25 or 0
    end
    return pose
end

local function placeBoss(root, pose)
    local groups = boss.rig.Groups
    local body = root * CFrame.new(groups.Body.Pivot + Vector3.new(0, pose.bob, 0)) * CFrame.Angles(pose.pitch, 0, pose.roll)
    local function fromBody(name)
        return body * CFrame.new(groups[name].Pivot - groups.Body.Pivot)
    end
    local joints = {
        Body = body,
        Head = fromBody("Head") * CFrame.Angles(pose.head, pose.headYaw, 0),
        ArmL = fromBody("ArmL") * CFrame.Angles(pose.armL, 0, -0.08),
        ArmR = fromBody("ArmR") * CFrame.Angles(pose.armR, 0, 0.08),
        LegL = root * CFrame.new(groups.LegL.Pivot + Vector3.new(0, pose.bob * 0.5, 0)) * CFrame.Angles(pose.legL, 0, 0),
        LegR = root * CFrame.new(groups.LegR.Pivot + Vector3.new(0, pose.bob * 0.5, 0)) * CFrame.Angles(pose.legR, 0, 0),
    }
    for i, part in boss.parts do
        boss.cframes[i] = joints[boss.groupOf[i]] * boss.offsets[i]
    end
    workspace:BulkMoveTo(boss.parts, boss.cframes, Enum.BulkMoveMode.FireCFrameChanged)
    if boss.egg then
        local spin = CFrame.Angles(0, os.clock() * 1.2, 0)
        local center = body * boss.rig.EggOffset * CFrame.new(0, math.sin(os.clock() * 2) * 0.3, 0) * spin
        boss.egg:PivotTo(center * boss.eggCenterOffset:Inverse())
    end
end

local function onSlamImpact(feet)
    local position = feet.Position + Vector3.new(0, 2, 0)
    splash(feet.Position + feet.LookVector * 8, 18, 30)
    playSound(SOUND_SPLASH, position, 0.5, 2)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end
    local offset = root.Position - feet.Position
    local flat = Vector3.new(offset.X, 0, offset.Z)
    local distance = flat.Magnitude
    if distance < 90 then
        shakeCamera(math.clamp(2.5 - distance / 40, 0.3, 2.5), 0.5)
    end

end

local function explode(winnerId)
    if not boss then
        return
    end
    local dying = boss
    boss = nil
    destroySlamField(dying)
    local center = dying.model:GetBoundingBox().Position
    splash(center - Vector3.new(0, 10, 0), 30, 40)
    ring(center - Vector3.new(0, 12, 0), 10, 80, Color3.fromRGB(255, 220, 120), 0.9)
    playSound(SOUND_SPLASH, center, 0.35, 3)
    shakeCamera(2, 0.8)
    -- The body pieces are open shells (one mesh per colour), so they must never fly apart or be walked into:
    -- nothing collides, back faces render (no see-through inside), and the pieces shrink away in place while
    -- coloured voxel debris bursts out instead.
    local palette = {}
    for _, color in Builder.Colors do
        table.insert(palette, color)
    end
    for _, part in dying.parts do
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        pcall(function()
            part.DoubleSided = true
        end)
    end
    for _ = 1, 80 do
        local origin = dying.parts[math.random(#dying.parts)].Position
        local cube = Instance.new("Part")
        cube.Size = Vector3.one * (math.random(5, 16) / 10)
        cube.Color = palette[math.random(#palette)]
        cube.Material = Enum.Material.SmoothPlastic
        cube.CanCollide = false
        cube.CanQuery = false
        cube.CanTouch = false
        cube.CFrame = CFrame.new(origin)
        local away = origin - center
        away = away.Magnitude > 0.1 and away.Unit or Vector3.yAxis
        cube.AssemblyLinearVelocity = away * math.random(18, 42) + Vector3.new(0, math.random(15, 40), 0)
        cube.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
        cube.Parent = effects
        TweenService:Create(cube, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
        Debris:AddItem(cube, 1.5)
    end
    task.delay(0.25, function()
        for _, part in dying.parts do
            TweenService:Create(part, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Size = part.Size * 0.02,
            }):Play()
        end
        task.wait(0.7)
        dying.model:Destroy()
    end)
    -- the egg pops up, then flies to the winner
    local egg = dying.egg
    if egg then
        local start = egg:GetPivot()
        local startScale = egg:GetScale()
        local winner = winnerId and Players:GetPlayerByUserId(winnerId)
        task.spawn(function()
            local began = os.clock()
            while os.clock() - began < 2.4 and egg.Parent do
                local k = (os.clock() - began) / 2.4
                local up = start * CFrame.new(0, ease(math.min(k * 2, 1)) * 14, 0)
                local targetRoot = winner and winner.Character and winner.Character:FindFirstChild("HumanoidRootPart")
                local cframe = up
                if targetRoot and k > 0.5 then
                    local fly = ease((k - 0.5) * 2)
                    cframe = up:Lerp(CFrame.new(targetRoot.Position + Vector3.new(0, 3, 0)), fly)
                    egg:ScaleTo(startScale * (1 - fly * 0.8))
                end
                egg:PivotTo(cframe * CFrame.Angles(0, os.clock() * 6, 0))
                RunService.RenderStepped:Wait()
            end
            if egg.Parent then
                splash(egg:GetPivot().Position, 12, 18)
                egg:Destroy()
            end
        end)
    end
end

-- ===== 5. Frame loop =====
RunService.RenderStepped:Connect(function()
    local now = workspace:GetServerTimeNow()
    refreshHud(now)
    local active = workspace:GetAttribute("BossActive") == true
    local state = workspace:GetAttribute("BossState")
    local epoch = workspace:GetAttribute("BossEpoch")
    if not active or not epoch or state == "Defeated" then
        if boss and not active then
            despawn()
        end
        return
    end
    if not boss or boss.epoch ~= epoch then
        spawnBoss()
    end
    local t = now - epoch
    local sinkOffset = 0
    if state == "Escaped" or state == "Cancelled" then
        local endedAt = workspace:GetAttribute("BossEndedAt") or now
        t = endedAt - epoch
        if state == "Cancelled" then
            sinkOffset = -SINK_DEPTH * ease((now - endedAt) / Config.SinkSeconds)
        end
    end
    local feet, phase, distance, slamTime = Config.Pose(t)
    if phase == "emerge" then
        sinkOffset = -SINK_DEPTH * (1 - ease(t / Config.EmergeSeconds))
        if not boss.emerged then
            boss.emerged = true
            splash(feet.Position, 30, 35)
            playSound(SOUND_SPLASH, feet.Position, 0.4, 3)
        end
    end
    if phase == "crawl" or phase == "exited" then
        sinkOffset -= Config.CrawlDrop * ease((slamTime or 0) * 4)
    end
    local pose = animate(phase, distance, slamTime, t)
    placeBoss(feet * CFrame.new(0, sinkOffset, 0), pose)
    -- footsteps: a thud and a splash each time a foot comes down
    local step = math.floor(distance / Config.StrideStuds * 2)
    if state == "Walking" and phase == "walk" and boss.lastStep ~= step then
        if boss.lastStep then
            local side = step % 2 == 0 and -3 or 3
            local foot = (feet * CFrame.new(side, 0, -2)).Position
            splash(foot, 5, 12)
            playSound(SOUND_STEP, foot, 0.35, 1.5)
        end
        boss.lastStep = step
    end
    -- slam warning field (laid on the real ground: grass and river bed) and impact
    local slamming = state == "Walking" and phase == "slam"
    if slamming and slamTime < Config.SlamImpactAt then
        if not boss.slamField then
            boss.slamField = buildSlamField(feet)
        end
        updateSlamField(boss.slamField)
    elseif boss.slamField and not slamming then
        destroySlamField(boss) -- the slam never landed (cancelled / boss gone)
    end
    if slamming and slamTime >= Config.SlamImpactAt then
        local slamIndex = math.floor((t - Config.EmergeSeconds) / Config.StepSeconds)
        if boss.lastSlam ~= slamIndex then
            boss.lastSlam = slamIndex
            if slamTime < Config.SlamImpactAt + 0.3 then
                impactSlamField(boss)
                onSlamImpact(feet)
            end
        end
    end
    -- hit flash whenever the HP drops (anyone's hit)
    local hp = workspace:GetAttribute("BossHP")
    if boss.lastHp and hp and hp < boss.lastHp then
        boss.highlight.FillTransparency = 0.45
        TweenService:Create(boss.highlight, TweenInfo.new(0.15), { FillTransparency = 1 }):Play()
    end
    boss.lastHp = hp
end)

-- ===== 6. Server-confirmed effects (no click/tap damage input) =====
fxEvent.OnClientEvent:Connect(function(kind, data)
    if kind == "Hit" and type(data) == "table" and typeof(data.position) == "Vector3" then
        floatText(data.position, "-" .. tostring(data.damage), Color3.fromRGB(255, 120, 90))
        playSound(SOUND_HIT, data.position, 0.6, 0.8)
    elseif kind == "SlamHit" then
        stunLabel.Visible = true
        task.delay(Config.StunSeconds, function() stunLabel.Visible = false end)
    elseif kind == "Defeated" then
        explode(type(data) == "table" and data.winnerId or nil)
    end
end)

