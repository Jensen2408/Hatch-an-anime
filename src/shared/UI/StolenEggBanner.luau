--[[ ReplicatedStorage.StolenEggBanner  (ModuleScript, client)
Compact stolen-egg banner in the game's cream / brown / vermilion style.
Same API as before (EggStealClient drives it): Start(), Show(basePosition), Resolve("Secured"|"Dropped"|"Cancelled"), Hide().
Show() also accepts an optional egg-info table: { name, rarity, price, eggType }.
Cosmetic only; the server keeps all steal validation and rewards.

Every Show/Resolve/Hide bumps `token`; delayed callbacks and background loops compare their captured
token against it so a stale callback never touches a newer banner state.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")

local Banner = {}
local player = Players.LocalPlayer

local Config = {
    AlertSound = "rbxassetid://9126047777", -- Synth Air Whoosh
    SuccessSound = "rbxassetid://112485797063762", -- UI Accomplishment Ding
    FailSound = "",
    Volume = 0.35,
    SoundGroupName = "SFX",
    MuteAttribute = "SFXMuted",
    ReducedMotionAttribute = "ReducedMotion",
    DismissAfter = { Secured = 2.2, Dropped = 2, Cancelled = 1.8 },
    PlateImage = "rbxassetid://95919146105293",
}
Banner.Config = Config

local _CREAM, _INK, RED, GOLD, GREEN, GREY =
    Color3.fromRGB(255, 243, 217),
    Color3.fromRGB(56, 34, 24),
    Color3.fromRGB(204, 68, 54),
    Color3.fromRGB(242, 190, 85),
    Color3.fromRGB(85, 163, 78),
    Color3.fromRGB(140, 128, 116)
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
-- Only the keys are used (Resolve() validates its state against them); the visible text lives in setState().
local COPY = {
    Stolen = { "CAPTURING EGG", "RETURN TO BASE!", RED },
    Secured = { "SUCCESS", "EGG SECURED!", GREEN },
    Dropped = { "FAILED", "EGG DROPPED", GREY },
    Cancelled = { "ENDED", "STEAL CANCELLED", GREY },
}

local function make(className, props, parent)
    local instance = Instance.new(className)
    for key, value in props do
        instance[key] = value
    end
    instance.Parent = parent
    return instance
end
local function tween(instance, duration, goal, style, direction)
    local activeTween = TweenService:Create(
        instance,
        TweenInfo.new(duration, style or Enum.EasingStyle.Quart, direction or Enum.EasingDirection.Out),
        goal
    )
    activeTween:Play()
    return activeTween
end
local function isReducedMotion()
    return player:GetAttribute(Config.ReducedMotionAttribute) == true
end

local gui, ui, currentState -- currentState: nil (hidden) | "Stolen" | "Secured" | "Dropped" | "Cancelled"
local _PLATE = "rbxassetid://0" -- Unused; the plate image comes from Banner.Config.PlateImage.
local PLATE_ASPECT = 987 / 265 -- source image is 987x265 px
local BANNER_WIDTH = 470
local BANNER_HEIGHT = BANNER_WIDTH / PLATE_ASPECT
local function build()
    gui = make(
        "ScreenGui",
        { Name = "StolenEggBanner", ResetOnSpawn = false, DisplayOrder = 20, Enabled = false },
        player:WaitForChild("PlayerGui")
    )
    -- holder slides in from above the screen; pop is scaled for the "bump" on resolve.
    local holder = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, -BANNER_HEIGHT - 30),
        Size = UDim2.fromOffset(BANNER_WIDTH, BANNER_HEIGHT),
        BackgroundTransparency = 1,
    }, gui)
    local scale = make("UIScale", {}, holder)
    local pop = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
    }, holder)
    local popScale = make("UIScale", {}, pop)
    -- soft drop shadow + painted plaque (studs, gold trim, blossoms)
    local _shadow = make("ImageLabel", {
        Position = UDim2.fromOffset(0, 6),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Image = Config.PlateImage,
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 0.6,
    }, pop)
    local plate = make(
        "ImageLabel",
        { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = Config.PlateImage, ZIndex = 2 },
        pop
    )
    -- Transparent frame centred at (centerX, centerY) in plate scale; used for the round sockets painted on the plate.
    local function socketFrame(centerX, centerY, width, height, zIndex)
        return make("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(centerX, centerY),
            Size = UDim2.fromScale(width, height),
            BackgroundTransparency = 1,
            ZIndex = zIndex or 3,
        }, plate)
    end
    -- inner panel: shine sweep + text
    local inner = make("Frame", {
        Position = UDim2.fromScale(0.192, 0.37),
        Size = UDim2.fromScale(0.618, 0.505),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 3,
    }, plate)
    local sweep = make("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(255, 225, 150),
        BorderSizePixel = 0,
        ZIndex = 3,
    }, inner)
    local sweepGrad = make("UIGradient", {
        Rotation = 18,
        Offset = Vector2.new(-1.3, 0),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.43, 1),
            NumberSequenceKeypoint.new(0.5, 0.75),
            NumberSequenceKeypoint.new(0.57, 1),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, sweep)
    local tag = make("TextLabel", {
        Position = UDim2.fromScale(0, 0.1),
        Size = UDim2.fromScale(1, 0.28),
        BackgroundTransparency = 1,
        FontFace = FONT,
        TextScaled = true,
        TextColor3 = GOLD,
        Text = "",
        ZIndex = 4,
        RichText = true,
    }, inner)
    local title = make("TextLabel", {
        Position = UDim2.fromScale(0, 0.38),
        Size = UDim2.fromScale(1, 0.5),
        BackgroundTransparency = 1,
        FontFace = FONT,
        TextScaled = true,
        TextColor3 = Color3.new(1, 1, 1),
        Text = "",
        ZIndex = 5,
    }, inner)
    make("UIStroke", { Color = Color3.fromRGB(70, 10, 10), Thickness = 2.5 }, title)
    local titleGrad = make(
        "UIGradient",
        { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 220, 150)) },
        title
    )
    -- Rich-text egg name/rarity/price line; built hidden (Visible = false) and only its Text is updated.
    local subtitle = make("TextLabel", {
        Visible = false,
        Position = UDim2.fromScale(0, 0.72),
        Size = UDim2.fromScale(1, 0.24),
        BackgroundTransparency = 1,
        FontFace = FONT,
        TextScaled = true,
        TextColor3 = Color3.fromRGB(255, 214, 200),
        Text = "",
        ZIndex = 4,
        RichText = true,
    }, inner)
    -- left socket: the egg (wobbles while stolen)
    local leftSocket = socketFrame(0.076, 0.56, 0.1, 0.38)
    make("UIAspectRatioConstraint", { AspectRatio = 1 }, leftSocket)
    local egg = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.52),
        Size = UDim2.fromScale(0.58, 0.74),
        BackgroundColor3 = GOLD,
        ZIndex = 4,
    }, leftSocket)
    make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, egg)
    make("UIStroke", { Color = Color3.fromRGB(70, 30, 10), Thickness = 2 }, egg)
    local _eggGrad =
        make("UIGradient", { Rotation = 60, Color = ColorSequence.new(Color3.fromRGB(255, 240, 190), GOLD) }, egg)
    local band = make("Frame", {
        Position = UDim2.fromScale(0, 0.44),
        Size = UDim2.fromScale(1, 0.14),
        BackgroundColor3 = RED,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, egg)
    local eggShine = make("Frame", {
        Position = UDim2.fromScale(0.22, 0.12),
        Size = UDim2.fromScale(0.22, 0.28),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.35,
        ZIndex = 5,
    }, egg)
    make("UICorner", { CornerRadius = UDim.new(1, 0) }, eggShine)
    local mark = make("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.86, 0.14),
        Size = UDim2.fromScale(0.42, 0.42),
        BackgroundColor3 = RED,
        FontFace = FONT,
        TextScaled = true,
        TextColor3 = Color3.new(1, 1, 1),
        Text = "!",
        ZIndex = 6,
    }, leftSocket)
    make("UICorner", { CornerRadius = UDim.new(1, 0) }, mark)
    make("UIStroke", { Color = Color3.fromRGB(70, 10, 10), Thickness = 1.5 }, mark)
    -- right socket: compass arrow + distance
    local rightSocket = socketFrame(0.921, 0.56, 0.1, 0.38)
    make("UIAspectRatioConstraint", { AspectRatio = 1 }, rightSocket)
    local glow = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.86, 0.86),
        BackgroundColor3 = GOLD,
        BackgroundTransparency = 0.75,
        ZIndex = 3,
    }, rightSocket)
    make("UICorner", { CornerRadius = UDim.new(1, 0) }, glow)
    local arrow = make("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.4),
        Size = UDim2.fromScale(0.62, 0.62),
        BackgroundTransparency = 1,
        FontFace = FONT,
        TextScaled = true,
        TextColor3 = GOLD,
        Text = "▲",
        ZIndex = 5,
    }, rightSocket)
    make("UIStroke", { Color = Color3.fromRGB(70, 10, 10), Thickness = 1.5 }, arrow)
    local distanceLabel = make("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromScale(0.5, 0.66),
        Size = UDim2.fromScale(1.1, 0.26),
        BackgroundTransparency = 1,
        FontFace = FONT,
        TextScaled = true,
        TextColor3 = Color3.new(1, 1, 1),
        Text = "",
        ZIndex = 5,
    }, rightSocket)
    -- Result icon (check / cross) that replaces the arrow once the steal is resolved.
    local icon = make("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.7, 0.7),
        BackgroundTransparency = 1,
        FontFace = FONT,
        TextScaled = true,
        TextColor3 = GREEN,
        Text = "",
        Visible = false,
        ZIndex = 5,
    }, rightSocket)
    make("UIStroke", { Color = Color3.fromRGB(20, 40, 10), Thickness = 1.5 }, icon)
    -- 3D egg preview (see showPreview); swaps with the flat 2D egg when a model is available.
    local viewport = make("ViewportFrame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1.15, 1.15),
        BackgroundTransparency = 1,
        Ambient = Color3.fromRGB(255, 255, 255),
        LightColor = Color3.new(1, 1, 1),
        LightDirection = Vector3.new(-1, -1, -1),
        Visible = false,
        ZIndex = 5,
    }, leftSocket)
    local disc = make("Frame", {
        Name = "EggDisc",
        Visible = false,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.86, 0.86),
        BackgroundColor3 = Color3.fromRGB(255, 236, 200),
        ZIndex = 4,
    }, leftSocket)
    make("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)
    make(
        "UIGradient",
        { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 248, 225), Color3.fromRGB(240, 196, 120)) },
        disc
    )
    ui = {
        vp = viewport,
        holder = holder,
        scale = scale,
        popScale = popScale,
        plate = plate,
        tag = tag,
        title = title,
        sub = subtitle,
        egg = egg,
        mark = mark,
        band = band,
        arrow = arrow,
        dist = distanceLabel,
        icon = icon,
        glow = glow,
        sweepGrad = sweepGrad,
        titleGrad = titleGrad,
        stroke = make("UIStroke", { Thickness = 0, Color = GOLD, Transparency = 1 }, glow),
    }
    -- Scale the banner to the viewport width (minus a 12 px margin each side), clamped.
    local function fit()
        local camera = workspace.CurrentCamera
        if not camera then
            return
        end
        local view = camera.ViewportSize
        local fitScale = (view.X - 24) / BANNER_WIDTH
        -- Phones (short screens): keep the banner to about a fifth of the screen height.
        local phone = view.Y < 500 or (game:GetService("UserInputService").TouchEnabled and view.X < 1100)
        if phone then
            fitScale = math.min(fitScale, view.Y * 0.13 / BANNER_HEIGHT)
        end
        scale.Scale = math.clamp(fitScale, phone and 0.3 or 0.5, 0.9)
    end
    fit()
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
end

