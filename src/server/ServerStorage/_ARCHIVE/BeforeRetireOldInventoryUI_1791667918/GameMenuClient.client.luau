--[[ StarterPlayerScripts.GameMenuClient  (LocalScript)
Left menu (INDEX / PLOT / QUESTS / SHOP) + one panel at a time. Display only: every action is a server request.
Keys: 1-4 open panels, Esc closes. Gamepad: ButtonSelect toggles, then normal UI navigation.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local root = RS:WaitForChild("GameMenu")
local Config = require(root:WaitForChild("Config"))
local R = root:WaitForChild("Remotes")
local GetState, Action, Changed = R:WaitForChild("GetState"), R:WaitForChild("Action"), R:WaitForChild("Changed")
if player.PlayerGui:FindFirstChild("GameMenu") then player.PlayerGui.GameMenu:Destroy() end -- no duplicates

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local C = { Ink = rgb(29, 20, 32), Cream = rgb(255, 243, 220), Head = rgb(255, 232, 191), Low = rgb(241, 220, 182), White = rgb(255, 255, 255),
	Red = rgb(232, 69, 44), RedLo = rgb(181, 42, 47), Gold = rgb(255, 211, 107), Green = rgb(72, 205, 52), GreenT = rgb(34, 106, 46), GreenB = rgb(216, 242, 207),
	Muted = rgb(107, 85, 96), Cap = rgb(134, 112, 124), Sel = rgb(255, 217, 207), ErrB = rgb(255, 220, 220), Lock = rgb(58, 47, 66) }
local RC = { Common = rgb(122, 129, 140), Uncommon = rgb(47, 154, 58), Rare = rgb(45, 111, 214), Epic = rgb(138, 63, 208), Legendary = rgb(176, 122, 0) }
local RORDER = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
local F = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local FB = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.SemiBold)
local reduced = function() return player:GetAttribute("ReducedMotion") == true end

local function make(c, p, parent) local o = Instance.new(c); for k, v in p do o[k] = v end; if parent then o.Parent = parent end; return o end
local function corner(o, r) make("UICorner", { CornerRadius = UDim.new(0, r or 12) }, o) end
local function ink(o, t) make("UIStroke", { Color = C.Ink, Thickness = t or 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o) end
local function grad(o, a, b, rot) return make("UIGradient", { Rotation = rot or 90, Color = ColorSequence.new(a, b) }, o) end
local function outline(l, th) make("UIStroke", { Color = C.Ink, Thickness = th or 2.5, LineJoinMode = Enum.LineJoinMode.Round, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, l); return l end
local function txt(parent, s, size, color, font, props)
	local l = make("TextLabel", { BackgroundTransparency = 1, Text = s, TextSize = size, TextColor3 = color or C.Ink, FontFace = font or F, AutomaticSize = Enum.AutomaticSize.XY, TextXAlignment = Enum.TextXAlignment.Left }, parent)
	if props then for k, v in props do l[k] = v end end
	return l
end
local lastSound = 0
local function sound(slot)
	local id = Config.Sounds[slot]; if not id or id == "" or os.clock() - lastSound < 0.06 then return end
	lastSound = os.clock(); local s = make("Sound", { SoundId = id, Volume = Config.Volume }, workspace.CurrentCamera); s.Ended:Once(function() s:Destroy() end); s:Play()
end
-- chunky 3D button: ink base + face that presses 3 px
local function button(parent, label, color, onClick, w, h, order)
	h = h or 38
	local hold = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(w and 0 or 1, w or 0, 0, h + 4), LayoutOrder = order or 0 }, parent)
	local base = make("Frame", { BackgroundColor3 = C.Ink, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, h) }, hold); corner(base, 11)
	local face = make("TextButton", { BackgroundColor3 = color, Size = UDim2.new(1, 0, 0, h), Text = label, FontFace = F, TextSize = 15, AutoButtonColor = false,
		TextColor3 = C.White }, hold); corner(face, 11); ink(face, 3)
	local light = color:Lerp(Color3.new(1, 1, 1), 0.35)
	grad(face, light, color)
	outline(face, 2.5)
	make("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.45, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 0, 3) }, face)
	local on = true
 local api={}
	face.MouseButton1Down:Connect(function() if on then face.Position = UDim2.fromOffset(0, 3) end end)
	face.MouseButton1Up:Connect(function() face.Position = UDim2.new() end); face.MouseLeave:Connect(function() face.Position = UDim2.new() end)
	face.Activated:Connect(function() if on then sound("Press"); onClick(api) end end)
	api.face=face;api.set=function(v, l) on = v; face.BackgroundTransparency = v and 0 or 0.4; face.TextTransparency = v and 0 or 0.45; if l then face.Text = l end end
 return api
end
local function chip(parent, label, active, onClick, color)
	local b = make("TextButton", { Text = label, FontFace = F, TextSize = 13, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), AutoButtonColor = false,
		BackgroundColor3 = active and C.Ink or C.White, TextColor3 = active and C.Gold or (color or C.Ink) }, parent)
	corner(b, 14); ink(b, 2); make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, b)
	b.Activated:Connect(onClick); return b
