-- SurfaceWakes v9: coarse opaque foam; history reprojects onto moving water each frame.
-- Water walking stays stream-only. One-shot footsteps follow animated foot planting, never a wading loop.
local Debris=game:GetService("Debris")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Path = require(RS:WaitForChild("WaterfallRiver"):WaitForChild("RiverPath"))
local Waves = require(RS.WaterfallRiver:WaitForChild("RiverWaves"))
local Arena = require(RS:WaitForChild("ArenaEvent"):WaitForChild("ArenaConfig"))
local Volcano = require(RS:WaitForChild("VolcanoEvent"):WaitForChild("VolcanoConfig"))
local eggs = workspace:WaitForChild("LocalRiverEggs")


-- ProSoundEffects: Puddle Stomps Small Water Splashes 18 / 3 (0.4 / 0.5 seconds).
local STEPS = {"rbxassetid://9117947974", "rbxassetid://9117946641"}
local SIZZLE = "rbxassetid://9114542867"
local PLOP = "rbxassetid://9125409816"
local WATER = Color3.fromRGB(212, 246, 255)
local LAVA = Color3.fromRGB(255, 163, 42)
local VIEW = 190
local MAX_SUBJECTS, MAX_IMPACTS = 32, 12
local folder = Instance.new("Folder")
folder.Name = "TexturedSurfaceWakes"
folder.Parent = workspace
local subjects, impacts = {}, {}
local count = 0
local START_X, END_X = Path.At(Path.LandDistance).X, Path.At(Path.Total - 4).X
local LAVA_Y = Arena.Center.Y - Arena.LavaDepth

local function anchor(name)
    local p = Instance.new("Part")
    p.Name, p.Size, p.Transparency = name, Vector3.one * 0.2, 1
    p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
    p.Parent = folder
    return p
end

local function riverSurface(p, state)
    if p.X < START_X or p.X > END_X then return nil end
    local lo, hi = 0, Path.Total
    for _ = 1, 11 do
        local m = (lo + hi) / 2
        if Path.At(m).X < p.X then lo = m else hi = m end
    end
    local d = (lo + hi) / 2
    local point, _, right = Path.At(d)
    local offset = (p - point):Dot(right)
    if math.abs(offset) > Path.WidthAt(d) / 2 - 0.3 then return nil end
    local start = workspace:GetAttribute("VolcanoStart")
    local lava = Volcano.ChunkLavaLevel(math.clamp(math.floor(d / 60) + 1, 1, 9),
        start and workspace:GetServerTimeNow() - start) > 0.5
    return Waves.SurfaceAt(state, d, offset) + (lava and 0.35 or 0), lava
end

local function newSound(parent, name, id, volume)
    local s = Instance.new("Sound")
    s.Name, s.SoundId, s.Volume = name, id, volume
    s.RollOffMode = Enum.RollOffMode.InverseTapered
    s.RollOffMinDistance, s.RollOffMaxDistance = 10, 75
    s.Parent = parent
    return s
end

