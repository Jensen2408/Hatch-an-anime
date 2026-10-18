
local Catalog={}
local ids={"Pirate","Shinobi","Power","Hero","Slayer","Curse","Soul","Titan","Magic","Academy","Devil","Guild","Sports","Mecha","God"}
local names={"TideCaptain","MoonRunner","SunForger","SproutGuard","LanternWarden","DuskWeaver","AshDuelist","SkyScout","RuneSmith","StarScholar","CopperImp","FrostNomad","CometStriker","PrismSentinel","DawnOracle"}
local prices={0,500,2500,10000,25000,60000,150000,350000,750000,10000000,35000000,100000000,500000000,2000000000,7500000000}
local rarities={"Common","Uncommon","Rare","Epic","Legendary"}
local colors={Color3.fromRGB(190,195,205),Color3.fromRGB(109,225,132),Color3.fromRGB(98,172,255),Color3.fromRGB(197,126,255),Color3.fromRGB(255,207,92)}
Catalog.Order={} Catalog.ById={}
for i,id in ipairs(ids) do
 local tier=math.ceil(i/3)
 local entry={Id=id,Name=names[i],Order=i,Rarity=rarities[tier],RarityRank=tier,Price=prices[i],Color=colors[tier]}
 table.insert(Catalog.Order,entry) Catalog.ById[id]=entry
end
function Catalog.FormatPrice(n)
 if n==0 then return "FREE" end
 local s=tostring(n) local result=s:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
 return "$"..result
end
function Catalog.Stamp(object,entry)
 for _,key in ipairs({"Rarity","RarityRank","Price","Order"}) do object:SetAttribute(key,entry[key]) end
 object:SetAttribute("DesignName",entry.Name)
end
function Catalog.Label(model,entry)
 local old=model:FindFirstChild("CharacterInfo") if old then old:Destroy() end
 local part=model:FindFirstChildWhichIsA("BasePart",true) if not part then return end
 local cf,size=model:GetBoundingBox()
 local gui=Instance.new("BillboardGui") gui.Name="CharacterInfo" gui.Adornee=part
 gui.Size=UDim2.fromOffset(210,72) gui.MaxDistance=75 gui.AlwaysOnTop=false
 gui.StudsOffsetWorldSpace=cf.Position+Vector3.new(0,size.Y/2+.7,0)-part.Position
 gui.Parent=model
 local function line(text,y,color,fontSize)
  local l=Instance.new("TextLabel") l.BackgroundTransparency=1 l.Size=UDim2.new(1,0,0,24) l.Position=UDim2.fromOffset(0,y)
  l.Text=text l.TextColor3=color l.Font=Enum.Font.GothamBold l.TextSize=fontSize l.TextStrokeColor3=Color3.fromRGB(15,17,22) l.TextStrokeTransparency=.15 l.Parent=gui
 end
 line(entry.Name,0,Color3.fromRGB(245,245,250),17)
 line(entry.Rarity,24,entry.Color,16)
 line(Catalog.FormatPrice(entry.Price),48,Color3.fromRGB(255,223,143),16)
end
return Catalog
