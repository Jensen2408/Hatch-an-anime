
local Economy={}
Economy.BaseIncome={Pirate=5,Shinobi=12,Power=25,Hero=60,Slayer=125,Curse=250,Soul=600,Titan=1200,Magic=2500,Academy=8000,Devil=20000,Guild=50000,Sports=150000,Mecha=400000,God=1000000,Unknown=10000000}
Economy.Version=3
-- Power ceiling is separate from cash. Existing valid Power values are retained.
Economy.MaxPower=1e18
Economy.RarityLuck={Pirate=1,Shinobi=1,Power=1,Hero=.85,Slayer=.85,Curse=.85,Soul=.65,Titan=.65,Magic=.65,Academy=.45,Devil=.45,Guild=.45,Sports=.25,Mecha=.25,God=.25,Unknown=.25}
Economy.Bands={
 {Name="Ordinary",Weight=95,Min=1,Max=1.2,Color=Color3.fromRGB(218,225,239)},
 {Name="Strong",Weight=4.5,Min=1.2,Max=3,Color=Color3.fromRGB(125,238,183)},
 {Name="Exceptional",Weight=.45,Min=3,Max=10,Color=Color3.fromRGB(112,188,255)},
 {Name="Jackpot",Weight=.045,Min=10,Max=100,Color=Color3.fromRGB(206,143,255)},
 {Name="Ultra",Weight=.0045,Min=100,Max=1000,Color=Color3.fromRGB(255,213,101)},
 {Name="Cosmic",Weight=.0005,Min=1000,Max=1e12,Color=Color3.fromRGB(255,153,217)}
}
function Economy.RollWeights(id)
 assert(Economy.BaseIncome[id],"Unknown character type")
 local factor=Economy.RarityLuck[id] or 1
 local weights={} local bonus=0
 for i=2,#Economy.Bands do weights[i]=Economy.Bands[i].Weight*factor;bonus+=weights[i] end
 weights[1]=100-bonus
 return weights
end
local random=Random.new()
function Economy.BasePower(id) local base=Economy.BaseIncome[id] assert(base,"Unknown character type") return base*100 end
function Economy.Income(id,power)
 assert(Economy.BaseIncome[id],"Unknown character type")
 assert(type(power)=="number" and power==power and power>=1 and power<=Economy.MaxPower,"Invalid power")
 -- Universal power-to-income curve; higher Power always earns at least as much.
 -- Growth softens above 100M Power; giant rolls stay valuable without runaway income.
 local rate=(id=="Unknown" or power<=100000000) and power/100 or 1000000*(power/100000000)^.4 -- Limited Unknown skips the soft cap
 return math.max(1,math.floor(rate+.5))
end
function Economy.Quality(id,power)
 local ratio=power/Economy.BasePower(id)
 for i=#Economy.Bands,1,-1 do if ratio>=Economy.Bands[i].Min then return Economy.Bands[i] end end
 return Economy.Bands[1]
end
function Economy.Roll(id,rng)
 local base=Economy.BasePower(id) rng=rng or random
 local weights=Economy.RollWeights(id)
 local roll=rng:NextNumber(0,100) local sum=0 local chosen=Economy.Bands[1]
 for i,band in ipairs(Economy.Bands) do sum+=weights[i] if roll<sum then chosen=band break end end
 local u=rng:NextNumber()^2
 local multiplier=chosen.Min*(chosen.Max/chosen.Min)^u
 local power=math.clamp(math.floor(base*multiplier+.5),1,Economy.MaxPower)
 return {Power=power,IncomePerSecond=Economy.Income(id,power),RollQuality=chosen.Name}
