-- CinematicHatch (LocalScript, StarterPlayerScripts)
-- Local hatch cinematic for the incubators. The server owns timing, rewards and machine
-- state; this script only draws. Everyone nearby sees the egg break; only the player who
-- pressed Hatch gets the camera, sound duck and control lock.
--
-- Physical cracking: the egg meshes are split into real shell sections with EditableMesh
-- (triangles grouped by fracture cell, original UVs + SurfaceAppearance kept), so the
-- intact egg looks identical and the pieces part along voxel-stepped fracture lines.
-- A warm core inside the shell is what you see through the opening seams.
--
-- Server contract:
--   tags  "IncubatorEgg" (egg models with a ChamberHome CFrame attribute; shell is pre-built)
--         "CinematicEggHatch" (hatch running; HatchEpoch = server start time, HatchDuration seconds)
--   ReplicatedStorage.CinematicHatchCue  server -> owner  (action, chamber, home, value, intro, cameraToken)
--         actions: "Start" (value = duration) | "HatchStarted" | "Reveal" (value = character name) | "End"
--   ReplicatedStorage.HatchCameraReady   owner -> server  (cameraToken), once the camera has settled
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local AssetService = game:GetService("AssetService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local ContextActionService = game:GetService("ContextActionService")
local _Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local cinematicHatchCue = game.ReplicatedStorage:WaitForChild("CinematicHatchCue")
local UISound = require(game.ReplicatedStorage:WaitForChild("UISound"))

local BASE_DURATION = 5.6 -- timeline below is written for a 5.6 s hatch and scaled to the real one
local NEAR_DISTANCE = 120 -- shells are only built / animated within this camera distance
local TAU = math.pi * 2
local CORE_COLOR = Color3.fromRGB(255, 236, 196)
-- Sounds are not set yet. Hook points are marked "SOUND:" below (hum start, each crack, release);
-- the crack and release hooks already play UISound cues.
-- shake beats: first fracture is a single jolt, then bursts grow with shorter pauses
--   t = start (timeline s), amp = tilt degrees, len = burst s, open = cells whose seam opens,
--   vol / pitch = crack sound, axis = tilt direction (radians)
local BEATS = {
    { t = 0.95, amp = 6, len = 0.28, cycles = 1, open = { 1, 2 }, vol = 0.5, pitch = 1.05, axis = 0.6 },
    { t = 1.85, amp = 4, len = 0.38, cycles = 2, open = { 3 }, vol = 0.42, pitch = 1.2, axis = 2.2 },
    { t = 2.55, amp = 6, len = 0.42, cycles = 2.5, open = { 4, 5 }, vol = 0.5, pitch = 1.3, axis = 4.0 },
    { t = 3.15, amp = 8, len = 0.48, cycles = 3, open = { 6 }, vol = 0.6, pitch = 1.4, axis = 1.1 },
    { t = 3.7, amp = 10, len = 0.52, cycles = 3.5, open = {}, vol = 0.7, pitch = 1.5, axis = 3.1 },
    { t = 4.25, amp = 13, len = 0.62, cycles = 4.5, open = {}, vol = 0.8, pitch = 1.6, axis = 5.2 },
}
local WHITE_FROM, WHITE_TO, HOLD = 4.25, 5.0, 5.0 -- breaking point, then tension hold

local function wrapAngle(angle)
    return (angle + math.pi) % TAU - math.pi
end
local function smooth(x)
    x = math.clamp(x, 0, 1)
    return x * x * (3 - 2 * x)
end

local function newPart(props)
    local part = Instance.new("Part")
    part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
    for key, value in props do
        part[key] = value
    end
    return part
end

------------------------------------------------------------------------ fracture builder
-- cells: 1-2 cap halves, 3-6 body sectors, 7 base cup (stays put)
-- height = egg-box Y / size Y (about -0.5..0.5), angle = around the up axis (0 faces the walkway)
local function cellOf(height, angle)
    local capLine = 0.13 + 0.05 * math.sin(3 * angle + 1.3) + 0.025 * math.sin(7 * angle + 0.4)
    local baseLine = -0.29 + 0.035 * math.sin(4 * angle + 2.1)
    if height > capLine then
        return wrapAngle(angle - (0.18 + 0.9 * (height - capLine))) < 0 and 1 or 2
    elseif height < baseLine then
        return 7
    end
    local sectorAngle = (angle - 0.55 - 0.2 * math.sin(9 * height + 2 * angle) - 0.07 * math.sin(23 * height + angle))
        % TAU
    return 3 + math.floor(sectorAngle / (TAU / 4)) % 4
end

local meshSources = {} -- MeshId -> {em, center, size, faces = {{a, b, c, uvs, normals, centroid}}}
-- Reads a mesh once (cached per MeshId). Yields: async mesh load + a frame every 1500 faces.
local function getMeshSource(meshId)
    local cached = meshSources[meshId]
    if cached then
        return cached
    end
    local editableMesh = AssetService:CreateEditableMeshAsync(Content.fromUri(meshId))
    local minCorner, maxCorner = Vector3.one * math.huge, -Vector3.one * math.huge
    for _, vertexId in editableMesh:GetVertices() do
        local position = editableMesh:GetPosition(vertexId)
        minCorner = minCorner:Min(position)
        maxCorner = maxCorner:Max(position)
    end
    cached = { em = editableMesh, center = (minCorner + maxCorner) / 2, size = maxCorner - minCorner, faces = {} }
    for i, faceId in editableMesh:GetFaces() do
        local vertexIds = editableMesh:GetFaceVertices(faceId)
        local p1, p2, p3 =
            editableMesh:GetPosition(vertexIds[1]),
            editableMesh:GetPosition(vertexIds[2]),
            editableMesh:GetPosition(vertexIds[3])
        local uvs, normals = {}, {}
        for k, uvId in editableMesh:GetFaceUVs(faceId) do
            uvs[k] = editableMesh:GetUV(uvId)
        end
        local okNormals, normalIds = pcall(editableMesh.GetFaceNormals, editableMesh, faceId)
        if okNormals then
            for k, normalId in normalIds do
                normals[k] = editableMesh:GetNormal(normalId)
            end
        end
        cached.faces[i] = { p1, p2, p3, uvs, normals, (p1 + p2 + p3) / 3 }
        if i % 1500 == 0 then
            task.wait()
        end
    end
    meshSources[meshId] = cached
    return cached
end

-- Returns {pieces = {[cell] = {parts = {{part, rel}}, dir, meshes}}} or nil
-- Yields (mesh loads + a frame every 1500 triangles); returns nil if the egg is removed meanwhile.
local function buildFracture(egg)
    local box, size = egg:GetBoundingBox()
    local pivot = egg:GetPivot()
    local pieces, sums, glow = {}, {}, {}
    for _, meshPart in egg:GetDescendants() do
        -- (the egg is still fading in when this runs, so its parts may read Transparency 1)
        if meshPart:IsA("MeshPart") and meshPart.MeshId ~= "" then
            local source = getMeshSource(meshPart.MeshId)
            if not egg.Parent then
                return nil
            end
            local scale = meshPart.Size / source.size
            -- sort triangles into fracture cells (by centroid, in egg-box space) and sum cell centroids
            local buckets = {}
            for _, face in source.faces do
                local world = meshPart.CFrame:PointToWorldSpace((face[6] - source.center) * scale)
                local localPos = box:PointToObjectSpace(world)
                local cell = cellOf(localPos.Y / size.Y, math.atan2(localPos.X, -localPos.Z)) -- angle 0 faces the walkway
                local bucket = buckets[cell]
                if not bucket then
                    bucket = {}
                    buckets[cell] = bucket
                end
                table.insert(bucket, face)
                local sum = sums[cell]
                if not sum then
                    sum = { Vector3.zero, 0 }
                    sums[cell] = sum
                end
                sum[1] += localPos
                sum[2] += 1
            end
            -- one new MeshPart per cell, rebuilt triangle by triangle
            local triangleCount = 0
            for cell, faces in buckets do
                local editableMesh = AssetService:CreateEditableMesh()
                local minCorner, maxCorner = Vector3.one * math.huge, -Vector3.one * math.huge
                for _, face in faces do
                    local vertexIds = {}
                    for k = 1, 3 do
                        minCorner = minCorner:Min(face[k])
                        maxCorner = maxCorner:Max(face[k])
                        vertexIds[k] = editableMesh:AddVertex(face[k])
                    end
                    local newFace = editableMesh:AddTriangle(vertexIds[1], vertexIds[2], vertexIds[3])
                    if #face[4] == 3 then
                        editableMesh:SetFaceUVs(newFace, {
                            editableMesh:AddUV(face[4][1]),
                            editableMesh:AddUV(face[4][2]),
                            editableMesh:AddUV(face[4][3]),
                        })
                    end
                    if #face[5] == 3 then
                        pcall(function()
                            editableMesh:SetFaceNormals(newFace, {
                                editableMesh:AddNormal(face[5][1]),
                                editableMesh:AddNormal(face[5][2]),
                                editableMesh:AddNormal(face[5][3]),
                            })
                        end)
                    end
                    triangleCount += 1
                    if triangleCount % 1500 == 0 then
                        task.wait()
                    end
                end
                local part = AssetService:CreateMeshPartAsync(Content.fromObject(editableMesh))
                part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
                part.Size = ((maxCorner - minCorner) * scale):Max(Vector3.one * 0.02)
                -- a mesh made from an EditableMesh keeps its source origin (it is not re-centred)
                part.CFrame = meshPart.CFrame * CFrame.new(-source.center * scale)
                part.Material, part.Color, part.Transparency = meshPart.Material, meshPart.Color, 0
                part.CastShadow = meshPart.CastShadow
                local surfaceAppearance = meshPart:FindFirstChildOfClass("SurfaceAppearance")
                if surfaceAppearance then
                    surfaceAppearance:Clone().Parent = part
                end
                local piece = pieces[cell]
                if not piece then
                    piece = { parts = {}, meshes = {} }
                    pieces[cell] = piece
                end
                table.insert(piece.parts, { part = part, rel = pivot:ToObjectSpace(part.CFrame) })
                table.insert(piece.meshes, editableMesh)
            end
            -- inner glow: the same egg layer shrunk to 92%, only visible through the seams
            local glowPart = meshPart:Clone()
            for _, child in glowPart:GetChildren() do
                child:Destroy()
            end
            glowPart.Material, glowPart.Color, glowPart.Transparency, glowPart.CastShadow =
                Enum.Material.Neon, CORE_COLOR, 1, false
            glowPart.Anchored, glowPart.CanCollide, glowPart.CanTouch, glowPart.CanQuery = true, false, false, false
            glowPart.Size = meshPart.Size * 0.92
            local rel = pivot:ToObjectSpace(meshPart.CFrame)
            table.insert(glow, { part = glowPart, rel = CFrame.new(rel.Position * 0.92) * rel.Rotation })
        end
    end
    -- outward direction of each piece, from the egg centre to the piece's real centroid
    for cell, piece in pieces do
        local centroid = sums[cell][1] / sums[cell][2]
        local flat = Vector3.new(centroid.X, 0, centroid.Z)
        local dir = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
        if cell <= 2 then
            dir = (dir + Vector3.new(0, 1.4, 0)).Unit
        end
        piece.dir = dir
        piece.cell = cell
    end
    if next(pieces) == nil then
        return nil
    end
    return { pieces = pieces, size = size, glow = glow }
end

------------------------------------------------------------------------ per-egg records
-- record.state: "building" -> "effects" (core light/sparkle ready) -> "ready" (shell pieces built)
local records = {} -- egg model -> record

local function hideOriginal(record, hidden)
    for _, part in record.egg:GetDescendants() do
        if part:IsA("BasePart") or part:IsA("Decal") then
            part.LocalTransparencyModifier = hidden and 1 or 0
        end
    end
end

local function cleanup(record)
    if record.dead then
        return
    end
    record.dead = true
    records[record.egg] = nil
    if record.hum then
        record.hum:Destroy()
    end
    if record.folder then
        record.folder:Destroy()
    end
    if record.fracture then
        for _, piece in record.fracture.pieces do
            for _, editableMesh in piece.meshes do
                editableMesh:Destroy()
            end
        end
    end
    if record.egg.Parent then
        hideOriginal(record, false)
    end
end

-- light, sparkles and highlight on an invisible core part at the egg home (parented to `folder`)
local function createCoreEffects(record, folder, home)
    -- invisible anchor for the light, sparkles and sounds
    record.core = newPart({
        Name = "HatchCore",
        Size = Vector3.one * 0.2,
        Transparency = 1,
        CastShadow = false,
        CFrame = home,
        Parent = folder,
    })
    record.light = Instance.new("PointLight")
    record.light.Color = CORE_COLOR
    record.light.Range = 7
    record.light.Brightness = 0
    record.light.Shadows = false
    record.light.Parent = record.core
    record.sparkle = Instance.new("ParticleEmitter")
    record.sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    record.sparkle.Rate = 0
    record.sparkle.LightEmission = 0.9
    record.sparkle.LightInfluence = 0
    record.sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 250, 235), Color3.fromRGB(255, 214, 140))
    record.sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
    record.sparkle.Lifetime = NumberRange.new(0.45, 0.85)
    record.sparkle.Speed = NumberRange.new(2.5, 5)
    record.sparkle.Drag = 5
    record.sparkle.SpreadAngle = Vector2.new(180, 180)
    record.sparkle.Parent = record.core
    record.highlight = Instance.new("Highlight")
    record.highlight.FillColor = Color3.new(1, 1, 1)
    record.highlight.OutlineColor = CORE_COLOR
    record.highlight.FillTransparency = 1
    record.highlight.OutlineTransparency = 1
    record.highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    record.highlight.Adornee = folder
    record.highlight.Parent = folder
