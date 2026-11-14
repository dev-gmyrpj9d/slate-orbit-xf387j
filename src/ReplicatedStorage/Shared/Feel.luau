--!strict
-- Timing curves for the throw's anticipation, action and recovery, and for the landing ring.
-- Pure Luau (no Roblox APIs) so the offline tests can check them; the client's ThrowPose and
-- Effects turn the numbers into joint rotations and parts.
--
-- Arm angles are radians about the shoulder's pitch axis, positive = forward/up. An overhand
-- throw keeps turning the same way: cocked up and back (about -2), over the top (-pi), out in
-- front (-3pi/2) and down into the follow-through, then settles at -2pi, which is the same
-- rotation as rest (0). Keeping one direction means the arm never snaps back the short way.

local Feel = {}

Feel.REST = -2 * math.pi

-- Anticipation: how far the arm is cocked back while charging (power 0..1).
function Feel.windUp(power: number): number
	return -(0.5 + 1.9 * math.clamp(power, 0, 1))
end

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function easeOut(x: number): number
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) ^ 3
end

-- Keyframes after the release: { time, angle, easing }.
local RELEASE = 0.12 -- the arm whips over the top
local FOLLOW = 0.24 -- lowest point of the follow-through
Feel.Duration = 0.55 -- back at rest
local FOLLOW_ANGLE = -5.7

-- Shoulder angle `t` seconds after release, starting from the wind-up angle `from`.
-- Returns nil once the motion is over (the caller stops overriding the joint).
function Feel.followThrough(t: number, from: number): number?
	if t < 0 then
		return from
	elseif t < RELEASE then
		return from + (-4.6 - from) * smooth(t / RELEASE)
	elseif t < FOLLOW then
		return -4.6 + (FOLLOW_ANGLE + 4.6) * smooth((t - RELEASE) / (FOLLOW - RELEASE))
	elseif t < Feel.Duration then
		return FOLLOW_ANGLE + (Feel.REST - FOLLOW_ANGLE) * smooth((t - FOLLOW) / (Feel.Duration - FOLLOW))
	end
	return nil
end

-- Another player's throw: we never saw them charge, so a quick cock-back comes first.
Feel.RemoteLead = 0.08
function Feel.remoteThrow(t: number): number?
	if t < Feel.RemoteLead then
		return Feel.windUp(0.8) * smooth(t / Feel.RemoteLead)
	end
	return Feel.followThrough(t - Feel.RemoteLead, Feel.windUp(0.8))
end

-- The landing ring around where the local player's food will come down. `progress` is 0 at
-- release and 1 at touchdown. It closes in as the food falls (anticipation), so the moment of
-- landing reads without watching the food. Reduced effects: a steady ring.
function Feel.landingRing(progress: number, reduced: boolean): (number, number)
	if reduced then
		return 3, 0.35
	end
	local p = math.clamp(progress, 0, 1)
	local diameter = 2.4 + 5.6 * (1 - easeOut(p))
	local transparency = 0.75 - 0.45 * p
	return diameter, transparency
end

return Feel
