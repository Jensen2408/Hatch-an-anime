local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Tween=game:GetService("TweenService")
local UIS=game:GetService("UserInputService")
local Run=game:GetService("RunService")
local player=Players.LocalPlayer
if player.UserId~=168774222 then return end
local modules=RS:WaitForChild("OwnerPanel")
local C=require(modules.Components) local T=require(modules.Theme)
local Toast=require(modules.Toast) local Confirm=require(modules.ConfirmDialog)
local Log=require(modules.ActivityLog) local PlayerRow=require(modules.PlayerRow)
local remote=RS:WaitForChild("OwnerControl")
local gui=C.Make("ScreenGui",{Name="OwnerControlPanel",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=500,Enabled=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},player:WaitForChild("PlayerGui"))
local shade=C.Make("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(),BackgroundTransparency=.35},gui)
local panel=C.Make("CanvasGroup",{Name="Panel",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(1240,780),BackgroundColor3=T.Panel,BorderSizePixel=0},shade) C.Round(panel,18) C.Border(panel)
C.Make("UISizeConstraint",{MaxSize=Vector2.new(1240,780),MinSize=Vector2.new(280,240)},panel)
local animScale=C.Make("UIScale",{Scale=1},panel)
local sidebar=C.Make("Frame",{Name="Sidebar",Size=UDim2.new(0,224,1,0),BackgroundColor3=T.Sidebar,BorderSizePixel=0},panel)
local title=C.Label(panel,"Overview",21) title.Name="PageTitle" title.TextTruncate=Enum.TextTruncate.AtEnd title.TextWrapped=false
local subtitle=C.Label(panel,"Owner access · Current server",12,T.Muted) subtitle.TextTruncate=Enum.TextTruncate.AtEnd subtitle.TextWrapped=false
local scopeRow=C.Make("Frame",{BackgroundTransparency=1},panel)
local scopeLayout=C.Make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,4)},scopeRow)
local chip=C.Button(panel,"",nil,T.Input) chip.Name="Recipient"
local avatar=C.Make("ImageLabel",{BackgroundTransparency=1,Size=UDim2.fromOffset(32,32),Position=UDim2.fromOffset(8,6)},chip)
local recipientText=C.Label(chip,"Me",12) recipientText.Position=UDim2.fromOffset(48,2) recipientText.Size=UDim2.new(1,-56,1,-4) recipientText.TextTruncate=Enum.TextTruncate.AtEnd
local close=C.Button(panel,"×",function() gui.Enabled=false end) close.Size=UDim2.fromOffset(44,44)
local mobileNav=C.Make("ScrollingFrame",{Name="MobileNavigation",BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=0,AutomaticCanvasSize=Enum.AutomaticSize.X,CanvasSize=UDim2.new()},panel)
C.Make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8)},mobileNav)
local content=C.Make("ScrollingFrame",{Name="Content",BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=T.Border,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new()},panel)
C.Make("UIPadding",{PaddingTop=UDim.new(0,20),PaddingBottom=UDim.new(0,20),PaddingLeft=UDim.new(0,20),PaddingRight=UDim.new(0,20)},content)
local body=C.Make("CanvasGroup",{Name="Body",Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1},content)
C.Stack(body,16)
local footer=C.Label(panel,"Ready · /owner",12,T.Muted)
local pages={"Overview","Players","Eggs and Characters","Money","Temples and Incubators","Events","Activity log"}
local selectedId=player.UserId local selectedName=player.Name local selectedDisplay=player.DisplayName
local scope="Me" local page="Overview" local working=false local data={Items={}}
local mobile=false local width=1240 local render local navButtons={} local mobileButtons={} local scopeButtons={}
local searchText="" local rarityFilter="All" local typeFilter="All" local selectedItem=nil local amountText="" local playerSearch="" local durationBy={EggRush=300,DoubleCash=300,GoldenHour=300}
local picker=C.Make("Frame",{Name="PlayerPicker",Visible=false,Size=UDim2.fromOffset(360,320),BackgroundColor3=T.Sidebar,BorderSizePixel=0,ZIndex=20},panel) C.Round(picker,14) C.Border(picker)
local pickerSearch=C.Input(picker,"Find online player…") pickerSearch.Name="PlayerSearch" pickerSearch.Position=UDim2.fromOffset(12,12) pickerSearch.Size=UDim2.new(1,-24,0,44)
local pickerList=C.Make("ScrollingFrame",{Name="OnlinePlayers",Position=UDim2.fromOffset(12,68),Size=UDim2.new(1,-24,1,-80),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new()},picker) C.Stack(pickerList,8)
local function roster() local r=Players:GetPlayers() table.sort(r,function(a,b)return a.Name:lower()<b.Name:lower()end) return r end
local function target() return scope=="Lobby" and "ALL" or scope=="Me" and tostring(player.UserId) or tostring(selectedId) end
local function targetLabel()
 if scope=="Lobby" then return "Entire current lobby" end
 local id=scope=="Me" and player.UserId or selectedId
 local p=Players:GetPlayerByUserId(id)
 return p and (p.DisplayName.." · @"..p.Name.." · "..p.UserId) or (selectedDisplay.." · @"..selectedName.." · "..id.." · LEFT")
