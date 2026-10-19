--[[ StarterPlayerScripts.CineCamClient  (LocalScript)
CineCam: an owner-only camera tool for recording trailer shots. A side panel (ScreenGui "CineCamUI", F6) lets you
free-fly the camera, drop up to 40 camera points (CFrame + FOV), save up to 25 named shots, and replay a shot as a
Catmull-Rom spline (optionally tracking a clicked model and optionally starting a Roblox CaptureService video capture).
F7 stops everything and restores the camera and UI.

Who can run it: UserId 168774222 (same id as CineCamServer.OWNER_ID; hard-coded here, NOT TrailerConfig.OwnerIds),
or UserId 0 in Studio. Everyone else returns before the remotes are awaited. The server re-checks on every call.

Remote contract (created by CineCamServer in ReplicatedStorage; payload shapes are contracts)
  CineCamOpen   RemoteEvent, server -> client, no payload. Fired when an allowed player types /film. The client then
                loads its shots and shows the panel.
  CineCamRemote RemoteFunction, client -> server:
    InvokeServer("load")         -> { ok = true, shots = { Shot } } | { ok = false, error = string }
    InvokeServer("save", shots)  -> { ok = true } | { ok = false, error = string }
    Shot  = { name = string (1-40), duration = number (1-29 s), points = { Point } (2-40) }
    Point = { cf = { 12 numbers from CFrame:GetComponents() }, fov = number (20-100) }
  The client applies the same limits before saving; a failed save keeps the shot for this session only.

State: points = the path being edited, shots = the saved shot list, playToken = generation counter that cancels a
running preview (stopAll / a new preview bump it), uiHidden = recording-mode hiding is active.
]]
-- ===== 1. Services and owner gate =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local CaptureService = game:GetService("CaptureService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
if player.UserId ~= 168774222 and not (RunService:IsStudio() and player.UserId == 0) then
    return
end

-- ===== 2. Remotes and panel GUI =====
local remote = ReplicatedStorage:WaitForChild("CineCamRemote")
local openEvent = ReplicatedStorage:WaitForChild("CineCamOpen")
local camera = workspace.CurrentCamera
local gui = Instance.new("ScreenGui")
gui.Name = "CineCamUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10000
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("ScrollingFrame")
panel.Name = "Controls"
panel.Size = UDim2.new(0, 330, 1, -32)
panel.Position = UDim2.new(1, -345, 0, 16)
panel.BackgroundColor3 = Color3.fromRGB(17, 22, 30)
panel.BackgroundTransparency = 0.08
panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
panel.CanvasSize = UDim2.new()
panel.ScrollBarThickness = 5
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local layout = Instance.new("UIListLayout", panel)
layout.Padding = UDim.new(0, 5)
layout.SortOrder = Enum.SortOrder.LayoutOrder
local padding = Instance.new("UIPadding", panel)
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)

-- ===== 3. Panel widget builders (appended in LayoutOrder) =====
local layoutOrder = 0
local function addLabel(message, height)
    layoutOrder += 1
    local item = Instance.new("TextLabel")
    item.LayoutOrder = layoutOrder
    item.Size = UDim2.new(1, 0, 0, height or 24)
    item.BackgroundTransparency = 1
    item.TextColor3 = Color3.fromRGB(235, 239, 245)
    item.Font = Enum.Font.Gotham
    item.TextSize = 13
    item.TextWrapped = true
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.Text = message
    item.Parent = panel
    return item
end
local function addButton(message, callback)
    layoutOrder += 1
    local item = Instance.new("TextButton")
    item.LayoutOrder = layoutOrder
    item.Size = UDim2.new(1, 0, 0, 34)
    item.BackgroundColor3 = Color3.fromRGB(38, 57, 75)
    item.TextColor3 = Color3.new(1, 1, 1)
    item.Font = Enum.Font.GothamMedium
    item.TextSize = 14
    item.Text = message
    item.Parent = panel
    Instance.new("UICorner", item).CornerRadius = UDim.new(0, 7)
    item.MouseButton1Click:Connect(function()
        callback(item)
    end)
    return item
