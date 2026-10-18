-- Framewisp billboard runtime. RunContext=Client makes this Script run on
-- each player's client even from Workspace (a LocalScript here would not),
-- so the billboard is self-contained: move or duplicate the anchor Part and
-- every copy keeps its effects. Sections are independent: delete one, the
-- rest keep working.

-- ======================================== FramewispShine
task.spawn(function()
local ok, err = pcall(function()
-- Framewisp: _shiny and _glint — your drawn shines in motion.
-- _shiny: sweeps across its parent in an endless loop, starting where you
--         placed it; after the whole formation leaves the right edge it
--         re-enters from the left.
local RunService = game:GetService("RunService")
local gui = script.Parent
local function fwRoots()
	local list = { gui }
	for _, v in ipairs(gui:GetChildren()) do
		if v:IsA("ObjectValue") and v.Name == "FW_ExtraRoot" and v.Value then
			list[#list + 1] = v.Value
		end
	end
	return list
end
local function fwAll()
	local out = {}
	for _, r in ipairs(fwRoots()) do
		for _, d in ipairs(r:GetDescendants()) do out[#out + 1] = d end
	end
	return out
end

-- ========================== tune the feel here ==========================
-- SPEED — _shiny travel speed, in parent-widths per second.
--   0.4 = slow, luxurious   ·   1.2 = default   ·   3 = fast flicker
-- COOLDOWN — pause between _shiny sweeps, in seconds.
--   0 = continuous conveyor   ·   2 = default glint   ·   6 = rare tease
-- GLINT_SPEED — _glint sweep speed on hover, in parent-widths per second.
--   1 = calm   ·   1.8 = default   ·   3 = snappy
-- ========================================================================
local SPEED = 1.2
local COOLDOWN = 2
local GLINT_SPEED = 1.8

local loops, glints = {}, {}
local function collect(attr, store)
	for _, d in ipairs(fwAll()) do
		if d:GetAttribute(attr) and d:IsA("GuiObject") and d.Parent and d.Parent:IsA("GuiObject") then
			d.Parent.ClipsDescendants = true
			d.Visible = true
			local w = d.Size.X.Scale
			if w <= 0 and d.Parent.AbsoluteSize.X > 0 then
				w = d.AbsoluteSize.X / d.Parent.AbsoluteSize.X
			end
			w = math.max(w, 0.01)
			local a = d.AnchorPoint.X
			local x0 = d.Position.X.Scale
			local g = store[d.Parent]
			if not g then
				g = { items = {}, off = 0, rest = 0, active = false, minLeft = math.huge, maxRight = -math.huge }
				store[d.Parent] = g
			end
			g.items[#g.items + 1] = { el = d, x0 = x0 }
			g.minLeft = math.min(g.minLeft, x0 - a * w)
			g.maxRight = math.max(g.maxRight, x0 + (1 - a) * w)
			g.speed = g.speed or d:GetAttribute("ShineSpeed") or d:GetAttribute("FigmaShineSpeed")
				or d:GetAttribute("GlintSpeed") or d:GetAttribute("FigmaGlintSpeed")
			g.cd = g.cd or d:GetAttribute("ShineCooldown") or d:GetAttribute("FigmaShineCooldown")
		end
	end
end
collect("FigmaShiny", loops)
collect("FigmaGlint", glints)

local function place(g)
	for _, it in ipairs(g.items) do
		local el = it.el
		if el.Parent then
			el.Position = UDim2.new(it.x0 + g.off, 0, el.Position.Y.Scale, el.Position.Y.Offset)
		end
	end
end

local list = {}
for _, g in pairs(loops) do list[#list + 1] = g end
local glist = {}
for parent, g in pairs(glints) do
	g.off = -g.maxRight
	place(g)
	glist[#glist + 1] = g
	parent.MouseEnter:Connect(function()
		if not g.active then
			g.off = -g.maxRight
			g.active = true
		end
	end)
end
if #list == 0 and #glist == 0 then return end

RunService.Heartbeat:Connect(function(dt)
	for _, g in ipairs(list) do
		if g.rest > 0 then
			g.rest = g.rest - dt
		else
			g.off = g.off + (g.speed or SPEED) * dt
			if g.minLeft + g.off > 1 then
				g.off = -g.maxRight
				g.rest = g.cd or COOLDOWN
			end
			place(g)
		end
	end
	for _, g in ipairs(glist) do
		if g.active then
			g.off = g.off + (g.speed or GLINT_SPEED) * dt
			if g.minLeft + g.off > 1 then
				g.off = -g.maxRight
				g.active = false
			end
			place(g)
		end
	end
end)

end)
if not ok then warn("[Framewisp] FramewispShine: " .. tostring(err)) end
end)

-- ======================================== FramewispTextScaler
task.spawn(function()
local ok, err = pcall(function()
-- Framewisp: keeps text and stroke sizes accurate at any screen resolution.
-- Safe to delete only if your UI never changes resolution (text will stop scaling).
local TextService = game:GetService("TextService")
local gui = script.Parent
do
	local okv, v = pcall(function() return script:GetAttribute("FWv") end)
	print("[Framewisp] TextScaler v" .. tostring(okv and v or "?") .. " in " .. gui.Name .. " — baselines are static, Play moves nothing")
end
local function fwRoots()
	local list = { gui }
	for _, v in ipairs(gui:GetChildren()) do
		if v:IsA("ObjectValue") and v.Name == "FW_ExtraRoot" and v.Value then
			list[#list + 1] = v.Value
		end
	end
	return list
end
local function fwAll()
	local out = {}
	for _, r in ipairs(fwRoots()) do
		for _, d in ipairs(r:GetDescendants()) do out[#out + 1] = d end
	end
	return out
end
local function fwScaleHost(el) -- Roblox honours ONE UIScale per object
	local sc = el:FindFirstChild("FW_Scale")
	if not sc then
		sc = el:FindFirstChildWhichIsA("UIScale")
		if sc then
			sc.Name = "FW_Scale"
		else
			sc = Instance.new("UIScale")
			sc.Name = "FW_Scale"
			sc:SetAttribute("FW_Owned", true)
			sc.Parent = el
		end
	end
	return sc
end
local function fwScaleApply(host)
	local total = 1
	for _, ch in ipairs(host:GetChildren()) do
		if ch:IsA("NumberValue") then total = total * ch.Value end
	end
	host.Scale = total
end
local function fwChannel(el, key) -- every runtime writes its OWN channel; the product applies once
	local host = fwScaleHost(el)
	local ch = host:FindFirstChild(key)
	if not ch then
		ch = Instance.new("NumberValue")
		ch.Name = key
		ch.Value = 1
		ch:SetAttribute("FW_Owned", true)
		ch.Parent = host
		ch.Changed:Connect(function() fwScaleApply(host) end)
	end
	return ch
end
local function fwRotSet(el, key, deg) -- Rotation is shared by three runtimes too
	local base = el:GetAttribute("FW_RotBase")
	if base == nil then
		base = el.Rotation
		el:SetAttribute("FW_RotBase", base)
	end
	el:SetAttribute(key, deg)
	local total = 0
	for _, k in ipairs({ "r_juice", "r_spin", "r_tl", "r_hover" }) do
		local v = el:GetAttribute(k)
		if type(v) == "number" then total = total + v end
	end
	el.Rotation = base + total
end
local function findRoot()
	local fallback = nil
	for _, child in ipairs(gui:GetChildren()) do
		if child:IsA("BillboardGui") then -- _billboard: the design lives one level deeper
			local inner = child:FindFirstChildWhichIsA("GuiObject")
			if inner then return inner end
		end
		if child:IsA("ObjectValue") and child.Name == "FW_ExtraRoot" and child.Value then
			local inner = child.Value:FindFirstChildWhichIsA("GuiObject")
			if inner then return inner end
		end
		if child:IsA("GuiObject") then
			fallback = fallback or child
			if child:GetAttribute("FW_Owned") == true then return child end
		end
	end
	return fallback
end
local root = findRoot()
if not root then return end
local designH = gui:GetAttribute("BB_DesignH") or 1080
local designW = gui:GetAttribute("BB_DesignW")
local factor = gui:GetAttribute("BB_TextFactor") or 1.16
local w100 = setmetatable({}, { __mode = "k" })
local gridInfo = setmetatable({}, { __mode = "k" })
local function fwRenders()
	local cam = workspace.CurrentCamera
	return cam ~= nil and cam.ViewportSize.X >= 2 and cam.ViewportSize.Y >= 2
end

local function fwHoverRoom(cells, cellW, cellH)
	local hs = 1
	if cells then
		for _, c in ipairs(cells:GetChildren()) do
			if c:IsA("GuiObject") and c:GetAttribute("FigmaSmooth") then
				local v = c:GetAttribute("SmoothHover") or c:GetAttribute("FigmaSmoothHover") or 1.08
				if type(v) == "number" and v > hs then hs = v end
			end
		end
	end
	if hs <= 1 then return 0, 0 end
	return cellW * (hs - 1) / 2, cellH * (hs - 1) / 2
end

local gridGeometry, gridScroll -- mutually recursive: a re-fit updates the canvas

local function gridRatio(cells, fallback, smScale)
	local grid = cells and cells:FindFirstChildWhichIsA("UIGridLayout")
	if not grid then return fallback end
	local winW = grid:GetAttribute("FigmaWinW") or 0
	if winW <= 0 then return fallback end
	local host = cells.Parent
	local live = ((host and host:IsA("ScrollingFrame")) and host.AbsoluteSize.X or cells.AbsoluteSize.X) / smScale
	if live <= 1 then return fallback end
	return live / winW
end

function gridGeometry(d, k, kx, smScale)
	if d:IsA("UIPadding") and d:GetAttribute("FigmaPadL") ~= nil then
		local gs = gridRatio(d.Parent, kx, smScale)
		d.PaddingLeft = UDim.new(0, (d:GetAttribute("FigmaPadL") or 0) * gs)
		d.PaddingTop = UDim.new(0, (d:GetAttribute("FigmaPadT") or 0) * gs)
		d.PaddingBottom = UDim.new(0, (d:GetAttribute("FigmaPadB") or 0) * gs)
		return
	end
	if not (d:IsA("UIGridLayout") and d:GetAttribute("FigmaCellW") ~= nil) then return end
	local cells = d.Parent
	local cols = math.max(1, d.FillDirectionMaxCells)
	local gs = gridRatio(cells, kx, smScale)
	local cellWD = d:GetAttribute("FigmaCellW") or 0
	local cellHD = d:GetAttribute("FigmaCellH") or 0
	local gapXD = d:GetAttribute("FigmaGapX") or 0
	local gapYD = d:GetAttribute("FigmaGapY") or 0
	local pad = cells and cells:FindFirstChildWhichIsA("UIPadding")
	local padLD = (pad and pad:GetAttribute("FigmaPadL")) or 0

	local sf = cells and cells.Parent
	local barD = 0
	if sf and sf:IsA("ScrollingFrame") then
		barD = sf:GetAttribute("FigmaBar") or sf.ScrollBarThickness
		local mineBar = sf:GetAttribute("FW_BarPx")
		if type(mineBar) == "number" and math.abs(sf.ScrollBarThickness - mineBar) > 0.5 then
			barD = sf.ScrollBarThickness / (gs > 0.001 and gs or 1)
			sf:SetAttribute("FigmaBar", barD)
		end
		local wantBar = math.max(2, barD * gs)
		sf.ScrollBarThickness = wantBar
		sf:SetAttribute("FW_BarPx", wantBar)
	end

	local roomD = d:GetAttribute("FigmaHoverRoom")
	if roomD == nil then roomD = select(1, fwHoverRoom(cells, cellWD, cellHD)) end
	local hostW = ((sf and sf:IsA("ScrollingFrame")) and sf.AbsoluteSize.X) or (cells and cells.AbsoluteSize.X) or 0
	local availD = (hostW / smScale) / math.max(gs, 1e-6)
	local cellW = cellWD
	if availD > 1 then
		local maxD = (availD - padLD - (cols - 1) * gapXD - barD - roomD) / cols
		if maxD > 0 and maxD < cellW then cellW = maxD end
	end
	local cellH = cellHD * (cellW / math.max(cellWD, 1e-6)) -- keep the card's shape

	d.CellSize = UDim2.fromOffset(math.max(1, cellW * gs), math.max(1, cellH * gs))
	d.CellPadding = UDim2.fromOffset(gapXD * gs, gapYD * gs)

	local info = gridInfo[d]
	if not info then
		info = {}
		gridInfo[d] = info
	end
	if cells and not info.sizeWired then
		info.sizeWired = true
		cells:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if info.refit and not info.busy and fwRenders() then
				info.busy = true
				info.refit()
				info.busy = false
			end
		end)
	end
	info.refit = function()
		gridGeometry(d, k, kx, smScale)
		if pad then gridGeometry(pad, k, kx, smScale) end -- the origin rides along
		if sf then gridScroll(sf) end
	end
end

function gridScroll(sf)
	if not (sf:IsA("ScrollingFrame") and sf:GetAttribute("FWGridScroll")) then return end
	local cells, grid
	for _, c in ipairs(sf:GetChildren()) do
		if c.Name == "Cells" and c:GetAttribute("FW_Owned") then
			local g = c:FindFirstChildWhichIsA("UIGridLayout")
			if g then cells, grid = c, g break end
		end
	end
	if not grid then return end
	local pad = cells:FindFirstChildWhichIsA("UIPadding")
	local info = gridInfo[grid]
	if not info then
		info = {}
		gridInfo[grid] = info
	end
	if not info.canvasWired then
		info.canvasWired = true
		grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			if info.set and fwRenders() then info.set() end
		end)
		cells.ChildAdded:Connect(function() if info.set and fwRenders() then info.set() end end)
		cells.ChildRemoved:Connect(function() if info.set and fwRenders() then info.set() end end)
	end
	info.set = function()
		local cellH = grid.CellSize.Y.Offset
		local gapY = grid.CellPadding.Y.Offset
		local pt = pad and pad.PaddingTop.Offset or 0
		local pb = pad and pad.PaddingBottom.Offset or 0
		local step = cellH + gapY
		local rows = 0
		if step > 0 then
			rows = math.max(0, math.floor((grid.AbsoluteContentSize.Y + gapY) / step + 0.5))
		end
		if rows == 0 then
			local n = 0
			for _, c in ipairs(cells:GetChildren()) do
				if c:IsA("GuiObject") and c.Visible then n = n + 1 end
			end
			rows = math.ceil(n / math.max(1, grid.FillDirectionMaxCells))
		end
		local h = rows > 0 and (pt + rows * cellH + (rows - 1) * gapY + pb) or 0
		if h <= sf.AbsoluteWindowSize.Y + 1 then h = 0 end
		sf.CanvasSize = UDim2.fromOffset(0, h)
	end
	info.set()
end

local function measure(d)
	local cached = w100[d]
	if cached ~= nil then return cached end
	local ok, b = pcall(function()
		local prm = Instance.new("GetTextBoundsParams")
		prm.Text = (d.ContentText:gsub("^%s+", ""):gsub("%s+$", ""))
		prm.Font = d.FontFace
		prm.Size = 100
		prm.Width = 1e6
		return TextService:GetTextBoundsAsync(prm)
	end)
	if ok and b and b.X > 0 then
		w100[d] = b.X
		return b.X
	end
	if ok then
		w100[d] = false
	end
	return nil
end
local function setTextPx(d, t, exact)
	if d:FindFirstAncestorWhichIsA("BillboardGui") then return end -- billboards size their own text
	local mine = d:GetAttribute("FW_TextMine")
	if type(mine) == "number" and (math.abs(d.TextSize - mine) > 0.5
		or d.TextScaled ~= (d:GetAttribute("FW_TextScaledMine") == true)) then
		d:SetAttribute("FW_TextOwn", true)
	end
	if d:GetAttribute("FW_TextOwn") then return end
	local sc = fwChannel(d, "k_text")
	local con = d:FindFirstChild("FWTextBig")
	if t > 100 and t <= 500 and exact then
		sc.Value = 1
		if not con then
			con = Instance.new("UITextSizeConstraint")
			con.Name = "FWTextBig"
			con:SetAttribute("FW_Owned", true)
			con.Parent = d
		end
		local px = math.floor(t)
		con.MinTextSize = px
		con.MaxTextSize = px
		d.TextScaled = true
		d.TextSize = 100
	elseif t > 100 then
		if con then con:Destroy() end
		d.TextScaled = false
		sc.Value = t / 100
		d.TextSize = 100
	else
		if con then con:Destroy() end
		d.TextScaled = false
		sc.Value = 1
		local px = exact and math.floor(t) or math.floor(t + 0.5)
		d.TextSize = math.max(1, px)
	end
	d:SetAttribute("FW_TextMine", d.TextSize)
	d:SetAttribute("FW_TextScaledMine", d.TextScaled)
end
local gen = 0
local coldTries = 0
local printedPass = false
local smHooked, smPend = nil, false
local apply
local function smRerun()
	if smPend then return end
	smPend = true
	task.delay(0.2, function()
		smPend = false
		apply()
	end)
end
function apply()
	gen = gen + 1
	local myGen = gen
	local sm = root:FindFirstChild("FW_Scale") or root:FindFirstChild("FramewispSmooth") or root:FindFirstChild("FWActScale")
	local smScale = (sm and sm:IsA("UIScale") and sm.Scale > 0) and sm.Scale or 1
	if sm and sm ~= smHooked and sm:IsA("UIScale") then
		smHooked = sm
		sm:GetPropertyChangedSignal("Scale"):Connect(smRerun) -- solved mid-tween = a size compensating a scale that finished at 1
	end
	local k = root.AbsoluteSize.Y / designH / smScale
	if k <= 0 then return end
	if not fwRenders() then return end
	if root.AbsoluteSize.X < 2 or root.AbsoluteSize.Y < 2 then return end
	local kx = (type(designW) == "number" and designW > 0) and root.AbsoluteSize.X / designW / smScale or k
	local transient = false
	local nExact, nFallback = 0, 0
	for _, d in ipairs(root:GetDescendants()) do
		if myGen ~= gen then return end
		local fs = d:GetAttribute("FigmaFontSize")
		if fs then
			local m = nil
			local tw = d:GetAttribute("FigmaTextW")
			if type(tw) == "number" and tw > 0 then
				local t0 = d:GetAttribute("FW_Text0")
				if t0 == nil then
					t0 = d.ContentText
					d:SetAttribute("FW_Text0", t0)
				end
				if d.ContentText == t0 then
					m = d:GetAttribute("FW_M100") or measure(d) -- stamped at import: no font race, same numbers as the editor
					if m == nil and w100[d] == nil then transient = true end
				end
				if myGen ~= gen then return end
			end
			if m then
				setTextPx(d, 100 * (tw * kx) / m, true)
				nExact = nExact + 1
			else
				setTextPx(d, fs * k * factor)
				nFallback = nFallback + 1
			end
		end
		local swMine = d:GetAttribute("FW_StrokeMine")
		if type(swMine) == "number" and math.abs(d.Thickness - swMine) > 0.01 then
			d:SetAttribute("FW_StrokeOwn", true)
		end
		if not d:GetAttribute("FW_StrokeOwn") and not d:GetAttribute("FW_StrokeScaled") then -- a fraction, not pixels
			local sw = d:GetAttribute("FigmaStrokeW")
			if sw then d.Thickness = math.max(0.35, sw * k) end
			local tsw = d:GetAttribute("FigmaTextStrokeW")
			if tsw then
				local ps = d.Parent and d.Parent:FindFirstChild("FW_Scale")
				d.Thickness = math.max(0.35, tsw * k * factor / ((ps and ps.Scale) or 1))
			end
			if sw or tsw then d:SetAttribute("FW_StrokeMine", d.Thickness) end
		end
		gridGeometry(d, k, kx, smScale)
		gridScroll(d)
	end
	gridScroll(root) -- the root can BE the scrolling grid
	if not printedPass and (nExact + nFallback) > 0 then
		printedPass = true
		print(("[Framewisp] TextScaler: %d width-exact, %d fallback"):format(nExact, nFallback))
		local rootH = root.AbsoluteSize.Y
		local worst, shown = {}, 0
		if rootH > 1 then
			for _, d in ipairs(root:GetDescendants()) do
				local tag = d:GetAttribute("FW_EDbg")
				if type(tag) == "string" and d:IsA("TextLabel") and d.AbsoluteSize.Y > 0 then
					local eL, eC = tag:match("([%d.]+)|([%d.]+)")
					eL, eC = tonumber(eL), tonumber(eC)
					if eL and eC then
						local pL = d.TextSize / rootH
						local pC = (d.AbsolutePosition.Y - root.AbsolutePosition.Y + d.AbsoluteSize.Y / 2) / rootH
						local dl, dc = pL - eL, pC - eC
						if math.abs(dl) > 0.002 or math.abs(dc) > 0.002 then
							worst[#worst + 1] = { n = d.Name, dl = dl * rootH, dc = dc * rootH }
						end
					end
				end
			end
		end
		table.sort(worst, function(a, b) return math.abs(a.dc) + math.abs(a.dl) > math.abs(b.dc) + math.abs(b.dl) end)
		for i = 1, math.min(3, #worst) do
			local x = worst[i]
			print(("[Framewisp] play vs edit %q: size %+.1f px, centre %+.1f px"):format(x.n, x.dl, x.dc))
		end
		if #worst == 0 then
			print("[Framewisp] play matches the editor within 0.2% — any remaining shift is pure rendering")
		end
	end
	if transient and coldTries < 6 then
		coldTries = coldTries + 1
		task.delay(0.5, function()
			if myGen == gen then apply() end
		end)
	end
end
local pending = false
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if pending then return end
	pending = true
	task.spawn(function()
		task.wait()
		pending = false
		apply()
	end)
end)
apply()

end)
if not ok then warn("[Framewisp] FramewispTextScaler: " .. tostring(err)) end
end)
