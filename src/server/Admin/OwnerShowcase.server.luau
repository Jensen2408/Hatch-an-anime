-- OwnerShowcase: a statue of the owner (real avatar) with the KitsBlox aura, ONLY on the owner's own temple.
local Players = game:GetService("Players")
local OWNER = 168774222
local plots = workspace:WaitForChild("Plots")
local auraTemplate = game:GetService("ServerStorage"):WaitForChild("OwnerShowcaseAura")
local current
for _, p in workspace:WaitForChild("Plots"):GetChildren() do
    local mk = p:FindFirstChild("OwnerShowcaseSpot")
    if mk then
        mk.Transparency = 1
    end
end

local function clear()
    if current then
        current:Destroy()
        current = nil
    end
end

local function build(plot)
    clear()
    local spawn = plot:FindFirstChild("PlotSpawn")
    if not spawn then
        return
    end
    local ok, desc = pcall(Players.GetHumanoidDescriptionFromUserId, Players, OWNER)
    if not ok then
        warn("[OwnerShowcase] avatar load failed", desc)
        return
    end
    local ok2, rig = pcall(Players.CreateHumanoidModelFromDescription, Players, desc, Enum.HumanoidRigType.R15)
    if not ok2 then
        warn("[OwnerShowcase]", rig)
        return
    end
    rig.Name = "OwnerShowcase"
    local hum = rig:FindFirstChildOfClass("Humanoid")
    hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    hum.BreakJointsOnDeath = false
    for _, p in rig:GetDescendants() do
        if p:IsA("BasePart") then
            p.CanCollide = false
            p.CanQuery = false
            p.CanTouch = false
            p.Anchored = false
        end
    end
    local root = rig:WaitForChild("HumanoidRootPart")
    root.Anchored = true
    -- stand beside the spawn, facing the player as they arrive
    local s = spawn.CFrame
    local fwd = Vector3.new(s.LookVector.X, 0, s.LookVector.Z).Unit
    -- spot = the purple "OwnerShowcaseSpot" block in TemplePlot01 (drag it in Studio to move the statue).
    -- Its position relative to TemplePlot01's spawn is reused on whichever plot the owner gets.
    local marker = workspace.Plots:FindFirstChild("TemplePlot01")
        and workspace.Plots.TemplePlot01:FindFirstChild("OwnerShowcaseSpot")
    local spotCF
    if marker then
        local rel = workspace.Plots.TemplePlot01.PlotSpawn.CFrame:ToObjectSpace(marker.CFrame)
        spotCF = s * rel
    else
        local pos = s.Position - fwd * 4 + s.RightVector * 8
        spotCF = CFrame.lookAt(pos, Vector3.new(s.Position.X, pos.Y, s.Position.Z))
    end
    local h = hum.HipHeight + root.Size.Y / 2
    local feetY = spotCF.Position.Y - (marker and marker.Size.Y / 2 or 0)
    root.CFrame = CFrame.new(spotCF.Position.X, feetY + h, spotCF.Position.Z) * (spotCF - spotCF.Position)
    -- aura on the body
    local aura = auraTemplate:Clone()
    aura.Name = "Aura"
    aura.Anchored = false
    aura.CFrame = root.CFrame
    local w = Instance.new("WeldConstraint")
    w.Part0 = root
    w.Part1 = aura
    w.Parent = aura
    aura.Parent = rig
    rig.Parent = plot
    -- idle animation so it looks alive, not frozen
    local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://507766388"
    local ok3, track = pcall(animator.LoadAnimation, animator, anim)
    if ok3 and track then
        track.Looped = true
        track:Play()
    end
    current = rig
end

local function check()
    for _, plot in plots:GetChildren() do
        if plot:GetAttribute("OwnerUserId") == OWNER then
            if not (current and current.Parent == plot) then
                build(plot)
            end
            return
        end
    end
    clear()
end
for _, plot in plots:GetChildren() do
    plot:GetAttributeChangedSignal("OwnerUserId"):Connect(check)
end
plots.ChildAdded:Connect(function(p)
    p:GetAttributeChangedSignal("OwnerUserId"):Connect(check)
end)
check()
