-- ReplicatedStorage.PixelIcon  (ModuleScript, shared)
-- Builds crisp pixel-art icons out of Frames. rows = strings, palette = {char=Color3}; "." = empty
-- Every row of an icon must have the same length (the first row sets the width).
local PixelIcon = {}
PixelIcon.Icons = {
    home = {
        rows = {
            ".....KK.....",
            "....KRRK....",
            "...KRRRRK...",
            "..KRRRRRRK..",
            ".KRRRRRRRRK.",
            "KKKKKKKKKKKK",
            ".KWWWWWWWWK.",
            ".KWWKKKKWWK.",
            ".KWWKDDKWWK.",
            ".KWWKDDKWWK.",
            ".KWWKDDKWWK.",
            ".KKKKKKKKKK.",
        },
        pal = {
            K = Color3.new(0, 0, 0),
            R = Color3.fromRGB(226, 70, 52),
            W = Color3.fromRGB(255, 236, 200),
            D = Color3.fromRGB(120, 70, 40),
        },
    },
    gear = {
        rows = {
            "....KKKK....",
            ".KK.KWWK.KK.",
            ".KWKKLLKKWK.",
            "..KLLLLLLK..",
            "KKKLLKKLLKKK",
            "KWLLK..KLLDK",
            "KWLLK..KLLDK",
            "KKKLLKKLLKKK",
            "..KLLLLLDK..",
            ".KDKKLDKKDK.",
            ".KK.KDDK.KK.",
            "....KKKK....",
        },
        pal = {
            K = Color3.new(0, 0, 0),
            W = Color3.fromRGB(255, 255, 255),
            L = Color3.fromRGB(205, 212, 226),
            D = Color3.fromRGB(120, 128, 150),
        },
    },
    bag = {
        rows = {
            "....KKKK....",
            "...K.KK.K...",
            "..KKKKKKKK..",
            ".KHRRRRRRRK.",
            ".KRRRRRRRDK.",
            ".KRKKKKKKDK.",
            ".KRKYYYYKDK.",
            ".KRKYKKYKDK.",
            ".KRKYYYYKDK.",
            ".KRKKKKKKDK.",
            ".KDDDDDDDDK.",
            "..KKKKKKKK..",
        },
        pal = {
            K = Color3.new(0, 0, 0),
            R = Color3.fromRGB(226, 70, 52),
            H = Color3.fromRGB(255, 140, 110),
            D = Color3.fromRGB(150, 36, 28),
            Y = Color3.fromRGB(255, 206, 60),
        },
    },
}
-- Builds icon `name` into a transparent "PixelIcon" frame (fills its parent, locked to the icon's aspect ratio
-- by a constraint). `props` are extra properties set on that frame before the pixels are added.
function PixelIcon.build(parent, name, props)
    local icon = PixelIcon.Icons[name]
    local height, width = #icon.rows, #icon.rows[1]
    local holder = Instance.new("Frame")
    holder.Name = "PixelIcon"
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.fromScale(1, 1)
    for property, value in props or {} do
        holder[property] = value
    end
    -- (deprecated two-argument Instance.new parents the constraint immediately)
    Instance.new("UIAspectRatioConstraint", holder).AspectRatio = width / height
    for y, row in icon.rows do
        local x = 1
        while x <= width do
            -- Run-length merge: one Frame per horizontal run of the same character.
            local char = row:sub(x, x)
            local run = 1
            while x + run <= width and row:sub(x + run, x + run) == char do
                run += 1
            end
            if char ~= "." and icon.pal[char] then
                local pixel = Instance.new("Frame")
                pixel.BorderSizePixel = 0
                pixel.BackgroundColor3 = icon.pal[char]
                pixel.Position = UDim2.fromScale((x - 1) / width, (y - 1) / height)
                -- +1 px on each axis hides the hairline seams between neighbouring frames
                pixel.Size = UDim2.new(run / width, 1, 1 / height, 1)
                pixel.ZIndex = holder.ZIndex
                pixel.Parent = holder
            end
            x += run
        end
    end
    holder.Parent = parent
    return holder
end
return PixelIcon
