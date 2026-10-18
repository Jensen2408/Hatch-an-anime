--[[ ReplicatedStorage.StolenEggBanner  (ModuleScript, client)
Compact stolen-egg banner in the game's cream / brown / vermilion style.
Same API as before (EggStealClient drives it): Start(), Show(basePosition), Resolve("Secured"|"Dropped"|"Cancelled"), Hide().
Cosmetic only; the server keeps all steal validation and rewards.
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

local CREAM, INK, RED, GOLD, GREEN, GREY =
    Color3.fromRGB(255, 243, 217),
    Color3.fromRGB(56, 34, 24),
    Color3.fromRGB(204, 68, 54),
    Color3.fromRGB(242, 190, 85),
    Color3.fromRGB(85, 163, 78),
    Color3.fromRGB(140, 128, 116)
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local COPY = {
    Stolen = { "CAPTURING EGG", "RETURN TO BASE!", RED },
    Secured = { "SUCCESS", "EGG SECURED!", GREEN },
    Dropped = { "FAILED", "EGG DROPPED", GREY },
    Cancelled = { "ENDED", "STEAL CANCELLED", GREY },
}

local function make(c, p, parent)
    local o = Instance.new(c)
    for k, v in p do
        o[k] = v
    end
    o.Parent = parent
    return o
end
local function tween(o, t, p, s, d)
    local tw = TweenService:Create(o, TweenInfo.new(t, s or Enum.EasingStyle.Quart, d or Enum.EasingDirection.Out), p)
    tw:Play()
    return tw
end
local function reduced()
    return player:GetAttribute(Config.ReducedMotionAttribute) == true
end

local gui, ui, current
local PLATE = "rbxassetid://0" -- set below by Banner.Config.PlateImage
local ASPECT = 987 / 265
local W = 470
local H = W / ASPECT
local function build()
    gui = make(
        "ScreenGui",
        { Name = "StolenEggBanner", ResetOnSpawn = false, DisplayOrder = 20, Enabled = false },
        player:WaitForChild("PlayerGui")
    )
    local holder = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, -H - 30),
        Size = UDim2.fromOffset(W, H),
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
    local shadow = make("ImageLabel", {
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
    local function at(cx, cy, w, h, z)
        return make("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(cx, cy),
            Size = UDim2.fromScale(w, h),
            BackgroundTransparency = 1,
            ZIndex = z or 3,
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
    local sub = make("TextLabel", {
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
    local left = at(0.076, 0.56, 0.1, 0.38)
    make("UIAspectRatioConstraint", { AspectRatio = 1 }, left)
    local egg = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.52),
        Size = UDim2.fromScale(0.58, 0.74),
        BackgroundColor3 = GOLD,
        ZIndex = 4,
    }, left)
    make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, egg)
    make("UIStroke", { Color = Color3.fromRGB(70, 30, 10), Thickness = 2 }, egg)
    local eggGrad =
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
    }, left)
    make("UICorner", { CornerRadius = UDim.new(1, 0) }, mark)
    make("UIStroke", { Color = Color3.fromRGB(70, 10, 10), Thickness = 1.5 }, mark)
    -- right socket: compass arrow + distance
    local right = at(0.921, 0.56, 0.1, 0.38)
    make("UIAspectRatioConstraint", { AspectRatio = 1 }, right)
    local glow = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.86, 0.86),
        BackgroundColor3 = GOLD,
        BackgroundTransparency = 0.75,
        ZIndex = 3,
    }, right)
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
    }, right)
    make("UIStroke", { Color = Color3.fromRGB(70, 10, 10), Thickness = 1.5 }, arrow)
    local dist = make("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromScale(0.5, 0.66),
        Size = UDim2.fromScale(1.1, 0.26),
        BackgroundTransparency = 1,
        FontFace = FONT,
        TextScaled = true,
        TextColor3 = Color3.new(1, 1, 1),
        Text = "",
        ZIndex = 5,
    }, right)
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
    }, right)
    make("UIStroke", { Color = Color3.fromRGB(20, 40, 10), Thickness = 1.5 }, icon)
    local vp = make("ViewportFrame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1.15, 1.15),
        BackgroundTransparency = 1,
        Ambient = Color3.fromRGB(255, 255, 255),
        LightColor = Color3.new(1, 1, 1),
        LightDirection = Vector3.new(-1, -1, -1),
        Visible = false,
        ZIndex = 5,
    }, left)
    local disc = make("Frame", {
        Name = "EggDisc",
        Visible = false,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.86, 0.86),
        BackgroundColor3 = Color3.fromRGB(255, 236, 200),
        ZIndex = 4,
    }, left)
    make("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)
    make(
        "UIGradient",
        { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 248, 225), Color3.fromRGB(240, 196, 120)) },
        disc
    )
    ui = {
        vp = vp,
        holder = holder,
        scale = scale,
        popScale = popScale,
        plate = plate,
        tag = tag,
        title = title,
        sub = sub,
        egg = egg,
        mark = mark,
        band = band,
        arrow = arrow,
        dist = dist,
        icon = icon,
        glow = glow,
        sweepGrad = sweepGrad,
        titleGrad = titleGrad,
        stroke = make("UIStroke", { Thickness = 0, Color = GOLD, Transparency = 1 }, glow),
    }
    local function fit()
        local cam = workspace.CurrentCamera
        if not cam then
            return
        end
        local view = cam.ViewportSize
        local s = (view.X - 24) / W
        -- Phones (short screens): keep the banner to about a fifth of the screen height.
        local phone = view.Y < 500 or (game:GetService("UserInputService").TouchEnabled and view.X < 1100)
        if phone then
            s = math.min(s, view.Y * 0.13 / H)
        end
        scale.Scale = math.clamp(s, phone and 0.3 or 0.5, 0.9)
    end
    fit()
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
end