-- Burst-only particles; secondary water spray is scheduled at the ballistic return time.
local surfaceTouch
local activeBursts=0
local function burst(pos,lava,amount,speed,secondary,arena)
    if activeBursts>=32 then return end
    activeBursts+=1
    local p=anchor("ParticleSplash")
    p.Position=pos
    local at=Instance.new("Attachment")
    at.Parent=p
    local e=Instance.new("ParticleEmitter")
    e.Texture="rbxassetid://102688400056466"
    e.Rate=0
    e.Lifetime=NumberRange.new(speed/20,speed/16)
    local angle=math.random()*math.pi*2
    local velocity=Vector3.new(math.cos(angle)*speed*0.4,speed*0.9,math.sin(angle)*speed*0.4)
    at.CFrame=CFrame.lookAt(Vector3.zero,velocity)
    e.EmissionDirection=Enum.NormalId.Front
    e.Speed=NumberRange.new(velocity.Magnitude)
    e.SpreadAngle=Vector2.new(secondary and 45 or 5,secondary and 45 or 5)
    e.Acceleration=Vector3.new(0,-32,0)
    e.Color=ColorSequence.new(lava and LAVA or WATER)
    e.LightEmission=lava and 0.7 or 0
    e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,secondary and 0.22 or 0.55),NumberSequenceKeypoint.new(1,0.1)})
    e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.8,0.1),NumberSequenceKeypoint.new(1,1)})
    e.Rotation=NumberRange.new(-15,15)
    e.RotSpeed=NumberRange.new(-30,30)
    e.Parent=at
    e:Emit(amount)
    Debris:AddItem(p,2)
    task.delay(2,function() activeBursts-=1 end)
    if not secondary then
        local flight=(velocity.Y+math.sqrt(velocity.Y^2+2*32*0.25))/32
        e.Lifetime=NumberRange.new(flight)
        local landing=pos+Vector3.new(velocity.X,0,velocity.Z)*flight
        task.delay(flight,function()
            if not folder.Parent then return end
            local y=arena and LAVA_Y or riverSurface(landing,Waves.State(workspace:GetServerTimeNow()))
            if y then
                local contact=Vector3.new(landing.X,y+0.2,landing.Z)
                burst(contact,lava,math.min(amount,5),3,true,arena)
                if surfaceTouch then surfaceTouch(contact,lava) end
            end
        end)
    end
end
-- The invisible carrier only places the texture. No visible wake geometry or frame animation.
local function makeWake(parent,isEgg)
    local gui=Instance.new("SurfaceGui")
    gui.Name="StaticWakeTexture"
    gui.Face=Enum.NormalId.Top
    gui.LightInfluence=0
    gui.CanvasSize=Vector2.new(256,256)
    gui.Adornee=parent
    gui.Parent=parent
    local image=Instance.new("ImageLabel")
    image.BackgroundTransparency=1
    image.Size=UDim2.fromScale(1,1)
    image.Image="rbxassetid://110842520915298"
    image.ResampleMode=Enum.ResamplerMode.Pixelated
    image.Parent=gui
    return image
end
local function makeRing(parent)
    local gui=Instance.new("SurfaceGui")
    gui.Name="PlayerSplashRing"
    gui.Face=Enum.NormalId.Top
    gui.LightInfluence=0
    gui.CanvasSize=Vector2.new(128,128)
    gui.Adornee=parent
    gui.Parent=parent
    local image=Instance.new("ImageLabel")
    image.BackgroundTransparency=1
    image.Size=UDim2.fromScale(1,1)
    image.Image="rbxassetid://77297633636595"
    image.ResampleMode=Enum.ResamplerMode.Pixelated
    image.Parent=gui
    return image
end
local contactCount=0
surfaceTouch=function(pos,lava)
    if contactCount>=24 then return end
    contactCount+=1
    local p=anchor("DropletContact")
    p.Position=pos
    p.Size=Vector3.new(0.35,0.04,0.35)
    local image=makeRing(p)
    image.ImageColor3=lava and LAVA or WATER
    local tween=game:GetService("TweenService")
    tween:Create(p,TweenInfo.new(0.4),{Size=Vector3.new(1.15,0.04,1.15)}):Play()
    tween:Create(image,TweenInfo.new(0.4),{ImageTransparency=1}):Play()
    Debris:AddItem(p,0.45)
    task.delay(0.45,function() contactCount-=1 end)
end
local function newSubject(object, isEgg, radius)
    if count >= MAX_SUBJECTS then return nil end
    local p = anchor(isEgg and "EggWake" or "PlayerWake")
    local rec = {object=object, carrier=p, isEgg=isEgg, radius=radius,
        lastStep=-10, feet={}, wasWet=false, wasActive=false, footSounds={}, opacity=0,
        phase=math.random(0,7)}
    rec.wake=makeWake(p,isEgg)
    rec.history={}
    rec.ribbons={}
    for i=1,10 do
        local a0,a1=Instance.new("Attachment"),Instance.new("Attachment")
        a0.Parent,a1.Parent=p,p
        local beam=Instance.new("Beam")
        beam.Name="SurfaceWakeHistory"
        beam.Attachment0,beam.Attachment1=a0,a1
        beam.FaceCamera=false
        beam.Texture="rbxassetid://76004795890424"
        beam.TextureMode=Enum.TextureMode.Wrap
        beam.TextureLength=4
        beam.LightInfluence=0
        beam.Segments=1
        beam.Enabled=false
        beam.Parent=p
        rec.ribbons[i]={beam=beam,a0=a0,a1=a1}
    end
    subjects[object], count = rec, count+1
    return rec
