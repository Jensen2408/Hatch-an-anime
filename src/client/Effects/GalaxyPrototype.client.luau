-- Galaxy v5: native-UV tinted/normal base + ONE continuously drifting photographic coat.
local RS=game:GetService('ReplicatedStorage')
local Assets=game:GetService('AssetService')
local Run=game:GetService('RunService')
local player=game.Players.LocalPlayer
local templates=RS:WaitForChild('ProjectedCoatingMeshes')
local bodyTemplates=RS:WaitForChild('GalaxyPrototype'):WaitForChild('BodyProjection')
local auraTemplate=RS.GalaxyPrototype:WaitForChild('GalaxyAura',25)
local SIZE=256
local white=Assets:CreateEditableImage({Size=Vector2.one});white:DrawRectangle(Vector2.zero,Vector2.one,Color3.new(1,1,1),0,Enum.ImageCombineType.Overwrite)
local black=Assets:CreateEditableImage({Size=Vector2.one});black:DrawRectangle(Vector2.zero,Vector2.one,Color3.new(),0,Enum.ImageCombineType.Overwrite)
local originalNormal=Assets:CreateEditableImageAsync(Content.fromUri('rbxassetid://122481203141794'))
local faceImage=Assets:CreateEditableImageAsync(Content.fromUri('rbxassetid://131043949385474'))
local faceMask=Assets:CreateEditableImageAsync(Content.fromUri('rbxassetid://81291379703357'))
local faceSurface=Assets:CreateSurfaceAppearanceAsync({ColorMap=Content.fromObject(faceImage),NormalMap=Content.fromObject(originalNormal),EmissiveMask=Content.fromObject(faceMask),RoughnessMap=Content.fromObject(white),MetalnessMap=Content.fromObject(black)})
faceSurface.Name='GalaxyBase';faceSurface.EmissiveStrength=1.6
-- Preserve native cube normal-map coordinates on the base; tint follows Orion navy/violet.
local tintImage=Assets:CreateEditableImageAsync(Content.fromUri('rbxassetid://92565503187719'))
local dims=tintImage.Size;local tintPixels=tintImage:ReadPixelsBuffer(Vector2.zero,dims)
for i=0,dims.X*dims.Y-1 do
 local p=i*4;local r=buffer.readu8(tintPixels,p)/255;local g=buffer.readu8(tintPixels,p+1)/255;local b=buffer.readu8(tintPixels,p+2)/255
 local lum=r*.3+g*.5+b*.2
 buffer.writeu8(tintPixels,p,math.floor((.025+lum*.25)*255));buffer.writeu8(tintPixels,p+1,math.floor((.02+lum*.17)*255));buffer.writeu8(tintPixels,p+2,math.floor((.065+lum*.42)*255))
end
tintImage:WritePixelsBuffer(Vector2.zero,dims,tintPixels)
local tintSurface=Assets:CreateSurfaceAppearanceAsync({ColorMap=Content.fromObject(tintImage),NormalMap=Content.fromObject(originalNormal),EmissiveMask=Content.fromObject(black),RoughnessMap=Content.fromObject(white),MetalnessMap=Content.fromObject(black)})
tintSurface.Name='GalaxyBase'
local photo=Assets:CreateEditableImageAsync(Content.fromUri('rbxassetid://108700382671963'))
-- One mirrored tile is prepared once. Runtime only translates this shared image; no pixel loops.
local tile=Assets:CreateEditableImage({Size=Vector2.new(512,512)})
for _,q in {{0,0,1,1},{512,0,-1,1},{0,512,1,-1},{512,512,-1,-1}} do
 tile:DrawImageTransformed(Vector2.new(q[1],q[2]),Vector2.new(q[3]*.25,q[4]*.25),0,photo,{PivotPoint=Vector2.zero,CombineType=Enum.ImageCombineType.Overwrite,SamplingMode=Enum.ResamplerMode.Default})
end
local driftImage=Assets:CreateEditableImage({Size=Vector2.new(SIZE,SIZE)})
local coat=Assets:CreateSurfaceAppearanceAsync({ColorMap=Content.fromObject(driftImage),EmissiveMask=Content.fromObject(white),RoughnessMap=Content.fromObject(white),MetalnessMap=Content.fromObject(black)})
coat.Name='GalaxyDrift';coat.EmissiveStrength=1.15
local zoom=1.25 -- 25% larger visual features than the previous body mapping.
local tileSize=512*zoom
local function drift(t)
 local dx=(t*13)%tileSize;local dy=(t*5)%tileSize
 for y=0,1 do for x=0,1 do
  driftImage:DrawImageTransformed(Vector2.new(-dx+x*tileSize,-dy+y*tileSize),Vector2.new(zoom,zoom),0,tile,{PivotPoint=Vector2.zero,CombineType=Enum.ImageCombineType.Overwrite,SamplingMode=Enum.ResamplerMode.Default})
 end end
end
drift(0)
local active,pending={},{}
local function remove(m)
 local rec=active[m];if not rec then return end
 rec.folder:Destroy()
 for _,r in rec.parts do
  if r.source.Parent then local s=r.source:FindFirstChild('GalaxyBase');if s then s:Destroy() end;if r.original then r.original.Parent=r.source end
  elseif r.original then r.original:Destroy() end
 end
 active[m]=nil
