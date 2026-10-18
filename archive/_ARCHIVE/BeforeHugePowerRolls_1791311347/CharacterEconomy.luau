
local Economy={}
Economy.BaseIncome={Pirate=5,Shinobi=12,Power=25,Hero=60,Slayer=125,Curse=250,Soul=600,Titan=1200,Magic=2500,Academy=15000,Devil=35000,Guild=75000,Sports=250000,Mecha=650000,God=1500000}
Economy.MaxPower=100
Economy.Falloff=.94
local random=Random.new()
local weights={} local total=0
for power=1,Economy.MaxPower do total+=Economy.Falloff^(power-1) weights[power]=total end
function Economy.Income(id,power)
 local base=Economy.BaseIncome[id] assert(base,"Unknown character type")
 power=math.clamp(math.floor(power),1,Economy.MaxPower)
 return math.max(1,math.floor(base*(.5+power*.05)+.5))
end
function Economy.Roll(id,rng)
 assert(Economy.BaseIncome[id],"Unknown character type")
 local roll=(rng or random):NextNumber(0,total) local power=Economy.MaxPower
 for i,cumulative in ipairs(weights) do if roll<cumulative then power=i break end end
 return {Power=power,IncomePerSecond=Economy.Income(id,power)}
end
function Economy.Read(object,id)
 local p=object and object:GetAttribute("Power")
 if type(p)=="number" and p==p and p>=1 and p<=Economy.MaxPower and p%1==0 then
  return {Power=p,IncomePerSecond=Economy.Income(id,p)}
 end
 return nil
end
function Economy.Apply(object,id,stats)
 assert(type(stats)=="table" and type(stats.Power)=="number" and stats.Power%1==0 and stats.Power>=1 and stats.Power<=Economy.MaxPower,"Invalid character power")
 object:SetAttribute("Power",stats.Power)
 object:SetAttribute("BaseIncomePerSecond",Economy.BaseIncome[id])
 object:SetAttribute("IncomePerSecond",Economy.Income(id,stats.Power))
 object:SetAttribute("PowerRolled",true)
end
function Economy.Format(n)
 if n>=1000000000 then return string.format("%.2fB",n/1000000000):gsub("%.00B","B") end
 if n>=1000000 then return string.format("%.2fM",n/1000000):gsub("%.00M","M") end
 if n>=1000 then return string.format("%.2fK",n/1000):gsub("%.00K","K") end
 return tostring(n)
end
function Economy.Color(power)
 if power>=80 then return Color3.fromRGB(255,213,101)
 elseif power>=60 then return Color3.fromRGB(206,143,255)
 elseif power>=40 then return Color3.fromRGB(112,188,255)
 elseif power>=20 then return Color3.fromRGB(125,238,183)
 else return Color3.fromRGB(218,225,239) end
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
 line("Power",preview and "POWER • RANDOM ON HATCH" or ("POWER "..stats.Power),0,preview and Color3.fromRGB(219,226,239) or Economy.Color(stats.Power))
 line("Income",(preview and "BASE $"..Economy.Format(Economy.BaseIncome[id]) or "$"..Economy.Format(stats.IncomePerSecond)).."/sec",23,Color3.fromRGB(132,241,166))
end
return Economy