end
local function row(parent, gap, order, wrap)
	local f = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order or 0 }, parent)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, gap or 6), Wraps = wrap ~= false, SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }, f)
	return f
end

-- previews: ViewportFrame for up to MaxViewports entries with a model, else a flat tile
local viewports = 0
local function preview(parent, entry, size, locked)
	if entry.image and not entry.model then
		local tile = make("Frame", { BackgroundColor3 = locked and C.Lock or C.Low, Size = size }, parent); corner(tile, 9)
		make("ImageLabel", { BackgroundTransparency = 1, Image = entry.image, Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Fit, ImageColor3 = locked and Color3.new(0, 0, 0) or Color3.new(1, 1, 1), ImageTransparency = locked and 0.8 or 0 }, tile)
		return tile
	end
	local tile = make("Frame", { BackgroundColor3 = locked and C.Lock or C.Low, Size = size }, parent); corner(tile, 9)
	local src = entry.model and RS:FindFirstChild(entry.model, true)
	if src and src:IsA("Model") and viewports < Config.MaxViewports then
		viewports += 1
		local vp = make("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = rgb(200, 200, 200), LightDirection = Vector3.new(-1, -1, -1) }, tile)
		local m = src:Clone(); m.Parent = vp
		local cf, sz = m:GetBoundingBox()
		local cam = make("Camera", { FieldOfView = 30 }, vp); vp.CurrentCamera = cam
		local d = math.max(sz.X, sz.Y) * 2.2
		cam.CFrame = CFrame.lookAt(cf.Position + cf.LookVector * d + Vector3.new(0, sz.Y * 0.15, 0), cf.Position)
		if locked then vp.ImageColor3 = rgb(20, 14, 24) end
		tile.Destroying:Once(function() viewports -= 1 end)
	end
	if locked then txt(tile, "?", 28, C.Cream, F, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) }) end
	return tile
end

---------------------------------------------------------------- shell
local gui = make("ScreenGui", { Name = "GameMenu", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 10 }, player.PlayerGui)
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local nav = make("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY }, gui)
local navList = make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, nav)
local navScale = make("UIScale", {}, nav)
local panel = make("Frame", { BackgroundColor3 = C.Cream, Visible = false }, gui); corner(panel, 18); ink(panel, 3.5)
local panelScale = make("UIScale", {}, panel)
local head = make("Frame", { BackgroundColor3 = C.Red, Size = UDim2.new(1, 0, 0, 56) }, panel); corner(head, 18)
grad(head, rgb(242, 96, 63), rgb(201, 54, 31))
make("Frame", { BackgroundColor3 = C.Ink, BorderSizePixel = 0, Position = UDim2.new(0, 0, 0, 56), Size = UDim2.new(1, 0, 0, 3) }, panel)
local title = txt(head, "", 28, C.White, F, { Position = UDim2.fromOffset(18, 12) })
outline(title, 3)
local titleGrad = make("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(255, 251, 232), rgb(245, 181, 58)) }, title)
local sub = txt(head, "", 12, C.Head, FB, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -60, 0.5, 0) })
local closeB = make("TextButton", { Text = "X", FontFace = F, TextSize = 16, Size = UDim2.fromOffset(34, 34), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), BackgroundColor3 = C.Gold, TextColor3 = C.Ink, AutoButtonColor = false }, head)
corner(closeB, 10); ink(closeB)
local tabsRow = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 68), Size = UDim2.new(1, -28, 0, 34) }, panel)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, tabsRow)
local body = make("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 108), Size = UDim2.new(1, 0, 1, -108), CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, ScrollBarImageColor3 = C.Ink }, panel)
make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14) }, body)
make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, body)
local footer = make("Frame", { BackgroundColor3 = C.Head, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 56), Visible = false, ZIndex = 3 }, panel)
corner(footer, 18); make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, footer)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, footer)
local toast = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -66), AutomaticSize = Enum.AutomaticSize.XY, BackgroundColor3 = C.GreenB, Text = "", FontFace = F, TextSize = 14, TextColor3 = C.Ink, Visible = false, ZIndex = 10 }, panel)
corner(toast, 12); ink(toast); make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7) }, toast)
local toastN = 0
local function say(ok, msg) toastN += 1; local n = toastN; toast.Text = msg or (ok and "Done" or "Failed"); toast.BackgroundColor3 = ok and C.GreenB or C.ErrB; toast.Visible = true; task.delay(2.4, function() if n == toastN then toast.Visible = false end end) end