local function playSound(id)
    if not id or id == "" or player:GetAttribute(Config.MuteAttribute) then
        return
    end
    local s = make("Sound", { SoundId = id, Volume = Config.Volume }, gui)
    local grp = SoundService:FindFirstChild(Config.SoundGroupName)
    if grp and grp:IsA("SoundGroup") then
        s.SoundGroup = grp
    end
    s.Ended:Once(function()
        s:Destroy()
    end)
    s:Play()
    task.delay(6, function()
        if s.Parent then
            s:Destroy()
        end
    end)
end

local function isPhone()
    local c = workspace.CurrentCamera
    return c
        and (c.ViewportSize.Y < 500 or (game:GetService("UserInputService").TouchEnabled and c.ViewportSize.X < 1100))
end
local function topY()
    if isPhone() then
        return 4
    end
    return GuiService:GetGuiInset().Y + 6
end
local RAR = {
    Common = "#C8C8C8",
    Uncommon = "#7FD86E",
    Rare = "#6FB2FF",
    Epic = "#C98BFF",
    Legendary = "#FFC94A",
    Mythic = "#FF6F8E",
    Secret = "#FFFFFF",
}
local function short(n)
    n = tonumber(n) or 0
    for _, u in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
        if n >= u[1] then
            return (string.format("%.1f", n / u[1]):gsub("%.0$", "")) .. u[2]
        end
    end
    return tostring(math.floor(n))
end
local info = {}
local function setState(state)
    local stolen = state == "Stolen"
    local nameLine = info.name and ('<font color="#FFFFFF">' .. info.name .. "</font>") or ""
    if info.rarity then
        nameLine = nameLine
            .. '  <font color="'
            .. (RAR[info.rarity] or "#FFFFFF")
            .. '">'
            .. string.upper(info.rarity)
            .. "</font>"
    end
    if info.price and info.price > 0 then
        nameLine = nameLine .. '  <font color="#9BE07A">$' .. short(info.price) .. "</font>"
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

local trackConn, loops = nil, {}
local function stopTracking()
    if trackConn then
        trackConn:Disconnect()
        trackConn = nil
    end
    for _, t in loops do
        t:Cancel()
    end
    table.clear(loops)
    ui.egg.Rotation = 0
    ui.glow.Size = UDim2.fromScale(0.86, 0.86)
end
local function loop(o, t, props)
    local tw =
        TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), props)
    tw:Play()
    table.insert(loops, tw)
end
local function startTracking(basePos)
    stopTracking()
    local acc = 0
    trackConn = RunService.RenderStepped:Connect(function(dt)
        acc += dt
        if acc < 0.05 then
            return
        end
        acc = 0
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local cam = workspace.CurrentCamera
        if not hrp or not cam or typeof(basePos) ~= "Vector3" then
            return
        end
        local to = basePos - hrp.Position
        local flat = Vector3.new(to.X, 0, to.Z)
        local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
        if flat.Magnitude > 0.1 and look.Magnitude > 0.01 then
            ui.arrow.Rotation = -math.deg(math.atan2(look.Unit:Cross(flat.Unit).Y, look.Unit:Dot(flat.Unit)))
        end
        local d = math.floor(flat.Magnitude + 0.5)
        ui.dist.Text = d .. "m"
        ui.dist.TextColor3 = d < 25 and Color3.fromRGB(150, 255, 140) or Color3.new(1, 1, 1)
    end)
    if not reduced() then
        ui.egg.Rotation = -8
        loop(ui.egg, 0.35, { Rotation = 8 })
        loop(ui.glow, 0.7, { Size = UDim2.fromScale(1.05, 1.05) })
    end
end

