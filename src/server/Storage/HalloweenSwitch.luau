-- HALLOWEEN SWITCH  (ServerStorage.HalloweenSwitch, ModuleScript; Studio edit-mode tool, never required at runtime)
-- Turn Halloween OFF:  require(game.ServerStorage.HalloweenSwitch).Set(false)
-- Turn Halloween ON:   require(game.ServerStorage.HalloweenSwitch).Set(true)
-- Run it in the Studio command bar (Edit mode), then save/publish.
-- Whatever season is not showing is kept in ServerStorage.SeasonStorage.
local HalloweenSwitch = {}
local ServerStorage = game.ServerStorage
local seasonStorage = ServerStorage.SeasonStorage
local Lighting = game.Lighting
-- Things that only exist in Halloween: {name, normal parent}
local ITEMS = {
    {
        "PumpkinGentleman",
        function()
            return workspace
        end,
    },
    {
        "HalloweenLights",
        function()
            return workspace.Map.Scenery
        end,
    },
    {
        "HalloweenMapDecor",
        function()
            return workspace.Map.Scenery
        end,
    },
    {
        "HalloweenGrade",
        function()
            return Lighting
        end,
    },
}
local function pathTo(path)
    local current = game
    for segment in path:gmatch("[^%.]+") do
        if segment ~= "Workspace" or current ~= game then
            current = current:FindFirstChild(segment)
        else
            current = workspace
        end
        if not current then
            return nil
        end
    end
    return current
end
local function setLighting(source)
    for attributeName, value in pairs(source:GetAttributes()) do
        if attributeName:sub(1, 2) == "L_" then
            Lighting[attributeName:sub(3)] = value
        elseif attributeName:sub(1, 2) == "A_" then
            local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
            if atmosphere then
                atmosphere[attributeName:sub(3)] = value
            end
        end
    end
end
local function swapColors(on)
    for _, descendant in ipairs(workspace:GetDescendants()) do
        local before = descendant:GetAttribute("BeforeHalloweenColor")
        if before ~= nil and (descendant:IsA("BasePart") or descendant:IsA("SurfaceAppearance")) then
            if on then
                local halloweenColor = descendant:GetAttribute("HalloweenSeasonColor")
                if halloweenColor then
                    descendant.Color = halloweenColor
                end
            else
                descendant:SetAttribute("HalloweenSeasonColor", descendant.Color)
                descendant.Color = before
            end
        end
    end
end
local function rebuildTemples(theme)
    local templates = ServerStorage:FindFirstChild("TempleUpgradeTemplates")
    local TempleAppearanceThemes = require(game.ReplicatedStorage.TempleAppearanceThemes)
    for _, plot in ipairs(workspace.Plots:GetChildren()) do
        if plot:GetAttribute("TempleAppearance") ~= nil then
            plot:SetAttribute("TempleAppearance", theme)
            local oldTemple = plot:FindFirstChild("Temple")
            local template = templates and templates:FindFirstChild("Level" .. (plot:GetAttribute("TempleLevel") or 1))
            if oldTemple and template and plot:FindFirstChild("TempleAnchor") then
                local newTemple = template:Clone()
                TempleAppearanceThemes.Apply(newTemple, theme)
                newTemple.Name = "Temple"
                newTemple:PivotTo(plot.TempleAnchor.CFrame)
                newTemple.ModelStreamingMode = oldTemple.ModelStreamingMode
                newTemple.Parent = plot
                oldTemple:Destroy()
            end
        end
    end
end
-- Instance.new(class, parent) below is deprecated (selene: deprecated); kept to keep creation order identical.
local function swapTrees(on)
    local from = on and seasonStorage.Halloween or seasonStorage.Original
    local to = on and seasonStorage.Original or seasonStorage.Halloween
    local stash = to:FindFirstChild("Trees") or Instance.new("Folder", to)
    stash.Name = "Trees"
    -- put showing trees away
    if on then
        -- Empty loop kept on purpose: the index chain errors (aborting Set) if this archive folder is missing.
        for _, _tree in ipairs(ServerStorage._ARCHIVE.BeforeHalloweenMap_1791902647.MapTrees:GetChildren()) do
        end
        for _, descendant in ipairs(workspace.Map:GetDescendants()) do
            if descendant:IsA("Model") and descendant:GetAttribute("SeasonTree") == "Original" then
                descendant.Parent = stash
            end
        end
    else
        for _, descendant in ipairs(workspace:GetDescendants()) do
            if descendant:IsA("Model") and descendant.Name:match("^Halloween_") then
                descendant:SetAttribute("PreviousParentPath", descendant.Parent:GetFullName())
                descendant:SetAttribute("SeasonTree", "Halloween")
                descendant.Parent = stash
            end
        end
    end
    -- bring the other set out
    local storedTrees = from:FindFirstChild("Trees")
    if storedTrees then
        for _, tree in ipairs(storedTrees:GetChildren()) do
            local parent = pathTo(tree:GetAttribute("PreviousParentPath") or "") or workspace.Map.Scenery
            tree:SetAttribute("SeasonTree", on and "Halloween" or "Original")
            tree.Parent = parent
        end
    end
end
-- Folders whose CONTENTS are swapped (e.g. egg designs): {container getter, storage name}
local SWAP_FOLDERS = {
    {
        function()
            return ServerStorage.AuxEggTemplates
        end,
        "AuxEggTemplates",
    },
    {
        function()
            return ServerStorage.BrainrotModels
        end,
        "BrainrotModels",
    },
}
local function swapFolders(on)
    for _, entry in ipairs(SWAP_FOLDERS) do
        local live = entry[1]()
        local stash = (on and seasonStorage.Original or seasonStorage.Halloween)
        local restoreFrom = (on and seasonStorage.Halloween or seasonStorage.Original):FindFirstChild(entry[2])
        if live and restoreFrom then
            local holdFolder = stash:FindFirstChild(entry[2]) or Instance.new("Folder", stash)
            holdFolder.Name = entry[2]
            for _, child in ipairs(live:GetChildren()) do
                child.Parent = holdFolder
            end
            for _, child in ipairs(restoreFrom:GetChildren()) do
                child.Parent = live
            end
        end
    end
end
function HalloweenSwitch.Set(on)
    local current = workspace:GetAttribute("HalloweenMode")
    if current == nil then
        current = true
    end
    if current == on then
        return "already " .. (on and "ON" or "OFF")
    end
    local stashTarget = on and seasonStorage.Original or seasonStorage.Halloween
    local restoreSource = on and seasonStorage.Halloween or seasonStorage.Original
    for _, item in ipairs(ITEMS) do
        if on then
            local instance = restoreSource:FindFirstChild(item[1])
            if instance then
                instance.Parent = item[2]()
            end
        else
            local instance = item[2]():FindFirstChild(item[1])
            if instance then
                instance.Parent = stashTarget
            end
        end
    end
    swapTrees(on)
    swapFolders(on)
    swapColors(on)
    rebuildTemples(on and "Halloween" or "Original")
    setLighting(on and seasonStorage.Halloween or seasonStorage.Original)
    workspace:SetAttribute("HalloweenMode", on)
    return "Halloween is now " .. (on and "ON" or "OFF")
end
return HalloweenSwitch
