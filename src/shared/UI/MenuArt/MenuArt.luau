-- ReplicatedStorage.MenuArt.MenuArt  (ModuleScript, client)
-- Shared art for the Settings, Quests and Inventory windows: GPT Image window art cut by
-- assets/ui/menus2/build_menus2.py into one background per window and a piece atlas (MenuArtAtlas, generated),
-- plus the helpers that draw them. Pieces are stored at the canvas size of their window, so a piece drawn at
-- its own size matches the background pixel for pixel.
--
--   local MenuArt = require(ReplicatedStorage.MenuArt.MenuArt)
--   MenuArt.piece(parent, "Name", "ButtonGreen", { x, y, w?, h? }, zIndex)       -- 9-sliced when w / h differ
--   MenuArt.label(parent, "Name", "Text", { x, y, w, h }, maxSize, color, zIndex, { alignX?, stroke?, wrap? })
--   MenuArt.hitBox(parent, "Name", { x, y, w, h }, onActivate, zIndex)
local Atlas = require(script.Parent:WaitForChild("MenuArtAtlas"))
local Atlas3 = require(script.Parent:WaitForChild("MenuArt3Atlas")) -- Feedback / Offline / egg tags (menus3)

local MenuArt = {}

MenuArt.Backgrounds = {
    Settings = "rbxassetid://129299347669921", -- settings_bg.png (the 1160 x 730 canvas at 0.883)
    Quests = "rbxassetid://134573953578438", -- quests_bg.png (the 1160 x 730 canvas at 0.883)
    Inventory = "rbxassetid://82596812997570", -- inventory_bg.png (660 x 402, full size)
    Feedback = "rbxassetid://116803729205505", -- assets/ui/menus3/feedback_bg.png (the 1160 x 730 canvas at 0.883)
    Offline = "rbxassetid://131694446837788", -- assets/ui/menus3/offline_bg.png (the 560 x 540 canvas at 1.8)
}
MenuArt.BoardArt = "rbxassetid://129151409851662" -- assets/ui/menus3/board_art.png (Mutation Drop sign, 2:1)
MenuArt.Pieces3 = "rbxassetid://103352692976504" -- assets/ui/menus3/menu3_pieces.png
MenuArt.Pieces = "rbxassetid://135496945753219" -- menu_pieces.png
MenuArt.BackpackButton = "rbxassetid://116322244078947" -- backpack_button.png

MenuArt.Font = Font.new("rbxasset://fonts/families/FredokaOne.json")
MenuArt.Stroke = Color3.fromRGB(14, 8, 28)
MenuArt.Colors = {
    White = Color3.fromRGB(255, 255, 255),
    Muted = Color3.fromRGB(196, 190, 226),
    Gold = Color3.fromRGB(255, 214, 48),
    Green = Color3.fromRGB(96, 236, 96),
}
MenuArt.Slice = 12 -- default 9-slice margin (canvas pixels)

function MenuArt.rect(instance, r)
    instance.Position = UDim2.fromOffset(r[1], r[2])
    instance.Size = UDim2.fromOffset(r[3], r[4])
end

function MenuArt.new(className, name, parent, zIndex)
    local instance = Instance.new(className)
    instance.Name = name
    if instance:IsA("GuiObject") then
        instance.BackgroundTransparency = 1
        instance.BorderSizePixel = 0
        instance.ZIndex = zIndex or 1
    end
    instance.Parent = parent
    return instance
end

-- the piece's atlas entry and atlas image (pieces of both atlases share one name space)
local function lookup(pieceName)
    local info = Atlas.Pieces[pieceName]
    if info then
        return info, MenuArt.Pieces
    end
    return Atlas3.Pieces[pieceName], MenuArt.Pieces3
end

function MenuArt.size(pieceName)
    return (lookup(pieceName)).Size
end

-- a piece at r = { x, y, w?, h? }; drawn 9-sliced (margin `slice`) when its size differs from the piece's
function MenuArt.piece(parent, name, pieceName, r, zIndex, slice)
    local info, atlasImage = lookup(pieceName)
    local source, size = info.Rect, info.Size
    local scale = source[3] / size.X
    local image = MenuArt.new("ImageLabel", name, parent, zIndex)
    image.Image = atlasImage
    image.ImageRectOffset = Vector2.new(source[1], source[2])
    image.ImageRectSize = Vector2.new(source[3], source[4])
    local w, h = r[3] or size.X, r[4] or size.Y
    if w ~= size.X or h ~= size.Y then
        -- margin in canvas pixels -> atlas pixels; borders are drawn at their canvas size (SliceScale)
        local m = math.min((slice or MenuArt.Slice) * scale, source[3] / 2 - 1, source[4] / 2 - 1)
        image.ScaleType = Enum.ScaleType.Slice
        image.SliceCenter = Rect.new(m, m, source[3] - m, source[4] - m)
        image.SliceScale = 1 / scale
    end
    MenuArt.rect(image, { r[1], r[2], w, h })
    return image