end

-- Creates the record for an incubator egg and builds its effects + shell in a background thread.
local function prepare(egg)
    if records[egg] or not egg:IsA("Model") then
        return
    end
    local home = egg:GetAttribute("ChamberHome")
    if typeof(home) ~= "CFrame" then
        return
    end
    local record = { egg = egg, home = home, state = "building" }
    records[egg] = record
    task.spawn(function()
        -- only build for eggs the camera is near (checked until it is)
        while
            not record.dead
            and egg.Parent
            and (workspace.CurrentCamera.CFrame.Position - home.Position).Magnitude > NEAR_DISTANCE
        do
            task.wait(1)
        end
        if record.dead or not egg.Parent then
            return
        end
        local folder = Instance.new("Folder")
        folder.Name = "LocalHatchShell"
        record.folder = folder
        local _, size = egg:GetBoundingBox()
        record.size = size
        createCoreEffects(record, folder, home)
        record.state = "effects" -- enough to animate the intact egg if the shell isn't ready in time
        local ok, result = pcall(buildFracture, egg)
        if record.dead then
            if ok and result then
                for _, piece in result.pieces do
                    for _, editableMesh in piece.meshes do
                        editableMesh:Destroy()
                    end
                end
            end
            return
        end
        if not ok or not result then
            -- EditableMesh off (Game Settings > Security) or mesh not accessible: the intact egg
            -- still gets the full timing, light, whitening and release, just without shell pieces
            warn("Hatch fracture unavailable, using intact egg: " .. tostring(result))
            return
        end
        record.fracture = result
        if record.shown then
            return
        end -- already hatching with the intact egg; never swap mid-sequence
        for _, piece in result.pieces do
            piece.gap, piece.target = 0, 0
            for _, entry in piece.parts do
                entry.part.Parent = folder
            end
        end
        for _, glowEntry in result.glow do
            glowEntry.part.Parent = folder
        end
        record.state = "ready"
    end)
