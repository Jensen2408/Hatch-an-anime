-- ReplicatedStorage.StudKit.StudUI  (ModuleScript, client)
-- Builders for the Figma UI kit pieces (tokens in StudTheme), shared by the GameMenus components (Plot, Shop,
-- Index, Quests), FeedbackMenu and SettingsMenu. Every screen is drawn on a StudTheme.CanvasSize canvas in
-- Figma pixels; newCanvas scales it to the panel.
--
--   local canvas, stop = StudUI.newCanvas(panel, layer)   -- stop() disconnects the resize hook
--   local zContent = StudUI.shell(canvas, Colors.Red, "MY PLOT", onClose?)  -- Panel + Header + Close
--   StudUI.button(canvas, "Buy", { x, y, w, h }, Colors.Green, "R$ 45", { onActivate = fn })
--
-- Rect = { x, y, w, h } in pixels of the parent. Each piece takes ZIndex = parent's + 1 (or an explicit
-- zIndex), so children draw above their parent under Global and Sibling ZIndexBehavior alike.
-- Every GuiObject gets the NoSkin attribute: FigmaSkin restyles TextButtons and dark frames in the menu
-- panels unless they (or their parent) carry it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent:WaitForChild("StudTheme"))
local UISound = require(ReplicatedStorage:WaitForChild("UISound"))

local Colors = Theme.Colors

local StudUI = {}

function StudUI.rect(instance, r)
    instance.Position = UDim2.fromOffset(r[1], r[2])
    instance.Size = UDim2.fromOffset(r[3], r[4])
end

local function new(className, name, parent, zIndex)
    local instance = Instance.new(className)
    instance.Name = name
    instance.BorderSizePixel = 0
    instance.ZIndex = zIndex or parent.ZIndex + 1
    instance:SetAttribute("NoSkin", true)
    return instance
end

local function corner(instance, radius)
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, radius)
    uiCorner.Parent = instance
end