end

-- swaps an image made by MenuArt.piece to another piece of the same size (a toggle's on / off, a tab's state)
function MenuArt.setPiece(image, pieceName)
    local source = (lookup(pieceName)).Rect
    image.ImageRectOffset = Vector2.new(source[1], source[2])
    image.ImageRectSize = Vector2.new(source[3], source[4])
end

function MenuArt.background(parent, window, size, zIndex)
    local image = MenuArt.new("ImageLabel", "Background", parent, zIndex)
    image.Image = MenuArt.Backgrounds[window]
    image.Size = size or UDim2.fromScale(1, 1)
    return image
end

-- white FredokaOne text with a dark outline; shrinks to fit, never grows past maxSize
function MenuArt.label(parent, name, text, r, maxSize, color, zIndex, options)
    options = options or {}
    local textLabel = MenuArt.new("TextLabel", name, parent, zIndex)
    textLabel.FontFace = MenuArt.Font
    textLabel.Text = text
    textLabel.TextColor3 = color or MenuArt.Colors.White
    textLabel.TextXAlignment = options.alignX or Enum.TextXAlignment.Left
    textLabel.TextWrapped = options.wrap == true
    textLabel.TextScaled = true
    local limit = Instance.new("UITextSizeConstraint")
    limit.MaxTextSize = maxSize
    limit.Parent = textLabel
    MenuArt.rect(textLabel, r)
    local thickness = options.stroke or 3
    if thickness > 0 then
        local stroke = Instance.new("UIStroke")
        stroke.Color = MenuArt.Stroke
        stroke.Thickness = thickness
        stroke.LineJoinMode = Enum.LineJoinMode.Round
        stroke.Parent = textLabel
    end
    return textLabel
end

function MenuArt.hitBox(parent, name, r, onActivate, zIndex)
    local button = MenuArt.new("TextButton", name, parent, zIndex)
    button.Text = ""
    button.AutoButtonColor = false
    MenuArt.rect(button, r)
    if onActivate then
        button.Activated:Connect(onActivate)
    end
    return button
end

-- Hides the panel's own skin and turns its Close button into an invisible hit-box over the drawn X
-- (closeRect in pixels of a canvas of canvasSize that fills the panel).
function MenuArt.useClose(panel, canvasSize, closeRect)
    for _, name in { "CleanSkin", "CleanBase", "FigmaWindow" } do
        local child = panel:FindFirstChild(name)
        if child and child:IsA("GuiObject") then
            child.Visible = false
        end
    end
    local closeButton = panel:FindFirstChild("Close")
    if not closeButton then
        return
    end
    closeButton.AnchorPoint = Vector2.zero
    closeButton.Position = UDim2.fromScale(closeRect[1] / canvasSize.X, closeRect[2] / canvasSize.Y)
    closeButton.Size = UDim2.fromScale(closeRect[3] / canvasSize.X, closeRect[4] / canvasSize.Y)
    closeButton.BackgroundTransparency = 1
    closeButton.ZIndex = 30
    for _, descendant in closeButton:GetDescendants() do
        if descendant:IsA("GuiObject") then
            descendant.Visible = false
        elseif descendant:IsA("UIStroke") then
            descendant.Enabled = false
        end
    end
    if closeButton:IsA("ImageButton") then
        closeButton.ImageTransparency = 1
    elseif closeButton:IsA("TextButton") then
        closeButton.TextTransparency = 1
    end
end

-- a dark veil over a button that can't be pressed
function MenuArt.veil(parent, r, zIndex, transparency)
    local veil = MenuArt.new("Frame", "Veil", parent, zIndex)
    veil.BackgroundTransparency = transparency or 0.45
    veil.BackgroundColor3 = Color3.new(0, 0, 0)
    MenuArt.rect(veil, r)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = veil
    return veil
end

return MenuArt
