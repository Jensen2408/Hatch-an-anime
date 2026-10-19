--[[ ReplicatedStorage.OwnerPanel.ConfirmDialog  (ModuleScript)
Legacy v2 panel: modal "Confirm <action>" card over `parent`; callback runs only on Confirm. Replaces an open dialog.
Client-side confirmation only: the server still requires args.confirmed for dangerous actions.
]]
local Components = require(script.Parent.Components)
local Theme = require(script.Parent.Theme)
local ConfirmDialog = {}
function ConfirmDialog.Show(parent, action, target, warning, callback)
    local oldDialog = parent:FindFirstChild("OwnerConfirm")
    if oldDialog then
        oldDialog:Destroy()
    end
    local cover = Components.Make("Frame", {
        Name = "OwnerConfirm",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Input,
        BackgroundTransparency = 0.1,
        ZIndex = 30,
    }, parent)
    local card = Components.Card(cover, "Confirm " .. action)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.new(0.85, 0, 0, 0)
    card.ZIndex = 31
    Components.Label(card, "TARGET: " .. target, 14, Theme.Gold)
    Components.Label(card, warning, 14, Theme.Muted)
    Components.Button(card, "Cancel", function()
        cover:Destroy()
    end)
    Components.Button(card, "Confirm", function()
        cover:Destroy()
        callback()
    end, Theme.Red)
    for _, descendant in card:GetDescendants() do
        if descendant:IsA("GuiObject") then
            descendant.ZIndex = 32
        end
    end
end
return ConfirmDialog
