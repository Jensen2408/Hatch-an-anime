
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
 local b=Instance.new("TextButton") b.Position=pos b.Size=size b.Text=str b.TextColor3=Color3.fromRGB(245,245,250) b.BackgroundColor3=color or Color3.fromRGB(38,43,55) b.Font=Enum.Font.GothamBold b.TextSize=14 b.AutoButtonColor=true b.Parent=parent round(b) return b
end
local function box(parent,hint,pos,size)
 local b=Instance.new("TextBox") b.Position=pos b.Size=size b.PlaceholderText=hint b.Text="" b.ClearTextOnFocus=false b.Font=Enum.Font.Gotham b.TextSize=14 b.TextColor3=Color3.new(1,1,1) b.PlaceholderColor3=Color3.fromRGB(150,157,176) b.BackgroundColor3=Color3.fromRGB(27,31,41) b.Parent=parent round(b) return b
end
local shade=Instance.new("Frame") shade.Size=UDim2.fromScale(1,1) shade.BackgroundColor3=Color3.new() shade.BackgroundTransparency=.35 shade.Parent=gui
local panel=Instance.new("CanvasGroup") panel.Name="Panel" panel.BackgroundTransparency=0 panel.AnchorPoint=Vector2.new(.5,.5) panel.Position=UDim2.fromScale(.5,.5) panel.Size=UDim2.fromOffset(760,530) panel.BackgroundColor3=Color3.fromRGB(16,19,27) panel.Parent=shade round(panel,16)
local scale=Instance.new("UIScale",panel)
local stroke=Instance.new("UIStroke",panel) stroke.Color=Color3.fromRGB(74,47,59) stroke.Thickness=1.5
local strip=Instance.new("Frame") strip.Size=UDim2.new(1,-32,0,3) strip.Position=UDim2.fromOffset(16,0) strip.BackgroundColor3=accent strip.BorderSizePixel=0 strip.Parent=panel
text(panel,"OWNER CONTROL",UDim2.fromOffset(24,18),UDim2.fromOffset(480,30),23)
text(panel,"PRIVATE ACCESS   /   CURRENT SERVER",UDim2.fromOffset(25,51),UDim2.fromOffset(600,24),11,Color3.fromRGB(154,164,188))
local close=button(panel,"×",UDim2.new(1,-58,0,20),UDim2.fromOffset(34,34))
local status=text(panel,"Ready. Type /owner in chat to open this panel.",UDim2.fromOffset(24,488),UDim2.fromOffset(712,28),13,Color3.fromRGB(174,186,207))
local body=Instance.new("Frame") body.Position=UDim2.fromOffset(24,124) body.Size=UDim2.fromOffset(712,352) body.BackgroundTransparency=1 body.Parent=panel
local data=nil local working=false local selected=nil local tab="Spawn" local pending=nil
local modal=Instance.new("Frame") modal.Name="Confirm" modal.Size=UDim2.fromScale(1,1) modal.BackgroundColor3=Color3.fromRGB(16,19,27) modal.Visible=false modal.ZIndex=10 modal.Parent=panel round(modal,16)
local confirmText=text(modal,"Confirm action",UDim2.fromOffset(60,165),UDim2.fromOffset(640,100),20) confirmText.TextWrapped=true confirmText.ZIndex=11
local cancel=button(modal,"CANCEL",UDim2.fromOffset(60,300),UDim2.fromOffset(300,44)) cancel.ZIndex=11
local confirm=button(modal,"CONFIRM",UDim2.fromOffset(390,300),UDim2.fromOffset(300,44),accent) confirm.ZIndex=11
local function request(action,payload)
 if working then return nil end working=true status.Text="Working…"
 local ok,result=pcall(remote.InvokeServer,remote,action,payload or {})
 working=false
 if not ok then status.Text="Connection failed. Try again." status.TextColor3=accent return nil end
 status.Text=result.Message or "Ready." status.TextColor3=result.Ok and Color3.fromRGB(142,228,185) or accent
 return result
end
local function ask(action,target)
 if target=="" then status.Text="Enter an exact username or User ID first." return end
 pending={Action=action,Target=target}
 confirmText.Text=action.." for "..target.."?\n"..(action=="Ban24h" and "24-hour ban across this experience." or action=="Unban" and "Remove this account's experience ban." or "Remove this player from the current server.")
 modal.Visible=true