end
local function plotOfTarget()
 if scope=="Lobby" then return nil end
 local id=scope=="Me" and player.UserId or selectedId local plots=workspace:FindFirstChild("Plots")
 if plots then for _,p in plots:GetChildren() do if p:GetAttribute("OwnerUserId")==id then return p end end end
end
local function updateRecipient()
 local left=scope=="Selected" and Players:GetPlayerByUserId(selectedId)==nil
 chip.BackgroundColor3=left and T.ErrorBG or T.Input recipientText.Text=targetLabel() recipientText.TextColor3=left and T.Error or T.Text
 local id=scope=="Me" and player.UserId or selectedId
 avatar.Image=scope=="Lobby" and "" or ("rbxthumb://type=AvatarHeadShot&id="..id.."&w=100&h=100")
 for name,b in scopeButtons do b.BackgroundColor3=name==scope and T.DarkRed or T.Card end
end
local function choose(p) selectedId=p.UserId selectedName=p.Name selectedDisplay=p.DisplayName scope="Selected" picker.Visible=false updateRecipient() if render then render() end end
local function refreshPicker()
 for _,o in pickerList:GetChildren() do if o:IsA("GuiObject") then o:Destroy() end end
 local q=pickerSearch.Text:lower()
 for _,p in roster() do if (p.DisplayName.." "..p.Name.." "..p.UserId):lower():find(q,1,true) then local b=PlayerRow.New(pickerList,p,p.UserId==selectedId and "Selected" or "",function() choose(p) end) b.ZIndex=21 for _,o in b:GetDescendants() do if o:IsA("GuiObject") then o.ZIndex=22 end end end end
 pickerSearch.ZIndex=21
end
chip.Activated:Connect(function() picker.Visible=not picker.Visible if picker.Visible then refreshPicker() end end)
pickerSearch:GetPropertyChangedSignal("Text"):Connect(refreshPicker)
local function actionReason(action)
 if scope=="Selected" and not Players:GetPlayerByUserId(selectedId) then return "Selected player has left." end
 if scope=="Lobby" and action~="GiveCash" and action~="SpawnEgg" and action~="SpawnCharacter" then return "Choose one player." end
