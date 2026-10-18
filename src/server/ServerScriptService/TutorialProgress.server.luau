-- Only acknowledges the UI tour after server-validated first income collection.
-- These acknowledgements cannot buy upgrades, grant cash, or award items.
local RS=game:GetService("ReplicatedStorage")
local remote=RS:FindFirstChild("FirstHatchTutorialAction") or Instance.new("RemoteEvent")
remote.Name="FirstHatchTutorialAction";remote.Parent=RS
local expected={[9]="PlotOpened",[10]="UpgradesOpened",[11]="TempleSeen",[12]="IncubatorsSeen"}
remote.OnServerEvent:Connect(function(player,action)
 if type(action)~="string" or not player:GetAttribute("TutorialDataReady") or player:GetAttribute("TutorialCompleted") or not player:GetAttribute("TutorialIncomeCollected") then return end
 local stage=player:GetAttribute("TutorialTourStage") or 9
 if expected[stage]~=action then return end
 if stage==12 then player:SetAttribute("TutorialCompleted",true)
 else player:SetAttribute("TutorialTourStage",stage+1) end
end)