end
local function addField(title, default)
    layoutOrder += 1
    local box = Instance.new("TextBox")
    box.LayoutOrder = layoutOrder
    box.Size = UDim2.new(1, 0, 0, 30)
    box.BackgroundColor3 = Color3.fromRGB(28, 37, 49)
    box.TextColor3 = Color3.new(1, 1, 1)
    box.PlaceholderText = title
    box.Text = default
    box.ClearTextOnFocus = false
    box.Font = Enum.Font.Gotham
    box.TextSize = 14
    box.Parent = panel
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
    return box
end

-- ===== 4. Panel header, input fields and state =====
addLabel("CINECAM  •  /film  •  F6 panel  •  F7 stop", 26)
local statusLabel = addLabel("Ready. Use Studio Play or join the game as owner.", 40)
local function setStatus(message)
    statusLabel.Text = message
end
local nameBox = addField("Shot name", "River Reveal")
local durationBox = addField("Duration in seconds (max 29)", "18")
local countdownBox = addField("Countdown in seconds", "5")
local fovBox = addField("Camera zoom / field of view (20 to 100)", "70")
local points = {}
local shots = {}
local target = nil
local pickingTarget = false
local flying = false
local playing = false
local recording = false
local uiHidden = false
local flySpeed = 30
local heldKeys = {}
local rightMouse = false
local originalCamera = nil
local hiddenGui = {}
local hiddenCore = {}
local hiddenConnections = {}
local frameGuide = nil
local guideMode = "Off"
local playToken = 0
local captureRunning = false

-- ===== 5. Recording mode: UI hiding and camera takeover =====
-- Hides (true) or restores (false) every CoreGui type, remembering each one's previous state.
local function setCoreHidden(shouldHide)
    for _, coreType in ipairs(Enum.CoreGuiType:GetEnumItems()) do
        if coreType ~= Enum.CoreGuiType.All then
            if shouldHide then
                local ok, enabled = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, coreType)
                if ok then
                    hiddenCore[coreType] = enabled
                    pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, false)
                end
            elseif hiddenCore[coreType] ~= nil then
                pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, hiddenCore[coreType])
            end
        end
    end
    if not shouldHide then
        table.clear(hiddenCore)
    end
end
-- Disables every ScreenGui / BillboardGui / SurfaceGui (except the panel) in PlayerGui and Workspace, including ones
-- added while hidden (DescendantAdded), and hides the panel. restoreVisualUI undoes it.
local function hideVisualUI()
    if uiHidden then
        return
    end
    uiHidden = true
    local function hideItem(item)
        if (item:IsA("ScreenGui") or item:IsA("BillboardGui") or item:IsA("SurfaceGui")) and item ~= gui then
            if hiddenGui[item] == nil then
                hiddenGui[item] = item.Enabled
            end
            item.Enabled = false
        end
    end
    for _, root in ipairs({ player.PlayerGui, workspace }) do
        for _, item in ipairs(root:GetDescendants()) do
            hideItem(item)
        end
        table.insert(hiddenConnections, root.DescendantAdded:Connect(hideItem))
    end
    setCoreHidden(true)
    gui.Enabled = false
end
local function restoreVisualUI()
    if not uiHidden then
        return
    end
    uiHidden = false
    for _, connection in ipairs(hiddenConnections) do
        connection:Disconnect()
    end
    table.clear(hiddenConnections)
    for item, enabled in pairs(hiddenGui) do
        if item.Parent then
            item.Enabled = enabled
        end
    end
    table.clear(hiddenGui)
    setCoreHidden(false)
    gui.Enabled = true
end
-- Makes the camera Scriptable, remembering the original type / subject / FOV the first time.
local function enterCamera()
    camera = workspace.CurrentCamera
    if not originalCamera then
        originalCamera = {
            cameraType = camera.CameraType,
            subject = camera.CameraSubject,
            fov = camera.FieldOfView,
            cf = camera.CFrame,
        }
    end
    camera.CameraType = Enum.CameraType.Scriptable
end
-- Note: originalCamera.cf is recorded but never restored (pre-existing).
local function exitCamera()
    if originalCamera then
        camera.CameraType = originalCamera.cameraType
        camera.CameraSubject = originalCamera.subject
        camera.FieldOfView = originalCamera.fov
        originalCamera = nil
    end
