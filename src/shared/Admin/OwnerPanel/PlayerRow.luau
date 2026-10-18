local C = require(script.Parent.Components)
local T = require(script.Parent.Theme)
local Players = game:GetService("Players")
local M = {}
local cache = {}
function M.New(parent, p, tags, callback)
    local b = C.Button(parent, "", callback)
    b.Size = UDim2.new(1, 0, 0, 74)
    b.Name = "Player_" .. p.UserId
    local image = C.Make(
        "ImageLabel",
        { BackgroundTransparency = 1, Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(12, 16) },
        b
    )
    local name = C.Label(b, p.DisplayName .. " · @" .. p.Name, 14)
    name.Position = UDim2.fromOffset(64, 7)
    name.Size = UDim2.new(1, -76, 0, 28)
    local detail = C.Label(b, tostring(p.UserId) .. "   " .. tags, 12, T.Muted)
    detail.Position = UDim2.fromOffset(64, 37)
    detail.Size = UDim2.new(1, -76, 0, 28)
    if cache[p.UserId] then
        image.Image = cache[p.UserId]
    else
        task.spawn(function()
            local ok, url = pcall(
                Players.GetUserThumbnailAsync,
                Players,
                p.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size100x100
            )
            if ok then
                cache[p.UserId] = url
                if image.Parent then
                    image.Image = url
                end
            end
        end)
    end
    return b
end
return M
