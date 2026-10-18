local T=require(script.Parent.Theme) local Tween=game:GetService("TweenService") local C={}
function C.Make(class,props,parent) local o=Instance.new(class) for k,v in props do o[k]=v end o.Parent=parent return o end
function C.Round(o,r) C.Make("UICorner",{CornerRadius=UDim.new(0,r or 10)},o) end
function C.Border(o) C.Make("UIStroke",{Color=T.Border,Thickness=1},o) end
function C.Label(parent,str,size,color) return C.Make("TextLabel",{BackgroundTransparency=1,Text=str,TextColor3=color or T.Text,Font=Enum.Font.GothamMedium,TextSize=size or 14,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,Size=UDim2.new(1,0,0,32)},parent) end
function C.Button(parent,str,fn,color)
 local b=C.Make("TextButton",{Text=str,Font=Enum.Font.GothamMedium,TextSize=14,TextColor3=T.Text,BackgroundColor3=color or T.Card,AutoButtonColor=false,BorderSizePixel=0,Size=UDim2.new(1,0,0,44)},parent) C.Round(b,10) C.Border(b)
 b.MouseEnter:Connect(function() if b:GetAttribute("DisabledReason")==nil then Tween:Create(b,TweenInfo.new(.15),{BackgroundColor3=color or T.Border}):Play() end end)
 b.MouseLeave:Connect(function() Tween:Create(b,TweenInfo.new(.15),{BackgroundColor3=color or T.Card}):Play() end)
 if fn then b.Activated:Connect(function() if not b:GetAttribute("DisabledReason") then fn(b) end end) end return b
end
function C.Disable(b,reason) b:SetAttribute("DisabledReason",reason) b.Interactable=not reason b.TextTransparency=reason and .55 or 0 if reason then local l=C.Label(b.Parent,reason,12,T.Muted) l.Size=UDim2.new(1,0,0,28) end end
function C.Input(parent,hint)
 local b=C.Make("TextBox",{PlaceholderText=hint,Text="",ClearTextOnFocus=false,Font=Enum.Font.GothamMedium,TextSize=14,TextColor3=T.Text,PlaceholderColor3=T.Muted,BackgroundColor3=T.Input,BorderSizePixel=0,Size=UDim2.new(1,0,0,44)},parent) C.Round(b) C.Border(b) C.Make("UIPadding",{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)},b) return b
end
function C.Stack(parent,pad) return C.Make("UIListLayout",{Padding=UDim.new(0,pad or 12),SortOrder=Enum.SortOrder.LayoutOrder},parent) end
function C.Card(parent,title,color)
 local f=C.Make("Frame",{BackgroundColor3=color or T.Card,BorderSizePixel=0,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},parent) C.Round(f,14) C.Border(f)
 C.Make("UIPadding",{PaddingTop=UDim.new(0,16),PaddingBottom=UDim.new(0,16),PaddingLeft=UDim.new(0,16),PaddingRight=UDim.new(0,16)},f) C.Stack(f,12) if title then local l=C.Label(f,title,16) l.LayoutOrder=-100 end return f
end
function C.Grid(parent,columns,width)
 local f=C.Make("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},parent)
 C.Make("UIGridLayout",{CellSize=UDim2.new(1/columns,-(columns-1)*12/columns,0,124),CellPadding=UDim2.fromOffset(12,12),SortOrder=Enum.SortOrder.LayoutOrder},f) return f
end
function C.Format(n) n=tonumber(n) or 0 for _,u in {{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}} do if n>=u[1] then return (string.format("%.2f",n/u[1]):gsub("0+$",""):gsub("%.$",""))..u[2] end end return tostring(math.floor(n)) end
return C