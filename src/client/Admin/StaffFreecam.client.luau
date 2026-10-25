--[[ StarterPlayerScripts.StaffFreecam  (LocalScript)
Shift + P free camera for staff (owner + admins) and for players given freecam only with the terminal's
/setfreecam. Access = the player attribute "FreecamAccess" (AdminRoles.CanFreecam, set on join and after
SetAdmin / SetFreecam), so a revoked player loses it at once (an open freecam is closed). Roblox's built-in freecam only works for accounts that can edit
the place; this one replaces it for staff.

Controls while on: W / A / S / D move, E / Q up / down, hold right mouse to look around, mouse wheel = move speed,
Shift + P again = off. The character does not move (movement keys are sunk) and every ScreenGui + the core UI are
hidden, then restored exactly as they were.

Network authority: none needed. It only moves the local camera; there is no remote and nothing the server trusts.
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ===== Settings =====
local SPEED_DEFAULT = 32 -- studs/s
local SPEED_MIN, SPEED_MAX = 2, 400
local SPEED_STEP = 1.25 -- mouse wheel multiplies / divides the speed by this
local LOOK_SENSITIVITY = 0.25 -- degrees per mouse pixel
local SMOOTHING = 10 -- higher = snappier movement
local PITCH_LIMIT = 85 -- degrees

-- above PlayerModule's controls (Default priority), so sunk keys never reach the character or the built-in freecam
local INPUT_PRIORITY = Enum.ContextActionPriority.High.Value + 10
local MOVE_KEYS = {
    Enum.KeyCode.W,
    Enum.KeyCode.A,
    Enum.KeyCode.S,
    Enum.KeyCode.D,
    Enum.KeyCode.E,
    Enum.KeyCode.Q,
    Enum.KeyCode.Space,
}

local active = false
local saved -- { cameraType, cframe, fov, mouseBehavior, guis = {[ScreenGui]=true}, core = {[CoreGuiType]=bool} }
local yaw, pitch, velocity, speed = 0, 0, Vector3.zero, SPEED_DEFAULT
local renderConnection, wheelConnection

local function isAllowed()
    return player:GetAttribute("FreecamAccess") == true
end

local function axis(positive, negative)
    return (UserInputService:IsKeyDown(positive) and 1 or 0) - (UserInputService:IsKeyDown(negative) and 1 or 0)
end

local function hideInterface()
    saved.guis, saved.core = {}, {}
    for _, gui in playerGui:GetChildren() do
        if gui:IsA("ScreenGui") and gui.Enabled then
            saved.guis[gui] = true
            gui.Enabled = false
        end
    end
    for _, coreType in Enum.CoreGuiType:GetEnumItems() do
        if coreType ~= Enum.CoreGuiType.All then
            saved.core[coreType] = StarterGui:GetCoreGuiEnabled(coreType)
        end
    end
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
end

local function restoreInterface()
    for gui in saved.guis do
        if gui.Parent then
            gui.Enabled = true
        end
    end
    for coreType, enabled in saved.core do
        pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, enabled)
    end
end

local function step(deltaTime)
    local camera = workspace.CurrentCamera
    camera.CameraType = Enum.CameraType.Scriptable -- the camera scripts may reset it (e.g. on respawn)
    if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
        local delta = UserInputService:GetMouseDelta()
        yaw -= delta.X * LOOK_SENSITIVITY
        pitch = math.clamp(pitch - delta.Y * LOOK_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
    else
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end
    local rotation = CFrame.fromOrientation(math.rad(pitch), math.rad(yaw), 0)
    local input = Vector3.new(
        axis(Enum.KeyCode.D, Enum.KeyCode.A),
        axis(Enum.KeyCode.E, Enum.KeyCode.Q),
        axis(Enum.KeyCode.S, Enum.KeyCode.W)
    )
    local target = input.Magnitude > 0 and rotation:VectorToWorldSpace(input.Unit) * speed or Vector3.zero
    velocity = velocity:Lerp(target, math.min(1, deltaTime * SMOOTHING))
    camera.CFrame = CFrame.new(camera.CFrame.Position + velocity * deltaTime) * rotation
end

local function enable()
    if active or not isAllowed() then
        return
    end
    active = true
    local camera = workspace.CurrentCamera
    saved = {
        cameraType = camera.CameraType,
        cframe = camera.CFrame,
        fov = camera.FieldOfView,
        mouseBehavior = UserInputService.MouseBehavior,
    }
    local x, y = camera.CFrame:ToOrientation()
    pitch, yaw, velocity = math.deg(x), math.deg(y), Vector3.zero
    hideInterface()
    ContextActionService:BindActionAtPriority("StaffFreecamMove", function()
        return Enum.ContextActionResult.Sink
    end, false, INPUT_PRIORITY, table.unpack(MOVE_KEYS))
    wheelConnection = UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            local factor = input.Position.Z > 0 and SPEED_STEP or 1 / SPEED_STEP
            speed = math.clamp(speed * factor, SPEED_MIN, SPEED_MAX)
        end
    end)
    renderConnection = RunService.RenderStepped:Connect(step)
end

local function disable()
    if not active then
        return
    end
    active = false
    renderConnection:Disconnect()
    wheelConnection:Disconnect()
    ContextActionService:UnbindAction("StaffFreecamMove")
    restoreInterface()
    local camera = workspace.CurrentCamera
    camera.CameraType = saved.cameraType
    camera.CFrame = saved.cframe
    camera.FieldOfView = saved.fov
    UserInputService.MouseBehavior = saved.mouseBehavior
    saved = nil
end

-- Shift + P. Bound only while the player has access; sunk so Roblox's own freecam does not toggle as well.
local function onToggle(_, inputState)
    if inputState ~= Enum.UserInputState.Begin then
        return Enum.ContextActionResult.Pass
    end
    if
        not (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift))
        or UserInputService:GetFocusedTextBox()
    then
        return Enum.ContextActionResult.Pass
    end
    if active then
        disable()
    else
        enable()
    end
    return Enum.ContextActionResult.Sink
end

local function refreshAccess()
    if isAllowed() then
        ContextActionService:BindActionAtPriority("StaffFreecamToggle", onToggle, false, INPUT_PRIORITY, Enum.KeyCode.P)
    else
        ContextActionService:UnbindAction("StaffFreecamToggle")
        disable()
    end
end
player:GetAttributeChangedSignal("FreecamAccess"):Connect(refreshAccess)
refreshAccess()