local function layout()
	local v = workspace.CurrentCamera.ViewportSize
	isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local s = math.clamp(v.Y / 820, 0.62, 1)
	navScale.Scale, panelScale.Scale = s, s
	if isTouch then -- row above the thumbstick, panels as overlays
		navList.FillDirection = Enum.FillDirection.Horizontal
		nav.AnchorPoint, nav.Position = Vector2.new(0, 1), UDim2.new(0, 12, 1, -210 * s)
		panel.AnchorPoint, panel.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, GuiService:GetGuiInset().Y + 8)
		panel.Size = UDim2.fromOffset(math.min(620, (v.X - 20) / s), math.min(700, (v.Y - GuiService:GetGuiInset().Y - 230 * s) / s))
	else -- vertical stack on the left, clear of chat (top-left) and the backpack (bottom)
		navList.FillDirection = Enum.FillDirection.Vertical
		nav.AnchorPoint, nav.Position = Vector2.new(0, 0.5), UDim2.new(0, 12, 0.5, 20)
		panel.AnchorPoint, panel.Position = Vector2.new(0, 0.5), UDim2.new(0, 12 + 92 * s, 0.5, 20)
		panel.Size = UDim2.fromOffset(600, math.min(620, (v.Y - 140) / s))
	end
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)

---------------------------------------------------------------- state + server
local current, tab, data, loading = nil, {}, {}, false
local setOpen
local ui = { search = "", rar = "All", disc = "All", sort = "Income", sel = {}, detail = nil }
local render
local function load(section)
	loading = true; render()
	local ok, res = pcall(GetState.InvokeServer, GetState, section)
	loading = false
	data[section] = ok and res or { error = "Couldn't reach the server" }
	if current == section then render() end
end
local acting = false
local function act(name, args, btn)
	if acting then return say(false, "Action in progress") end
	acting = true; if btn then btn.set(false, "Waiting…") end
	local ok, res, msg = pcall(Action.InvokeServer, Action, name, args or {})
	acting = false
	if not ok then res, msg = false, "Server didn't respond" end
	say(res, msg); if res then sound(name:find("Claim") and "Claim" or "Success") end
	if current then load(current) end
	return res
end

local function clear() for _, c in body:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end for _, c in tabsRow:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end for _, c in footer:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end for _, c in panel:GetChildren() do if c.Name=="MenuDetailOverlay" then c:Destroy() end end end
local function message(t, b) local f = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 160) }, body); txt(f, t, 22, C.Ink, F, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40) })
	txt(f, b or "", 14, C.Muted, FB, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 74), TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(0.8, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Center }); return f end
local function tabs(list, key, default)
	tab[key] = tab[key] or default
	for i, t in list do local on = tab[key] == t
		local b = make("TextButton", { Text = t, FontFace = F, TextSize = 14, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 32), AutoButtonColor = false, LayoutOrder = i,
			BackgroundColor3 = on and C.Red or C.White, TextColor3 = on and C.White or C.Ink }, tabsRow)
		corner(b, 10); ink(b); make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, b)
		b.Activated:Connect(function() tab[key] = t; ui.detail = nil; render(true) end)

	end
	return tab[key]
end

