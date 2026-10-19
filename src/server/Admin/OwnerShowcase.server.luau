--[[ ServerScriptService.OwnerShowcase  (Script, Disabled in the Rojo project)
A statue of the owner (real avatar, R15, idle animation) with the KitsBlox aura (ServerStorage.OwnerShowcaseAura), shown ONLY
on the plot whose OwnerUserId is the owner. Rebuilt when plot ownership changes. No remotes. Owner UserId hard-coded.
]]
-- ===== 1. Setup (hides the OwnerShowcaseSpot markers) =====
local Players = game:GetService("Players")
local OWNER_USER_ID = 168774222
local plots = workspace:WaitForChild("Plots")
local auraTemplate = game:GetService("ServerStorage"):WaitForChild("OwnerShowcaseAura")
local currentStatue
for _, plot in workspace:WaitForChild("Plots"):GetChildren() do
    local spot = plot:FindFirstChild("OwnerShowcaseSpot")
    if spot then
        spot.Transparency = 1
    end
end

-- ===== 2. Statue =====
local function clearStatue()
    if currentStatue then
        currentStatue:Destroy()
        currentStatue = nil
    end
end

local function buildStatue(plot)
    clearStatue()
    local plotSpawn = plot:FindFirstChild("PlotSpawn")
    if not plotSpawn then
        return
    end
    local ok, desc = pcall(Players.GetHumanoidDescriptionFromUserId, Players, OWNER_USER_ID)
    if not ok then
        warn("[OwnerShowcase] avatar load failed", desc)
        return
    end
    local rigOk, rig = pcall(Players.CreateHumanoidModelFromDescription, Players, desc, Enum.HumanoidRigType.R15)
    if not rigOk then
        warn("[OwnerShowcase]", rig)
        return
    end
    rig.Name = "OwnerShowcase"
    local humanoid = rig:FindFirstChildOfClass("Humanoid")
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.BreakJointsOnDeath = false
    for _, part in rig:GetDescendants() do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.CanQuery = false
            part.CanTouch = false
            part.Anchored = false
        end
    end
    local root = rig:WaitForChild("HumanoidRootPart")
    root.Anchored = true
    -- stand beside the spawn, facing the player as they arrive
    local spawnCFrame = plotSpawn.CFrame
    local forward = Vector3.new(spawnCFrame.LookVector.X, 0, spawnCFrame.LookVector.Z).Unit
    -- spot = the purple "OwnerShowcaseSpot" block in TemplePlot01 (drag it in Studio to move the statue).
    -- Its position relative to TemplePlot01's spawn is reused on whichever plot the owner gets.
    local marker = workspace.Plots:FindFirstChild("TemplePlot01")
        and workspace.Plots.TemplePlot01:FindFirstChild("OwnerShowcaseSpot")
    local spotCF
    if marker then
        local offsetFromSpawn = workspace.Plots.TemplePlot01.PlotSpawn.CFrame:ToObjectSpace(marker.CFrame)
        spotCF = spawnCFrame * offsetFromSpawn
    else
        local pos = spawnCFrame.Position - forward * 4 + spawnCFrame.RightVector * 8
        spotCF = CFrame.lookAt(pos, Vector3.new(spawnCFrame.Position.X, pos.Y, spawnCFrame.Position.Z))
    end
    local rootHeight = humanoid.HipHeight + root.Size.Y / 2
    local feetY = spotCF.Position.Y - (marker and marker.Size.Y / 2 or 0)
    root.CFrame = CFrame.new(spotCF.Position.X, feetY + rootHeight, spotCF.Position.Z) * (spotCF - spotCF.Position)
    -- aura on the body
    local aura = auraTemplate:Clone()
    aura.Name = "Aura"
    aura.Anchored = false
    aura.CFrame = root.CFrame
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = root
    weld.Part1 = aura
    weld.Parent = aura
    aura.Parent = rig
    rig.Parent = plot
    -- idle animation so it looks alive, not frozen
    local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid) -- deprecated parent arg (kept)
    local animation = Instance.new("Animation")
    animation.AnimationId = "rbxassetid://507766388"
    local trackOk, track = pcall(animator.LoadAnimation, animator, animation)
    if trackOk and track then
        track.Looped = true
        track:Play()
    end
    currentStatue = rig
end

-- ===== 3. Follow plot ownership =====
-- Note: plots added later are watched but refreshStatue is not called for them until an attribute change.
local function refreshStatue()
    for _, plot in plots:GetChildren() do
        if plot:GetAttribute("OwnerUserId") == OWNER_USER_ID then
            if not (currentStatue and currentStatue.Parent == plot) then
                buildStatue(plot)
            end
            return
        end
    end
    clearStatue()
end
for _, plot in plots:GetChildren() do
    plot:GetAttributeChangedSignal("OwnerUserId"):Connect(refreshStatue)
end
plots.ChildAdded:Connect(function(plot)
    plot:GetAttributeChangedSignal("OwnerUserId"):Connect(refreshStatue)
end)
refreshStatue()