local function border(instance, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = thickness or Theme.Border
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = instance
    return stroke
end
StudUI.border = border

-- Hover / click sounds and the action of any pressable piece
local function wire(button, onActivate)
    button.MouseEnter:Connect(function()
        UISound.Play("Hover")
    end)
    button.Activated:Connect(function()
        UISound.Play("Click")
        onActivate()
    end)
end

-- Figma "Stud texture • shared bitmap": the 30 px tile over the whole plate, clipped to its corners
function StudUI.studs(frame, radius)
    local texture = new("ImageLabel", "Studs", frame, frame.ZIndex)
    texture.BackgroundTransparency = 1
    texture.Image = Theme.Assets.StudTexture
    texture.ImageTransparency = Theme.Assets.StudTransparency
    texture.ScaleType = Enum.ScaleType.Tile
    texture.TileSize = UDim2.fromOffset(Theme.Assets.StudTile, Theme.Assets.StudTile)
    texture.Size = UDim2.fromScale(1, 1)
    if radius then
        corner(texture, radius)
    end
    texture.Parent = frame
    return texture
end

-- Solid rounded box (Frame)
function StudUI.plate(parent, name, r, color, radius, borderColor, zIndex)
    local frame = new("Frame", name, parent, zIndex)
    frame.BackgroundColor3 = color
    StudUI.rect(frame, r)
    if radius then
        corner(frame, radius)
    end
    if borderColor then
        border(frame, borderColor)
    end
    frame.Parent = parent
    return frame
end

-- Studded card; a TextButton (with sounds) when onActivate is given
function StudUI.card(parent, name, r, color, radius, borderColor, onActivate, zIndex)
    local card = new(onActivate and "TextButton" or "Frame", name, parent, zIndex)
    card.BackgroundColor3 = color
    if onActivate then
        card.Text = ""
        card.AutoButtonColor = false
        wire(card, onActivate)
    end
    StudUI.rect(card, r)
    corner(card, radius)
    local stroke = borderColor and border(card, borderColor)
    StudUI.studs(card, radius)
    card.Parent = parent
    return card, stroke
end

-- Text that fits its box: TextScaled, capped at the Figma size. opts: display (Lilita / Fredoka + outline),
-- align, alignY, wrap, zIndex, stroke (outline thickness, 0 = none; display text defaults to
-- TextStroke.Display)
function StudUI.label(parent, name, str, r, size, color, opts)
    opts = opts or {}
    local text = new("TextLabel", name, parent, opts.zIndex or parent.ZIndex + 2)
    text.BackgroundTransparency = 1
    text.Text = str
    text.FontFace = opts.display and Theme.Fonts.Display or Theme.Fonts.Body
    text.TextColor3 = color
    -- order matters: setting TextWrapped = false switches TextScaled off again (the label then falls back to
    -- TextSize 8), so TextScaled must be set last
    text.TextWrapped = opts.wrap == true
    text.TextScaled = true
    text.TextXAlignment = opts.align or Enum.TextXAlignment.Left
    text.TextYAlignment = opts.alignY or Enum.TextYAlignment.Center
    StudUI.rect(text, r)
    local limit = Instance.new("UITextSizeConstraint")
    limit.MaxTextSize = size
    limit.Parent = text
    local strokeThickness = opts.stroke or (opts.display and Theme.TextStroke.Display)
    if strokeThickness and strokeThickness > 0 then
        local stroke = Instance.new("UIStroke")
        stroke.Color = Colors.Ink
        stroke.Thickness = strokeThickness
        stroke.Parent = text
    end
    text.Parent = parent
    return text
end

local function centered(opts)
    opts = opts or {}
    opts.align = Enum.TextXAlignment.Center
    return opts
end
StudUI.centered = centered

-- Figma "Progress": ink track, inset fill (default blue). Returns the track and a setter for the ratio.
function StudUI.progress(parent, name, r, ratio, fillColor, zIndex)
    local track = StudUI.plate(parent, name, r, Colors.Ink, r[4] / 2, nil, zIndex)
    local inset = Theme.Progress.Inset
    local innerWidth, innerHeight = r[3] - inset * 2, r[4] - inset * 2
    local fill =
        StudUI.plate(track, "Fill", { inset, inset, 0, innerHeight }, fillColor or Colors.Blue, innerHeight / 2)
    local function set(value)
        local width = innerWidth * math.clamp(value, 0, 1)
        fill.Visible = width > 0
        fill.Size = UDim2.fromOffset(math.max(width, innerHeight), innerHeight)
    end
    set(ratio)
    return track, set
end

-- Figma "Button / <color>": ink base, colored face (Disabled = grey), studs, highlight line, label.
-- Pressed: face drops onto the base. opts: enabled (default true), onActivate, zIndex, labelSize.
-- A disabled button still calls onActivate (menus use it to explain why, e.g. a toast).
function StudUI.button(parent, name, r, color, text, opts)
    opts = opts or {}
    local style = Theme.Button
    local enabled = opts.enabled ~= false
    local w, h = r[3], r[4]
    local root = new("TextButton", name, parent, opts.zIndex)
    root.Text = ""
    root.AutoButtonColor = false
    root.BackgroundTransparency = 1
    StudUI.rect(root, r)
    root.Parent = parent

    StudUI.plate(root, "Base", { 0, style.BaseDrop, w, h - style.BaseDrop }, Colors.Ink, style.Radius)
    local faceRect = { 2, 2, w - 4, h - style.BaseDrop - 4 }
    local face = StudUI.plate(
        root,
        "Face",
        faceRect,
        enabled and color or Colors.Disabled,
        style.FaceRadius,
        Colors.Ink,
        root.ZIndex + 2
    )
    StudUI.studs(face, style.FaceRadius)
    StudUI.plate(
        face,
        "Highlight",
        { style.HighlightInset, 3, faceRect[3] - style.HighlightInset * 2, style.HighlightHeight },
        Colors.White,
        1
    )
    local label = StudUI.label(
        face,
        "Label",
        text,
        { 8, 2, faceRect[3] - 16, faceRect[4] - 4 },
        opts.labelSize or style.LabelSize,
        Colors.White,
        centered({ display = true })
    )

    local function setPressed(pressed)
        face.Position = UDim2.fromOffset(2, pressed and 2 + style.PressDrop or 2)
    end
    root.MouseButton1Down:Connect(function()
        setPressed(true)
    end)
    root.MouseButton1Up:Connect(function()
        setPressed(false)
    end)
    root.MouseLeave:Connect(function()
        setPressed(false)
    end)
    if opts.onActivate then
        wire(root, opts.onActivate)
    end
    return root, label
end

-- Figma "Tab/Selected" (orange) / "Tab/Default" (panel2); selecting the open tab does nothing
function StudUI.tab(parent, name, r, text, selected, onActivate, zIndex)
    local style = Theme.Tab
    local tab = StudUI.card(
        parent,
        name,
        r,
        selected and Colors.Orange or Colors.Panel2,
        style.Radius,
        Colors.Ink,
        function()
            if not selected then
                onActivate()
            end
        end,
        zIndex
    )
    StudUI.label(
        tab,
        "Label",
        text,
        { 8, 8, r[3] - 16, r[4] - 16 },
        style.LabelSize,
        Colors.White,
        centered({
            display = true,
        })
    )
    return tab
end

-- Figma "Badge": small purple tag with a white border
function StudUI.badge(parent, name, r, text, color, zIndex)
    local style = Theme.Badge
    local badge = StudUI.plate(parent, name, r, color or Colors.Purple, style.Radius, Colors.White, zIndex)
    StudUI.label(
        badge,
        "Label",
        text,
        { 4, 3, r[3] - 8, r[4] - 6 },
        style.LabelSize,
        Colors.White,
        centered({
            display = true,
        })
    )
    return badge
end

-- Figma "Panel" + "Header/<color>" (title and Close art). With onClose the Close art is a button; without it
-- the GameMenus panel's own Close button is laid over the art by StudUI.useShell. Returns the ZIndex for the
-- menu's content.
function StudUI.shell(canvas, headerColor, title, onClose)
    local panel, header = Theme.Panel, Theme.Header
    local r = panel.Rect
    StudUI.plate(canvas, "Shadow", { r[1], r[2] + panel.ShadowOffset, r[3], r[4] }, Colors.Ink, panel.Radius)
    local body = StudUI.plate(canvas, "Plate", r, Colors.Panel, panel.PlateRadius, Colors.White, canvas.ZIndex + 2)
    StudUI.studs(body, panel.PlateRadius)
    local zContent = body.ZIndex + 1

    local headerPlate = StudUI.plate(canvas, "Header", header.Rect, headerColor, header.Radius, Colors.White, zContent)
    StudUI.studs(headerPlate, header.Radius)
    StudUI.label(
        headerPlate,
        "Title",
        title,
        header.TitleRect,
        header.TitleSize,
        Colors.White,
        centered({
            display = true,
            stroke = Theme.TextStroke.Title,
        })
    )
    local close = header.Close.Rect
    StudUI.plate(headerPlate, "CloseBase", { close[1], close[2] + 4, close[3], close[4] - 4 }, Colors.Ink, 8)
    local closeFace = StudUI.plate(
        headerPlate,
        "CloseFace",
        { close[1] + 3, close[2], close[3] - 6, close[3] - 6 },
        Colors.Red,
        7,
        Colors.White,
        headerPlate.ZIndex + 2
    )
    StudUI.studs(closeFace, 7)
    StudUI.label(
        closeFace,
        "Glyph",
        "×",
        { 0, -2, close[3] - 6, close[3] - 6 },
        header.Close.GlyphSize,
        Colors.White,
        centered({ display = true })
    )
    if onClose then
        local hitBox = new("TextButton", "Close", headerPlate, closeFace.ZIndex + 3)
        hitBox.Text = ""
        hitBox.BackgroundTransparency = 1
        StudUI.rect(hitBox, close)
        wire(hitBox, onClose)
        hitBox.Parent = headerPlate
    end
    return zContent
end

-- Canvas in Figma pixels, scaled to the panel's pixel width (the panel's own UIScale "Fit" stays on top).
-- Returns the canvas and a function that disconnects the resize hook.
function StudUI.newCanvas(panel, layer)
    local size = Theme.CanvasSize
    local canvas = new("Frame", "StudCanvas", layer, Theme.ZIndex)
    canvas.BackgroundTransparency = 1
    canvas.Size = UDim2.fromOffset(size.X, size.Y)
    local scale = Instance.new("UIScale")
    scale.Parent = canvas
    local function fit()
        scale.Scale = math.max(panel.Size.X.Offset, 1) / size.X
    end
    fit()
    local connection = panel:GetPropertyChangedSignal("Size"):Connect(fit)
    canvas.Parent = layer
    return canvas, function()
        connection:Disconnect()
    end
