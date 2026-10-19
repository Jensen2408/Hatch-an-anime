--[[ StartupAssetManifest (Script, ServerScriptService)
Builds the content-ID manifests that ReplicatedFirst.StartupLoader preloads on the client, including
gameplay templates in ServerStorage that are never replicated (the client could not scan them itself).

Contract with StartupLoader.Run (client):
  ReplicatedStorage.StartupAssetManifest           StringValue, JSON array of { id = contentId, kind = "Mesh" | "Sound" | "Animation" | "Image" }
                                                   - everything; preloaded after the essentials
  ReplicatedStorage.StartupAssetManifestEssential  StringValue, same shape - what the player sees first (HUD,
                                                   eggs, characters); preloaded first
Both lists come from StartupLoader.Collect, so the entry shape is defined in one place. The values are written
once at server start; a client that joins before they exist simply scans its own replicated instances.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
-- Server-side require: only Collect is used here (pure scan, no yielding).
local StartupLoader = require(game:GetService("ReplicatedFirst"):WaitForChild("StartupLoader"))
-- ===== 1. Full manifest =====
local manifestRoots = {
    workspace,
    ReplicatedStorage,
    game:GetService("Lighting"),
    game:GetService("MaterialService"),
    game:GetService("StarterGui"),
}
for _, name in
    {
        "BrainrotModels",
        "AuxEggTemplates",
        "EggTemplates",
        "TempleUpgradeTemplates",
        "IncubatorUpgradeTemplates",
        "HatchChamberTemplate",
        "Weapons",
        "FutureUpdateContent",
    }
do
    local root = ServerStorage:FindFirstChild(name)
    if root then
        table.insert(manifestRoots, root)
    end
end
local assetIds = StartupLoader.Collect(manifestRoots)
local manifest = Instance.new("StringValue")
manifest.Name = "StartupAssetManifest"
manifest.Value = game:GetService("HttpService"):JSONEncode(assetIds)
manifest.Parent = ReplicatedStorage

-- ===== 2. Essential manifest (loaded first) =====
local essentialRoots = { game:GetService("StarterGui"), game:GetService("Lighting") }
for _, name in { "AuxEggTemplates", "BrainrotModels" } do
    local root = ServerStorage:FindFirstChild(name)
    if root then
        table.insert(essentialRoots, root)
    end
end
local essentialManifest = Instance.new("StringValue")
essentialManifest.Name = "StartupAssetManifestEssential"
essentialManifest.Value = game:GetService("HttpService"):JSONEncode(StartupLoader.Collect(essentialRoots))
essentialManifest.Parent = ReplicatedStorage
