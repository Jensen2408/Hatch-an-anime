--[[ StarterPlayer.StarterPlayerScripts.RainbowMutationClient (LocalScript)
Rainbow-mutation characters cycle through RGB. ServerScriptService.Mutations gives every Rainbow v2 character a bright
pearl colour map and the tag "RainbowMutation"; this script multiplies that map by a hue that keeps turning
(SurfaceAppearance.Color), on placed displays, held tools and incubator reveals alike. Client only, nothing replicates.
Models further than RANGE studs from the camera are skipped.
]]
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "RainbowMutation"
local CYCLE_SECONDS = 10 -- one full trip around the colour wheel (2026-11-12: was 4, Jacob asked for a slower strobe)
local SATURATION = 0.8
local RANGE = 200

local tracked = {} -- [Model] = { surfaces = { SurfaceAppearance }, offset = number }

local function track(model)
    if not model:IsA("Model") or tracked[model] then
        return
    end
    local surfaces = {}
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("SurfaceAppearance") then
            table.insert(surfaces, descendant)
        end
    end
    -- each model starts at its own hue so a row of rainbow characters doesn't pulse in sync
    tracked[model] = { surfaces = surfaces, offset = (#model:GetFullName() % 17) / 17 }
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
    tracked[model] = nil
end)
for _, model in CollectionService:GetTagged(TAG) do
    track(model)
end

RunService.RenderStepped:Connect(function()
    local camera = workspace.CurrentCamera
    local cameraPosition = camera and camera.CFrame.Position
    local now = os.clock() / CYCLE_SECONDS
    for model, info in tracked do
        if not model.Parent then
            tracked[model] = nil
        elseif
            not cameraPosition
            or not model:IsDescendantOf(workspace)
            or (model:GetPivot().Position - cameraPosition).Magnitude < RANGE
        then
            local color = Color3.fromHSV((now + info.offset) % 1, SATURATION, 1)
            for _, surface in info.surfaces do
                surface.Color = color
            end
        end
    end
end)
