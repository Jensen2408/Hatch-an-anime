--[[ ServerScriptService.VolcanoHazardService: what the Volcano Eruption does to the world and the players that the server must own.
Everything follows the shared clock (workspace attribute VolcanoStart, see VolcanoEventService) and VolcanoConfig:

  bridges   RiverBridge01 / RiverBridge02 burn from the middle outward and come back after the event. The look (embers, fire,
            charring, fading away) is drawn by VolcanoEventClient; here only the collision follows: a piece that has burnt
            away stops colliding (players on it fall into the river), and starts colliding again as the bridge returns.
  players   standing in lava (a river chunk whose lava fade is past half) or on / beside a burning bridge piece sets a player
            on fire: damage over time (never below Config.MinHealthFraction of their health unless you set it to 0), a Fire on
            their body, and a speed bonus while they burn (Config.BurnSpeedBoost). It all ends BurnSeconds after the last contact,
            or when the event ends. ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("VolcanoEvent"):WaitForChild("VolcanoConfig"))
local Path = require(ReplicatedStorage:WaitForChild("WaterfallRiver"):WaitForChild("RiverPath"))

local TICK = 0.2
local CHUNK_LENGTH = 60 -- the river meshes are cut into 60 stud chunks starting 6 studs behind the waterfall foot
local CHUNK_START = -6
local CHUNK_COUNT = 9

local function eventTime()
    local started = workspace:GetAttribute("VolcanoStart")
    if type(started) ~= "number" then
        return nil
    end
    local t = workspace:GetServerTimeNow() - started
    if Config.PhaseAt(t) == "Idle" then
        return nil
    end
    return t
end

-- ===== River projection: where along the river a point is =====
local samples = {}
do
    local d = 0
    while d <= Path.Total do
        local position, _, right = Path.At(d)
        table.insert(samples, { d = d, position = position, right = right, half = Path.WidthAt(d) / 2 })
        d += 2
    end
end

-- distance along the river and sideways offset of a world position (nearest centre-line sample), or nil when far from it
local function riverOf(position)
    local best, bestDistance = nil, math.huge
    for _, s in samples do
        local dx, dz = position.X - s.position.X, position.Z - s.position.Z
        local flat = dx * dx + dz * dz
        if flat < bestDistance then
            best, bestDistance = s, flat
        end
    end
    if not best or bestDistance > 40 * 40 then
        return nil
    end
    local offset = (position - best.position):Dot(best.right)
    return best, offset
end

local function inLava(rootPosition, t)
    if rootPosition.Y > Path.SurfaceY + 4.5 or rootPosition.Y < Path.SurfaceY - 4 then
        return false -- on a bridge, jumping, or nowhere near the water
    end
    local sample, offset = riverOf(rootPosition)
    if not sample or math.abs(offset) > sample.half + 1 then
        return false
    end
    local index = math.clamp(math.floor((sample.d - CHUNK_START) / CHUNK_LENGTH) + 1, 1, CHUNK_COUNT)
    return Config.ChunkLavaLevel(index, t) >= 0.5
end

-- ===== Bridges =====
local bridges = {} -- [name] = { model, parts = { { part, q, canCollide } } }
local lastScan = -1e9
local function scanBridges()
    if os.clock() - lastScan < 2 then
        return
    end
    lastScan = os.clock()
    for _, name in Config.BridgeNames do
        local model = workspace:FindFirstChild(name, true)
        local entry = bridges[name]
        if model and (not entry or entry.model ~= model) then
            -- long axis and middle of the bridge from its bounding box
            local minV, maxV = Vector3.one * math.huge, Vector3.one * -math.huge
            for _, d in model:GetDescendants() do
                if d:IsA("BasePart") then
                    local p, h = d.Position, d.Size / 2
                    minV = Vector3.new(math.min(minV.X, p.X - h.X), math.min(minV.Y, p.Y - h.Y), math.min(minV.Z, p.Z - h.Z))
                    maxV = Vector3.new(math.max(maxV.X, p.X + h.X), math.max(maxV.Y, p.Y + h.Y), math.max(maxV.Z, p.Z + h.Z))
                end
            end
            local size = maxV - minV
            local alongX = size.X > size.Z
            local centre = (minV + maxV) / 2
            local half = math.max(1, (alongX and size.X or size.Z) / 2)
            local parts = {}
            for _, d in model:GetDescendants() do
                if d:IsA("BasePart") then
                    local along = alongX and (d.Position.X - centre.X) or (d.Position.Z - centre.Z)
                    table.insert(parts, { part = d, q = math.clamp(math.abs(along) / half, 0, 1), canCollide = d.CanCollide })
                end
            end
            bridges[name] = { model = model, parts = parts }
        end
    end
end

local burning = {} -- parts currently on fire: { part, ... } rebuilt every tick
local function updateBridges(t)
    scanBridges()
    local level = Config.BridgeLevel(t)
    table.clear(burning)
    for _, bridge in bridges do
        for _, entry in bridge.parts do
            local part = entry.part
            if part.Parent then
                local bv = Config.BridgeBurnValue(level, entry.q)
                local gone = bv >= 1
                if gone then
                    if part.CanCollide then
                        part.CanCollide = false
                    end
                elseif entry.canCollide and not part.CanCollide then
                    part.CanCollide = true
                end
                if bv > 0 and bv < 1 then
                    table.insert(burning, part)
                end
            end
        end
    end
end

local function nearBurningPiece(rootPosition)
    for _, part in burning do
        if (part.Position - rootPosition).Magnitude < part.Size.Magnitude / 2 + 3.5 then
            return true
        end
    end
    return false
end

-- ===== Players on fire =====
local states = {} -- [Player] = { fireUntil, boosted, fire }

local function extinguish(player)
    local state = states[player]
    if not state then
        return
    end
    if state.fire then
        state.fire:Destroy()
    end
    local humanoid = state.humanoid
    if state.boosted and humanoid and humanoid.Parent then
        humanoid.WalkSpeed = humanoid.WalkSpeed / Config.BurnSpeedBoost
    end
    player:SetAttribute("VolcanoBurning", nil)
    states[player] = nil
end

local function ignite(player, character, humanoid, root, now)
    local state = states[player]
    if state and state.humanoid ~= humanoid then
        extinguish(player) -- a new character: the old fire went with the old body
        state = nil
    end
    if not state then
        state = { humanoid = humanoid, boosted = false }
        states[player] = state
        local fire = Instance.new("Fire")
        fire.Name = "VolcanoBurn"
        fire.Size = 7
        fire.Heat = 9
        fire.Color = Color3.fromRGB(255, 150, 40)
        fire.SecondaryColor = Color3.fromRGB(200, 40, 10)
        fire.Parent = root
        state.fire = fire
        player:SetAttribute("VolcanoBurning", true)
    end
    if not state.boosted then
        state.boosted = true
        humanoid.WalkSpeed = humanoid.WalkSpeed * Config.BurnSpeedBoost -- the bonus
    end
    state.fireUntil = now + Config.BurnSeconds
end

local function damage(humanoid, amount, lethal)
    local floor = humanoid.MaxHealth * Config.MinHealthFraction
    local allowed = math.max(0, humanoid.Health - floor)
    if lethal or Config.MinHealthFraction <= 0 then
        allowed = amount
    end
    local dealt = math.min(amount, allowed)
    if dealt > 0 then
        humanoid:TakeDamage(dealt)
    end
end

Players.PlayerRemoving:Connect(function(player)
    states[player] = nil
end)

-- ===== Loop =====
while true do
    local t = eventTime()
    updateBridges(t)
    local now = os.clock()
    for _, player in Players:GetPlayers() do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if t and humanoid and root and humanoid.Health > 0 and not player:GetAttribute("ArenaIn") then
            local dps, lethal = 0, false
            if inLava(root.Position, t) then
                dps, lethal = Config.LavaDps, Config.LavaKills
            elseif nearBurningPiece(root.Position) then
                dps = Config.BridgeDps
            end
            local state = states[player]
            if dps > 0 then
                ignite(player, character, humanoid, root, now)
                damage(humanoid, dps * TICK, lethal)
            elseif state and now < state.fireUntil then
                damage(humanoid, Config.AfterburnDps * TICK)
            elseif state then
                extinguish(player)
            end
        elseif states[player] then
            extinguish(player)
        end
    end
    task.wait(TICK)
end
