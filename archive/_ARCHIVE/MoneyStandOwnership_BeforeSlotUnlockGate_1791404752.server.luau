local CS=game:GetService("CollectionService")
local templates=game.ServerStorage:WaitForChild("MoneyStandPlotTemplates")
local function setup(plot)
 local function refresh()
  local owner=plot:GetAttribute("OwnerUserId") or 0
  local folder=templates:FindFirstChild(plot.Name)
  for _,slot in plot.Slots:GetChildren() do
   local stand=slot:FindFirstChild("MoneyStand")
   if owner==0 then
    if stand then CS:RemoveTag(stand,"MoneyStand");stand:Destroy() end
   else
    if not stand then
     local template=folder and folder:FindFirstChild(slot.Name)
     if template then
      stand=template:Clone();stand.Name="MoneyStand"
      stand:SetAttribute("OwnerUserId",owner);stand:SetAttribute("Stored",0)
      stand:SetAttribute("IncomePerSecond",0);stand:SetAttribute("Pressed",false)
      stand.Parent=slot;CS:AddTag(stand,"MoneyStand")
     end
    elseif stand:GetAttribute("OwnerUserId")~=owner then
     stand:SetAttribute("OwnerUserId",owner);stand:SetAttribute("Stored",0)
     stand:SetAttribute("IncomePerSecond",0);stand:SetAttribute("Pressed",false)
    end
   end
  end
 end
 plot:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh);refresh()
end
for _,plot in workspace.Plots:GetChildren() do setup(plot) end
workspace.Plots.ChildAdded:Connect(setup)
