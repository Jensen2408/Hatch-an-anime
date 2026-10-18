
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Tween=game:GetService("TweenService")
local player=Players.LocalPlayer
if player.UserId~=168774222 then return end
local remote=RS:WaitForChild("OwnerControl")
local gui=Instance.new("ScreenGui") gui.Name="OwnerControlPanel" gui.ResetOnSpawn=false gui.IgnoreGuiInset=true gui.DisplayOrder=500 gui.Enabled=false gui.Parent=player:WaitForChild("PlayerGui")
local accent=Color3.fromRGB(237,68,89)
local function round(x,r) local c=Instance.new("UICorner",x) c.CornerRadius=UDim.new(0,r or 8) end
local function text(parent,str,pos,size,fs,color)
 local t=Instance.new("TextLabel") t.BackgroundTransparency=1 t.Position=pos t.Size=size t.Text=str t.TextColor3=color or Color3.fromRGB(242,244,251) t.Font=Enum.Font.GothamBold t.TextSize=fs or 15 t.TextXAlignment=Enum.TextXAlignment.Left t.Parent=parent return t
end
local function button(parent,str,pos,size,color)
 local b=Instance.new("TextButton") b.Position=pos b.Size=size b.Text=str b.TextColor3=Color3.fromRGB(245,245,250) b.BackgroundColor3=color or Color3.fromRGB(38,43,55) b.Font=Enum.Font.GothamBold b.TextSize=14 b.AutoButtonColor=false b.Parent=parent b.BorderSizePixel=0 round(b,10)
 local border=Instance.new("UIStroke",b) border.Color=Color3.fromRGB(70,77,94) border.Transparency=.65
 b.MouseEnter:Connect(function() Tween:Create(border,TweenInfo.new(.15),{Transparency=.05}):Play() end)
 b.MouseLeave:Connect(function() Tween:Create(border,TweenInfo.new(.2),{Transparency=.65}):Play() end)
 return b
end
local function box(parent,hint,pos,size)
 local b=Instance.new("TextBox") b.Position=pos b.Size=size b.PlaceholderText=hint b.Text="" b.ClearTextOnFocus=false b.Font=Enum.Font.Gotham b.TextSize=14 b.TextColor3=Color3.new(1,1,1) b.PlaceholderColor3=Color3.fromRGB(150,157,176) b.BackgroundColor3=Color3.fromRGB(27,31,41) b.Parent=parent b.BorderSizePixel=0 round(b,10)
 local pad=Instance.new("UIPadding",b) pad.PaddingLeft=UDim.new(0,12) pad.PaddingRight=UDim.new(0,12)
 local border=Instance.new("UIStroke",b) border.Color=Color3.fromRGB(67,77,96) border.Transparency=.35
 b.Focused:Connect(function() border.Color=accent end) b.FocusLost:Connect(function() border.Color=Color3.fromRGB(67,77,96) end)
 return b
