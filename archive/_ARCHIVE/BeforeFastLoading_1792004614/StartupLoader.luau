-- Startup readiness and bounded content loading. No gameplay data is created here.
local M = {}
local CP = game:GetService("ContentProvider")
local RS = game:GetService("ReplicatedStorage")
local HTTP = game:GetService("HttpService")
local PROPERTIES = {
 MeshPart={"MeshId","TextureID"}, SpecialMesh={"MeshId","TextureId"},
 Decal={"Texture"}, Texture={"Texture"}, ImageLabel={"Image"}, ImageButton={"Image"},
 Sound={"SoundId"}, Animation={"AnimationId"}, ParticleEmitter={"Texture"},
 Beam={"Texture"}, Trail={"Texture"}, SurfaceAppearance={"ColorMap","MetalnessMap","NormalMap","RoughnessMap"},
 MaterialVariant={"ColorMap","MetalnessMap","NormalMap","RoughnessMap"},
 Sky={"SkyboxBk","SkyboxDn","SkyboxFt","SkyboxLf","SkyboxRt","SkyboxUp","SunTextureId","MoonTextureId"},
}
function M.Collect(roots)
 local seen, ids = {}, {}
 local function scan(v)
  for _,prop in PROPERTIES[v.ClassName] or {} do
   local ok,id=pcall(function() return v[prop] end)
   if ok and type(id)=="string" and id~="" and not seen[id] then seen[id]=true;table.insert(ids,{id=id,kind=prop=="MeshId" and "Mesh" or (prop=="SoundId" and "Sound" or (prop=="AnimationId" and "Animation" or "Image"))}) end
  end
 end
 for _,root in roots do if root then scan(root);for _,v in root:GetDescendants() do scan(v) end end end
 return ids
end
-- Each pass has a wall-clock budget, including requests that never return.
function M.Preload(ids, budget, update, fetch)
 fetch=fetch or function(asset, callback)
  local proxy
  if asset.kind=="Mesh" then proxy=Instance.new("SpecialMesh");proxy.MeshId=asset.id
  elseif asset.kind=="Sound" then proxy=Instance.new("Sound");proxy.SoundId=asset.id
  elseif asset.kind=="Animation" then proxy=Instance.new("Animation");proxy.AnimationId=asset.id
  else proxy=Instance.new("Decal");proxy.Texture=asset.id end
  -- A request must carry its content type; raw IDs can be fetched as the wrong type.
  local cleanup=task.delay(120,function() proxy:Destroy() end)
  local ok,err=pcall(function() CP:PreloadAsync({proxy},callback) end)
  task.cancel(cleanup);proxy:Destroy()
  if not ok then error(err) end
 end
 local nextIndex,done,active=1,0,true
 local failed,threads={},{}
 local deadline=os.clock()+budget
 local function worker()
  while active and nextIndex<=#ids do
   local index=nextIndex;nextIndex+=1
   local id=ids[index]
   local success=false
   local ok=pcall(fetch,id,function(_,result)
    if result==Enum.AssetFetchStatus.Success then success=true end
   end)
   if not active then return end
   failed[index]=not (ok and success)
   done+=1
  end
 end
 for _=1,math.min(24,#ids) do table.insert(threads,task.spawn(worker)) end
 while done<#ids and os.clock()<deadline do update(done,#ids);task.wait(.1) end
 active=false
 for _,thread in threads do if coroutine.status(thread)~="dead" then pcall(task.cancel,thread) end end
 local retry={}
 for i,id in ids do if failed[i]~=false then table.insert(retry,id) end end
 update(done,#ids)
 return retry
end
function M.Ready(player)
 if not game:IsLoaded() then return nil,"Connecting to the game" end
 if player:GetAttribute("StartupSessionReady")~=true then
  return nil,player:GetAttribute("WaitingForPlot") and "Waiting for an available temple" or "Preparing your session"
 end
 if RS:GetAttribute("StartupInventoryReady")~=true then return nil,"Preparing your inventory" end
 local stats=player:FindFirstChild("leaderstats")
 if not stats or not stats:FindFirstChild("Cash") or not player:FindFirstChildOfClass("Backpack") then return nil,"Preparing your player data" end
 local char=player.Character
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 if not hum or hum.Health<=0 or not char:FindFirstChild("HumanoidRootPart") then return nil,"Spawning your character" end
 local plots=workspace:FindFirstChild("Plots")
 if plots then for _,plot in plots:GetChildren() do
  if plot:GetAttribute("PlotId")==player:GetAttribute("PlotId") and plot:GetAttribute("OwnerUserId")==player.UserId then
   if plot:FindFirstChild("Temple") and plot:FindFirstChild("PlotSpawn") and plot:FindFirstChild("Slots") then return plot end
  end
 end end
 return nil,"Loading your temple"
end
function M.Run(player,gui,update)
 local function waitReady()
  local deadline=os.clock()+45
  repeat
   local plot,message=M.Ready(player)
   if plot then return plot end
   update(.08,message)
   task.wait(.2)
  until os.clock()>=deadline
  error("Your session is taking longer than expected. Please retry.")
 end
 local plot=waitReady()
 update(.15,"Loading the area around your temple")
 if workspace.StreamingEnabled then
  local finished=false
  local thread=task.spawn(function()
   pcall(function() player:RequestStreamAroundAsync(plot.PlotSpawn.Position,8) end)
   finished=true
  end)
  local deadline=os.clock()+9
  repeat task.wait(.1) until finished or os.clock()>=deadline
  if not finished then pcall(task.cancel,thread) end
 end
 local manifest=RS:WaitForChild("StartupAssetManifest",15)
 if not manifest or manifest.Value=="" then error("The game is still preparing its models. Please retry.") end
 local ids=HTTP:JSONDecode(manifest.Value)
 local seen={} for _,asset in ids do seen[asset.id]=true end
 for _,asset in M.Collect({workspace,RS,gui,game:GetService("Lighting"),game:GetService("MaterialService")}) do
  if not seen[asset.id] then seen[asset.id]=true;table.insert(ids,asset) end
 end
 player:SetAttribute("StartupAssetCount",#ids)
 local failed=M.Preload(ids,90,function(done,total)
  update(.2+.65*(total>0 and done/total or 1),"Loading models and visuals ("..done.."/"..total..")")
 end)
 if #failed>0 then
  failed=M.Preload(failed,20,function(done,total)
   update(.85+.1*(total>0 and done/total or 1),"Retrying asset downloads ("..done.."/"..total..")")
  end)
 end
 player:SetAttribute("StartupAssetFailures",#failed)
 if #failed>0 then warn("[Startup] "..#failed.." assets unavailable after retry; gameplay prerequisites still required.") end
 -- Recheck after downloads in case the character respawned or the plot changed.
 waitReady()
 update(1,"Ready!")
end
return M
