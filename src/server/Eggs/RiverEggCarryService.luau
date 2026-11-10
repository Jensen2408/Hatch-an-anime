--[[ ServerScriptService.RiverEggCarryService  (ModuleScript, SERVER)
"Carry it home" phase after a river egg is bought (PirateEggFreeConveyor) or a dropped egg is picked up
(TwoHandItemCarryService.DropTool). The egg Tool is already in the player's Backpack; while carrying it is
disabled (Enabled = false, attribute ReturningToBase = true) and held with the two-hand carry visual.

Public API
  Service.Begin(player, tool) -> boolean    start a carry (cancels any previous one)
  Service.Drop(player)        -> boolean    end the carry as "Dropped" and drop the Tool on the ground
  Service.IsCarrying(player)  -> boolean    true while an egg is still on its way home (one carry at a time:
                                            the river and dropped-egg pickups refuse a new egg until it is secured)

Ends (server decides, checked every Heartbeat):
  "Secured"   root inside the capture square on the player's PlotSpawn pad, after 0.5 s -> Tool re-enabled + equipped
  "Cancelled" character changed / died, Tool gone, plot lost, or a new Begin
  "Dropped"   via Service.Drop
While carrying, Humanoid.WalkSpeed is scaled by EggCarryConfig.CarryWalkSpeedMultiplier and restored on every end.
Replication: player attributes RiverEggCarryBase / RiverEggCarryId / RiverEggCarryType, and
ReplicatedStorage.RiverEggCarryState (place-owned RemoteEvent, server -> client):
  FireClient(player, "Stolen", { basePosition, id, eggType, name, rarity, price })  on Begin
  FireClient(player, state, { id })                                                on every end
Note: TwoHandItemCarryService is required lazily (it requires this module back from DropTool).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CarryConfig = require(ReplicatedStorage:WaitForChild("EggCarryConfig"))
local StealRules = require(ReplicatedStorage:WaitForChild("EggSteal"):WaitForChild("EggStealConfig")).Rules
local CAPTURE_HALF = StealRules.CaptureHalfSize or 6
local CAPTURE_HEIGHT = StealRules.CaptureHeight or 14
local Service = {}
local activeCarries = {} -- [Player] = { tool, enabled, plot, char, started, id, humanoid?, walkSpeed?, slowSpeed?, visual? }
local carryStateEvent = ReplicatedStorage:WaitForChild("RiverEggCarryState")
local function homePlot(player)
    for _, plot in workspace.Plots:GetChildren() do
        if plot:GetAttribute("OwnerUserId") == player.UserId then
            return plot
        end
    end
end
local function finish(player, state)
    local carry = activeCarries[player]
    if not carry then
        return
    end
    activeCarries[player] = nil
    -- `visual` is never set in the current code (the carry visual is TwoHandItemCarryService's); kept for safety.
    if carry.visual then
        carry.visual:Destroy()
    end
    -- restore the carry slowdown, unless something else changed WalkSpeed in the meantime
    if carry.humanoid and carry.humanoid.Parent and carry.humanoid.WalkSpeed == carry.slowSpeed then
        carry.humanoid.WalkSpeed = carry.walkSpeed
    end
    if carry.tool and carry.tool.Parent then
        carry.tool.Enabled = carry.enabled
        carry.tool:SetAttribute("ReturningToBase", nil)
    end
    player:SetAttribute("RiverEggCarryBase", nil)
    player:SetAttribute("RiverEggCarryId", nil)
    player:SetAttribute("RiverEggCarryType", nil)
    if state == "Secured" and carry.tool and carry.tool.Parent then
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then
            humanoid:EquipTool(carry.tool)
            task.defer(function()
                if carry.tool.Parent == player.Character then
                    require(game.ServerScriptService.TwoHandItemCarryService).Attach(player, carry.tool)
                end
            end)
        end
    end
    carryStateEvent:FireClient(player, state, { id = carry.id })
end
function Service.Begin(player, tool)
    local plot = homePlot(player)
    local character = player.Character
    local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
    local source = tool:FindFirstChild("Egg")
    if not plot or not torso or not source then
        return false
    end
    if activeCarries[player] then
        finish(player, "Cancelled")
    end
    local carry = {
        tool = tool,
        enabled = tool.Enabled,
        plot = plot,
        char = character,
        started = os.clock(),
        id = game:GetService("HttpService"):GenerateGUID(false),
    }
    activeCarries[player] = carry
    tool.Enabled = false
    tool:SetAttribute("ReturningToBase", true)
    -- Equip the owned inventory Tool; shared carry rendering provides one visible egg.
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        finish(player, "Cancelled")
        return false
    end
    humanoid:EquipTool(tool)
    require(game.ServerScriptService.TwoHandItemCarryService).Attach(player, tool)
    carry.humanoid = humanoid
    carry.walkSpeed = humanoid.WalkSpeed
    humanoid.WalkSpeed *= CarryConfig.CarryWalkSpeedMultiplier
    carry.slowSpeed = humanoid.WalkSpeed -- read back: WalkSpeed is stored as a float32
    local basePosition = plot.PlotSpawn.Position
    player:SetAttribute("RiverEggCarryType", tool:GetAttribute("EggType") or tool.Name)
    player:SetAttribute("RiverEggCarryBase", basePosition)
    player:SetAttribute("RiverEggCarryId", carry.id)
    carryStateEvent:FireClient(player, "Stolen", {
        basePosition = basePosition,
        id = carry.id,
        eggType = tool:GetAttribute("EggType") or tool.Name,
        name = tool.Name,
        rarity = tool:GetAttribute("Rarity"),
        price = tool:GetAttribute("Price"),
    })
    return true
end
-- finish() clears activeCarries[player] while this loop iterates; assigning nil to the current key is safe in Luau.
RunService.Heartbeat:Connect(function()
    for player, carry in activeCarries do
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if
            character ~= carry.char
            or not root
            or not humanoid
            or humanoid.Health <= 0
            or not carry.tool.Parent
            or carry.plot:GetAttribute("OwnerUserId") ~= player.UserId
        then
            finish(player, "Cancelled")
        elseif os.clock() - carry.started > 0.5 then
            -- capture square on the plot's spawn pad (EggStealConfig CaptureHalfSize, drawn by StolenEggBanner);
            -- plots without a PlotSpawn fall back to the old home box in TempleAnchor space
            local spawnPad = carry.plot:FindFirstChild("PlotSpawn")
            if spawnPad then
                local pad = spawnPad.CFrame:PointToObjectSpace(root.Position)
                if math.abs(pad.X) <= CAPTURE_HALF and math.abs(pad.Z) <= CAPTURE_HALF and pad.Y >= -4 and pad.Y <= CAPTURE_HEIGHT then
                    finish(player, "Secured")
                end
            else
                local rel = carry.plot.TempleAnchor.CFrame:PointToObjectSpace(root.Position)
                if rel.X >= -58 and rel.X <= 32 and rel.Z >= -32 and rel.Z <= 48 and rel.Y >= -15 and rel.Y <= 60 then
                    finish(player, "Secured")
                end
            end
        end
    end
end)
Players.PlayerRemoving:Connect(function(player)
    local carry = activeCarries[player]
    if carry and carry.visual then
        carry.visual:Destroy()
    end
    activeCarries[player] = nil
end)
function Service.IsCarrying(player)
    return activeCarries[player] ~= nil
end
function Service.Drop(player)
    local carry = activeCarries[player]
    if not carry then
        return false
    end
    local tool = carry.tool
    finish(player, "Dropped")
    return require(game.ServerScriptService.TwoHandItemCarryService).DropTool(player, tool)
end
return Service
