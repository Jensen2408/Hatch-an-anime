-- HALLOWEEN SWITCH
-- Turn Halloween OFF:  require(game.ServerStorage.HalloweenSwitch).Set(false)
-- Turn Halloween ON:   require(game.ServerStorage.HalloweenSwitch).Set(true)
-- Run it in the Studio command bar (Edit mode), then save/publish.
-- Whatever season is not showing is kept in ServerStorage.SeasonStorage.
local S={}
local SS=game.ServerStorage
local store=SS.SeasonStorage
local L=game.Lighting
-- Things that only exist in Halloween: {name, normal parent}
local ITEMS={
	{"PumpkinGentleman",function() return workspace end},
	{"HalloweenLights",function() return workspace.Map.Scenery end},
	{"HalloweenMapDecor",function() return workspace.Map.Scenery end},
	{"HalloweenGrade",function() return L end},
}
local function pathTo(path)
	local cur=game for seg in path:gmatch("[^%.]+") do if seg~="Workspace" or cur~=game then cur=cur:FindFirstChild(seg) else cur=workspace end if not cur then return nil end end return cur
end
local function setLighting(f)
	for k,v in pairs(f:GetAttributes()) do
		if k:sub(1,2)=="L_" then L[k:sub(3)]=v
		elseif k:sub(1,2)=="A_" then local a=L:FindFirstChildOfClass("Atmosphere") if a then a[k:sub(3)]=v end end
	end
end
local function swapColors(on)
	for _,d in ipairs(workspace:GetDescendants()) do
		local before=d:GetAttribute("BeforeHalloweenColor")
		if before~=nil and (d:IsA("BasePart") or d:IsA("SurfaceAppearance")) then
			if on then
				local h=d:GetAttribute("HalloweenSeasonColor") if h then d.Color=h end
			else
				d:SetAttribute("HalloweenSeasonColor",d.Color) d.Color=before
			end
		end
	end
end
local function rebuildTemples(theme)
	local templates=SS:FindFirstChild("TempleUpgradeTemplates")
	local Themes=require(game.ReplicatedStorage.TempleAppearanceThemes)
	for _,plot in ipairs(workspace.Plots:GetChildren()) do
		if plot:GetAttribute("TempleAppearance")~=nil then
			plot:SetAttribute("TempleAppearance",theme)
			local old=plot:FindFirstChild("Temple")
			local tpl=templates and templates:FindFirstChild("Level"..(plot:GetAttribute("TempleLevel") or 1))
			if old and tpl and plot:FindFirstChild("TempleAnchor") then
				local c=tpl:Clone() Themes.Apply(c,theme) c.Name="Temple" c:PivotTo(plot.TempleAnchor.CFrame)
				c.ModelStreamingMode=old.ModelStreamingMode c.Parent=plot old:Destroy()
			end
		end
	end
end
local function swapTrees(on)
	local from=on and store.Halloween or store.Original
	local to=on and store.Original or store.Halloween
	local away=to:FindFirstChild("Trees") or Instance.new("Folder",to) away.Name="Trees"
	-- put showing trees away
	if on then
		for _,m in ipairs(SS._ARCHIVE.BeforeHalloweenMap_1791902647.MapTrees:GetChildren()) do end
		for _,d in ipairs(workspace.Map:GetDescendants()) do
			if d:IsA("Model") and d:GetAttribute("SeasonTree")=="Original" then d.Parent=away end
		end
	else
		for _,d in ipairs(workspace:GetDescendants()) do
			if d:IsA("Model") and d.Name:match("^Halloween_") then
				d:SetAttribute("PreviousParentPath",d.Parent:GetFullName()) d:SetAttribute("SeasonTree","Halloween") d.Parent=away
			end
		end
	end
	-- bring the other set out
	local back=from:FindFirstChild("Trees")
	if back then for _,m in ipairs(back:GetChildren()) do
		local p=pathTo(m:GetAttribute("PreviousParentPath") or "") or workspace.Map.Scenery
		m:SetAttribute("SeasonTree",on and "Halloween" or "Original") m.Parent=p
	end end
end
-- Folders whose CONTENTS are swapped (e.g. egg designs): {container getter, storage name}
local SWAP_FOLDERS={
	{function() return SS.AuxEggTemplates end,"AuxEggTemplates"},
	{function() return SS.BrainrotModels end,"BrainrotModels"},
}
local function swapFolders(on)
	for _,f in ipairs(SWAP_FOLDERS) do
		local live=f[1]()
		local away=(on and store.Original or store.Halloween)
		local back=(on and store.Halloween or store.Original):FindFirstChild(f[2])
		if live and back then
			local hold=away:FindFirstChild(f[2]) or Instance.new("Folder",away) hold.Name=f[2]
			for _,c in ipairs(live:GetChildren()) do c.Parent=hold end
			for _,c in ipairs(back:GetChildren()) do c.Parent=live end
		end
	end
end
function S.Set(on)
	local current=workspace:GetAttribute("HalloweenMode")
	if current==nil then current=true end
	if current==on then return "already "..(on and "ON" or "OFF") end
	local into=on and store.Original or store.Halloween
	local out=on and store.Halloween or store.Original
	for _,it in ipairs(ITEMS) do
		if on then local o=out:FindFirstChild(it[1]) if o then o.Parent=it[2]() end
		else local o=it[2]():FindFirstChild(it[1]) if o then o.Parent=into end end
	end
	swapTrees(on)
	swapFolders(on)
	swapColors(on)
	rebuildTemples(on and "Halloween" or "Original")
	setLighting(on and store.Halloween or store.Original)
	workspace:SetAttribute("HalloweenMode",on)
	return "Halloween is now "..(on and "ON" or "OFF")
end
return S