end
-- F7 / Stop button: cancels a preview, stops capture, restores UI + camera.
local function stopAll()
    playToken += 1
    playing = false
    flying = false
    if captureRunning then
        pcall(CaptureService.StopVideoCapture, CaptureService)
        captureRunning = false
    end
    restoreVisualUI()
    exitCamera()
    setStatus("Stopped. Camera and UI restored.")
end

-- ===== 6. Path math and persistence =====
local function cfArray(cframe)
    return { cframe:GetComponents() }
end
local function pointCF(point)
    return CFrame.new(table.unpack(point.cf))
end
-- Position of the tracked model / part; clears the target once it is destroyed.
local function targetPosition()
    if not target or not target.Parent then
        target = nil
        return nil
    end
    if target:IsA("Model") then
        return target:GetPivot().Position
    end
    if target:IsA("BasePart") then
        return target.Position
    end
    return nil
end
local function lerp(from, to, alpha)
    return from + (to - from) * alpha
end
-- Catmull-Rom spline point between p1 and p2.
local function catmull(p0, p1, p2, p3, t)
    local t2, t3 = t * t, t * t * t
    return 0.5 * ((p1 * 2) + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (-p0 + p1 * 3 - p2 * 3 + p3) * t3)
end
-- Places the camera at progress alpha (0..1) along the points, smoothstepped per segment. Looks at the tracked
-- target when there is one, otherwise slerps between the two neighbouring points' rotations.
local function cameraAt(path, alpha)
    local count = #path
    local scaled = math.clamp(alpha, 0, 1) * (count - 1)
    local segIndex = math.min(math.floor(scaled) + 1, count - 1)
    local localT = scaled - (segIndex - 1)
    localT = localT * localT * (3 - 2 * localT)
    local cf0 = pointCF(path[math.max(segIndex - 1, 1)])
    local cf1 = pointCF(path[segIndex])
    local cf2 = pointCF(path[segIndex + 1])
    local cf3 = pointCF(path[math.min(segIndex + 2, count)])
    local pos = catmull(cf0.Position, cf1.Position, cf2.Position, cf3.Position, localT)
    local aim = targetPosition()
    if aim and (aim - pos).Magnitude > 0.1 then
        camera.CFrame = CFrame.lookAt(pos, aim)
    else
        local orientation = cf1:Lerp(cf2, localT)
        camera.CFrame = CFrame.new(pos) * orientation.Rotation
    end
    camera.FieldOfView = lerp(path[segIndex].fov, path[segIndex + 1].fov, localT)
    camera.Focus = CFrame.new(aim or (pos + camera.CFrame.LookVector * 100))
