-- SummonHatch.Sfx: plays the summon sounds by name (made in code for the HatchDemo and uploaded to the group).
-- Goes through SoundService.SFX (the settings volume slider) and stays silent while the player attribute SFXMuted is set.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Config = require(script.Parent.Config)

local player = Players.LocalPlayer
local Sfx = {}

local Ids = {
    boom = "rbxassetid://84683853335912",
    tick = "rbxassetid://74627152160333",
    crack = "rbxassetid://134210474282593",
    thunk = "rbxassetid://133965544218530",
    heart = "rbxassetid://94506160225487",
    whoosh = "rbxassetid://88585884979469",
    rumble = "rbxassetid://87789181867531",
    shut = "rbxassetid://125330874964931",
    shing = "rbxassetid://93492276687768",
    stamp = "rbxassetid://85993517997296",
    reveal1 = "rbxassetid://87562006879221",
    reveal2 = "rbxassetid://103536124701219",
    reveal3 = "rbxassetid://130771076979093",
    reveal4 = "rbxassetid://111116365386959",
    reveal5 = "rbxassetid://120867420385556",
    reveal6 = "rbxassetid://118805820304551",
    riser = "rbxassetid://83454008848794",
}

local folder = Instance.new("Folder")
folder.Name = "SummonHatchSfx"
folder.Parent = SoundService

local function make(name)
    local sound = Instance.new("Sound")
    sound.SoundId = Ids[name]
    sound:SetAttribute("HatchFX", true) -- not ducked by other cinematics
    local group = SoundService:FindFirstChild("SFX")
    if group and group:IsA("SoundGroup") then
        sound.SoundGroup = group
    end
    sound.Parent = folder
    return sound
end

function Sfx.preload()
    local list = {}
    for name in Ids do
        table.insert(list, make(name))
    end
    task.spawn(function()
        pcall(ContentProvider.PreloadAsync, ContentProvider, list)
        for _, sound in list do
            sound:Destroy()
        end
    end)
end

function Sfx.play(name, volume, pitch)
    if not Ids[name] or player:GetAttribute("SFXMuted") then
        return
    end
    local sound = make(name)
    sound.Volume = (volume or 0.7) * Config.Volume
    sound.PlaybackSpeed = pitch or 1
    sound:Play()
    sound.Ended:Once(function()
        sound:Destroy()
    end)
    task.delay(12, function()
        sound:Destroy()
    end)
end

-- True for sounds made here, so the music duck leaves them alone.
function Sfx.owns(sound)
    return sound:IsDescendantOf(folder)
end

return Sfx
