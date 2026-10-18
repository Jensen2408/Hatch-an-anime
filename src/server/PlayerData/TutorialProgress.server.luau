-- TutorialProgress: advances the post-hatch UI tour (TutorialTourStage 9..12) when the client reports each step.
-- Only acknowledges the UI tour after server-validated first income collection.
-- These acknowledgements cannot buy upgrades, grant cash, or award items.
-- Runtime: Script in ServerScriptService. Remote: ReplicatedStorage.FirstHatchTutorialAction (RemoteEvent, action string).
-- Attributes TutorialDataReady / TutorialCompleted / TutorialIncomeCollected / TutorialTourStage are loaded and saved by
-- PlayerDataService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage:FindFirstChild("FirstHatchTutorialAction") or Instance.new("RemoteEvent")
remote.Name = "FirstHatchTutorialAction"
remote.Parent = ReplicatedStorage
-- stage -> the action the client must send to leave that stage; stage 12 completes the tutorial
local EXPECTED_ACTION = { [9] = "PlotOpened", [10] = "UpgradesOpened", [11] = "TempleSeen", [12] = "IncubatorsSeen" }
remote.OnServerEvent:Connect(function(player, action)
    if
        type(action) ~= "string"
        or not player:GetAttribute("TutorialDataReady")
        or player:GetAttribute("TutorialCompleted")
        or not player:GetAttribute("TutorialIncomeCollected")
    then
        return
    end
    local stage = player:GetAttribute("TutorialTourStage") or 9
    if EXPECTED_ACTION[stage] ~= action then
        return
    end
    if stage == 12 then
        player:SetAttribute("TutorialCompleted", true)
    else
        player:SetAttribute("TutorialTourStage", stage + 1)
    end
end)
