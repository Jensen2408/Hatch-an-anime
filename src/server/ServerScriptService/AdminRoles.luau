-- Who can open the panel. Owner = everything. Admin = events, river spawns, announcements, teleports, respawn, kick.
-- Add permanent admins here by User ID, or use the Admins page in the owner panel (saved in a DataStore).
local Players=game:GetService("Players")
local DSS=game:GetService("DataStoreService")
local M={}
M.Owners={[168774222]=true}
M.Admins={
	[353101613]=true, -- CO-OWNER tag
}
-- Actions an Admin may use (everything else is owner-only)
M.AdminActions={Snapshot=true,SpawnEgg=true,EggShower=true,StartEvent=true,StopEvent=true,StartNight=true,StopNight=true,SetSpawnInterval=true,
	SendHome=true,Bring=true,GoTo=true,SendToPlayer=true,Respawn=true,Kick=true,Announce=true,JoinStaffServer=true,ReturnToPublic=true,AnnounceUpdate=true}
local saved={} -- [userId]=name (from DataStore)
local store do local ok,s=pcall(DSS.GetDataStore,DSS,"PanelAdmins_v1") store=ok and s or nil end
pcall(function() local data=store and store:GetAsync("list") if type(data)=="table" then for k,v in pairs(data) do saved[tonumber(k)]=v end end end)
function M.Role(who)
	local id=typeof(who)=="Instance" and who.UserId or tonumber(who)
	if not id then return nil end
	-- Studio testing only: workspace attribute StudioTestRole="Admin" makes the owner act as an admin
	if game:GetService("RunService"):IsStudio() and M.Owners[id] and workspace:GetAttribute("StudioTestRole")=="Admin" then return "Admin" end
	if M.Owners[id] then return "Owner" end
	if M.Admins[id] or saved[id] then return "Admin" end
	return nil
end
function M.Can(player,action)
	local r=M.Role(player)
	return r=="Owner" or (r=="Admin" and M.AdminActions[action]==true)
end
function M.List()
	local t={}
	for id in pairs(M.Admins) do table.insert(t,{userId=id,name=saved[id] or tostring(id),fixed=true}) end
	for id,name in pairs(saved) do if not M.Admins[id] then table.insert(t,{userId=id,name=name,fixed=false}) end end
	return t
end
local function publish(id) local p=Players:GetPlayerByUserId(id) if p then p:SetAttribute("PanelRole",M.Role(p)) end end
function M.SetAdmin(id,name,on)
	id=tonumber(id) assert(id and id>0 and id%1==0,"Enter a numeric User ID.")
	assert(not M.Owners[id],"The owner can't be changed.")
	assert(not (M.Admins[id] and not on),"That admin is in the AdminRoles script; remove them there.")
	saved[id]=on and (name or tostring(id)) or nil
	local persisted=false
	if store then
		persisted=pcall(function() store:UpdateAsync("list",function(old) old=type(old)=="table" and old or {} old[tostring(id)]=on and (name or tostring(id)) or nil return old end) end)
	end
	publish(id) return persisted
end
local function onJoin(p) p:SetAttribute("PanelRole",M.Role(p)) end
Players.PlayerAdded:Connect(onJoin) for _,p in ipairs(Players:GetPlayers()) do onJoin(p) end
return M
