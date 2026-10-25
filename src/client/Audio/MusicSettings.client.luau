--[[ StarterPlayerScripts.MusicSettings  — Settings panel
Music volume, sound-effects volume, reduced motion, night sky effects and floating labels.
Music = sounds under workspace.Music. Sound effects = everything else (routed into SoundService.SFX).
Values are kept on the player as attributes for this session (MusicVolume, SFXVolume, SFXMuted, ReducedMotion, ...).
Persistence: PlayerDataService restores saved values onto those attributes; this script first waits up to 8 s for
the DataLoaded attribute. Changes are sent back via ReplicatedStorage.SaveSettings:FireServer({ <key> = value, ... })
for the keys in savedKeys, debounced to one send per 1.5 s.
Other scripts read the attributes (ReducedMotion, NightFX, HideLabels). The left menu's SETTINGS button
(GameMenus.MenuLogic) fires the "Toggle" BindableEvent (child of MusicSettingsUI).
UI: MusicSettingsUI.Panel (FirstHatchTutorial looks for it) is the Figma "06 Settings" window, drawn by
ReplicatedStorage.SettingsMenu (SettingsComponent / SettingsConfig) on the StudKit canvas.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UISound = require(ReplicatedStorage:WaitForChild("UISound"))
local StudUI = require(ReplicatedStorage:WaitForChild("StudKit"):WaitForChild("StudUI"))
local SettingsComponent = require(ReplicatedStorage:WaitForChild("SettingsMenu"):WaitForChild("SettingsComponent"))
local player = Players.LocalPlayer
do
    local waitStart = os.clock()
    while not player:GetAttribute("DataLoaded") and os.clock() - waitStart < 8 do
        task.wait(0.1)
    end
end -- saved settings arrive with the save
local playerGui = player:WaitForChild("PlayerGui")

-- ===== 1. ScreenGui and panel =====
local gui = Instance.new("ScreenGui")
gui.Name = "MusicSettingsUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 45
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = playerGui
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.BackgroundTransparency = 1
panel.Visible = false
panel.Active = true
panel:SetAttribute("NoSkin", true)
panel.Parent = gui
local panelScale = Instance.new("UIScale")
panelScale.Parent = panel
local function layoutSettings()
    if gui.AbsoluteSize.X > 0 and gui.AbsoluteSize.Y > 0 then
        StudUI.fitPanel(panel, gui.AbsoluteSize)
    end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutSettings)
layoutSettings()

-- ===== 2. Music / sound-effect routing =====
-- Music sounds keep their authored volume in originalVolumes and are scaled by musicVolume; every other
-- Sound without a SoundGroup is routed into SoundService.SFX so the SFX slider can scale it.
local musicVolume, originalVolumes = player:GetAttribute("MusicVolume") or 1, {}
local function isMusic(sound)
    local musicFolder = workspace:FindFirstChild("Music")
    return musicFolder and sound:IsDescendantOf(musicFolder)
end
---------------------------------------------------------------- sound effects (everything that isn't music)
local sfxGroup = SoundService:FindFirstChild("SFX")
if not (sfxGroup and sfxGroup:IsA("SoundGroup")) then
    sfxGroup = Instance.new("SoundGroup")
    sfxGroup.Name = "SFX"
    sfxGroup.Volume = 1
    sfxGroup.Parent = SoundService
end
local function registerSound(sound)
    if not sound:IsA("Sound") then
        return
    end
    if isMusic(sound) then
        if not originalVolumes[sound] then
            originalVolumes[sound] = sound.Volume
            sound.Volume = originalVolumes[sound] * musicVolume
        end
    elseif not sound.SoundGroup then
        sound.SoundGroup = sfxGroup
    end
end
task.spawn(function()
    for _, container in { workspace, playerGui, SoundService } do
        for index, descendant in container:GetDescendants() do
            if descendant:IsA("Sound") then
                pcall(registerSound, descendant)
            end
            if index % 2000 == 0 then
                task.wait()
            end
        end
        container.DescendantAdded:Connect(function(descendant)
            if descendant:IsA("Sound") then
                task.defer(pcall, registerSound, descendant)
            end
        end)
    end
end)

-- ===== 3. Settings rows =====
local setOpen -- section 5
local rows = {
    {
        kind = "slider",
        title = "Music",
        value = musicVolume,
        onChange = function(volume)
            musicVolume = volume
            player:SetAttribute("MusicVolume", volume)
            for sound, baseVolume in originalVolumes do
                if sound.Parent then
                    sound.Volume = baseVolume * volume
                else
                    originalVolumes[sound] = nil
                end
            end
        end,
    },
    {
        kind = "slider",
        title = "Sound effects",
        value = player:GetAttribute("SFXVolume") or 1,
        onChange = function(volume)
            sfxGroup.Volume = volume
            player:SetAttribute("SFXVolume", volume)
            player:SetAttribute("SFXMuted", volume == 0)
        end,
    },
    {
        kind = "toggle",
        title = "Animations",
        text = "Turn off for simpler, calmer effects",
        value = player:GetAttribute("ReducedMotion") ~= true,
        onChange = function(isOn)
            player:SetAttribute("ReducedMotion", not isOn)
        end,
    },
    {
        kind = "toggle",
        title = "Night sky effects",
        text = "Aurora and floating stars at night",
        value = player:GetAttribute("NightFX") ~= false,
        onChange = function(isOn)
            player:SetAttribute("NightFX", isOn)
            local nightFx = workspace:FindFirstChild("NighttimeLocalFX")
            if nightFx then
                for _, descendant in nightFx:GetDescendants() do
                    if descendant:IsA("Beam") or descendant:IsA("ParticleEmitter") then
                        descendant:SetAttribute("UserOff", not isOn)
                        if not isOn then
                            descendant.Enabled = false
                        end
                    end
                end
            end
        end,
    },
    {
        kind = "toggle",
        title = "Floating labels",
        text = "Names and stats above characters",
        value = player:GetAttribute("HideLabels") ~= true,
        onChange = function(isOn)
            player:SetAttribute("HideLabels", not isOn)
            for _, billboard in playerGui:GetChildren() do
                if billboard:IsA("BillboardGui") and billboard.Name == "CharacterInfoLabel" then
                    billboard.Enabled = isOn
                end
            end
        end,
    },
}
SettingsComponent.new(panel, {
    onClose = function()
        setOpen(false)
    end,
    rows = rows,
})
-- apply the starting values once (the controls are built silently)
for _, row in rows do
    row.onChange(row.value)
end
-- ===== 4. Persistence =====
do -- apply saved values + save changes
    sfxGroup.Volume = player:GetAttribute("SFXVolume") or 1
    local savedKeys = { "MusicVolume", "SFXVolume", "SFXMuted", "ReducedMotion", "NightFX", "HideLabels" }
    local saveQueued = false
    local saveRemote = game:GetService("ReplicatedStorage"):WaitForChild("SaveSettings", 10)
    player.AttributeChanged:Connect(function(name)
        if not saveRemote or saveQueued or not table.find(savedKeys, name) then
            return
        end
        saveQueued = true
        task.delay(1.5, function()
            saveQueued = false
            local payload = {}
            for _, key in savedKeys do
                payload[key] = player:GetAttribute(key)
            end
            saveRemote:FireServer(payload)
        end)
    end)
end
playerGui.ChildAdded:Connect(function(child)
    if child.Name == "CharacterInfoLabel" and player:GetAttribute("HideLabels") then
        task.defer(function()
            child.Enabled = false
        end)
    end
end)

-- ===== 5. Open / close =====
local isOpen = false
local BASE_DISPLAY = gui.DisplayOrder -- 45
setOpen = function(shouldOpen)
    if isOpen ~= shouldOpen then
        UISound.Play(shouldOpen and "Open" or "Close")
    end
    isOpen = shouldOpen
    -- When Settings panel is open, render above GameMenus' boosted DisplayOrder (60)
    gui.DisplayOrder = shouldOpen and math.max(BASE_DISPLAY, 65) or BASE_DISPLAY
    if shouldOpen then
        panel.Visible = true
        panelScale.Scale = 0.85
        TweenService:Create(panelScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
    else
        local closeTween = TweenService:Create(panelScale, TweenInfo.new(0.12), { Scale = 0.85 })
        closeTween:Play()
        closeTween.Completed:Once(function()
            if not isOpen then
                panel.Visible = false
            end
        end)
    end
end
-- the left menu's SETTINGS button (GameMenus.MenuLogic) opens / closes the panel through this bindable
local toggleEvent = Instance.new("BindableEvent")
toggleEvent.Name = "Toggle"
toggleEvent.Event:Connect(function()
    setOpen(not isOpen)
end)
toggleEvent.Parent = gui

-- Close the Settings panel when a GameMenu panel opens.
local gameMenusGui = playerGui:WaitForChild("GameMenus", 10)
if gameMenusGui then
    local dim = gameMenusGui:WaitForChild("Dim", 5)
    if dim then
        local function onMenuOverlay()
            local menuOpen = dim.Visible
            -- If the settings panel was open, close it so it does not fight the menu
            if menuOpen and isOpen then
                setOpen(false)
            end
        end
        dim:GetPropertyChangedSignal("Visible"):Connect(onMenuOverlay)
        onMenuOverlay()
    end
end
