-- StarterPlayer.StarterPlayerScripts.LeaderboardClientStart  (LocalScript)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(ReplicatedStorage:WaitForChild("Leaderboard"):WaitForChild("LeaderboardClient")).Start()