-- One-shot Sound parented to the banner gui; destroyed on Ended or after 6 s at the latest.
local function playSound(id)
    if not id or id == "" or player:GetAttribute(Config.MuteAttribute) then
        return
    end
    local sound = make("Sound", { SoundId = id, Volume = Config.Volume }, gui)
    local soundGroup = SoundService:FindFirstChild(Config.SoundGroupName)
    if soundGroup and soundGroup:IsA("SoundGroup") then
        sound.SoundGroup = soundGroup
    end
    sound.Ended:Once(function()
        sound:Destroy()
    end)
    sound:Play()
    task.delay(6, function()
        if sound.Parent then
            sound:Destroy()
        end
    end)
end

-- Same phone heuristic as fit() inside build().
local function isPhone()
    local camera = workspace.CurrentCamera
    return camera
        and (
            camera.ViewportSize.Y < 500
            or (game:GetService("UserInputService").TouchEnabled and camera.ViewportSize.X < 1100)
        )
end
-- Resting Y offset of the banner: just below the top-bar inset on desktop, flush to the top on phones.
local function topY()
    if isPhone() then
        return 4
    end
    return GuiService:GetGuiInset().Y + 6
end
-- Rich-text hex colour per rarity for the subtitle line.
local RARITY_HEX = {
    Common = "#C8C8C8",
    Uncommon = "#7FD86E",
    Rare = "#6FB2FF",
    Epic = "#C98BFF",
    Legendary = "#FFC94A",
    Mythic = "#FF6F8E",
    Secret = "#FFFFFF",
}
-- 1 decimal with a unit suffix ("1.5K", "2M"); plain integer below 1000.
local function short(n)
    n = tonumber(n) or 0
    for _, unit in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
        if n >= unit[1] then
            return (string.format("%.1f", n / unit[1]):gsub("%.0$", "")) .. unit[2]
        end
    end
    return tostring(math.floor(n))