end

local function restoreRunning(rec)
    if rec.running and rec.running.Parent and rec.runningVolume then
        rec.running.Volume = rec.runningVolume
    end
    rec.running, rec.runningVolume = nil,nil
end
local function dispose(object)
    local rec = subjects[object]
    if not rec then return end
    restoreRunning(rec)
    rec.carrier:Destroy()
    subjects[object], count = nil,count-1
end
local function setActive(rec,pos,dir,lava,moving,active,dt)
    rec.carrier.Position=pos
    rec.opacity+=(((active and moving) and 1 or 0)-rec.opacity)*(1-math.exp(-dt/0.18))
    local diameter=rec.isEgg and math.clamp(rec.radius*2.65,4.98,13.25) or 5.5
    local centre=pos-dir*0.1
    rec.carrier.CFrame=CFrame.lookAt(centre,centre+dir)*CFrame.Angles(0,-math.pi/2,0)
    local hullState=Waves.State(workspace:GetServerTimeNow())
    local surface=riverSurface(pos,hullState) or pos.Y-0.4
    for _,offset in {dir*diameter*0.35,-dir*diameter*0.35,Vector3.new(-dir.Z,0,dir.X)*diameter*0.35,Vector3.new(dir.Z,0,-dir.X)*diameter*0.35} do
        surface=math.max(surface,riverSurface(pos+offset,hullState) or surface)
    end
    rec.carrier.Position=Vector3.new(rec.carrier.Position.X,surface+0.25,rec.carrier.Position.Z)
    rec.carrier.Size=Vector3.new(diameter,0.04,diameter)
    local right=Vector3.new(-dir.Z,0,dir.X)
    local now=os.clock()
    local history=rec.history
    local wakeStep=rec.lastWakePos and (pos-rec.lastWakePos).Magnitude or 0
    if wakeStep>15 then table.clear(history) end
    rec.lastWakePos=pos
    local stern=pos-dir*(diameter*0.15+0.1) -- Origin shoulders end at 65% of the square texture.
    local spacing=math.clamp(wakeStep/math.max(dt,1/240)*1.8/10,0.7,3.5)
    if active and moving and (not history[1] or (stern-history[1].pos).Magnitude>spacing) then
        rec.travel=(rec.travel or 0)+(history[1] and (stern-history[1].pos).Magnitude or 0)
        table.insert(history,1,{pos=stern,born=now,distance=rec.travel})
    end
    while #history>11 or (#history>0 and now-history[#history].born>1.8) do table.remove(history) end
    local state=Waves.State(workspace:GetServerTimeNow())
    for i,ribbon in rec.ribbons do
        local liveHead=active and moving
        local newer=liveHead and (i==1 and {pos=stern,born=now,distance=(rec.travel or 0)+(history[1] and (stern-history[1].pos).Magnitude or 0)} or history[i-1]) or history[i]
        local older=history[liveHead and i or i+1]
        if newer and older then
            local delta=older.pos-newer.pos
            if Vector3.new(delta.X,0,delta.Z).Magnitude<0.02 then ribbon.beam.Enabled=false;continue end
            local tangent=Vector3.new(delta.X,0,delta.Z).Unit
            local side=Vector3.new(-tangent.Z,0,tangent.X)
            local age=(now-older.born)/1.8
            local width=diameter*(0.70/0.67) -- Match painted foam edges, not transparent image bounds.
            local function lift(point)
                local y=riverSurface(point,state)
                local l=riverSurface(point+side*width*0.5,state)
                local r=riverSurface(point-side*width*0.5,state)
                return Vector3.new(point.X,math.max(y or point.Y,l or -math.huge,r or -math.huge)+0.24,point.Z)
            end
            local v0,v1=lift(newer.pos),lift(older.pos)
            ribbon.a0.WorldCFrame=CFrame.fromMatrix(v0,tangent,side)
            ribbon.a1.WorldCFrame=CFrame.fromMatrix(v1,tangent,side)
            -- Match the square hull texture's world cell size; retain phase across short history spans.
            ribbon.beam.TextureLength=diameter
            ribbon.beam.TextureSpeed=0
            ribbon.beam:SetTextureOffset((-newer.distance/diameter)%1)
            ribbon.beam.Width0,ribbon.beam.Width1=width,width
            ribbon.beam.Color=ColorSequence.new(lava and LAVA or Color3.new(1,1,1))
            ribbon.beam.Transparency=NumberSequence.new(math.clamp((age-0.3)/0.7,0,1))
            ribbon.beam.Enabled=true
        else ribbon.beam.Enabled=false end
    end
    rec.wake.ImageTransparency=1-rec.opacity
    rec.wake.ImageColor3=lava and LAVA or Color3.new(1,1,1)
    if not active then restoreRunning(rec) end
    rec.lava,rec.wasActive=lava,active
