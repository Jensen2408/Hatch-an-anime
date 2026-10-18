-- ReplicatedStorage.WaterfallRiver.RiverPath
-- Shared, deterministic river + egg maths. Server (validation) and client (visuals) compute identical positions from server time.
local Config = require(script.Parent.RiverConfig)
local Path = {}
local O = Config.Origin
local N = 160

local function smooth(e0, e1, x)
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end
Path.Smooth = smooth

local function centerZ(t)
	return O.Z + Config.Meander * (math.sin(t * math.pi * 2.2) * 0.7 + math.sin(t * math.pi * 4.7 + 1.3) * 0.3) * smooth(0, 0.12, t)
end

Path.SurfaceY = O.Y - Config.RiverDepth
local points, cum = table.create(N + 1), table.create(N + 1)
for i = 0, N do
	local t = i / N
	points[i + 1] = Vector3.new(O.X + 1 + t * Config.Length, Path.SurfaceY, centerZ(t))
end
cum[1] = 0
for i = 2, N + 1 do cum[i] = cum[i - 1] + (points[i] - points[i - 1]).Magnitude end
Path.Total = cum[N + 1]
Path.LandDistance = 5

-- position on the centre line (at surface height), unit tangent (downstream), unit right
function Path.At(d)
	d = math.clamp(d, 0, Path.Total)
	local lo, hi = 1, N + 1
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if cum[mid] <= d then lo = mid else hi = mid end
	end
	local a, b = points[lo], points[hi]
	local seg = cum[hi] - cum[lo]
	local f = seg > 0 and (d - cum[lo]) / seg or 0
	local tan = (b - a).Unit
	return a:Lerp(b, f), tan, tan:Cross(Vector3.yAxis).Unit
end

function Path.WidthAt(d)
	return Config.RiverWidth + Config.PoolExtraWidth * (1 - smooth(Config.PoolLength * 0.4, Config.PoolLength, d))
end

-- Transparency sequence with `count` soft-edged dashes travelling along a beam. x grows with time.
function Path.Dash(x, len, alpha, count)
	count = count or 1
	local period = 1 + len
	local ps = table.create(count)
	for k = 0, count - 1 do ps[k + 1] = (x + k * period / count) % period end
	table.sort(ps)
	local kps = { NumberSequenceKeypoint.new(0, 1) }
	local last = 0
	local function add(t, v)
		if t > last + 0.002 and t < 0.998 then
			table.insert(kps, NumberSequenceKeypoint.new(t, v))
			last = t
		end
	end
	for _, p in ps do
		add(p - len, 1)
		add(p - len * 0.35, alpha)
		add(p, 1)
	end
	table.insert(kps, NumberSequenceKeypoint.new(1, 1))
	return NumberSequence.new(kps)
end

return Path
