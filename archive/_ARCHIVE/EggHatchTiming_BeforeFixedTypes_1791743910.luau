local Economy=require(script.Parent.CharacterEconomy)
local M={}
M.Base={Pirate=120,Shinobi=180,Power=300,Hero=600,Slayer=900,Curse=1200,Soul=1800,Titan=2700,Magic=3600,Academy=5400,Devil=7200,Guild=10800,Sports=21600,Mecha=28800,God=43200}
function M.Seconds(id,stats)
 local base=M.Base[id] or 30
 local ratio=math.max(1,(stats and stats.IncomePerSecond or Economy.BaseIncome[id])/Economy.BaseIncome[id])
 local factor=1+math.log(ratio)/math.log(2)*.25
 return math.clamp(math.ceil(base*factor/5)*5,120,86400)
end
function M.Format(seconds)
 seconds=math.max(0,math.ceil(seconds))
 local h=math.floor(seconds/3600);local m=math.floor(seconds/60)%60;local s=seconds%60
 if h>0 then return string.format("%d:%02d:%02d",h,m,s)end
 return string.format("%02d:%02d",m,s)
end
return M