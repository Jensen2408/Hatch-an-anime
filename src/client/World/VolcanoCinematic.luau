--[[ StarterPlayerScripts.VolcanoCinematic (ModuleScript, client only): the cutscene at the start of the Volcano Eruption.
For about 27 seconds the camera leaves the player, flies in on the volcano and watches lava rise in its caldera and pour out through the
opening, then cuts away as the volcano blows. Everything extra exists only for the cutscene and is removed when it ends:
  * a small animated lava lake (VolcanoLavaPatch, the arena lava technology) that rises from the crater floor to the opening's lip
  * a temporary patch of ground around the volcano (nothing stands there; without it the mountain floats in the void)
  * letterbox bars, captions and a SKIP button; the game's other GUI and the player's controls are switched off, then restored
It is driven by the shared event clock (the time since VolcanoStart), so a player who joins mid-cutscene never sees a half cutscene:
the caller only starts it within the first couple of seconds. Skipping, dying, entering the arena or the event ending stops it at once.

  local cinematic = Cinematic.new({ Config = Config, volcano = volcano, opening = unitVector, templates = folder })
  cinematic:Start(startedAt)        -- server time the event started
  cinematic.active                  -- true while it runs ]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local LavaPatch = require(script.Parent:WaitForChild("VolcanoLavaPatch"))

local player = Players.LocalPlayer
local Cinematic = {}
Cinematic.__index = Cinematic

local function smooth(a, b, x)
    local q = math.clamp((x - a) / (b - a), 0, 1)
    return q * q * (3 - 2 * q)
end

-- uniform Catmull-Rom between p1 and p2 (p0 / p3 are the neighbours)
local function spline(p0, p1, p2, p3, u)
    local u2, u3 = u * u, u * u * u
    return 0.5
        * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2 + (-p0 + 3 * p1 - 3 * p2 + p3) * u3)
end

function Cinematic.new(env)
    return setmetatable({
        Config = env.Config,
        volcano = env.volcano,
        opening = env.opening, -- unit vector (flat) from the crater toward the opening
        templates = env.templates,
        active = false,
        finished = false,
    }, Cinematic)
end

-- Camera path: keyframes in seconds after the event starts. n = toward the opening (and the map), s = sideways.
function Cinematic:_keyframes()
    local c, v, cfg = self.volcano, self.volcano, self.Config
    local n = self.opening
    local s = Vector3.new(-n.Z, 0, n.X)
    local centre = Vector3.new(v.crater.X, 0, v.crater.Z)
    local floorY, lipY = v.base + cfg.LakeFloor, v.base + cfg.LipHeight
    local rimY = v.base + cfg.RimHeight
    local function at(offset, y)
        return centre + offset + Vector3.new(0, y, 0)
    end
    return {
        -- a wide establishing shot of the whole mountain over the map's edge
        { t = 0, pos = at(n * 1700, lipY - 330), target = at(Vector3.zero, lipY - 60), fov = 52 },
        { t = 5, pos = at(n * 1250 + s * 240, lipY - 250), target = at(Vector3.zero, lipY - 20), fov = 54 },
        -- in toward the opening: the lava can already be seen glowing inside
        { t = 11, pos = at(n * 560 - s * 130, lipY + 70), target = at(n * 60, lipY - 25), fov = 60 },
        -- right up to the lip, looking down into the rising lake
        { t = 16, pos = at(n * 250, lipY + 45), target = at(Vector3.zero, floorY + 25), fov = 66 },
        { t = 19, pos = at(n * 320 + s * 60, rimY + 90), target = at(Vector3.zero, lipY), fov = 68 },
        -- the blast at t = 20: pull back and up, so the fountain rises past the lens
        { t = 23, pos = at(n * 760 + s * 300, rimY + 190), target = at(Vector3.zero, rimY + 150), fov = 62 },
        { t = 27, pos = at(n * 1250 + s * 90, 340), target = at(Vector3.zero, rimY + 230), fov = 56 },
        -- a last wide shot: the lava pouring down the cone toward the river
        { t = 33, pos = at(n * 1750 + s * 420, 420), target = at(n * 260, rimY - 170), fov = 56 },
    }
