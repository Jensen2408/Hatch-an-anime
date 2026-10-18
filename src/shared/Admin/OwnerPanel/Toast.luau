local C = require(script.Parent.Components)
local T = require(script.Parent.Theme)
local Tween = game:GetService("TweenService")
local M = {}
local token = 0
function M.Show(parent, message, ok)
    token += 1
    local id = token
    local old = parent:FindFirstChild("OwnerToast")
    if old then
        old:Destroy()
    end
    local f = C.Make("CanvasGroup", {
        Name = "OwnerToast",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.new(0, math.min(420, parent.AbsoluteSize.X - 32), 0, 78),
        BackgroundColor3 = ok and T.SuccessBG or T.ErrorBG,
        GroupTransparency = 1,
        ZIndex = 50,
    }, parent)
    C.Round(f, 14)
    local l = C.Label(f, (ok and "●  " or "●  ") .. message, 14, ok and T.Success or T.Error)
    l.Position = UDim2.fromOffset(16, 10)
    l.Size = UDim2.new(1, -32, 1, -20)
    l.ZIndex = 51
    Tween:Create(f, TweenInfo.new(0.2), { GroupTransparency = 0 }):Play()
    task.delay(2.6, function()
        if id == token and f.Parent then
            Tween:Create(f, TweenInfo.new(0.2), { GroupTransparency = 1 }):Play()
            task.delay(0.2, function()
                f:Destroy()
            end)
        end
    end)
end
return M
