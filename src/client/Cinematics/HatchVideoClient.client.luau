-- Owners only. Press J (or /hatchvid) = RECORDING MODE + "hatching until GOD" run.
-- Hides ALL UI, name labels and your own character; smooth camera on your incubator between hatches,
-- the game's own hatch-reveal camera for every reveal. Press J again to stop.
-- Remote: ReplicatedStorage.HatchVideo (see HatchVideoService). Also starts when the player
-- attribute "StartHatchVideo" turns truthy.
local Players, RunService, UserInputService, _TweenService =
    game:GetService("Players"),
    game:GetService("RunService"),
    game:GetService("UserInputService"),
    game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
-- Same owner ids as HatchVideoService.OWNERS (the server checks again).
if not ({ [168774222] = true, [353101613] = true })[player.UserId] then
    return
end
local remote = game.ReplicatedStorage:WaitForChild("HatchVideo")
-- hiddenGuis: GUIs this script disabled, re-enabled on stop()
local active, chamber, connections, hiddenGuis = false, nil, {}, {}

-- Runs every Heartbeat while recording, so newly created GUIs / characters are hidden too.
local function hideStuff()
    for _, gui in player.PlayerGui:GetChildren() do
        if (gui:IsA("ScreenGui") or gui:IsA("BillboardGui")) and gui.Enabled and not hiddenGuis[gui] then
            hiddenGuis[gui] = true
            gui.Enabled = false
        end
    end
    -- Billboards inside the recorded chamber (countdown, status) stay visible.
    for _, billboard in workspace:GetDescendants() do
        if
            billboard:IsA("BillboardGui")
            and billboard.Enabled
            and not hiddenGuis[billboard]
            and not billboard:IsDescendantOf(chamber or workspace.Terrain)
        then
            hiddenGuis[billboard] = true
            billboard.Enabled = false
        end
    end
    local character = player.Character
    if character then
        for _, part in character:GetDescendants() do
            if part:IsA("BasePart") or part:IsA("Decal") then
                part.LocalTransparencyModifier = 1
            end
        end
    end
    for _, otherPlayer in Players:GetPlayers() do
        local humanoid = otherPlayer.Character and otherPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        end
    end
end
local function stop()
    if not active then
        return
    end
    active = false
    RunService:UnbindFromRenderStep("HatchVideoCam")
    for _, connection in connections do
        connection:Disconnect()
    end
    connections = {}
    for gui in hiddenGuis do
        if gui.Parent then
            gui.Enabled = true
        end
    end
    hiddenGuis = {}
    local character = player.Character
    if character then
        for _, part in character:GetDescendants() do
            if part:IsA("BasePart") or part:IsA("Decal") then
                part.LocalTransparencyModifier = 0
            end
        end
    end
    pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, true)
    pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)
    workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    remote:FireServer("Stop")
end
-- Toggles: a second press while recording stops the run.
local function start()
    if active then
        stop()
        return
    end
    active = true
    pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)
    remote:FireServer("Start")
end

remote.OnClientEvent:Connect(function(kind, payload, _arg2, _arg3)
    if kind == "Begin" then
        chamber = payload
        local camera = workspace.CurrentCamera
        local startClock = os.clock()
        table.insert(connections, RunService.Heartbeat:Connect(hideStuff))
        -- Slow orbit around the chamber that slowly dollies in, restarting every 15 s.
        RunService:BindToRenderStep("HatchVideoCam", Enum.RenderPriority.Camera.Value + 2, function()
            if not chamber or not chamber.Parent then
                return
            end
            local status = chamber:GetAttribute("Status")
            if status == "HatchReveal" or status == "Revealing" then
                return
            end -- the game's reveal camera takes over
            local pivot = chamber:GetPivot()
            local elapsed = os.clock() - startClock
            local center = pivot.Position + Vector3.new(0, 3, 0)
            local orbitAngle = math.sin(elapsed * 0.35) * 0.5
            local distance = 24 - math.min(6, (elapsed % 15) * 0.4)
            local lookVector = pivot.LookVector
            local direction = (CFrame.Angles(0, orbitAngle, 0) * CFrame.new(Vector3.zero, -lookVector)).LookVector
            camera.CameraType = Enum.CameraType.Scriptable
            camera.FieldOfView = 55
            camera.CFrame = CFrame.lookAt(center + direction * distance + Vector3.new(0, 6, 0), center)
        end)
    elseif kind == "Done" or kind == "Error" then
        task.delay(kind == "Done" and 4 or 0, stop)
    end
end)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.J then
        start()
    end
end)
player.Chatted:Connect(function(message)
    if message:lower() == "/hatchvid" then
        start()
    end
end)
player:GetAttributeChangedSignal("StartHatchVideo"):Connect(function()
    if player:GetAttribute("StartHatchVideo") then
        start()
    end
end)