end

function Cinematic:_buildGui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "VolcanoCinematic"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 1000
    gui.Parent = player:WaitForChild("PlayerGui")
    local function bar(position)
        local frame = Instance.new("Frame")
        frame.BackgroundColor3 = Color3.new(0, 0, 0)
        frame.BorderSizePixel = 0
        frame.Size = UDim2.new(1, 0, 0, 0)
        frame.Position = position
        frame.AnchorPoint = Vector2.new(0, position.Y.Scale)
        frame.Parent = gui
        return frame
    end
    local top, bottom = bar(UDim2.new(0, 0, 0, 0)), bar(UDim2.new(0, 0, 1, 0))
    local caption = Instance.new("TextLabel")
    caption.BackgroundTransparency = 1
    caption.AnchorPoint = Vector2.new(0.5, 1)
    caption.Position = UDim2.new(0.5, 0, 0.88, 0)
    caption.Size = UDim2.new(0.8, 0, 0, 56)
    caption.Font = Enum.Font.GothamBlack
    caption.TextScaled = true
    caption.TextColor3 = Color3.fromRGB(255, 214, 160)
    caption.TextStrokeTransparency = 0.3
    caption.TextStrokeColor3 = Color3.fromRGB(60, 10, 0)
    caption.TextTransparency = 1
    caption.Text = ""
    caption.Parent = gui
    local skip = Instance.new("TextButton")
    skip.AnchorPoint = Vector2.new(1, 1)
    skip.Position = UDim2.new(1, -20, 1, -18)
    skip.Size = UDim2.new(0, 120, 0, 38)
    skip.BackgroundColor3 = Color3.fromRGB(30, 20, 20)
    skip.BackgroundTransparency = 0.25
    skip.TextColor3 = Color3.new(1, 1, 1)
    skip.Font = Enum.Font.GothamBold
    skip.TextSize = 18
    skip.Text = "SKIP  \u{25B6}"
    skip.ZIndex = 5
    skip.Parent = gui
    Instance.new("UICorner", skip).CornerRadius = UDim.new(0, 8)
    local fade = Instance.new("Frame")
    fade.BackgroundColor3 = Color3.new(0, 0, 0)
    fade.BorderSizePixel = 0
    fade.Size = UDim2.fromScale(1, 1)
    fade.ZIndex = 4
    fade.BackgroundTransparency = 0
    fade.Parent = gui
    skip.Activated:Connect(function()
        self:Stop("skipped")
    end)
    self.gui, self.top, self.bottom, self.caption, self.fade = gui, top, bottom, caption, fade
end

function Cinematic:_hideWorldUi()
    self.hiddenGuis = {}
    for _, child in player:WaitForChild("PlayerGui"):GetChildren() do
        if child:IsA("ScreenGui") and child ~= self.gui and child.Enabled then
            child.Enabled = false
            table.insert(self.hiddenGuis, child)
        end
    end
    self.coreStates = {}
    for _, kind in { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Chat, Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.EmotesMenu, Enum.CoreGuiType.Health } do
        local ok, enabled = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, kind)
        if ok and enabled then
            self.coreStates[kind] = true
            pcall(StarterGui.SetCoreGuiEnabled, StarterGui, kind, false)
        end
    end
    -- the player cannot walk around while watching
    local ok, controls = pcall(function()
        return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 2)):GetControls()
    end)
    if ok and controls then
        self.controls = controls
        controls:Disable()
    end
end

function Cinematic:_restoreWorldUi()
    for _, gui in self.hiddenGuis or {} do
        if gui.Parent then
            gui.Enabled = true
        end
    end
    for kind in self.coreStates or {} do
        pcall(StarterGui.SetCoreGuiEnabled, StarterGui, kind, true)
    end
    if self.controls then
        self.controls:Enable()
    end
