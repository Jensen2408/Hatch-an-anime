local Assets = game:GetService("AssetService")
local Encoding = game:GetService("EncodingService")
local data = require(script.MoltenMapData)
local size = data.Size
local dimensions = Vector2.new(size, size)
local rowBytes = size * 4
local maps = {}

local function mapContent(name)
    local source = Encoding:DecompressBuffer(
        Encoding:Base64Decode(buffer.fromstring(data[name])),
        Enum.CompressionAlgorithm.Zstd
    )
    assert(buffer.len(source) == rowBytes * size, "Unexpected Molten map dimensions")
    local image = assert(Assets:CreateEditableImage({ Size = dimensions }), "Molten image budget unavailable")
    image:WritePixelsBuffer(Vector2.zero, dimensions, source)
    table.insert(maps, { source = source, frame = buffer.create(buffer.len(source)), image = image })
    return Content.fromObject(image)
end

local function uniformMap(value)
    local image = assert(Assets:CreateEditableImage({ Size = Vector2.one }), "Molten image budget unavailable")
    image:DrawRectangle(Vector2.zero, Vector2.one, Color3.new(value, value, value), 0, Enum.ImageCombineType.Overwrite)
    return Content.fromObject(image)
end

local surface = Assets:CreateSurfaceAppearanceAsync({
    ColorMap = mapContent("Color"),
    NormalMap = mapContent("Normal"),
    EmissiveMask = mapContent("Emissive"),
    RoughnessMap = uniformMap(.81),
    MetalnessMap = uniformMap(0),
})
surface.Name = "Molten"
surface.EmissiveStrength = 1.15

local nextFrame = 0
local function update(now)
    if now < nextFrame then
        return
    end
    nextFrame = now + 1 / 16
    local xOffset = math.floor(now * 5) % size * 4
    local yOffset = math.floor(now * 17) % size
    local firstBytes = rowBytes - xOffset
    for _, map in maps do
        for y = 0, size - 1 do
            local sourceRow = (y + yOffset) % size * rowBytes
            local destination = y * rowBytes
            buffer.copy(map.frame, destination, map.source, sourceRow + xOffset, firstBytes)
            if xOffset > 0 then
                buffer.copy(map.frame, destination + firstBytes, map.source, sourceRow, xOffset)
            end
        end
        map.image:WritePixelsBuffer(Vector2.zero, dimensions, map.frame)
    end
end

return { Surface = surface, Update = update }
