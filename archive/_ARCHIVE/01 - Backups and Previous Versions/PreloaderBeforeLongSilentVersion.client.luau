
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "AnimeEggPreloader"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 10000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local root = Instance.new("CanvasGroup")
root.Name = "BlackScreen"
root.Size = UDim2.fromScale(1,1)
root.BackgroundColor3 = Color3.new(0,0,0)
root.BorderSizePixel = 0
root.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()
local started = os.clock()
local finished = false
local connections = {}
local tiles = {}
local function text(parent, name, content, size, color)
 local t = Instance.new("TextLabel")
 t.Name=name;t.BackgroundTransparency=1;t.Text=content
 t.Font=Enum.Font.GothamBold;t.TextSize=size;t.TextColor3=color
 t.Parent=parent
 return t
end
local art = Instance.new("Frame")
art.Name="StudTitle";art.AnchorPoint=Vector2.new(.5,.5)
art.Position=UDim2.fromScale(.5,.45);art.Size=UDim2.fromOffset(650,315)
art.BackgroundTransparency=1;art.Parent=root
local scale=Instance.new("UIScale");scale.Parent=art
local patterns={
 H={"10001","10001","10001","11111","10001","10001","10001"},
 A={"01110","10001","10001","11111","10001","10001","10001"},
 T={"11111","00100","00100","00100","00100","00100","00100"},
 C={"01111","10000","10000","10000","10000","10000","01111"},
 N={"10001","11001","11001","10101","10011","10011","10001"},
 I={"11111","00100","00100","00100","00100","00100","11111"},
 M={"10001","11011","10101","10101","10001","10001","10001"},
 E={"11111","10000","10000","11110","10000","10000","11111"},
 G={"01111","10000","10000","10111","10001","10001","01110"},
}
local amber=Color3.fromRGB(255,188,61)
local coral=Color3.fromRGB(255,87,115)
local cyan=Color3.fromRGB(67,213,245)
local violet=Color3.fromRGB(176,125,255)
local function line(words,y,unit)
 local length=0
 for i,w in words do length+=#w[1]*6-1;if i<#words then length+=4 end end
 local x=(650-length*unit)/2
 for _,w in words do
  for char in w[1]:gmatch(".") do
   local glyph=patterns[char]
   for row,bits in glyph do for col=1,5 do if bits:sub(col,col)=="1" then
    local tile=Instance.new("Frame")
    tile.Name="Stud";tile.BorderSizePixel=0
    tile.BackgroundColor3=w[2]:Lerp(Color3.new(0,0,0),.5)
    tile.Position=UDim2.fromOffset(x+(col-1)*unit,y+(row-1)*unit)
    tile.Size=UDim2.fromOffset(unit-1,unit-1);tile.Parent=art
    local face=Instance.new("Frame")
    face.Name="Face";face.BorderSizePixel=0;face.BackgroundColor3=w[2]
    face.Position=UDim2.fromOffset(1,1);face.Size=UDim2.new(1,-2,1,-3);face.Parent=tile
    local bevel=Instance.new("UIGradient")
    bevel.Rotation=90
    bevel.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(135,135,135))
    bevel.Parent=face
    local stud=Instance.new("Frame")
    stud.Name="InsetStud";stud.Size=UDim2.fromScale(.48,.48);stud.Position=UDim2.fromScale(.26,.22)
    stud.BackgroundColor3=w[2]:Lerp(Color3.new(0,0,0),.12);stud.BorderSizePixel=0;stud.Parent=face
    local edge=Instance.new("UIStroke");edge.Thickness=1;edge.Color=w[2]:Lerp(Color3.new(1,1,1),.48);edge.Transparency=.35;edge.Parent=stud
    table.insert(tiles,{face=face,stud=stud,edge=edge,color=w[2],x=x+(col-1)*unit,y=y+(row-1)*unit})
   end end end
   x+=6*unit
  end
  x+=3*unit
 end
