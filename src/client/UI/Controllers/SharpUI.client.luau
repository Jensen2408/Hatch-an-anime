--[[ StarterPlayerScripts.SharpUI (LocalScript)
House style = sharp corners + solid black outlines on all game menus.
Strips UICorner, forces UIStroke black/mitred, removes thin white highlight lines. Image art (torii, side buttons)
is left alone.

Part 1 (menus): every descendant of the PlayerGui ScreenGuis named in TARGETS (now and when added later), except
  anything inside GameMenus.Plot / Index / Quests / VipShop (those keep their rounded 3D look) and anything
  carrying the NoSkin attribute itself or on its parent (StudKit pieces, e.g. the Settings panel and toasts).
  A UICorner survives when its parent has the "KeepRound" attribute (set by GameHUD on the PLOT button) or is an
  ImageLabel / ImageButton with an image (corners act as clipping masks there).
Part 2 (world): workspace BillboardGuis named "SlotUnlockLabel" (temple slot signs built by the server's
  TempleSlotUnlocks, child "Card") get the same treatment, plus a distance-based
  grow-in / shrink-out (SHOW_DIST) and outlines that thin out with distance.
  Both are driven from one RenderStepped loop; entries are dropped once their instance loses its Parent.
Instance names looked up: ScreenGuis GameMenus, GameHUD, NightBar, MusicSettingsUI, JoinArrivalUI; frames named
  "Gloss" / "Stripes" are hidden; the slot sign's card gets a UIScale named "Pop".
]]

