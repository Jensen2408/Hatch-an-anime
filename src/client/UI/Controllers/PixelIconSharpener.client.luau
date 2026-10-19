--[[ StarterPlayerScripts.PixelIconSharpener (LocalScript)
Pixel-art icons (CC0 packs: OwlishMedia "RPG UI icons", Bonsaiheldin "Gold treasure icons") are drawn with
nearest-neighbour scaling so they stay crisp instead of blurry.
Any ImageLabel / ImageButton anywhere in PlayerGui whose Image is one of the asset ids below gets
ResampleMode = Pixelated (existing descendants now, new ones via DescendantAdded). The check runs only when
an instance is added: an image swapped to a pixel-art id later is not re-checked.
]]

-- set of "rbxassetid://<id>" strings
local PIXEL_ART_IMAGES = {}
for _, assetId in
    {
        "123121531396779",
        "115300000098827",
        "132384741215584",
        "125162321561970",
        "91503030293166",
        "132917301116912",
        "109018349043224",
        "108828180161951",
        "101647680219886",
        "89561259739700",
        "104286530759848",
        "79414603176573",
        "86826769942442",
        "93664136134324",
        "115933046975719",
        "112731802177209",
        "125953814573772",
        "139683651057323",
        "108893717182985",
    }
do
    PIXEL_ART_IMAGES["rbxassetid://" .. assetId] = true
end

local function makePixelated(image)
    if image:IsA("ImageLabel") or image:IsA("ImageButton") then
        if PIXEL_ART_IMAGES[image.Image] then
            image.ResampleMode = Enum.ResamplerMode.Pixelated
        end
    end
end
local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
for _, descendant in playerGui:GetDescendants() do
    makePixelated(descendant)
end
playerGui.DescendantAdded:Connect(makePixelated)
