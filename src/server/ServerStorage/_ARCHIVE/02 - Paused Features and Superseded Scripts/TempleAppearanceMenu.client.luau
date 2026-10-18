local player=game.Players.LocalPlayer
local remote=game.ReplicatedStorage:WaitForChild("TempleAppearanceRequest")
local themes=require(game.ReplicatedStorage:WaitForChild("TempleAppearanceThemes"))
local gui=Instance.new("ScreenGui") gui.Name="TempleFinishMenu" gui.ResetOnSpawn=false gui.Enabled=false gui.Parent=player:WaitForChild("PlayerGui")
local overlay=Instance.new("Frame") overlay.Size=UDim2.fromScale(1,1) overlay.BackgroundColor3=Color3.new(0,0,0) overlay.BackgroundTransparency=.4 overlay.Parent=gui
local panel=Instance.new("Frame") panel.AnchorPoint=Vector2.new(.5,.5) panel.Position=UDim2.fromScale(.5,.5) panel.Size=UDim2.fromScale(.85,.65) panel.BackgroundColor3=Color3.fromRGB(29,31,40) panel.Parent=overlay
local limit=Instance.new("UISizeConstraint") limit.MaxSize=Vector2.new(620,460) limit.MinSize=Vector2.new(280,280) limit.Parent=panel
local corner=Instance.new("UICorner") corner.CornerRadius=UDim.new(0,16) corner.Parent=panel
local stroke=Instance.new("UIStroke") stroke.Color=Color3.fromRGB(170,137,83) stroke.Thickness=2 stroke.Parent=panel
local function label(text,pos,size)
 local t=Instance.new("TextLabel") t.Text=text t.Position=pos t.Size=size t.BackgroundTransparency=1 t.Font=Enum.Font.GothamBold t.TextColor3=Color3.fromRGB(238,225,203) t.TextScaled=true t.Parent=panel return t
end
label("TEMPLE FINISH",UDim2.fromScale(.06,.05),UDim2.fromScale(.75,.09))
local subtitle=label("Choose a color • rebuilding is free",UDim2.fromScale(.06,.15),UDim2.fromScale(.88,.055))
local close=Instance.new("TextButton") close.Text="×" close.Font=Enum.Font.GothamBold close.TextScaled=true close.Size=UDim2.fromScale(.08,.09) close.Position=UDim2.fromScale(.86,.05) close.BackgroundTransparency=1 close.TextColor3=Color3.fromRGB(238,225,203) close.Parent=panel close.Activated:Connect(function()gui.Enabled=false end)
local selected="Original" local building=false local buttons={}
local function refresh()
 for id,b in pairs(buttons) do b.Text=(id==selected and "✓  " or "")..b:GetAttribute("Title") b.BackgroundColor3=id==selected and Color3.fromRGB(81,68,49) or Color3.fromRGB(44,47,58) b.Active=not building end
end
for i,t in ipairs(themes) do
 local b=Instance.new("TextButton") b.Name=t.Id b:SetAttribute("Title",t.Name) b.Font=Enum.Font.GothamBold b.TextSize=18 b.TextColor3=Color3.fromRGB(240,230,211) b.TextXAlignment=Enum.TextXAlignment.Left b.Size=UDim2.fromScale(.88,.095) b.Position=UDim2.fromScale(.06,.25+(i-1)*.105) b.AutoButtonColor=true b.Parent=panel
 local pad=Instance.new("UIPadding") pad.PaddingLeft=UDim.new(0,48) pad.Parent=b
 local round=Instance.new("UICorner") round.CornerRadius=UDim.new(0,8) round.Parent=b
 local swatch=Instance.new("Frame") swatch.Size=UDim2.new(0,24,0,24) swatch.AnchorPoint=Vector2.new(0,.5) swatch.Position=UDim2.new(0,-36,.5,0) swatch.BackgroundColor3=t.Tint swatch.BorderSizePixel=0 swatch.Parent=b
 local cr=Instance.new("UICorner") cr.CornerRadius=UDim.new(0,6) cr.Parent=swatch
 buttons[t.Id]=b
 b.Activated:Connect(function()
  if building or t.Id==selected then return end
  building=true subtitle.Text="Rebuilding your temple…" refresh()
  remote:FireServer("Apply",t.Id)
  task.delay(8,function()if building then building=false subtitle.Text="Move near your finish sign to choose a color" refresh()end end)
 end)
end
remote.OnClientEvent:Connect(function(action,id)
 if action=="Open" then selected=id building=false gui.Enabled=true subtitle.Text="Choose a color • rebuilding is free"
 elseif action=="Building" then building=true selected=id subtitle.Text="Rising from the ground…" gui.Enabled=false
 elseif action=="Done" then selected=id building=false subtitle.Text="Finish applied • upgrades keep this color" end
 refresh()
end)
player.CharacterAdded:Connect(function()gui.Enabled=false building=false end)
