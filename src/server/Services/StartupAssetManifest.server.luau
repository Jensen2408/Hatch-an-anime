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

local essRoots={game:GetService("StarterGui"),game:GetService("Lighting")}
for _,name in {"AuxEggTemplates","BrainrotModels"} do local r=SS:FindFirstChild(name);if r then table.insert(essRoots,r) end end
local ess=Instance.new("StringValue")
ess.Name="StartupAssetManifestEssential"
ess.Value=game:GetService("HttpService"):JSONEncode(Loader.Collect(essRoots))
ess.Parent=RS
