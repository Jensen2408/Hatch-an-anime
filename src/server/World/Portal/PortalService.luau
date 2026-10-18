--[[ ServerScriptService.Portal.PortalService  (ModuleScript, server)
  PortalService.Build(baseCFrame, parent) -> portal Model
  PortalService.Emerge(portal, characterModel, opts) -> ok, err
      opts.rarity     "Common".."Legendary" (vortex colour)       default: idle colour
      opts.parent     where the character goes                     default: workspace
      opts.target     feet CFrame where it stops                   default: in front of the gate, facing out
      opts.onComplete function(character, cancelled)
  PortalService.Cancel(portal)

The server puts the character at its final spot straight away (so it's always correct for late joiners).
Each client then plays the walk-out locally from the attributes below and lands on the same spot.
Character = the R6 rigs from RigEggCharacter (Torso/Head/Left Arm/...); animated by CharacterAnimator.
]]
local CollectionService = game:GetService("CollectionService")
local C = require(game:GetService("ReplicatedStorage"):WaitForChild("Portal"):WaitForChild("PortalConfig"))
local Builder = require(script.Parent:WaitForChild("PortalBuilder"))

local S = {}
local busy = {} -- portal -> { thread, character }

function S.Build(base, parent) return Builder.Build(base, parent) end

local function feetOrigin(model)
	local cf, size = model:GetBoundingBox()
	return CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0)) * cf.Rotation
end

local function finish(portal, cancelled)
	local b = busy[portal]; if not b then return end
	busy[portal] = nil
	if cancelled and b.thread then pcall(task.cancel, b.thread) end
	if portal.Parent then portal:SetAttribute("EmergeToken", nil) end
	local v = portal:FindFirstChild("EmergeTarget"); if v then v.Value = nil end
	if b.onComplete then task.spawn(b.onComplete, b.character, cancelled) end
end

function S.Emerge(portal, character, opts)
	opts = opts or {}
	if busy[portal] then return false, "portal busy" end
	if not (character and character:IsA("Model") and portal:FindFirstChild("Surface")) then return false, "bad portal or character" end

	local base = portal:GetPivot()
	local target = opts.target or base * CFrame.new(0, C.GroundY, -C.WalkOut)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false end
	end
	-- CharacterAnimator moves limbs relative to the model pivot; a limb PrimaryPart would drag the pivot with it
	if character.PrimaryPart then character.WorldPivot = character:GetPivot(); character.PrimaryPart = nil end
	character:PivotTo(target * feetOrigin(character):ToObjectSpace(character:GetPivot()))
	if not character:GetAttribute("Animation") then character:SetAttribute("Animation", C.EndAnimation) end
	CollectionService:AddTag(character, "AnimatedCharacter")

	local ref = portal:FindFirstChild("EmergeTarget") or Instance.new("ObjectValue")
	ref.Name = "EmergeTarget"; ref.Parent = portal
	-- set the cue first, then parent the character in the same frame (clients hide it immediately)
	ref.Value = character
	portal:SetAttribute("EmergeRarity", opts.rarity or "")
	portal:SetAttribute("EmergeStart", workspace:GetServerTimeNow())
	portal:SetAttribute("EmergeToken", (portal:GetAttribute("EmergeToken") or 0) % 1e6 + 1)
	character.Parent = opts.parent or workspace

	local b = { character = character, onComplete = opts.onComplete }
	busy[portal] = b
	b.thread = task.delay(C.Total(), function() b.thread = false; finish(portal, false) end)
	return true
end

function S.Cancel(portal) finish(portal, true) end
function S.IsBusy(portal) return busy[portal] ~= nil end

return S
