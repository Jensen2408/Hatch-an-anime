--[[ SummonHatch.RollFx  (ModuleScript, client)
The hatch animation, ported from the HatchDemo RollFx. The server already chose the result (HatchGoo rolled it when the
egg went in); this only plays it for the player who pressed Hatch.

Everything runs from one clock in one render step, on springs and curves, so it stays smooth at any frame rate and the
clock itself can be slowed for hit-stops and slow motion.

Beats: 1. the world loses its colour, a circle draws itself in front of the incubator, the egg comes up
       2. it spins up, the camera dives in, white  ->  the summon room (high above the map, local parts only)
       3. the reel: the egg's three characters circle it as silhouettes on cards, three crack hits
       4. it stops on the winner, the other two are cut down, the card is drawn into the egg
       5. colour; a rare enough result (tier + bonus) fakes a lower one first, then the lights die
       6. a few black-and-white impact frames   7. the character on its rarity page, camera swings round
       8. type: name, rarity, stars, Power / income / roll quality, mutation seal, COLLECT
       9. shutters sweep across, back to the world

Roll.play(data, onDone) - data is the SummonHatchCue payload (see SummonHatchServer). onDone runs after cleanup.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local Config = require(script.Parent.Config)
local Ui = require(script.Parent.SummonUi)
local Sfx = require(script.Parent.Sfx)
local K = require(script.Parent.FxKit)
local Economy = require(ReplicatedStorage:WaitForChild("CharacterEconomy"))

local player = Players.LocalPlayer
local Roll = { busy = false }
local rng = Random.new()
local WHITE = Color3.new(1, 1, 1)
local INK, PAPER = Ui.INK, Ui.PAPER
local SHADE = Color3.fromRGB(38, 34, 48)
local VOID = Color3.fromRGB(13, 10, 22)
local ROOM = Vector3.new(0, 6000, 0) -- nothing in the map reaches this high, so every summon looks the same anywhere
local CHAR_H = Config.CharacterHeight
local SIL_H = Config.SilhouetteHeight
local EGG_W = Config.EggWorldHeight
local EGG_H = Config.EggRoomHeight
local WALL_D = 300
local REEL = Config.Reel
local TURNS = Config.Turns
local LOCK_ACTION = "SummonHatchLock"
local BIND = "SummonHatchCam"
local clips = {}

local function lowEnd()
    return UserGameSettings.SavedQualityLevel.Value > 0 and UserGameSettings.SavedQualityLevel.Value <= 3
end

-- A signature move from ReplicatedStorage.V2Moves (Blender export, Bone.Transform per frame), cached.
local function clip(name)
    if clips[name] ~= nil then
        return clips[name]
    end
    local folder = ReplicatedStorage:FindFirstChild("V2Moves")
    local module = folder and folder:FindFirstChild(name)
    if not module or not module:IsA("ModuleScript") then
        clips[name] = false
        return false
    end
    local ok, data = pcall(require, module)
    if not ok or type(data) ~= "table" or type(data.Bones) ~= "table" then
        clips[name] = false
        return false
    end
    local bones = {}
    for bone, flat in data.Bones do
        local frames = {}
        for i = 1, #flat, 7 do
            table.insert(
                frames,
                CFrame.new(flat[i], flat[i + 1], flat[i + 2], flat[i + 3], flat[i + 4], flat[i + 5], flat[i + 6])
            )
        end
        bones[bone] = frames
    end
    clips[name] = { Rate = data.Rate, Length = data.Length, Events = data.Events, Bones = bones }
    return clips[name]
end

local function bonesOf(model, data)
    local list = {}
    if data then
        for _, d in model:GetDescendants() do
            if d:IsA("Bone") and data.Bones[d.Name] then
                list[d] = data.Bones[d.Name]
            end
        end
    end
    return list
end

-- Root is left out: it carries the jumps and spins that would take the character out of the shot.
-- scale = model:GetScale() / 6 (the moves are authored on 6-stud rigs at scale 6, like V2MoveClient).
local function poseAt(list, data, t, scale)
    local f = math.clamp(t, 0, data.Length) * data.Rate
    local i, a = math.floor(f) + 1, f % 1
    for bone, frames in list do
        if frames[i] and bone.Name ~= "Root" then
            local cf = frames[i]:Lerp(frames[i + 1] or frames[i], a)
            bone.Transform = cf.Rotation + cf.Position * scale
        end
    end
end

local function heroPose(model, id)
    local data = clip(id)
    if data then
        poseAt(bonesOf(model, data), data, 0, model:GetScale() / 6)
    end
end

-- Scales a character so it stands `height` studs tall (relative, so a mutated model keeps its proportions).
local function standTall(model, height)
    local _, size = model:GetBoundingBox()
    model:ScaleTo(model:GetScale() * height / math.max(size.Y, 0.01))
end

-- Display-only copy: no scripts, prompts, name tags or sounds, nothing that collides or casts a shadow.
local function displayCopy(source)
    local copy = source:Clone()
    for _, d in copy:GetDescendants() do
        if
            d:IsA("LuaSourceContainer")
            or d:IsA("ProximityPrompt")
            or d:IsA("BillboardGui")
            or d:IsA("ClickDetector")
            or d:IsA("Sound")
        then
            d:Destroy()
        elseif d:IsA("BasePart") then
            d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
            d.CastShadow = false
        elseif d:IsA("Humanoid") then
            d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        end
    end
    return copy
end

local function tween(obj, time, props)
    local tw = TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

local function full(parent, z, color, transparency)
    local f = Instance.new("Frame")
    f.BorderSizePixel = 0
    f.BackgroundColor3 = color
    f.BackgroundTransparency = transparency or 0
    f.Size = UDim2.fromScale(1, 1)
    f.ZIndex = z
    f.Parent = parent
    return f
end

local function hex(color)
    return string.format("#%02X%02X%02X", color.R * 255, color.G * 255, color.B * 255)
end

-- Shard colour: the egg's biggest part, unless it is (nearly) white because a texture carries the colour.
local function eggColorOf(model, fallback)
    local best, volume = nil, 0
    for _, d in model:GetDescendants() do
        if d:IsA("BasePart") and d.Transparency < 0.5 then
            local v = d.Size.X * d.Size.Y * d.Size.Z
            if v > volume then
                best, volume = d, v
            end
        end
    end
    if not best then
        return fallback
    end
    local h, s, v = best.Color:ToHSV()
    if s < 0.12 and v > 0.85 then
        return fallback
    end
    return Color3.fromHSV(h, s, v)
end

function Roll.play(res, onDone)
    Roll.busy = true
    local cam = workspace.CurrentCamera
    local low = lowEnd()
    local reduced = player:GetAttribute("ReducedMotion") == true
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local tier = math.clamp(math.floor(tonumber(res.rarityRank) or 1), 1, #Config.Tiers)
    local tierInfo = Config.Tiers[tier]
    local tierColor = tierInfo.color
    local mutInfo = res.mutation and Config.Mutations[res.mutation]
    local page = Config.Pages[tier]
    local qualityRank = tonumber(res.qualityRank) or 1
    local bonusRoll = qualityRank >= Config.BonusQualityRank
    local bonus = res.topPick == true or bonusRoll
    local drama = math.min(tier + (bonus and 1 or 0), 6) -- intensity; colours and type still follow `tier`
    local accent = bonusRoll and typeof(res.qualityColor) == "Color3" and res.qualityColor or tierColor
    local origin = res.origin
    -- inside the incubator: a tank-sized egg, a small circle on the egg platform, the camera just outside the glass
    local inChamber = res.inChamber == true
    local EGG_W = inChamber and Config.EggChamberHeight or EGG_W
    local circleStuds = inChamber and Config.ChamberCircleSize or Config.CircleSize
    local sceneMotion, uiMotion = K.motion(), K.motion()
    local anim = sceneMotion.anim

    local maid, conns = {}, {}
    local function own(x)
        table.insert(maid, x)
        return x
    end
    local fx = own(Instance.new("Folder"))
    fx.Name = "SummonHatchFx"
    fx.Parent = workspace

    -- The room is turned so the real sun comes from over the camera's left shoulder.
    local sun = Lighting:GetSunDirection() * Vector3.new(1, 0, 1)
    local toCamera = sun.Magnitude > 0.05 and CFrame.Angles(0, math.rad(-38), 0):VectorToWorldSpace(sun.Unit)
        or Vector3.new(0, 0, 1)
    local room = CFrame.lookAt(ROOM, ROOM - toCamera)
    local function here(x, y, z)
        return room * CFrame.new(x, y, z)
    end
    local function at(x, y, z)
        return room:PointToWorldSpace(Vector3.new(x, y, z))
    end

    -- First shot: from the walkway, looking back at the incubator, turned until nothing blocks it
    local flat = (typeof(res.face) == "Vector3" and res.face or Vector3.zAxis) * Vector3.new(1, 0, 1)
    local faceDir = flat.Magnitude > 0.1 and flat.Unit or Vector3.zAxis
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = { char, fx }
    for _, turn in (inChamber and {} or { 0, 30, -30, 60, -60, 90, -90, 120, -120, 180 }) do
        local dir = CFrame.Angles(0, math.rad(turn), 0):VectorToWorldSpace(faceDir)
        if not workspace:Raycast(origin, dir * 18, rayParams) then
            faceDir = dir
            break
        end
    end
    local worldEye = inChamber and origin + faceDir * Config.ChamberCameraDistance + Vector3.new(0, 0.9, 0)
        or origin + faceDir * 15 - Vector3.new(0, 2.2, 0)
    local down = workspace:Raycast(origin, Vector3.new(0, -24, 0), rayParams)
    local groundY = down and down.Position.Y or origin.Y - 4

    -- Egg, in the world first
    local model = displayCopy(res.egg)
    local _, eggSize = model:GetBoundingBox()
    model:ScaleTo(model:GetScale() * EGG_W / math.max(eggSize.Y, 0.01))
    local eggRoot = Instance.new("Part")
    eggRoot.Anchored, eggRoot.CanCollide, eggRoot.CanQuery, eggRoot.CanTouch = true, false, false, false
    eggRoot.Transparency = 1
    eggRoot.Size = Vector3.one
    eggRoot.CFrame = CFrame.new(model:GetBoundingBox().Position)
    eggRoot.Parent = model
    model.PrimaryPart = eggRoot
    model:PivotTo(CFrame.new(origin - Vector3.new(0, EGG_W, 0)))
    model.Parent = fx
    local eggColor = eggColorOf(model, tierColor)
    local eggLine = Instance.new("Highlight")
    eggLine.FillTransparency = 1
    eggLine.OutlineColor = INK
    eggLine.DepthMode = Enum.HighlightDepthMode.Occluded
    eggLine.Parent = model

    -- Summon circle on the real ground
    local floorCf = CFrame.lookAt(
        Vector3.new(origin.X, groundY + 0.15, origin.Z),
        Vector3.new(origin.X, groundY + 1, origin.Z),
        Vector3.zAxis
    )
    local circleGui, circlePart = K.panel(fx, circleStuds, circleStuds, floorCf, 24)
    local circleA, circleB = K.image(circleGui, "circle_a", PAPER), K.image(circleGui, "circle_b", PAPER)
    for _, i in { circleA, circleB } do
        i.Position = UDim2.fromScale(0.5, 0.5)
        i.Size = UDim2.fromScale(0, 0)
    end

    -- Backdrop that rides on the camera: it always fills the frame, and only exists in the summon room
    local wallGui, wallPart = K.panel(nil, 1600, 900, CFrame.identity, 1)
    own(wallPart)
    local wallBase = full(wallGui, 1, VOID)
    local burst = K.image(wallGui, "sunburst", page.burst, 2)
    burst.Size = UDim2.fromOffset(2000, 2000)
    burst.Position = UDim2.fromOffset(800, 450)
    burst.Visible = false

    -- Up to three cards, one silhouette each. The order is shuffled here, it means nothing.
    -- An egg with a single character (Unknown) gets no cards: the egg alone takes the three hits.
    local slots = {}
    if type(res.slots) == "table" and #res.slots >= 2 then
        slots = table.clone(res.slots)
    end
    for i = #slots, 2, -1 do
        local j = rng:NextInteger(1, i)
        slots[i], slots[j] = slots[j], slots[i]
    end
    local portraits = ReplicatedStorage:FindFirstChild("CharacterInventory")
    portraits = portraits and portraits:FindFirstChild("Portraits")
    local cards = {}
    for i, id in slots do
        local gui, part = K.panel(nil, 14, 21, CFrame.identity, 14)
        part.Transparency = 0 -- solid, so the card really covers whatever it passes in front of
        part.Color = INK
        own(part)
        local face = full(gui, 1, SHADE)
        local edge = Instance.new("UIStroke")
        edge.Thickness = 7
        edge.Color = PAPER
        edge.LineJoinMode = Enum.LineJoinMode.Miter
        edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        edge.Parent = face
        face.Position = UDim2.fromOffset(9, 9)
        face.Size = UDim2.new(1, -18, 1, -18)
        local source = portraits and portraits:FindFirstChild(id)
        local sil
        if source and source:IsA("Model") then
            sil = displayCopy(source)
            for _, d in sil:GetDescendants() do
                if d:IsA("SurfaceAppearance") or d:IsA("ParticleEmitter") or d:IsA("Highlight") then
                    d:Destroy()
                elseif d:IsA("Decal") or d:IsA("Texture") then
                    d.Transparency = 1
                elseif d:IsA("BasePart") then
                    d.Color = Color3.new(0, 0, 0)
                    d.Material = Enum.Material.SmoothPlastic
                    if d:IsA("MeshPart") then
                        d.TextureID = ""
                    end
                end
            end
            standTall(sil, SIL_H)
            sil:PivotTo(here(0, -400 - i * 30, 0))
            sil.Parent = fx
            heroPose(sil, id)
        end
        cards[i] = {
            part = part,
            face = face,
            edge = edge,
            sil = sil,
            id = id,
            lit = 0,
            push = 0,
            fly = Vector3.zero,
            spin = 0,
            gone = false,
        }
    end
    local winnerSlot = table.find(slots, res.characterId) or 1
    local ringEnd = -(winnerSlot - 1) * math.pi * 2 / 3

    -- World dims and takes the camera
    local cc = own(Instance.new("ColorCorrectionEffect"))
    cc.Name = "SummonHatchGrade"
    cc.Parent = Lighting
    local sceneDof = {}
    for _, e in Lighting:GetChildren() do
        if e:IsA("DepthOfFieldEffect") and e.Enabled then
            sceneDof[e] = true
            e.Enabled = false
        end
    end
    tween(cc, 0.45, { Contrast = 0.2, Saturation = -0.5, Brightness = -0.03 })

    -- UI layers
    local gui = own(Ui.screen(Ui.GuiName, 200))
    local canvas = Ui.canvas(gui)
    canvas.ZIndex = 12
    Ui.setHud(false, Sfx.owns)
    local vs = cam.ViewportSize
    local aspect = vs.X / math.max(vs.Y, 1)
    local cover = math.max(vs.X, vs.Y) * 1.5

    local function bar(y, anchor)
        local f = full(gui, 8, INK)
        f.AnchorPoint = Vector2.new(0, anchor)
        f.Position = UDim2.fromScale(0, y)
        f.Size = UDim2.fromScale(1, 0)
        return f
    end
    local barTop, barBottom = bar(0, 0), bar(1, 1)
    local barSize = uiMotion.spring(0, 2.6, 0.9, function(v)
        barTop.Size = UDim2.fromScale(1, v)
        barBottom.Size = UDim2.fromScale(1, v)
    end)
    local flash = full(gui, 30, WHITE, 1)
    local focus = K.image(gui, "focus", WHITE, 5)
    focus.Position = UDim2.fromScale(0.5, 0.5)
    focus.Size = UDim2.fromOffset(cover, cover)
    focus.ImageTransparency = 1
    local halftone = K.image(gui, "halftone", INK, 4)
    halftone.Position = UDim2.fromScale(0.5, 0.5)
    halftone.Size = UDim2.fromScale(1, 1)
    halftone.ImageTransparency = 1
    local shutters = {}
    for i = 1, 3 do
        local f = full(gui, 25, INK)
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Rotation = 7
        f.Size = UDim2.fromScale(0.42, 1.6)
        f.Position = UDim2.fromScale(i / 3 - 1 / 6, -1)
        shutters[i] = f
    end

    -- Sound effects written on the page, like a manga panel. Same for every result.
    local gogo = {}
    local function addGogo(x, y, size, rot)
        local t = Ui.text(gui, "ゴ", size, PAPER, Enum.Font.GothamBlack)
        t.AnchorPoint = Vector2.new(0.5, 0.5)
        t.Position = UDim2.fromScale(x, y)
        t.Size = UDim2.fromOffset(size * 1.4, size * 1.4)
        t.Rotation = rot
        t.ZIndex = 6
        t.Visible = false
        table.insert(gogo, { label = t, x = x, y = y, rot = rot })
    end

    local skipped = false
    local skipBtn

    -- Own character out of the shot, controls off for the animation
    local hidden = {}
    -- the real egg in the tank makes way for the summon's copy while it plays
    local tankEgg = inChamber and typeof(res.chamber) == "Instance" and res.chamber:FindFirstChild("IncubatingEgg")
    if tankEgg then
        for _, d in tankEgg:GetDescendants() do
            if d:IsA("BasePart") or d:IsA("Decal") then
                hidden[d] = true
            end
        end
    end
    if char then
        for _, d in char:GetDescendants() do
            if d:IsA("BasePart") or d:IsA("Decal") then
                hidden[d] = true
            end
        end
    end
    ContextActionService:BindActionAtPriority(LOCK_ACTION, function()
        return Enum.ContextActionResult.Sink
    end, false, Enum.ContextActionPriority.High.Value, table.unpack(Enum.PlayerActions:GetEnumItems()))
    local controls
    pcall(function()
        local module = player.PlayerScripts:FindFirstChild("PlayerModule")
        if module then
            controls = require(module):GetControls()
            controls:Disable()
        end
    end)

    -- Light behind the egg
    local rays = K.bill(fx, "rays", WHITE, true, 1)
    local core = K.bill(fx, "glow", WHITE, true, 1)
    local tunnel

    -- Live state read by the render step
    local st = {
        clock = 0,
        scale = 1,
        stopUntil = 0,
        trauma = 0,
        fromCf = cam.CFrame,
        fromFov = cam.FieldOfView,
        fromType = cam.CameraType,
        fromSubject = cam.CameraSubject,
        spin = 0,
        spinRate = 2,
        shake = 0,
        room = false,
        ring = ringEnd - TURNS * math.pi * 2,
        reelFrom = false,
        pass = false,
        tilt = 0,
        raysSize = 0,
        raysA = 1,
        coreA = 1,
        focusA = 1,
        focusColor = WHITE,
        flow = 0,
        flowRate = 0,
        crackFlash = 0,
        hero = false,
        shards = {},
        rainbow = false,
        burstRate = 0.09,
    }
    local eggY = sceneMotion.spring(inChamber and -0.35 * EGG_W or -EGG_W, 2.2, 0.55)
    local circleSize = sceneMotion.spring(0, 1.8, 0.8, function(v)
        circleA.Size = UDim2.fromScale(v, v)
        circleB.Size = UDim2.fromScale(v * 0.72, v * 0.72)
    end)
    local eyeAt = sceneMotion.spring(cam.CFrame.Position, 1.25, 1)
    local lookAt = sceneMotion.spring(cam.CFrame.Position + cam.CFrame.LookVector * 18, 1.25, 1)
    local fov = sceneMotion.spring(cam.FieldOfView, 1.25, 1)
    local rollAt = sceneMotion.spring(0, 1.6, 0.8)
    local heroPoint

    local function hitStop(sec)
        st.stopUntil = os.clock() + sec
    end
    local function hold(sec)
        local to = st.clock + sec
        while st.clock < to and gui.Parent do
            RunService.Heartbeat:Wait()
        end
    end
    local function snapCamera(eye, look, degrees, rollDegrees)
        eyeAt.x, eyeAt.to, eyeAt.v = eye, eye, Vector3.zero
        lookAt.x, lookAt.to, lookAt.v = look, look, Vector3.zero
        if degrees then
            fov.x, fov.to, fov.v = degrees, degrees, 0
        end
        rollAt.x, rollAt.to, rollAt.v = rollDegrees or 0, rollDegrees or 0, 0
    end

    local function shard(pos, vel, size, color, life)
        local w = Instance.new("WedgePart")
        w.Anchored, w.CanCollide, w.CanQuery, w.CanTouch = true, false, false, false
        w.CastShadow = false
        w.Material = Enum.Material.SmoothPlastic
        w.Size, w.Color = size, color
        w.CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
        w.Parent = fx
        table.insert(
            st.shards,
            { p = w, v = vel, life = life, age = 0, rot = rng:NextUnitVector() * rng:NextNumber(3, 11) }
        )
    end

    -- Cracks are real lines on the shell. They run along the surface, stay on it as the egg moves,
    -- get covered by a card passing in front, and light comes through them.
    local crack = { stages = {}, hot = {}, nodes = {}, color = Color3.fromRGB(255, 214, 120) }

    local function trace(from, heading, steps, stride)
        local route, zig = { from }, rng:NextNumber() < 0.5 and 1 or -1
        local lon, lat = from[1], from[2]
        for _ = 1, steps do
            zig = -zig
            local turn = heading + zig * rng:NextNumber(0.35, 1.05)
            local step = stride * rng:NextNumber(0.7, 1.3)
            lon += math.cos(turn) * step
            lat = math.clamp(lat + math.sin(turn) * step, -1.15, 1.15)
            table.insert(route, { lon, lat })
        end
        return route
    end

    function crack.build()
        local _, size = model:GetBoundingBox()
        local parts = {}
        for _, d in model:GetDescendants() do
            if d:IsA("BasePart") and d ~= eggRoot then
                d.CanQuery = true
                table.insert(parts, d)
            end
        end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = { model }
        local function onShell(spot)
            local lon, lat = spot[1], spot[2]
            local dir = Vector3.new(math.sin(lon) * math.cos(lat), math.sin(lat), -math.cos(lon) * math.cos(lat))
            local guess = dir * size / 2
            local from = eggRoot.CFrame:PointToWorldSpace(guess * 1.7)
            local hit = workspace:Raycast(from, eggRoot.Position - from, params)
            if hit then
                local p = eggRoot.CFrame:PointToObjectSpace(hit.Position)
                return p + p.Unit * 0.05
            end
            return guess * 1.02
        end
        local a = trace({ -0.25, 0.28 }, 0, 7, 0.2)
        local b = trace(a[4], -1.3, 5, 0.17)
        local c = trace(a[6], 1.2, 3, 0.14)
        local d = trace(b[#b], math.pi, 7, 0.2)
        local e = trace(a[1], math.pi + 0.3, 5, 0.18)
        local f = trace(d[4], -1.4, 4, 0.15)
        local g = trace(e[3], 1.4, 4, 0.15)
        local h = trace(a[#a], -0.9, 5, 0.18)
        local plan = {
            { { a, 0.2 } },
            { { b, 0.15 }, { c, 0.1 } },
            { { d, 0.17 }, { e, 0.16 } },
            { { f, 0.11 }, { g, 0.11 }, { h, 0.14 } },
            {},
        }
        local routes = { a, b, c, d, e, f, g, h }
        for _ = 1, low and 3 or 7 do
            local route = routes[rng:NextInteger(1, #routes)]
            table.insert(
                plan[5],
                { trace(route[rng:NextInteger(1, #route)], rng:NextNumber(0, math.pi * 2), 3, 0.13), 0.08 }
            )
        end
        for k, lines in plan do
            crack.stages[k] = {}
            for _, line in lines do
                local points = {}
                for i, spot in line[1] do
                    points[i] = onShell(spot)
                    table.insert(crack.nodes, points[i])
                end
                table.insert(crack.stages[k], { points = points, width = line[2] })
            end
        end
        for _, part in parts do
            part.CanQuery = false
        end
    end

    local function crackBeam(a0, a1, w0, w1, color, z)
        local beam = Instance.new("Beam")
        beam.Attachment0, beam.Attachment1 = a0, a1
        beam.Segments = 1
        beam.FaceCamera = true
        beam.LightInfluence = 0
        beam.Color = ColorSequence.new(color)
        beam.Transparency = NumberSequence.new(0)
        beam.Width0, beam.Width1 = w0, w1
        beam.ZOffset = z
        beam.Parent = eggRoot
        return beam
    end

    -- The lines of one stage shoot out from their start in a fraction of a second
    function crack.run(k, duration)
        for _, line in crack.stages[k] or {} do
            local points, width = line.points, line.width
            local tips = {}
            local start = Instance.new("Attachment")
            start.Position = points[1]
            start.Parent = eggRoot
            local last = start
            for i = 2, #points do
                local tip = Instance.new("Attachment")
                tip.Position = points[i - 1]
                tip.Parent = eggRoot
                local w0, w1 = width * (1 - (i - 2) / (#points - 1)), width * (1 - (i - 1) / (#points - 1))
                if not low then
                    crackBeam(last, tip, w0 * 3 + 0.1, w1 * 3 + 0.1, INK, 0)
                end
                local hot = crackBeam(last, tip, w0, w1, crack.color, 0.1)
                hot.Brightness = 1.3
                table.insert(crack.hot, { beam = hot, w0 = w0, w1 = w1 })
                tips[i - 1] = { tip = tip, from = points[i - 1], to = points[i] }
                last = tip
            end
            anim(duration or 0.14, function(u)
                local p = u * #tips
                for i, t in tips do
                    t.tip.Position = t.from:Lerp(t.to, math.clamp(p - (i - 1), 0, 1))
                end
            end)
        end
        st.crackFlash = 1
    end

    function crack.tint(color)
        crack.color = color
        for _, h in crack.hot do
            h.beam.Color = ColorSequence.new(color)
        end
    end

    function crack.chips(count)
        if #crack.nodes == 0 then
            return
        end
        local toEye = room.LookVector * -1
        for _ = 1, low and math.ceil(count / 2) or count do
            local node = crack.nodes[rng:NextInteger(1, #crack.nodes)]
            local spot = eggRoot.CFrame:PointToWorldSpace(node)
            local out = (spot - eggRoot.Position).Unit
            local size = rng:NextNumber(0.2, 0.6)
            shard(
                spot,
                (out + toEye * 0.6).Unit * rng:NextNumber(7, 20),
                Vector3.new(0.06, size, size * rng:NextNumber(0.6, 1.3)),
                eggColor,
                rng:NextNumber(0.5, 0.9)
            )
        end
    end

    cam.CameraType = Enum.CameraType.Scriptable
    RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function(realDt)
        realDt = math.min(realDt, 0.1)
        local now = os.clock()
        local rate = st.scale * (now < st.stopUntil and 0.03 or 1) * (skipped and not st.hero and 5 or 1)
        local dt = realDt * rate
        st.clock += dt
        local t = st.clock
        for part in hidden do
            if part.Parent then
                part.LocalTransparencyModifier = 1
            end
        end
        sceneMotion.step(dt)
        uiMotion.step(realDt)

        -- reel
        if st.reelFrom then
            local u = math.clamp((t - st.reelFrom) / REEL, 0, 1)
            local over = math.rad(15) * math.sin(math.pi * math.clamp((u - 0.8) / 0.2, 0, 1))
            st.ring = ringEnd - TURNS * math.pi * 2 * (1 - u) ^ 2.6 + over
            local pass = math.floor(st.ring / (math.pi * 2 / 3) + 0.5)
            if pass ~= st.pass then
                if st.pass and #cards > 0 then
                    Sfx.play("tick", 0.45 + u * 0.5, 1.2 - u * 0.45)
                    st.trauma = math.max(st.trauma, 0.06 + u * 0.12)
                end
                st.pass = pass
            end
        end

        -- egg
        st.spin += st.spinRate * dt
        st.shake = math.max(0, st.shake - dt * 0.9)
        local jit = Vector3.new(math.noise(t * 34, 1.5), math.noise(t * 34, 4.5), 0) * st.shake
        local eggAt
        if model.Parent then
            if st.room then
                eggAt = at(0, 1 + math.sin(t * 1.7) * 0.35, 0)
                local face = room.Rotation
                    * CFrame.Angles(0, math.pi + math.sin(t * 0.8) * 0.16, 0)
                    * CFrame.Angles(0, 0, st.tilt + jit.X * 0.06)
                model:PivotTo(CFrame.new(eggAt + room:VectorToWorldSpace(jit)) * face)
            else
                eggAt = origin + Vector3.new(0, eggY.x, 0)
                model:PivotTo(
                    CFrame.new(eggAt + jit)
                        * CFrame.Angles(0, st.spin, 0)
                        * CFrame.Angles(0, 0, 0.08 * math.sin(t * 2.4))
                )
            end
            st.eggAt = eggAt
        end
        eggAt = st.eggAt or origin

        -- camera
        st.trauma = math.max(0, st.trauma - dt * 1.5)
        local s = st.trauma * st.trauma * (reduced and 0.25 or 1)
        local n = t * 13
        local shaken = CFrame.new(math.noise(n, 1.1) * s * 2.2, math.noise(n, 2.2) * s * 2.2, 0)
            * CFrame.Angles(0, 0, math.noise(n, 3.3) * s * 0.09)
        local up = st.room and room.UpVector or Vector3.yAxis
        local camCf = CFrame.lookAt(eyeAt.x, lookAt.x, up) * CFrame.Angles(0, 0, math.rad(rollAt.x)) * shaken
        cam.CFrame = camCf
        cam.FieldOfView = fov.x

        -- light surges through the cracks after a hit
        if st.crackFlash > 0.01 then
            st.crackFlash *= math.exp(-dt * 9)
            local grow = 1 + st.crackFlash * 0.8
            for _, h in crack.hot do
                h.beam.Width0, h.beam.Width1 = h.w0 * grow, h.w1 * grow
            end
        end

        -- the backdrop rides on the camera
        if st.room then
            wallPart.CFrame = camCf * CFrame.new(0, 0, -WALL_D) * CFrame.Angles(0, math.pi, 0)
            if burst.Visible then
                burst.Rotation += realDt * 360 * st.burstRate * 0.2
                local h = 2 * WALL_D * math.tan(math.rad(fov.x / 2))
                local p = cam:WorldToViewportPoint(heroPoint or eggAt)
                burst.Position = UDim2.fromOffset(800 + (p.X / vs.X - 0.5) * h * aspect, 450 + (p.Y / vs.Y - 0.5) * h)
            end
        end

        -- cards ride round the egg, the one nearest the camera is lit
        for i, c in cards do
            if not c.gone and st.room then
                local dir = st.ring + (i - 1) * math.pi * 2 / 3
                local radius = aspect > 1.4 and 15 or 10
                local front = (math.cos(dir) + 1) / 2
                local pos = Vector3.new(
                    math.sin(dir) * radius,
                    0.4 + (1 - math.cos(dir)) * 3.4,
                    math.cos(dir) * radius - 8 + c.push
                )
                pos = pos:Lerp(Vector3.new(0, 1, 0), c.absorb or 0) + c.fly
                local world = room:PointToWorldSpace(pos)
                local cf = CFrame.lookAt(world, camCf.Position, up) * CFrame.Angles(0, 0, math.rad(5) + c.spin)
                c.part.CFrame = cf
                if c.sil then
                    c.sil:PivotTo(cf * CFrame.new(0, -7.6, -1.2))
                end
                local lit = c.lit + (K.smooth((front - 0.86) / 0.13) - c.lit) * math.min(realDt * 24, 1)
                c.lit = lit
                if c.color then
                    c.face.BackgroundColor3 = c.color
                else
                    c.face.BackgroundColor3 = SHADE:Lerp(PAPER, lit)
                end
            end
        end

        -- light behind the egg
        if st.raysA < 0.99 then
            local toEye = (camCf.Position - eggAt).Unit
            rays.set(eggAt - toEye * 7, camCf, t * 0.7, st.raysSize, st.raysA)
            core.set(eggAt - toEye * 6, camCf, 0, st.raysSize * 0.62, st.coreA)
        else
            rays.set(eggAt, camCf, 0, 0.1, 1)
            core.set(eggAt, camCf, 0, 0.1, 1)
        end

        -- ground circle turns while it charges
        if circlePart.Parent then
            circleA.Rotation = t * 30
            circleB.Rotation = -t * 55
        end

        -- hyperspace: the texture is pushed by hand so a hit-stop freezes it too
        if tunnel then
            st.flow += st.flowRate * dt
            tunnel.part.CFrame = room * CFrame.Angles(0, 0, t * 0.22)
            for _, b in tunnel.beams do
                b.beam:SetTextureOffset((st.flow * b.speed) % 1)
            end
        end

        -- focus lines turn slowly
        if st.focusA < 0.99 then
            focus.Rotation += realDt * 14
            focus.ImageColor3 = st.focusColor
        end
        focus.ImageTransparency = st.focusA
        if heroPoint then
            local p = cam:WorldToViewportPoint(heroPoint)
            focus.Position = UDim2.fromOffset(p.X, p.Y)
        end

        for _, g in gogo do
            if g.label.Visible then
                g.label.Position = UDim2.new(g.x, math.noise(t * 5, g.y * 9) * 5, g.y, math.noise(t * 5, g.x * 9) * 5)
            end
        end

        if st.rainbow then
            local c = Color3.fromHSV((t * 0.1) % 1, 0.8, 1) -- 2026-11-12: slower (was 0.22)
            burst.ImageColor3 = c
            if st.heroLine then
                st.heroLine.OutlineColor = c
            end
        end

        -- shards fall on the same clock, so slow motion catches them
        for i = #st.shards, 1, -1 do
            local d = st.shards[i]
            d.age += dt
            if d.age >= d.life then
                d.p:Destroy()
                table.remove(st.shards, i)
            else
                d.v -= room:VectorToWorldSpace(Vector3.new(0, 30 * dt, 0))
                d.p.CFrame = (d.p.CFrame + d.v * dt) * CFrame.Angles(d.rot.X * dt, d.rot.Y * dt, d.rot.Z * dt)
            end
        end
    end)

    task.spawn(function()
        local ok, err = pcall(function()
            -- Everything for the reveal is made before anything moves, out of sight, so nothing hitches later
            local c = displayCopy(res.character)
            standTall(c, CHAR_H)
            local charCf = here(0, -7.5, 0) * CFrame.Angles(0, math.pi, 0)
            local farCf = charCf * CFrame.new(0, -500, 0)
            c:PivotTo(farCf)
            c.Parent = fx
            local poseScale = c:GetScale() / 6
            local data = clip(res.characterId)
            local moveBones = bonesOf(c, data)
            local heroTime = 0
            if data then
                poseAt(moveBones, data, heroTime, poseScale)
            end
            RunService.Heartbeat:Wait()
            local headBone = c:FindFirstChild("Head", true)
            local hipBone = c:FindFirstChild("Hips", true)
            local function rest(node, fallback)
                if not node then
                    return fallback
                end
                local p = node:IsA("Bone") and node.TransformedWorldCFrame.Position
                    or node:IsA("BasePart") and node.Position
                    or nil
                return p and charCf:PointToWorldSpace(farCf:PointToObjectSpace(p)) or fallback
            end
            local head = rest(headBone, at(0, 5, 0))
            local hips = rest(hipBone, at(0, -2, 0))
            local subject = head:Lerp(hips, 0.5)
            local inRoom = room:PointToObjectSpace(subject)

            -- 1. The world loses its colour, a circle draws itself, the egg comes up
            Sfx.play("rumble", 0.6, 1)
            barSize.to = 0.095
            eyeAt.to, lookAt.to, fov.to = worldEye, origin + Vector3.new(0, 0.6, 0), 44
            eggY.to = 0
            circleSize.to = 1
            local smokeK = inChamber and 0.35 or 1
            local smokeR = 8 * smokeK
            for i = 1, low and 3 or 6 do
                local a = i / 6 * math.pi * 2
                K.flip(
                    fx,
                    Vector3.new(origin.X + math.cos(a) * smokeR, groundY + 0.8 * smokeK, origin.Z + math.sin(a) * smokeR),
                    "smoke",
                    { size = 3.5 * smokeK, life = 0.6, color = Color3.fromRGB(226, 214, 200), rot = rng:NextNumber(0, 360) }
                )
            end
            hold(0.85)

            -- 2. It spins up, the camera dives in, and the white takes everything
            Sfx.play("riser", 0.8, 1)
            Sfx.play("whoosh", 0.7, 0.7)
            st.raysA, st.coreA = 0.6, 0.55
            anim(0.64, function(u)
                local e = K.inCubic(u)
                st.spinRate = 2 + e * 46
                st.raysSize = 14 + e * 30
                st.focusA = 1 - u * 0.5
                st.shake = 0.1 + e * 0.3
                eyeAt.to = worldEye:Lerp(origin + faceDir * (inChamber and Config.ChamberDiveDistance or 5), e)
                fov.to = 44 + e * 44
            end)
            hold(0.44)
            anim(0.2, function(u)
                flash.BackgroundTransparency = 1 - u
            end)
            hold(0.2)

            -- Behind the white: the summon room
            st.room = true
            circlePart.Parent = nil
            cc.Contrast, cc.Saturation, cc.Brightness = 0.06, 0.05, 0
            wallPart.Parent = fx
            model:ScaleTo(model:GetScale() * EGG_H / EGG_W)
            crack.build()
            st.spinRate, st.shake, st.focusA = 0, 0.1, 0.8
            st.focusColor = PAPER
            local beams = {}
            local tunnelPart = K.part(fx, Vector3.one, room)
            for i = 1, low and 12 or 30 do
                local a = rng:NextNumber(0, math.pi * 2)
                local r = rng:NextNumber(18, 72)
                local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
                a0.Position = Vector3.new(math.cos(a) * r * 1.6, math.sin(a) * r, 80)
                a1.Position = Vector3.new(math.cos(a) * r * 1.6, math.sin(a) * r, -220)
                a0.Parent, a1.Parent = tunnelPart, tunnelPart
                local b = Instance.new("Beam")
                b.Attachment0, b.Attachment1 = a0, a1
                b.Texture = K.Art.Ids.streak or ""
                b.TextureMode = Enum.TextureMode.Static
                b.TextureLength = rng:NextNumber(150, 300)
                b.Segments = 10
                b.FaceCamera = true
                b.LightInfluence = 0
                b.LightEmission = 1
                b.Width0 = rng:NextNumber(5, 26)
                b.Width1 = b.Width0
                b.Color = ColorSequence.new(WHITE)
                b.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(0.16, 0.3),
                    NumberSequenceKeypoint.new(0.72, 0.45),
                    NumberSequenceKeypoint.new(1, 1),
                })
                b.Parent = tunnelPart
                beams[i] = { beam = b, speed = rng:NextNumber(0.7, 1.3) }
            end
            tunnel = { part = tunnelPart, beams = beams }
            st.flowRate = 1.6
            snapCamera(at(0, 0.5, 66), at(0, 0.4, -10), 40)
            eyeAt.f, lookAt.f = 0.9, 2
            eyeAt.to = at(0, 0.4, 56)
            st.raysSize, st.raysA, st.coreA = 34, 0.7, 0.72
            for _, card in cards do
                card.part.Parent = fx
            end
            st.reelFrom = st.clock
            anim(0.34, function(u)
                flash.BackgroundTransparency = u
            end)
            Sfx.play("whoosh", 0.8, 1.2)
            task.delay(Config.SkipAfter, function()
                if gui.Parent and not st.stopped then
                    local holder = Ui.button(
                        canvas,
                        "SKIP",
                        UDim2.fromOffset(112, 48),
                        UDim2.new(1, -24, 0, 84),
                        Color3.fromRGB(70, 66, 84),
                        function()
                            skipped = true
                        end,
                        Vector2.new(1, 0)
                    )
                    holder.ZIndex = 9
                    skipBtn = holder
                end
            end)
            for i = 1, low and 2 or 4 do
                local side = i % 2 == 0 and 1 or -1
                addGogo(
                    0.5 + side * (0.3 + i * 0.022),
                    0.76 - i * 0.12,
                    math.floor(vs.Y * (0.11 + i * 0.03)),
                    side * 11
                )
            end

            -- 3. The reel. Same curve and same three hits for every result.
            local function crackHit(k)
                crack.run(k)
                crack.chips(4 + k * 2)
                Sfx.play("crack", 0.7 + k * 0.1, 1.1 - k * 0.08)
                st.trauma = math.min(st.trauma + 0.3 + k * 0.05, 1)
                st.shake = 0.35 + k * 0.12
                st.tilt = rng:NextNumber(-0.14, 0.14)
                st.raysSize += 14
                st.raysA = math.max(st.raysA - 0.12, 0.25)
                st.coreA = math.max(st.coreA - 0.12, 0.2)
                st.focusA = math.max(st.focusA - 0.12, 0.45)
                st.flowRate += 0.9
                eyeAt.to = at(0, 0.4, 56 - k * 1.5)
                fov.v -= 3
                if not low then
                    K.sparks(fx, st.eggAt + room.LookVector * -5, 8 + k * 4, PAPER, 34, 1.6, 0.4)
                end
                if gogo[k] then
                    gogo[k].label.Visible = true
                end
            end
            hold(REEL * 0.26)
            crackHit(1)
            hold(REEL * 0.32)
            crackHit(2)
            hold(REEL * 0.24)
            crackHit(3)
            if gogo[4] then
                gogo[4].label.Visible = true
            end
            hold(REEL * 0.18)

            -- 4. It stops. The winner slams forward, the other two are cut down.
            st.stopped = true
            st.reelFrom = false
            st.ring = ringEnd
            if skipBtn then
                skipBtn.Visible = false
            end
            for _, g in gogo do
                g.label.Visible = false
            end
            Sfx.play("thunk", 1, 1)
            Sfx.play("shing", 0.9, 1)
            hitStop(0.1)
            st.trauma = 0.7
            st.flowRate = 0.5
            local winner = cards[winnerSlot]
            if winner then
                winner.color = PAPER
                for i, card in cards do
                    if i ~= winnerSlot then
                        local cut = K.image(gui, "slash", WHITE, 7)
                        local p = cam:WorldToViewportPoint(card.part.Position)
                        cut.Position = UDim2.fromOffset(p.X, p.Y)
                        cut.Rotation = rng:NextNumber(-62, -48)
                        anim(0.2, function(u)
                            cut.Size = UDim2.fromOffset(vs.Y * 1.5 * K.outQuint(u), vs.Y * 0.28 * (1 - u))
                        end, function()
                            cut:Destroy()
                        end)
                        local side = card.part.Position - at(0, 0, 0)
                        local dir = room:VectorToObjectSpace(side) * Vector3.new(1, 0.4, 0.2)
                        anim(0.4, function(u)
                            card.fly = dir.Unit * K.inCubic(u) * 130 + Vector3.new(0, -K.inCubic(u) * 24, 0)
                            card.spin = K.inCubic(u) * (dir.X > 0 and -2.4 or 2.4)
                        end, function()
                            card.gone = true
                            card.part.Parent = nil
                            if card.sil then
                                card.sil.Parent = nil
                            end
                        end)
                    end
                end
                anim(0.28, function(u)
                    winner.push = K.outBack(u) * 5
                end)
                hold(0.42)

                -- The card is drawn into the egg
                Sfx.play("whoosh", 0.7, 1.5)
                anim(0.24, function(u)
                    winner.absorb = K.inCubic(u)
                end, function()
                    winner.gone = true
                    winner.part.Parent = nil
                    if winner.sil then
                        winner.sil.Parent = nil
                    end
                end)
                hold(0.24)
            else
                hold(0.42)
            end
            st.trauma = 0.3
            eyeAt.f, lookAt.f = 1.7, 2
            eyeAt.to, lookAt.to, fov.to = at(0, 0.4, 24), at(0, 1, 0), 36
            crack.run(4, 0.22)
            crack.chips(10)
            Sfx.play("crack", 0.9, 0.9)

            local function glow(color)
                crack.tint(color == WHITE and crack.color or color)
                rays.color(color)
                core.color(color)
                for _, b in tunnel.beams do
                    b.beam.Color = ColorSequence.new(color)
                end
            end

            -- 5. Colour at last. More drama means longer, and enough of it lies first.
            if drama <= 2 then
                glow((tier >= 2 or bonus) and accent or WHITE)
                hold(0.6)
            elseif drama <= 4 then
                glow(accent)
                st.raysSize, st.raysA, st.coreA = 90, 0.2, 0.2
                st.shake = 0.5
                st.trauma = drama == 4 and 0.75 or 0.4
                Sfx.play("rumble", 0.7, drama == 4 and 0.9 or 1.1)
                hold(drama == 4 and 0.8 or 0.65)
            elseif skipped then
                glow(accent)
                hold(0.12)
            else
                -- Fake-out: it looks like a lower rarity, then the lights die
                glow(Config.Tiers[math.max(1, tier - 2)].color)
                st.raysSize, st.raysA, st.coreA = 90, 0.2, 0.2
                st.shake = 0.5
                st.trauma = 0.4
                Sfx.play("rumble", 0.7, 1.1)
                hold(0.7)
                st.raysA, st.coreA, st.focusA = 1, 1, 1
                st.shake = 0
                for _, b in tunnel.beams do
                    b.beam.Enabled = false
                end
                wallBase.BackgroundColor3 = Color3.new(0, 0, 0)
                crack.tint(Color3.fromRGB(46, 42, 54))
                tween(cc, 0.1, { Brightness = -0.5, Saturation = -1 })
                Sfx.play("heart", 1, 1)
                eyeAt.f = 0.7
                eyeAt.to = at(0, 0.8, 18)
                hold(0.6)
                Sfx.play("heart", 1, 1.05)
                hold(0.42)
                tween(cc, 0.06, { Brightness = 0.04, Saturation = 0.1 })
                Sfx.play("crack", 1, 0.7)
                glow(accent)
                st.raysSize, st.raysA, st.coreA = 120, 0.05, 0.15
                st.shake, st.trauma = 0.9, 1
                hitStop(0.1)
                hold(0.42)
            end

            -- The shell gives way
            crack.run(5, 0.1)
            crack.chips(14)
            Sfx.play("crack", 1, 0.8)
            st.shake = math.max(st.shake, 0.6)
            hold(0.14)

            -- 6. The hit: a few frames of pure black and white before any colour comes back
            local heroLine = Instance.new("Highlight")
            heroLine.DepthMode = Enum.HighlightDepthMode.Occluded
            heroLine.OutlineColor = INK
            heroLine.FillColor = INK
            heroLine.FillTransparency = 0
            heroLine.Parent = c
            st.heroLine = heroLine
            c:PivotTo(charCf)
            heroPoint = subject
            if data then
                poseAt(moveBones, data, heroTime, poseScale)
            end

            -- Frame the subject on the right third, from low down, with the horizon leaning into them
            local kx = aspect > 1.45 and 0.3 or (aspect > 1.1 and 0.14 or 0)
            local dist = 31 + (6 - drama) * 0.6
            local fovEnd = 34
            local halfW = math.tan(math.rad(fovEnd / 2)) * dist * aspect
            local camX = inRoom.X - kx * halfW
            local camY = inRoom.Y - 3
            local eyeEnd = at(camX, camY, inRoom.Z + dist)
            local lookEnd = eyeEnd + room:VectorToWorldSpace(Vector3.new(0, 0.085, -1).Unit) * 10
            local dutch = drama >= 3 and -5 or -2

            -- Dress the page behind the impact frames
            local shellPos = st.eggAt
            model.Parent = nil
            st.eggAt = at(0, 1, 0)
            for _, b in tunnel.beams do
                b.beam.Enabled = false
            end
            st.raysA, st.coreA = 1, 1
            local depth = (inRoom.Z + dist + 26) / dist
            local wordAt = here(camX + (inRoom.X - camX) * depth - 4, camY + (inRoom.Y + 3 - camY) * depth, -26)
                * CFrame.Angles(0, math.pi, math.rad(-4))
            local kanjiGui, kanjiPart = K.panel(nil, 58, 58, wordAt, 8)
            own(kanjiPart)
            local kanji = K.image(kanjiGui, "kanji" .. math.min(tier, 6), page.word)
            kanji.AnchorPoint = Vector2.zero
            kanji.Size = UDim2.fromScale(1, 1)
            local floorGui, floorPart =
                K.panel(fx, 70, 70, CFrame.lookAt(at(0, -7.4, 0), at(0, -6, 0), room.LookVector), 10)
            local floorRing = K.image(floorGui, "circle_a", page.floor)
            floorRing.Position = UDim2.fromScale(0.5, 0.5)
            floorRing.Size = UDim2.fromScale(1, 1)
            local floorTwo = K.image(floorGui, "circle_b", page.floor)
            floorTwo.Position = UDim2.fromScale(0.5, 0.5)
            floorTwo.Size = UDim2.fromScale(0.7, 0.7)
            floorPart.Parent = nil
            burst.ImageColor3 = page.burst
            wallBase.BackgroundColor3 = WHITE
            if tunnel then
                tunnel.part:Destroy()
                tunnel = nil
            end

            Sfx.play("boom", 1, drama >= 5 and 0.8 or 1)
            Sfx.play("reveal" .. math.min(tier, 6), 1, 1)
            local pieces = (low and 10 or 20) + drama * (low and 2 or 6)
            for _ = 1, pieces do
                local size = rng:NextNumber(0.5, 1.8)
                local dir = room:VectorToWorldSpace(
                    Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.6, 1), rng:NextNumber(0.1, 1)).Unit
                )
                local colour = rng:NextNumber() < 0.6 and eggColor or (rng:NextNumber() < 0.5 and INK or PAPER)
                shard(
                    shellPos + dir * 3,
                    dir * rng:NextNumber(14, 38),
                    Vector3.new(0.14, size, size * rng:NextNumber(0.6, 1.4)),
                    colour,
                    rng:NextNumber(0.9, 1.5)
                )
            end

            -- W white, K black, C accent colour. More drama means more frames.
            local seq = ({ "W", "WK", "WKW", "WKCW", "KWCKWC", "WKCKWKCW" })[drama]
            st.focusColor = INK
            for i = 1, #seq do
                local kind = seq:sub(i, i)
                local on = kind == "K"
                wallBase.BackgroundColor3 = on and INK or (kind == "C" and accent or WHITE)
                heroLine.FillColor = on and WHITE or INK
                heroLine.OutlineColor = on and WHITE or INK
                st.focusColor = on and WHITE or INK
                st.focusA = drama >= 2 and 0 or 1
                local push = 0.74 + rng:NextNumber(0, 0.5)
                local shot = subject + (eyeEnd - subject) * push
                snapCamera(
                    shot,
                    subject + (lookEnd - subject) * 0.1,
                    44,
                    rng:NextNumber(-9, 9) * (drama >= 4 and 1 or 0.4) * (reduced and 0.3 or 1)
                )
                task.wait(i == #seq and 0.09 or 0.055)
            end

            -- 7. Colour comes back: the character in their pose, the camera swings round them
            st.hero = true
            wallBase.BackgroundColor3 = page.bg
            burst.Visible = true
            kanjiPart.Parent = fx
            floorPart.Parent = fx
            heroLine.FillTransparency = 1
            heroLine.OutlineColor = INK
            if mutInfo and res.mutation ~= "Rainbow" then
                heroLine.FillColor = mutInfo.color
                heroLine.FillTransparency = 0.82
            end
            st.rainbow = res.mutation == "Rainbow"
            barSize.to = 0
            st.focusColor = drama >= 3 and WHITE or INK
            st.focusA = drama >= 3 and 0.1 or 1
            anim(drama >= 5 and 1.5 or 0.8, function(u)
                st.focusA = (drama >= 3 and 0.1 or 1) + (drama >= 3 and 0.9 or 0) * K.smooth(u)
            end)
            flash.BackgroundColor3 = drama >= 3 and accent:Lerp(WHITE, 0.3) or WHITE
            flash.BackgroundTransparency = 0.05
            tween(flash, 0.26, { BackgroundTransparency = 1 })
            tween(cc, 0.1, { Contrast = 0.12, Saturation = 0.14, Brightness = 0 })

            local orbitFrom = room:VectorToWorldSpace(Vector3.new(drama >= 3 and -14 or 8, -2.4, -8))
            eyeAt.f, lookAt.f = 1.35, 2
            fov.f = 1.4
            snapCamera(eyeEnd + orbitFrom, lookEnd:Lerp(subject, 0.4), 50, dutch - 10)
            eyeAt.to, lookAt.to, fov.to, rollAt.to = eyeEnd, lookEnd, fovEnd, dutch
            st.trauma = math.min(0.35 + drama * 0.12, 1)
            if drama >= 3 then
                st.scale = 0.24
                anim(0.16, function(u)
                    st.scale = 0.24 + K.inCubic(u) * 0.76
                end)
            end

            local behind = subject + room:VectorToWorldSpace(Vector3.new(0, 0, -7))
            K.flip(fx, behind, "burst", {
                size = 22 + drama * 3,
                life = 0.55,
                color = tier == 1 and not bonus and PAPER or accent:Lerp(WHITE, 0.25),
                rot = rng:NextNumber(0, 360),
                z = -2,
            })
            if not low then
                K.sparks(fx, behind, 14 + drama * 12, accent:Lerp(WHITE, 0.3), 60, 3.5, 0.7)
            end

            -- rim light in the accent colour, the only coloured light in the room
            local rimColor = mutInfo and res.mutation ~= "Rainbow" and mutInfo.color or accent
            for side = -1, 1, 2 do
                local lamp = K.part(
                    fx,
                    Vector3.one,
                    CFrame.new(subject + room:VectorToWorldSpace(Vector3.new(side * 15, 6, -13)))
                )
                local light = Instance.new("PointLight")
                light.Color = rimColor
                light.Brightness = 0.8 + drama * 0.12
                light.Range = 24
                light.Parent = lamp
            end

            if not low then
                halftone.ImageColor3 = drama >= 3 and page.burst or INK
                halftone.ImageTransparency = drama >= 3 and 0.45 or 0.86
            end

            table.insert(
                conns,
                RunService.RenderStepped:Connect(function()
                    floorRing.Rotation = st.clock * 14
                    floorTwo.Rotation = -st.clock * 22
                end)
            )
            task.delay(1.6, function()
                if gui.Parent then
                    eyeAt.f, lookAt.f = 0.18, 0.18
                    eyeAt.to = eyeEnd + room:VectorToWorldSpace(Vector3.new(-1.2, 0.2, -1))
                    lookAt.to = lookEnd + room:VectorToWorldSpace(Vector3.new(-0.5, 0, 0))
                end
            end)

            -- 8. Type. Everything lands on springs, one piece at a time.
            hold(0.2)
            local rise = Instance.new("Frame")
            rise.BackgroundTransparency = 1
            rise.AnchorPoint = Vector2.new(0, 1)
            rise.Position = UDim2.new(0, 30, 1, -30)
            rise.Size = UDim2.fromOffset(660, 372)
            rise.Rotation = -2
            rise.Parent = canvas

            local plate = K.image(rise, "plate", tier == 1 and PAPER or tierColor, 1)
            plate.Size = UDim2.fromOffset(660, 165)
            local display = tostring(res.name or res.characterId):upper()
            local logoKey = type(res.logoKey) == "string" and K.Art.Ids["logo_n_" .. res.logoKey] and res.logoKey
            local aspectName = logoKey and K.Art.Aspect["n_" .. logoKey] or math.max(4, #display * 0.62)
            local nameHeight = math.min(92, 570 / aspectName)
            local nameLogo = K.logo(rise, "n_" .. (logoKey or "_text"), nameHeight, display, WHITE, 3)
            nameLogo.Size = UDim2.fromOffset(nameHeight * aspectName, nameHeight)
            local plateX = uiMotion.spring(-1000, 2.6, 0.72, function(v)
                plate.Position = UDim2.fromOffset(330 + v, 216)
            end)
            local nameX = uiMotion.spring(-1300, 2.4, 0.68, function(v)
                nameLogo.Position = UDim2.fromOffset(296 + v, 214)
            end)
            Sfx.play("whoosh", 0.6, 1.3)
            plateX.to, nameX.to = 0, 0

            task.wait(0.14)
            local rarityLogo, rarityScale = K.logo(rise, tierInfo.logo, 96, tierInfo.name, tierColor, 4)
            rarityLogo.AnchorPoint = Vector2.new(0, 0.5)
            rarityLogo.Position = UDim2.fromOffset(10, 62)
            rarityLogo.ImageTransparency = 1
            uiMotion.anim(0.05, function(u)
                rarityLogo.ImageTransparency = 1 - u
            end)
            local rarityPop = uiMotion.spring(3.2, 3.3, 0.5, function(v)
                rarityScale.Scale = v
            end)
            rarityPop.to = 1
            task.wait(0.08)
            Sfx.play("stamp", 0.9, 1.1 - tier * 0.05)
            st.trauma = math.max(st.trauma, 0.3)

            task.wait(0.06)
            for i = 1, tier do
                local star = K.image(rise, "star", tierColor:Lerp(WHITE, 0.2), 5)
                star.Position = UDim2.fromOffset(32 + (i - 1) * 46, 136)
                star.Size = UDim2.fromOffset(46, 46)
                local starScale = Instance.new("UIScale")
                starScale.Scale = 0
                starScale.Parent = star
                local pop = uiMotion.spring(0, 3.6, 0.42, function(v)
                    starScale.Scale = math.max(v, 0)
                end)
                pop.to = 1
                Sfx.play("tick", 0.7, 1 + i * 0.12)
                task.wait(0.07)
            end

            -- Power, income and the roll's quality (this replaces the separate Power card after a hatch).
            -- Power counts up on a log scale, so it passes through K -> M -> B instead of sitting on one unit.
            local power = math.max(tonumber(res.power) or 0, 0)
            local income = math.max(tonumber(res.income) or 0, 0)
            local fromPower = math.max(math.min(tonumber(res.basePower) or power * 0.1, power) * 0.5, 1)
            local qualityText = ""
            if qualityRank >= 2 and type(res.quality) == "string" then
                local qColor = typeof(res.qualityColor) == "Color3" and res.qualityColor or WHITE
                qualityText = string.format('  •  <font color="%s">%s ROLL</font>', hex(qColor), res.quality:upper())
            end
            local stats = Ui.text(rise, "", 30, WHITE, Enum.Font.LuckiestGuy)
            stats.RichText = true
            stats.AnchorPoint = Vector2.zero
            stats.Position = UDim2.fromOffset(30, 300)
            stats.Size = UDim2.fromOffset(640, 36)
            stats.TextXAlignment = Enum.TextXAlignment.Left
            local function showStats(shownPower)
                stats.Text = string.format(
                    "POWER %s  •  $%s/s%s",
                    Economy.Format(shownPower),
                    Economy.Format(income),
                    qualityText
                )
            end
            showStats(fromPower)
            if power > fromPower then
                uiMotion.anim(0.7, function(u)
                    local e = K.outCubic(u)
                    showStats(
                        u >= 1 and power or math.exp(math.log(fromPower) + (math.log(power) - math.log(fromPower)) * e)
                    )
                end)
            else
                showStats(power)
            end
            Sfx.play("tick", 0.6, 0.9)
            if qualityRank >= Config.BonusQualityRank then
                task.delay(0.7, function()
                    if gui.Parent then
                        Sfx.play("stamp", 1, 0.85)
                        st.trauma = math.max(st.trauma, 0.4)
                    end
                end)
            end

            local fromEgg =
                Ui.text(rise, "FROM THE " .. tostring(res.eggName or "EGG"):upper(), 20, WHITE, Enum.Font.GothamBlack)
            fromEgg.AnchorPoint = Vector2.zero
            fromEgg.Position = UDim2.fromOffset(30, 342)
            fromEgg.Size = UDim2.fromOffset(500, 24)
            fromEgg.TextXAlignment = Enum.TextXAlignment.Left

            if mutInfo then
                task.wait(0.1)
                local mLogo, mScale = K.logo(rise, "m_" .. res.mutation:lower(), 58, mutInfo.name, mutInfo.color, 6)
                mLogo.AnchorPoint = Vector2.new(0, 0.5)
                mLogo.Position = UDim2.fromOffset(14, 2)
                local mPop = uiMotion.spring(2.2, 3.3, 0.52, function(v)
                    mScale.Scale = v
                end)
                mPop.to = 1
                -- 2026-11-12: Molten has no seal art yet; skip the stamp instead of showing a blank paper square
                local hasSeal = K.Art.Ids["seal_" .. res.mutation:lower()] ~= nil
                local seal = Instance.new("Frame")
                seal.Visible = hasSeal
                seal.BorderSizePixel = 0
                seal.BackgroundColor3 = PAPER
                seal.AnchorPoint = Vector2.new(0.5, 0.5)
                seal.Position = UDim2.fromOffset(600, 66)
                seal.Size = UDim2.fromOffset(112, 112)
                seal.Rotation = -11
                seal.ZIndex = 7
                seal.Parent = rise
                local sealEdge = Instance.new("UIStroke")
                sealEdge.Thickness = 5
                sealEdge.Color = INK
                sealEdge.LineJoinMode = Enum.LineJoinMode.Miter
                sealEdge.Parent = seal
                local mark = K.image(seal, "seal_" .. res.mutation:lower(), Color3.fromRGB(214, 28, 40), 8)
                mark.Position = UDim2.fromScale(0.5, 0.5)
                mark.Size = UDim2.fromScale(1, 1)
                local sealScale = Instance.new("UIScale")
                sealScale.Parent = seal
                local sealPop = uiMotion.spring(3, 3.4, 0.5, function(v)
                    sealScale.Scale = v
                end)
                sealPop.to = 1
                task.wait(0.09)
                Sfx.play("stamp", 1, 1)
                st.trauma = math.max(st.trauma, 0.45)
                if not low then
                    K.sparks(fx, subject, 26, mutInfo.color, 70, 3.6, 0.7, res.mutation == "Diamond" and "star" or nil)
                end
            end

            -- COLLECT only closes the summon: the character waits in the incubator, picked up as before.
            local finished = false
            task.wait(0.2)
            local collect = Instance.new("ImageButton")
            collect.BackgroundTransparency = 1
            collect.Image = K.Art.Ids.slab or ""
            collect.ImageColor3 = Color3.fromRGB(58, 214, 104)
            collect.AnchorPoint = Vector2.new(1, 1)
            collect.Size = UDim2.fromOffset(228, 72)
            collect.ZIndex = 3
            collect.Parent = canvas
            local collectLogo = K.logo(collect, "collect", 46, "COLLECT", WHITE, 4)
            collectLogo.Position = UDim2.fromScale(0.5, 0.47)
            local collectScale = Instance.new("UIScale")
            collectScale.Parent = collect
            local collectY = uiMotion.spring(200, 2.8, 0.66, function(v)
                collect.Position = UDim2.new(1, -30, 1, -36 + v)
            end)
            collectY.to = 0
            collect.Activated:Connect(function()
                finished = true
            end)
            collect.MouseButton1Down:Connect(function()
                collectScale.Scale = 0.94
            end)
            collect.MouseButton1Up:Connect(function()
                collectScale.Scale = 1
            end)
            if UserInputService.GamepadEnabled then
                GuiService.SelectedObject = collect
            end

            local holdUntil = os.clock() + Config.HoldSeconds
            while not finished and os.clock() < holdUntil and gui.Parent do
                task.wait()
            end
            if GuiService.SelectedObject == collect then
                GuiService.SelectedObject = nil
            end

            -- 9. Out: the shutters sweep across, the world comes back behind them, they sweep off
            Sfx.play("shut", 0.6, 1.2)
            for i, f in shutters do
                uiMotion.anim(0.2, function(u)
                    f.Position = UDim2.fromScale(i / 3 - 1 / 6, -1 + 1.5 * K.outCubic(u))
                end)
                task.wait(0.03)
            end
            task.wait(0.2)
            canvas.Visible = false
            halftone.ImageTransparency = 1
            st.focusA = 1
            st.room = false
            heroPoint = nil
            st.rainbow = false
            c:Destroy()
            wallPart.Parent = nil
            kanjiPart.Parent = nil
            floorPart:Destroy()
            tween(cc, 0.3, { Contrast = 0, Saturation = 0, Brightness = 0 })
            eyeAt.f, lookAt.f, fov.f = 2.4, 2.4, 2.4
            snapCamera(worldEye, origin, 44)
            eyeAt.to = st.fromCf.Position
            lookAt.to = st.fromCf.Position + st.fromCf.LookVector * 18
            fov.to = st.fromFov
            task.wait(0.06)
            Sfx.play("whoosh", 0.45, 1.5)
            for i, f in shutters do
                uiMotion.anim(0.24, function(u)
                    f.Position = UDim2.fromScale(i / 3 - 1 / 6, 0.5 + 1.2 * K.inCubic(u))
                end)
                task.wait(0.02)
            end
            task.wait(0.4)
        end)
        if not ok then
            warn("[SummonHatch] animation error: " .. tostring(err))
        end

        -- Cleanup, always runs
        RunService:UnbindFromRenderStep(BIND)
        for _, conn in conns do
            conn:Disconnect()
        end
        for part in hidden do
            if part.Parent then
                part.LocalTransparencyModifier = 0
            end
        end
        for e in sceneDof do
            e.Enabled = true
        end
        cam.CameraType = st.fromType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or st.fromType
        cam.CameraSubject = st.fromSubject
        cam.FieldOfView = st.fromFov
        if hrp and hrp.Parent then
            cam.CFrame = st.fromCf
        end
        ContextActionService:UnbindAction(LOCK_ACTION)
        if controls then
            pcall(function()
                controls:Enable()
            end)
        end
        for _, x in maid do
            x:Destroy()
        end
        Ui.setHud(true)
        Roll.busy = false
        onDone()
    end)
end

return Roll
