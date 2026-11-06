-- SummonHatch.FxKit (ported from the HatchDemo): springs and timed curves instead of tweens, so motion
-- stays smooth at any frame rate and can be slowed down; unlit billboards, flipbook bursts and rendered logos.
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Art = require(script.Parent.HatchArt)

local K = {}
local SUB = 1 / 120

function K.outCubic(x)
    return 1 - (1 - x) ^ 3
end
function K.outQuint(x)
    return 1 - (1 - x) ^ 5
end
function K.inCubic(x)
    return x * x * x
end
function K.smooth(x)
    x = math.clamp(x, 0, 1)
    return x * x * (3 - 2 * x)
end
function K.outBack(x)
    return 1 + 2.7 * (x - 1) ^ 3 + 1.7 * (x - 1) ^ 2
end

-- A spring for a number or a Vector3. freq in cycles a second, damp 1 = settles without overshoot.
function K.spring(x, freq, damp)
    return { x = x, v = x * 0, to = x, f = freq, d = damp or 1 }
end

function K.stepSprings(list, dt)
    local n = math.clamp(math.ceil(dt / SUB), 1, 12)
    local h = dt / n
    for _, s in list do
        local w = 2 * math.pi * s.f
        for _ = 1, n do
            s.v += (((s.to - s.x) * w * w) - s.v * (2 * s.d * w)) * h
            s.x += s.v * h
        end
        if s.apply then
            s.apply(s.x)
        end
    end
end

-- One list of springs and one of timed curves, both stepped from a single render step.
function K.motion()
    local M = { springs = {}, anims = {} }
    function M.spring(x, freq, damp, apply)
        local s = K.spring(x, freq, damp)
        s.apply = apply
        table.insert(M.springs, s)
        return s
    end
    function M.anim(duration, fn, finished)
        table.insert(M.anims, { t = 0, d = duration, fn = fn, done = finished })
    end
    function M.step(dt)
        K.stepSprings(M.springs, dt)
        for i = #M.anims, 1, -1 do
            local a = M.anims[i]
            a.t += dt
            local u = math.min(a.t / a.d, 1)
            a.fn(u)
            if u >= 1 then
                table.remove(M.anims, i)
                if a.done then
                    a.done()
                end
            end
        end
    end
    return M
end

function K.part(parent, size, cf)
    local p = Instance.new("Part")
    p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
    p.CastShadow = false
    p.Transparency = 1
    p.Size = size or Vector3.one
    p.CFrame = cf or CFrame.identity
    p.Parent = parent
    return p
end

-- An unlit square that always faces the camera. It is a one-segment Beam, so it can be additive.
function K.bill(parent, name, color, additive, z)
    local p = K.part(parent)
    local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
    a0.Parent, a1.Parent = p, p
    local b = Instance.new("Beam")
    b.Attachment0, b.Attachment1 = a0, a1
    b.Texture = Art.Ids[name] or ""
    b.TextureMode = Enum.TextureMode.Stretch
    b.TextureLength = 1
    b.Segments = 1
    b.FaceCamera = true
    b.LightInfluence = 0
    b.LightEmission = additive and 1 or 0
    b.Brightness = 1
    b.ZOffset = z or 0
    b.Color = ColorSequence.new(color or Color3.new(1, 1, 1))
    b.Transparency = NumberSequence.new(1)
    b.Parent = p
    local B = { part = p, beam = b, shown = 1 }
    function B.set(pos, cameraCf, rot, size, transparency)
        p.CFrame = CFrame.new(pos) * cameraCf.Rotation * CFrame.Angles(0, 0, rot)
        a0.Position, a1.Position = Vector3.new(-size / 2, 0, 0), Vector3.new(size / 2, 0, 0)
        b.Width0, b.Width1 = size, size
        if math.abs(transparency - B.shown) > 0.004 then
            B.shown = transparency
            b.Transparency = NumberSequence.new(transparency)
        end
    end
    function B.color(c)
        b.Color = ColorSequence.new(c)
    end
    return B
end

