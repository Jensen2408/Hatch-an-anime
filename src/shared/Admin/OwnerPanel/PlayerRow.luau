--[[ ReplicatedStorage.OwnerPanel.PlayerRow  (ModuleScript)
Legacy v2 panel: one roster button (headshot, "Display · @name", UserId + tags). Headshot URLs are cached per UserId
for the session.
]]
local Components = require(script.Parent.Components)
local Theme = require(script.Parent.Theme)
local Players = game:GetService("Players")
local PlayerRow = {}
local thumbnailCache = {}
function PlayerRow.New(parent, rowPlayer, tags, callback)
    local button = Components.Button(parent, "", callback)
    button.Size = UDim2.new(1, 0, 0, 74)
    button.Name = "Player_" .. rowPlayer.UserId
    local headshot = Components.Make(
        "ImageLabel",
        { BackgroundTransparency = 1, Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(12, 16) },
        button
    )
    local nameLabel = Components.Label(button, rowPlayer.DisplayName .. " · @" .. rowPlayer.Name, 14)
    nameLabel.Position = UDim2.fromOffset(64, 7)
    nameLabel.Size = UDim2.new(1, -76, 0, 28)
    local detailLabel = Components.Label(button, tostring(rowPlayer.UserId) .. "   " .. tags, 12, Theme.Muted)
    detailLabel.Position = UDim2.fromOffset(64, 37)
    detailLabel.Size = UDim2.new(1, -76, 0, 28)
    if thumbnailCache[rowPlayer.UserId] then
        headshot.Image = thumbnailCache[rowPlayer.UserId]
    else
        task.spawn(function()
            local ok, url = pcall(
                Players.GetUserThumbnailAsync,
                Players,
                rowPlayer.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size100x100
            )
            if ok then
                thumbnailCache[rowPlayer.UserId] = url
                if headshot.Parent then
                    headshot.Image = url
                end
            end
        end)
    end
    return button
end
return PlayerRow
