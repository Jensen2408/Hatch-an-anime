--[[ ReplicatedFirst.LoadingScreen.Config  (ModuleScript, child of the LoadingScreen LocalScript)
Edit everything here. Any empty or failed image falls back to a clean built-in shape, and Skip keeps working either way.
]]
return {
	MaxSeconds = 180,
	MinSeconds = 3.2,
	Images = {
		Background = "rbxassetid://104665669226233",
		BackgroundRight = "rbxassetid://121551875103201",
		Logo = "rbxassetid://136968104266135",
		Mountains = "", Hills = "", Temple = "", BranchLeft = "", BranchRight = "", Petal = "", Paper = "",
	},
	PreloadFolders = { "Characters", "Eggs" },
	PlotReadyAttribute = "PlotReady",
	PlotWait = 4,
	Tips = {
		"Collect eggs as they float down the river.",
		"Every character rolls its own Power.",
		"Place characters on stands to earn money.",
		"Upgrade your incubators to hatch faster.",
		"Step on your money plate to collect income.",
	},
	TipSeconds = 3.2,
	HideCoreGui = true,
	DisableControls = true,
	ReducedMotionAttribute = "ReducedMotion",
	Colors = {
		Cream = Color3.fromRGB(255, 243, 220), Ivory = Color3.fromRGB(255, 248, 234), Biscuit = Color3.fromRGB(255, 232, 191),
		Ink = Color3.fromRGB(29, 20, 32), Red = Color3.fromRGB(232, 69, 44), Crimson = Color3.fromRGB(157, 41, 37),
		Gold = Color3.fromRGB(255, 211, 107), Jade = Color3.fromRGB(47, 154, 100), JadeLight = Color3.fromRGB(70, 185, 124),
		Indigo = Color3.fromRGB(127, 106, 160), Haze = Color3.fromRGB(201, 165, 194), Sky = Color3.fromRGB(246, 199, 168),
		Grass = Color3.fromRGB(120, 168, 59), River = Color3.fromRGB(95, 201, 194), Blossom = Color3.fromRGB(255, 183, 201),
	},
}
