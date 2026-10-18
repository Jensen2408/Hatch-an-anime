--[[ ReplicatedStorage.IncubatorController (ModuleScript)
Brings the viewer behaviour into Roblox for the imported incubators (L1 / L2 / L3):
  • sliding glass doors (GlassLeft / GlassRight slide 2.5 studs sideways into the frame)
  • egg shake, jade glow pulse, warm lantern lights (L3)
  • a full Hatch() sequence: shake → flash → doors open → character appears on the egg platform
Setup also fixes import details: clear glass, Neon glow parts, real PointLights.

USAGE (Script in ServerScriptService):
  local Incubator = require(game.ReplicatedStorage.IncubatorController)
  local inc = Incubator.new(workspace.Incubator_L1_Apprentice)
  inc:Hatch(game.ServerStorage.Characters.TideCaptain, workspace.MyEgg) -- egg model optional
  -- or: inc:Open()  inc:Close()  inc:Shake(1.5)

Public methods (contract): Incubator.new(model), :Open(t), :Close(t), :Shake(duration),
:PlaceEgg(egg), :Hatch(character, egg), :Destroy(). The live chambers (HatchGoo) use
new / Open / Close / Destroy; HatchFXServer creates one lazily for its default glass hooks.
Open/Close yield until the doors arrive and replicate the model attribute "DoorsOpen".
--]]
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Incubator = {}
Incubator.__index = Incubator

local SLIDE_DISTANCE = 2.5 -- studs each door travels (matches the design)
local JADE_COLOR = Color3.fromRGB(95, 224, 176)
local WARM_COLOR = Color3.fromRGB(255, 184, 102)
local GLOW_WORDS = { "Jade", "Backlight", "Indicator_Cell", "Eave_Light", "Crown_Jewel", "Liquid" }
local WARM_WORDS = { "Lantern_Glow" }

-- Plain (non-pattern) substring match against any of `words`.
local function nameHasAny(name, words)
    for _, word in words do
        if string.find(name, word, 1, true) then
            return true
        end
    end
    return false
end
local function findDescendant(root, name)
    return root:FindFirstChild(name, true)
end
-- `instance` itself (if it is a part) plus all descendant BaseParts.
local function partsOf(instance)
    local parts = {}
    if instance:IsA("BasePart") then
        parts[1] = instance
    end
    for _, descendant in instance:GetDescendants() do
        if descendant:IsA("BasePart") then
            table.insert(parts, descendant)
        end
    end
    return parts
end
-- Doors may be a single part or a Model.
local function pivotOf(instance)
    return instance:IsA("Model") and instance:GetPivot() or instance.CFrame
end
local function setPivot(instance, cframe)
    if instance:IsA("Model") then
        instance:PivotTo(cframe)
    else
        instance.CFrame = cframe
    end
end

