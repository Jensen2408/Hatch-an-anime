-- Idle loop for the Pumpkin Gentleman: breathing, look around, cane tap, hat tip, flickering face.
local M=script.Parent
local root=M.Root
local function motor(n) return root:FindFirstChild(n,true) or M:FindFirstChild(n,true) end
local hips=motor("HipsMotor") local head=motor("HeadMotor") local hat=motor("HatMotor")
local shL=motor("ShoulderLMotor") local shR=motor("ShoulderRMotor")
local base={} for _,m in ipairs({hips,head,hat,shL,shR}) do base[m]=m.C0 end
local face=M:FindFirstChild("FaceGlow",true)
local glowParts={} for _,p in ipairs(M:GetDescendants()) do if p:IsA("BasePart") and p.Material==Enum.Material.Neon then table.insert(glowParts,p) end end
local LOOP=8
local function ease(t) return (1-math.cos(math.pi*math.clamp(t,0,1)))/2 end
local function pulse(t,a,b) if t<a or t>b then return 0 end return math.sin(math.pi*(t-a)/(b-a)) end
local rad=math.rad
local t0=os.clock()
game:GetService("RunService").Heartbeat:Connect(function()
	local t=(os.clock()-t0)%LOOP
	local br=math.sin(t/LOOP*math.pi*2*4)
	hips.C0=base[hips]*CFrame.new(0,0.15*br,0)*CFrame.Angles(rad(1.2)*br,0,0)
	-- look left, hold, look right, hold
	local yaw=0
	if t<1.5 then yaw=ease(t/1.5)*18 elseif t<3 then yaw=18 elseif t<4.5 then yaw=18-ease((t-3)/1.5)*36 elseif t<6 then yaw=-18 else yaw=-18+ease((t-6)/1.2)*18 end
	head.C0=base[head]*CFrame.Angles(rad(-3*br),rad(yaw),rad(yaw*0.15))
	-- cane taps
	local tap=pulse(t,3.2,3.5)+pulse(t,3.6,3.9)
	shR.C0=base[shR]*CFrame.Angles(rad(-10*tap),0,0)
	shL.C0=base[shL]*CFrame.Angles(rad(4*math.sin(t/LOOP*math.pi*2)),0,rad(-2*br))
	-- hat tip
	local tip=pulse(t,6.6,7.8)
	hat.C0=base[hat]*CFrame.new(0,1.2*tip,-0.6*tip)*CFrame.Angles(rad(-25*tip),0,0)
	-- candle flicker
	local f=0.75+0.25*math.noise(os.clock()*3,0.5)+0.1*math.random()
	if face then face.Brightness=3*f end
end)
