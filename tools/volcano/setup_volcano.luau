--[[ tools/volcano/setup_volcano.luau: run in Studio (command bar, or an MCP execute_luau in Edit mode) right after importing FarVolcano.glb.
It finishes the imported volcano so it works with the Volcano Eruption event:
  1. replaces the previous Workspace.FarVolcano (the one with the attribute ManualPlace) with the new import, keeping its place
     (centre x / z and its lowest point), or just uses the new one where it landed if there is no old one
  2. turns the model about its centre so the OPENING in the crater's rim faces the map (toward x = 0, z = 0), found by raycasting a ring just
     inside the rim and taking the lowest point
  3. on every MeshPart: anchored, no collision / touch / shadows, CanQuery on (the flows are laid by raycasting), Plastic with the
     "Incubator One Stud Cavity" variant, EmissiveMaskContent from emissive_ids.json, EmissiveTint (255,150,60), EmissiveStrength 0
  4. attribute ManualPlace = true and Persistent streaming
Fill EMISSIVE from assets/Volcano/emissive_ids.json (uploaded masks) before running. ]]
local EMISSIVE = { S1 = 123765265008842, S2 = 123765265008842, S3 = 123765265008842, S4 = 123765265008842, S5 = 123765265008842, S6 = 123765265008842, S7 = 123765265008842, S8 = 110245954805345, S9 = 134289558024090 }
local COLOR = { S1 = 91057401424667, S2 = 137711700548656, S3 = 81504297165788, S4 = 133335444790918, S5 = 89321068038879, S6 = 132458354712271, S7 = 70756323052654, S8 = 132719087372371, S9 = 124899494675911 }
local NORMAL = { S1 = 108669205068766, S2 = 108705082556581, S3 = 97058665822916, S4 = 91175222066635, S5 = 119571529139001, S6 = 108913843964993, S7 = 109498852079175, S8 = 88637828747257, S9 = 79417054280657 }
local MAP_CENTRE = Vector3.new(0, 0, 0)
local OPENING_RING = 98 -- studs from the crater's centre: inside the opening's strip (88 to 110)

local function bounds(model)
    local mn, mx = Vector3.one * math.huge, Vector3.one * -math.huge
    for _, d in model:GetDescendants() do
        if d:IsA("BasePart") then
            local h = d.Size / 2
            for sx = -1, 1, 2 do
                for sy = -1, 1, 2 do
                    for sz = -1, 1, 2 do
                        local p = d.CFrame:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz))
                        mn = Vector3.new(math.min(mn.X, p.X), math.min(mn.Y, p.Y), math.min(mn.Z, p.Z))
                        mx = Vector3.new(math.max(mx.X, p.X), math.max(mx.Y, p.Y), math.max(mx.Z, p.Z))
                    end
                end
            end
        end
    end
    return mn, mx
end

local old, new
for _, child in workspace:GetChildren() do
    if child.Name == "FarVolcano" and child:IsA("Model") then
        if child:GetAttribute("ManualPlace") then
            old = child
        else
            new = child
        end
    end
end
assert(new, "no freshly imported FarVolcano found (one without ManualPlace)")

-- 1. where the old one stood
local target
if old then
    local omn, omx = bounds(old)
    target = Vector3.new((omn.X + omx.X) / 2, omn.Y, (omn.Z + omx.Z) / 2)
end
local function placeAt(position)
    local mn, mx = bounds(new)
    new:PivotTo(new:GetPivot() + (position - Vector3.new((mn.X + mx.X) / 2, mn.Y, (mn.Z + mx.Z) / 2)))
end
if target then
    placeAt(target)
    old:Destroy()
end

-- 3. properties first (the raycast below needs CanQuery)
for _, d in new:GetDescendants() do
    if d:IsA("BasePart") then
        d.Anchored, d.CanCollide, d.CanTouch, d.CanQuery, d.CastShadow = true, false, false, true, false
    end
    if d:IsA("MeshPart") then
        d.Material = Enum.Material.Plastic
        d.MaterialVariant = "Incubator One Stud Cavity"
        d.RenderFidelity = Enum.RenderFidelity.Precise
        local key = d.Name:match("_S(%d)$")
        local appearance = d:FindFirstChildOfClass("SurfaceAppearance")
        if appearance and key and EMISSIVE["S" .. key] then
            appearance.ColorMapContent = Content.fromUri("rbxassetid://" .. COLOR["S" .. key])
            appearance.NormalMapContent = Content.fromUri("rbxassetid://" .. NORMAL["S" .. key])
            appearance.EmissiveMaskContent = Content.fromUri("rbxassetid://" .. EMISSIVE["S" .. key])
            appearance.EmissiveTint = Color3.fromRGB(255, 150, 60)
            appearance.EmissiveStrength = 0
        end
    end
end

-- 2. turn the opening toward the map
local mn, mx = bounds(new)
local centre = Vector3.new((mn.X + mx.X) / 2, 0, (mn.Z + mx.Z) / 2)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { new }
local lowest, lowestAngle, highest = math.huge, nil, -math.huge
for step = 0, 71 do
    local angle = step / 72 * math.pi * 2
    local x, z = centre.X + math.cos(angle) * OPENING_RING, centre.Z + math.sin(angle) * OPENING_RING
    local hit = workspace:Raycast(Vector3.new(x, mx.Y + 100, z), Vector3.new(0, -(mx.Y - mn.Y + 300), 0), params)
    if hit then
        if hit.Position.Y < lowest then
            lowest, lowestAngle = hit.Position.Y, angle
        end
        highest = math.max(highest, hit.Position.Y)
    end
end
local report = ("opening found: %s (rim ring %.0f..%.0f)"):format(tostring(lowestAngle and highest - lowest > 25), lowest, highest)
if lowestAngle and highest - lowest > 25 then
    local toMap = Vector3.new(MAP_CENTRE.X - centre.X, 0, MAP_CENTRE.Z - centre.Z)
    local wanted = math.atan2(toMap.Z, toMap.X)
    local turn = wanted - lowestAngle -- radians to turn about +Y (x/z plane angle, so the sign is the CFrame.Angles one with y flipped)
    new:PivotTo(CFrame.new(centre) * CFrame.Angles(0, -turn, 0) * CFrame.new(-centre) * new:GetPivot())
    report ..= (", turned %.0f degrees to face the map"):format(math.deg(turn))
end

-- 4.
new:SetAttribute("ManualPlace", true)
new.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
local inner = new:FindFirstChild("FarVolcano")
if inner and inner:IsA("Model") then
    inner.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
end
return report
