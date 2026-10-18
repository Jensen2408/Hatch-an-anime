local C=require(script.Parent.Components) local T=require(script.Parent.Theme) local M={}
function M.Show(parent,action,target,warning,callback)
local old=parent:FindFirstChild("OwnerConfirm") if old then old:Destroy() end
local cover=C.Make("Frame",{Name="OwnerConfirm",Size=UDim2.fromScale(1,1),BackgroundColor3=T.Input,BackgroundTransparency=.1,ZIndex=30},parent)
local card=C.Card(cover,"Confirm "..action) card.AnchorPoint=Vector2.new(.5,.5) card.Position=UDim2.fromScale(.5,.5) card.Size=UDim2.new(.85,0,0,0) card.ZIndex=31
C.Label(card,"TARGET: "..target,14,T.Gold) C.Label(card,warning,14,T.Muted)
C.Button(card,"Cancel",function() cover:Destroy() end)
C.Button(card,"Confirm",function() cover:Destroy() callback() end,T.Red)
for _,o in card:GetDescendants() do if o:IsA("GuiObject") then o.ZIndex=32 end end
end return M