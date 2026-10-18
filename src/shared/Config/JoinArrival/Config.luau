--[[ JoinArrival.Config
	Settings for the join cinematic (sky -> your temple -> behind your character).
	All times are seconds; heights/distances are studs unless noted.
	Set ReplicatedStorage.JoinArrival:SetAttribute("Enabled", false) to switch the whole feature off
	(the loading screen then restores the HUD itself, exactly like before).
]]
return {
	-- timing (the journey is one continuous eased move; these mark where each beat lands)
	SkyTime = 0.9, -- aerial view, barely moving
	ApproachTime = 1.4, -- descent toward the plot
	RevealTime = 1.0, -- settle behind the character
	HandoffTime = 0.5, -- blend into the normal Roblox camera + HUD fade

	-- sky framing, relative to the map's bounds (radius = half of the map's largest side)
	SkyHeightScale = 0.42, -- start height above the map = radius * this
	SkyBackScale = 0.95, -- how far the shot starts from the plot, out over the map = radius * this
	SkyLookBias = 0.3, -- 0 = sky shot aims at the plot, 1 = at the map centre
	SkySideAngle = 28, -- degrees the start is swung to the side (adds a gentle turn on the way down)
	StartFov = 58,

	-- landing shot (should match the normal camera so the handoff is invisible)
	EndDistance = 12.5, -- Roblox's default zoom distance
	EndPitch = 16, -- degrees above the character, looking down
	ShoulderOffset = 0, -- studs to the right (0 = centred like the default camera)

	-- waiting / streaming
	PlotWaitTimeout = 20, -- give up on the cinematic (fall back to normal gameplay) after this
	StreamTimeout = 4,
	LoadingScreenWait = 25, -- longest we wait for the loading screen before starting anyway

	-- optional sounds: leave "" to play nothing
	Sounds = {
		Ambience = { Id = "", Volume = 0.35 }, -- soft aerial wind, fades out on landing
		Whoosh = { Id = "", Volume = 0.5 }, -- plays as the descent speeds up
		Arrival = { Id = "", Volume = 0.45 }, -- subtle landing cue at the handoff
	},

	-- Studio only: press this key during a play test to replay the arrival
	StudioReplayKey = Enum.KeyCode.F6,
	-- testing aid: behave as if the player turned on Reduced Motion (Roblox doesn't let scripts set it)
	ForceReducedMotion = false,
}