---------------------------------------------------------------- pages
local PAGES = {}
PAGES.index = function(d)
	local which = tabs({ "Characters", "Eggs" }, "index", "Characters")
	local list = (which == "Eggs" and d.catalog.eggs or d.catalog.characters) or {}
	if #list == 0 then return message("No entries yet", "New eggs and characters appear here automatically when added to the catalog.") end
	local disc, total = 0, #list; for _, e in list do if d.discovered[e.id] then disc += 1 end end
	sub.Text = ("%s · %d / %d discovered"):format(which, disc, total)
	local top = row(body, 8, 1, false)
	local box = make("TextBox", { PlaceholderText = "Search", Text = ui.search, FontFace = F, TextSize = 15, TextColor3 = C.Ink, PlaceholderColor3 = C.Cap, BackgroundColor3 = C.Head, Size = UDim2.new(1, -90, 0, 36), ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left }, top)
	corner(box, 10); ink(box); make("UIPadding", { PaddingLeft = UDim.new(0, 12) }, box)
	box.FocusLost:Connect(function() ui.search = box.Text; render() end)
	local cnt = txt(top, ("%d / %d"):format(disc, total), 14, C.Gold, F, { BackgroundTransparency = 0, BackgroundColor3 = C.Ink }); corner(cnt, 10); make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, cnt)
	local f = row(body, 5, 2)
	for _, r in { "All", "Common", "Uncommon", "Rare", "Epic", "Legendary" } do chip(f, r, ui.rar == r, function() ui.rar = r; render() end, RC[r]) end
	for _, r in { "All", "Discovered", "Undiscovered" } do chip(f, r, ui.disc == r, function() ui.disc = r; render() end) end
	local grid = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3 }, body)
	make("UIGridLayout", { CellSize = UDim2.new(isTouch and 1 / 3 or 0.25, -8, 0, 140), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	local q = ui.search:lower()
	for i, e in list do
		local known = d.discovered[e.id] == true
		local okR = ui.rar == "All" or e.rarity == ui.rar
		local okD = ui.disc == "All" or (ui.disc == "Discovered") == known
		local okS = q == "" or (known and e.name:lower():find(q, 1, true))
		if okR and okD and okS then
			local card = make("TextButton", { Text = "", BackgroundColor3 = C.White, AutoButtonColor = false, LayoutOrder = i }, grid); corner(card, 12); ink(card)
			local p = preview(card, e, UDim2.new(1, -12, 0, 72), not known); p.Position = UDim2.fromOffset(6, 6)
			txt(card, known and e.name or "Undiscovered", 14, C.Ink, F, { Position = UDim2.fromOffset(8, 84), TextWrapped = true, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -16, 0, 30) })
			txt(card, string.upper(e.rarity), 11, RC[e.rarity] or C.Muted, F, { Position = UDim2.fromOffset(8, 118) })
			if e.limited then local l = txt(p, "LIMITED", 10, C.Ink, F, { BackgroundTransparency = 0, BackgroundColor3 = C.Gold, Position = UDim2.fromOffset(4, 4) }); corner(l, 5); make("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, l) end
			if known and (d.owned[e.id] or 0) > 0 then local o = txt(p, "OWNED", 10, C.GreenT, F, { BackgroundTransparency = 0, BackgroundColor3 = C.GreenB, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4) }); corner(o, 5); make("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, o) end
			card.Activated:Connect(function() ui.detail = e; render() end)
		end
	end
	if ui.detail then
		local e = ui.detail; local known = d.discovered[e.id] == true; local own = d.owned[e.id] or 0
		local dim = make("TextButton", { Name = "MenuDetailOverlay", Text = "", AutoButtonColor = false, BackgroundColor3 = C.Ink, BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), ZIndex = 8 }, panel); corner(dim, 18)
		local box2 = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(380, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.Cream, ZIndex = 9 }, dim)
		corner(box2, 16); ink(box2, 3); make("UIPadding", { PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 16), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, box2)
		make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, box2)
		local function z(o) o.ZIndex = 10; for _, c in o:GetDescendants() do if c:IsA("GuiObject") then c.ZIndex = 10 end end return o end
		z(preview(box2, e, UDim2.new(1, 0, 0, 120), not known))
		z(txt(box2, known and e.name or "???", 24, C.Ink, F, { LayoutOrder = 1 })); z(txt(box2, e.rarity, 14, RC[e.rarity], F, { LayoutOrder = 2 }))
		z(txt(box2, known and (e.description or "") or "Not discovered yet.", 14, C.Muted, FB, { LayoutOrder = 3, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) }))
		z(txt(box2, "How to get it: " .. (e.obtain or "—"), 13, C.Muted, FB, { LayoutOrder = 4, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) }))
		z(txt(box2, (known and "Discovered before" or "Not discovered") .. "   ·   " .. (own > 0 and ("Owned now ×" .. own) or "Not owned now"), 13, C.Ink, F, { LayoutOrder = 5 }))
		z(txt(box2, "Power is rolled per character, so it isn't listed here.", 12, C.Cap, FB, { LayoutOrder = 6 }))
		local close = function() dim:Destroy(); ui.detail = nil end
		dim.Activated:Connect(close)
		local b = button(box2, "Back", C.Gold, close, 100, 34, 7); z(b.face.Parent)
	end
end