end
local function request(action,payload,b)
 if working then return end
 working=true local oldText=b and b.Text
 local buttons={} for _,o in panel:GetDescendants() do if o:IsA("GuiButton") then buttons[o]=o.Interactable o.Interactable=false end end
 if b then b.Text="◌ Waiting for server…" end footer.Text="Waiting for server…"
 local ok,result=pcall(remote.InvokeServer,remote,action,payload or {})
 if not ok or type(result)~="table" then result={Ok=false,Message="Connection failed. Please try again."} end
 working=false
 for o,enabled in buttons do if o.Parent then o.Interactable=enabled end end
 if b and b.Parent then b.Text=oldText end
 if action=="Info" then if result.Ok then data=result footer.Text="Ready · /owner" end return result end
 Log.Add(action,payload and payload.Target=="ALL" and "Lobby" or payload and payload.Target or "Current server",result)
 footer.Text=result.Message or "Ready" footer.TextColor3=result.Ok and T.Success or T.Error
 Toast.Show(panel,result.Message or "Request finished.",result.Ok)
 return result
end
local destructive={SetCash=true,Respawn=true,ClearInventory=true,ClearPlaced=true,ResetSlots=true,Kick=true,Ban24h=true,Unban=true}
local function runAction(action,payload,b,serverOnly)
 payload=payload or {} if not serverOnly then payload.Target=target() end
 local reason=not serverOnly and actionReason(action)
 if reason then Toast.Show(panel,reason,false) return end
 local function perform() task.spawn(function() request(action,payload,b) if gui.Enabled then render() end end) end
 if destructive[action] or payload.Target=="ALL" then
 Confirm.Show(panel,action,serverOnly and (payload.Target or "Current server") or targetLabel(),action=="Ban24h" and "This bans the account from the experience for 24 hours." or action=="SetCash" and "This replaces the player's current balance." or "Confirm applying this action. Removed items cannot be recovered from this panel.",function() payload.Confirmed=true perform() end)
 else perform() end
end
local function actionButton(parent,label,action,payload,reason,serverOnly,color)
 local b=C.Button(parent,label,function(button) runAction(action,payload,button,serverOnly) end,color)
 C.Disable(b,reason or (not serverOnly and actionReason(action) or nil)) return b
