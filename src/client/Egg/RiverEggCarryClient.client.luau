local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local Banner=require(RS:WaitForChild("StolenEggBanner"))
Banner.Start()
local current
local function recover()
 local id=player:GetAttribute("RiverEggCarryId")
 local base=player:GetAttribute("RiverEggCarryBase")
 if id and typeof(base)=="Vector3" then
  current=id;Banner.Show(base,{eggType=player:GetAttribute("RiverEggCarryType")})
 end
end
RS:WaitForChild("RiverEggCarryState").OnClientEvent:Connect(function(state,data)
 if state=="Stolen" then current=data.id;Banner.Show(data.basePosition,data)
 elseif current and (not data or data.id==current) then
  current=nil;Banner.Resolve(state)
 end
end)
player:GetAttributeChangedSignal("RiverEggCarryId"):Connect(recover)
player:GetAttributeChangedSignal("RiverEggCarryBase"):Connect(recover)
recover()