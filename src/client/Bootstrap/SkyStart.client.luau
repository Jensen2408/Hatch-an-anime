--[[ ReplicatedFirst.SkyStart (2026-11-08) - replaces the loading screen (ReplicatedFirst.LoadingScreen is disabled, not deleted).
No logo, no bar: a plain sky-coloured cover hides the spawn for a moment, then JoinArrival flies the camera down from
the sky to your character. Keeps the same handshake attributes the old loading screen used:
  LoadingScreenFinishing -> JoinArrival starts and sets JoinArrivalCameraSet -> cover fades -> LoadingScreenDone ]]
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
ReplicatedFirst:RemoveDefaultLoadingScreen()

local gui = Instance.new("ScreenGui")
gui.Name = "HatchLoading" -- the name JoinArrival waits for
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
local cover = Instance.new("Frame")
cover.Size = UDim2.fromScale(1, 1)
cover.BorderSizePixel = 0
cover.BackgroundColor3 = Color3.fromRGB(214, 236, 255) -- same sky colour as JoinArrival's cover
cover.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")

if not game:IsLoaded() then
    game.Loaded:Wait()
end
player:SetAttribute("LoadingScreenFinishing", true)
local start = os.clock()
while not player:GetAttribute("JoinArrivalCameraSet") and os.clock() - start < 12 do
    task.wait(0.05)
end
TweenService:Create(cover, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 }):Play()
task.wait(0.5)
player:SetAttribute("LoadingScreenDone", true)
gui:Destroy()