-- ===== 1. Menus: sharp corners + black outlines =====
local Players = game:GetService("Players")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local TARGETS = { GameMenus = true, GameHUD = true, NightBar = true, MusicSettingsUI = true, JoinArrivalUI = true }
local KEEP_ROUND = { ImageLabel = true, ImageButton = true } -- corners on pictures stay (they're clipping masks)
local BLACK = Color3.new(0, 0, 0)

local function sharpen(inst)
    -- StudKit pieces (Figma UI kit) carry NoSkin on every GuiObject: leave them and their corners / strokes alone
    if inst:GetAttribute("NoSkin") or (inst.Parent and inst.Parent:GetAttribute("NoSkin")) then
        return
    end
    -- the 4 menus (Plot / Index / Quests / Shop) use rounded 3D boxes: leave their corners, shine and highlights alone
    local gameMenus = inst:FindFirstAncestor("GameMenus")
    if gameMenus then
        for _, panelName in { "Plot", "Index", "Quests", "VipShop" } do
            local panel = gameMenus:FindFirstChild(panelName)
            if panel and inst:IsDescendantOf(panel) then
                return
            end
        end
    end
    if inst:IsA("UICorner") then
        local parent = inst.Parent
        if parent and parent:GetAttribute("KeepRound") then
            return
        end
        if parent and KEEP_ROUND[parent.ClassName] and parent.Image ~= "" then
            return
        end
        inst.CornerRadius = UDim.new(0, 0)
    elseif inst:IsA("UIStroke") then
        inst.Color = BLACK
        inst.LineJoinMode = Enum.LineJoinMode.Miter
        if inst.ApplyStrokeMode == Enum.ApplyStrokeMode.Border and inst.Thickness < 2.5 then
            inst.Thickness = 2.5
        end
        inst.Transparency = math.min(inst.Transparency, 0)
    elseif inst:IsA("Frame") then
        local color = inst.BackgroundColor3
        if
            color.R > 0.95
            and color.G > 0.95
            and color.B > 0.95
            and inst.BackgroundTransparency > 0.3
            and inst.BackgroundTransparency < 0.97
        then
            task.defer(function()
                if inst.Parent and inst.AbsoluteSize.Y <= 8 then
                    inst.Visible = false
                end
            end)
        end
        if inst.Name == "Gloss" or inst.Name == "Stripes" then
            inst.Visible = false
        end
    end
end
local function watchGui(gui)
    for _, descendant in gui:GetDescendants() do
        sharpen(descendant)
    end
    gui.DescendantAdded:Connect(sharpen)
end
for _, gui in playerGui:GetChildren() do
    if TARGETS[gui.Name] then
        watchGui(gui)
    end
end
playerGui.ChildAdded:Connect(function(gui)
    if TARGETS[gui.Name] then
        watchGui(gui)
    end
end)

-- ===== 2. Temple slot signs (SlotUnlockLabel billboards) =====
-- slot unlock labels above temple slots
-- outlines scale with the sign (it's sized in studs), so they thin out with distance instead of staying chunky
local slotStrokes = {} -- UIStroke -> { card, base thickness }
local function trackStroke(descendant, billboard)
    if descendant:IsA("UIStroke") and billboard:FindFirstChild("Card") then
        slotStrokes[descendant] = { billboard.Card, descendant.Thickness }
    end
end
-- signs grow in when you come within range and shrink out when you leave (instead of popping)
local SHOW_DIST = 45
local TweenService = game:GetService("TweenService")
local popSigns = {} -- billboard -> { card, scale, shown }
local function addPop(billboard)
    local card = billboard:WaitForChild("Card", 5)
    if not card then
        return
    end
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    local popScale = card:FindFirstChild("Pop") or Instance.new("UIScale")
    popScale.Name = "Pop"
    popScale.Scale = 0.01
    popScale.Parent = card
    card.Visible = false -- hidden while shrunk (outlines would otherwise leave a dot)
    billboard.MaxDistance = 0 -- distance handled below
    popSigns[billboard] = { card = card, scale = popScale, shown = false }
end
local function sharpBillboard(billboard)
    if billboard:IsA("BillboardGui") and billboard.Name == "SlotUnlockLabel" then
        for _, descendant in billboard:GetDescendants() do
            sharpen(descendant)
            trackStroke(descendant, billboard)
        end
        billboard.DescendantAdded:Connect(function(descendant)
            sharpen(descendant)
            trackStroke(descendant, billboard)
        end)
        task.spawn(addPop, billboard)
    end
end
-- per frame: pop signs in/out by camera distance, rescale tracked sign outlines to the card's on-screen height
game:GetService("RunService").RenderStepped:Connect(function()
    local camera = workspace.CurrentCamera
    for billboard, pop in popSigns do
        if not billboard.Parent then
            popSigns[billboard] = nil
        else
            local anchorPart = billboard.Parent
            local shouldShow = billboard.Enabled
                and anchorPart:IsA("BasePart")
                and camera
                and (anchorPart.Position - camera.CFrame.Position).Magnitude < SHOW_DIST
            if shouldShow ~= pop.shown then
                pop.shown = shouldShow
                if pop.tw then
                    pop.tw:Cancel()
                end
                pop.tw = shouldShow
                        and TweenService:Create(pop.scale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 })
                    or TweenService:Create(
                        pop.scale,
                        TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                        { Scale = 0.01 }
                    )
                if shouldShow then
                    pop.card.Visible = true
                else
                    local tween = pop.tw
                    tween.Completed:Once(function(state)
                        if state == Enum.PlaybackState.Completed and not pop.shown then
                            pop.card.Visible = false
                        end
                    end)
                end
                pop.tw:Play()
            end
        end
    end
    for stroke, entry in slotStrokes do
        if not stroke.Parent then
            slotStrokes[stroke] = nil
        else
            -- 74 px = card height at which the stroke keeps its authored thickness; transparent-background
            -- frames lose their Border stroke entirely
            local cardHeight = entry[1].AbsoluteSize.Y
            local hidden = stroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Border
                and stroke.Parent:IsA("GuiObject")
                and stroke.Parent.BackgroundTransparency >= 0.99
            stroke.Thickness = hidden and 0
                or (cardHeight > 0 and math.clamp(entry[2] * cardHeight / 74, 0.5, entry[2]) or entry[2])
        end
    end
end)
for _, descendant in workspace:GetDescendants() do
    sharpBillboard(descendant)
end
workspace.DescendantAdded:Connect(sharpBillboard)