end

-- temporary ground: nothing stands around the volcano, so give the cutscene a horizon (it is removed at the end)
function Cinematic:_buildGround()
    local v = self.volcano
    local folder = Instance.new("Folder")
    folder.Name = "VolcanoCinematicGround"
    folder.Parent = workspace
    local size = 2048
    for gx = -1, 1 do
        for gz = -1, 1 do
            local tile = Instance.new("Part")
            tile.Anchored = true
            tile.CanCollide = false
            tile.CanTouch = false
            tile.CanQuery = false
            tile.CastShadow = false
            tile.Size = Vector3.new(size, 4, size)
            tile.Position = Vector3.new(v.crater.X + gx * size, v.base + 22 - 2, v.crater.Z + gz * size)
            tile.Material = Enum.Material.Plastic
            tile.MaterialVariant = "Incubator One Stud Cavity"
            tile.Color = Color3.fromRGB(70, 124, 66)
            tile.Parent = folder
        end
    end
    self.ground = folder
end

local CAPTIONS = {
    { 0.8, 5.2, "The volcano stirs..." },
    { 11.5, 16.5, "Lava is rising!" },
    { 20.3, 24.5, "ERUPTION!" },
    { 27.5, 32, "The river will run with lava..." },
}

function Cinematic:Start(startedAt)
    if self.active or self.finished then
        return
    end
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end
    self.active = true
    self.startedAt = startedAt
    self:_buildGui()
    self:_hideWorldUi()
    self:_buildGround()
    local cfg, v = self.Config, self.volcano
    local floorY, lipY = v.base + cfg.LakeFloor, v.base + cfg.LipHeight
    self.patch = LavaPatch.new({
        center = Vector3.new(v.crater.X, 0, v.crater.Z),
        radius = 100,
        level = floorY + 1.5,
        templates = self.templates,
        parent = workspace,
    })
    self.keyframes = self:_keyframes()
    self.savedType, self.savedFov = camera.CameraType, camera.FieldOfView
    camera.CameraType = Enum.CameraType.Scriptable
    self.blasted = false
    self.lastTime = 0
    RunService:BindToRenderStep("VolcanoCinematic", Enum.RenderPriority.Camera.Value + 5, function(dt)
        self:_step(dt)
    end)
    -- bars slide in, the black cover lifts
    local info = TweenInfo.new(1.2, Enum.EasingStyle.Sine)
    TweenService:Create(self.top, info, { Size = UDim2.new(1, 0, 0.1, 0) }):Play()
    TweenService:Create(self.bottom, info, { Size = UDim2.new(1, 0, 0.1, 0) }):Play()
    TweenService:Create(self.fade, TweenInfo.new(0.9), { BackgroundTransparency = 1 }):Play()
end

