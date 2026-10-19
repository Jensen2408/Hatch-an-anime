--[[ StarterPlayerScripts.BackgroundMusic
Background music. Plays the workspace.Music.Day playlist normally; while workspace.NighttimeActive is true
(20 s every 5 min, see NighttimeService) it crossfades to the workspace.Music.Night playlist and back.
Each playlist plays its sounds in Order and loops. A faded-out playlist pauses and resumes where it left off;
night also moves on to its next track each night so every night track gets heard.
Volume slider lives in MusicSettings. Client-only: no remotes; reads the replicated workspace attribute
NighttimeActive.
]]
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local FADE_TIME = 2.5
local musicFolder = workspace:WaitForChild("Music")

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
    local folder = musicFolder:WaitForChild(name)
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
                startTrack(playlist.tracks[playlist.index])
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
        TweenInfo.new(FADE_TIME, Enum.EasingStyle.Sine),
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

-- Night (rotate = true) moves on to the next track on every re-entry; day resumes the paused track.
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
    startTrack(playlist.tracks[playlist.index])
    fadePlaylist(playlist, true)
end

local function leavePlaylist(playlist)
    playlist.active = false
    fadePlaylist(playlist, false)
end

local dayPlaylist, nightPlaylist = makePlaylist("Day", false), makePlaylist("Night", true)
local currentPlaylist
local function updatePlaylist()
    local target = if workspace:GetAttribute("NighttimeActive") == true then nightPlaylist else dayPlaylist
    if target == currentPlaylist then
        return
    end
    if currentPlaylist then
        leavePlaylist(currentPlaylist)
    end
    currentPlaylist = target
    enterPlaylist(target)
end
workspace:GetAttributeChangedSignal("NighttimeActive"):Connect(updatePlaylist)
updatePlaylist()
