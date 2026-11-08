-- MoneyDisplay.CashComponent  (ModuleScript, client)
-- The cash card in the Folk Stud look (2026-11-07): a white studded plate with a black outline and a hard shadow,
-- the game's coin breaking out over the left edge on faint spinning rays, the amount in candy green with a light
-- sweeping over its outline, and a flat green income pill underneath. Display only; MoneyLogic feeds it.
-- Same API and the same names MoneyLogic looks for (MainBackground > CoinIcon), so MoneyLogic is unchanged:
--
--   local cash = CashComponent.new(screenGui)
--   cash:SetCash(4200000)   --> "$4.2M"
--   cash:SetIncome(25)      --> "+$25 / sec"
--   cash:SetVisible(true)
-- Old version: ServerStorage._ARCHIVE.CashComponent_BeforeStud_2026-11-07
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local M = require(ReplicatedStorage:WaitForChild("FolkStudUI"))
local H = M.H
local Config = require(script.Parent:WaitForChild("CashConfig"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("CharacterInventory"):WaitForChild("InventoryFormat"))

local COIN = "rbxassetid://136807180106184"   -- FOLK cash stack (i_cash)
local CASH_GREEN = H.hex("2BF08C")
local W, HGT = Config.RootSize.X, Config.RootSize.Y   -- 330 x 141, MoneyLogic lays the card out by this size

local CashComponent = {}
CashComponent.__index = CashComponent

-- 1000 -> "$1K", 4200000 -> "$4.2M" (InventoryFormat.Short truncates, never rounds up)
function CashComponent.FormatCash(value)
	return "$" .. NumberFormat.Short(value)
end

-- a label that fits its box: long amounts shrink instead of running off the plate
local function fitText(parent, name, x, y, w, h, maxSize, z, col)
	local l = H.new("TextLabel", { Name = name, BackgroundTransparency = 1, FontFace = M.FONT, Text = "", TextScaled = true, TextColor3 = col,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z }, parent)
	H.new("UITextSizeConstraint", { MaxTextSize = maxSize }, l)
	H.new("UIStroke", { Name = "UIStroke", Thickness = 3.7, Color = H.BLACK, LineJoinMode = Enum.LineJoinMode.Bevel }, l)
	return l
end

function CashComponent.new(parent)
	local self = setmetatable({}, CashComponent)
	local root = H.new("Frame", { Name = "CashUI", BackgroundTransparency = 1, Size = UDim2.fromOffset(W, HGT) }, nil)
	self.Scale = H.new("UIScale", {}, root)

	-- the plate: white sheet, faint studs, black outline, hard shadow (read only, so no lip)
	local PX, PY, PW, PH = 22, 8, 296, 84
	H.shadow(root, "Main", PX, PY, PW, PH, 16, 2)
	local plate = H.rect(root, "MainBackground", PX, PY, PW, PH, 16, 3, H.WHITE)
	H.ink(plate, 4)
	H.studs(plate, Vector2.new(50, 46), 0.8, 16, 3)
	H.shine(plate, 16, 4)

	-- the coin breaks out over the left edge, on faint spinning gold rays
	H.beams(plate, 22, PH / 2, 140, 4, H.hex("FFD000"), 0.35, 6)
	local coin = H.art(plate, "CoinIcon", COIN, 22, PH / 2 - 2, 96, 6)
	H.sparkle(plate, "Twinkle1", 62, 10, 22, 7, 0)
	H.sparkle(plate, "Twinkle2", -14, 74, 18, 7, 0.5)

	-- the amount, in candy green with a light sweeping over its outline
	self.CashAmount = fitText(plate, "CashAmount", 76, 10, PW - 90, PH - 20, 50, 8, CASH_GREEN)
	H.gleam(self.CashAmount)

	-- income per second: a flat green pill under the plate
	local IW, IH = 200, 38
	local ix = PX + (PW - IW) / 2 + 20
	H.shadow(root, "Income", ix, PY + PH + 4, IW, IH, 12, 2)
	local pill = H.rect(root, "IncomePanel", ix, PY + PH + 4, IW, IH, 12, 4, H.WHITE)
	H.ink(pill, 4)
	H.grad(pill, M.COLOR.leaf[1], M.COLOR.leaf[2])
	self.IncomeText = fitText(pill, "IncomeText", 10, 3, IW - 20, IH - 6, 26, 6, H.WHITE)

	M.animate(root, { sounds = false })
	self.Root = root
	self:SetCash(0)
	self:SetIncome(0)
	root.Parent = parent
	return self
end

function CashComponent:SetCash(value)
	local t = CashComponent.FormatCash(value)
	if self.CashAmount.Text ~= t then self.CashAmount.Text = t end
end

function CashComponent:SetIncome(perSecond)
	local t = "+" .. CashComponent.FormatCash(perSecond) .. Config.IncomeSuffix
	if self.IncomeText.Text ~= t then self.IncomeText.Text = t end
end

function CashComponent:SetVisible(visible)
	self.Root.Visible = visible
end

function CashComponent:Destroy()
	self.Root:Destroy()
end

return CashComponent
