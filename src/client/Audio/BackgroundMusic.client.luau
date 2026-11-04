--[[ StarterPlayerScripts.BackgroundMusic
Background music. Plays the workspace.Music.Day playlist normally; crossfades to:
  * workspace.Music.Arena   while the player is inside the Arena Brawl (Player attribute ArenaIn == true)
  * workspace.Music.Volcano while the Volcano Eruption event is running (workspace attribute VolcanoStart ~= nil)
  * workspace.Music.Night   while nighttime is active (workspace attribute NighttimeActive == true)
Each playlist plays its sounds in Order and loops. A faded-out playlist pauses and resumes where it left off;
event/night playlists also advance to their next track on each re-entry so every track gets heard.
Volume slider lives in MusicSettings. Client-only: no remotes; reads replicated attributes.
]]
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local FADE_TIME = 2.5
local EVENT_FADE_IN = 0.8 -- the volcano music comes in almost at once (the day music still fades out over FADE_TIME)
local musicFolder = workspace:WaitForChild("Music")

-- Licensed APMOfficial tracks for Arena Brawl and Volcano Eruption (created automatically if the folder is missing).
local DEFAULT_EVENT_TRACKS = {
    Arena = {
        { name = "Shogun Warlord", id = "rbxassetid://1836683148", volume = 0.4, order = 1, startOffset = 36 },
        { name = "Extreme Challenge", id = "rbxassetid://1836691037", volume = 0.4, order = 2, startOffset = 50 },
        { name = "Battleground", id = "rbxassetid://1840866092", volume = 0.4, order = 3, startOffset = 45 },
        { name = "Too Fast To Die", id = "rbxassetid://9044962270", volume = 0.4, order = 4, startOffset = 58 },
    },
    Volcano = {
        { name = "Outbreak Plan", id = "rbxassetid://9044961825", volume = 0.8, order = 1 },
        { name = "Wild Ambush", id = "rbxassetid://9039925079", volume = 0.8, order = 2 },
    },
}

local function ensurePlaylistFolder(name)
    local folder = musicFolder:FindFirstChild(name)
    local defaults = DEFAULT_EVENT_TRACKS[name]
    if not folder and not defaults then
        folder = musicFolder:WaitForChild(name)
    elseif not folder then
        folder = Instance.new("Folder")
        folder.Name = name
        folder.Parent = musicFolder
    end
    if defaults then
        local hasSound = false
        for _, child in folder:GetChildren() do
            if child:IsA("Sound") then
                hasSound = true
                break
            end
        end
        if not hasSound then
            for _, spec in defaults do
                local sound = Instance.new("Sound")
                sound.Name = spec.name
                sound.SoundId = spec.id
                sound.Volume = spec.volume
                sound.Looped = false
                sound:SetAttribute("Order", spec.order)
                if spec.startOffset then
                    sound:SetAttribute("StartOffset", spec.startOffset)
                end
                sound.Parent = folder
            end
        end
    end
    return folder
end

-- Resume a paused track where it stopped, otherwise start it from TimePosition.
local function startTrack(sound)
    if sound.IsPlaying then
        return
    end
    if sound.IsPaused and sound.TimePosition > 0 then
        sound:Resume()
    else
        sound:Play()
    end
end

-- fades run on a SoundGroup per playlist so they don't fight MusicSettings, which scales Sound.Volume
local function makePlaylist(name, rotate)
    local folder = ensurePlaylistFolder(name)
    local group = Instance.new("SoundGroup")
    group.Name = "MusicFade" .. name
    group.Volume = 0
    group.Parent = SoundService
    local playlist = { group = group, tracks = {}, index = 1, rotate = rotate, entered = false, active = false }
    for _, sound in folder:GetChildren() do
        if sound:IsA("Sound") then
            sound.Looped = false
            sound.SoundGroup = group
            table.insert(playlist.tracks, sound)
        end
    end
    table.sort(playlist.tracks, function(trackA, trackB)
        return (trackA:GetAttribute("Order") or 0) < (trackB:GetAttribute("Order") or 0)
    end)
    for _, sound in playlist.tracks do
        -- Only the current track advances the playlist; a stale Ended from another track just rewinds it.
        sound.Ended:Connect(function()
            sound.TimePosition = 0
            if playlist.tracks[playlist.index] ~= sound then
                return
            end
            playlist.index = playlist.index % #playlist.tracks + 1
            if playlist.active then
                local nextSound = playlist.tracks[playlist.index]
                local nextOffset = nextSound:GetAttribute("StartOffset") or 0
                if nextOffset > 0 then
                    nextSound.TimePosition = nextOffset
                end
                startTrack(nextSound)
            end
        end)
    end
    return playlist