end
line({{"HATCH",amber}},0,13)
line({{"AN",coral},{"ANIME",cyan}},112,11)
line({{"EGG",violet}},218,12)
local subtitle=text(root,"Subtitle","YOUR NEXT ADVENTURE IS ABOUT TO HATCH",12,Color3.fromRGB(140,145,156))
subtitle.AnchorPoint=Vector2.new(.5,0);subtitle.Position=UDim2.fromScale(.5,.70);subtitle.Size=UDim2.new(.85,0,0,25)
local status=text(root,"LoadingStatus","PREPARING YOUR WORLD",12,Color3.fromRGB(181,190,206))
status.AnchorPoint=Vector2.new(.5,0);status.Position=UDim2.fromScale(.5,.78);status.Size=UDim2.new(.8,0,0,24)
local track=Instance.new("Frame");track.Name="ProgressTrack";track.AnchorPoint=Vector2.new(.5,0)
track.Position=UDim2.fromScale(.5,.83);track.Size=UDim2.new(.36,0,0,4);track.BorderSizePixel=0;track.BackgroundColor3=Color3.fromRGB(24,27,34);track.Parent=root
local fill=Instance.new("Frame");fill.Name="Progress";fill.Size=UDim2.fromScale(0,1);fill.BackgroundColor3=Color3.new(1,1,1);fill.BorderSizePixel=0;fill.Parent=track
local gradient=Instance.new("UIGradient");gradient.Color=ColorSequence.new(cyan,violet);gradient.Parent=fill
local skip=Instance.new("TextButton");skip.Name="Skip";skip.AnchorPoint=Vector2.new(1,1)
skip.Position=UDim2.new(1,-28,1,-30);skip.Size=UDim2.fromOffset(126,44)
skip.BackgroundColor3=Color3.fromRGB(15,18,24);skip.Text="SKIP  ›";skip.Font=Enum.Font.GothamBold;skip.TextSize=14;skip.TextColor3=Color3.fromRGB(221,231,246)
skip.AutoButtonColor=true;skip.Parent=root
local border=Instance.new("UIStroke");border.Color=Color3.fromRGB(80,97,119);border.Thickness=1;border.Parent=skip
local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,6);corner.Parent=skip
local function close(reason)
 if finished then return end
 finished=true;skip.Active=false
 gui:SetAttribute("FinishReason",reason)
 for _,c in connections do c:Disconnect() end
 local fade=TweenService:Create(root,TweenInfo.new(.55,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{GroupTransparency=1})
 fade:Play()
 task.delay(.6,function() gui:Destroy() end)
end
table.insert(connections,skip.Activated:Connect(function() close("Skipped") end))
local acc=0
table.insert(connections,RunService.RenderStepped:Connect(function(dt)
 acc+=dt;if acc<1/24 then return end;acc=0
 local camera=workspace.CurrentCamera
 if camera then scale.Scale=math.min(1,(camera.ViewportSize.X-36)/650,camera.ViewportSize.Y/700) end
 local elapsed=os.clock()-started
 local sweep=(elapsed%3.6)/1.1
 local band=-130+sweep*900
 for _,t in tiles do
  local shine=math.max(0,1-math.abs(t.x+t.y*.5-band)/42)
  t.face.BackgroundColor3=t.color:Lerp(Color3.new(1,1,1),shine*.85)
  t.stud.BackgroundColor3=t.color:Lerp(Color3.new(0,0,0),.12):Lerp(Color3.new(1,1,1),shine*.8)
  t.edge.Transparency=.35-shine*.3
 end
end))
task.delay(20,function() close("Timeout") end)
task.spawn(function()
 while not game:IsLoaded() and not finished do task.wait(.1) end
 if finished then return end
 local ids,seen={},{}
 local function add(id)
  if type(id)=="string" and id~="" and not seen[id] and #ids<400 then seen[id]=true;table.insert(ids,id) end
 end
 for _,container in {workspace,game.ReplicatedStorage} do
  for _,o in container:GetDescendants() do
   if o:IsA("MeshPart") then add(o.MeshId);add(o.TextureID)
   elseif o:IsA("Decal") or o:IsA("Texture") then add(o.Texture)
   elseif o:IsA("ImageLabel") or o:IsA("ImageButton") then add(o.Image)
   elseif o:IsA("SurfaceAppearance") then
    for _,property in {"ColorMap","NormalMap","RoughnessMap","MetalnessMap"} do
     local ok,value=pcall(function() return o[property] end);if ok then add(value) end
    end
   end
  end
 end
 local done=0
 for first=1,#ids,20 do
  if finished then return end
  local batch={} for i=first,math.min(first+19,#ids) do table.insert(batch,ids[i]) end
  pcall(function() ContentProvider:PreloadAsync(batch) end)
  done+=#batch
  local progress=done/math.max(1,#ids)
  TweenService:Create(fill,TweenInfo.new(.2),{Size=UDim2.fromScale(progress,1)}):Play()
  status.Text=string.format("LOADING YOUR WORLD  •  %d%%",math.floor(progress*100))
 end
 fill.Size=UDim2.fromScale(1,1);status.Text="READY TO HATCH"
 while os.clock()-started<3 and not finished do task.wait(.1) end
 if not finished then task.wait(.35);close("Loaded") end
end)
