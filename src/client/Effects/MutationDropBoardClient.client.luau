-- MutationDropBoardClient (LocalScript, StarterPlayerScripts)
-- Drives the river board (workspace.MutationDropBoard.Board.Screen): countdown to the next guaranteed mutation drop,
-- then "<TIER> DROPPED!" for 20 s after one. Reads the workspace attributes written by MutationDropService
-- (NextMutationDropAt, LastMutationDrop, LastMutationDropAt) against server time, so every client agrees.
local screen = workspace:WaitForChild("MutationDropBoard"):WaitForChild("Board"):WaitForChild("Screen")
local timerLabel = screen:FindFirstChild("Timer", true)
local tiersLabel = screen:FindFirstChild("Tiers", true)

-- The sign's art (ReplicatedStorage.MenuArt.BoardArt: GPT Image, Halloween Shop style, title baked in) replaces the
-- place's flat frame / studs / header; the subtitle, timer and tiers labels stay and are drawn on top of it.
do
    local MenuArt = require(game:GetService("ReplicatedStorage"):WaitForChild("MenuArt"):WaitForChild("MenuArt"))
    local face = timerLabel.Parent
    face.BackgroundTransparency = 1
    for _, child in face:GetChildren() do
        if child:IsA("ImageLabel") or (child:IsA("Frame") and child.Name == "Header") then
            child.Visible = false
        elseif child:IsA("TextLabel") then
            child.ZIndex = 3
        end
    end
    local art = Instance.new("ImageLabel")
    art.Name = "BoardArt"
    art.BackgroundTransparency = 1
    art.Image = MenuArt.BoardArt
    art.Size = UDim2.fromScale(1, 1)
    art.ZIndex = 1
    art.Parent = face
    local subtitle = face:FindFirstChild("T")
    if subtitle and subtitle:IsA("TextLabel") then
        subtitle.Position = UDim2.fromScale(0.06, 0.25) -- right under the drawn header
    end
end

local TIER_COLORS = {
    Silver = Color3.fromRGB(220, 225, 235),
    Gold = Color3.fromRGB(255, 200, 60),
    Diamond = Color3.fromRGB(90, 220, 255),
    Rainbow = Color3.fromRGB(255, 90, 200),
}

while true do
    local now = workspace:GetServerTimeNow()
    local lastTier, lastDropAt =
        workspace:GetAttribute("LastMutationDrop"), workspace:GetAttribute("LastMutationDropAt")
    if lastTier and lastDropAt and now - lastDropAt < 20 then
        timerLabel.Text = string.upper(lastTier) .. " DROPPED!"
        timerLabel.TextColor3 = TIER_COLORS[lastTier] or Color3.new(1, 1, 1)
        tiersLabel.Text = "GO GRAB IT IN THE RIVER!"
    else
        local secondsLeft = math.max(0, math.ceil((workspace:GetAttribute("NextMutationDropAt") or now) - now))
        timerLabel.Text = string.format("%d:%02d", secondsLeft // 60, secondsLeft % 60)
        timerLabel.TextColor3 = secondsLeft <= 10 and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(255, 220, 80)
        tiersLabel.Text = "SILVER · GOLD · DIAMOND · RAINBOW"
    end
    task.wait(0.25)
end
