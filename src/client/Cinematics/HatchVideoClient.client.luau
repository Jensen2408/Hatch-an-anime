-- Owners only. Press J (or /hatchvid) = RECORDING MODE + "hatching until GOD" run.
-- Hides ALL UI, name labels and your own character; smooth camera on your incubator between hatches,
-- the game's own hatch-reveal camera for every reveal. Press J again to stop.
local Players, RunService, UIS, TS =
    game:GetService("Players"),
    game:GetService("RunService"),
    game:GetService("UserInputService"),
    game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
if not ({ [168774222] = true, [353101613] = true })[player.UserId] then
    return
end
local remote = game.ReplicatedStorage:WaitForChild("HatchVideo")
local active, chamber, conns, hidden = false, nil, {}, {}

local function hideStuff()
    for _, g in player.PlayerGui:GetChildren() do
        if (g:IsA("ScreenGui") or g:IsA("BillboardGui")) and g.Enabled and not hidden[g] then
            hidden[g] = true
            g.Enabled = false
        end
    end
    for _, b in workspace:GetDescendants() do
        if
            b:IsA("BillboardGui")
            and b.Enabled
            and not hidden[b]
            and not b:IsDescendantOf(chamber or workspace.Terrain)
        then
            hidden[b] = true
            b.Enabled = false
        end
    end
    local c = player.Character
    if c then
        for _, p in c:GetDescendants() do
            if p:IsA("BasePart") or p:IsA("Decal") then
                p.LocalTransparencyModifier = 1
            end
        end
    end
    for _, o in Players:GetPlayers() do
        local h = o.Character and o.Character:FindFirstChildOfClass("Humanoid")
        if h then
            h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        end
    end
end
local function stop()
    if not active then
        return
    end
    active = false
    RunService:UnbindFromRenderStep("HatchVideoCam")
    for _, c in conns do
        c:Disconnect()
    end
    conns = {}
    for g in hidden do
        if g.Parent then
            g.Enabled = true
        end
    end
    hidden = {}
    local c = player.Character
    if c then
        for _, p in c:GetDescendants() do
            if p:IsA("BasePart") or p:IsA("Decal") then
                p.LocalTransparencyModifier = 0
            end
        end
    end
    pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, true)
    pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)
    workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    remote:FireServer("Stop")
end
local function start()
    if active then
        stop()
        return
    end
    active = true
    pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)
    remote:FireServer("Start")
end

remote.OnClientEvent:Connect(function(kind, a, b, c)
    if kind == "Begin" then
        chamber = a
        local cam = workspace.CurrentCamera
        local t0 = os.clock()
        table.insert(conns, RunService.Heartbeat:Connect(hideStuff))
        RunService:BindToRenderStep("HatchVideoCam", Enum.RenderPriority.Camera.Value + 2, function()
            if not chamber or not chamber.Parent then
                return
            end
            local status = chamber:GetAttribute("Status")
            if status == "HatchReveal" or status == "Revealing" then
                return
            end -- the game's reveal camera takes over
            local pivot = chamber:GetPivot()
            local t = os.clock() - t0
            local center = pivot.Position + Vector3.new(0, 3, 0)
            local ang = math.sin(t * 0.35) * 0.5
            local dist = 24 - math.min(6, (t % 15) * 0.4)
            local look = pivot.LookVector
            local dir = (CFrame.Angles(0, ang, 0) * CFrame.new(Vector3.zero, -look)).LookVector
            cam.CameraType = Enum.CameraType.Scriptable
            cam.FieldOfView = 55
            cam.CFrame = CFrame.lookAt(center + dir * dist + Vector3.new(0, 6, 0), center)
        end)
    elseif kind == "Done" or kind == "Error" then
        task.delay(kind == "Done" and 4 or 0, stop)
    end
end)
UIS.InputBegan:Connect(function(i, gp)
    if not gp and i.KeyCode == Enum.KeyCode.J then
        start()
    end
end)
player.Chatted:Connect(function(m)
    if m:lower() == "/hatchvid" then
        start()
    end
end)
player:GetAttributeChangedSignal("StartHatchVideo"):Connect(function()
    if player:GetAttribute("StartHatchVideo") then
        start()
    end
end)
