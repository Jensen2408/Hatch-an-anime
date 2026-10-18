--!strict
-- Central UI feedback. UI and plate samples come from Creator Store;
-- existing coin, purchase, and hatch cues retain their previous assets.

local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")

local UISound = {}

type SoundConfig = {
	id: string,
	volume: number,
	pitchRange: { number }?,
	debounce: number?,
	aliasGroup: string?,
	warm: boolean?,
	maxDuration: number?, -- Optional only after auditioning a sample; default plays it in full.
}

local SOUND_CONFIGS: { [string]: SoundConfig } = {
	Click = {
		id = "rbxassetid://102855535543930", -- Creator Store: Creamy Keyboard Sound Effect (single key)
		volume = 0.40, pitchRange = { 1.04, 1.10 }, debounce = 0.045,
		warm = true, aliasGroup = "ButtonTap",
	},
	PaperClick = {
		id = "rbxassetid://102855535543930", -- Compatibility alias for button taps
		volume = 0.40, pitchRange = { 1.04, 1.10 }, debounce = 0.045,
		warm = true, aliasGroup = "ButtonTap",
	},
	PaperSwipe = {
		id = "rbxassetid://15675037413", -- Official Roblox_UI_Paper_Swipe (Roblox)
		volume = 0.45,
		pitchRange = { 1.20, 1.30 },
		debounce = 0.05,
	},
	PaperPickUp = {
		id = "rbxassetid://102855535543930", -- Compatibility alias for tactile card taps
		volume = 0.36, pitchRange = { 1.00, 1.05 }, debounce = 0.045,
		warm = true, aliasGroup = "ButtonTap",
	},
	Hover = {
		id = "rbxassetid://102855535543930", -- Light, higher-pitched single-key hover
		volume = 0.08, pitchRange = { 1.24, 1.30 }, debounce = 0.065,
		warm = true, aliasGroup = "Hover",
	},
	Open = {
		id = "rbxassetid://97861038165143", -- Creator Store: ui-simple-menu-open (AmbientSorcery)
		volume = 0.32, pitchRange = { 0.99, 1.02 }, debounce = 0.09,
	},
	Close = {
		id = "rbxassetid://110059957735733", -- Creator Store: ui-simple-menu-close (AmbientSorcery)
		volume = 0.25, pitchRange = { 0.98, 1.01 }, debounce = 0.09,
	},
	PlatePress = {
		id = "rbxassetid://96750121076266", -- Creator Store: creamy1 (swagished) - satisfying creamy keyboard thock
		volume = 0.20, pitchRange = { 0.98, 1.03 }, debounce = 0.08,
		warm = false, aliasGroup = "PlatePress",
	},
	PlateRelease = {
		id = "rbxassetid://96750121076266", -- Smooth creamy switch release
		volume = 0.08, pitchRange = { 1.15, 1.22 }, debounce = 0.08,
		warm = false, aliasGroup = "PlateRelease",
	},
	CoinRustle = {
		id = "rbxassetid://9113849492", -- Coins Or Keys Jingle 6 (ProSoundEffects) - natural metal coins jingle
		volume = 0.50,
		pitchRange = { 0.96, 1.04 },
		debounce = 0.10,
	},
	CoinPickup = {
		id = "rbxassetid://90531793028786", -- Cash Register (Kaching) (HMP STUDIO'S) - satisfying coin gain ching!
		volume = 0.65,
		pitchRange = { 0.98, 1.05 },
		debounce = 0.08,
	},
	CoinChing = {
		id = "rbxassetid://90531793028786", -- Cash Register (Kaching) - sell system (HMP STUDIO'S) - bright ching on coin gains!
		volume = 0.80,
		pitchRange = { 0.98, 1.04 },
		debounce = 0.10,
	},
	Purchase = {
		id = "rbxassetid://10066947742", -- RBLX UI Purchase (SFX) (Roblox) - authentic spend / purchase sound
		volume = 0.55,
		pitchRange = { 0.98, 1.02 },
		debounce = 0.12,
	},
	EggBuy = {
		id = "rbxassetid://10066947742", -- RBLX UI Purchase (SFX) (Roblox) - spend on egg
		volume = 0.55,
		pitchRange = { 0.98, 1.02 },
		debounce = 0.12,
	},
	EggBuyChing = {
		id = "rbxassetid://10066947742", -- RBLX UI Purchase (SFX) (Roblox) - spend on egg (alias)
		volume = 0.55,
		pitchRange = { 0.98, 1.02 },
		debounce = 0.12,
	},
	CashRegister = {
		id = "rbxassetid://1319346243", -- Money, Coins, Drop In Cash Register (codes4breakfast)
		volume = 0.52,
		pitchRange = { 0.98, 1.02 },
		debounce = 0.20,
	},
	EggCrack = {
		id = "rbxassetid://9113959343", -- Crack Egg Crunchy 11 (ProSoundEffects)
		volume = 0.50,
		pitchRange = { 0.95, 1.05 },
		debounce = 0.05,
	},
	EggCrackAlt = {
		id = "rbxassetid://9113959071", -- Crack Egg Crunchy 6 (ProSoundEffects)
		volume = 0.50,
		pitchRange = { 0.95, 1.05 },
		debounce = 0.05,
	},
	Shine = {
		id = "rbxassetid://9119447936", -- Sparkle Bell Tree Wind Chimes (ProSoundEffects)
		volume = 0.45,
		pitchRange = { 0.98, 1.03 },
		debounce = 0.25,
	},
	Claim = {
		id = "rbxassetid://90531793028786", -- Cash Register (Kaching) (HMP STUDIO'S) - satisfying coin gain ching on claims!
		volume = 0.58,
		pitchRange = { 0.98, 1.02 },
		debounce = 0.12,
	},
	RewardRustle = {
		id = "rbxassetid://90531793028786", -- Cash Register (Kaching) - coin gain ching
		volume = 0.58,
		pitchRange = { 0.98, 1.02 },
		debounce = 0.12,
	},
	Success = {
		id = "rbxassetid://112485797063762", -- UI Level Up / Accomplishment Ding (SodaBreadle)
		volume = 0.50,
		pitchRange = { 0.98, 1.02 },
		debounce = 0.10,
	},
	HatchDoor = {
		id = "rbxassetid://9118297953", -- Robot Pneumatics Sweeping Piston Slides 6 (ProSoundEffects)
		volume = 0.35,
		pitchRange = { 1.20, 1.30 },
		debounce = 0.20,
	},
	HatchHum = {
		id = "rbxassetid://9116732713", -- Metallic Glow Constant Distant Pulsing Hum 1 (ProSoundEffects)
		volume = 0.25,
		pitchRange = { 0.95, 1.05 },
		debounce = 0.50,
	},
	HatchReady = {
		id = "rbxassetid://9116394545", -- Magic Glows Soft Clusters Of Chiming Hits 1 (ProSoundEffects)
		volume = 0.40,
		pitchRange = { 1.05, 1.15 },
		debounce = 0.30,
	},
	HatchSteam = {
		id = "rbxassetid://9119625292", -- Steam Piston Pump 34 (ProSoundEffects)
		volume = 0.30,
		pitchRange = { 0.98, 1.04 },
		debounce = 0.30,
	},
}

type Voice = { sound: Sound, generation: number, started: number }
type PlaybackState = {
	pools: { [string]: { Voice } },
	lastName: { [string]: number },
	lastId: { [string]: number },
}
type ButtonBinding = {
	clickName: string,
	hoverName: string?,
	selectionHover: boolean,
}

local MAX_VOICES = 3
local ALIAS_DEBOUNCE = 0.04
local CASH_ALIAS_DEBOUNCE = 0.35
local LOAD_TIMEOUT = 15
local random = Random.new()
local folder: Folder? = nil
local cashSuppressedUntil = 0
local uiState: PlaybackState = { pools = {}, lastName = {}, lastId = {} }
local emitterStates: { [BasePart]: PlaybackState } = setmetatable({}, { __mode = "k" })
local managedSounds: { [Sound]: boolean } = setmetatable({}, { __mode = "k" })
local buttonBindings: { [GuiButton]: ButtonBinding } = setmetatable({}, { __mode = "k" })
local descendantBindings: { [Instance]: ButtonBinding } = setmetatable({}, { __mode = "k" })

local function getFolder(): Folder
	local current = folder
	if current and current.Parent then
		return current
	end
	local existing = SoundService:FindFirstChild("UISounds")
	if existing and existing:IsA("Folder") then
		folder = existing
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "UISounds"
	created.Parent = SoundService
	folder = created
	return created
end

local function getSfxGroup(): SoundGroup?
	local group = SoundService:FindFirstChild("SFX")
	return if group and group:IsA("SoundGroup") then group else nil
end

local function isMuted(): boolean
	local player = Players.LocalPlayer
	if player then
		local volume = player:GetAttribute("SFXVolume")
		if player:GetAttribute("SFXMuted") == true or (typeof(volume) == "number" and volume <= 0) then
			return true
		end
	end
	local group = getSfxGroup()
	return group ~= nil and group.Volume <= 0
end

-- Settings may create the SFX group after this module has already been required.
SoundService.ChildAdded:Connect(function(child)
	if child.Name == "SFX" and child:IsA("SoundGroup") then
		for sound in pairs(managedSounds) do
			if sound.Parent then
				sound.SoundGroup = child
			end
		end
	end
end)

local function createVoice(soundName: string, cfg: SoundConfig, parent: Instance, spatial: boolean): Voice
	local sound = Instance.new("Sound")
	sound.Name = "UI_" .. soundName
	sound.SoundId = cfg.id
	sound.Volume = cfg.volume
	sound.Looped = false
	sound.SoundGroup = getSfxGroup()
	if spatial then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 10
		sound.RollOffMaxDistance = 50
	end
	if cfg.warm then
		local equalizer = Instance.new("EqualizerSoundEffect")
		equalizer.Name = "WarmKeyTone"
		equalizer.LowGain = 1.5
		equalizer.MidGain = 0
		equalizer.HighGain = -3.5
		equalizer.Parent = sound
	end
	managedSounds[sound] = true
	sound.Parent = parent
	if spatial then
		-- Spatial one-shots never leave silent Sound instances on streamed stands.
		sound.Ended:Connect(function()
			if not sound.IsPlaying then
				managedSounds[sound] = nil
				sound:Destroy()
			end
		end)
	end
	return { sound = sound, generation = 0, started = 0 }
end

local function acquireVoice(state: PlaybackState, soundName: string, cfg: SoundConfig, parent: Instance, spatial: boolean): Voice
	local pool = state.pools[soundName]
	if not pool then
		pool = {}
		state.pools[soundName] = pool
	end
	for index = #pool, 1, -1 do
		if pool[index].sound.Parent ~= parent then
			table.remove(pool, index)
		end
	end
	for _, voice in ipairs(pool) do
		if not voice.sound.IsPlaying then
			return voice
		end
	end
	if #pool < MAX_VOICES then
		local voice = createVoice(soundName, cfg, parent, spatial)
		table.insert(pool, voice)
		return voice
	end
	local oldest = pool[1]
	for _, voice in ipairs(pool) do
		if voice.started < oldest.started then
			oldest = voice
		end
	end
	oldest.sound:Stop()
	return oldest
end

local function scheduleCleanup(voice: Voice, spatial: boolean, maxDuration: number?)
	local sound = voice.sound
	local generation = voice.generation
	local function finish()
		if voice.generation ~= generation or not sound.Parent then
			return
		end
		sound:Stop()
		if spatial then
			managedSounds[sound] = nil
			sound:Destroy()
		end
	end
	if maxDuration and maxDuration > 0 then
		task.delay(maxDuration, finish)
	elseif sound.IsLoaded and sound.TimeLength > 0 then
		task.delay(sound.TimeLength / sound.PlaybackSpeed + 1, finish)
	else
		-- Failed asset loads also expire. Loaded clips get their full remaining length.
		task.delay(LOAD_TIMEOUT, function()
			if voice.generation ~= generation or not sound.Parent then
				return
			end
			if sound.IsLoaded and sound.TimeLength > 0 then
				local remaining = math.max(0, sound.TimeLength - sound.TimePosition) / sound.PlaybackSpeed
				task.delay(remaining + 1, finish)
			else
				finish()
			end
		end)
	end
end

local function play(state: PlaybackState, soundName: string, parent: Instance, spatial: boolean, customPitch: number?, customVol: number?): Sound?
	local cfg = SOUND_CONFIGS[soundName]
	if not cfg then
		warn("[UISound] Unknown sound:", soundName)
		return nil
	end
	if isMuted() then
		return nil
	end
	local now = os.clock()
	local previousName = state.lastName[soundName]
	local aliasKey = cfg.aliasGroup or cfg.id
	local previousId = state.lastId[aliasKey]
	if previousName and now - previousName < (cfg.debounce or 0.04) then
		return nil
	end
	local aliasDebounce = if cfg.id == "rbxassetid://90531793028786" then CASH_ALIAS_DEBOUNCE else ALIAS_DEBOUNCE
	if previousId and now - previousId < aliasDebounce then
		return nil
	end
	state.lastName[soundName] = now
	state.lastId[aliasKey] = now
	local voice = acquireVoice(state, soundName, cfg, parent, spatial)
	local sound = voice.sound
	voice.generation += 1
	voice.started = now
	local pitch = customPitch or 1
	local range = cfg.pitchRange
	if range then
		pitch *= random:NextNumber(range[1], range[2])
	end
	sound.SoundId = cfg.id
	sound.SoundGroup = getSfxGroup()
	sound.PlaybackSpeed = math.clamp(pitch, 0.1, 4)
	sound.Volume = math.clamp(if customVol ~= nil then customVol else cfg.volume, 0, 10)
	sound.Looped = false
	sound.TimePosition = 0
	sound:Play()
	scheduleCleanup(voice, spatial, cfg.maxDuration)
	return sound
end

function UISound.Play(soundName: string, customPitch: number?, customVol: number?): Sound?
	return play(uiState, soundName, getFolder(), false, customPitch, customVol)
end

function UISound.PlayAt(soundName: string, emitter: BasePart, customPitch: number?, customVol: number?): Sound?
	if not emitter:IsA("BasePart") or not emitter:IsDescendantOf(workspace) then
		return nil
	end
	local state = emitterStates[emitter]
	if not state then
		state = { pools = {}, lastName = {}, lastId = {} }
		emitterStates[emitter] = state
		emitter.Destroying:Once(function()
			emitterStates[emitter] = nil
		end)
	end
	return play(state, soundName, emitter, true, customPitch, customVol)
end

function UISound.PlayCoinPickup(): Sound?
	return UISound.Play("CoinPickup")
end

function UISound.SuppressCashFeedback(_seconds: number?)
	-- Cash sounds are preserved and never suppressed
end

function UISound.IsCashFeedbackSuppressed(): boolean
	return false
end

local function canUseButton(button: GuiButton): boolean
	if not button.Parent or not button.Active or not button.Interactable then
		return false
	end
	-- A muted dim/backdrop button may contain audible controls, so mute is local.
	if button:GetAttribute("UISoundMuted") == true or button:GetAttribute("UISoundDisabled") == true
		or button:GetAttribute("Disabled") == true or button:GetAttribute("SoundEnabled") == false then
		return false
	end
	local ancestor: Instance? = button
	while ancestor do
		if ancestor:IsA("GuiObject") and not ancestor.Visible then
			return false
		end
		if ancestor:IsA("LayerCollector") and not ancestor.Enabled then
			return false
		end
		ancestor = ancestor.Parent
	end
	return true
end

function UISound.AttachButton(button: GuiButton, clickSound: string?, hoverSound: (string | boolean)?, selectionHover: boolean?)
	local binding = buttonBindings[button]
	local hoverName: string? = if hoverSound == false then nil else (if typeof(hoverSound) == "string" then hoverSound else "Hover")
	if binding then
		binding.clickName = clickSound or "Click"
		binding.hoverName = hoverName
		binding.selectionHover = selectionHover ~= false
		return
	end
	local created: ButtonBinding = {
		clickName = clickSound or "Click",
		hoverName = hoverName,
		selectionHover = selectionHover ~= false,
	}
	buttonBindings[button] = created
	button.Activated:Connect(function()
		if canUseButton(button) then
			UISound.Play(created.clickName)
		end
	end)
	local function hover()
		local name = created.hoverName
		if name and canUseButton(button) then
			UISound.Play(name)
		end
	end
	button.MouseEnter:Connect(hover)
	button.SelectionGained:Connect(function()
		if created.selectionHover then
			hover()
		end
	end)
	button.Destroying:Once(function()
		buttonBindings[button] = nil
	end)
end

function UISound.AttachDescendants(parentGui: Instance, clickSound: string?, hoverSound: (string | boolean)?, selectionHover: boolean?)
	local binding = descendantBindings[parentGui]
	if not binding then
		binding = { clickName = "Click", hoverName = "Hover", selectionHover = true }
		descendantBindings[parentGui] = binding
		local created = binding
		parentGui.DescendantAdded:Connect(function(child)
			if child:IsA("GuiButton") then
				UISound.AttachButton(child, created.clickName, created.hoverName or false, created.selectionHover)
			end
		end)
		parentGui.Destroying:Once(function()
			descendantBindings[parentGui] = nil
		end)
	end
	binding.clickName = clickSound or "Click"
	binding.hoverName = if hoverSound == false then nil else (if typeof(hoverSound) == "string" then hoverSound else "Hover")
	binding.selectionHover = selectionHover ~= false
	if parentGui:IsA("GuiButton") then
		UISound.AttachButton(parentGui, binding.clickName, binding.hoverName or false, binding.selectionHover)
	end
	for _, child in ipairs(parentGui:GetDescendants()) do
		if child:IsA("GuiButton") then
			UISound.AttachButton(child, binding.clickName, binding.hoverName or false, binding.selectionHover)
		end
	end
end

-- Preload audio properly as Sound instances to avoid asset type warnings
task.spawn(function()
	local toPreload: { Instance } = {}
	local seen: { [string]: boolean } = {}
	for _, cfg in pairs(SOUND_CONFIGS) do
		if not seen[cfg.id] then
			seen[cfg.id] = true
			local s = Instance.new("Sound")
			s.SoundId = cfg.id
			table.insert(toPreload, s)
		end
	end
	pcall(function()
		ContentProvider:PreloadAsync(toPreload)
	end)
	for _, s in ipairs(toPreload) do
		s:Destroy()
	end
end)

UISound.Configs = SOUND_CONFIGS

return UISound