end
Economy.MutationMult={Silver=1.5,Gold=2,Diamond=3,Rainbow=5}
local function mutMult(object) local t=object and object:GetAttribute("Mutation") return (t and Economy.MutationMult[t]) or 1 end
function Economy.Read(object,id)
 local p=object and object:GetAttribute("Power")
 if type(p)=="number" and p==p and p>=1 and p<=Economy.MaxPower and p%1==0 then
  if (object:GetAttribute("PowerVersion")==nil or object:GetAttribute("PowerVersion")==1) and p<=100 then
   p=math.floor(Economy.BasePower(id)*(.5+p*.05)+.5)
  end
  return {Power=p,IncomePerSecond=math.floor(Economy.Income(id,p)*mutMult(object)+.5),RollQuality=Economy.Quality(id,p).Name}
 end
 return nil
end
function Economy.Apply(object,id,stats)
 assert(type(stats)=="table" and type(stats.Power)=="number" and stats.Power%1==0 and stats.Power>=1 and stats.Power<=Economy.MaxPower,"Invalid character power")
 object:SetAttribute("Power",stats.Power)
 object:SetAttribute("PowerVersion",Economy.Version)
 object:SetAttribute("BasePower",Economy.BasePower(id))
 object:SetAttribute("RollQuality",Economy.Quality(id,stats.Power).Name)
 object:SetAttribute("BaseIncomePerSecond",Economy.BaseIncome[id])
 object:SetAttribute("IncomePerSecond",math.floor(Economy.Income(id,stats.Power)*mutMult(object)+.5))
 object:SetAttribute("PowerRolled",true)
end
function Economy.Format(n)
 local units={{1000000000000000,"Qa"},{1000000000000,"T"},{1000000000,"B"},{1000000,"M"},{1000,"K"}}
 for i,u in ipairs(units) do
  if n>=u[1] then
   local value=math.floor(n/u[1]*100+.5)/100
   if value>=1000 and i>1 then return Economy.Format(math.floor(n/units[i-1][1]*100+.5)/100*units[i-1][1]) end
   local s=string.format("%.2f",value):gsub("0+$",""):gsub("%.$","")
   return s..u[2]
  end
 end
 return tostring(math.floor(n+.5))
end
function Economy.Color(power,id)
 if id then return Economy.Quality(id,power).Color end
 return Color3.fromRGB(218,225,239)
end
function Economy.Label(model,id,stats,preview)
 local old=model:FindFirstChild("PowerInfo") if old then old:Destroy() end
 local p=model:FindFirstChildWhichIsA("BasePart",true) if not p then return end
 local box,size=model:GetBoundingBox()
 local attachment=p:FindFirstChild("CharacterPowerAnchor") or Instance.new("Attachment")
 attachment.Name="CharacterPowerAnchor"
 attachment.Position=p.CFrame:PointToObjectSpace(box.Position-Vector3.new(0,size.Y*.5-.25,0))
 attachment.Parent=p
 local gui=Instance.new("BillboardGui") gui.Name="PowerInfo" gui.Adornee=attachment gui.Size=UDim2.fromOffset(210,48)
 gui.MaxDistance=65 gui.AlwaysOnTop=true gui.LightInfluence=0 gui.Parent=model
 local function line(name,text,y,color)
  local l=Instance.new("TextLabel") l.Name=name l.BackgroundTransparency=1 l.Size=UDim2.new(1,0,0,23) l.Position=UDim2.fromOffset(0,y)
  l.Font=Enum.Font.GothamBold l.TextSize=15 l.TextColor3=color l.TextStrokeTransparency=.1 l.TextStrokeColor3=Color3.fromRGB(13,16,22) l.Text=text l.Parent=gui return l
 end
 line("Power",preview and "POWER • RANDOM ON HATCH" or ("POWER "..Economy.Format(stats.Power).." • "..Economy.Quality(id,stats.Power).Name),0,preview and Color3.fromRGB(219,226,239) or Economy.Color(stats.Power,id))
 line("Income",(preview and "BASE $"..Economy.Format(Economy.BaseIncome[id]) or "$"..Economy.Format(stats.IncomePerSecond)).."/sec",23,Color3.fromRGB(132,241,166))
end
return Economy
