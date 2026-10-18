-- Temporary filming bypass. Original loading and arrival scripts are archived.
local player=game:GetService("Players").LocalPlayer
game:GetService("ReplicatedFirst"):RemoveDefaultLoadingScreen()
player:SetAttribute("LoadingScreenFinishing",true)
player:SetAttribute("LoadingScreenDone",true)
player:SetAttribute("JoinArrivalCameraSet",true)
player:SetAttribute("JoinArrivalFinished",true)
