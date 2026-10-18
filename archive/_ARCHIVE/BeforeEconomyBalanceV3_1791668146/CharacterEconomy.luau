
local Economy={}
Economy.BaseIncome={Pirate=5,Shinobi=12,Power=25,Hero=60,Slayer=125,Curse=250,Soul=600,Titan=1200,Magic=2500,Academy=15000,Devil=35000,Guild=75000,Sports=250000,Mecha=650000,God=1500000}
Economy.Version=2
Economy.MaxPower=1000000000000000
-- Weighted bonus bands. Within each band, high values are rarer as well.
Economy.Bands={
 {Name="Ordinary",Weight=72,Min=.6,Max=1.3,Color=Color3.fromRGB(218,225,239)},
 {Name="Strong",Weight=22,Min=1.3,Max=3,Color=Color3.fromRGB(125,238,183)},
 {Name="Exceptional",Weight=5,Min=3,Max=10,Color=Color3.fromRGB(112,188,255)},
 {Name="Jackpot",Weight=.9,Min=10,Max=100,Color=Color3.fromRGB(206,143,255)},
 {Name="Ultra",Weight=.09,Min=100,Max=1000,Color=Color3.fromRGB(255,213,101)},
 {Name="Cosmic",Weight=.01,Min=1000,Max=1000000,Color=Color3.fromRGB(255,153,217)}
}
local random=Random.new()
function Economy.BasePower(id) local base=Economy.BaseIncome[id] assert(base,"Unknown character type") return base*100 end
function Economy.Income(id,power)
 assert(Economy.BaseIncome[id],"Unknown character type")
 assert(type(power)=="number" and power==power and power>=1 and power<=Economy.MaxPower,"Invalid power")
 -- Universal power-to-income curve; higher Power always earns at least as much.
 -- Growth softens above 1B Power to keep giant jackpot numbers playable.
 local rate=power<=1000000000 and power/100 or 10000000*math.sqrt(power/1000000000)
 return math.max(1,math.floor(rate+.5))
end
function Economy.Quality(id,power)
 local ratio=power/Economy.BasePower(id)
 for i=#Economy.Bands,1,-1 do if ratio>=Economy.Bands[i].Min then return Economy.Bands[i] end end
 return Economy.Bands[1]
end
function Economy.Roll(id,rng)
 local base=Economy.BasePower(id) rng=rng or random
 local roll=rng:NextNumber(0,100) local sum=0 local chosen=Economy.Bands[1]
 for _,band in ipairs(Economy.Bands) do sum+=band.Weight if roll<sum then chosen=band break end end
 local u=rng:NextNumber()^2
 local multiplier=chosen.Min*(chosen.Max/chosen.Min)^u
 local power=math.clamp(math.floor(base*multiplier+.5),1,Economy.MaxPower)
 return {Power=power,IncomePerSecond=Economy.Income(id,power),RollQuality=chosen.Name}
end
function Economy.Read(object,id)
 local p=object and object:GetAttribute("Power")
 if type(p)=="number" and p==p and p>=1 and p<=Economy.MaxPower and p%1==0 then
  if object:GetAttribute("PowerVersion")~=Economy.Version and p<=100 then
   p=math.floor(Economy.BasePower(id)*(.5+p*.05)+.5)
  end
  return {Power=p,IncomePerSecond=Economy.Income(id,p),RollQuality=Economy.Quality(id,p).Name}
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
 object:SetAttribute("IncomePerSecond",Economy.Income(id,stats.Power))
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
