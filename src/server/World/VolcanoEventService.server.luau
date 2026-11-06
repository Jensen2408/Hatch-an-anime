--[[ ServerScriptService.VolcanoEventService: the Volcano Eruption event (the far voxel volcano erupts and the river turns to lava).
Everything the players see is drawn on their own clients from the shared clock; the server only decides WHEN:
  workspace attribute VolcanoStart   server time the running event started (nil when idle)
  workspace attribute VolcanoNextAt  server time of the next scheduled start
Phases and timings: ReplicatedStorage.VolcanoEvent.VolcanoConfig. Staff: StudPanel buttons (StartVolcano / StopVolcano) and /volcano.
It also keeps the imported volcano model streamed in at any distance (Persistent), so it can be seen from the whole map. ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage:WaitForChild("VolcanoEvent"):WaitForChild("VolcanoConfig"))
local AdminRoles = require(script.Parent:WaitForChild("AdminRoles"))
local HighTideService = require(script.Parent:WaitForChild("HighTideService"))

local control = script:FindFirstChild("Control") or Instance.new("BindableFunction")
control.Name = "Control"
control.Parent = script

local function announce(payload)
    local announcement = ReplicatedStorage:FindFirstChild("OwnerPanel")
        and ReplicatedStorage.OwnerPanel:FindFirstChild("Announcement")
    if announcement then
        payload.by = payload.by or "Server"
        announcement:FireAllClients(payload)
    end
end

-- ===== 1. The volcano model and far background scenery stay streamed in and crisp =====
local function keepVolcanoStreamed()
    local found = workspace:FindFirstChild(Config.ModelName, true)
    if found then
        local models = found:IsA("Model") and { found } or {}
        if found:IsA("Folder") then
            for _, child in found:GetChildren() do
                if child:IsA("Model") then
                    table.insert(models, child)
                end
            end
        end
        for _, model in models do
            if model.ModelStreamingMode ~= Enum.ModelStreamingMode.Persistent then
                model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
            end
        end
        for _, d in found:GetDescendants() do
            if d:IsA("Model") and d.ModelStreamingMode ~= Enum.ModelStreamingMode.Persistent then
                d.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
            end -- (RenderFidelity cannot be written by a script: it is set to Precise on the volcano in Studio, see tools/volcano/setup_volcano.luau)
        end
    end
    local bgTrees = workspace:FindFirstChild("Flat Trees Background", true)
    if bgTrees then
        for _, child in bgTrees:GetChildren() do
            if child:IsA("Model") and child.ModelStreamingMode ~= Enum.ModelStreamingMode.Persistent then
                child.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
            end
        end
    end
end
task.spawn(function()
    while true do
        keepVolcanoStreamed()
        task.wait(20)
    end
end)

-- ===== 1b. ...and stands where Config.Position says =====
local function placeVolcano()
    local model = workspace:FindFirstChild(Config.ModelName, true)
    if not model or not model:IsA("Model") or model:GetAttribute("ManualPlace") or model:GetAttribute("VolcanoPlaced") then
        return
    end
    local minV, maxV = Vector3.one * math.huge, Vector3.one * -math.huge
    for _, d in model:GetDescendants() do
        if d:IsA("BasePart") then
            local h = d.Size / 2
            for sx = -1, 1, 2 do
                for sy = -1, 1, 2 do
                    for sz = -1, 1, 2 do
                        local p = d.CFrame:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz))
                        minV = Vector3.new(math.min(minV.X, p.X), math.min(minV.Y, p.Y), math.min(minV.Z, p.Z))
                        maxV = Vector3.new(math.max(maxV.X, p.X), math.max(maxV.Y, p.Y), math.max(maxV.Z, p.Z))
                    end
                end
            end
            d.Anchored = true
            d.CanCollide = false
            d.CanTouch = false
            d.CanQuery = true -- the lava flows are laid on the cone by raycasting against it (on the client)
            d.CastShadow = false
        end
    end
    if minV.X == math.huge then
        return -- not loaded yet
    end
    local target = Vector3.new(Config.Position.X, Config.Position.Y - Config.BuryDepth, Config.Position.Z)
    local current = Vector3.new((minV.X + maxV.X) / 2, minV.Y, (minV.Z + maxV.Z) / 2)
    model:PivotTo(model:GetPivot() + (target - current))
    model:SetAttribute("VolcanoPlaced", true)
