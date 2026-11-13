local Assets=game:GetService("AssetService")
local Run=game:GetService("RunService")
local textures={Silver="rbxassetid://96228988315926",Gold="rbxassetid://110840054513785",Diamond="rbxassetid://70482436642739",Rainbow="rbxassetid://70614355485441",Molten=true}
-- Molten v3 is an opaque lava coat over the whole body (the old half-out head fade was dropped). On the head the
-- lava is MOLTEN_HEAD_ALPHA transparent over a GlowFace base, so the eyes and mouth glow through it like Galaxy.
local opacity={Silver=.28,Gold=.5,Diamond=.58,Rainbow=.48,Molten=0}
local MOLTEN_HEAD_ALPHA=.58 -- 2026-11-12: was .45; less lava crust over the face so it reads less cracked
local GlowFace=require(game.ReplicatedStorage:WaitForChild("GlowFace"))
local MOLTEN_FACE={
 -- basalt: the character's own shading kept as dark rock with a faint red heat
 base=function(r,g,b) local l=r*.3+g*.59+b*.11 return .07+l*.30,.035+l*.13,.025+l*.08 end,
 glow=Color3.fromRGB(255,170,55),emissive=2.4,
}
-- Tiers that get a projected layer. Gold and Silver have their pattern baked into the character texture
-- (MutationFinish/bake_metal_atlas.js), so they get no layer.
-- Rainbow keeps its moving diagonal gradient (briefly removed on 2026-11-12, restored at Jacob's request).
local coated={Rainbow=true,Molten=true,Diamond=true}
local RAINBOW_SPEED=.15 -- colour-wheel turns per second of the gradient (was .36; slower strobe)
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
 s.folder:Destroy() for _,p in s.parts do
 if p.mesh then p.mesh:Destroy() end
 if p.hideBase and p.source.Parent then p.source.LocalTransparencyModifier=0 end
 if p.faceSwap then
 local g=p.source:FindFirstChild("GlowFace") if g then g:Destroy() end
 if p.original then if p.source.Parent then p.original.Parent=p.source else p.original:Destroy() end end
 end
 end active[m]=nil
end
local function build(m)
 if active[m] or pending[m] then return end
 -- 2026-11-13: the shells are skinned meshes that bind to the model's bones by name when they are parented.
 -- A placed character streams in parts first and its rig part (RootPart with the bones) later; a coat built
 -- before the bones arrived stayed frozen in the rest pose while the hidden body animated (broken coat and an
 -- outline tracing the moving body). Wait for the bones; DescendantAdded below rebuilds if more arrive later.
 local skinned,hasBone=false,false
 for _,d in m:GetDescendants() do
 if d:IsA("Bone") then hasBone=true break end
 if d:IsA("MeshPart") and d.HasSkinnedMesh then skinned=true end
 end
 if skinned and not hasBone then return end
 pending[m]=true
 local s={folder=Instance.new("Folder"),parts={},tier=m:GetAttribute("Mutation")}
 s.folder.Name="MutationCoating"
 s.folder.Archivable=false -- client copies of the character (reveal, icons) must not take stale shells along
 local ok,err=pcall(function()
 local finish
 if s.tier == "Molten" then
     moltenSurface = moltenSurface or require(script.MoltenSurface)
     finish = moltenSurface.Surface
     s.face, s.faceParts = GlowFace.Surface(m, "Molten", MOLTEN_FACE)
 else
     finish = s.tier == "Rainbow" and rainbowSurface or finishes:WaitForChild(s.tier)
 end
 for _,part in m:GetDescendants() do
 if not part:IsA("MeshPart") or part.Transparency>=1 then continue end
 local template=(s.tier=="Rainbow" and templates or closedTemplates):FindFirstChild(part.Name)
 if not template then continue end
 local rec={source=part,bones={},alpha=opacity[s.tier],hideBase=s.tier=="Molten" and opacity.Molten==0} table.insert(s.parts,rec)
 if s.face and s.faceParts and s.faceParts[part.Name] then
 -- head: keep the base visible with the glowing face, lava shell partly see-through on top
 rec.hideBase=false rec.alpha=MOLTEN_HEAD_ALPHA rec.faceSwap=true
 rec.original=part:FindFirstChildOfClass("SurfaceAppearance") if rec.original then rec.original.Parent=nil end
 s.face:Clone().Parent=part
 end
 local shell=part:Clone()
 for _,d in shell:GetDescendants() do if not d:IsA("Bone") and not d:FindFirstAncestorWhichIsA("Bone") then d:Destroy() end end
 -- The projected mesh has a baked normal offset. Preserve that offset at the source mesh's scale.
 -- An exact native-mesh clone shares the base surface's depth and flickers as the rig moves.
 shell:ApplyMesh(template)
 shell.Size=part.Size*(template.MeshSize/part.MeshSize)
 shell.CFrame=part.CFrame shell.Name="ProjectedCoating"
 shell:SetAttribute("CoatingStyle",s.tier=="Rainbow" and "ProjectedRainbow" or s.tier=="Molten" and "LavaFlow" or STYLE)
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
 end end
 -- the shells live inside the character (below), so rename their bones: pose / move scripts find bones by name
 for _,pair in rec.bones do pair[2].Name="Coat"..pair[2].Name end
 shell.Parent=s.folder
 end end)
 pending[m]=nil
 if not ok or not m:IsDescendantOf(workspace) then
 s.folder:Destroy() active[m]=s remove(m)
 if not ok then warn("[MutationCoating] "..tostring(err)) end return end
 -- 2026-11-12: inside the model (was workspace), so a Highlight on the character (reveal, placed outline,
 -- hatchery aura) outlines the coat too. Before, Molten hides its base meshes and the outline only went round the head.
 active[m]=s s.folder.Parent=m
end
-- Event-driven candidate list instead of a whole-workspace GetDescendants() every second.
local candidates={}
local function consider(m)
 if m:IsA("Model") and not m:IsA("Tool") and coated[m:GetAttribute("Mutation")] then candidates[m]=true end
end
for _,m in workspace:GetDescendants() do consider(m) end
-- a bone (or the rig part holding them) arriving after the coat was built: rebuild so the shells bind to it
local function rigChanged(d)
 if not (d:IsA("Bone") or d:FindFirstChildWhichIsA("Bone",true)) or d:FindFirstAncestor("MutationCoating") then return end
 local m=d:FindFirstAncestorWhichIsA("Model")
 while m and not active[m] do m=m:FindFirstAncestorWhichIsA("Model") end
 if m then remove(m) end -- the 1 s loop builds it again with the bones in place
end
workspace.DescendantAdded:Connect(function(m)
 consider(m) if m:IsA("Model") then task.defer(consider,m) end
 if next(active) then rigChanged(m) end
end)
workspace.DescendantRemoving:Connect(function(m) candidates[m]=nil end)
task.spawn(function()
 while task.wait(1) do
 local cam=workspace.CurrentCamera if not cam then continue end
 local near={}
 for m in candidates do
 if not m.Parent or not coated[m:GetAttribute("Mutation")] then candidates[m]=nil continue end
 local distance=(m:GetPivot().Position-cam.CFrame.Position).Magnitude
 if distance<100 then table.insert(near,{m,distance}) end end
 table.sort(near,function(a,b) return a[2]<b[2] end)
 local keep={}
 for i=1,math.min(6,#near) do keep[near[i][1]]=true task.spawn(build,near[i][1]) end
 for m in active do if not keep[m] then remove(m) end end
 end
end)
local nextImage,nextGlow=0,0
Run.RenderStepped:Connect(function()
 local now=os.clock()
 local hasRainbow,hasMolten=false,false
 for _,state in active do
 if #state.parts>0 then
 if state.tier=="Rainbow" then hasRainbow=true elseif state.tier=="Molten" then hasMolten=true end
 end
 end
 -- the rainbow texture only needs regenerating while a Rainbow coat is on screen
 if hasRainbow and now>=nextImage then nextImage=now+.05
 for y=0,63 do for x=0,63 do
 local c=Color3.fromHSV(((x+y)/64-now*RAINBOW_SPEED)%1,.75,1) local p=(y*64+x)*4
 buffer.writeu8(pixels,p,math.floor(c.R*255)) buffer.writeu8(pixels,p+1,math.floor(c.G*255))
 buffer.writeu8(pixels,p+2,math.floor(c.B*255)) buffer.writeu8(pixels,p+3,255)
 end end image:WritePixelsBuffer(Vector2.zero,Vector2.new(64,64),pixels) end
 local glow=hasMolten and moltenSurface and moltenSurface.Update(now)
 -- 2026-11-12 perf: properties are only written when their value changes, and the breathing glow at most 8x/s.
 -- Writing EmissiveStrength on every shell's SurfaceAppearance every frame (plus CFrame / transparency on static
 -- displays) cost ~10 ms a frame with two Molten characters on screen.
 local glowStep=nil
 if glow and now>=nextGlow then nextGlow=now+1/8 glowStep=math.floor(glow*40+.5)/40 end
 for m,s in active do
 if not m:IsDescendantOf(workspace) then remove(m) continue end
 for _,p in s.parts do if p.shell and p.source.Parent then
 local cf=p.source.CFrame if p.lastCf~=cf then p.lastCf=cf p.shell.CFrame=cf end
 local alpha=p.source.Transparency>=1 and 1 or p.alpha
 if p.lastAlpha~=alpha then p.lastAlpha=alpha p.shell.Transparency=alpha end
 if glowStep and p.surface and s.tier=="Molten" and p.lastGlow~=glowStep then p.lastGlow=glowStep p.surface.EmissiveStrength=glowStep end
 if p.hideBase then
 -- opaque Molten coat: hide the base mesh locally so it can't poke through the shell as black specks
 if p.source.LocalTransparencyModifier~=1 then p.source.LocalTransparencyModifier=1 end
 else
 local ltm=p.source.LocalTransparencyModifier
 if p.shell.LocalTransparencyModifier~=ltm then p.shell.LocalTransparencyModifier=ltm end
 end
 for _,b in p.bones do if b[1].Parent then b[2].Transform=b[1].Transform end end
 end end end
end)
