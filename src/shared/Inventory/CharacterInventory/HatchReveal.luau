--[[ ReplicatedStorage.CharacterInventory.HatchReveal  (ModuleScript)
The Power reveal card shown after a hatch. Order of events:

  1. Your CinematicHatch shot presents the character ("… UNLOCKED").
  2. Config.Reveal.Delay later this card rises: rarity + name first.
  3. Power rolls up to the server's value (log-scaled, so it passes through K → M → B → T instead
     of sitting on one unit), then lands on the exact result and stays still.
  4. Roll quality appears. Ordinary rolls get a small settle; notable rolls get one shine sweep and a
     few square particles; top rolls a stronger sweep and more particles.

The number never passes the real value and always ends on it exactly. The card shows only what the
server sent: no odds, no "1 in X" claims, nothing invented.
]]
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Config = require(script.Parent.InventoryConfig)
local Format = require(script.Parent.InventoryFormat)
local Style = require(script.Parent.InventoryStyle)
local UISound = require(game:GetService("ReplicatedStorage"):WaitForChild("UISound"))

local T = Config.Theme
local F = Config.Fonts
local R = Config.Reveal
local make, text, chip = Style.Make, Style.Text, Style.Chip

local Reveal = {}
Reveal.__index = Reveal

function Reveal.new(gui)
    local self = setmetatable({ gui = gui, queue = {}, running = false }, Reveal)
    return self
end

local function reduced()
    return Players.LocalPlayer:GetAttribute("ReducedMotion") == true
end

local function compactScreen()
    local cam = workspace.CurrentCamera
    local v = cam and cam.ViewportSize or Vector2.new(1280, 720)
    return v.X < Config.Layout.CompactBelowWidth or v.Y < Config.Layout.CompactBelowHeight
end

function Reveal:Push(data)
    table.insert(self.queue, data)
    if not self.running then
        self.running = true
        task.spawn(function()
            while #self.queue > 0 do
                local nextData = table.remove(self.queue, 1)
                local ok, err = pcall(self._play, self, nextData)
                if not ok then
                    warn("[Inventory] reveal: " .. tostring(err))
                end
            end
            self.running = false
        end)
    end
end

