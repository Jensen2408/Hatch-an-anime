-- Builds crisp pixel-art icons out of Frames. rows = strings, palette = {char=Color3}; "." = empty
local P = {}
P.Icons = {
	home = { rows = {
		".....KK.....",
		"....KRRK....",
		"...KRRRRK...",
		"..KRRRRRRK..",
		".KRRRRRRRRK.",
		"KKKKKKKKKKKK",
		".KWWWWWWWWK.",
		".KWWKKKKWWK.",
		".KWWKDDKWWK.",
		".KWWKDDKWWK.",
		".KWWKDDKWWK.",
		".KKKKKKKKKK.",
	}, pal = { K = Color3.new(0,0,0), R = Color3.fromRGB(226,70,52), W = Color3.fromRGB(255,236,200), D = Color3.fromRGB(120,70,40) } },
	gear = { rows = {
		"....KKKK....",
		".KK.KWWK.KK.",
		".KWKKLLKKWK.",
		"..KLLLLLLK..",
		"KKKLLKKLLKKK",
		"KWLLK..KLLDK",
		"KWLLK..KLLDK",
		"KKKLLKKLLKKK",
		"..KLLLLLDK..",
		".KDKKLDKKDK.",
		".KK.KDDK.KK.",
		"....KKKK....",
	}, pal = { K = Color3.new(0,0,0), W = Color3.fromRGB(255,255,255), L = Color3.fromRGB(205,212,226), D = Color3.fromRGB(120,128,150) } },
	bag = { rows = {
		"....KKKK....",
		"...K.KK.K...",
		"..KKKKKKKK..",
		".KHRRRRRRRK.",
		".KRRRRRRRDK.",
		".KRKKKKKKDK.",
		".KRKYYYYKDK.",
		".KRKYKKYKDK.",
		".KRKYYYYKDK.",
		".KRKKKKKKDK.",
		".KDDDDDDDDK.",
		"..KKKKKKKK..",
	}, pal = { K = Color3.new(0,0,0), R = Color3.fromRGB(226,70,52), H = Color3.fromRGB(255,140,110), D = Color3.fromRGB(150,36,28), Y = Color3.fromRGB(255,206,60) } },
}
function P.build(parent, name, props)
	local def = P.Icons[name]
	local h, w = #def.rows, #def.rows[1]
	local holder = Instance.new("Frame")
	holder.Name = "PixelIcon"; holder.BackgroundTransparency = 1; holder.Size = UDim2.fromScale(1, 1)
	for k, v in props or {} do holder[k] = v end
	Instance.new("UIAspectRatioConstraint", holder).AspectRatio = w / h
	for y, row in def.rows do
		local x = 1
		while x <= w do
			local c = row:sub(x, x)
			local run = 1
			while x + run <= w and row:sub(x + run, x + run) == c do run += 1 end
			if c ~= "." and def.pal[c] then
				local px = Instance.new("Frame")
				px.BorderSizePixel = 0; px.BackgroundColor3 = def.pal[c]
				px.Position = UDim2.fromScale((x - 1) / w, (y - 1) / h); px.Size = UDim2.new(run / w, 1, 1 / h, 1)
				px.ZIndex = holder.ZIndex; px.Parent = holder
			end
			x += run
		end
	end
	holder.Parent = parent
	return holder
end
return P