-- A flat printed panel in the world. SurfaceGuis ignore the lighting, so art keeps its exact colours.
function K.panel(parent, w, h, cf, pxPerStud, face)
    local p = K.part(parent, Vector3.new(w, h, 0.2), cf)
    local s = Instance.new("SurfaceGui")
    s.Face = face or Enum.NormalId.Front
    s.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    s.CanvasSize = Vector2.new(math.floor(w * pxPerStud), math.floor(h * pxPerStud))
    s.LightInfluence = 0
    s.Brightness = 1
    s.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    s.ClipsDescendants = true
    s.Parent = p
    return s, p
end

function K.image(parent, name, color, z)
    local i = Instance.new("ImageLabel")
    i.BackgroundTransparency = 1
    i.BorderSizePixel = 0
    i.Image = Art.Ids[name] or ""
    i.ImageColor3 = color or Color3.new(1, 1, 1)
    i.AnchorPoint = Vector2.new(0.5, 0.5)
    i.ZIndex = z or 1
    i.Parent = parent
    return i
end

-- A rendered title, sized by height. Falls back to plain text if the image is missing, so a result can never read blank.
function K.logo(parent, name, height, fallback, color, z)
    local aspect = Art.Aspect[name] or 4
    local i = K.image(parent, "logo_" .. name, nil, z)
    i.Size = UDim2.fromOffset(height * aspect, height)
    if not Art.Ids["logo_" .. name] and fallback then
        local t = Instance.new("TextLabel")
        t.BackgroundTransparency = 1
        t.Size = UDim2.fromScale(1, 1)
        t.Font = Enum.Font.Bangers
        t.TextScaled = true
        t.Text = fallback
        t.TextColor3 = color or Color3.new(1, 1, 1)
        t.ZIndex = i.ZIndex
        t.Parent = i
    end
    local s = Instance.new("UIScale")
    s.Parent = i
    return i, s
end

-- One flipbook played once: emitter on a throwaway part, cleaned up after its life.
function K.flip(parent, pos, name, opts)
    opts = opts or {}
    local life = opts.life or 0.8
    local p = K.part(parent, Vector3.one, CFrame.new(pos))
    local e = Instance.new("ParticleEmitter")
    e.Texture = Art.Ids[name] or ""
    e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
    e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
    e.Lifetime = NumberRange.new(life)
    e.Speed = NumberRange.new(0)
    e.Rate = 0
    e.Rotation = NumberRange.new(opts.rot or 0)
    e.Size = NumberSequence.new(opts.size or 30)
    e.Color = ColorSequence.new(opts.color or Color3.new(1, 1, 1))
    e.LightInfluence = 0
    e.LightEmission = opts.add and 0.6 or 0
    e.Brightness = opts.bright or 1
    e.ZOffset = opts.z or 0
    e.TimeScale = opts.timeScale or 1
    e.Transparency = NumberSequence.new(0)
    e.LockedToPart = true
    e.Parent = p
    e:Emit(1)
    Debris:AddItem(p, life / (opts.timeScale or 1) + 0.5)
end

-- Thin sharp streaks thrown out from a point, stretched along their speed.
function K.sparks(parent, pos, count, color, speed, size, life, texture)
    local p = K.part(parent, Vector3.one, CFrame.new(pos))
    local e = Instance.new("ParticleEmitter")
    e.Texture = Art.Ids[texture or "spark"] or ""
    e.Orientation = texture and Enum.ParticleOrientation.FacingCamera or Enum.ParticleOrientation.VelocityParallel
    e.SpreadAngle = Vector2.new(180, 180)
    e.Speed = NumberRange.new(speed * 0.5, speed)
    e.Drag = 3
    e.Lifetime = NumberRange.new(life * 0.6, life)
    e.Rate = 0
    e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
    e.Color = ColorSequence.new(color)
    e.LightInfluence = 0
    e.LightEmission = texture and 0 or 0.5
    e.Brightness = 1.6
    e.Parent = p
    e:Emit(count)
    Debris:AddItem(p, life + 0.5)
end

function K.preload()
    local list = {}
    for _, id in Art.Ids do
        local i = Instance.new("ImageLabel")
        i.Image = id
        list[#list + 1] = i
    end
    task.spawn(function()
        pcall(function()
            ContentProvider:PreloadAsync(list)
        end)
    end)
end

K.Art = Art
return K