end
cancel.Activated:Connect(function() pending=nil modal.Visible=false end)
confirm.Activated:Connect(function()
 local action=pending pending=nil modal.Visible=false
 if action then request(action.Action,{Target=action.Target,Confirmed=true}) end
end)
local render
render=function()
 body:ClearAllChildren()
 if tab=="Spawn" then
  text(body,"EGGS & CHARACTERS",UDim2.fromOffset(0,0),UDim2.fromOffset(430,24),16)
  local list=Instance.new("ScrollingFrame") list.Size=UDim2.fromOffset(420,306) list.Position=UDim2.fromOffset(0,36) list.BackgroundTransparency=1 list.BorderSizePixel=0 list.ScrollBarThickness=4 list.CanvasSize=UDim2.fromOffset(0,#(data and data.Items or {})*44) list.Parent=body
  local buttons={}
  for i,item in ipairs(data and data.Items or {}) do
   local b=button(list,item.Id.."  /  "..item.Rarity,UDim2.fromOffset(0,(i-1)*44),UDim2.fromOffset(404,38))
   buttons[item.Id]=b
   b.Activated:Connect(function()
    selected=item.Id
    for id,v in pairs(buttons) do v.BackgroundColor3=id==selected and accent or Color3.fromRGB(38,43,55) end
   end)
  end
  text(body,"ADD TO YOUR BACKPACK",UDim2.fromOffset(444,0),UDim2.fromOffset(268,24),12,Color3.fromRGB(161,172,194))
  local egg=button(body,"SPAWN EGG",UDim2.fromOffset(444,40),UDim2.fromOffset(268,44),accent)
  local character=button(body,"SPAWN CHARACTER",UDim2.fromOffset(444,94),UDim2.fromOffset(268,44))
  egg.Activated:Connect(function() if selected then request("SpawnEgg",{Id=selected}) else status.Text="Select an egg from the list." end end)
  character.Activated:Connect(function() if selected then request("SpawnCharacter",{Id=selected}) else status.Text="Select a character from the list." end end)
  text(body,"TEST CASH • YOUR ACCOUNT",UDim2.fromOffset(444,177),UDim2.fromOffset(268,24),12,Color3.fromRGB(161,172,194))
  local amount=box(body,"Amount, e.g. 100000",UDim2.fromOffset(444,209),UDim2.fromOffset(268,40))
  local cash=button(body,"ADD CASH",UDim2.fromOffset(444,259),UDim2.fromOffset(268,40))
  cash.Activated:Connect(function() request("GiveCash",{Amount=amount.Text}) end)
 elseif tab=="Events" then
  text(body,"TIMED SERVER EVENTS",UDim2.fromOffset(0,0),UDim2.fromOffset(500,24),16)
  local duration=box(body,"Duration in seconds (15–300)",UDim2.fromOffset(0,38),UDim2.fromOffset(420,40)) duration.Text="120"
  for i,event in ipairs({{"EggRush","EGG RUSH","Eggs appear twice as often."},{"DoubleCash","DOUBLE CASH","Placed characters earn 2× cash."},{"GoldenHour","GOLDEN HOUR","Warm sunset lighting across the map."}}) do
   local b=button(body,event[2],UDim2.fromOffset(0,96+(i-1)*65),UDim2.fromOffset(240,48),i==1 and accent or nil)
   text(body,event[3],UDim2.fromOffset(260,96+(i-1)*65),UDim2.fromOffset(452,48),14,Color3.fromRGB(177,186,204))
   b.Activated:Connect(function() request("StartEvent",{Kind=event[1],Duration=duration.Text}) end)
  end
  local stop=button(body,"STOP EVENT",UDim2.fromOffset(0,299),UDim2.fromOffset(240,42))
  stop.Activated:Connect(function() request("StopEvent") end)
 else
  text(body,"PLAYER MODERATION",UDim2.fromOffset(0,0),UDim2.fromOffset(500,24),16)
  local target=box(body,"Exact username or numeric User ID",UDim2.fromOffset(0,38),UDim2.fromOffset(440,42))
  local list=Instance.new("ScrollingFrame") list.Position=UDim2.fromOffset(0,92) list.Size=UDim2.fromOffset(440,220) list.BackgroundTransparency=1 list.BorderSizePixel=0 list.ScrollBarThickness=4 list.CanvasSize=UDim2.fromOffset(0,#(data and data.Players or {})*44) list.Parent=body
  for i,p in ipairs(data and data.Players or {}) do
   local b=button(list,"@"..p.Name.."  •  "..p.Id,UDim2.fromOffset(0,(i-1)*44),UDim2.fromOffset(424,38))
   b.Activated:Connect(function() target.Text=tostring(p.Id) status.Text="Selected @"..p.Name.." ("..p.Id..")" end)
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
for i,name in ipairs({"Spawn","Events","Players"}) do
 local b=button(panel,name:upper(),UDim2.fromOffset(24+(i-1)*240,84),UDim2.fromOffset(232,30),i==1 and accent or nil) tabs[name]=b
 b.Activated:Connect(function()
  tab=name for n,v in pairs(tabs) do v.BackgroundColor3=n==tab and accent or Color3.fromRGB(38,43,55) end render()
 end)
end
local function open()
 if gui.Enabled then gui.Enabled=false return end
 local r=request("Info") if not r or not r.Ok then return end data=r selected=nil
 gui.Enabled=true modal.Visible=false panel.GroupTransparency=1
 local camera=workspace.CurrentCamera local v=camera.ViewportSize scale.Scale=math.min(1,(v.X-24)/760,(v.Y-30)/530)
 render() Tween:Create(panel,TweenInfo.new(.2),{GroupTransparency=0}):Play()
end
close.Activated:Connect(function() gui.Enabled=false end)
RS:WaitForChild("OwnerPanelOpen").OnClientEvent:Connect(open)
player.Chatted:Connect(function(message)
 if message:lower()=="/owner" and game:GetService("TextChatService").ChatVersion==Enum.ChatVersion.LegacyChatService then open() end
end)
