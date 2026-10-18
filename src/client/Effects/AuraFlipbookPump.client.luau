-- AuraFlipbookPump (LocalScript, StarterPlayerScripts)
-- Keeps flipbook auras alive: emits one crossfading particle every half lifetime (Rate is scaled to 0 on low graphics).
-- Targets every ParticleEmitter tagged "AuraFlipbook" whose part is within 160 studs of the camera.
local CollectionService = game:GetService("CollectionService")

local camera = workspace.CurrentCamera

while true do
    for _, emitter in CollectionService:GetTagged("AuraFlipbook") do
        if emitter:IsA("ParticleEmitter") and emitter.Enabled and emitter:IsDescendantOf(workspace) then
            local part = emitter.Parent
            if part:IsA("BasePart") and (part.Position - camera.CFrame.Position).Magnitude < 160 then
                emitter:Emit(1)
            end
        end
    end
    task.wait(1.5)
end
