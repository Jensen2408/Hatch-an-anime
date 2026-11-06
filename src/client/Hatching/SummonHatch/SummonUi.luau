-- SummonHatch.SummonUi: the few UI pieces the summon animation builds on (ported from the HatchDemo Ui), plus
-- setHud, which clears the game's own screen while the summon plays and puts it back afterwards.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local Ui = {}
local INK = Color3.fromRGB(12, 10, 16)
local PAPER = Color3.fromRGB(255, 248, 232)
Ui.INK, Ui.PAPER = INK, PAPER
Ui.GuiName = "SummonHatchUI"

function Ui.screen(name, order)
    local gui = Instance.new("ScreenGui")
    gui.Name = name
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.ScreenInsets = Enum.ScreenInsets.None
    gui.DisplayOrder = order or 10
    gui.Parent = player:WaitForChild("PlayerGui")
    return gui
end

-- A scaled design canvas: authored at 1280x720, keeps everything on screen from phone to 4K.
function Ui.canvas(gui)
    local canvas = Instance.new("Frame")
    canvas.Name = "Canvas"
    canvas.BackgroundTransparency = 1
    canvas.AnchorPoint = Vector2.new(0.5, 0.5)
    canvas.Position = UDim2.fromScale(0.5, 0.5)
    local scale = Instance.new("UIScale")
    scale.Parent = canvas
    local function fit()
        local size = gui.AbsoluteSize
        if size.X < 1 then
            return
        end
        local k = math.min(size.X / 1280, size.Y / 720)
        if UserInputService.TouchEnabled then -- phones get a smaller canvas, so buttons stay a thumb wide
            k = math.min(size.X / 960, size.Y / 540)
        end
        scale.Scale = k
        canvas.Size = UDim2.fromOffset(size.X / k, size.Y / k)
    end
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
    canvas.Parent = gui
    fit()
    return canvas
end

function Ui.text(parent, text, size, color, font)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Font = font or Enum.Font.LuckiestGuy
    label.Text = text
    label.TextSize = size
    label.TextColor3 = color or Color3.new(1, 1, 1)
    label.Size = UDim2.fromOffset(300, size + 6)
    label.TextXAlignment = Enum.TextXAlignment.Center
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = math.max(2, size * 0.09)
    stroke.Color = INK
    stroke.LineJoinMode = Enum.LineJoinMode.Miter
    stroke.Parent = label
    label.Parent = parent
    return label
end

-- Panel with a hard shadow. The shadow is a sibling so it can't be clipped.
local function panel(parent, size, pos, color, anchor, shadow)
    local holder = Instance.new("Frame")
    holder.BackgroundTransparency = 1
    holder.Size = size
    holder.Position = pos
    holder.AnchorPoint = anchor or Vector2.zero
    holder.Parent = parent
    local depth = shadow or 6
    local back = Instance.new("Frame")
    back.Name = "Shadow"
    back.BorderSizePixel = 0
    back.BackgroundColor3 = INK
    back.Size = UDim2.fromScale(1, 1)
    back.Position = UDim2.fromOffset(depth, depth)
    back.Parent = holder
    local face = Instance.new("Frame")
    face.Name = "Face"
    face.BorderSizePixel = 0
    face.BackgroundColor3 = color or PAPER
    face.Size = UDim2.fromScale(1, 1)
    face.Parent = holder
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 3
    stroke.Color = INK
    stroke.LineJoinMode = Enum.LineJoinMode.Miter
    stroke.Parent = face
    return holder, face
end

function Ui.button(parent, text, size, pos, color, onClick, anchor)
    local holder, face = panel(parent, size, pos, color, anchor, 5)
    local button = Instance.new("TextButton")
    button.BackgroundTransparency = 1
    button.Size = UDim2.fromScale(1, 1)
    button.Font = Enum.Font.LuckiestGuy
    button.Text = text
    button.TextSize = math.floor(size.Y.Offset * 0.5)
    button.TextColor3 = Color3.new(1, 1, 1)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2.5
    stroke.Color = INK
    stroke.LineJoinMode = Enum.LineJoinMode.Miter
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    stroke.Parent = button
    button.Parent = face
    button.Activated:Connect(onClick)
    button.MouseButton1Down:Connect(function()
        face.Position = UDim2.fromOffset(3, 3)
    end)
    button.MouseButton1Up:Connect(function()
        face.Position = UDim2.fromOffset(0, 0)
    end)
    button.MouseLeave:Connect(function()
        face.Position = UDim2.fromOffset(0, 0)
    end)
    return holder, button, face
end

---------------------------------------------------------------- the game's screen while the summon plays
local hidden -- nil while the HUD is shown; otherwise what setHud(false) turned off, to turn back on
local CORE = { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.EmotesMenu }

-- setHud(false): every other ScreenGui and the prompt cards go away, prompts are disabled, playing sounds are ducked and
-- the CinematicHatchUI "Active" attribute is set (the tutorial and PromptCards hide themselves on it).
-- setHud(true) restores exactly what was changed.
function Ui.setHud(on, ownsSound)
    local playerGui = player:FindFirstChild("PlayerGui")
    if not on then
        if hidden then
            return
        end
        hidden = { guis = {}, core = {}, ducked = {}, prompts = ProximityPromptService.Enabled }
        player:SetAttribute("SummonHatchActive", true)
        if playerGui then
            local cinematic = playerGui:FindFirstChild("CinematicHatchUI")
            if cinematic then
                hidden.cinematic = cinematic
                cinematic:SetAttribute("Active", true)
            end
            for _, gui in playerGui:GetChildren() do
                if
                    (gui:IsA("ScreenGui") or (gui:IsA("BillboardGui") and gui.Name == "PromptCard"))
                    and gui.Enabled
                    and gui.Name ~= Ui.GuiName
                then
                    hidden.guis[gui] = true
                    gui.Enabled = false
                end
            end
        end
        for _, kind in CORE do
            local ok, enabled = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, kind)
            if ok and enabled then
                hidden.core[kind] = true
                pcall(StarterGui.SetCoreGuiEnabled, StarterGui, kind, false)
            end
        end
        ProximityPromptService.Enabled = false
        for _, root in { workspace, SoundService } do
            for _, sound in root:GetDescendants() do
                if
                    sound:IsA("Sound")
                    and sound.Playing
                    and sound.Volume > 0
                    and not sound:GetAttribute("HatchFX")
                    and not (ownsSound and ownsSound(sound))
                then
                    hidden.ducked[sound] = sound.Volume
                    TweenService:Create(sound, TweenInfo.new(0.8), { Volume = sound.Volume * 0.35 }):Play()
                end
            end
        end
    else
        local was = hidden
        if not was then
            return
        end
        hidden = nil
        for gui in was.guis do
            if gui.Parent then
                gui.Enabled = true
            end
        end
        for kind in was.core do
            pcall(StarterGui.SetCoreGuiEnabled, StarterGui, kind, true)
        end
        ProximityPromptService.Enabled = was.prompts
        for sound, volume in was.ducked do
            if sound.Parent then
                TweenService:Create(sound, TweenInfo.new(0.6), { Volume = volume }):Play()
            end
        end
        if was.cinematic and was.cinematic.Parent then
            was.cinematic:SetAttribute("Active", false)
        end
        player:SetAttribute("SummonHatchActive", nil)
    end
end

return Ui