end

-- Pixel size of a panel on a screen of `viewport` pixels: as wide as fits (max 1000 px, 86 % of the width,
-- 32 px of height to spare) at the canvas' aspect ratio. Same rule as GameMenus' fitPanelToScreen.
function StudUI.fitPanel(panel, viewport)
    local size = Theme.CanvasSize
    local ratio = size.X / size.Y
    local width = math.max(1, math.min(1000, viewport.X * 0.86, (viewport.Y - 32) * ratio))
    panel.Size = UDim2.fromOffset(width, width / ratio)
end

-- Vertical ScrollingFrame for content laid out in `contentRect` (children use content coordinates from 0,0).
-- The frame reaches ScrollPadding past the content on every side, so card borders and pressed / selected
-- outlines are not clipped at the edges, and the thin muted bar sits in the right padding instead of over the
-- cards. Set the content height with StudUI.setScrollHeight.
function StudUI.scroller(parent, name, contentRect, zIndex)
    local pad, bar = Theme.ScrollPadding, Theme.ScrollBar
    local scroller = new("ScrollingFrame", name, parent, zIndex)
    scroller.BackgroundTransparency = 1
    scroller.ScrollingDirection = Enum.ScrollingDirection.Y
    scroller.ScrollBarThickness = bar
    scroller.ScrollBarImageColor3 = Colors.Muted
    scroller.CanvasSize = UDim2.new()
    StudUI.rect(scroller, {
        contentRect[1] - pad,
        contentRect[2] - pad,
        contentRect[3] + pad * 2 + bar,
        contentRect[4] + pad * 2,
    })
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, pad)
    padding.PaddingTop = UDim.new(0, pad)
    padding.PaddingBottom = UDim.new(0, pad)
    padding.PaddingRight = UDim.new(0, pad + bar)
    padding.Parent = scroller
    scroller.Parent = parent
    return scroller
