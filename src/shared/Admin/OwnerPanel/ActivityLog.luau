--[[ ReplicatedStorage.OwnerPanel.ActivityLog  (ModuleScript)
Newest-first in-memory log of panel actions (max 50 rows). Legacy v2 panel helper: nothing in src requires it
any more (StudPanel is self-contained). Row = { Time, Action, Target, Ok, Response }.
]]
local ActivityLog = { Rows = {} }
function ActivityLog.Add(action, target, result)
    table.insert(ActivityLog.Rows, 1, {
        Time = os.date("%H:%M:%S"),
        Action = action,
        Target = target,
        Ok = result.Ok == true,
        Response = result.Message or "",
    })
    while #ActivityLog.Rows > 50 do
        table.remove(ActivityLog.Rows)
    end
end
function ActivityLog.Clear()
    table.clear(ActivityLog.Rows)
end
return ActivityLog
