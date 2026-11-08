--[[ SummonHatchServer  (ServerScriptService ModuleScript)
Starts the summon-room hatch animation (StarterPlayerScripts.SummonHatch) on the hatching player's client and tracks
when it has finished. It changes nothing about the reward: HatchGoo still rolls it, places the character in the
incubator and grants it to the player's backpack.

API:
  Service.Play(player, info) -> token
    info: chamber, egg (Model, the egg in the tank), character (Model, the reward as shown in the incubator),
          characterId, rarityRank, mutation?, power, income, golden?
  Service.IsBusy(player) -> boolean   true from Play until the client reports done (or Service.Timeout passes)

Remotes (created here, at require time):
  ReplicatedStorage.SummonHatchCue   server -> owner ("Play", payload)
  ReplicatedStorage.SummonHatchDone  owner -> server (token)
Display copies of the egg and character go to PlayerGui.SummonHatchAssets.<token>, so only that player downloads them;
they are removed once the summon is done.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Catalog = require(ReplicatedStorage:WaitForChild("CharacterCatalog"))
local Economy = require(ReplicatedStorage:WaitForChild("CharacterEconomy"))

local Service = {}
Service.Timeout = 45 -- seconds; a client that never answers stops blocking the next hatch after this

local function remote(class, name)
    local existing = ReplicatedStorage:FindFirstChild(name)
    if existing and existing:IsA(class) then
        return existing
    end
    local instance = Instance.new(class)
    instance.Name = name
    instance.Parent = ReplicatedStorage
    return instance
end
local cue = remote("RemoteEvent", "SummonHatchCue")
local doneRemote = remote("RemoteEvent", "SummonHatchDone")

local active = {} -- [player] = { token, folder, deadline }

local function clear(player)
    local job = active[player]
    active[player] = nil
    if job and job.folder then
        job.folder:Destroy()
    end
end

doneRemote.OnServerEvent:Connect(function(player, token)
    local job = active[player]
    if job and job.token == token then
        clear(player)
    end
end)
Players.PlayerRemoving:Connect(clear)

function Service.IsBusy(player)
    local job = player and active[player]
    if not job then
        return false
    end
    if os.clock() > job.deadline then
        clear(player)
        return false
    end
    return true
end

-- A copy that is safe to hand to one client: no scripts, prompts, labels, sounds or physics.
local function displayCopy(source, name)
    local copy = source:Clone()
    copy.Name = name
    for _, descendant in copy:GetDescendants() do
        if
            descendant:IsA("LuaSourceContainer")
            or descendant:IsA("ProximityPrompt")
            or descendant:IsA("BillboardGui")
            or descendant:IsA("ClickDetector")
            or descendant:IsA("Sound")
            or descendant:IsA("ObjectValue")
        then
            descendant:Destroy()
        elseif descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
            descendant.LocalTransparencyModifier = 0
        end
    end
    local poses = copy:FindFirstChild("InitialPoses") -- animation data only, and most of the model's instances
    if poses then
        poses:Destroy()
    end
    return copy
end

-- Where the summon starts: inside the incubator, where the egg sits in the tank (HatchGoo puts it at pivot * (0, 3.5, -1.5)).
-- The camera looks in from the front (the pivot's LookVector).
local function stageOf(chamber, egg)
    local pivot = chamber:GetPivot()
    local look = pivot.LookVector * Vector3.new(1, 0, 1)
    look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
    local home = egg and egg:GetAttribute("ChamberHome")
    local origin = typeof(home) == "CFrame" and home.Position or (pivot * CFrame.new(0, 3.5, -1.5)).Position
    return origin, look
end

function Service.Play(player, info)
    clear(player)
    local entry = Catalog.ById[info.characterId]
    local egg = entry and Catalog.EggById[entry.Egg]
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if not entry or not playerGui or not info.egg or not info.character then
        return nil
    end
    local token = HttpService:GenerateGUID(false)
    local root = playerGui:FindFirstChild("SummonHatchAssets")
    if not root then
        root = Instance.new("Folder")
        root.Name = "SummonHatchAssets"
        root.Parent = playerGui
    end
    local folder = Instance.new("Folder")
    folder.Name = token
    displayCopy(info.egg, "Egg").Parent = folder
    displayCopy(info.character, "Character").Parent = folder
    folder.Parent = root
    active[player] = { token = token, folder = folder, deadline = os.clock() + Service.Timeout }

    -- The other characters of the same egg ride the reel; the rarest of them is the "top pick".
    local slots, lowest = {}, math.huge
    for _, character in (egg and egg.Characters or {}) do
        table.insert(slots, character.Id)
        lowest = math.min(lowest, tonumber(character.Chance) or 100)
    end
    local band, rank = Economy.Quality(info.characterId, info.power), 1
    for index, candidate in ipairs(Economy.Bands) do
        if candidate == band then
            rank = index
        end
    end
    local origin, face = stageOf(info.chamber, info.egg)
    cue:FireClient(player, "Play", {
        token = token,
        characterId = info.characterId,
        name = (info.golden and "Golden " or "") .. entry.Name,
        logoKey = not info.golden and info.characterId or nil, -- rendered name logos exist for the plain names only
        eggName = egg and egg.Name or "Mystery Egg",
        rarityRank = entry.RarityRank or 1,
        slots = #slots >= 2 and slots or {},
        topPick = #slots >= 2 and (tonumber(entry.Chance) or 100) <= lowest,
        mutation = info.mutation,
        power = info.power,
        income = info.income,
        basePower = Economy.BasePower(info.characterId),
        quality = band and band.Name or "Ordinary",
        qualityRank = rank,
        qualityColor = band and band.Color or Color3.new(1, 1, 1),
        origin = origin,
        face = face,
        inChamber = true, -- the opening plays inside the incubator, not on the walkway
        chamber = info.chamber,
    })
    return token
end

return Service