end

-- Canvas height of a StudUI.scroller for `height` px of content (adds the top and bottom padding)
function StudUI.setScrollHeight(scroller, height)
    scroller.CanvasSize = UDim2.fromOffset(0, math.max(height, 0) + Theme.ScrollPadding * 2)
end

-- Figma "Toggle/On" (green) / "Toggle/Off" (grey): pill with a white knob. Returns set(isOn, silent).
function StudUI.toggle(parent, name, r, isOn, onChange, zIndex)
    local style = Theme.Toggle
    local pill = new("TextButton", name, parent, zIndex)
    pill.Text = ""
    pill.AutoButtonColor = false
    StudUI.rect(pill, r)
    corner(pill, r[4] / 2)
    border(pill, Colors.Ink)
    local knobSize = r[4] - style.KnobInset * 2
    local knob =
        StudUI.plate(pill, "Knob", { 0, style.KnobInset, knobSize, knobSize }, Colors.White, knobSize / 2, Colors.Ink)
    pill.Parent = parent
    local state = isOn
    local function set(value, silent)
        state = value
        pill.BackgroundColor3 = state and Colors.Green or Colors.Disabled
        knob.Position =
            UDim2.fromOffset(state and r[3] - style.KnobInset - knobSize or style.KnobInset, style.KnobInset)
        if not silent then
            onChange(state)
        end
    end
    set(isOn, true)
    wire(pill, function()
        set(not state)
    end)
    return set
end

