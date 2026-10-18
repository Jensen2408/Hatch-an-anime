-- Hatch An Anime CineCam: place in StarterPlayerScripts as CineCamClient.
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
local remote = ReplicatedStorage:WaitForChild("CineCamRemote")
local open = ReplicatedStorage:WaitForChild("CineCamOpen")
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
local pad = Instance.new("UIPadding", panel)
pad.PaddingTop = UDim.new(0, 10)
pad.PaddingLeft = UDim.new(0, 10)
pad.PaddingRight = UDim.new(0, 10)

local order = 0
local function label(message, height)
    order += 1
    local item = Instance.new("TextLabel")
    item.LayoutOrder = order
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
local function button(message, callback)
    order += 1
    local item = Instance.new("TextButton")
    item.LayoutOrder = order
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
local function field(title, default)
    order += 1
    local box = Instance.new("TextBox")
    box.LayoutOrder = order
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

label("CINECAM  •  /film  •  F6 panel  •  F7 stop", 26)
local status = label("Ready. Use Studio Play or join the game as owner.", 40)
local function say(message)
    status.Text = message
end
local nameBox = field("Shot name", "River Reveal")
local durationBox = field("Duration in seconds (max 29)", "18")
local countdownBox = field("Countdown in seconds", "5")
local fovBox = field("Camera zoom / field of view (20 to 100)", "70")
local points = {}
local shots = {}
local target = nil
local pickingTarget = false
local flying = false
local playing = false
local recording = false
local clean = false
local speed = 30
local keys = {}
local rightMouse = false
local originalCamera = nil
local hiddenGui = {}
local hiddenCore = {}
local hiddenConnections = {}
local frameGuide = nil
local guideMode = "Off"
local playToken = 0
local captureRunning = false

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
local function hideVisualUI()
    if clean then
        return
    end
    clean = true
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
    if not clean then
        return
    end
    clean = false
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
local function exitCamera()
    if originalCamera then
        camera.CameraType = originalCamera.cameraType
        camera.CameraSubject = originalCamera.subject
        camera.FieldOfView = originalCamera.fov
        originalCamera = nil
    end
end
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
    say("Stopped. Camera and UI restored.")
end

local function cfArray(cf)
    return { cf:GetComponents() }
end
local function pointCF(point)
    return CFrame.new(table.unpack(point.cf))
end
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
local function lerp(a, b, t)
    return a + (b - a) * t
end
local function catmull(a, b, c, d, t)
    local t2, t3 = t * t, t * t * t
    return 0.5 * ((b * 2) + (c - a) * t + (a * 2 - b * 5 + c * 4 - d) * t2 + (-a + b * 3 - c * 3 + d) * t3)
end
local function cameraAt(path, alpha)
    local n = #path
    local scaled = math.clamp(alpha, 0, 1) * (n - 1)
    local i = math.min(math.floor(scaled) + 1, n - 1)
    local t = scaled - (i - 1)
    t = t * t * (3 - 2 * t)
    local a = pointCF(path[math.max(i - 1, 1)])
    local b = pointCF(path[i])
    local c = pointCF(path[i + 1])
    local d = pointCF(path[math.min(i + 2, n)])
    local pos = catmull(a.Position, b.Position, c.Position, d.Position, t)
    local aim = targetPosition()
    if aim and (aim - pos).Magnitude > 0.1 then
        camera.CFrame = CFrame.lookAt(pos, aim)
    else
        local orientation = b:Lerp(c, t)
        camera.CFrame = CFrame.new(pos) * orientation.Rotation
    end
    camera.FieldOfView = lerp(path[i].fov, path[i + 1].fov, t)
    camera.Focus = CFrame.new(aim or (pos + camera.CFrame.LookVector * 100))