end
local eggInfo = {} -- { name?, rarity?, price?, eggType? } from the last Show() call that passed a table
local function setState(state)
    local stolen = state == "Stolen"
    local nameLine = eggInfo.name and ('<font color="#FFFFFF">' .. eggInfo.name .. "</font>") or ""
    if eggInfo.rarity then
        nameLine = nameLine
            .. '  <font color="'
            .. (RARITY_HEX[eggInfo.rarity] or "#FFFFFF")
            .. '">'
            .. string.upper(eggInfo.rarity)
            .. "</font>"
    end
    if eggInfo.price and eggInfo.price > 0 then
        nameLine = nameLine .. '  <font color="#9BE07A">$' .. short(eggInfo.price) .. "</font>"
    end
    if state == "Stolen" then
        ui.tag.Text = "STOLEN EGG"
        ui.title.Text = "RETURN TO BASE!"
        ui.sub.Text = nameLine ~= "" and nameLine or "Get it home before you're caught!"
        ui.titleGrad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 220, 150))
        ui.mark.Text = "!"
        ui.mark.BackgroundColor3 = RED
    elseif state == "Secured" then
        ui.tag.Text = "SUCCESS"
        ui.title.Text = "EGG SECURED!"
        ui.sub.Text = nameLine ~= "" and (nameLine .. "  is yours") or "The egg is safe in your base"
        ui.titleGrad.Color = ColorSequence.new(Color3.fromRGB(235, 255, 225), Color3.fromRGB(120, 230, 110))
        ui.mark.Text = "✓"
        ui.mark.BackgroundColor3 = GREEN
    else
        ui.tag.Text = state == "Dropped" and "FAILED" or "ENDED"
        ui.title.Text = state == "Dropped" and "EGG DROPPED" or "STEAL CANCELLED"
        ui.sub.Text = state == "Dropped" and "Bonked! Grab it back before someone else does" or "The steal has ended"
        ui.titleGrad.Color = ColorSequence.new(Color3.fromRGB(235, 235, 240), Color3.fromRGB(170, 170, 185))
        ui.mark.Text = "×"
        ui.mark.BackgroundColor3 = GREY
    end
    ui.arrow.Visible, ui.dist.Visible = stolen, stolen
    ui.icon.Visible = not stolen
    ui.icon.Text = state == "Secured" and "✓" or "×"
    ui.icon.TextColor3 = state == "Secured" and GREEN or Color3.fromRGB(230, 230, 235)
    ui.glow.BackgroundColor3 = state == "Secured" and GREEN or (stolen and GOLD or GREY)
