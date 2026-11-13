-- Molten v3 "LavaFlow" style: ambientCG Lava003 (CC0, photo-based) cooled basalt crust with glowing flow seams,
-- 384px seamless maps (MutationFinish/Molten/build-maps-lava003.js), drifting slowly along the flow, gentle breathing glow.
-- Normal map is rebuilt from Color + Emissive.
local Assets = game:GetService("AssetService")
local Encoding = game:GetService("EncodingService")
local data = require(script.MoltenMapData)
local size = data.Size
local dimensions = Vector2.new(size, size)
local rowBytes = size * 4
local totalBytes = rowBytes * size
local maps = {}

local function decode(text)
    return Encoding:DecompressBuffer(Encoding:Base64Decode(buffer.fromstring(text)), Enum.CompressionAlgorithm.Zstd)
end

local function addMap(source)
    assert(buffer.len(source) == totalBytes, "Unexpected Ash map dimensions")
    local image = assert(Assets:CreateEditableImage({ Size = dimensions }), "Ash image budget unavailable")
    image:WritePixelsBuffer(Vector2.zero, dimensions, source)
    table.insert(maps, { source = source, frame = buffer.create(totalBytes), image = image })
    return Content.fromObject(image)
end

local function uniformMap(value)
    local image = assert(Assets:CreateEditableImage({ Size = Vector2.one }), "Ash image budget unavailable")
    image:DrawRectangle(Vector2.zero, Vector2.one, Color3.new(value, value, value), 0, Enum.ImageCombineType.Overwrite)
    return Content.fromObject(image)
end

local color = buffer.create(totalBytes)
local offset = 0
for _, part in data.Color do
    local bytes = decode(part)
    buffer.copy(color, offset, bytes)
    offset += buffer.len(bytes)
end
local emissive = decode(data.Emissive)
if data.EmissiveGrey then
    -- stored as one grey byte per pixel to keep the module small; expand to RGBA
    local grey = emissive
    emissive = buffer.create(totalBytes)
    for i = 0, size * size - 1 do
        local v = buffer.readu8(grey, i)
        buffer.writeu32(emissive, i * 4, 0xFF000000 + v * 0x010101)
    end
end

-- Height from brightness minus the glowing cracks, then slope -> tangent-space normal.
local height = table.create(size * size)
for i = 0, size * size - 1 do
    local p = i * 4
    height[i + 1] = (buffer.readu8(color, p) + buffer.readu8(color, p + 1) + buffer.readu8(color, p + 2)) / 765 * .24
        - buffer.readu8(emissive, p) / 255 * .42
end
local normal = buffer.create(totalBytes)
for y = 0, size - 1 do
    local up, down = (y - 1) % size * size, (y + 1) % size * size
    local row = y * size
    for x = 0, size - 1 do
        local left, right = (x - 1) % size, (x + 1) % size
        local nx = (height[row + left + 1] - height[row + right + 1]) * 1.5
        local ny = (height[down + x + 1] - height[up + x + 1]) * 1.5
        local inv = 1 / math.sqrt(nx * nx + ny * ny + 1)
        local p = (row + x) * 4
        buffer.writeu8(normal, p, math.floor((nx * inv * .5 + .5) * 255))
        buffer.writeu8(normal, p + 1, math.floor((ny * inv * .5 + .5) * 255))
        buffer.writeu8(normal, p + 2, math.floor((inv * .5 + .5) * 255))
        buffer.writeu8(normal, p + 3, 255)
    end
end

local surface = Assets:CreateSurfaceAppearanceAsync({
    ColorMap = addMap(color),
    NormalMap = addMap(normal),
    EmissiveMask = addMap(emissive),
    RoughnessMap = uniformMap(.81),
    MetalnessMap = uniformMap(0),
})
surface.Name = "LavaFlow"
surface.EmissiveStrength = 1.4

-- pixels per second. Frame row y shows source row y + offset, so a growing Y offset moves the lava UP the model;
-- X adds the sideways component, so it rises at an angle (~50 degrees)
local X_SPEED, Y_SPEED = 6, 7
local lastX, lastY = -1, -1
local nextFrame = 0
local function update(now)
    -- Breathing glow every frame: perfectly smooth, costs nothing.
    local glow = 1.35 + .25 * math.sin(now * .9) + .08 * math.sin(now * 2.3 + 1.7)
    surface.EmissiveStrength = glow
    if now < nextFrame then
        return glow
    end
    nextFrame = now + 1 / 24
    local xPixels = math.floor(now * X_SPEED) % size
    local yPixels = math.floor(now * Y_SPEED) % size
    if xPixels == lastX and yPixels == lastY then
        return glow
    end
    lastX, lastY = xPixels, yPixels
    local xOffset = xPixels * 4
    local firstBytes = rowBytes - xOffset
    for _, map in maps do
        for y = 0, size - 1 do
            local sourceRow = (y + yPixels) % size * rowBytes
            local destination = y * rowBytes
            buffer.copy(map.frame, destination, map.source, sourceRow + xOffset, firstBytes)
            if xOffset > 0 then
                buffer.copy(map.frame, destination + firstBytes, map.source, sourceRow, xOffset)
            end
        end
        map.image:WritePixelsBuffer(Vector2.zero, dimensions, map.frame)
    end
    return glow
end

return { Surface = surface, Update = update }
