local Service={}
function Service.Update(now)
 local boundary=math.floor(now/300)*300
 local active=now-boundary<20
 workspace:SetAttribute("NighttimeActive",active)
 workspace:SetAttribute("NighttimeEndsAt",boundary+20)
 workspace:SetAttribute("NighttimeNextAt",boundary+300)
 workspace:SetAttribute("NightCashMultiplier",active and 2 or 1)
 workspace:SetAttribute("NightHatchSpeedMultiplier",active and 2 or 1)
 workspace:SetAttribute("NightRiverLuckMultiplier",active and 2 or 1)
 return active
end
return Service