end

---------------------------------------------------------------- compass tracking + idle loops
local trackConnection, loopTweens = nil, {}
local function stopTracking()
    if trackConnection then
        trackConnection:Disconnect()
        trackConnection = nil
    end
    for _, loopTween in loopTweens do
        loopTween:Cancel()
    end
    table.clear(loopTweens)
    ui.egg.Rotation = 0
    ui.glow.Size = UDim2.fromScale(0.86, 0.86)
end
-- Infinite reversing Sine tween; cancelled by stopTracking().
local function startLoopTween(instance, duration, goal)
    local loopTween = TweenService:Create(
        instance,
        TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        goal
    )
    loopTween:Play()
    table.insert(loopTweens, loopTween)
end
-- Points the arrow at basePos relative to the camera's flat look direction and shows the distance (20 Hz).
local function startTracking(basePos)
    stopTracking()
    local elapsed = 0
    trackConnection = RunService.RenderStepped:Connect(function(dt)
        elapsed += dt
        if elapsed < 0.05 then
            return
        end
        elapsed = 0
        local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local camera = workspace.CurrentCamera
        if not rootPart or not camera or typeof(basePos) ~= "Vector3" then
            return
        end
        local toBase = basePos - rootPart.Position
        local flatToBase = Vector3.new(toBase.X, 0, toBase.Z)
        local flatLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
        if flatToBase.Magnitude > 0.1 and flatLook.Magnitude > 0.01 then
            -- Signed yaw angle between look and target directions.
            ui.arrow.Rotation =
                -math.deg(math.atan2(flatLook.Unit:Cross(flatToBase.Unit).Y, flatLook.Unit:Dot(flatToBase.Unit)))
        end
        local meters = math.floor(flatToBase.Magnitude + 0.5)
        ui.dist.Text = meters .. "m"
        ui.dist.TextColor3 = meters < 25 and Color3.fromRGB(150, 255, 140) or Color3.new(1, 1, 1)
    end)
    if not isReducedMotion() then
        ui.egg.Rotation = -8
        startLoopTween(ui.egg, 0.35, { Rotation = 8 })
        startLoopTween(ui.glow, 0.7, { Size = UDim2.fromScale(1.05, 1.05) })
    end
