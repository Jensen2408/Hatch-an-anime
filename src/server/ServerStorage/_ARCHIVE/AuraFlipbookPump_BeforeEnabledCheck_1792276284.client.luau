-- Keeps flipbook auras alive: emits one crossfading particle every half lifetime (Rate is scaled to 0 on low graphics).
local CS = game:GetService("CollectionService")
local cam = workspace.CurrentCamera
while true do
	for _, e in CS:GetTagged("AuraFlipbook") do
		if e:IsA("ParticleEmitter") and e:IsDescendantOf(workspace) then
			local p = e.Parent
			if p:IsA("BasePart") and (p.Position - cam.CFrame.Position).Magnitude < 160 then e:Emit(1) end
		end
	end
	task.wait(1.5)
end