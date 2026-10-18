local Service = {}
function Service.Update(now)
    local boundary = math.floor(now / 300) * 300
    local active = now - boundary < 20
    local endsAt = boundary + 20
    -- Staff panel trigger: NightForcedUntil (server time) forces night on until then
    local forced = workspace:GetAttribute("NightForcedUntil")
    if forced and now < forced then
        active = true
        endsAt = math.max(forced, active and endsAt or 0)
    end
    workspace:SetAttribute("NighttimeActive", active)
    workspace:SetAttribute("NighttimeEndsAt", endsAt)
    workspace:SetAttribute("NighttimeNextAt", boundary + 300)
    workspace:SetAttribute("NightCashMultiplier", active and 3 or 1)
    workspace:SetAttribute("NightHatchSpeedMultiplier", active and 2 or 1)
    workspace:SetAttribute("NightRiverLuckMultiplier", active and 3 or 1)
    return active
end
return Service