end

local function startHatch(egg)
    prepare(egg)
    local record = records[egg]
    if not record then
        return
    end
    record.epoch = egg:GetAttribute("HatchEpoch") or workspace:GetServerTimeNow()
    record.duration = egg:GetAttribute("HatchDuration") or BASE_DURATION
    record.hatching = true
    record.beat = 0
end

CollectionService:GetInstanceAddedSignal("IncubatorEgg"):Connect(prepare)
CollectionService:GetInstanceAddedSignal("CinematicEggHatch"):Connect(startHatch)
CollectionService:GetInstanceRemovedSignal("CinematicEggHatch"):Connect(function(egg)
    local record = records[egg]
    if record and not record.released then
        cleanup(record)
    end -- released shells finish their fall
end)
for _, egg in CollectionService:GetTagged("IncubatorEgg") do
    prepare(egg)
end
for _, egg in CollectionService:GetTagged("CinematicEggHatch") do
    startHatch(egg)
end

------------------------------------------------------------------------ owner session
local gui = Instance.new("ScreenGui")
gui.Name = "CinematicHatchUI"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 160
gui:SetAttribute("Active", false)
gui.Parent = player:WaitForChild("PlayerGui")
local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.new(1, 1, 1)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = gui
local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 1)
title.Position = UDim2.fromScale(0.5, 0.9)
title.Size = UDim2.fromOffset(460, 48)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 233, 167)
title.TextStrokeTransparency = 0.3
title.Font = Enum.Font.GothamBold
title.TextSize = 27
title.Text = ""
title.TextTransparency = 1
title.Parent = gui