end
local function build(m)
 if active[m] or pending[m] then return end;pending[m]=true
 local folder=Instance.new('Folder');folder.Name='GalaxyLayersLocal';local records={}
 for _,p in m:GetDescendants() do
  if not p:IsA('MeshPart') or p.Transparency>=1 then continue end
  local partIndex=tonumber(p.Name:match('Part (%d+)$'))
  local projected=(partIndex and partIndex<=5 and bodyTemplates:FindFirstChild(p.Name,true)) or templates:FindFirstChild(p.Name);if not projected then continue end
  local original=p:FindFirstChildOfClass('SurfaceAppearance');if original then original.Parent=nil end
  local index=tonumber(p.Name:match('Part (%d+)$'));local head=index and index>=6
  local base=head and faceSurface or tintSurface;base:Clone().Parent=p
  local shell=p:Clone()
  for _,d in shell:GetDescendants() do if not d:IsA('Bone') and not d:FindFirstAncestorWhichIsA('Bone') then d:Destroy() end end
  shell:ApplyMesh(projected);shell.Size=p.Size*(projected.MeshSize/p.MeshSize)
  shell.Name='GalaxyMovingLayer';shell.Material=Enum.Material.SmoothPlastic;shell.Color=Color3.new(1,1,1);shell.TextureID=''
  shell.Anchored=true;shell.CanCollide=false;shell.CanQuery=false;shell.CanTouch=false;shell.CastShadow=false
  local opacity=head and .68 or .46;shell.Transparency=opacity;coat:Clone().Parent=shell
  local rec={source=p,shell=shell,original=original,opacity=opacity,bones={}}
  for _,b in p:GetDescendants() do if b:IsA('Bone') then
   local path={};local parent=b;while parent~=p do table.insert(path,1,parent.Name);parent=parent.Parent end
   local target=shell;for _,name in path do target=target and target:FindFirstChild(name) end
   if target then table.insert(rec.bones,{b,target}) end
  end end
  shell.CFrame=p.CFrame;shell.Parent=folder;table.insert(records,rec)
 end
 pending[m]=nil
 if #records==0 then folder:Destroy();return end
 local aura,offset
 if auraTemplate then aura=auraTemplate:Clone();aura.Name='GalaxyAuraLocal';local box=m:GetBoundingBox();offset=m:GetPivot():ToObjectSpace(box);aura.CFrame=box;aura.Parent=folder end
 folder.Parent=workspace;active[m]={folder=folder,parts=records,aura=aura,auraOffset=offset}
end
local credit=Instance.new('ScreenGui');credit.Name='GalaxyReferenceCredit';credit.ResetOnSpawn=false
local label=Instance.new('TextLabel');label.BackgroundTransparency=.3;label.BackgroundColor3=Color3.fromRGB(10,8,25);label.TextColor3=Color3.new(1,1,1)
label.Text='Galaxy texture: ESO/H. Drass et al. | CC BY 4.0 | adapted, layered and animated';label.TextSize=12;label.TextWrapped=true
label.AnchorPoint=Vector2.new(.5,1);label.Position=UDim2.fromScale(.5,.99);label.Size=UDim2.new(.75,0,0,32);label.Parent=credit;credit.Enabled=false;credit.Parent=player:WaitForChild('PlayerGui')
local nextScan,nextImage=0,0
local connection=Run.RenderStepped:Connect(function()
 local t=os.clock()
 if t>=nextScan then nextScan=t+1
  local near={};local cam=workspace.CurrentCamera
  if cam then for _,m in workspace:GetDescendants() do
   if m:IsA('Model') and not m:IsA('Tool') and m:GetAttribute('GalaxyPrototype')==true then
    local distance=(m:GetPivot().Position-cam.CFrame.Position).Magnitude
    if distance<100 then table.insert(near,{model=m,distance=distance}) end
   end
  end end
  table.sort(near,function(a,b)return a.distance<b.distance end)
  local keep={};for i=1,math.min(2,#near) do local m=near[i].model;keep[m]=true;build(m) end
  for m in active do if not keep[m] then remove(m) end end;credit.Enabled=next(active)~=nil
 end
 if next(active) and t>=nextImage then nextImage=t+1/20;drift(t) end
 for m,rec in active do
  if not m:IsDescendantOf(workspace) then remove(m);continue end
  if rec.aura then rec.aura.CFrame=m:GetPivot()*rec.auraOffset end
  for _,r in rec.parts do if r.source.Parent then
   r.shell.CFrame=r.source.CFrame;r.shell.LocalTransparencyModifier=r.source.LocalTransparencyModifier;r.shell.Transparency=r.source.Transparency>=1 and 1 or r.opacity
   for _,pair in r.bones do if pair[1].Parent and pair[2].Parent then pair[2].Transform=pair[1].Transform end end
  end end
 end
end)
script.Destroying:Connect(function()
 connection:Disconnect();for m in active do remove(m) end;credit:Destroy()
 for _,v in {white,black,originalNormal,faceImage,faceMask,faceSurface,tintImage,tintSurface,photo,tile,driftImage,coat} do v:Destroy() end
end)