end
local function saveShots()
    local ok, response = pcall(function()
        return remote:InvokeServer("save", shots)
    end)
    if not ok or not response or not response.ok then
        say("Shot kept this session; cloud save failed: " .. tostring(response and response.error or response))
    else
        say("Saved " .. #shots .. " shot(s).")
    end
end

button("Free fly  •  WASD / Q E / right mouse", function()
    if playing then
        return
    end
    enterCamera()
    flying = not flying
    say(flying and "Flying. Shift = faster, mouse wheel = speed." or "Fly paused. Add a point or replay.")
end)
button("Apply camera zoom", function()
    local value = tonumber(fovBox.Text)
    if not value or value < 20 or value > 100 then
        say("Zoom value must be 20 to 100.")
        return
    end
    enterCamera()
    camera.FieldOfView = value
    say("Camera field of view set to " .. value .. ". Add a point to save it.")
end)
button("Set camera point", function()
    if playing then
        return
    end
    if #points >= 40 then
        say("Maximum 40 points.")
        return
    end
    local cf = camera.CFrame
    table.insert(points, { cf = cfArray(cf), fov = camera.FieldOfView })
    say("Point " .. #points .. " saved with position, direction, and zoom.")
end)
button("Track object under mouse / clear tracking", function()
    if target then
        target = nil
        say("Tracking cleared.")
        return
    end
    pickingTarget = true
    say("Click an egg, player, or model in the world to track it.")
end)
button("Undo last point", function()
    if playing then
        return
    end
    if #points > 0 then
        table.remove(points)
        say(#points .. " points remain.")
    end
end)
button("Save current shot", function()
    if #points < 2 then
        say("Add at least two camera points.")
        return
    end
    local duration = tonumber(durationBox.Text)
    if not duration or duration < 1 or duration > 29 then
        say("Duration must be 1 to 29 seconds.")
        return
    end
    local name = nameBox.Text:sub(1, 40)
    if name == "" then
        say("Enter a shot name.")
        return
    end
    for index, shot in ipairs(shots) do
        if shot.name == name then
            table.remove(shots, index)
            break
        end
    end
    if #shots >= 25 then
        say("Maximum 25 saved shots.")
        return
    end
    table.insert(shots, { name = name, duration = duration, points = table.clone(points) })
    saveShots()
end)
button("Load named shot", function()
    for _, shot in ipairs(shots) do
        if shot.name == nameBox.Text then
            points = table.clone(shot.points)
            durationBox.Text = tostring(shot.duration)
            say("Loaded " .. shot.name .. " with " .. #points .. " points.")
            return
        end
    end
    say("No saved shot with that exact name.")
end)
button("Preview saved path", function()
    if #points < 2 or playing then
        say("Set or load at least two points.")
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
            say("Starting in " .. second .. "…")
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
                say("Capture unavailable here; replaying for screen recording.")
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
            say("Replay complete. Edit points or run it again.")
        end
    end)
end)
button("Recording: OFF", function(item)
    recording = not recording
    item.Text = recording and "Recording: ON (Roblox capture)" or "Recording: OFF"
    say(recording and "Replay will request a video capture." or "Replay can be screen recorded externally.")
end)
button("Framing: OFF", function(item)
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
    say("Guide is for composition; set the recording window or crop in your editor.")
end)
button("Stop and restore camera/UI", function()
    stopAll()
end)
label("F6: panel   F7: stop   Shift: fast fly", 23)

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
            say("No object selected. Try again.")
            return
        end
        target = hit:FindFirstAncestorOfClass("Model") or hit
        say("Tracking " .. target.Name .. " while it exists.")
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        rightMouse = true
    end
    keys[input.KeyCode] = true
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        rightMouse = false
    end
    keys[input.KeyCode] = nil
end)
UserInputService.InputChanged:Connect(function(input)
    if not flying or playing then
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseWheel then
        speed = math.clamp(speed * (input.Position.Z > 0 and 1.2 or 1 / 1.2), 2, 400)
    elseif input.UserInputType == Enum.UserInputType.MouseMovement and rightMouse then
        local yaw = CFrame.Angles(0, -input.Delta.X * 0.003, 0)
        local pitch = CFrame.Angles(-input.Delta.Y * 0.003, 0, 0)
        camera.CFrame = CFrame.new(camera.CFrame.Position) * yaw * camera.CFrame.Rotation * pitch
    end
end)
RunService.RenderStepped:Connect(function(dt)
    if not flying or playing then
        return
    end
    local v = Vector3.zero
    if keys[Enum.KeyCode.W] then
        v += Vector3.new(0, 0, -1)
    end
    if keys[Enum.KeyCode.S] then
        v += Vector3.new(0, 0, 1)
    end
    if keys[Enum.KeyCode.A] then
        v += Vector3.new(-1, 0, 0)
    end
    if keys[Enum.KeyCode.D] then
        v += Vector3.new(1, 0, 0)
    end
    if keys[Enum.KeyCode.E] then
        v += Vector3.new(0, 1, 0)
    end
    if keys[Enum.KeyCode.Q] then
        v += Vector3.new(0, -1, 0)
    end
    if v.Magnitude > 0 then
        local boost = keys[Enum.KeyCode.LeftShift] and 3 or 1
        camera.CFrame += camera.CFrame:VectorToWorldSpace(v.Unit) * speed * boost * dt
    end
    camera.Focus = CFrame.new(camera.CFrame.Position + camera.CFrame.LookVector * 100)
end)

open.OnClientEvent:Connect(function()
    local ok, response = pcall(function()
        return remote:InvokeServer("load")
    end)
    if not ok or not response or not response.ok then
        say("Opened. Cloud shots unavailable; this session still works.")
    else
        shots = response.shots
        say("Opened. " .. #shots .. " saved shot(s). F6 toggles panel.")
    end
    gui.Enabled = true
end)
