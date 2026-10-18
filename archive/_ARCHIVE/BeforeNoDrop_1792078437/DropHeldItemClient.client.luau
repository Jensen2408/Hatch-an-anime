local Players=game:GetService("Players")
local CAS=game:GetService("ContextActionService")
local player=Players.LocalPlayer
local function drop(_,state)
 if state~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
 local c=player.Character
 local tool=c and c:FindFirstChildOfClass("Tool")
 if player:GetAttribute("RiverEggCarryId") or (tool and tool:GetAttribute("HoldStyle")~="OneHand" and (tool:GetAttribute("EggType") or tool:GetAttribute("CharacterId"))) then
 game.ReplicatedStorage.DropHeldItem:FireServer()
 return Enum.ContextActionResult.Sink
 end
 return Enum.ContextActionResult.Pass
end
CAS:BindActionAtPriority("DropHeldEggOrCharacter",drop,true,2100,Enum.KeyCode.F)
CAS:SetTitle("DropHeldEggOrCharacter","Drop")
CAS:SetPosition("DropHeldEggOrCharacter",UDim2.new(1,-150,1,-210))

-- touch: the fixed spot above can land on the jump button on small phones, so sit the Drop button just left of jump
local function place()
 local btn=CAS:GetButton("DropHeldEggOrCharacter") if not btn or not btn.Parent then return end
 local pg=player:FindFirstChildOfClass("PlayerGui") local jump=pg and pg:FindFirstChild("JumpButton",true)
 if not jump or jump.AbsoluteSize.X<=0 then return end
 local f=btn.Parent.AbsolutePosition local j=jump.AbsolutePosition local js=jump.AbsoluteSize local bs=btn.AbsoluteSize
 btn.Position=UDim2.fromOffset(j.X-f.X-bs.X-10, j.Y-f.Y+(js.Y-bs.Y)/2)
end
task.spawn(function() while true do task.wait(0.5) place() end end)