function Incubator.new(model)
    assert(model and model:IsA("Model"), "Incubator.new needs the incubator Model")
    local self = setmetatable({ model = model, open = false, busy = false }, Incubator)
    local origin = model:GetPivot()
    self.right = origin.RightVector

    -- materials fixed for Roblox
    for _, part in partsOf(model) do
        part.Anchored = true
        if part.Name:find("Pane", 1, true) or part.Name:match("Glass%d*$") then
            part.Material = Enum.Material.Glass
            part.Transparency = 0.82
            part.CastShadow = false
        elseif part.Name == "TankLiquid" and part.Parent.Name == "LiquidSystemAndTrim" then
            part.Transparency = 1
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
        elseif nameHasAny(part.Name, GLOW_WORDS) then
            part.Material = Enum.Material.Neon
            part.Color = string.find(part.Name, "Dim", 1, true) and JADE_COLOR:Lerp(Color3.new(0, 0, 0), 0.45)
                or JADE_COLOR
            if string.find(part.Name, "Liquid", 1, true) then
                part.Transparency = 0.35
            end
        elseif nameHasAny(part.Name, WARM_WORDS) then
            part.Material = Enum.Material.Neon
            part.Color = WARM_COLOR
        end
    end

    -- doors: remember closed pivots; left slides toward -Right, right toward +Right (model space)
    -- The closed pivots are captured once here, so the model must not be moved after new().
    self.doors = {}
    for _, doorName in { "GlassLeft", "GlassRight" } do
        local door = findDescendant(model, doorName)
        if door then
            local doorBox = door:IsA("Model") and door:GetBoundingBox() or door.CFrame
            local side = (doorBox.Position - origin.Position):Dot(self.right)
            table.insert(self.doors, { obj = door, closed = pivotOf(door), dir = side >= 0 and 1 or -1 })
        end
    end

    -- egg spot = top centre of the egg platform
    local platform = findDescendant(model, "EggPlatform")
    if platform then
        local platformCFrame, platformSize
        if platform:IsA("Model") then
            platformCFrame, platformSize = platform:GetBoundingBox()
        else
            platformCFrame, platformSize = platform.CFrame, platform.Size
        end
        self.eggCF = CFrame.new(platformCFrame.Position + origin.UpVector * (platformSize.Y / 2)) * origin.Rotation
    else
        self.eggCF = origin * CFrame.new(0, 2.25, 1.5)
    end

    -- lights (GLB lights don't import)
    local fxHolder = Instance.new("Part")
    fxHolder.Name = "IncubatorFX"
    fxHolder.Transparency = 1
    fxHolder.Anchored = true
    fxHolder.CanCollide = false
    fxHolder.CanQuery = false
    fxHolder.CanTouch = false
    fxHolder.Size = Vector3.new(0.2, 0.2, 0.2)
    fxHolder.CFrame = self.eggCF * CFrame.new(0, 3.3, 0)
    fxHolder.Parent = model
    self.light = Instance.new("PointLight")
    self.light.Color = JADE_COLOR
    self.light.Brightness = 1.6
    self.light.Range = 11
    self.light.Shadows = false
    self.light.Parent = fxHolder
    for _, part in partsOf(model) do
        if nameHasAny(part.Name, WARM_WORDS) and not part:FindFirstChildOfClass("PointLight") then
            local lanternLight = Instance.new("PointLight")
            lanternLight.Color = WARM_COLOR
            lanternLight.Brightness = 0.9
            lanternLight.Range = 7
            lanternLight.Parent = part
        end
    end
    -- burst emitter for the hatch flash
    local burstAttachment = Instance.new("Attachment")
    burstAttachment.CFrame = fxHolder.CFrame:ToObjectSpace(self.eggCF * CFrame.new(0, 1.5, 0))
    burstAttachment.Parent = fxHolder
    local burstEmitter = Instance.new("ParticleEmitter")
    burstEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    burstEmitter.Rate = 0
    burstEmitter.LightEmission = 1
    burstEmitter.LightInfluence = 0
    burstEmitter.Color = ColorSequence.new(JADE_COLOR, Color3.fromRGB(255, 240, 200))
    burstEmitter.Speed = NumberRange.new(4, 9)
    burstEmitter.SpreadAngle = Vector2.new(180, 180)
    burstEmitter.Lifetime = NumberRange.new(0.5, 0.9)
    burstEmitter.Drag = 4
    burstEmitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
    burstEmitter.Parent = burstAttachment
    self.burst = burstEmitter

    -- idle glow breathing (paused while Hatch() drives the light); stops itself once the model is removed
    self._pulse = RunService.Heartbeat:Connect(function()
        if not model.Parent then
            self:Destroy()
            return
        end
        if not self.busy then
            self.light.Brightness = 1.4 + 0.4 * math.sin(os.clock() * 1.5)
        end
    end)
    return self
end

-- Models cannot be tweened by pivot directly: tween a NumberValue 0 -> 1 and lerp. Yields until done.
local function tweenPivot(target, fromCFrame, toCFrame, duration, easingStyle)
    local driver = Instance.new("NumberValue")
    local connection = driver.Changed:Connect(function(alpha)
        setPivot(target, fromCFrame:Lerp(toCFrame, alpha))
    end)
    local pivotTween = TweenService:Create(
        driver,
        TweenInfo.new(duration, easingStyle or Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
        { Value = 1 }
    )
    pivotTween:Play()
    pivotTween.Completed:Wait()
    connection:Disconnect()
    driver:Destroy()
end

-- Slides all doors to open/closed in parallel (with a slide sound) and yields until every door arrived.
function Incubator:_slide(open, duration)
    local soundHost = self.model.PrimaryPart or self.model:FindFirstChildWhichIsA("BasePart") or self.model
    if soundHost then
        local slideSound = Instance.new("Sound")
        slideSound.Name = "DoorSlideSound"
        slideSound.SoundId = "rbxassetid://9118297953" -- Robot Pneumatics Sweeping Piston Slides 6 (ProSoundEffects)
        slideSound.Volume = 0.25
        slideSound.PlaybackSpeed = 1.3
        slideSound.RollOffMaxDistance = 45
        slideSound.Parent = soundHost
        slideSound:Play()
        game:GetService("Debris"):AddItem(slideSound, 3)
    end
    local pendingDoors = 0
    for _, door in self.doors do
        pendingDoors += 1
        local target = open and (door.closed + self.right * (door.dir * SLIDE_DISTANCE)) or door.closed
        task.spawn(function()
            tweenPivot(door.obj, pivotOf(door.obj), target, duration or 0.7)
            pendingDoors -= 1
        end)
    end
    while pendingDoors > 0 do
        task.wait()
    end
    -- `open` only flips after the slide finished, so overlapping Open/Close calls both slide.
    self.open = open
    self.model:SetAttribute("DoorsOpen", open)
end
function Incubator:Open(duration)
    if not self.open then
        self:_slide(true, duration)
    end
end
function Incubator:Close(duration)
    if self.open then
        self:_slide(false, duration)
    end
end

function Incubator:PlaceEgg(egg)
    if not egg then
        return
    end
    local _, size = egg:GetBoundingBox()
    egg:PivotTo(self.eggCF * CFrame.new(0, size.Y / 2, 0))
    self.egg = egg
end

-- Wobbles the placed egg (and flickers the light) for `duration` seconds; yields. Without an egg it just waits.
function Incubator:Shake(duration)
    duration = duration or 1.6
    local egg = self.egg
    if not egg then
        task.wait(duration)
        return
    end
    local basePivot = egg:GetPivot()
    local startClock = os.clock()
    while os.clock() - startClock < duration do
        local elapsed = os.clock() - startClock
        local amplitude = math.min(1, elapsed * 4) * (0.45 + 0.55 * elapsed / duration) -- builds up toward the hatch
        local roll, pitch = math.sin(elapsed * 38) * 0.16 * amplitude, math.sin(elapsed * 29) * 0.07 * amplitude
        egg:PivotTo(
            basePivot
                * CFrame.new(0, math.abs(math.sin(elapsed * 19)) * 0.1 * amplitude, 0)
                * CFrame.Angles(pitch, 0, roll)
        )
        self.light.Brightness = 1.6 + 2.5 * amplitude * (0.5 + 0.5 * math.sin(elapsed * 25))
        task.wait()
    end
    egg:PivotTo(basePivot)
end

-- Full sequence. character: a Model to reveal (cloned). egg: optional egg Model already in the world.
function Incubator:Hatch(character, egg)
    if self.busy then
        return
    end
    self.busy = true
    if egg then
        self:PlaceEgg(egg)
    end
    self:Close(0.4)
    self:Shake(1.8)
    self.burst:Emit(60)
    self.light.Brightness = 6
    if self.egg then
        self.egg:Destroy()
        self.egg = nil
    end
    local revealed
    if character then
        revealed = character:Clone()
        local _, size = revealed:GetBoundingBox()
        revealed:PivotTo(self.eggCF * CFrame.new(0, size.Y / 2, 0) * CFrame.Angles(0, math.pi, 0)) -- face the walkway
        for _, part in partsOf(revealed) do
            part.Anchored = true
        end
        revealed.Parent = self.model
    end
    TweenService:Create(self.light, TweenInfo.new(0.8), { Brightness = 1.6 }):Play()
    self:Open(0.8)
    self.busy = false
    return revealed
end

-- Stops the idle pulse. The IncubatorFX part and lights stay in the model.
function Incubator:Destroy()
    if self._pulse then
        self._pulse:Disconnect()
        self._pulse = nil
    end
end

return Incubator