end

local token = 0 -- banner generation; see header comment
-- Repeats the shine sweep every 2.4 s while this generation is current and the banner is visible.
local function shineLoop(myToken)
    task.spawn(function()
        while myToken == token and gui.Enabled and not isReducedMotion() do
            ui.sweepGrad.Offset = Vector2.new(-1.3, 0)
            TweenService
                :Create(ui.sweepGrad, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Offset = Vector2.new(1.3, 0) })
                :Play()
            task.wait(2.4)
        end
    end)
end
local function slideIn()
    gui.Enabled = true
    if isReducedMotion() then
        ui.holder.Position = UDim2.new(0.5, 0, 0, topY())
        return
    end
    ui.holder.Position = UDim2.new(0.5, 0, 0, -BANNER_HEIGHT - 30)
    ui.popScale.Scale = 0.9
    tween(ui.holder, 0.45, { Position = UDim2.new(0.5, 0, 0, topY()) }, Enum.EasingStyle.Back)
    tween(ui.popScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
end

---------------------------------------------------------------- 3D egg preview
-- 3D picture of the egg you're carrying (copied from the StolenEggCarry model the server attaches)
local spinConnection
local function clearPreview()
    if spinConnection then
        spinConnection:Disconnect()
        spinConnection = nil
    end
    ui.vp:ClearAllChildren()
    ui.vp.Visible = false
    ui.egg.Visible = true
    ui.vp.Parent.EggDisc.Visible = false
end
local function showPreview(myToken)
    task.spawn(function()
        local sourceModel
        -- 1) clean preview model for this egg type (all eggs have one)
        local previews = game:GetService("ReplicatedStorage"):FindFirstChild("GameMenu")
            and game:GetService("ReplicatedStorage").GameMenu:FindFirstChild("EggPreviews")
        if previews then
            -- Candidate names, lower-cased with a trailing " Egg" stripped, matched against "MenuEgg_<name>".
            local wantedNames = {}
            for _, candidate in
                {
                    eggInfo.eggType,
                    eggInfo.name,
                    player:GetAttribute("CarryingStolenEggType"),
                    player:GetAttribute("RiverEggCarryType"),
                }
            do
                if type(candidate) == "string" then
                    table.insert(wantedNames, (candidate:gsub("%s*[Ee]gg%s*$", "")):lower())
                end
            end
            for _, previewModel in previews:GetChildren() do
                local previewName = previewModel.Name:gsub("^MenuEgg_", ""):lower()
                for _, wantedName in wantedNames do
                    if wantedName == previewName then
                        sourceModel = previewModel
                    end
                end
            end
        end
        -- 2) otherwise the egg on your character (polls up to 30 x 0.1 s for the carry model to replicate)
        for _ = 1, sourceModel and 0 or 30 do
            local character = player.Character
            sourceModel = character
                    and (character:FindFirstChild("StolenEggCarry", true) or character:FindFirstChild("HeldItemCarry") or character:FindFirstChild(
                        "RiverEggCarry"
                    ))
                or workspace:FindFirstChild("StolenEggCarry_" .. player.UserId, true)
            if sourceModel or myToken ~= token then
                break
            end
            task.wait(0.1)
        end
        if not sourceModel or myToken ~= token then
            return
        end
        -- Copy visible parts (all parts for MenuEgg_ previews) keeping only their mesh/surface children.
        local model = Instance.new("Model")
        for _, descendant in sourceModel:GetDescendants() do
            if
                descendant:IsA("BasePart")
                and (descendant.Transparency < 0.95 or sourceModel.Name:find("^MenuEgg_"))
                and descendant.Name ~= "Carrier"
            then
                local partClone = descendant:Clone()
                for _, child in partClone:GetDescendants() do
                    if
                        not (
                            child:IsA("DataModelMesh")
                            or child:IsA("Decal")
                            or child:IsA("Texture")
                            or child:IsA("SurfaceAppearance")
                        )
                    then
                        child:Destroy()
                    end
                end
                partClone.Anchored = true
                partClone.Parent = model
            end
        end
        if #model:GetChildren() == 0 then
            model:Destroy()
            return
        end
        local boundsCFrame, boundsSize = model:GetBoundingBox()
        for _, part in model:GetChildren() do
            part.CFrame = boundsCFrame:Inverse() * part.CFrame
        end -- centre at origin
        model.Parent = ui.vp
        local previewCamera = Instance.new("Camera")
        previewCamera.FieldOfView = 30
        previewCamera.Parent = ui.vp
        ui.vp.CurrentCamera = previewCamera
        -- Orbit distance that fits the largest extent inside the 30 deg FOV (half-angle 15 deg), slightly zoomed in.
        local radius = math.max(boundsSize.X, boundsSize.Y, boundsSize.Z)
        local distance = radius / math.tan(math.rad(15)) * 0.6
        local angle = 0
        spinConnection = RunService.RenderStepped:Connect(function(dt)
            angle += dt * 0.9
            previewCamera.CFrame =
                CFrame.new(Vector3.new(math.sin(angle) * distance, 0, math.cos(angle) * distance), Vector3.zero)
        end)
        ui.vp.Visible = true
        ui.egg.Visible = false
        ui.vp.Parent.EggDisc.Visible = true
    end)
