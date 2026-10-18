-- Pixel-art icons (CC0 packs: OwlishMedia "RPG UI icons", Bonsaiheldin "Gold treasure icons") are drawn with
-- nearest-neighbour scaling so they stay crisp instead of blurry.
local PX = {}
for _, id in
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
    PX["rbxassetid://" .. id] = true
end
local function fix(o)
    if o:IsA("ImageLabel") or o:IsA("ImageButton") then
        if PX[o.Image] then
            o.ResampleMode = Enum.ResamplerMode.Pixelated
        end
    end
end
local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
for _, d in pg:GetDescendants() do
    fix(d)
end
pg.DescendantAdded:Connect(fix)
