--[[ StarterPlayerScripts.GoldenLuffyIdle  (LocalScript)
Subtle Motor6D idle (shoulder sway, neck nod, root bob) for the golden Luffy models, client-only.
Targets any workspace Model named "LUFFY GOLD", or a "HatchedCharacter" with the "Golden" attribute.
The HumanoidRootPart is anchored, all other parts are unanchored and non-colliding so the joints drive them.
Only models within IDLE_DISTANCE studs of the camera are animated.
]]
local RunService = game:GetService("RunService")

local IDLE_DISTANCE = 100

local active = {} -- [Model] = { root = BasePart, joints = { [Motor6D] = rest C0 } }

local function add(model)
    if not model:IsA("Model") or active[model] then
        return
    end
    if model.Name ~= "LUFFY GOLD" and not (model.Name == "HatchedCharacter" and model:GetAttribute("Golden")) then
        return
    end
    local rootPart = model:FindFirstChild("HumanoidRootPart", true)
    if not rootPart then
        return
    end
    local joints = {}
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("Motor6D") then
            joints[descendant] = descendant.C0
        elseif descendant:IsA("BasePart") then
            descendant.Anchored = descendant == rootPart
            descendant.CanCollide = false
        end
    end
    active[model] = { root = rootPart, joints = joints }
end

-- deferred so a freshly added model's descendants (name, joints) have arrived
workspace.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("Model") then
        task.defer(add, descendant)
    end
end)
for _, descendant in ipairs(workspace:GetDescendants()) do
    if descendant:IsA("Model") then
        add(descendant)
    end
end

RunService:BindToRenderStep("GoldenLuffyIdle", Enum.RenderPriority.Camera.Value + 3, function()
    local now = os.clock()
    for model, data in pairs(active) do
        if not model:IsDescendantOf(workspace) then
            active[model] = nil
        elseif
            workspace.CurrentCamera
            and (workspace.CurrentCamera.CFrame.Position - data.root.Position).Magnitude < IDLE_DISTANCE
        then
            for motor, restC0 in pairs(data.joints) do
                if motor.Parent then
                    local angle = math.sin(now * 1.8) * 0.045
                    if motor.Name == "Right Shoulder" then
                        motor.C0 = restC0 * CFrame.Angles(0, 0, angle)
                    elseif motor.Name == "Left Shoulder" then
                        motor.C0 = restC0 * CFrame.Angles(0, 0, -angle)
                    elseif motor.Name == "Neck" then
                        motor.C0 = restC0 * CFrame.Angles(math.sin(now * 1.1) * 0.025, 0, 0)
                    elseif motor.Name == "RootJoint" then
                        motor.C0 = restC0 * CFrame.new(0, math.sin(now * 1.8) * 0.035, 0)
                    end
                end
            end
        end
    end
end)
