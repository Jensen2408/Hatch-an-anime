local function setup(plot)
 local function reset()
  for _,slot in plot.Slots:GetChildren() do
   local stand=slot:FindFirstChild("MoneyStand")
   if stand then
    stand:SetAttribute("OwnerUserId",plot:GetAttribute("OwnerUserId") or 0)
    stand:SetAttribute("Stored",0);stand:SetAttribute("IncomePerSecond",0);stand:SetAttribute("Pressed",false)
   end
  end
 end
 plot:GetAttributeChangedSignal("OwnerUserId"):Connect(reset);reset()
end
for _,plot in workspace.Plots:GetChildren() do setup(plot) end
workspace.Plots.ChildAdded:Connect(setup)