end

---------------------------------------------------------------- public API
function Banner.Show(basePosition, eggData)
    if type(eggData) == "table" then
        eggInfo = {
            name = eggData.name,
            rarity = eggData.rarity,
            price = tonumber(eggData.price),
            eggType = eggData.eggType,
        }
    end
    -- Already showing a steal: only refresh tracking / preview, don't replay the slide-in.
    if currentState == "Stolen" and gui.Enabled then
        if typeof(basePosition) == "Vector3" then
            startTracking(basePosition)
        end
        if type(eggData) == "table" and (eggData.eggType or eggData.name) then
            clearPreview()
            showPreview(token)
        end
        return
    end
    token += 1
    currentState = "Stolen"
    setState("Stolen")
    clearPreview()
    showPreview(token)
    slideIn()
    shineLoop(token)
    playSound(Config.AlertSound)
    if typeof(basePosition) == "Vector3" then
        startTracking(basePosition)
    else
        ui.dist.Text = ""
    end
end

function Banner.Resolve(state)
    if not COPY[state] or state == "Stolen" or not currentState then
        return
    end
    token += 1
    local myToken = token
    currentState = state
    stopTracking()
    setState(state)
    if not isReducedMotion() then
        ui.popScale.Scale = 1
        tween(ui.popScale, 0.12, { Scale = 1.07 }).Completed:Once(function()
            tween(ui.popScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
        end)
        if state == "Secured" then
            shineLoop(myToken)
        end
    end
    playSound(state == "Secured" and Config.SuccessSound or Config.FailSound)
    task.delay(Config.DismissAfter[state] or 1.8, function()
        if myToken == token then
            Banner.Hide()
        end
    end)
end

function Banner.Hide()
    token += 1
    -- Clear the 3D preview after the slide-out, unless a new banner was shown meanwhile.
    task.delay(0.5, function()
        if not currentState then
            clearPreview()
        end
    end)
    local myToken = token
    stopTracking()
    currentState = nil
    if not gui.Enabled then
        return
    end
    if isReducedMotion() then
        gui.Enabled = false
        return
    end
    tween(
        ui.holder,
        0.3,
        { Position = UDim2.new(0.5, 0, 0, -BANNER_HEIGHT - 40) },
        Enum.EasingStyle.Back,
        Enum.EasingDirection.In
    ).Completed:Once(function()
        if myToken == token then
            gui.Enabled = false
        end
    end)
end

local started = false
-- Idempotent; builds the gui (yields on PlayerGui) and hides the banner when the character respawns mid-steal.
function Banner.Start()
    if started then
        return
    end
    started = true
    build()
    task.spawn(function()
        pcall(function()
            game:GetService("ContentProvider"):PreloadAsync({ ui.plate })
        end)
    end)
    player.CharacterRemoving:Connect(function()
        if currentState == "Stolen" then
            Banner.Hide()
        end
    end)
end

return Banner
