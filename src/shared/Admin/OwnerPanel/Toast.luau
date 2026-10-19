--[[ ReplicatedStorage.OwnerPanel.Toast  (ModuleScript)
Legacy v2 panel: bottom-right result toast (green on success, red on error) that fades out after 2.6 s. A newer toast
replaces the old one; showToken makes an older toast's delayed fade a no-op.
Note: both branches of the bullet prefix are the same string (pre-existing).
]]
local Components = require(script.Parent.Components)
local Theme = require(script.Parent.Theme)
local TweenService = game:GetService("TweenService")
local Toast = {}
local showToken = 0
function Toast.Show(parent, message, isSuccess)
    showToken += 1
    local myToken = showToken
    local oldToast = parent:FindFirstChild("OwnerToast")
    if oldToast then
        oldToast:Destroy()
    end
    local toast = Components.Make("CanvasGroup", {
        Name = "OwnerToast",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.new(0, math.min(420, parent.AbsoluteSize.X - 32), 0, 78),
        BackgroundColor3 = isSuccess and Theme.SuccessBG or Theme.ErrorBG,
        GroupTransparency = 1,
        ZIndex = 50,
    }, parent)
    Components.Round(toast, 14)
    local label = Components.Label(
        toast,
        (isSuccess and "●  " or "●  ") .. message,
        14,
        isSuccess and Theme.Success or Theme.Error
    )
    label.Position = UDim2.fromOffset(16, 10)
    label.Size = UDim2.new(1, -32, 1, -20)
    label.ZIndex = 51
    TweenService:Create(toast, TweenInfo.new(0.2), { GroupTransparency = 0 }):Play()
    task.delay(2.6, function()
        if myToken == showToken and toast.Parent then
            TweenService:Create(toast, TweenInfo.new(0.2), { GroupTransparency = 1 }):Play()
            task.delay(0.2, function()
                toast:Destroy()
            end)
        end
    end)
end
return Toast
