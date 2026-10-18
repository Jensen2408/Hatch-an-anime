-- PlayerGui buttons, including menus built after join, share the same audio palette.
-- Activated supports mouse, touch, and gamepad. UISound guards duplicate bindings.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UISound = require(ReplicatedStorage:WaitForChild("UISound"))
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

UISound.AttachDescendants(playerGui)
