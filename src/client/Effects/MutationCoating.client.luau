local Assets=game:GetService("AssetService")
local Run=game:GetService("RunService")
local textures={Silver="rbxassetid://96228988315926",Gold="rbxassetid://110840054513785",Diamond="rbxassetid://70482436642739",Rainbow="rbxassetid://70614355485441",Molten=true}
local opacity={Silver=.28,Gold=.5,Diamond=.58,Rainbow=.48,Molten=.20}
-- Ash (Molten) head fade: shells above HEAD_FRAC of the model height use HEAD_ALPHA transparency (1 = no coating).
local HEAD_FRAC,HEAD_ALPHA=.55,.88
-- Tiers that get a projected layer. Gold and Silver have their pattern baked into the character texture
-- (MutationFinish/bake_metal_atlas.js), so they get no layer.
local coated={Rainbow=true,Molten=true,Diamond=true}
local active,pending={},{}
local moltenSurface
-- Style "LiquidMetal": seamless wave textures + closed meshes (smoothed-normal offset, no cracks at cube edges).
-- Rainbow keeps the original projected meshes ("ProjectedRainbow").
local STYLE="LiquidMetal"
local templates=game.ReplicatedStorage:WaitForChild("ProjectedCoatingMeshes")
local closedTemplates=game.ReplicatedStorage:WaitForChild("ClosedCoatingMeshes")
local finishes=game.ReplicatedStorage:WaitForChild("MutationSurfaceFinishes")
local image=Assets:CreateEditableImage({Size=Vector2.new(64,64)})
local pixels=buffer.create(16384)
local white=Assets:CreateEditableImage({Size=Vector2.one})
local black=Assets:CreateEditableImage({Size=Vector2.one})
white:DrawRectangle(Vector2.zero,Vector2.one,Color3.new(1,1,1),0,Enum.ImageCombineType.Overwrite)
black:DrawRectangle(Vector2.zero,Vector2.one,Color3.new(0,0,0),0,Enum.ImageCombineType.Overwrite)
local rainbowSurface=Assets:CreateSurfaceAppearanceAsync({
 ColorMap=Content.fromObject(image),EmissiveMask=Content.fromObject(white),
 RoughnessMap=Content.fromObject(white),MetalnessMap=Content.fromObject(black)
})
rainbowSurface.Name="Rainbow" rainbowSurface.EmissiveStrength=.85
local function remove(m)
 local s=active[m] if not s then return end
 s.folder:Destroy() for _,p in s.parts do if p.mesh then p.mesh:Destroy() end end active[m]=nil