end

local activeFades = {} -- [playlist] = Tween currently fading that playlist's SoundGroup
local function fadePlaylist(playlist, fadeIn)
    if activeFades[playlist] then
        activeFades[playlist]:Cancel()
    end
    local tween = TweenService:Create(
        playlist.group,
        TweenInfo.new((fadeIn and playlist.fastIn) and EVENT_FADE_IN or FADE_TIME, Enum.EasingStyle.Sine),
        { Volume = fadeIn and 1 or 0 }
    )
    tween.Completed:Connect(function(state)
        if state ~= Enum.PlaybackState.Completed or fadeIn then
            return
        end
        for _, sound in playlist.tracks do
            if sound.IsPlaying then
                sound:Pause()
            end
        end
    end)
    activeFades[playlist] = tween
    tween:Play()
end

-- Night / event playlists (rotate = true) move on to the next track on every re-entry; day resumes the paused track.
local function enterPlaylist(playlist)
    if #playlist.tracks == 0 then
        return
    end
    if playlist.rotate and playlist.entered then
        local previous = playlist.tracks[playlist.index]
        if previous.IsPlaying then
            previous:Pause()
        end
        playlist.index = playlist.index % #playlist.tracks + 1
    end
    playlist.entered, playlist.active = true, true
    local sound = playlist.tracks[playlist.index]
    if playlist.fastIn then
        local offset = sound:GetAttribute("StartOffset") or 0
        sound.TimePosition = offset
    end
    startTrack(sound)
    fadePlaylist(playlist, true)
end

local function leavePlaylist(playlist)
    playlist.active = false
    fadePlaylist(playlist, false)
end

local dayPlaylist = makePlaylist("Day", false)
local nightPlaylist = makePlaylist("Night", true)
local arenaPlaylist = makePlaylist("Arena", true)
local volcanoPlaylist = makePlaylist("Volcano", true)
arenaPlaylist.fastIn = true
volcanoPlaylist.fastIn = true

-- Preload event tracks now so they are ready the moment the player enters
task.spawn(function()
    pcall(function()
        local ContentProvider = game:GetService("ContentProvider")
        ContentProvider:PreloadAsync(volcanoPlaylist.tracks)
        ContentProvider:PreloadAsync(arenaPlaylist.tracks)
    end)
end)

local function shouldPlayArena()
    -- Only plays when the player is inside the Arena Brawl
    return player:GetAttribute("ArenaIn") == true
end

local currentPlaylist
local function updatePlaylist()
    local target = dayPlaylist
    if shouldPlayArena() and #arenaPlaylist.tracks > 0 then
        target = arenaPlaylist
    elseif workspace:GetAttribute("VolcanoStart") ~= nil and #volcanoPlaylist.tracks > 0 then
        target = volcanoPlaylist
    elseif workspace:GetAttribute("NighttimeActive") == true then
        target = nightPlaylist
    end
    if target == currentPlaylist then
        return
    end
    if currentPlaylist then
        leavePlaylist(currentPlaylist)
    end
    currentPlaylist = target
    enterPlaylist(target)
end

player:GetAttributeChangedSignal("ArenaIn"):Connect(updatePlaylist)
workspace:GetAttributeChangedSignal("VolcanoStart"):Connect(updatePlaylist)
workspace:GetAttributeChangedSignal("NighttimeActive"):Connect(updatePlaylist)

updatePlaylist()
