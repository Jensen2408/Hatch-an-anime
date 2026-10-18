-- EggSellService: sells an egg Tool from the player's own backpack/hand for cash. Server decides the price.
-- Price = 40% of the egg's shop price; free eggs sell for $0. Limited, golden and owner-test eggs can't be sold.
local Players=game:GetService("Players") local RS=game:GetService("ReplicatedStorage")
local Catalog=require(RS:WaitForChild("CharacterCatalog"))
local remote=RS:FindFirstChild("SellEgg") or Instance.new("RemoteFunction") remote.Name="SellEgg" remote.Parent=RS
local SELL_RATE=0.4 -- eggs sell for 40% of their shop price
local last={}
local function priceOf(tool)
 if not (tool and tool:IsA("Tool")) then return nil end
 local id=tool:GetAttribute("EggType") if type(id)~="string" then return nil end
 if tool:GetAttribute("CharacterId") then return nil end -- characters are sold through CharacterInventory
 -- every egg can be sold now; eggs without a normal price (owner/test, golden, limited, unknown) just sell for $0
 if tool:GetAttribute("OwnerSpawned") or tool:GetAttribute("GoldVariant") or tool:GetAttribute("UnknownEgg") then return 0 end
 local e=Catalog.ById[id] if not e or e.Limited then return 0 end
 local price=e.Price or 0
 if price<=0 then return 0 end -- allow clearing free eggs without awarding cash
 return math.floor(price*SELL_RATE)
end
RS:SetAttribute("EggSellReady",true)
local function owns(p,t) return t.Parent==p:FindFirstChildOfClass("Backpack") or t.Parent==p.Character end
remote.OnServerInvoke=function(p,action,tool)
 if action=="Quote" then if typeof(tool)~="Instance" or not owns(p,tool) then return nil end return priceOf(tool) end
 if os.clock()-(last[p] or 0)<.15 then return false,"Slow down" end last[p]=os.clock()
 local cash=p:FindFirstChild("leaderstats") and p.leaderstats:FindFirstChild("Cash") if not cash then return false,"Not ready" end
 local list={}
 if action=="Sell" and typeof(tool)=="Instance" then list={tool}
 elseif action=="SellAll" then for _,c in {p:FindFirstChildOfClass("Backpack"),p.Character} do if c then for _,t in c:GetChildren() do table.insert(list,t) end end end
 else return false,"Bad request" end
 local total,n=0,0
 for _,t in list do if typeof(t)=="Instance" and t.Parent and owns(p,t) then local v=priceOf(t) if v then t:Destroy() total+=v n+=1 end end end
 if n==0 then return false,"Nothing to sell" end
 cash.Value+=total
 return true,total,n
end
Players.PlayerRemoving:Connect(function(p) last[p]=nil end)
