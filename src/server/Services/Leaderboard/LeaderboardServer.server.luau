-- ServerScriptService.Leaderboard.LeaderboardServer  (Script)
-- Starts LeaderboardService (creates the remote, joins/leaves, refresh and DataStore loops).
require(script.Parent:WaitForChild("LeaderboardService")).Start()
