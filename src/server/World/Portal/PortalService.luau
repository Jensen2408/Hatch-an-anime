--[[ ServerScriptService.Portal.PortalService  (ModuleScript, server)
  PortalService.Build(baseCFrame, parent) -> portal Model
  PortalService.Emerge(portal, characterModel, opts) -> ok, err
      opts.rarity     "Common".."Legendary" (vortex colour)       default: idle colour
      opts.parent     where the character goes                     default: workspace
      opts.target     feet CFrame where it stops                   default: in front of the gate, facing out
      opts.onComplete function(character, cancelled)
  PortalService.Cancel(portal)
  PortalService.IsBusy(portal) -> bool

The server puts the character at its final spot straight away (so it's always correct for late joiners).
Each client then plays the walk-out locally from the attributes below and lands on the same spot.
Character = the R6 rigs from RigEggCharacter (Torso/Head/Left Arm/...); animated by CharacterAnimator.
Client cue on the portal: EmergeTarget (ObjectValue -> character), EmergeRarity, EmergeStart (server time),
EmergeToken (incremented per emerge; read by PortalClient).
]]
local CollectionService = game:GetService("CollectionService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Portal"):WaitForChild("PortalConfig"))
local Builder = require(script.Parent:WaitForChild("PortalBuilder"))

local PortalService = {}
local busy = {} -- portal -> { thread, character, onComplete }

function PortalService.Build(base, parent)
    return Builder.Build(base, parent)
end

-- Bottom-centre of the model's bounding box, keeping its rotation.
local function feetOrigin(model)
    local boxCFrame, size = model:GetBoundingBox()
    return CFrame.new(boxCFrame.Position - Vector3.new(0, size.Y / 2, 0)) * boxCFrame.Rotation
end

-- Ends an emerge: clears the client cue (EmergeToken / EmergeTarget) and runs onComplete once.
local function finish(portal, cancelled)
    local emergeJob = busy[portal]
    if not emergeJob then
        return
    end
    busy[portal] = nil
    if cancelled and emergeJob.thread then
        pcall(task.cancel, emergeJob.thread)
    end
    if portal.Parent then
        portal:SetAttribute("EmergeToken", nil)
    end
    local targetValue = portal:FindFirstChild("EmergeTarget")
    if targetValue then
        targetValue.Value = nil
    end
    if emergeJob.onComplete then
        task.spawn(emergeJob.onComplete, emergeJob.character, cancelled)
    end
end

function PortalService.Emerge(portal, character, opts)
    opts = opts or {}
    if busy[portal] then
        return false, "portal busy"
    end
    if not (character and character:IsA("Model") and portal:FindFirstChild("Surface")) then
        return false, "bad portal or character"
    end

    local gatePivot = portal:GetPivot()
    local target = opts.target or gatePivot * CFrame.new(0, Config.GroundY, -Config.WalkOut)
    for _, descendant in character:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CanCollide = false
        end
    end
    -- CharacterAnimator moves limbs relative to the model pivot; a limb PrimaryPart would drag the pivot with it
    if character.PrimaryPart then
        character.WorldPivot = character:GetPivot()
        character.PrimaryPart = nil
    end
    character:PivotTo(target * feetOrigin(character):ToObjectSpace(character:GetPivot()))
    if not character:GetAttribute("Animation") then
        character:SetAttribute("Animation", Config.EndAnimation)
    end
    CollectionService:AddTag(character, "AnimatedCharacter")

    local targetValue = portal:FindFirstChild("EmergeTarget") or Instance.new("ObjectValue")
    targetValue.Name = "EmergeTarget"
    targetValue.Parent = portal
    -- set the cue first, then parent the character in the same frame (clients hide it immediately)
    targetValue.Value = character
    portal:SetAttribute("EmergeRarity", opts.rarity or "")
    portal:SetAttribute("EmergeStart", workspace:GetServerTimeNow())
    portal:SetAttribute("EmergeToken", (portal:GetAttribute("EmergeToken") or 0) % 1e6 + 1)
    character.Parent = opts.parent or workspace

    local emergeJob = { character = character, onComplete = opts.onComplete }
    busy[portal] = emergeJob
    emergeJob.thread = task.delay(Config.Total(), function()
        emergeJob.thread = false
        finish(portal, false)
    end)
    return true
end

function PortalService.Cancel(portal)
    finish(portal, true)
end
function PortalService.IsBusy(portal)
    return busy[portal] ~= nil
end

return PortalService