end
local shade=Instance.new("Frame") shade.Size=UDim2.fromScale(1,1) shade.BackgroundColor3=Color3.new() shade.BackgroundTransparency=.35 shade.Parent=gui
local panel=Instance.new("CanvasGroup") panel.Name="Panel" panel.BackgroundTransparency=0 panel.AnchorPoint=Vector2.new(.5,.5) panel.Position=UDim2.fromScale(.5,.5) panel.Size=UDim2.fromOffset(1000,680) panel.BackgroundColor3=Color3.fromRGB(16,19,27) panel.Parent=shade round(panel,16)
local scale=Instance.new("UIScale",panel)
local stroke=Instance.new("UIStroke",panel) stroke.Color=Color3.fromRGB(74,47,59) stroke.Thickness=1.5
local strip=Instance.new("Frame") strip.Size=UDim2.new(1,-32,0,3) strip.Position=UDim2.fromOffset(16,0) strip.BackgroundColor3=accent strip.BorderSizePixel=0 strip.Parent=panel
text(panel,"OWNER CONTROL",UDim2.fromOffset(264,26),UDim2.fromOffset(480,34),27)
text(panel,"PRIVATE ACCESS   /   CURRENT SERVER",UDim2.fromOffset(265,68),UDim2.fromOffset(600,24),11,Color3.fromRGB(154,164,188))
local close=button(panel,"×",UDim2.new(1,-58,0,20),UDim2.fromOffset(34,34))
local status=text(panel,"Ready. Type /owner in chat to open this panel.",UDim2.fromOffset(264,632),UDim2.fromOffset(712,28),13,Color3.fromRGB(174,186,207))
local body=Instance.new("Frame") body.Name="Content" body.Position=UDim2.fromOffset(264,190) body.Size=UDim2.fromOffset(712,420) body.BackgroundTransparency=1 body.Parent=panel
text(panel,"RECIPIENT",UDim2.fromOffset(264,126),UDim2.fromOffset(76,34),12,Color3.fromRGB(161,172,194))
local recipient=box(panel,"@username, display name or User ID",UDim2.fromOffset(350,126),UDim2.fromOffset(408,40)) recipient.Text="ME"
local me=button(panel,"ME",UDim2.fromOffset(768,126),UDim2.fromOffset(72,40)) me.Activated:Connect(function() recipient.Text="ME" end)
local everyone=button(panel,"ALL / LOBBY",UDim2.fromOffset(850,126),UDim2.fromOffset(126,40)) everyone.Activated:Connect(function() recipient.Text="ALL" end)
local summary=text(panel,"",UDim2.fromOffset(264,94),UDim2.fromOffset(650,20),12,Color3.fromRGB(151,169,191))
local sidebar=Instance.new("Frame") sidebar.Name="Navigation" sidebar.Size=UDim2.new(0,244,1,0) sidebar.BackgroundColor3=Color3.fromRGB(21,26,36) sidebar.BorderSizePixel=0 sidebar.ZIndex=0 sidebar.Parent=panel
text(panel,"COMMAND\nCENTER",UDim2.fromOffset(24,34),UDim2.fromOffset(204,74),26)
text(panel,"OWNER ACCESS",UDim2.fromOffset(24,116),UDim2.fromOffset(204,24),11,accent)
text(panel,"HATCH AN ANIME EGG\nCurrent server tools\n\nOpen with /owner",UDim2.fromOffset(24,542),UDim2.fromOffset(204,104),12,Color3.fromRGB(132,148,171))
local data=nil local working=false local selected=nil local tab="Spawn" local pending=nil
local modal=Instance.new("Frame") modal.Name="Confirm" modal.Size=UDim2.fromScale(1,1) modal.BackgroundColor3=Color3.fromRGB(16,19,27) modal.Visible=false modal.ZIndex=10 modal.Parent=panel round(modal,16)
local confirmText=text(modal,"Confirm action",UDim2.fromOffset(160,230),UDim2.fromOffset(680,100),20) confirmText.TextWrapped=true confirmText.ZIndex=11
local cancel=button(modal,"CANCEL",UDim2.fromOffset(160,370),UDim2.fromOffset(320,48)) cancel.ZIndex=11
local confirm=button(modal,"CONFIRM",UDim2.fromOffset(520,370),UDim2.fromOffset(320,48),accent) confirm.ZIndex=11
local function request(action,payload)
 if working then return nil end working=true status.Text="Working…"
 for _,o in body:GetDescendants() do if o:IsA("GuiButton") then o.Interactable=false end end
 local ok,result=pcall(remote.InvokeServer,remote,action,payload or {})
 working=false
 for _,o in body:GetDescendants() do if o:IsA("GuiButton") then o.Interactable=true end end
 if not ok then status.Text="Connection failed. Try again." status.TextColor3=accent return nil end
 status.Text=result.Message or "Ready." status.TextColor3=result.Ok and Color3.fromRGB(142,228,185) or accent
 return result
end
local function ask(action,target,payload)
 if target=="" then status.Text="Enter an exact username or User ID first." return end
 pending={Action=action,Target=target,Payload=payload or {}}
 confirmText.Text=action.." for "..target..(payload and payload.Amount and (" • $"..tostring(payload.Amount)) or "").."?\n"..(action=="Ban24h" and "24-hour ban across this experience." or action=="Unban" and "Remove this account's experience ban." or "Apply this action to the selected target.")
 modal.Visible=true