PAGES.plot = function(d)
	if not d.plotOwned then return message("You don't have a plot yet", "Claim a temple plot first. Plot actions stay disabled until you own one.") end
	local items = d.items or {}
	local used, total = 0, 0
	for _, it in items do if it.state == "placed" then used += 1; total += it.income end end
	local stats = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 58), LayoutOrder = 1 }, body)
	make("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 1, 0), CellPadding = UDim2.fromOffset(8, 0) }, stats)
	for _, s in { { "Temple", "Level " .. tostring(d.level) }, { "Stands", ("%d / %d used"):format(used, d.unlocked) }, { "Income", "$" .. Config.Short(total) .. "/sec" } } do
		local c = make("Frame", { BackgroundColor3 = C.White }, stats); corner(c, 12); ink(c)
		txt(c, s[1], 11, C.Cap, FB, { Position = UDim2.fromOffset(10, 7) }); txt(c, s[2], 17, s[1] == "Income" and C.GreenT or C.Ink, F, { Position = UDim2.fromOffset(10, 25) })
	end
	local acts = row(body, 6, 2)
 button(acts,"Inventory",C.Gold,function() setOpen(nil);require(RS.CharacterInventory.InventoryClient).Open() end,110,34)
	button(acts, "Equip best", C.Red, function(b) act("EquipBest", nil, b) end, 130, 34)
	button(acts, "Unequip all", C.Gold, function()
		if used == 0 then return say(false, "Nothing is placed") end
		local dim = make("TextButton", { Name = "MenuDetailOverlay", Text = "", AutoButtonColor = false, BackgroundColor3 = C.Ink, BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), ZIndex = 8 }, panel); corner(dim, 18)
		local box = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(320, 150), BackgroundColor3 = C.Cream, ZIndex = 9 }, dim); corner(box, 16); ink(box, 3)
		txt(box, "Unequip all characters?", 19, C.Ink, F, { Position = UDim2.fromOffset(16, 16), ZIndex = 10 })
		txt(box, "They go back to your inventory. Nothing is deleted or sold.", 13, C.Muted, FB, { Position = UDim2.fromOffset(16, 46), Size = UDim2.new(1, -32, 0, 36), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = true, ZIndex = 10 })
		local r2 = row(box, 8); r2.Position = UDim2.new(0, 16, 1, -54); r2.Size = UDim2.new(1, -32, 0, 0)
		local function z(b) for _, c in b.face.Parent:GetDescendants() do c.ZIndex = 10 end b.face.Parent.ZIndex = 10 end
		z(button(r2, "Cancel", C.White, function() dim:Destroy() end, 120, 34)); z(button(r2, "Unequip all", C.Red, function() dim:Destroy(); act("UnequipAll") end, 150, 34))
	end, 130, 34)
	local sorts = row(body, 5, 3)
	for _, s in { "Income", "Power", "Rarity", "Newest" } do chip(sorts, s, ui.sort == s, function() ui.sort = s; render() end) end
	if #items == 0 then return message("No characters yet", "Hatch an egg in an incubator, then place your character on a stand.") end
	local cmp = { Income = function(a, b) return a.income > b.income end, Power = function(a, b) return a.power > b.power end,
		Rarity = function(a, b) return (RORDER[a.rarity] or 0) > (RORDER[b.rarity] or 0) end, Newest = function(a, b) return (a.acquired or 0) > (b.acquired or 0) end }
	local list = table.clone(items); table.sort(list, cmp[ui.sort])
	local grid = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4 }, body)
	make("UIGridLayout", { CellSize = UDim2.new(isTouch and 1 or 0.5, -5, 0, 72), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	for i, it in list do
		local on = ui.sel[it.uid] == true
		local c = make("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = on and C.Sel or C.White, LayoutOrder = i }, grid); corner(c, 12); ink(c, on and 3.5 or 2.5)
		local p = preview(c, it, UDim2.fromOffset(56, 56), false); p.Position = UDim2.fromOffset(8, 8)
		txt(c, it.name, 15, C.Ink, F, { Position = UDim2.fromOffset(72, 8), AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -150, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
		txt(c, string.upper(it.rarity), 10, RC[it.rarity], F, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -40, 0, 11) })
		txt(c, "PWR " .. Config.Short(it.power), 13, C.Red, F, { Position = UDim2.fromOffset(72, 30) })
		txt(c, "$" .. Config.Short(it.income) .. "/sec", 13, C.GreenT, F, { Position = UDim2.fromOffset(150, 30) })
		txt(c, it.state == "placed" and "Placed on a stand" or it.state == "held" and "Held" or "In inventory", 11, it.state == "placed" and C.GreenT or C.Cap, FB, { Position = UDim2.fromOffset(72, 50) })
		local box = make("TextLabel", { Text = on and "✓" or "", FontFace = F, TextSize = 12, TextColor3 = C.White, BackgroundColor3 = on and C.Red or C.White, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(20, 20) }, c)
		corner(box, 6); ink(box, 2)
		c.Activated:Connect(function() ui.sel[it.uid] = not on or nil; render() end) -- selection only; never moves the character
	end
	local n = 0; for _ in ui.sel do n += 1 end
	if n > 0 then
		footer.Visible = true; body.Size = UDim2.new(1, 0, 1, -170)
		txt(footer, n .. " selected", 14, C.Ink, F, { LayoutOrder = 0 })
		local uids = {}; for u in ui.sel do table.insert(uids, u) end
		local full = used >= d.unlocked
		local pb = button(footer, full and "No free stands" or "Place selected", C.Red, function(b) if act("PlaceSelected", { uids = uids }, b) then ui.sel = {} end end, 150, 34, 1); pb.set(not full)
		button(footer, "Store selected", C.Gold, function(b) if act("StoreSelected", { uids = uids }, b) then ui.sel = {} end end, 140, 34, 2)
		button(footer, "Clear", C.White, function() ui.sel = {}; render() end, 80, 34, 3)
	end
end

PAGES.quests = function(d)
	local period = tabs({ "Daily", "Weekly", "Monthly" }, "quests", "Daily")
	local offset = d.serverTime - workspace:GetServerTimeNow() -- countdown follows server time
	local top = row(body, 8, 1, false)
	local reset = txt(top, "", 14, C.Gold, F, { BackgroundTransparency = 0, BackgroundColor3 = C.Ink }); corner(reset, 10); make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, reset)
	local function tick() local left = math.max(0, d.ends[period] - (workspace:GetServerTimeNow() + offset)); local h = math.floor(left / 3600)
		reset.Text = h >= 48 and ("Resets in %dd %dh"):format(h // 24, h % 24) or ("Resets in %dh %02dm %02ds"):format(h, (left // 60) % 60, left % 60) end
	tick(); task.spawn(function() while reset.Parent do task.wait(1); if reset.Parent then tick() end end end)
	local list, ready = {}, {}
	for _, q in d.list do if q.period == period then table.insert(list, q); if q.progress >= q.target and not q.claimed then table.insert(ready, q) end end end
	table.sort(list, function(a, b) return a.order < b.order end)
	if #ready > 1 then button(top, ("Claim all (%d)"):format(#ready), C.Green, function(b) act("ClaimAll", nil, b) end, 150, 32) end
	if #list == 0 then return message("No quests right now", "New quests arrive when this period resets.") end
	for i, q in list do
		local done, cl = q.progress >= q.target, q.claimed
		local c = make("Frame", { BackgroundColor3 = cl and rgb(244, 236, 220) or C.White, Size = UDim2.new(1, 0, 0, 82), LayoutOrder = 10 + i }, body); corner(c, 12); ink(c)
		txt(c, q.title, 16, C.Ink, F, { Position = UDim2.fromOffset(12, 9) })
		txt(c, q.description, 12, C.Muted, FB, { Position = UDim2.fromOffset(12, 31) })
		local bar = make("Frame", { BackgroundColor3 = C.Low, Position = UDim2.fromOffset(12, 54), Size = UDim2.new(1, -150, 0, 16) }, c); corner(bar, 8); ink(bar, 2)
		local fill = make("Frame", { BackgroundColor3 = cl and rgb(185, 194, 180) or done and C.Green or rgb(255, 201, 74), Size = UDim2.fromScale(math.clamp(q.progress / q.target, 0, 1), 1) }, bar); corner(fill, 8)
		txt(bar, (q.target >= 1e6 and (Config.Short(q.progress) .. " / " .. Config.Short(q.target)) or (q.progress .. " / " .. q.target)), 11, C.Ink, F, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 2 })
		local rw = q.reward and q.reward.cash and ("$" .. Config.Short(q.reward.cash)) or "Reward"
		txt(c, rw, 13, C.GreenT, F, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(1, -66, 0, 12) })
		local holder = make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 36), Size = UDim2.fromOffset(110, 38) }, c)
		local b = button(holder, cl and "Claimed" or done and "Claim" or "In progress", done and not cl and C.Green or C.Low, function(btn)
			if act("Claim", { id = q.id }, btn) and not reduced() then local s = make("UIScale", {}, c); TweenService:Create(s, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1.04 }):Play() end
		end, nil, 32)
		b.set(done and not cl)
	end
