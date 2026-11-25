-- Config: every number you might want to tweak while playtesting lives here.
-- Change a value, save, and Rojo syncs it into Studio. Then press Play again.

local Config = {}

Config.Mossback = {
	-- Body
	BodySize = Vector3.new(6, 6, 11), -- width, height, length (studs)
	HipHeight = 5, -- leg length: how far the body floats above the ground

	-- Chasing
	WalkSpeed = 14, -- players walk at 16, so you can only just outrun it
	SightRange = 300, -- it ignores players further away than this
	StopDistance = 12, -- it stops walking when this close to its target
	RepathInterval = 0.6, -- seconds between pathfinding updates

	-- Antler Charge
	FirstChargeDelay = 3, -- grace period after it spawns
	ChargeCooldown = 5, -- seconds between charges
	ChargeRange = 70, -- it starts a charge when a player is this close (and visible)
	TelegraphTime = 1.0, -- antlers glow green for this long before the charge
	TelegraphLockTime = 0.25, -- for the last bit of the glow it stops turning (your dodge window)
	ChargeSpeed = 65,
	ChargeDistance = 80, -- how far one charge travels
	ChargeMaxTime = 2, -- safety cap in seconds
	MissRecoverTime = 1.2, -- how long it pants after a charge that hit nothing

	-- Hitting players
	ChargeKnockback = 70, -- how hard players get flung forwards
	ChargeKnockUp = 45, -- how hard players get flung upwards
	PlayerRagdollTime = 2.5,

	-- Getting stunned
	StunTime = 2, -- normal stun
	TreeStunMultiplier = 2, -- WEAKNESS: charging into a big tree stuns it twice as long
	KnockdownTime = 3, -- how long it lies on its side after a Log Swing hit
}

Config.LogSwing = {
	GateWidth = 18, -- distance between the two posts
	PivotHeight = 20, -- height of the top beam
	RopeLength = 13, -- so the log passes about 7 studs above the ground
	ArmedAngle = 75, -- degrees the log is pulled back while waiting
	SwingPeriod = 1.6, -- seconds for one full back-and-forth
	SwingDuration = 2.4, -- how long it keeps swinging once triggered
	Damping = 0.5, -- how fast the swing dies down
	ResetTime = 1.5, -- seconds to winch the log back up
	RearmCooldown = 4, -- extra wait before it can trigger again
	TriggerLeadTime = 0.4, -- it fires this early so the log meets a moving legend
	MinHitSpeed = 1.5, -- (radians/sec) slower than this the log is harmless

	PlayerKnockback = 80, -- yes, it hits players too. Physics comedy.
	PlayerKnockUp = 50,
	PlayerRagdollTime = 3,
}

-- Any part with this tag counts as a "big tree" for Mossback's weakness.
-- Later, when you build the real Whisperwood map, add this tag to your tree trunks
-- (Studio: select the trunk > Properties > Tags > add "BigTree").
Config.BigTreeTag = "BigTree"

-- Every legend model gets this tag so traps can find it.
Config.LegendTag = "Legend"

return Config