end
cancel.Activated:Connect(function() pending=nil modal.Visible=false end)
confirm.Activated:Connect(function()
 local action=pending pending=nil modal.Visible=false
 if action then action.Payload.Target=action.Target action.Payload.Confirmed=true request(action.Action,action.Payload) end
end)
local render
local pickPlayer=button(panel,"CHOOSE PLAYER",UDim2.fromOffset(806,66),UDim2.fromOffset(170,32)) pickPlayer.TextSize=11
local picker=Instance.new("Frame") picker.Name="PlayerPicker" picker.Position=UDim2.fromOffset(646,106) picker.Size=UDim2.fromOffset(330,310) picker.BackgroundColor3=Color3.fromRGB(22,28,39) picker.BorderSizePixel=0 picker.Visible=false picker.ZIndex=8 picker.Parent=panel round(picker,10)
local playerSearch=box(picker,"Search online players…",UDim2.fromOffset(10,10),UDim2.fromOffset(310,38)) playerSearch.Name="PlayerSearch" playerSearch.ZIndex=9
local lobbyList=Instance.new("ScrollingFrame") lobbyList.Name="OnlinePlayers" lobbyList.Position=UDim2.fromOffset(10,58) lobbyList.Size=UDim2.fromOffset(310,240) lobbyList.BackgroundTransparency=1 lobbyList.BorderSizePixel=0 lobbyList.ScrollBarThickness=3 lobbyList.ZIndex=9 lobbyList.Parent=picker
local function syncPlayers()
 if not data then data={} end data.Players={}
 local roster=Players:GetPlayers() table.sort(roster,function(a,b)return a.Name:lower()<b.Name:lower()end)
 for _,p in roster do table.insert(data.Players,{Id=p.UserId,Name=p.Name,Display=p.DisplayName}) end
end
local function refreshPicker()
 syncPlayers() lobbyList:ClearAllChildren() local y=0 local query=playerSearch.Text:lower()
 for _,p in ipairs(data.Players) do
 if (p.Name.." "..p.Display.." "..p.Id):lower():find(query,1,true) then
 local b=button(lobbyList,p.Display.."  ·  @"..p.Name,UDim2.fromOffset(0,y),UDim2.fromOffset(298,48)) b.Name="Player_"..p.Id b:SetAttribute("TargetUserId",p.Id) b.TextSize=12 b.ZIndex=10
 b.Activated:Connect(function()
 if not Players:GetPlayerByUserId(p.Id) then status.Text="That player left the lobby." refreshPicker() return end
 recipient.Text="@"..p.Name picker.Visible=false status.Text="Recipient: "..p.Display.." (@"..p.Name..")"
 if tab=="Players" then render() end
 end)
 y+=54 end end
 lobbyList.CanvasSize=UDim2.fromOffset(0,y)
 if y==0 then local empty=text(lobbyList,"No matching online players.",UDim2.fromOffset(8,12),UDim2.fromOffset(290,36),13) empty.ZIndex=10 end
