-- StarterPlayer.StarterPlayerScripts.LeaderboardClientStart  (LocalScript)
-- Boots the shared leaderboard controller (ReplicatedStorage.Leaderboard.LeaderboardClient).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(ReplicatedStorage:WaitForChild("Leaderboard"):WaitForChild("LeaderboardClient")).Start()