end
local function build(m)
 if active[m] or pending[m] then return end pending[m]=true
 local s={folder=Instance.new("Folder"),parts={},tier=m:GetAttribute("Mutation")}
 s.folder.Name="MutationCoating"
 local home=m:GetPivot() local bbox,size=m:GetBoundingBox() local tile=math.max(size.Y*.65,1)
 local headY=bbox.Position.Y-size.Y/2+size.Y*HEAD_FRAC
 local ok,err=pcall(function()
 local finish
 if s.tier == "Molten" then
     moltenSurface = moltenSurface or require(script.MoltenSurface)
     finish = moltenSurface.Surface
 else
     finish = s.tier == "Rainbow" and rainbowSurface or finishes:WaitForChild(s.tier)
 end
 for _,part in m:GetDescendants() do
 if not part:IsA("MeshPart") or part.Transparency>=1 then continue end
 local template=(s.tier=="Rainbow" and templates or closedTemplates):FindFirstChild(part.Name)
 if not template then continue end
 local rec={source=part,bones={},alpha=opacity[s.tier]} table.insert(s.parts,rec)
 -- Molten/Ash: fade the coating on the head so the face reads through the crust.
 if s.tier=="Molten" and part.Position.Y>headY then rec.alpha=HEAD_ALPHA end
 local shell=part:Clone()
 for _,d in shell:GetDescendants() do if not d:IsA("Bone") and not d:FindFirstAncestorWhichIsA("Bone") then d:Destroy() end end
 -- The projected mesh has a baked normal offset. Preserve that offset at the source mesh's scale.
 -- An exact native-mesh clone shares the base surface's depth and flickers as the rig moves.
 shell:ApplyMesh(template)
 shell.Size=part.Size*(template.MeshSize/part.MeshSize)
 shell.CFrame=part.CFrame shell.Name="ProjectedCoating"
 shell:SetAttribute("CoatingStyle",s.tier=="Rainbow" and "ProjectedRainbow" or s.tier=="Molten" and "Ash" or STYLE)
 shell.Material=Enum.Material.SmoothPlastic shell.Reflectance=0 shell.Color=Color3.new(1,1,1)
 shell.TextureID=""
 local surface=finish:Clone()
 surface.Parent=shell rec.surface=surface
 shell.Anchored=true shell.CanCollide=false shell.CanQuery=false shell.CanTouch=false shell.CastShadow=false
 shell.Transparency=rec.alpha rec.shell=shell
 for _,b in part:GetDescendants() do if b:IsA("Bone") then
 local path={} local p=b while p~=part do table.insert(path,1,p.Name) p=p.Parent end
 local target=shell for _,name in path do target=target and target:FindFirstChild(name) end
 if target then table.insert(rec.bones,{b,target}) end
 end end shell.Parent=s.folder
 end end)
 pending[m]=nil
 if not ok or not m:IsDescendantOf(workspace) then
 s.folder:Destroy() for _,p in s.parts do if p.mesh then p.mesh:Destroy() end end
 if not ok then warn("[MutationCoating] "..tostring(err)) end return end
 active[m]=s s.folder.Parent=workspace
end
task.spawn(function()
 while task.wait(1) do
 local cam=workspace.CurrentCamera if not cam then continue end
 local near={}
 for _,m in workspace:GetDescendants() do if m:IsA("Model") and not m:IsA("Tool") and coated[m:GetAttribute("Mutation")] then
 local distance=(m:GetPivot().Position-cam.CFrame.Position).Magnitude
 if distance<100 then table.insert(near,{m,distance}) end end end
 table.sort(near,function(a,b) return a[2]<b[2] end)
 local keep={}
 for i=1,math.min(6,#near) do keep[near[i][1]]=true task.spawn(build,near[i][1]) end
 for m in active do if not keep[m] then remove(m) end end
 end
end)
local nextImage=0
Run.RenderStepped:Connect(function()
 local now=os.clock()
 if image and now>=nextImage then nextImage=now+.05
 for y=0,63 do for x=0,63 do
 local c=Color3.fromHSV(((x+y)/64-now*.36)%1,.75,1) local p=(y*64+x)*4
 buffer.writeu8(pixels,p,math.floor(c.R*255)) buffer.writeu8(pixels,p+1,math.floor(c.G*255))
 buffer.writeu8(pixels,p+2,math.floor(c.B*255)) buffer.writeu8(pixels,p+3,255)
 end end image:WritePixelsBuffer(Vector2.zero,Vector2.new(64,64),pixels) end
 local hasMolten = false
 for _, state in active do
     if state.tier == "Molten" and #state.parts > 0 then
         hasMolten = true
         break
     end
 end
 local glow=hasMolten and moltenSurface and moltenSurface.Update(now)
 for m,s in active do
 if not m:IsDescendantOf(workspace) then remove(m) continue end
 for _,p in s.parts do if p.shell and p.source.Parent then
 p.shell.CFrame=p.source.CFrame p.shell.Transparency=p.source.Transparency>=1 and 1 or p.alpha
 if glow and p.surface and s.tier=="Molten" then p.surface.EmissiveStrength=glow end
 p.shell.LocalTransparencyModifier=p.source.LocalTransparencyModifier
 for _,b in p.bones do if b[1].Parent then b[2].Transform=b[1].Transform end end
 end end end
end)
