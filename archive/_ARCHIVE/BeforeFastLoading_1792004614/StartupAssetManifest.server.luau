-- Build a content-ID manifest, including gameplay templates not yet replicated.
local RS=game:GetService("ReplicatedStorage")
local SS=game:GetService("ServerStorage")
local Loader=require(game:GetService("ReplicatedFirst"):WaitForChild("StartupLoader"))
local roots={workspace,RS,game:GetService("Lighting"),game:GetService("MaterialService"),game:GetService("StarterGui")}
for _,name in {"BrainrotModels","AuxEggTemplates","EggTemplates","TempleUpgradeTemplates","IncubatorUpgradeTemplates","HatchChamberTemplate","Weapons","FutureUpdateContent"} do
 local root=SS:FindFirstChild(name);if root then table.insert(roots,root) end
end
local ids=Loader.Collect(roots)
local manifest=Instance.new("StringValue")
manifest.Name="StartupAssetManifest"
manifest.Value=game:GetService("HttpService"):JSONEncode(ids)
manifest.Parent=RS
