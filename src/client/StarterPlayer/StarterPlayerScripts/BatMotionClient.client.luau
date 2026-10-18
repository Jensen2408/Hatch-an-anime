-- BatMotionClient: play the uploaded bat swing through the character Animator.
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local SWING_COOLDOWN = 1.1
local animation = Instance.new("Animation")
animation.Name = "BatSwing"
animation.AnimationId = "rbxassetid://127841018476619"
animation.Parent = script

-- Owner-started Animator tracks replicate to the other players automatically.
local hookedTools = setmetatable({}, { __mode = "k" })

local function hookTool(tool, character)
	if not tool:IsA("Tool") or tool.Name ~= "WoodenBat" or hookedTools[tool] then return end
	hookedTools[tool] = true
	local track
	local lastSwing = -math.huge

	local function stopSwing()
		if track then
			track:Stop(0.1)
			track:Destroy()
			track = nil
		end
	end

	tool.Activated:Connect(function()
		if tool.Parent ~= character or character ~= localPlayer.Character then return end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if not animator or humanoid.Health <= 0 then return end
		local now = os.clock()
		if now - lastSwing < SWING_COOLDOWN then return end
		lastSwing = now

		if not track then
			local ok, result = pcall(function()
				return animator:LoadAnimation(animation)
			end)
			if not ok then
				warn("Unable to load bat swing animation:", result)
				return
			end
			track = result
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = false
		end
		if track.IsPlaying then return end
		track:Play(0.05)
	end)
	tool.Unequipped:Connect(stopSwing)
	tool.AncestryChanged:Connect(function()
		if tool.Parent ~= character then stopSwing() end
	end)
	tool.Destroying:Connect(stopSwing)
end

local function watchCharacter(character)
	character.ChildAdded:Connect(function(child)
		hookTool(child, character)
	end)
	for _, child in ipairs(character:GetChildren()) do
		hookTool(child, character)
	end
end

localPlayer.CharacterAdded:Connect(watchCharacter)
if localPlayer.Character then watchCharacter(localPlayer.Character) end