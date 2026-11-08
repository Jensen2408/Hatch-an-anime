-- Studio edit-mode restoration for group-owned projected coating meshes.
local folder=game.ReplicatedStorage:FindFirstChild("ProjectedCoatingMeshes") or Instance.new("Folder")
folder.Name="ProjectedCoatingMeshes" folder.Parent=game.ReplicatedStorage
for _,id in {124085908780687,128071511330035,84195886055723,126935452003226,138901682638208,96777148616075,127494696769079,80667011072238,71946342962753,111731632362754,108198659657250,132967575540418,132410566943213,80751847952599,136407826231247,83968469563582,89218848623812} do
 local root=game:GetService("InsertService"):LoadAsset(id)
 for _,p in root:GetDescendants() do if p:IsA("MeshPart") and not folder:FindFirstChild(p.Name) then
  local c=p:Clone() c:ClearAllChildren() c.Anchored=true c.CanCollide=false c.Parent=folder
 end end
 root:Destroy() task.wait(.2)
end
game:GetService("ChangeHistoryService"):SetWaypoint("Restore projected mutation coatings")
return #folder:GetChildren()
