local Economy=require(script.Parent.CharacterEconomy)
local M={}
M.Base={Pirate=30,Shinobi=60,Power=90,Hero=180,Slayer=300,Curse=480,Soul=720,Titan=900,Magic=1200,Academy=1800,Devil=2700,Guild=3600,Sports=5400,Mecha=7200,God=10800,Unknown=1800}
-- Every egg of a given type has the same base incubation time.
-- Power rolls do not change the timer; Nighttime speeds up the countdown.
function M.Seconds(id,stats)
 return M.Base[id] or 120
end
function M.Format(seconds)
 seconds=math.max(0,math.ceil(seconds))
 local h=math.floor(seconds/3600);local m=math.floor(seconds/60)%60;local s=seconds%60
 if h>0 then return string.format("%d:%02d:%02d",h,m,s)end
 return string.format("%02d:%02d",m,s)
end
return M