end

local function impact(pos, radius, lava)
    if #impacts>=MAX_IMPACTS then return end
    local camera=workspace.CurrentCamera
    if not camera or (camera.CFrame.Position-pos).Magnitude>350 then return end
    local p=anchor("SurfaceImpact")
    p.Position=pos
    local ring=makeRing(p)
    ring.ImageColor3=lava and LAVA or WATER
    local arena=math.abs(pos.Y-LAVA_Y)<2
    burst(pos,lava,math.clamp(math.floor(radius*2),10,24),math.clamp(radius*2,9,20),false,arena)
    local sound=newSound(p,"Impact",lava and PLOP or "rbxassetid://9120585252",math.clamp(radius*0.07,0.3,0.9))
    sound.RollOffMaxDistance=180
    sound:Play()
    if lava then
        local heat=newSound(p,"Sizzle",SIZZLE,0.65)
        heat.TimePosition=4
        heat.RollOffMaxDistance=180
        heat:Play()
    end
    table.insert(impacts,{carrier=p,ring=ring,born=os.clock(),life=1.6,radius=radius,lava=lava})
end

local function jumpSpray(pos,lava)
    burst(pos,lava,10,12,false,false)
end
-- No arbitrary cadence or multi-step loops: trigger at each animated foot's forward-to-back plant.
-- Works for the current markerless R15 animations and blended walks. R6 uses its leg endpoints.
local function footsteps(rec, root, hum, dir, moving, wet, now, dt)
    for _,name in {"PixelWadeWater","PixelWadeLava"} do
        local old=root:FindFirstChild(name)
        if old then old:Destroy() end
    end
    local running=root:FindFirstChild("Running")
    if wet and running and running:IsA("Sound") then
        if rec.running~=running then
            restoreRunning(rec)
            rec.running,rec.runningVolume=running,running.Volume
        end
        running.Volume=0
    elseif not wet then restoreRunning(rec) end
    local char=root.Parent
    for i,names in {{"LeftFoot","Left Leg"},{"RightFoot","Right Leg"}} do
        local foot=char:FindFirstChild(names[1]) or char:FindFirstChild(names[2])
        if not foot then continue end
        local f=rec.feet[i] or {forward=nil,advancing=false,last=-10}
        rec.feet[i]=f
        local relative=root.CFrame:PointToObjectSpace(foot.Position)
        local localDir=root.CFrame:VectorToObjectSpace(dir)
        local forward=relative:Dot(localDir)
        local rate=f.forward and (forward-f.forward)/math.max(dt,1/240) or 0
        local low=relative.Y-foot.Size.Y/2 < -(hum.HipHeight+root.Size.Y/2)*0.45
        if moving and wet and hum.Health>0 and hum.FloorMaterial~=Enum.Material.Air then
            if rate>0.8 then f.advancing=true end
            if f.advancing and rate < -0.8 and low then
                f.advancing=false
                if now-f.last>0.18 and now-rec.lastStep>0.10 then
                    f.last,rec.lastStep=now,now
                    local sound=rec.footSounds[i]
                    if not sound then
                        sound=newSound(rec.carrier,"FootPlant"..i,STEPS[i],0.55)
                        rec.footSounds[i]=sound
                    end
                    sound.SoundId=rec.lava and PLOP or STEPS[i]
                    sound.PlaybackSpeed=rec.lava and 0.85 or 1
                    sound.Volume=rec.lava and 0.4 or 0.55
                    sound.TimePosition=0
                    sound:Play()
                    burst(Vector3.new(foot.Position.X,rec.carrier.Position.Y,foot.Position.Z),rec.lava,3,6,false,false)
                    if rec.lava then
                        if not rec.heat then rec.heat=newSound(rec.carrier,"StepHeat",SIZZLE,0.25) end
                        rec.heat.TimePosition=4
                        rec.heat:Play()
                        rec.heatUntil=now+0.25
                    end
                    rec.carrier:SetAttribute("LastFoot",i)
                    rec.carrier:SetAttribute("StepCount",(rec.carrier:GetAttribute("StepCount") or 0)+1)
                end
            end
        else
            f.advancing=false
        end
        f.forward=forward
    end
    if rec.heat and (not wet or now>(rec.heatUntil or 0)) then rec.heat:Stop() end