end
pickPlayer.Text="ONLINE PLAYERS"
pickPlayer.Activated:Connect(function() picker.Visible=not picker.Visible if picker.Visible then refreshPicker() end end)
playerSearch:GetPropertyChangedSignal("Text"):Connect(refreshPicker)
Players.PlayerAdded:Connect(function() syncPlayers() if picker.Visible then refreshPicker() end if gui.Enabled and tab=="Players" then render() end end)
Players.PlayerRemoving:Connect(function() task.defer(function() syncPlayers() if picker.Visible then refreshPicker() end if gui.Enabled and tab=="Players" then render() end end) end)
game:GetService("UserInputService").InputBegan:Connect(function(input,processed) if not processed and input.KeyCode==Enum.KeyCode.Escape and gui.Enabled then gui.Enabled=false end end)
render=function()
 body:ClearAllChildren()
 syncPlayers()
 summary.Text=string.format("%d PLAYERS ONLINE     •     %d CATALOG ITEMS     •     %s",#(data and data.Players or {}),#(data and data.Items or {}),(workspace:GetAttribute("OwnerEventName") or "")~="" and ("EVENT: "..workspace:GetAttribute("OwnerEventName")) or "NO ACTIVE EVENT")
 if tab=="Spawn" then
  text(body,"EGGS & CHARACTERS",UDim2.fromOffset(0,0),UDim2.fromOffset(430,24),16)
  local list=Instance.new("ScrollingFrame") list.Size=UDim2.fromOffset(420,314) list.Position=UDim2.fromOffset(0,96) list.BackgroundTransparency=1 list.BorderSizePixel=0 list.ScrollBarThickness=4 list.CanvasSize=UDim2.fromOffset(0,#(data and data.Items or {})*44) list.Parent=body
  local search=box(body,"Search eggs, characters or rarity…",UDim2.fromOffset(0,36),UDim2.fromOffset(420,44)) search.Name="CatalogSearch"
 local selection=text(body,selected and ("SELECTED: "..selected) or "Select an item to begin",UDim2.fromOffset(444,330),UDim2.fromOffset(268,58),15,Color3.fromRGB(207,218,235)) selection.TextWrapped=true
 local buttons={}
  for i,item in ipairs(data and data.Items or {}) do
   local b=button(list,item.Id.."  /  "..item.Rarity..(item.EggAvailable and "" or " • Character only"),UDim2.fromOffset(0,(i-1)*44),UDim2.fromOffset(404,38))
   buttons[item.Id]=b if item.Id==selected then b.BackgroundColor3=accent end
   b.Activated:Connect(function()
    selected=item.Id selection.Text="SELECTED: "..item.Id.."\n"..item.Rarity status.Text="Selected "..item.Id.." • "..item.Rarity
    for id,v in pairs(buttons) do v.BackgroundColor3=id==selected and accent or Color3.fromRGB(38,43,55) end
   end)
  end
  search:GetPropertyChangedSignal("Text"):Connect(function()
   local y=0 local query=search.Text:lower()
   for _,item in ipairs(data and data.Items or {}) do local b=buttons[item.Id] local show=(item.Id.." "..item.Rarity):lower():find(query,1,true)~=nil b.Visible=show if show then b.Position=UDim2.fromOffset(0,y) y+=44 end end
   list.CanvasSize=UDim2.fromOffset(0,y)
  end)
  text(body,"GIVE TO SELECTED PLAYER",UDim2.fromOffset(444,0),UDim2.fromOffset(268,24),12,Color3.fromRGB(161,172,194))
  local egg=button(body,"SPAWN EGG",UDim2.fromOffset(444,40),UDim2.fromOffset(268,44),accent)
  local character=button(body,"SPAWN CHARACTER",UDim2.fromOffset(444,94),UDim2.fromOffset(268,44))
  egg.Activated:Connect(function() if selected then
 if recipient.Text:upper()=="ALL" or recipient.Text:upper()=="LOBBY" then ask("SpawnEgg","ALL",{Id=selected}) else request("SpawnEgg",{Id=selected,Target=recipient.Text}) end
 else status.Text="Select an egg from the list." end end)
  character.Activated:Connect(function() if selected then
 if recipient.Text:upper()=="ALL" or recipient.Text:upper()=="LOBBY" then ask("SpawnCharacter","ALL",{Id=selected}) else request("SpawnCharacter",{Id=selected,Target=recipient.Text}) end
 else status.Text="Select a character from the list." end end)
  local riverButton=button(body,"SPAWN ON RIVER",UDim2.fromOffset(444,147),UDim2.fromOffset(268,36))
  riverButton.Activated:Connect(function() if selected then request("SpawnRiverEgg",{Id=selected}) else status.Text="Select an egg first." end end)
  text(body,"CASH • SELECTED PLAYER",UDim2.fromOffset(444,191),UDim2.fromOffset(268,24),12,Color3.fromRGB(161,172,194))
  local amount=box(body,"Amount, e.g. 100000",UDim2.fromOffset(444,220),UDim2.fromOffset(268,40))
  local cash=button(body,"ADD CASH",UDim2.fromOffset(444,270),UDim2.fromOffset(268,40))
  cash.Activated:Connect(function() if recipient.Text:upper()=="ALL" or recipient.Text:upper()=="LOBBY" then ask("GiveCash","ALL",{Amount=amount.Text}) else request("GiveCash",{Amount=amount.Text,Target=recipient.Text}) end end)

 elseif tab=="Money" then
  text(body,"PLAYER CASH",UDim2.fromOffset(0,0),UDim2.fromOffset(712,26),18)
  text(body,"Choose the recipient above. ME means your account.",UDim2.fromOffset(0,34),UDim2.fromOffset(712,26),14,Color3.fromRGB(177,186,204))
  local amount=box(body,"Amount — e.g. 1000000",UDim2.fromOffset(0,80),UDim2.fromOffset(440,48))
  for i,value in ipairs({1000,100000,1000000,1000000000}) do
   local chip=button(body,({"1K","100K","1M","1B"})[i],UDim2.fromOffset((i-1)*112,136),UDim2.fromOffset(104,32)) chip.Activated:Connect(function() amount.Text=tostring(value) end)
  end
  local give=button(body,"GIVE MONEY",UDim2.fromOffset(0,186),UDim2.fromOffset(344,48),accent)
  local set=button(body,"SET EXACT BALANCE",UDim2.fromOffset(368,186),UDim2.fromOffset(344,48))
  give.Activated:Connect(function()
   if recipient.Text=="ALL" then ask("GiveCash","ALL",{Amount=amount.Text})
   else request("GiveCash",{Target=recipient.Text,Amount=amount.Text}) end
  end)
  set.Activated:Connect(function() ask("SetCash",recipient.Text,{Amount=amount.Text}) end)
  local all=button(body,"GIVE MONEY TO EVERYONE",UDim2.fromOffset(0,248),UDim2.fromOffset(712,48))
  all.Activated:Connect(function() ask("GiveCash","ALL",{Amount=amount.Text}) end)
  text(body,"Cash and upgrades are session-only while saving is disabled.",UDim2.fromOffset(0,324),UDim2.fromOffset(712,28),13,Color3.fromRGB(161,172,194))
 elseif tab=="Plots" then
  text(body,"PLOT & PLAYER TOOLS",UDim2.fromOffset(0,0),UDim2.fromOffset(712,26),18)
  local options={
   {"UpgradeTemple","UPGRADE TEMPLE"},{"AddChamber","ADD INCUBATOR"},
   {"UpgradeChamber","UPGRADE INCUBATOR 1",false,1},{"UpgradeChamber","UPGRADE INCUBATOR 2",false,2},
   {"UpgradeChamber","UPGRADE INCUBATOR 3",false,3},{"UnlockSlots","UNLOCK ALL SLOTS"},
   {"GoHome","SEND PLAYER HOME"},{"TeleportTo","GO TO PLAYER"},
   {"Bring","BRING PLAYER TO ME"},{"Respawn","RESPAWN PLAYER",true},
   {"ClearInventory","CLEAR HELD INVENTORY",true},{"ClearPlaced","CLEAR PLACED CHARACTERS",true},
   {"ResetSlots","RESET SLOT UNLOCKS",true}
  }
  for i,o in ipairs(options) do
   local x=((i-1)%2)*364 local y=42+math.floor((i-1)/2)*43
   local b=button(body,o[2],UDim2.fromOffset(x,y),UDim2.fromOffset(348,35))
   b.TextSize=12
   b.Activated:Connect(function()
    local payload={Target=recipient.Text,Index=o[4]}
    if o[3] then ask(o[1],recipient.Text,payload) else request(o[1],payload) end
   end)
  end

 elseif tab=="Events" then
  text(body,"TIMED SERVER EVENTS",UDim2.fromOffset(0,0),UDim2.fromOffset(500,24),16)
  local duration=box(body,"Duration in seconds (15–300)",UDim2.fromOffset(0,38),UDim2.fromOffset(420,40)) duration.Text="120"
  local interval=box(body,"River spawn interval (1.5–30s)",UDim2.fromOffset(440,38),UDim2.fromOffset(272,40))
  local apply=button(body,"SET SPAWN INTERVAL",UDim2.fromOffset(440,299),UDim2.fromOffset(272,42))
  apply.Activated:Connect(function() request("SetSpawnInterval",{Amount=interval.Text}) end)
  for i,event in ipairs({{"EggRush","EGG RUSH","Eggs appear twice as often."},{"DoubleCash","DOUBLE CASH","Placed characters earn 2× cash."},{"GoldenHour","GOLDEN HOUR","Warm sunset lighting across the map."}}) do
   local b=button(body,event[2],UDim2.fromOffset(0,96+(i-1)*65),UDim2.fromOffset(240,48),i==1 and accent or nil)
   text(body,event[3],UDim2.fromOffset(260,96+(i-1)*65),UDim2.fromOffset(452,48),14,Color3.fromRGB(177,186,204))
   b.Activated:Connect(function() request("StartEvent",{Kind=event[1],Duration=duration.Text}) end)
  end
  local stop=button(body,"STOP EVENT",UDim2.fromOffset(0,299),UDim2.fromOffset(240,42))
  stop.Activated:Connect(function() request("StopEvent") end)
 else
  text(body,"PLAYER MODERATION",UDim2.fromOffset(0,0),UDim2.fromOffset(500,24),16)
  local target=box(body,"Choose an online player above, or enter User ID",UDim2.fromOffset(0,38),UDim2.fromOffset(440,42)) target.Text=recipient.Text=="ME" and tostring(player.UserId) or recipient.Text:gsub("^@","")
  local list=Instance.new("ScrollingFrame") list.Position=UDim2.fromOffset(0,92) list.Size=UDim2.fromOffset(440,220) list.BackgroundTransparency=1 list.BorderSizePixel=0 list.ScrollBarThickness=4 list.CanvasSize=UDim2.fromOffset(0,#(data and data.Players or {})*44) list.Parent=body
  for i,p in ipairs(data and data.Players or {}) do
   local b=button(list,"@"..p.Name.."  •  "..p.Id,UDim2.fromOffset(0,(i-1)*44),UDim2.fromOffset(424,38))
   b.Activated:Connect(function() target.Text=tostring(p.Id) recipient.Text=tostring(p.Id) status.Text="Selected @"..p.Name.." ("..p.Id..")" end)
  end
  for i,a in ipairs({{"Kick","KICK FROM SERVER"},{"Ban24h","BAN FOR 24 HOURS"},{"Unban","UNBAN ACCOUNT"}}) do
   local b=button(body,a[2],UDim2.fromOffset(464,38+(i-1)*56),UDim2.fromOffset(248,44),a[1]=="Ban24h" and accent or nil)
   b.Activated:Connect(function() ask(a[1],target.Text) end)
  end
  text(body,"Bans apply across this experience.\nBans are available in the published game.\nYour owner account is protected.",UDim2.fromOffset(464,221),UDim2.fromOffset(248,80),12,Color3.fromRGB(163,174,195)).TextWrapped=true
  local refresh=button(body,"REFRESH PLAYERS",UDim2.fromOffset(0,317),UDim2.fromOffset(440,34))
  refresh.Activated:Connect(function() local r=request("Info") if r and r.Ok then data=r render() end end)
 end
end
local tabs={}
for i,name in ipairs({"Spawn","Money","Plots","Events","Players"}) do
 local b=button(panel,name:upper(),UDim2.fromOffset(24,166+(i-1)*58),UDim2.fromOffset(204,46),i==1 and accent or nil) tabs[name]=b
 b.Activated:Connect(function()
  tab=name for n,v in pairs(tabs) do v.BackgroundColor3=n==tab and accent or Color3.fromRGB(38,43,55) end render()
 end)
end
local function open()
 if gui.Enabled then gui.Enabled=false return end
 picker.Visible=false
 local r=request("Info") if not r or not r.Ok then return end data=r selected=nil
 gui.Enabled=true modal.Visible=false panel.GroupTransparency=1
 local camera=workspace.CurrentCamera local v=camera.ViewportSize scale.Scale=math.min(1,(v.X-24)/1000,(v.Y-30)/680)
 render() Tween:Create(panel,TweenInfo.new(.2),{GroupTransparency=0}):Play()
end
close.Activated:Connect(function() gui.Enabled=false end)
RS:WaitForChild("OwnerPanelOpen").OnClientEvent:Connect(open)
player.Chatted:Connect(function(message)
 if message:lower()=="/owner" and game:GetService("TextChatService").ChatVersion==Enum.ChatVersion.LegacyChatService then open() end
end)
