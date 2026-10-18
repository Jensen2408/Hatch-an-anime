--[[ StarterPlayerScripts.BackgroundMusic
Background music. Plays the workspace.Music.Day playlist normally; while workspace.NighttimeActive is true
(20 s every 5 min, see NighttimeService) it crossfades to the workspace.Music.Night playlist and back.
Each playlist plays its sounds in Order and loops. A faded-out playlist pauses and resumes where it left off;
night also moves on to its next track each night so every night track gets heard.
Volume slider lives in MusicSettings.
]]
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local FADE = 2.5
local music = workspace:WaitForChild("Music")

local function start(sound)
	if sound.IsPlaying then return end
	if sound.IsPaused and sound.TimePosition > 0 then sound:Resume() else sound:Play() end
end

-- fades run on a SoundGroup per playlist so they don't fight MusicSettings, which scales Sound.Volume
local function playlist(name, rotate)
	local folder = music:WaitForChild(name)
	local group = Instance.new("SoundGroup")
	group.Name = "MusicFade" .. name
	group.Volume = 0
	group.Parent = SoundService
	local list = { group = group, tracks = {}, index = 1, rotate = rotate, entered = false, active = false }
	for _, sound in folder:GetChildren() do
		if sound:IsA("Sound") then
			sound.Looped = false
			sound.SoundGroup = group
			table.insert(list.tracks, sound)
		end
	end
	table.sort(list.tracks, function(a, b) return (a:GetAttribute("Order") or 0) < (b:GetAttribute("Order") or 0) end)
	for _, sound in list.tracks do
		sound.Ended:Connect(function()
			sound.TimePosition = 0
			if list.tracks[list.index] ~= sound then return end
			list.index = list.index % #list.tracks + 1
			if list.active then start(list.tracks[list.index]) end
		end)
	end
	return list
end

local fades = {}
local function fade(list, on)
	if fades[list] then fades[list]:Cancel() end
	local tween = TweenService:Create(list.group, TweenInfo.new(FADE, Enum.EasingStyle.Sine), { Volume = on and 1 or 0 })
	tween.Completed:Connect(function(state)
		if state ~= Enum.PlaybackState.Completed or on then return end
		for _, sound in list.tracks do if sound.IsPlaying then sound:Pause() end end
	end)
	fades[list] = tween
	tween:Play()
end

local function enter(list)
	if #list.tracks == 0 then return end
	if list.rotate and list.entered then
		local previous = list.tracks[list.index]
		if previous.IsPlaying then previous:Pause() end
		list.index = list.index % #list.tracks + 1
	end
	list.entered, list.active = true, true
	start(list.tracks[list.index])
	fade(list, true)
end

local function leave(list)
	list.active = false
	fade(list, false)
end

local day, night = playlist("Day", false), playlist("Night", true)
local current
local function update()
	local target = if workspace:GetAttribute("NighttimeActive") == true then night else day
	if target == current then return end
	if current then leave(current) end
	current = target
	enter(target)
end
workspace:GetAttributeChangedSignal("NighttimeActive"):Connect(update)
update()
