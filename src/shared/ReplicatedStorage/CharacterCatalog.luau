
local Catalog={}
-- Display text only; model IDs and artwork keys retain their existing names.
-- Player-facing names (Adam, Oct 16): hint at the anime each one references.
local RENAME={TideCaptain="Straw Captain",MoonRunner="Leaf Runner",SunForger="Solar Warrior",SproutGuard="Emerald Hero",LanternWarden="Ember Slayer",DuskWeaver="Infinity Sage",AshDuelist="Soul Reaper",SkyScout="Titan Shifter",RuneSmith="Clover Knight"}
Catalog.Rename=RENAME
function Catalog.DisplayName(name)
 if RENAME[tostring(name)] then return RENAME[tostring(name)] end
 return (tostring(name):gsub("(%l)(%u)","%1 %2"):gsub("(%u)(%u%l)","%1 %2"))
end
local ids={"Pirate","Shinobi","Power","Hero","Slayer","Curse","Soul","Titan","Magic","Academy","Devil","Guild","Sports","Mecha","God"}
local names={"TideCaptain","MoonRunner","SunForger","SproutGuard","LanternWarden","DuskWeaver","AshDuelist","SkyScout","RuneSmith","StarScholar","CopperImp","FrostNomad","CometStriker","PrismSentinel","DawnOracle"}
local prices={0,750,3000,20000,40000,100000,400000,750000,2000000,12000000,35000000,100000000,600000000,1500000000,5000000000} -- economy v4 (Oct 15): ~1 min common → ~1 h legendary payback
local rarities={"Common","Uncommon","Rare","Epic","Legendary"}
local colors={Color3.fromRGB(190,195,205),Color3.fromRGB(109,225,132),Color3.fromRGB(98,172,255),Color3.fromRGB(197,126,255),Color3.fromRGB(255,207,92)}
-- Percent chance per rarity, shared by all eggs within that rarity.
Catalog.SpawnChances={Common=70,Uncommon=22,Rare=6.5,Epic=1.3,Legendary=.2}
function Catalog.BuildSpawnPool(templates)
 local buckets={}
 for _,template in ipairs(templates) do
  local entry=Catalog.ById[template.Name]
  if entry and template:GetAttribute("ReleaseEnabled")~=false then
   local bucket=buckets[entry.Rarity] or {}
   buckets[entry.Rarity]=bucket table.insert(bucket,template)
  end
 end
 local pool={} local total=0
 for _,rarity in ipairs({"Common","Uncommon","Rare","Epic","Legendary"}) do
  local bucket=buckets[rarity]
  local weight=Catalog.SpawnChances[rarity] or 0
  if bucket and #bucket>0 and weight>0 then
   total+=weight table.insert(pool,{Items=bucket,Weight=weight})
  end
 end
 assert(total>0,"No released eggs have a configured spawn rarity")
 return function(random)
  local roll=random:NextNumber(0,total) local cumulative=0
  for _,bucket in ipairs(pool) do
   cumulative+=bucket.Weight
   if roll<cumulative then return bucket.Items[random:NextInteger(1,#bucket.Items)] end
  end
  local items=pool[#pool].Items return items[random:NextInteger(1,#items)]
 end
end
Catalog.Order={} Catalog.ById={}

for i,id in ipairs(ids) do
 local tier=math.ceil(i/3)
 local entry={Id=id,Name=Catalog.DisplayName(names[i]),AssetName=names[i],Order=i,Rarity=rarities[tier],RarityRank=tier,Price=prices[i],Color=colors[tier]}
 table.insert(Catalog.Order,entry) Catalog.ById[id]=entry
end
-- LIMITED: Unknown (from the 199 R$ Unknown Egg only; never spawns on the river)
do local e={Id="Unknown",Name="Unknown",Order=16,Rarity="Limited",RarityRank=6,Price=0,Color=Color3.fromRGB(255,60,90),Limited=true} table.insert(Catalog.Order,e) Catalog.ById.Unknown=e end
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

local MenuImages={["AshDuelist"]="rbxassetid://86519861962600",
["CometStriker"]="rbxassetid://96416272941728",
["CopperImp"]="rbxassetid://112987882831167",
["DawnOracle"]="rbxassetid://77906939709813",
["DuskWeaver"]="rbxassetid://99801009246682",
["FrostNomad"]="rbxassetid://119820320826727",
["LanternWarden"]="rbxassetid://74677117609190",
["MoonRunner"]="rbxassetid://126333199801308",
["PrismSentinel"]="rbxassetid://87083032561086",
["RuneSmith"]="rbxassetid://139172704925469",
["SkyScout"]="rbxassetid://126336500094509",
["SproutGuard"]="rbxassetid://76887827944280",
["StarScholar"]="rbxassetid://81810975929521",
["SunForger"]="rbxassetid://138059275161423",
["TideCaptain"]="rbxassetid://126909405621214"}
for _,entry in Catalog.Order do entry.image=MenuImages[entry.AssetName or entry.Name] end
return Catalog