function Reveal:_build(data)
    local compact = compactScreen()
    local W, H = compact and 300 or 360, compact and 136 or 164
    local holder = make("Frame", {
        Name = "HatchReveal",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, compact and -96 or -132),
        Size = UDim2.fromOffset(W, H),
    }, self.gui)
    local group =
        make("CanvasGroup", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), GroupTransparency = 1 }, holder)
    -- the leaderboard's shrine shell in temple colours: lacquer brown, gold bevel and studs, dark-wood page
    -- (inset by the stroke width so the CanvasGroup never clips the edge)
    local card = Style.Shell(group, { Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4) }, 12)
    local edge = card:FindFirstChildOfClass("UIStroke")
    local band = Style.StudBand(card, 6, 26, 6, 2)
    band.Position = UDim2.fromOffset(18, 5)
    band.Size = UDim2.new(1, -36, 0, 6)
    local page = Style.Page(card, 6, 14, 6, 6, 8)

    local rarityColor = T.Rarity[data.rarity] or T.Rarity.Common
    local top = compact and 6 or 8
    local rarity =
        chip(page, string.upper(data.rarity), rarityColor, { Position = UDim2.fromOffset(10, top), ZIndex = 3 })
    local name = text(page, {
        Text = data.name,
        FontFace = F.Head,
        TextSize = compact and 20 or 23,
        TextColor3 = T.PageText,
        ZIndex = 3,
        Position = UDim2.fromOffset(10, top + 17),
        Size = UDim2.new(1, -20, 0, compact and 22 or 26),
    })
    local well = Style.Inset(page, {
        Position = UDim2.fromOffset(6, top + (compact and 42 or 48)),
        Size = UDim2.new(1, -12, 0, compact and 52 or 58),
        ZIndex = 3,
        BackgroundColor3 = T.Card,
    }, 7)
    text(well, {
        Text = "POWER",
        FontFace = F.Bold,
        TextSize = 10,
        TextColor3 = T.Muted,
        Position = UDim2.fromOffset(12, 5),
        Size = UDim2.fromOffset(80, 12),
        ZIndex = 4,
    })
    local power = text(well, {
        Text = "0",
        FontFace = F.Heavy,
        TextSize = compact and 28 or 32,
        ZIndex = 5,
        TextTruncate = Enum.TextTruncate.None,
        Position = UDim2.fromOffset(12, compact and 16 or 17),
        Size = UDim2.new(0.6, 0, 0, compact and 30 or 36),
    })
    local powerScale = make("UIScale", { Scale = 1 }, power)
    local exact = text(well, {
        Text = "",
        FontFace = F.Body,
        TextSize = 11,
        TextColor3 = T.Muted,
        ZIndex = 4,
        TextTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 6),
        Size = UDim2.new(0.6, 0, 0, 12),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local income = text(well, {
        Text = Format.Rate(data.income),
        FontFace = F.Bold,
        TextSize = compact and 13 or 15,
        TextColor3 = T.Income,
        ZIndex = 4,
        TextTransparency = 1,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -12, 1, -8),
        Size = UDim2.new(0.45, 0, 0, 18),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local quality = chip(page, string.upper(data.quality) .. " ROLL", T.Ink, {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, top),
        ZIndex = 3,
        TextColor3 = data.qualityColor,
        TextTransparency = 1,
        BackgroundTransparency = 1,
    })
    local hint = text(page, {
        Text = "Collect it from the chamber",
        FontFace = F.Body,
        TextSize = 11,
        TextColor3 = T.PageMuted,
        ZIndex = 3,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 10, 1, -5),
        Size = UDim2.new(1, -20, 0, 14),
        TextTransparency = 1,
        Visible = not compact,
    })
    -- one diagonal sweep, used only for notable rolls
    local sweep = make("Frame", {
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
        Size = UDim2.fromScale(1, 1),
        ZIndex = 8,
        BackgroundTransparency = 0,
        Visible = false,
    }, card)
    Style.Corner(sweep, 12)
    local sweepGradient = make("UIGradient", {
        Rotation = 20,
        Offset = Vector2.new(-1, 0),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.44, 1),
            NumberSequenceKeypoint.new(0.5, 0.78),
            NumberSequenceKeypoint.new(0.56, 1),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, sweep)
    local dismiss = make(
        "TextButton",
        { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 10, Selectable = false },
        holder
    )
    return {
        holder = holder,
        group = group,
        card = card,
        edge = edge,
        rarity = rarity,
        name = name,
        power = power,
        powerScale = powerScale,
        exact = exact,
        income = income,
        quality = quality,
        hint = hint,
        sweep = sweep,
        sweepGradient = sweepGradient,
        dismiss = dismiss,
        well = well,
    }
end

