-- require(game.ServerStorage.RestoreSurfaceAppearances)() puts back the SurfaceAppearances + RenderFidelity removed by the Oct 15 memory cleanup
return function()
	local n=0
	for _,r in ipairs({workspace,game.ServerStorage}) do for _,p in ipairs(r:GetDescendants()) do
		if p:IsA("BasePart") and p:GetAttribute("SA_Color")~=nil and not p:FindFirstChildOfClass("SurfaceAppearance") then
			local s=Instance.new("SurfaceAppearance") s.ColorMap=p:GetAttribute("SA_Color") s.NormalMap=p:GetAttribute("SA_Normal") s.MetalnessMap=p:GetAttribute("SA_Metal") s.RoughnessMap=p:GetAttribute("SA_Rough")
			pcall(function() s.AlphaMode=Enum.AlphaMode[p:GetAttribute("SA_Alpha")] s.Color=p:GetAttribute("SA_Tint") end) s.Parent=p n+=1
		end
		if p:IsA("MeshPart") and p:GetAttribute("OldRenderFidelity") then pcall(function() p.RenderFidelity=Enum.RenderFidelity[p:GetAttribute("OldRenderFidelity")] end) end
	end end
	return n
end