local token = 0
local function shineLoop(my)
    task.spawn(function()
        while my == token and gui.Enabled and not reduced() do
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
    if reduced() then
        ui.holder.Position = UDim2.new(0.5, 0, 0, topY())
        return
    end
    ui.holder.Position = UDim2.new(0.5, 0, 0, -H - 30)
    ui.popScale.Scale = 0.9
    tween(ui.holder, 0.45, { Position = UDim2.new(0.5, 0, 0, topY()) }, Enum.EasingStyle.Back)
    tween(ui.popScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- 3D picture of the egg you're carrying (copied from the StolenEggCarry model the server attaches)
local spinConn
local function clearPreview()
    if spinConn then
        spinConn:Disconnect()
        spinConn = nil
    end
    ui.vp:ClearAllChildren()
    ui.vp.Visible = false
    ui.egg.Visible = true
    ui.vp.Parent.EggDisc.Visible = false
end
local function showPreview(myToken)
    task.spawn(function()
        local src
        -- 1) clean preview model for this egg type (all eggs have one)
        local previews = game:GetService("ReplicatedStorage"):FindFirstChild("GameMenu")
            and game:GetService("ReplicatedStorage").GameMenu:FindFirstChild("EggPreviews")
        if previews then
            local want = {}
            for _, k in
                {
                    info.eggType,
                    info.name,
                    player:GetAttribute("CarryingStolenEggType"),
                    player:GetAttribute("RiverEggCarryType"),
                }
            do
                if type(k) == "string" then
                    table.insert(want, (k:gsub("%s*[Ee]gg%s*$", "")):lower())
                end
            end
            for _, mdl in previews:GetChildren() do
                local n = mdl.Name:gsub("^MenuEgg_", ""):lower()
                for _, w in want do
                    if w == n then
                        src = mdl
                    end
                end
            end
        end
        -- 2) otherwise the egg on your character
        for _ = 1, src and 0 or 30 do
            local char = player.Character
            src = char
                    and (char:FindFirstChild("StolenEggCarry", true) or char:FindFirstChild("HeldItemCarry") or char:FindFirstChild(
                        "RiverEggCarry"
                    ))
                or workspace:FindFirstChild("StolenEggCarry_" .. player.UserId, true)
            if src or myToken ~= token then
                break
            end
            task.wait(0.1)
        end
        if not src or myToken ~= token then
            return
        end
        local model = Instance.new("Model")
        for _, d in src:GetDescendants() do
            if d:IsA("BasePart") and (d.Transparency < 0.95 or src.Name:find("^MenuEgg_")) and d.Name ~= "Carrier" then
                local c = d:Clone()
                for _, x in c:GetDescendants() do
                    if
                        not (x:IsA("DataModelMesh") or x:IsA("Decal") or x:IsA("Texture") or x:IsA("SurfaceAppearance"))
                    then
                        x:Destroy()
                    end
                end
                c.Anchored = true
                c.Parent = model
            end
        end
        if #model:GetChildren() == 0 then
            model:Destroy()
            return
        end
        local cf, size = model:GetBoundingBox()
        for _, p in model:GetChildren() do
            p.CFrame = cf:Inverse() * p.CFrame
        end -- centre at origin
        model.Parent = ui.vp
        local cam = Instance.new("Camera")
        cam.FieldOfView = 30
        cam.Parent = ui.vp
        ui.vp.CurrentCamera = cam
        local r = math.max(size.X, size.Y, size.Z)
        local distance = r / math.tan(math.rad(15)) * 0.6
        local angle = 0
        spinConn = RunService.RenderStepped:Connect(function(dt)
            angle += dt * 0.9
            cam.CFrame =
                CFrame.new(Vector3.new(math.sin(angle) * distance, 0, math.cos(angle) * distance), Vector3.zero)
        end)
        ui.vp.Visible = true
        ui.egg.Visible = false
        ui.vp.Parent.EggDisc.Visible = true
    end)
end

function Banner.Show(basePosition, d)
    if type(d) == "table" then
        info = { name = d.name, rarity = d.rarity, price = tonumber(d.price), eggType = d.eggType }
    end
    if current == "Stolen" and gui.Enabled then
        if typeof(basePosition) == "Vector3" then
            startTracking(basePosition)
        end
        if type(d) == "table" and (d.eggType or d.name) then
            clearPreview()
            showPreview(token)
        end
        return
    end
    token += 1
    current = "Stolen"
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
    if not COPY[state] or state == "Stolen" or not current then
        return
    end
    token += 1
    local my = token
    current = state
    stopTracking()
    setState(state)
    if not reduced() then
        ui.popScale.Scale = 1
        tween(ui.popScale, 0.12, { Scale = 1.07 }).Completed:Once(function()
            tween(ui.popScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
        end)
        if state == "Secured" then
            shineLoop(my)
        end
    end
    playSound(state == "Secured" and Config.SuccessSound or Config.FailSound)
    task.delay(Config.DismissAfter[state] or 1.8, function()
        if my == token then
            Banner.Hide()
        end
    end)
end

function Banner.Hide()
    token += 1
    task.delay(0.5, function()
        if not current then
            clearPreview()
        end
    end)
    local my = token
    stopTracking()
    current = nil
    if not gui.Enabled then
        return
    end
    if reduced() then
        gui.Enabled = false
        return
    end
    tween(ui.holder, 0.3, { Position = UDim2.new(0.5, 0, 0, -H - 40) }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Once(
        function()
            if my == token then
                gui.Enabled = false
            end
        end
    )
end

local started = false
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
        if current == "Stolen" then
            Banner.Hide()
        end
    end)
end

return Banner
