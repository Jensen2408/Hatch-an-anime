--[[
	ServerScriptService.WeaponGiver (server, no remotes)
	Gives each player their equipped bat (Player attribute EquippedWeapon, saved by PlayerDataService, set by
	ShopService) from ServerStorage > Weapons each time they spawn, and swaps it at once when they equip another one
	in the shop's WEAPONS tab. The Backpack is reset on every respawn, so a copy is cloned on each CharacterAdded
	(each clone carries its own BatServer Script).

	At start-up every ShopConfig.Weapons tier is cloned from the WoodenBat template (same mesh, grip, sounds, trail and
	BatServer). A tier with a `tint` loses the wood SurfaceAppearance and gets that colour + `material` on the mesh.
	Every tier is stamped with the Tool attributes BatServer / BatMotionClient / BossEventService read:
	BatWeapon = true, Knockback, HitRange, SwingCooldown, BossDamage.
	Display copies of the meshes (no scripts, anchored) go to ReplicatedStorage.ShopSystem.ShopModels.Weapons for the
	shop's previews; each is a Model whose pivot is the Handle's centre.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local weaponsFolder = ServerStorage:WaitForChild("Weapons")
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopSystem"):WaitForChild("ShopConfig"))
local DEFAULT_WEAPON = ShopConfig.DefaultWeapon or "WoodenBat"

-- Recolours a tier's mesh. Scripts cannot write SurfaceAppearance maps at runtime ("lacking capability Plugin"), so the
-- textured tiers are templates built in Studio (tools/weapons/build_bat_templates.luau): they carry the wood bat's
-- SurfaceAppearance with the tier's tinted colour map and the attribute TintedMaps = true, and are left alone here.
-- A tier without such a template (e.g. a place built from Rojo alone) falls back to a flat Color + Material.
local function recolour(tool, weapon)
    local handle = tool:FindFirstChild("Handle")
    if not (handle and weapon.tint) or tool:GetAttribute("TintedMaps") then
        return
    end
    local surface = handle:FindFirstChildOfClass("SurfaceAppearance")
    if surface then
        surface:Destroy()
    end
    handle.Color = weapon.tint
    handle.Material = weapon.material or Enum.Material.SmoothPlastic
end

-- build every tier + the shop's display copies
local displayFolder = Instance.new("Folder")
displayFolder.Name = "Weapons"
local base = weaponsFolder:FindFirstChild(DEFAULT_WEAPON)
local baseCopy = base and base:Clone() -- untouched copy: every tier starts from the same Handle/BatServer
local baseBatServer = baseCopy and baseCopy:FindFirstChild("BatServer")
for _, weapon in ShopConfig.Weapons or {} do
    local template = weaponsFolder:FindFirstChild(weapon.key)
    if not template and baseCopy then
        template = baseCopy:Clone()
        template.Name = weapon.key
        template.Parent = weaponsFolder
    end
    if template then
        -- Keep pre-existing tier templates synced with the latest WoodenBat.BatServer
        if template ~= base and baseBatServer then
            local oldScript = template:FindFirstChild("BatServer")
            if oldScript then
                oldScript:Destroy()
            end
            baseBatServer:Clone().Parent = template
        end
        recolour(template, weapon)
        template:SetAttribute("BatWeapon", true)
        template:SetAttribute("Knockback", weapon.knockback)
        template:SetAttribute("HitRange", weapon.range)
        template:SetAttribute("SwingCooldown", weapon.cooldown)
        template:SetAttribute("BossDamage", weapon.bossDamage)
        template.ToolTip = weapon.name
        local handle = template:FindFirstChild("Handle")
        if handle then
            local display = Instance.new("Model")
            display.Name = weapon.key
            local copy = handle:Clone()
            for _, child in copy:GetChildren() do
                if not child:IsA("SurfaceAppearance") then
                    child:Destroy()
                end
            end
            copy.Anchored = true
            copy.CFrame = CFrame.new()
            copy.Parent = display
            display.WorldPivot = CFrame.new()
            display.Parent = displayFolder
        end
    end
end
local shopModels = ReplicatedStorage.ShopSystem:FindFirstChild("ShopModels")
if shopModels then
    local old = shopModels:FindFirstChild("Weapons")
    if old then
        old:Destroy()
    end
    displayFolder.Parent = shopModels
end

local function isBat(tool)
    return tool:IsA("Tool") and tool:GetAttribute("BatWeapon") == true
end

-- removes the player's current bat (Backpack or held) and gives the equipped one; re-equips it if a bat was held
local function giveWeapons(player)
    local backpack = player:WaitForChild("Backpack")
    local key = player:GetAttribute("EquippedWeapon") or DEFAULT_WEAPON
    local template = weaponsFolder:FindFirstChild(key) or weaponsFolder:FindFirstChild(DEFAULT_WEAPON)
    if not template then
        warn("WeaponGiver: no weapon named '" .. key .. "' in ServerStorage.Weapons")
        return
    end
    local character = player.Character
    local wasHeld = false
    for _, container in { backpack, character } do
        for _, tool in container and container:GetChildren() or {} do
            if isBat(tool) then
                wasHeld = wasHeld or tool.Parent == character
                tool:Destroy()
            end
        end
    end
    local tool = template:Clone()
    tool.Parent = backpack
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if wasHeld and humanoid then
        humanoid:EquipTool(tool)
    end
end

local function onPlayerAdded(player)
    player.CharacterAdded:Connect(function()
        giveWeapons(player)
    end)
    player:GetAttributeChangedSignal("EquippedWeapon"):Connect(function()
        if player.Character then
            giveWeapons(player)
        end
    end)
    if player.Character then
        giveWeapons(player)
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end
