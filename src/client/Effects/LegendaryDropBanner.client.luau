-- LegendaryDropBanner (LocalScript, StarterPlayerScripts)
-- Gold banner at the top of the screen whenever a Legendary egg enters the river. Watches the workspace attribute
-- LastLegendaryAt (written by RiverEggSpawnScheduler); the river board shows the countdown to the next one.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MenuArt = require(ReplicatedStorage:WaitForChild("MenuArt"):WaitForChild("MenuArt"))
local HudScale = require(ReplicatedStorage:WaitForChild("HudScale"))
local UISound = require(ReplicatedStorage:WaitForChild("UISound"))

local SHOW_SECONDS = 4
local BANNER_SIZE = Vector2.new(640, 88)

local gui = Instance.new("ScreenGui")
gui.Name = "LegendaryDropBanner"
gui.ResetOnSpawn = false
gui.DisplayOrder = 60
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local banner = MenuArt.new("Frame", "Banner", gui, 1)
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 96)
banner.Size = UDim2.fromOffset(BANNER_SIZE.X, BANNER_SIZE.Y)
banner.Visible = false
local bannerScale = Instance.new("UIScale")
bannerScale.Parent = banner
MenuArt.piece(banner, "Plate", "OffGold", { 0, 0, BANNER_SIZE.X, BANNER_SIZE.Y }, 1, 18)
MenuArt.label(
    banner,
    "Label",
    "LEGENDARY EGG IN THE RIVER!",
    { 24, 12, BANNER_SIZE.X - 48, BANNER_SIZE.Y - 28 },
    40,
    nil,
    2,
    { alignX = Enum.TextXAlignment.Center }
)

local showCount = 0
workspace:GetAttributeChangedSignal("LastLegendaryAt"):Connect(function()
    showCount += 1
    local thisShow = showCount
    local fit = HudScale.For(gui.AbsoluteSize)
    banner.Position = UDim2.new(0.5, 0, 0, 96 * fit)
    bannerScale.Scale = fit * 0.5
    banner.Visible = true
    UISound.Play("Purchase")
    TweenService:Create(bannerScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = fit }):Play()
    task.delay(SHOW_SECONDS, function()
        if thisShow == showCount then
            banner.Visible = false
        end
    end)
end)