end
local function horizontal(parent,choices,chosen,onSelect)
 local scroll=mobile and #choices>4
 local f=C.Make(scroll and "ScrollingFrame" or "Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,44)},parent)
 if scroll then f.BorderSizePixel=0 f.ScrollBarThickness=0 f.AutomaticCanvasSize=Enum.AutomaticSize.X f.CanvasSize=UDim2.new() end
 C.Make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8)},f)
 for _,name in choices do local b=C.Button(f,name,function() onSelect(name) end,name==chosen and T.DarkRed or T.Input) b.Size=scroll and UDim2.fromOffset(92,44) or UDim2.new(1/#choices,-8,0,44) b.TextSize=12 end return f
end
local function heading(str) C.Label(body,str,21) end
local function grid(columns,height)
 local f=C.Make("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},body)
 local layout=C.Make("UIGridLayout",{CellSize=UDim2.new(1/columns,-(columns-1)*12/columns,0,height),CellPadding=UDim2.fromOffset(12,12)},f)
 f.AutomaticSize=Enum.AutomaticSize.None
 local function fit() f.Size=UDim2.new(1,0,0,layout.AbsoluteContentSize.Y) end
 layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit) task.defer(fit) return f
end
local eventLabels={}
local function eventRemaining() return math.max(0,math.ceil((workspace:GetAttribute("OwnerEventEnds") or 0)-workspace:GetServerTimeNow())) end
render=function()
 if working then return end
 local sticky=panel:FindFirstChild("StickyItemSummary") if sticky then sticky:Destroy() end
 body.Size=UDim2.new(1,-40,0,0)
 for _,o in body:GetChildren() do if o:IsA("GuiObject") then o:Destroy() end end
 eventLabels={} title.Text=page updateRecipient()
 for name,b in navButtons do b.BackgroundColor3=name==page and Color3.fromRGB(42,29,34) or T.Sidebar b.Bar.Visible=name==page end
 for name,b in mobileButtons do b.BackgroundColor3=name==page and T.DarkRed or T.Card end
 local plot=plotOfTarget() local columns=mobile and 1 or 2
 if page=="Overview" then
 local stats=grid(mobile and 1 or 4,112)
 local interval=workspace:FindFirstChild("PirateEggConveyor") and workspace.PirateEggConveyor:GetAttribute("SpawnInterval")
 for _,entry in {{"Online players",tostring(#roster())},{"Active event",workspace:GetAttribute("OwnerEventName") or "None"},{"River interval",interval and (interval.." sec") or "Unavailable"},{"Selected plot",plot and (plot.Name.." · LV "..(plot:GetAttribute("TempleLevel") or 1)) or "No plot"}} do
 local card=C.Card(stats,nil) card.Size=UDim2.fromScale(1,1) card.AutomaticSize=Enum.AutomaticSize.None C.Label(card,entry[1],12,T.Muted) local l=C.Label(card,entry[2],24,T.Gold) l.TextScaled=true if entry[1]=="Active event" then table.insert(eventLabels,l) end end
 heading("Quick actions")
 for _,entry in {{"Players","Choose online player"},{"Eggs and Characters","Give eggs or characters"},{"Money","Manage cash"},{"Temples and Incubators","Manage a plot"},{"Events","Run a server event"},{"Activity log","Review completed actions"}} do C.Button(body,entry[2],function() page=entry[1] render() end) end
 elseif page=="Players" then
 local search=C.Input(body,"Search display name, @username or User ID") search.Text=playerSearch
 local list=C.Make("Frame",{Name="PlayerRows",BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},body) C.Stack(list,8)
 local function refresh()
 for _,o in list:GetChildren() do if o:IsA("GuiObject") then o:Destroy() end end
 local names={} for _,p in roster() do names[p.DisplayName]=(names[p.DisplayName] or 0)+1 end
 local n=0 for _,p in roster() do if (p.Name.." "..p.DisplayName.." "..p.UserId):lower():find(playerSearch:lower():gsub("^@",""),1,true) then
 local tags=(p.UserId==selectedId and "Selected  " or "")..(names[p.DisplayName]>1 and "Same name  " or "")..(p.UserId==168774222 and "Owner" or "")
 PlayerRow.New(list,p,tags,function() choose(p) end) n+=1 end end
 if n==0 then C.Label(list,"No matching online players.",14,T.Muted) end
 if not Players:GetPlayerByUserId(selectedId) then C.Label(list,selectedDisplay.." · @"..selectedName.." · Left",14,T.Error) end
 end
 search:GetPropertyChangedSignal("Text"):Connect(function() playerSearch=search.Text refresh() end) refresh()
 local card=C.Card(body,"Moderation")
 local id=scope=="Me" and player.UserId or selectedId
 local reason=id==168774222 and "Owner account is protected." or actionReason("Kick")
 actionButton(card,"Kick from this server","Kick",nil,reason)
 actionButton(card,"Ban for 24 hours","Ban24h",nil,Run:IsStudio() and "Available in the published game." or reason)
 local offline=C.Input(card,"User ID to unban")
 C.Button(card,"Unban typed User ID",function(b)
 local n=tonumber(offline.Text) if not n or n%1~=0 or n<1 then Toast.Show(panel,"Enter a valid numeric User ID.",false) return end
 runAction("Unban",{Target=tostring(n)},b,true)
 end)
 C.Label(card,"Persistent bans are unavailable in Studio.",12,T.Muted)
 elseif page=="Eggs and Characters" then
 local search=C.Input(body,"Search eggs, characters or rarity") search.Text=searchText
 horizontal(body,{"All","Common","Uncommon","Rare","Epic","Legendary"},rarityFilter,function(v) rarityFilter=v render() end)
 horizontal(body,{"All","Eggs","Characters"},typeFilter,function(v) typeFilter=v render() end)
 local selection=C.Card(mobile and body or panel,"Selected item")
 if not mobile then selection.Name="StickyItemSummary" selection.Position=UDim2.new(1,-290,0,112) selection.Size=UDim2.fromOffset(270,0) body.Size=UDim2.new(1,-336,0,0) end
 local item for _,e in data.Items or {} do if e.Id==selectedItem then item=e break end end
 C.Label(selection,item and (item.Id.." · "..item.Rarity.." · $"..C.Format(item.Price)) or "Select a catalog item below.",14,T.Gold)
 C.Label(selection,"Recipient: "..targetLabel(),12,T.Muted)
 local unavailable=not item and "Choose an item." or item.Reserved and "Reserved for a future update." or nil
 actionButton(selection,"Give egg","SpawnEgg",{Id=selectedItem},unavailable or (item and not item.EggAvailable and "No egg has been imported." or nil))
 actionButton(selection,"Give character","SpawnCharacter",{Id=selectedItem},unavailable)
 actionButton(selection,"Spawn on river","SpawnRiverEgg",{Id=selectedItem},unavailable or (item and not item.EggAvailable and "No egg has been imported." or nil),true)
 local list=grid(columns,144) list.Name="CatalogCards"
 local function populate()
 for _,o in list:GetChildren() do if o:IsA("GuiObject") then o:Destroy() end end
 for _,e in data.Items or {} do
 if (e.Id.." "..e.Name.." "..e.Rarity):lower():find(searchText:lower(),1,true) and (rarityFilter=="All" or e.Rarity==rarityFilter) and (typeFilter=="All" or typeFilter=="Eggs" and e.EggAvailable or typeFilter=="Characters" and e.CharacterAvailable~=false) then
 local b=C.Button(list,e.Name.."\n"..e.Id.." · "..e.Rarity.."\n"..(e.Reserved and "Reserved" or e.EggAvailable and "Egg available" or "Character only").." · $"..C.Format(e.Price),function() selectedItem=e.Id render() end,e.Id==selectedItem and T.DarkRed or T.Card)
 b.Name="Catalog_"..e.Id b:SetAttribute("CharacterId",e.Id) b.Size=UDim2.fromScale(1,1) if e.Reserved then b.Interactable=false b.TextTransparency=.5 end
 end end end
 search:GetPropertyChangedSignal("Text"):Connect(function() searchText=search.Text populate() end) populate()
 elseif page=="Money" then
 local card=C.Card(body,"Cash • "..targetLabel()) card.Name="MoneyCard"
 local input=C.Input(card,"Amount from 0 to 1 trillion") input.Text=amountText
 local preview=C.Label(card,"",24,T.Gold) local errorText=C.Label(card,"",12,T.Error)
 local give=actionButton(card,"Give cash","GiveCash",{Amount=amountText},nil,false,T.Red)
 local set=actionButton(card,"Set exact balance","SetCash",{Amount=amountText})
 local lobby=C.Button(card,"Give to entire lobby",function(b) runAction("GiveCash",{Target="ALL",Amount=amountText},b,true) end)
 local function valid()
 amountText=input.Text local n=tonumber(amountText) local ok=n and n==n and n>=0 and n<=1e12 and n%1==0
 preview.Text=ok and ("$"..C.Format(n)) or "$—" errorText.Text=ok and "" or "Enter a whole amount between 0 and 1 trillion."
 for _,b in {give,set,lobby} do b.Interactable=ok and not b:GetAttribute("DisabledReason") or false end
 end
 -- Rebuild these callbacks around the current input instead of captured text.
 give:Destroy() set:Destroy() lobby:Destroy()
 horizontal(card,{"1K","100K","1M","1B"},"",function(v) input.Text=tostring(({["1K"]=1000,["100K"]=100000,["1M"]=1000000,["1B"]=1e9})[v]) end)
 give=C.Button(card,"Give cash",function(b) runAction("GiveCash",{Amount=amountText},b) end,T.Red)
 set=C.Button(card,"Set exact balance",function(b) runAction("SetCash",{Amount=amountText},b) end)
 lobby=C.Button(card,"Give to entire lobby",function(b) runAction("GiveCash",{Target="ALL",Amount=amountText},b,true) end)
 give.Name="GiveCash" input.Name="CashAmount"
 C.Disable(give,actionReason("GiveCash")) C.Disable(set,actionReason("SetCash"))
 input:GetPropertyChangedSignal("Text"):Connect(valid) valid()
 elseif page=="Temples and Incubators" then
 local card=C.Card(body,"Temple and slots")
 if plot then
 local level=plot:GetAttribute("TempleLevel") or 1 C.Label(card,"Temple level "..level.." / 3",24,T.Gold)
 local bars=C.Label(card,string.rep("■ ",level)..string.rep("□ ",5-level).."  ·  3 playable levels",14,T.Muted)
 local slots={} for _,s in plot.Slots:GetChildren() do table.insert(slots,s) end table.sort(slots,function(a,b)return a.Name<b.Name end)
 local row="" local unlocked=0 for _,s in slots do if s:GetAttribute("Unlocked") then unlocked+=1 end end
 for i=1,6 do row..=(i<=math.ceil(unlocked/math.max(1,#slots)*6) and "■ " or "□ ") end
 C.Label(card,row.."  "..unlocked.." / "..#slots.." slots unlocked",14,T.Muted)
 actionButton(card,"Upgrade temple","UpgradeTemple",nil,level>=3 and "Maximum temple level." or plot:GetAttribute("TempleBuilding") and "Construction in progress." or nil)
 actionButton(card,"Unlock all slots","UnlockSlots")
 else C.Label(card,"No plot for this recipient.",14,T.Muted) end
 local chambers=plot and plot:FindFirstChild("Chambers")
 for index=1,3 do local chamber=chambers and chambers:FindFirstChild("Chamber"..index)
 local c=C.Card(body,"Incubator "..index)
 if chamber then local level=chamber:GetAttribute("UpgradeLevel") or 1 local state=chamber:GetAttribute("Status") or "Ready" C.Label(c,"Level "..level.." / 3 · "..state,14,T.Gold)
 actionButton(c,"Upgrade incubator","UpgradeChamber",{Index=index},level>=3 and "Maximum level." or ((state~="Ready" or chamber:GetAttribute("UnderConstruction") or plot:GetAttribute("ChamberBuilding")) and "Wait for the incubator to be ready." or nil))
 else C.Label(c,"Not built",14,T.Muted) actionButton(c,"Add next incubator","AddChamber",nil,not plot and "No plot." or plot:GetAttribute("ChamberBuilding") and "Construction in progress." or nil) end end
 local actions=C.Card(body,"Player actions")
 for _,e in {{"Send home","GoHome"},{"Go to player","TeleportTo"},{"Bring player","Bring"},{"Respawn player","Respawn"}} do actionButton(actions,e[1],e[2]) end
 local cleanup=C.Card(body,"Clean-up · confirmation required",T.DarkRed)
 for _,e in {{"Clear held inventory","ClearInventory"},{"Clear placed characters","ClearPlaced"},{"Reset slot unlocks","ResetSlots"}} do actionButton(cleanup,e[1],e[2]) end
 elseif page=="Events" then
 local active=workspace:GetAttribute("OwnerEventName")
 local banner=C.Card(body,active and ("Active: "..active) or "No active event",active and T.DarkRed or T.Card)
 local countdown=C.Label(banner,"",24,T.Gold) table.insert(eventLabels,countdown)
 actionButton(banner,"Stop event","StopEvent",nil,not active and "No event running." or nil,true)
 for _,event in {{"EggRush","Egg Rush","Eggs spawn twice as often."},{"DoubleCash","Double Cash","Placed characters earn double cash."},{"GoldenHour","Golden Hour","Warm sunset lighting."}} do
 local card=C.Card(body,event[2]) C.Label(card,event[3],14,T.Muted)
 horizontal(card,{"5 min","10 min","30 min"},durationBy[event[1]]==300 and "5 min" or durationBy[event[1]]==600 and "10 min" or "30 min",function(v) durationBy[event[1]]=({["5 min"]=300,["10 min"]=600,["30 min"]=1800})[v] render() end)
 actionButton(card,"Start "..event[2],"StartEvent",{Kind=event[1],Duration=durationBy[event[1]]},active and "Stop the active event first." or nil,true,T.Red) end
 local card=C.Card(body,"River spawn interval")
 local river=workspace:FindFirstChild("PirateEggConveyor") local input=C.Input(card,"1.5–30 seconds") input.Text=tostring(river and river:GetAttribute("SpawnInterval") or 4)
 horizontal(card,{"− 0.5","+ 0.5","Reset"},"",function(v) input.Text=tostring(v=="Reset" and 4 or math.clamp((tonumber(input.Text) or 4)+(v=="− 0.5" and -.5 or .5),1.5,30)) end)
 local apply=C.Button(card,"Apply interval",function(b) runAction("SetSpawnInterval",{Amount=input.Text},b,true) end) C.Disable(apply,active and "Stop the active event first." or nil)
 else
 C.Button(body,"Clear session log",function() Log.Clear() render() end)
 C.Label(body,"Time / Action / Target / Result / Server response",12,T.Muted)
 if #Log.Rows==0 then C.Label(body,"No actions recorded in this session.",14,T.Muted) end
 for _,row in Log.Rows do local card=C.Card(body,nil) C.Label(card,row.Time.."  /  "..row.Action.."  /  "..row.Target.."  /  "..(row.Ok and "Success" or "Failed"),12,row.Ok and T.Success or T.Error) C.Label(card,row.Response,14,T.Muted) end
 end
 body.GroupTransparency=1 body.Position=UDim2.fromOffset(0,6) Tween:Create(body,TweenInfo.new(.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{GroupTransparency=0,Position=UDim2.fromOffset(0,0)}):Play()
end
for i,name in pages do
 local b=C.Button(sidebar,name,function() page=name picker.Visible=false render() end,T.Sidebar) b.Name="Nav"..i b.Position=UDim2.fromOffset(12,120+(i-1)*64) b.Size=UDim2.fromOffset(200,52) b.TextSize=14
 C.Make("Frame",{Name="Bar",Position=UDim2.fromOffset(0,8),Size=UDim2.new(0,3,1,-16),BackgroundColor3=T.Red,BorderSizePixel=0,Visible=false},b) navButtons[name]=b
 local mb=C.Button(mobileNav,name,function() page=name picker.Visible=false render() end) mb.Size=UDim2.fromOffset(160,44) mobileButtons[name]=mb
end
for y=0,1 do for x=0,2 do local stud=C.Make("Frame",{Position=UDim2.fromOffset(24+x*22,22+y*22),Size=UDim2.fromOffset(16,16),BackgroundColor3=T.Red,BorderSizePixel=0},sidebar) C.Round(stud,4) end end
local logo=C.Label(sidebar,"OWNER\nCONTROL",16) logo.Position=UDim2.fromOffset(104,18) logo.Size=UDim2.fromOffset(110,52)
for _,name in {"Me","Selected","Lobby"} do local b=C.Button(scopeRow,name,function() scope=name updateRecipient() render() end) b.Size=UDim2.new(1/3,-4,0,44) b.TextSize=12 scopeButtons[name]=b end
local function layout(view)
 mobile=view.X<600 width=math.min(1240,view.X-24) local height=math.min(780,view.Y-24)
 panel.Size=UDim2.fromOffset(width,height) sidebar.Visible=not mobile mobileNav.Visible=mobile
 if mobile then
 title.Position=UDim2.fromOffset(16,10) title.Size=UDim2.new(1,-76,0,28) subtitle.Visible=false
 close.Position=UDim2.new(1,-56,0,8)
 mobileNav.Position=UDim2.fromOffset(12,54) mobileNav.Size=UDim2.new(1,-24,0,48)
 scopeRow.Position=UDim2.fromOffset(12,110) scopeRow.Size=UDim2.new(1,-24,0,44)
 chip.Position=UDim2.fromOffset(12,162) chip.Size=UDim2.new(1,-24,0,44)
 content.Position=UDim2.fromOffset(0,218) content.Size=UDim2.new(1,0,1,-254)
 footer.Position=UDim2.new(0,12,1,-30) footer.Size=UDim2.new(1,-24,0,24)
 picker.Position=UDim2.fromOffset(12,210) picker.Size=UDim2.new(1,-24,0,math.max(120,math.min(320,height-230)))
 else
 local available=width-264 local titleWidth=math.max(90,available-468)
 title.Position=UDim2.fromOffset(244,20) title.Size=UDim2.fromOffset(titleWidth,28)
 subtitle.Visible=true subtitle.Position=UDim2.fromOffset(244,48) subtitle.Size=UDim2.fromOffset(titleWidth,24)
 scopeRow.Position=UDim2.fromOffset(width-460,24) scopeRow.Size=UDim2.fromOffset(204,44)
 chip.Position=UDim2.fromOffset(width-244,24) chip.Size=UDim2.fromOffset(180,44)
 close.Position=UDim2.new(1,-56,0,24)
 content.Position=UDim2.fromOffset(224,92) content.Size=UDim2.new(1,-224,1,-130)
 footer.Position=UDim2.new(0,244,1,-30) footer.Size=UDim2.new(1,-264,0,24)
 picker.Position=UDim2.fromOffset(width-380,78) picker.Size=UDim2.fromOffset(360,320)
 end
end
local function open()
 if gui.Enabled then gui.Enabled=false return end
 local r=request("Info") if not r or not r.Ok then return end
 gui.Enabled=true picker.Visible=false layout(workspace.CurrentCamera.ViewportSize) render()
 panel.GroupTransparency=1 animScale.Scale=.96
 Tween:Create(panel,TweenInfo.new(.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{GroupTransparency=0}):Play()
 Tween:Create(animScale,TweenInfo.new(.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=1}):Play()
end
RS:WaitForChild("OwnerPanelOpen").OnClientEvent:Connect(open)
UIS.InputBegan:Connect(function(input,processed) if not processed and input.KeyCode==Enum.KeyCode.Escape then gui.Enabled=false end end)
player.Chatted:Connect(function(message) if message:lower()=="/owner" and game:GetService("TextChatService").ChatVersion==Enum.ChatVersion.LegacyChatService then open() end end)
Players.PlayerAdded:Connect(function() if picker.Visible then refreshPicker() end if gui.Enabled then render() end end)
Players.PlayerRemoving:Connect(function() task.defer(function() updateRecipient() if picker.Visible then refreshPicker() end if gui.Enabled then render() end end) end)
workspace:GetAttributeChangedSignal("OwnerEventName"):Connect(function() if gui.Enabled and not working then render() end end)
local elapsed=0 local lastView=Vector2.zero
Run.Heartbeat:Connect(function(dt)
 elapsed+=dt if elapsed<.25 then return end elapsed=0 if not gui.Enabled then return end
 local view=workspace.CurrentCamera.ViewportSize if view~=lastView then local oldMobile=mobile lastView=view layout(view) if oldMobile~=mobile then render() end end
 for _,l in eventLabels do if l.Parent then local active=workspace:GetAttribute("OwnerEventName") l.Text=active and (active.." · "..math.floor(eventRemaining()/60)..":"..string.format("%02d",eventRemaining()%60)) or "None" end end
end)
-- Deterministic layout checks can use this client-only BindableFunction.
local check=C.Make("BindableFunction",{Name="PreviewLayout"},gui)
check.OnInvoke=function(x,y,requestedPage) if requestedPage and table.find(pages,requestedPage) then page=requestedPage end layout(Vector2.new(x,y)) render() return {Width=width,Mobile=mobile,PanelHeight=panel.Size.Y.Offset,ContentWidth=content.Size.X.Offset,Sidebar=sidebar.Visible} end