end

local function eggRadius(egg)
    local pivot=egg:GetPivot()
    local minY,maxX,maxZ=math.huge,0,0
    for _,p in egg:GetDescendants() do
        if p:IsA("BasePart") and p.Transparency<1 and p.Name~="LabelAnchor" and p.Name~="CollectAnchor" then
            for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
                local v=pivot:PointToObjectSpace(p.CFrame:PointToWorldSpace(p.Size*Vector3.new(x,y,z)/2))
                minY=math.min(minY,v.Y);maxX=math.max(maxX,math.abs(v.X));maxZ=math.max(maxZ,math.abs(v.Z))
            end end end
        end
    end
    return math.clamp(math.max(maxX,maxZ)+0.7,1.2,7),minY
end

RunService:BindToRenderStep("TexturedSurfaceWakes",Enum.RenderPriority.Camera.Value+2,function(dt)
    local camera=workspace.CurrentCamera
    if not camera then return end
    local now=os.clock()
    local state=Waves.State(workspace:GetServerTimeNow())
    -- Player work is first so an egg-heavy river cannot exhaust their effect budget.
    local live={}
    for _,player in Players:GetPlayers() do
        local char=player.Character
        local root=char and char:FindFirstChild("HumanoidRootPart")
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then continue end
        live[char]=true
        local rec=subjects[char]
        local p=root.Position
        if (p-camera.CFrame.Position).Magnitude>VIEW then
            if rec then dispose(char) end
            continue
        end
        rec=rec or newSubject(char,false,1.4)
        if not rec then continue end
        local prev=rec.previous or p
        if (p-prev).Magnitude>40 then rec.peak=p.Y; rec.fallFired=false; rec.wasWet=false end
        rec.peak=math.max(rec.peak or p.Y,p.Y)
        local v=root.AssemblyLinearVelocity
        local flat=Vector3.new(v.X,0,v.Z)
        local moving=flat.Magnitude>2 and hum.Health>0
        local dir=flat.Magnitude>0.1 and flat.Unit or Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z).Unit
        local arena=workspace:FindFirstChild("PvPArena") and Vector2.new(p.X-Arena.Center.X,p.Z-Arena.Center.Z).Magnitude<Arena.LavaRadius
        if arena then
            setActive(rec,p,dir,true,false,false,dt)
            footsteps(rec,root,hum,dir,false,false,now,dt)
            if p.Y>Arena.Center.Y-2 then rec.fallFired=false end
            if not rec.fallFired and p.Y<prev.Y and p.Y<Arena.Center.Y-7 then
                rec.fallFired=true
                local remaining=math.max(0,p.Y-LAVA_Y)
                local down=math.max(0,-v.Y)
                local gravity=math.max(1,workspace.Gravity)
                local delay=(math.sqrt(down*down+2*gravity*remaining)-down)/gravity
                local drop=math.max(rec.peak,Arena.Center.Y)-LAVA_Y
                local pos=Vector3.new(p.X+v.X*delay,LAVA_Y+0.5,p.Z+v.Z*delay)
                task.delay(delay,function() if workspace:FindFirstChild("PvPArena") then impact(pos,math.clamp(3+math.sqrt(drop)*1.5,4,26),true) end end)
            end
        else
            local y,lava=riverSurface(p,state)
            local feet=p.Y-hum.HipHeight-root.Size.Y/2
            local wet=y~=nil and feet<y+0.5 and feet>y-5 and hum.Health>0
            setActive(rec,Vector3.new(p.X,(y or p.Y)+0.4,p.Z),dir,lava==true,moving,wet and hum.FloorMaterial~=Enum.Material.Air and hum:GetState()~=Enum.HumanoidStateType.Jumping,dt)
            footsteps(rec,root,hum,dir,moving,wet,now,dt)
            if y and (wet or rec.wasWet) and v.Y>8 and (rec.previousVy or 0)<=8 and now-(rec.lastJump or -10)>0.4 then
                rec.lastJump=now
                jumpSpray(Vector3.new(p.X,y+0.4,p.Z),lava)
                rec.carrier:SetAttribute("JumpCount",(rec.carrier:GetAttribute("JumpCount") or 0)+1)
            end
            rec.previousVy=v.Y
            if wet and not rec.wasWet and v.Y < -10 then
                impact(Vector3.new(p.X,y+0.2,p.Z),math.clamp(2+math.sqrt(math.max(0,rec.peak-y)),2,9),lava)
            end
            rec.wasWet=wet
            if hum.FloorMaterial~=Enum.Material.Air then rec.peak=p.Y end
        end
        rec.previous=p
    end
    for _,egg in eggs:GetChildren() do
        if not egg:IsA("Model") then continue end
        live[egg]=true
        local rec=subjects[egg]
        local p=egg:GetPivot().Position
        local visible=egg:GetAttribute("Collectible") and not egg:GetAttribute("Collected")
            and (p-camera.CFrame.Position).Magnitude<VIEW
        if not visible then if rec then dispose(egg) end;continue end
        if not rec then
            local radius,minY=eggRadius(egg)
            rec=newSubject(egg,true,radius)
            if rec then rec.minY=minY end
        end
        if not rec then continue end
        local y,lava=riverSurface(p,state)
        local delta=rec.previous and p-rec.previous or Vector3.xAxis
        local flat=Vector3.new(delta.X,0,delta.Z)
        local dir=flat.Magnitude>0.001 and flat.Unit or Vector3.xAxis
        -- Same render step as the visual egg, positioned from the actual river wave field.
        setActive(rec,Vector3.new(p.X,(y or p.Y)+0.4,p.Z),dir,lava==true,flat.Magnitude>0.001,y~=nil,dt)
        rec.previous=p
    end
    for object in subjects do if not live[object] or not object.Parent then dispose(object) end end
    for i=#impacts,1,-1 do
        local e=impacts[i]
        local t=(now-e.born)/e.life
        if t>=1 then e.carrier:Destroy();table.remove(impacts,i)
        else
            e.carrier.Size=Vector3.new(1,0.04,1)*(e.radius*(0.4+t*1.8))
            e.ring.ImageTransparency=0.12+t*0.88
        end
    end
end)
script.Destroying:Connect(function()
    RunService:UnbindFromRenderStep("TexturedSurfaceWakes")
    for object in subjects do dispose(object) end
    folder:Destroy()

end)