end
-- Sends the whole shot list to the server (see the remote contract in the header).
local function saveShots()
    local ok, response = pcall(function()
        return remote:InvokeServer("save", shots)
    end)
    if not ok or not response or not response.ok then
        setStatus("Shot kept this session; cloud save failed: " .. tostring(response and response.error or response))
    else
        setStatus("Saved " .. #shots .. " shot(s).")
    end
end

-- ===== 7. Panel buttons (created in display order) =====
addButton("Free fly  •  WASD / Q E / right mouse", function()
    if playing then
        return
    end
    enterCamera()
    flying = not flying
    setStatus(flying and "Flying. Shift = faster, mouse wheel = speed." or "Fly paused. Add a point or replay.")
end)
addButton("Apply camera zoom", function()
    local value = tonumber(fovBox.Text)
    if not value or value < 20 or value > 100 then
        setStatus("Zoom value must be 20 to 100.")
        return
    end
    enterCamera()
    camera.FieldOfView = value
    setStatus("Camera field of view set to " .. value .. ". Add a point to save it.")
end)
addButton("Set camera point", function()
    if playing then
        return
    end
    if #points >= 40 then
        setStatus("Maximum 40 points.")
        return
    end
    local cameraCF = camera.CFrame
    table.insert(points, { cf = cfArray(cameraCF), fov = camera.FieldOfView })
    setStatus("Point " .. #points .. " saved with position, direction, and zoom.")
end)
addButton("Track object under mouse / clear tracking", function()
    if target then
        target = nil
        setStatus("Tracking cleared.")
        return
    end
    pickingTarget = true
    setStatus("Click an egg, player, or model in the world to track it.")
end)
addButton("Undo last point", function()
    if playing then
        return
    end
    if #points > 0 then
        table.remove(points)
        setStatus(#points .. " points remain.")
    end
end)
addButton("Save current shot", function()
    if #points < 2 then
        setStatus("Add at least two camera points.")
        return
    end
    local duration = tonumber(durationBox.Text)
    if not duration or duration < 1 or duration > 29 then
        setStatus("Duration must be 1 to 29 seconds.")
        return
    end
    local name = nameBox.Text:sub(1, 40)
    if name == "" then
        setStatus("Enter a shot name.")
        return
    end
    for index, shot in ipairs(shots) do
        if shot.name == name then
            table.remove(shots, index)
            break
        end
    end
    if #shots >= 25 then
        setStatus("Maximum 25 saved shots.")
        return
    end
    table.insert(shots, { name = name, duration = duration, points = table.clone(points) })
    saveShots()
end)
addButton("Load named shot", function()
    for _, shot in ipairs(shots) do
        if shot.name == nameBox.Text then
            points = table.clone(shot.points)
            durationBox.Text = tostring(shot.duration)
            setStatus("Loaded " .. shot.name .. " with " .. #points .. " points.")
            return
        end
    end
    setStatus("No saved shot with that exact name.")
end)
-- Countdown, optional video capture, then replays the path for `duration` seconds. Every wait checks the
-- token so stopAll / a newer preview cancels this one.
addButton("Preview saved path", function()
    if #points < 2 or playing then
        setStatus("Set or load at least two points.")
        return
    end
    local duration = math.clamp(tonumber(durationBox.Text) or 18, 1, 29)
    local countdown = math.clamp(tonumber(countdownBox.Text) or 5, 0, 30)
    flying = false
    enterCamera()
    playing = true
    playToken += 1
    local token = playToken
    task.spawn(function()
        for second = countdown, 1, -1 do
            if token ~= playToken then
                return
            end
            setStatus("Starting in " .. second .. "…")
            task.wait(1)
        end
        if token ~= playToken then
            return
        end
        if recording then
            local ok, result = pcall(function()
                return CaptureService:StartVideoCaptureAsync(function(captureResult, capture)
                    captureRunning = false
                    if
                        capture
                        and (
                            captureResult == Enum.VideoCaptureResult.Success
                            or captureResult == Enum.VideoCaptureResult.TimeLimitReached
                        )
                    then
                        CaptureService:PromptSaveCapturesToGallery({ capture }, function() end)
                    end
                end, {})
            end)
            captureRunning = ok and result == Enum.VideoCaptureStartedResult.Success
            if not captureRunning then
                setStatus("Capture unavailable here; replaying for screen recording.")
            end
        end
        hideVisualUI()
        local start = os.clock()
        while token == playToken do
            local alpha = (os.clock() - start) / duration
            cameraAt(points, alpha)
            if alpha >= 1 then
                break
            end
            RunService.RenderStepped:Wait()
        end
        if token == playToken then
            if captureRunning then
                pcall(CaptureService.StopVideoCapture, CaptureService)
                captureRunning = false
            end
            playing = false
            restoreVisualUI()
            setStatus("Replay complete. Edit points or run it again.")
        end
    end)
end)
addButton("Recording: OFF", function(item)
    recording = not recording
    item.Text = recording and "Recording: ON (Roblox capture)" or "Recording: OFF"
    setStatus(recording and "Replay will request a video capture." or "Replay can be screen recorded externally.")
end)
addButton("Framing: OFF", function(item)
    guideMode = guideMode == "Off" and "Vertical 9:16" or (guideMode == "Vertical 9:16" and "Wide 16:9" or "Off")
    item.Text = "Framing: " .. guideMode
    if frameGuide then
        frameGuide:Destroy()
        frameGuide = nil
    end
    if guideMode ~= "Off" then
        frameGuide = Instance.new("Frame")
        frameGuide.BackgroundTransparency = 1
        frameGuide.BorderSizePixel = 3
        frameGuide.BorderColor3 = Color3.fromRGB(255, 215, 115)
        frameGuide.AnchorPoint = Vector2.new(0.5, 0.5)
        frameGuide.Position = UDim2.fromScale(0.5, 0.5)
        local viewport = workspace.CurrentCamera.ViewportSize
        local ratio = guideMode == "Vertical 9:16" and 9 / 16 or 16 / 9
        local width = math.min(viewport.X * 0.9, viewport.Y * 0.9 * ratio)
        frameGuide.Size = UDim2.fromOffset(width, width / ratio)
        frameGuide.Parent = gui
    end
    setStatus("Guide is for composition; set the recording window or crop in your editor.")
end)
addButton("Stop and restore camera/UI", function()
    stopAll()
end)
addLabel("F6: panel   F7: stop   Shift: fast fly", 23)

-- ===== 8. Input and free-fly =====
-- F6 / F7 work even while typing (checked before `processed`).
UserInputService.InputBegan:Connect(function(input, processed)
    if input.KeyCode == Enum.KeyCode.F6 then
        gui.Enabled = not gui.Enabled
        return
    end
    if input.KeyCode == Enum.KeyCode.F7 then
        stopAll()
        return
    end
    if processed then
        return
    end
    if pickingTarget and input.UserInputType == Enum.UserInputType.MouseButton1 then
        local hit = player:GetMouse().Target
        pickingTarget = false
        if not hit then
            setStatus("No object selected. Try again.")
            return
        end
        target = hit:FindFirstAncestorOfClass("Model") or hit
        setStatus("Tracking " .. target.Name .. " while it exists.")
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        rightMouse = true
    end
    heldKeys[input.KeyCode] = true
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        rightMouse = false
    end
    heldKeys[input.KeyCode] = nil
end)
UserInputService.InputChanged:Connect(function(input)
    if not flying or playing then
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseWheel then
        flySpeed = math.clamp(flySpeed * (input.Position.Z > 0 and 1.2 or 1 / 1.2), 2, 400)
    elseif input.UserInputType == Enum.UserInputType.MouseMovement and rightMouse then
        local yaw = CFrame.Angles(0, -input.Delta.X * 0.003, 0)
        local pitch = CFrame.Angles(-input.Delta.Y * 0.003, 0, 0)
        camera.CFrame = CFrame.new(camera.CFrame.Position) * yaw * camera.CFrame.Rotation * pitch
    end
end)
-- Free-fly movement in camera space; Shift = 3x.
RunService.RenderStepped:Connect(function(dt)
    if not flying or playing then
        return
    end
    local moveDir = Vector3.zero
    if heldKeys[Enum.KeyCode.W] then
        moveDir += Vector3.new(0, 0, -1)
    end
    if heldKeys[Enum.KeyCode.S] then
        moveDir += Vector3.new(0, 0, 1)
    end
    if heldKeys[Enum.KeyCode.A] then
        moveDir += Vector3.new(-1, 0, 0)
    end
    if heldKeys[Enum.KeyCode.D] then
        moveDir += Vector3.new(1, 0, 0)
    end
    if heldKeys[Enum.KeyCode.E] then
        moveDir += Vector3.new(0, 1, 0)
    end
    if heldKeys[Enum.KeyCode.Q] then
        moveDir += Vector3.new(0, -1, 0)
    end
    if moveDir.Magnitude > 0 then
        local boost = heldKeys[Enum.KeyCode.LeftShift] and 3 or 1
        camera.CFrame += camera.CFrame:VectorToWorldSpace(moveDir.Unit) * flySpeed * boost * dt
    end
    camera.Focus = CFrame.new(camera.CFrame.Position + camera.CFrame.LookVector * 100)
end)

-- ===== 9. Open (/film) =====
openEvent.OnClientEvent:Connect(function()
    local ok, response = pcall(function()
        return remote:InvokeServer("load")
    end)
    if not ok or not response or not response.ok then
        setStatus("Opened. Cloud shots unavailable; this session still works.")
    else
        shots = response.shots
        setStatus("Opened. " .. #shots .. " saved shot(s). F6 toggles panel.")
    end
    gui.Enabled = true
end)