function Cinematic:_step(dt)
    local cfg = self.Config
    local now = workspace:GetServerTimeNow()
    local t = self.debugTime or (now - self.startedAt) -- debugTime freezes the cutscene at one moment (for testing shots)
    local total = cfg.CinematicSeconds
    local camera = workspace.CurrentCamera
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if t >= total or not camera or player:GetAttribute("ArenaIn") == true or (humanoid and humanoid.Health <= 0) then
        self:Stop("done")
        return
    end
    if not self.debugTime and workspace:GetAttribute("VolcanoStart") ~= self.startedAt then
        self:Stop("event ended")
        return
    end
    -- the camera: a spline through the keyframes
    local keys = self.keyframes
    local last = #keys
    local index = 1
    while index < last - 1 and t >= keys[index + 1].t do
        index += 1
    end
    local k1, k2 = keys[index], keys[index + 1]
    local k0, k3 = keys[math.max(1, index - 1)], keys[math.min(last, index + 2)]
    local u = math.clamp((t - k1.t) / (k2.t - k1.t), 0, 1)
    if index == 1 then
        u = u * u * (3 - 2 * u) -- ease out of the first shot
    end
    local position = spline(k0.pos, k1.pos, k2.pos, k3.pos, u)
    local target = spline(k0.target, k1.target, k2.target, k3.target, u)
    local fov = k1.fov + (k2.fov - k1.fov) * u
    -- rumble: builds toward the blast, a hard kick at it, then settles
    local blastAt = cfg.WarnSeconds
    local shake = 0.25 * smooth(8, blastAt, t) + 1.0 * math.exp(-math.max(0, t - blastAt) * 1.1) * (t >= blastAt and 1 or 0)
    local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * shake * 3
    camera.CameraType = Enum.CameraType.Scriptable -- keep it ours even if another script hands the camera back
    camera.CFrame = CFrame.lookAt(position + jitter, target + jitter * 0.5)
    camera.FieldOfView = fov
    -- the lava: rises from the crater floor to just under the opening's lip, then swells over it at the blast
    local v = self.volcano
    local floorY, lipY = v.base + cfg.LakeFloor, v.base + cfg.LipHeight
    local rise = smooth(2, blastAt - 0.5, t)
    local level = floorY + 1.5 + (lipY - 3 - (floorY + 1.5)) * rise
    if t >= blastAt then
        level = lipY - 3 + 9 * smooth(blastAt, blastAt + 1.4, t)
        if not self.blasted then
            self.blasted = true
            self.patch:Burst(now)
        end
    end
    self.patch:SetLevel(level)
    self.patch:Step(now)
    -- game popups that open while we are watching (offline earnings, daily rewards...) are put away too, and given back after
    if now - (self.lastSweep or 0) > 0.4 then
        self.lastSweep = now
        for _, child in player.PlayerGui:GetChildren() do
            if child:IsA("ScreenGui") and child ~= self.gui and child.Enabled then
                child.Enabled = false
                table.insert(self.hiddenGuis, child)
            end
        end
    end
    -- captions and the way out
    local label, alpha = "", 0
    for _, entry in CAPTIONS do
        if t >= entry[1] and t <= entry[2] then
            label = entry[3]
            alpha = smooth(entry[1], entry[1] + 0.6, t) * (1 - smooth(entry[2] - 0.6, entry[2], t))
        end
    end
    if label ~= "" then
        self.caption.Text = label
    end
    self.caption.TextTransparency = 1 - alpha
    self.caption.TextStrokeTransparency = 1 - 0.7 * alpha
    self.fade.BackgroundTransparency = math.min(self.fade.BackgroundTransparency, 1 - smooth(total - 1.0, total, t))
    if t > total - 1.0 then
        self.fade.BackgroundTransparency = 1 - smooth(total - 1.0, total, t)
    end
end

function Cinematic:Stop(reason)
    if not self.active then
        return
    end
    self.active = false
    self.finished = true
    pcall(RunService.UnbindFromRenderStep, RunService, "VolcanoCinematic")
    local camera = workspace.CurrentCamera
    if camera then
        camera.CameraType = Enum.CameraType.Custom
        camera.FieldOfView = self.savedFov or 70
    end
    if self.patch then
        self.patch:Destroy()
        self.patch = nil
    end
    if self.ground then
        self.ground:Destroy()
        self.ground = nil
    end
    self:_restoreWorldUi()
    -- cut back to the game from black, then clear the cover
    local gui = self.gui
    if gui then
        self.fade.BackgroundTransparency = 0
        TweenService:Create(self.fade, TweenInfo.new(0.7), { BackgroundTransparency = 1 }):Play()
        task.delay(0.8, function()
            gui:Destroy()
        end)
        self.top:Destroy()
        self.bottom:Destroy()
        self.caption:Destroy()
    end
    self.stopReason = reason
end

return Cinematic