end

PAGES.shop = function(d)
	local t = tabs(d.tabs or Config.ShopTabs, "shop", "Featured")
	if t == "Featured" and Config.Banner then -- big glossy featured banner (Config.Banner = { title, subtitle, image })
		local bn = make("Frame", { BackgroundColor3 = C.White, Size = UDim2.new(1, 0, 0, 150), LayoutOrder = 0, ClipsDescendants = true }, body); corner(bn, 14); ink(bn, 3)
		make("UIGradient", { Rotation = 0, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(90, 26, 168)), ColorSequenceKeypoint.new(0.4, rgb(176, 42, 208)), ColorSequenceKeypoint.new(0.65, C.Red), ColorSequenceKeypoint.new(1, rgb(255, 178, 42)) }) }, bn)
		make("UIStroke", { Color = C.Gold, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, bn).Transparency = 0.1
		if Config.Banner.image then make("ImageLabel", { BackgroundTransparency = 1, Image = Config.Banner.image, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, 6), Size = UDim2.fromOffset(150, 160), ScaleType = Enum.ScaleType.Fit }, bn) end
		outline(txt(bn, Config.Banner.title or "", 30, C.White, F, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 30) }), 3)
		outline(txt(bn, Config.Banner.subtitle or "", 15, C.White, F, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 72) }), 2)
		local sh = make("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(0.3, 0, 1, 0), BorderSizePixel = 0 }, bn)
		local sg = make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 1) }) }, sh)
		if not reduced() then task.spawn(function() while sh.Parent do sh.Position = UDim2.fromScale(-0.35, 0); TweenService:Create(sh, TweenInfo.new(1.4, Enum.EasingStyle.Sine), { Position = UDim2.fromScale(1.05, 0) }):Play(); task.wait(4) end end) end
	end
	local grid = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, body)
	make("UIGridLayout", { CellSize = UDim2.new(isTouch and 0.5 or 1 / 3, -8, 0, 214), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	local any = false
	for i, e in d.items do if e.tab == t then any = true
		local c = make("Frame", { BackgroundColor3 = C.White, LayoutOrder = i, ClipsDescendants = true }, grid); corner(c, 14); ink(c, 3)
		if e.available then grad(c, rgb(255, 227, 106), rgb(255, 106, 42), 135) else grad(c, rgb(169, 154, 168), rgb(111, 100, 120), 135) end
		make("UIStroke", { Color = e.available and C.Gold or rgb(138, 127, 142), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = 0.2 }, c)
		local p = preview(c, e, UDim2.new(1, -16, 0, 78), false); p.Position = UDim2.fromOffset(8, 8)
		if e.endsAt and e.available then local left = e.endsAt - d.serverTime; if left > 0 then local l = txt(p, ("Ends in %dd %dh"):format(left // 86400, (left // 3600) % 24), 10, C.Gold, F, { BackgroundTransparency = 0, BackgroundColor3 = C.Ink, Position = UDim2.fromOffset(4, 4) }); corner(l, 5); make("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, l) end end
		outline(txt(c, e.name, 18, C.White, F, { Position = UDim2.fromOffset(10, 92) }), 2.5)
		txt(c, e.available and e.description or "Coming soon", 12, C.Muted, FB, { Position = UDim2.fromOffset(10, 116), Size = UDim2.new(1, -20, 0, 34), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
		local holder = make("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 8, 1, -48), Size = UDim2.new(1, -16, 0, 40) }, c)
		local label = not e.available and "Coming soon" or e.owned and "Owned" or e.kind == "robux" and "Robux" or ("$" .. Config.Short(e.price))
		local b = button(holder, label, e.available and C.Green or rgb(168, 173, 187), function(btn) act("Buy", { id = e.id }, btn) end, nil, 34)
		b.set(e.available and not e.owned)
	end end
	if not any then message("Nothing for sale", "Check back soon.") end
end

render = function(keepScroll)
	if not current then return end
	local pos = body.CanvasPosition
	for _, c in panel:GetChildren() do if c:IsA("TextButton") and c.ZIndex == 8 then c:Destroy() end end
	clear(); footer.Visible = false; body.Size = UDim2.new(1, 0, 1, -108)
	title.Text = ({ index = "Index", plot = "Your Temple", quests = "Quests", shop = "Shop" })[current]
	sub.Text = ({ index = "", plot = "Only your own plot", quests = "Session progress · resets on rejoin", shop = "Cash and Robux" })[current]
	local d = data[current]
	if loading and not d then message("Loading…", "Getting this from the server.") return end
	if not d or d.error then message("Couldn't load this", (d and d.error) or "Try again in a moment."); button(body, "Retry", C.Red, function() load(current) end, 120, 36, 9); return end
	PAGES[current](d)
	if keepScroll ~= true then task.defer(function() body.CanvasPosition = pos end) end
end

---------------------------------------------------------------- nav buttons
local navButtons, badges = {}, {}
setOpen = function(id)
	if current == id then id = nil end
	current = id; ui.detail = nil
	for k, b in navButtons do local on = k == id; b.BackgroundColor3 = on and C.Red or C.Cream; b.Label.TextColor3 = on and C.White or C.Ink; b.Position = UDim2.fromOffset(0, on and 3 or 0) end
	panel.Visible = id ~= nil
	if id then
        local inventoryClient=require(RS.CharacterInventory.InventoryClient);inventoryClient.Close()
		sound("Open"); layout()
		if not reduced() then local target = panel.Position; panel.Position = target - UDim2.fromOffset(18, 0); TweenService:Create(panel, TweenInfo.new(0.24, Enum.EasingStyle.Back), { Position = target }):Play() end
		load(id)
	end
end
closeB.Activated:Connect(function() setOpen(nil) end)
local ICONS = { index = "rbxassetid://0", plot = "rbxassetid://0", quests = "rbxassetid://0", shop = "rbxassetid://0" } -- replace with your uploaded icon images
for i, n in { { "index", "INDEX" }, { "plot", "PLOT" }, { "quests", "QUESTS" }, { "shop", "SHOP" } } do
	local hold = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(76, 81), LayoutOrder = i }, nav)
	local base = make("Frame", { BackgroundColor3 = C.Ink, Position = UDim2.fromOffset(0, 5), Size = UDim2.fromOffset(76, 76) }, hold); corner(base, 14)
	local b = make("TextButton", { Text = "", BackgroundColor3 = C.Cream, Size = UDim2.fromOffset(76, 76), AutoButtonColor = false }, hold); corner(b, 14); ink(b, 3)
	for k = -1, 1 do local s = make("Frame", { BackgroundColor3 = C.Gold, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, k * 15, 0, 4), Size = UDim2.fromOffset(7, 4), BorderSizePixel = 0 }, b); corner(s, 2) end
	local symbol=({index="≡",plot="⌂",quests="✓",shop="$"})[n[1]];txt(b,symbol,30,C.Gold,F,{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,8),Size=UDim2.fromOffset(40,38),AutomaticSize=Enum.AutomaticSize.None,TextXAlignment=Enum.TextXAlignment.Center})
	txt(b, n[2], 13, C.Ink, F, { Name = "Label", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8) })
	local badge = make("TextLabel", { Text = "", FontFace = F, TextSize = 12, TextColor3 = C.White, BackgroundColor3 = C.Red, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(22, 22), Visible = false, ZIndex = 3 }, hold)
	corner(badge, 11); ink(badge, 2.5)
	b.MouseButton1Down:Connect(function() b.Position = UDim2.fromOffset(0, 5) end)
	b.MouseButton1Up:Connect(function() b.Position = UDim2.fromOffset(0, current == n[1] and 3 or 0) end)
	b.Activated:Connect(function() setOpen(n[1]) end)
	navButtons[n[1]], badges[n[1]] = b, badge
end

-- quest badge: only when something is actually claimable
local function refreshBadge()
	local ok, q = pcall(GetState.InvokeServer, GetState, "quests")
	local n = 0
	if ok and q and q.list then for _, x in q.list do if x.progress >= x.target and not x.claimed then n += 1 end end end
	badges.quests.Visible = n > 0; badges.quests.Text = tostring(n)
	if current == "quests" and ok then data.quests = q; render(true) end
end
local refreshScheduled=false
Changed.OnClientEvent:Connect(function()
 if acting or refreshScheduled then return end
 refreshScheduled=true
 task.delay(.3,function() refreshScheduled=false;if acting then return end;refreshBadge();if current and current~="quests" then task.wait(.12);load(current) end end)
end)

UserInputService.InputBegan:Connect(function(i, gp)
	if gp then return end
	local map = { [Enum.KeyCode.F2] = "index", [Enum.KeyCode.F3] = "plot", [Enum.KeyCode.F4] = "quests", [Enum.KeyCode.F6] = "shop" }
	if map[i.KeyCode] then setOpen(map[i.KeyCode])
	elseif i.KeyCode == Enum.KeyCode.Escape and current then setOpen(nil)
	elseif i.KeyCode == Enum.KeyCode.ButtonSelect then if current then setOpen(nil) else setOpen("index"); GuiService.SelectedObject = navButtons.index end end
end)
-- The new Plot menu replaces the old overlapping inventory HUD button; G and Inventory remain.
local function hideInventoryButton(g)
 if g.Name~="CharacterInventory" then return end
 local function hide(o) if o.Name=="InventoryButton" and o:IsA("GuiObject") then o.Visible=false;o:GetPropertyChangedSignal("Visible"):Connect(function()if o.Visible then o.Visible=false end end) end end
 for _,o in g:GetChildren() do hide(o) end;g.ChildAdded:Connect(hide)
end
for _,g in player.PlayerGui:GetChildren() do hideInventoryButton(g) end
player.PlayerGui.ChildAdded:Connect(hideInventoryButton)
layout(); refreshBadge()