end
task.spawn(function()
    while true do
        placeVolcano()
        task.wait(10)
    end
end)

-- ===== 2. Running an event =====
local state = { running = false, token = 0 }

local function setStart(value)
    workspace:SetAttribute("VolcanoStart", value)
    HighTideService.Update(workspace:GetServerTimeNow())
end

local function endEvent(message)
    if not state.running then
        return
    end
    state.running = false
    state.token += 1
    setStart(nil)
    if message then
        announce({ title = "VOLCANO CALMS", text = message, color = "tide" })
    end
end

local function startEvent(byPlayer)
    if state.running then
        return false, "The volcano is already erupting."
    end
    state.running = true
    state.token += 1
    local token = state.token
    local started = workspace:GetServerTimeNow()
    setStart(started)
    announce({
        title = "THE VOLCANO IS RUMBLING!",
        text = "Look to the horizon... something is about to blow.",
        color = "gold",
        by = byPlayer and byPlayer.Name or "Server",
    })
    task.spawn(function()
        task.wait(Config.WarnSeconds)
        if state.token ~= token then
            return
        end
        announce({ title = "VOLCANO ERUPTION!", text = "The river is turning to lava!", color = "red" })
        task.wait(Config.TotalSeconds - Config.WarnSeconds - Config.CoolSeconds)
        if state.token ~= token then
            return
        end
        announce({ title = "THE LAVA COOLS", text = "The river runs clear again.", color = "tide" })
        task.wait(Config.CoolSeconds)
        if state.token ~= token then
            return
        end
        state.running = false
        setStart(nil)
    end)
    return true, "The volcano is erupting."
end

local function controlAction(action, player)
    if action == "Start" then
        return startEvent(player)
    elseif action == "Stop" then
        if not state.running then
            return false, "No eruption is running."
        end
        endEvent("The eruption was ended early.")
        return true, "Eruption ended."
    end
    return false, "Unknown action."
end
control.OnInvoke = controlAction

local command = TextChatService:FindFirstChild("VolcanoEventCommand") or Instance.new("TextChatCommand")
command.Name = "VolcanoEventCommand"
command.PrimaryAlias = "/volcano"
command.Parent = TextChatService
command.Triggered:Connect(function(source, text)
    local player = source and Players:GetPlayerByUserId(source.UserId)
    if not player then
        return
    end
    local stopping = tostring(text):lower():find("stop") ~= nil
    if not AdminRoles.Can(player, stopping and "StopVolcano" or "StartVolcano") then
        return
    end
    local _, message = controlAction(stopping and "Stop" or "Start", player)
    local announcement = ReplicatedStorage:FindFirstChild("OwnerPanel")
        and ReplicatedStorage.OwnerPanel:FindFirstChild("Announcement")
    if announcement and message then
        announcement:FireClient(player, { title = "VOLCANO", text = message, color = "blue", by = "Server" })
    end
end)

-- ===== 3. Schedule =====
local startedFor
while true do
    local now = workspace:GetServerTimeNow()
    local nextAt = Config.NextScheduled(now)
    local previousAt = nextAt - Config.CycleSeconds
    workspace:SetAttribute("VolcanoNextAt", nextAt)
    if startedFor == nil then
        startedFor = previousAt -- a server that boots mid-slot skips it
    end
    if startedFor ~= previousAt and now - previousAt < 10 then
        startedFor = previousAt
        if #Players:GetPlayers() > 0 and not state.running then
            startEvent(nil)
        end
    end
    task.wait(0.5)
end