local session -- the owner's camera session, or nil when no cinematic is running for this player
-- Plays a Sine InOut tween; tweens made during a session are cancelled when it finishes.
local function tween(instance, duration, props, style)
    local tweenObject = TweenService:Create(
        instance,
        TweenInfo.new(duration, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
        props
    )
    tweenObject:Play()
    if session then
        table.insert(session.tweens, tweenObject)
    end
    return tweenObject
end

-- Ends the owner session and restores camera, controls, hidden parts, ducked sounds and the UI.
local function finish()
    local endedSession = session
    if not endedSession then
        return
    end
    session = nil
    for _, tweenObject in endedSession.tweens do
        tweenObject:Cancel()
    end
    for _, connection in endedSession.connections do
        connection:Disconnect()
    end
    ContextActionService:UnbindAction("CinematicHatchLock")
    local cam = workspace.CurrentCamera
    if cam then
        cam.CameraType = endedSession.camType
        cam.CameraSubject = endedSession.subject
        cam.FieldOfView = endedSession.fov
        if endedSession.camType == Enum.CameraType.Scriptable then
            cam.CFrame = endedSession.original
        end
    end
    for instance, modifier in endedSession.hidden do
        if instance.Parent then
            instance.LocalTransparencyModifier = modifier
        end
    end
    for snd, volume in endedSession.ducked do
        if snd.Parent then
            snd.Volume = volume
        end
    end
    if endedSession.controls then
        pcall(function()
            endedSession.controls:Enable()
        end)
    end
    if endedSession.cc then
        endedSession.cc:Destroy()
    end
    flash.BackgroundTransparency = 1
    title.Text = ""
    title.TextTransparency = 1
    gui:SetAttribute("Active", false)
end

-- sets LocalTransparencyModifier, remembering the first original value for finish()
local function hideInstance(activeSession, instance, value)
    if activeSession.hidden[instance] == nil then
        activeSession.hidden[instance] = instance.LocalTransparencyModifier
    end
    instance.LocalTransparencyModifier = value
end

local function hideAvatars(activeSession)
    for _, other in Players:GetPlayers() do
        local char = other.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root and (root.Position - activeSession.home.Position).Magnitude < 40 then
            for _, part in char:GetDescendants() do
                if part:IsA("BasePart") or part:IsA("Decal") then
                    hideInstance(activeSession, part, 1)
                end
            end
        end
    end
end

-- Starts the owner session: takes the camera, locks controls, hides prompts / glass / avatars,
-- ducks playing sounds, and restores everything on death, respawn or chamber removal.
local function begin(chamber, home, duration)
    finish()
    local cam = workspace.CurrentCamera
    local controls
    pcall(function()
        controls = require(player.PlayerScripts:FindFirstChild("PlayerModule")):GetControls()
    end)
    local activeSession = {
        chamber = chamber,
        home = home,
        duration = duration or BASE_DURATION,
        start = os.clock(),
        original = cam.CFrame,
        fov = cam.FieldOfView,
        camType = cam.CameraType,
        subject = cam.CameraSubject,
        controls = controls,
        hidden = {},
        ducked = {},
        tweens = {},
        connections = {},
    }
    session = activeSession
    -- Remove existing overlays before camera takeover; attribute listeners handle later cards.
    for _, overlay in player.PlayerGui:GetChildren() do
        if overlay:IsA("BillboardGui") and overlay.Name == "PromptCard" then
            overlay.Enabled = false
        end
    end
    local tutorial = player.PlayerGui:FindFirstChild("FirstHatchTutorial")
    if tutorial then
        tutorial.Enabled = false
    end
    gui:SetAttribute("Active", true)
    if controls then
        pcall(function()
            controls:Disable()
        end)
    end
    -- sink every player action at high priority while the cinematic runs
    ContextActionService:BindActionAtPriority("CinematicHatchLock", function()
        return Enum.ContextActionResult.Sink
    end, false, 3000, table.unpack(Enum.PlayerActions:GetEnumItems()))
    -- glass stays closed; just a little clearer for this player
    for _, part in chamber:GetDescendants() do
        if
            part:IsA("BasePart")
            and (part.Material == Enum.Material.Glass or part.Name:lower():find("glass") or part.Name:find("Pane"))
        then
            hideInstance(activeSession, part, 0.55)
        end
    end
    hideAvatars(activeSession)
    -- duck what is already playing
    for _, root in { workspace, SoundService } do
        for _, snd in root:GetDescendants() do
            if snd:IsA("Sound") and snd.Playing and snd.Volume > 0 and not snd:GetAttribute("HatchFX") then
                activeSession.ducked[snd] = snd.Volume
                tween(snd, 0.8, { Volume = snd.Volume * 0.4 })
            end
        end
    end
    activeSession.cc = Instance.new("ColorCorrectionEffect")
    activeSession.cc.Name = "HatchFlashGrade"
    activeSession.cc.Parent = Lighting
    -- restore if the player dies, respawns, or the machine disappears
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        table.insert(activeSession.connections, hum.Died:Connect(finish))
    end
    table.insert(activeSession.connections, player.CharacterRemoving:Connect(finish))
    table.insert(
        activeSession.connections,
        chamber.AncestryChanged:Connect(function()
            if not chamber:IsDescendantOf(workspace) then
                finish()
            end
        end)
    )
    cam.CameraType = Enum.CameraType.Scriptable
    title.Text = "HATCHING..."
    tween(title, 0.6, { TextTransparency = 0 })
end

cinematicHatchCue.OnClientEvent:Connect(function(action, chamber, home, value, intro, cameraToken)
    if action == "Start" then
        begin(chamber, home, value)
        if session then
            session.intro = intro or 0
            session.cameraToken = cameraToken
        end
    elseif session and chamber == session.chamber then
        if action == "HatchStarted" then
            session.start = os.clock()
            session.intro = 0
        elseif action == "Reveal" then
            session.reveal = os.clock()
            session.home = home or session.home
            title.Text = tostring(value):upper() .. " UNLOCKED"
        elseif action == "End" then
            session.ending = os.clock()
        end
    end
end)

------------------------------------------------------------------------ frame update
-- `timelineTime` below is time on the BASE_DURATION-long beat timeline (real time rescaled)
local function shotFor(activeSession, timelineTime, elapsed)
    -- slow dolly toward the egg, tighter at the tension hold, ease back for the reveal
    local dist = 4.2 - 0.7 * smooth(timelineTime / WHITE_TO) - 0.35 * smooth((timelineTime - HOLD) / 0.6)
    if activeSession.reveal then
        dist += 5.5 * smooth((os.clock() - activeSession.reveal) / 0.3)
    end
    -- a slow orbit across the whole sequence gives the shot parallax
    local orbit = math.rad(-10 + 18 * smooth(elapsed / ((activeSession.intro or 0) + activeSession.duration + 1.5)))
    local eyeLocal = CFrame.Angles(0, orbit, 0)
        :VectorToWorldSpace(Vector3.new(0.35, 0.55 + 0.15 * smooth(timelineTime / BASE_DURATION), -dist))
    -- gentle handheld drift (very low frequency, never a shake)
    local drift = Vector3.new(math.noise(elapsed * 0.45, 7.1) * 0.05, math.noise(3.3, elapsed * 0.4) * 0.035, 0)
    local eye = activeSession.home:PointToWorldSpace(eyeLocal + drift)
    return CFrame.lookAt(eye, activeSession.home.Position + Vector3.new(0, 0.1, 0))
end

-- camera travel bends out through the open space in front of the glass, so the
-- transition never cuts through the incubator frame (quadratic Bezier, alpha 0..1)
local function arc(activeSession, from, to, alpha)
    local mid = activeSession.home:PointToWorldSpace(Vector3.new(0.35, 1.4, -7.5))
    local position = (1 - alpha) ^ 2 * from.Position + 2 * (1 - alpha) * alpha * mid + alpha ^ 2 * to.Position
    return CFrame.new(position) * from.Rotation:Lerp(to.Rotation, alpha)
end

-- egg tilt (tx, tz radians), lift (studs) and camera shake strength at a timeline time
local function beatPose(timelineTime)
    local tx, tz, lift, shake = 0, 0, 0, 0
    for _, beat in BEATS do
        local sinceBeat = timelineTime - beat.t
        if sinceBeat >= 0 and sinceBeat < beat.len then
            local x = sinceBeat / beat.len
            local env = (1 - x) ^ 2
            local wave = beat.cycles <= 1 and math.sin(x * math.pi) * math.exp(-3 * x) * 2
                or math.sin(x * beat.cycles * TAU)
            local attack = smooth(x / 0.12) -- eases into each burst instead of snapping
            local angle = math.rad(beat.amp) * env * wave * attack
            tx += angle * math.sin(beat.axis)
            tz += angle * math.cos(beat.axis)
            lift += math.abs(wave) * env * 0.012 * beat.amp
            shake = math.max(shake, env * beat.amp / 13)
        end
    end
    if timelineTime > HOLD then -- tension: almost still, a fine tremble
        local k = smooth((timelineTime - HOLD) / 0.3)
        tx += math.rad(0.7) * k * math.sin(timelineTime * 73)
        tz += math.rad(0.7) * k * math.sin(timelineTime * 61 + 1)
    end
    return tx, tz, lift, shake
end

-- shell bursts: sounds, sparkle, light flare, and a launch velocity / spin for every piece
local function release(record)
    record.released = true
    record.releaseAt = os.clock()
    -- SOUND: release / shatter
    UISound.Play("EggCrack", 1.25, 0.8)
    UISound.Play("Shine", 1.1, 0.55)
    record.sparkle:Emit(16)
    record.light.Brightness = 9
    record.light.Range = 11
    TweenService:Create(
        record.light,
        TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Brightness = 0, Range = 7 }
    ):Play()
    for _, glowEntry in record.glow do
        TweenService:Create(
            glowEntry.part,
            TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Transparency = 1 }
        ):Play()
    end
    TweenService:Create(record.highlight, TweenInfo.new(0.5), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
    for cell, piece in record.pieces do
        local still = cell == 7 -- the base cup stays where it is
        piece.vel = still and Vector3.zero
            or piece.dir * (2.4 + math.random() * 1.2) + Vector3.new(0, cell <= 2 and 3 or 1.9, 0)
        piece.spin = still and Vector3.zero
            or Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 6
        piece.pos, piece.rot = piece.dir * piece.gap, Vector3.zero
    end
end

-- egg intact or shell: one-time setup on the first animated frame
local function showRecord(record, timelineTime)
    -- first visible frame: pick shell or intact-egg fallback for the whole sequence
    record.shown = true
    record.shell = record.state == "ready"
    record.fallback = not record.shell
    record.pieces = record.shell and record.fracture.pieces or {}
    record.glow = record.shell and record.fracture.glow or {}
    -- joined late (walked up mid-hatch): skip beats already missed instead of firing them all at once
    while record.beat < #BEATS and timelineTime >= BEATS[record.beat + 1].t + 0.3 do
        record.beat += 1
        for _, cell in BEATS[record.beat].open do
            local piece = record.pieces[cell]
            if piece then
                piece.target = 0.035
            end
        end
    end
    if not record.fallback then
        hideOriginal(record, true)
    end
    record.highlight.Adornee = record.fallback and record.egg or record.folder
    record.folder.Parent = workspace
    -- SOUND: rising hum starts here
end

-- one frame before release: beat pose, crack beats, glow / light / highlight build-up, seams opening
local function animateHatching(record, sinceEpoch, timelineTime, half, dt)
    local tx, tz, lift, shake = beatPose(timelineTime)
    record.shake = shake
    -- tilt around the bottom contact point
    local pose = record.home * CFrame.new(0, -half + lift, 0) * CFrame.Angles(tx, 0, tz) * CFrame.new(0, half, 0)
    -- beats: crack sound, seam opens, light pops
    while record.beat < #BEATS and timelineTime >= BEATS[record.beat + 1].t do
        record.beat += 1
        local beat = BEATS[record.beat]
        for _, cell in beat.open do
            local piece = record.pieces[cell]
            if piece then
                piece.target = 0.035
            end
        end
        -- SOUND: crack (beat.vol / beat.pitch rise with each beat)
        UISound.Play(record.beat % 2 == 0 and "EggCrackAlt" or "EggCrack", beat.pitch, beat.vol)
        record.pop = 1
        record.sparkle:Emit(record.beat >= 4 and 3 or 1)
    end
    record.pop = math.max(0, (record.pop or 0) - dt * 5)
    local white = smooth((timelineTime - WHITE_FROM) / (WHITE_TO - WHITE_FROM))
    local progress = math.clamp(timelineTime / WHITE_TO, 0, 1)
    -- light leaking through the fractures
    -- the glow breathes between bursts and flares on each crack
    local breathe = 0.5 + 0.5 * math.sin(timelineTime * (3 + 5 * progress))
    for _, glowEntry in record.glow do
        glowEntry.part.CFrame = pose * glowEntry.rel
        glowEntry.part.Transparency = record.beat > 0
                and math.clamp(0.35 - 0.3 * breathe * progress - 0.35 * record.pop - white, 0, 1)
            or 1
    end
    record.light.Brightness = (record.beat > 0 and 0.4 or 0)
        + 2.2 * progress * progress
        + 0.6 * breathe * progress
        + 2.5 * record.pop
        + 3 * white
    record.highlight.FillTransparency = 1 - 0.88 * white
    record.highlight.OutlineTransparency = 1 - 0.5 * white
    -- SOUND: cut the hum at timelineTime > BASE_DURATION - 0.18 for a beat of silence before release
    for cell, piece in record.pieces do
        if white > 0 and cell ~= 7 then
            piece.target = math.max(piece.target, 0.035 + 0.045 * white)
        end
        piece.gap += (piece.target - piece.gap) * (1 - math.exp(-dt * 14))
        local capLift = cell <= 2 and 0.05 * smooth((timelineTime - HOLD) / 0.5) or 0
        local offset = CFrame.new(piece.dir * piece.gap + Vector3.new(0, capLift, 0))
        for _, entry in piece.parts do
            entry.part.CFrame = pose * offset * entry.rel
        end
    end
    record.core.CFrame = pose
    record.pose = pose
    if record.fallback then
        record.egg:PivotTo(pose)
    end
    if sinceEpoch >= record.duration then
        release(record)
    end
end

-- one frame after release: pieces fall inside the chamber and fade; the record is cleaned up after 1.7 s
local function animateRelease(record, half, dt)
    -- shell pieces fly a short way, land inside the chamber and fade
    local age = os.clock() - record.releaseAt
    local floorY = -half
    for cell, piece in record.pieces do
        if cell ~= 7 then
            -- floaty fall: softer gravity plus air drag, so the shell drifts apart
            piece.vel -= Vector3.new(0, 18 * dt, 0)
            piece.vel *= math.exp(-1.8 * dt)
            piece.spin *= math.exp(-1.2 * dt)
            piece.pos += piece.vel * dt
            local flat = Vector3.new(piece.pos.X, 0, piece.pos.Z)
            if flat.Magnitude > 1.9 then -- stay inside the glass
                piece.pos = flat.Unit * 1.9 + Vector3.new(0, piece.pos.Y, 0)
                piece.vel = Vector3.new(0, piece.vel.Y, 0)
            end
            if piece.pos.Y < floorY + 0.3 then
                piece.pos = Vector3.new(piece.pos.X, floorY + 0.3, piece.pos.Z)
                piece.vel = Vector3.new(piece.vel.X * 0.4, 0, piece.vel.Z * 0.4)
                piece.spin *= 0.5
            end
            piece.rot += piece.spin * dt
        end
        local fade = smooth((age - (cell == 7 and 0.1 or 0.5)) / 0.6)
        local spinCF = CFrame.Angles(piece.rot.X, piece.rot.Y, piece.rot.Z)
        for _, entry in piece.parts do
            entry.part.CFrame = record.pose * CFrame.new(piece.pos) * spinCF * entry.rel
            entry.part.Transparency = fade
        end
    end
    if record.fallback and record.egg.Parent then
        local fade = smooth(age / 0.25)
        for _, part in record.egg:GetDescendants() do
            if part:IsA("BasePart") then
                part.LocalTransparencyModifier = fade
            end
        end
    end
    if age > 1.7 then
        cleanup(record)
    end
end

-- owner camera: intro fly-in, settled shot with shake, reveal flash, fly-back on "End"
local function updateOwnerCamera(cam, dt)
    local activeSession = session
    if not activeSession then
        return
    end
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    -- safety net: end the session if the chamber/humanoid is gone or the server never sent "End"
    if
        not activeSession.chamber:IsDescendantOf(workspace)
        or not hum
        or hum.Health <= 0
        or os.clock() - activeSession.start > activeSession.duration + (activeSession.intro or 0) + 6
    then
        finish()
        return
    end
    hideAvatars(activeSession) -- keeps late arrivals and respawned avatars out of the shot
    cam.CameraType = Enum.CameraType.Scriptable
    local intro = activeSession.intro or 0
    local elapsed = os.clock() - activeSession.start
    local timelineTime = math.max(0, elapsed - intro) * BASE_DURATION / activeSession.duration -- egg timeline starts after the intro
    -- zoom-in during the intro while the glass opens: moves at once, settles as the shell starts to crack
    local enter =
        TweenService:GetValue(math.clamp(elapsed / 0.2, 0, 1), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    if activeSession.cameraSettled then
        enter = 1
    end
    local target = shotFor(activeSession, timelineTime, elapsed)
    if enter < 1 then
        activeSession.smoothCF = arc(activeSession, activeSession.original, target, enter)
    else
        -- critically-damped follow: glides into every change instead of snapping
        activeSession.smoothCF = (activeSession.smoothCF or target):Lerp(target, 1 - math.exp(-dt * 9))
    end
    if enter >= 1 and not activeSession.cameraSettled then
        -- camera has arrived: tell the server (HatchCameraGate) so the reveal can start
        activeSession.cameraSettled = true
        activeSession.smoothCF = target
        cam.CFrame = target
        cam.FieldOfView = 55
        if activeSession.cameraToken then
            game.ReplicatedStorage.HatchCameraReady:FireServer(activeSession.cameraToken)
        end
    end
    local shot = activeSession.smoothCF
    local fov = activeSession.fov
        + (55 - activeSession.fov) * enter
        - 5 * smooth(timelineTime / WHITE_TO)
        + (activeSession.reveal and 6 * smooth((os.clock() - activeSession.reveal) / 0.8) or 0)
    -- restrained shake, only on the bursts
    local shake = 0
    for _, otherRecord in records do
        if otherRecord.home == activeSession.home then
            shake = otherRecord.shake or 0
        end
    end
    local amp = shake * 0.035
    if amp > 0 then
        shot *= CFrame.new(math.noise(elapsed * 23, 1) * amp, math.noise(2, elapsed * 23) * amp, 0) * CFrame.Angles(
            0,
            0,
            math.noise(elapsed * 19, 3) * amp * 0.4
        )
    end
    -- reveal flash: grows, peaks under the swap, clears gracefully (never fully opaque)
    if activeSession.reveal then
        local sinceReveal = os.clock() - activeSession.reveal
        local up, down = smooth(sinceReveal / 0.12), smooth((sinceReveal - 0.25) / 0.9)
        local flashAlpha = math.max(up, 0.73) * (1 - down) -- continues from the pre-flash, no dip
        flash.BackgroundTransparency = 1 - 0.55 * flashAlpha
        activeSession.cc.Brightness = 0.25 * flashAlpha
        activeSession.cc.Contrast = -0.1 * flashAlpha
    elseif timelineTime > BASE_DURATION - 0.1 then -- release happens just before the server's reveal cue arrives
        local flashAlpha = smooth((timelineTime - (BASE_DURATION - 0.1)) / 0.15)
        flash.BackgroundTransparency = 1 - 0.4 * flashAlpha
        activeSession.cc.Brightness = 0.18 * flashAlpha
    end
    if activeSession.ending then
        activeSession.exitFrom = activeSession.exitFrom or shot -- fly back from a fixed point, not a moving one
        local exit = TweenService:GetValue(
            math.clamp((os.clock() - activeSession.ending) / 1.0, 0, 1),
            Enum.EasingStyle.Sine,
            Enum.EasingDirection.InOut
        )
        cam.CFrame = arc(activeSession, activeSession.exitFrom, activeSession.original, exit)
        cam.FieldOfView = fov + (activeSession.fov - fov) * exit
        title.TextTransparency = exit
        if exit >= 1 then
            finish()
        end
    else
        cam.CFrame = shot
        cam.FieldOfView = fov
    end
end

-- Runs after the default camera (Camera + 3) so the owner shot overrides it each frame.
RunService:BindToRenderStep("CinematicHatch", Enum.RenderPriority.Camera.Value + 3, function(dt)
    local now = workspace:GetServerTimeNow()
    local cam = workspace.CurrentCamera

    for egg, record in records do
        if not egg:IsDescendantOf(workspace) and not record.released then
            cleanup(record)
        elseif
            record.hatching
            and (record.state == "ready" or record.state == "effects")
            and (record.released or (cam.CFrame.Position - record.home.Position).Magnitude < NEAR_DISTANCE)
        then
            local sinceEpoch = now - record.epoch
            local timelineTime = sinceEpoch * BASE_DURATION / record.duration
            local half = record.size.Y / 2
            if not record.shown then
                showRecord(record, timelineTime)
            end
            if not record.released then
                animateHatching(record, sinceEpoch, timelineTime, half, dt)
            else
                animateRelease(record, half, dt)
            end
        end
    end

    -- owner camera
    updateOwnerCamera(cam, dt)
end)