-- Figma "Progress" used as a slider (the UI SCALE row of "06 Settings"): drag or click on the bar.
-- Returns set(value, silent).
function StudUI.slider(parent, name, r, value, onChange, zIndex)
    local style = Theme.Slider
    local track, setFill = StudUI.progress(parent, name, r, value, Colors.Blue, zIndex)
    local knobSize = r[4] + style.KnobGrow
    local knob = StudUI.plate(
        track,
        "Knob",
        { 0, (r[4] - knobSize) / 2, knobSize, knobSize },
        Colors.White,
        knobSize / 2,
        Colors.Ink,
        track.ZIndex + 2
    )
    local hitArea = new("TextButton", "HitArea", track, track.ZIndex + 3)
    hitArea.Text = ""
    hitArea.BackgroundTransparency = 1
    hitArea.Position = UDim2.fromOffset(-knobSize / 2, -style.HitPad)
    hitArea.Size = UDim2.new(1, knobSize, 1, style.HitPad * 2)
    hitArea:SetAttribute("UISoundMuted", true)
    hitArea.Parent = track
    local function set(newValue, silent)
        newValue = math.clamp(newValue, 0, 1)
        setFill(newValue)
        knob.Position = UDim2.fromOffset((r[3] - knobSize) * newValue, (r[4] - knobSize) / 2)
        if not silent then
            onChange(newValue)
        end
    end
    local function setFromScreenX(screenX)
        set((screenX - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1))
    end
    local function isPress(input)
        return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
    end
    local dragging = false
    hitArea.InputBegan:Connect(function(input)
        if isPress(input) then
            dragging = true
            setFromScreenX(input.Position.X)
        end
    end)
    local moved = UserInputService.InputChanged:Connect(function(input)
        local isMove = input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        if dragging and isMove then
            setFromScreenX(input.Position.X)
        end
    end)
    local released = UserInputService.InputEnded:Connect(function(input)
        if isPress(input) then
            dragging = false
        end
    end)
    track.Destroying:Connect(function()
        moved:Disconnect()
        released:Disconnect()
    end)
    set(value, true)
    return set
end

-- Figma "Input": dark field with a muted placeholder. opts: placeholder, textSize, multiLine, maxLength,
-- zIndex. Returns the TextBox.
function StudUI.input(parent, name, r, opts)
    opts = opts or {}
    local style = Theme.Input
    local field = StudUI.card(parent, name, r, Colors.Ink, style.Radius, Colors.Muted, nil, opts.zIndex)
    local box = new("TextBox", "Box", field, field.ZIndex + 2)
    box.BackgroundTransparency = 1
    box.Text = ""
    box.PlaceholderText = opts.placeholder or ""
    box.PlaceholderColor3 = Colors.Muted
    box.TextColor3 = Colors.White
    box.FontFace = Theme.Fonts.Body
    box.TextSize = opts.textSize or style.TextSize
    box.ClearTextOnFocus = false
    box.MultiLine = opts.multiLine == true
    box.TextWrapped = opts.multiLine == true
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.TextYAlignment = opts.multiLine and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
    local pad = style.Padding
    if opts.multiLine then
        StudUI.rect(box, { pad, pad, r[3] - pad * 2, r[4] - pad * 2 })
    else
        StudUI.rect(box, { pad, 0, r[3] - pad * 2, r[4] })
    end
    box.Parent = field
    if opts.maxLength then
        box:GetPropertyChangedSignal("Text"):Connect(function()
            if #box.Text > opts.maxLength then
                box.Text = box.Text:sub(1, opts.maxLength)
            end
        end)
    end
    return box
end

-- Hides the panel's clean skin (the canvas draws its own shell) and turns the panel's Close button into an
-- invisible hit-box over the drawn X.
function StudUI.useShell(panel)
    for _, skinName in { "CleanSkin", "CleanBase", "FigmaWindow" } do
        local oldSkin = panel:FindFirstChild(skinName)
        if oldSkin then
            oldSkin.Visible = false
        end
    end
    local closeButton = panel:FindFirstChild("Close")
    if closeButton then
        local close, canvas = Theme.Header.Close.Rect, Theme.CanvasSize
        closeButton.AnchorPoint = Vector2.zero
        closeButton.Position = UDim2.fromScale(close[1] / canvas.X, close[2] / canvas.Y)
        closeButton.Size = UDim2.fromScale(close[3] / canvas.X, close[4] / canvas.Y)
        closeButton.BackgroundTransparency = 1
        for _, descendant in closeButton:GetDescendants() do
            if descendant:IsA("GuiObject") then
                descendant.Visible = false
            elseif descendant:IsA("UIStroke") then
                descendant.Enabled = false
            end
        end
        closeButton.ZIndex = 30
    end
end

return StudUI
