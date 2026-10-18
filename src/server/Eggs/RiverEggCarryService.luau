local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Service = {}
local active = {}
local event = RS:WaitForChild("RiverEggCarryState")
local function home(player)
    for _, plot in workspace.Plots:GetChildren() do
        if plot:GetAttribute("OwnerUserId") == player.UserId then
            return plot
        end
    end
end
local function finish(player, state)
    local rec = active[player]
    if not rec then
        return
    end
    active[player] = nil
    if rec.visual then
        rec.visual:Destroy()
    end
    if rec.tool and rec.tool.Parent then
        rec.tool.Enabled = rec.enabled
        rec.tool:SetAttribute("ReturningToBase", nil)
    end
    player:SetAttribute("RiverEggCarryBase", nil)
    player:SetAttribute("RiverEggCarryId", nil)
    player:SetAttribute("RiverEggCarryType", nil)
    if state == "Secured" and rec.tool and rec.tool.Parent then
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            hum:EquipTool(rec.tool)
            task.defer(function()
                if rec.tool.Parent == player.Character then
                    require(game.ServerScriptService.TwoHandItemCarryService).Attach(player, rec.tool)
                end
            end)
        end
    end
    event:FireClient(player, state, { id = rec.id })
end
function Service.Begin(player, tool)
    local plot = home(player)
    local char = player.Character
    local torso = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))
    local source = tool:FindFirstChild("Egg")
    if not plot or not torso or not source then
        return false
    end
    if active[player] then
        finish(player, "Cancelled")
    end
    local rec = {
        tool = tool,
        enabled = tool.Enabled,
        plot = plot,
        char = char,
        started = os.clock(),
        id = game:GetService("HttpService"):GenerateGUID(false),
    }
    active[player] = rec
    tool.Enabled = false
    tool:SetAttribute("ReturningToBase", true)
    -- Equip the owned inventory Tool; shared carry rendering provides one visible egg.
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        finish(player, "Cancelled")
        return false
    end
    hum:EquipTool(tool)
    require(game.ServerScriptService.TwoHandItemCarryService).Attach(player, tool)
    local base = plot.PlotSpawn.Position
    player:SetAttribute("RiverEggCarryType", tool:GetAttribute("EggType") or tool.Name)
    player:SetAttribute("RiverEggCarryBase", base)
    player:SetAttribute("RiverEggCarryId", rec.id)
    event:FireClient(player, "Stolen", {
        basePosition = base,
        id = rec.id,
        eggType = tool:GetAttribute("EggType") or tool.Name,
        name = tool.Name,
        rarity = tool:GetAttribute("Rarity"),
        price = tool:GetAttribute("Price"),
    })
    return true
end
RunService.Heartbeat:Connect(function()
    for player, rec in active do
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if
            char ~= rec.char
            or not root
            or not hum
            or hum.Health <= 0
            or not rec.tool.Parent
            or rec.plot:GetAttribute("OwnerUserId") ~= player.UserId
        then
            finish(player, "Cancelled")
        elseif os.clock() - rec.started > 0.5 then
            local rel = rec.plot.TempleAnchor.CFrame:PointToObjectSpace(root.Position)
            if rel.X >= -58 and rel.X <= 32 and rel.Z >= -32 and rel.Z <= 48 and rel.Y >= -15 and rel.Y <= 60 then
                finish(player, "Secured")
            end
        end
    end
end)
Players.PlayerRemoving:Connect(function(p)
    local rec = active[p]
    if rec and rec.visual then
        rec.visual:Destroy()
    end
    active[p] = nil
end)
function Service.Drop(player)
    local rec = active[player]
    if not rec then
        return false
    end
    local tool = rec.tool
    finish(player, "Dropped")
    return require(game.ServerScriptService.TwoHandItemCarryService).DropTool(player, tool)
end
return Service
