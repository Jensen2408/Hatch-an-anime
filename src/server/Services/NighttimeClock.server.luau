local Night=require(script.Parent.NighttimeService)
while true do Night.Update(workspace:GetServerTimeNow());task.wait(.1)end