local Style={}
function Style.Panel(parent,color)
 local frame=Instance.new("Frame");frame.Name="Panel";frame.Size=UDim2.fromScale(1,1);frame.BackgroundColor3=color;frame.BorderSizePixel=0;frame.ClipsDescendants=true;frame.Parent=parent
 local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(.09,0);corner.Parent=frame
 local border=Instance.new("UIStroke");border.Thickness=3;border.Color=Color3.fromRGB(20,20,25);border.Parent=frame
 local gradient=Instance.new("UIGradient");gradient.Rotation=90;gradient.Color=ColorSequence.new(color:Lerp(Color3.new(1,1,1),.2),color:Lerp(Color3.new(0,0,0),.18));gradient.Parent=frame
 -- Repeated egg silhouettes, deliberately low contrast behind the lettering.
 for row=0,3 do for col=0,9 do
 local dot=Instance.new("Frame");dot.Name="EggPattern";dot.AnchorPoint=Vector2.new(.5,.5);dot.Position=UDim2.fromScale(col*.12+(row%2)*.06,row*.32+.04);dot.Size=UDim2.fromScale(.065,.23);dot.BackgroundColor3=Color3.new(1,1,1);dot.BackgroundTransparency=.88;dot.BorderSizePixel=0;dot.Parent=frame
 local round=Instance.new("UICorner");round.CornerRadius=UDim.new(.5,0);round.Parent=dot
 end end
 return frame
end
function Style.Text(parent,text,pos,size,color)
 local t=Instance.new("TextLabel");t.BackgroundTransparency=1;t.Position=pos;t.Size=size;t.Font=Enum.Font.Cartoon;t.TextScaled=true;t.Text=text;t.TextColor3=color or Color3.new(1,1,1);t.ZIndex=3;t.Parent=parent
 local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromRGB(18,18,22);stroke.Thickness=2;stroke.Parent=t
 return t
end
return Style