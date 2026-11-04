--[[ StarterPlayerScripts.V2MoveClient (LocalScript)
Plays a v2 character's signature move once, client-side only, then leaves it in its original stance.
  * placed     = a model tagged "FloatingCharacter" with attribute V2Move plays as soon as it appears
  * preview    = a ProximityPrompt named "V2Preview" inside the model plays it on demand
Moves are ModuleScripts in ReplicatedStorage.V2Moves (generated from Blender), Bone.Transform per frame.
While a move plays the model has attribute V2Playing, FloatingCharacters holds its spin for that time.
]]
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TAG = "FloatingCharacter"
local RANGE = 150
local BASE_SCALE = 6
local folder = ReplicatedStorage:WaitForChild("V2Moves")
local FX = require(folder:WaitForChild("V2MoveFX"))
local clips = {}

local function clip(name)
	if clips[name] then
		return clips[name]
	end
	local module = folder:FindFirstChild(name)
	if not module then
		return nil
	end
	local data = require(module)
	local bones = {}
	for bone, flat in data.Bones do
		local frames = {}
		for i = 1, #flat, 7 do
			table.insert(frames, CFrame.new(flat[i], flat[i + 1], flat[i + 2], flat[i + 3], flat[i + 4], flat[i + 5], flat[i + 6]))
		end
		bones[bone] = frames
	end
	clips[name] = { Rate = data.Rate, Length = data.Length, Events = data.Events, Bones = bones }
	return clips[name]
end

local function play(model)
	local c = clip(model:GetAttribute("V2Move"))
	if not c or model:GetAttribute("V2Playing") then
		return
	end
	local bones = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Bone") and c.Bones[d.Name] then
			bones[d] = c.Bones[d.Name]
		end
	end
	if not next(bones) then
		return
	end
	model:SetAttribute("V2Playing", true)
	local size = model:GetScale() / BASE_SCALE
	local rootBone = model:FindFirstChild("Root", true)
	local nextEvent, t0 = 1, os.clock()
	local conn
	conn = RunService.Stepped:Connect(function()
		local t = os.clock() - t0
		if t >= c.Length or not model.Parent then
			conn:Disconnect()
			for bone in bones do
				bone.Transform = CFrame.identity
			end
			model:SetAttribute("V2Playing", nil)
			return
		end
		local f = t * c.Rate
		local i, a = math.floor(f) + 1, f % 1
		for bone, frames in bones do
			local cf = frames[i]:Lerp(frames[i + 1] or frames[i], a)
			bone.Transform = size == 1 and cf or (cf - cf.Position) + cf.Position * size
		end
		local e = c.Events[nextEvent]
		if e and t >= e[1] then
			nextEvent += 1
			local fx = FX[e[2]]
			if fx and e[3] then
				local home = rootBone and rootBone.WorldCFrame or model:GetPivot() -- the bone's rest place, Transform does not change it
				local spot = home * CFrame.new(e[4] * size, e[5] * size, e[6] * size)
				task.spawn(fx, model, Color3.fromHex(e[3]), spot, size)
			elseif fx then
				task.spawn(fx, model)
			end
		end
	end)
end

local function near(model)
	local camera = workspace.CurrentCamera
	return camera and (model:GetPivot().Position - camera.CFrame.Position).Magnitude <= RANGE
end

local function placed(model)
	local deadline = os.clock() + 5
	while model.Parent and not model:FindFirstChild("Root", true) and os.clock() < deadline do
		task.wait(0.1) -- bones stream in with the model
	end
	task.wait(0.5)
	if model.Parent and near(model) then
		play(model)
	end
end

local function watchPrompt(prompt)
	if prompt:IsA("ProximityPrompt") and prompt.Name == "V2Preview" then
		prompt.Triggered:Connect(function()
			play(prompt:FindFirstAncestorOfClass("Model"))
		end)
	end
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model)
	if model:GetAttribute("V2Move") then
		placed(model)
	end
end)
for _, d in workspace:GetDescendants() do
	watchPrompt(d)
end
workspace.DescendantAdded:Connect(watchPrompt)
folder:WaitForChild("Play").Event:Connect(play) -- testing: fire with a model to play its move
