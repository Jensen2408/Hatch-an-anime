local Payment={}
function Payment.TryCharge(player,price)
 if type(price)~="number" or price~=price or price<0 or price==math.huge or price%1~=0 then return false,"Invalid egg price" end
 if price==0 then return true end
 local stats=player:FindFirstChild("leaderstats")
 local cash=stats and stats:FindFirstChild("Cash")
 if not cash or not (cash:IsA("IntValue") or cash:IsA("NumberValue")) then return false,"Cash is not ready yet" end
 if cash.Value<price then return false,"Not enough cash" end
 cash.Value-=price
 return true
end
return Payment