local function burst(parent, origin, color, count)
    for i = 1, count do
        local size = math.random(4, 7)
        local p = make("Frame", {
            BorderSizePixel = 0,
            BackgroundColor3 = i % 3 == 0 and T.Accent or color,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(size, size),
            Position = UDim2.fromOffset(origin.X, origin.Y),
            ZIndex = 9,
            Rotation = math.random(0, 45),
        }, parent)
        local angle = (i / count) * math.pi * 2 + math.random() * 0.5
        local dist = math.random(36, 70)
        local target = origin + Vector2.new(math.cos(angle) * dist * 1.6, math.sin(angle) * dist * 0.8)
        local tw = TweenService:Create(
            p,
            TweenInfo.new(0.65 + math.random() * 0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {
                Position = UDim2.fromOffset(target.X, target.Y),
                BackgroundTransparency = 1,
                Rotation = p.Rotation + math.random(60, 140),
            }
        )
        tw.Completed:Connect(function()
            p:Destroy()
        end)
        tw:Play()
    end
end

function Reveal:_play(data)
    task.wait(R.Delay)
    local ui = self:_build(data)
    local calm = reduced()
    local rank = tonumber(data.qualityRank) or 1
    local notable = rank >= Config.NotableRank
    local top = rank >= Config.TopRank
    local final = data.power
    local done = false
    ui.dismiss.Activated:Connect(function()
        done = true
    end)

    -- 1. card in: character first
    ui.holder.Position += UDim2.fromOffset(0, 18)
    UISound.Play("Open")
    TweenService:Create(ui.group, TweenInfo.new(0.22, Enum.EasingStyle.Quad), { GroupTransparency = 0 }):Play()
    TweenService:Create(ui.holder, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = ui.holder.Position - UDim2.fromOffset(0, 18),
    }):Play()
    task.wait(0.4)

    -- 2. Power rolls up to the exact server value
    local duration = top and R.CountTop or (notable and R.CountNotable or R.CountOrdinary)
    if not calm and final > 1 then
        local logFinal = math.log10(final)
        local start = os.clock()
        while not done do
            local u = math.clamp((os.clock() - start) / duration, 0, 1)
            local e = 1 - (1 - u) ^ 4
            local shown
            if final > 10000 then
                shown = 10 ^ (logFinal * e)
            else
                shown = final * e
            end
            ui.power.Text = Format.Short(math.min(final, math.floor(shown)))
            if u >= 1 then
                break
            end
            RunService.RenderStepped:Wait()
        end
    end
    ui.power.Text = Format.Short(final)
    ui.exact.Text = Format.Exact(final)
    if notable then
        ui.power.TextColor3 = Style.Deep(data.qualityColor)
        UISound.Play("Claim")
        UISound.Play("Shine")
    else
        UISound.Play("Success")
    end

    -- 3. land: stillness, quality, income
    local fade = TweenInfo.new(0.25, Enum.EasingStyle.Quad)
    TweenService:Create(ui.exact, fade, { TextTransparency = 0 }):Play()
    TweenService:Create(ui.income, fade, { TextTransparency = 0 }):Play()
    TweenService:Create(ui.hint, fade, { TextTransparency = 0 }):Play()
    TweenService:Create(ui.quality, fade, { TextTransparency = 0, BackgroundTransparency = 0 }):Play()
    if not calm then
        ui.powerScale.Scale = notable and 1.12 or 1.05
        TweenService:Create(
            ui.powerScale,
            TweenInfo.new(notable and 0.35 or 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Scale = 1 }
        ):Play()
    end
    if notable then
        ui.edge.Color = data.qualityColor
        ui.edge.Transparency = 0
        ui.edge.Thickness = 2
        if not calm then
            ui.sweep.Visible = true
            local sweeps = top and 2 or 1
            task.spawn(function()
                for _ = 1, sweeps do
                    ui.sweepGradient.Offset = Vector2.new(-1, 0)
                    local tw = TweenService:Create(
                        ui.sweepGradient,
                        TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                        { Offset = Vector2.new(1, 0) }
                    )
                    tw:Play()
                    tw.Completed:Wait()
                end
                if ui.sweep.Parent then
                    ui.sweep.Visible = false
                end
            end)
            -- particles live outside the CanvasGroup so they can leave the card
            local abs = ui.power.AbsolutePosition - ui.holder.AbsolutePosition
            local origin = Vector2.new(abs.X + ui.power.TextBounds.X * 0.5, abs.Y + ui.power.AbsoluteSize.Y * 0.5)
            burst(ui.holder, origin, data.qualityColor, top and R.ParticlesTop or R.ParticlesNotable)
        end
    end

    -- 4. hold still, then out
    local held = os.clock()
    while not done and os.clock() - held < R.Hold + (notable and 0.8 or 0) do
        task.wait(0.05)
    end
    local out = TweenService:Create(ui.group, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { GroupTransparency = 1 })
    TweenService:Create(
        ui.holder,
        TweenInfo.new(0.25, Enum.EasingStyle.Quad),
        { Position = ui.holder.Position + UDim2.fromOffset(0, 12) }
    ):Play()
    out:Play()
    out.Completed:Wait()
    ui.holder:Destroy()
end

return Reveal
