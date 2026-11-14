--!strict
-- Shared rules for how animals are rigged, how their limbs move and how they idle.
--   * The server's AnimalFactory uses PARTS to decide which parts get an animated Motor6D (and
--     which part each one hangs from).
--   * The client's AnimalAnimator calls `jointAngles` every frame to pose those joints locally.
--   * The server's AnimalService uses `pickIdle` and `separation` for idle behaviour.
-- Pure Luau (no Roblox APIs) so the offline Lune tests can load it.

local AnimalMotion = {}

-- role: animated joint kind (nil = rigidly welded). parent: name of the part it hangs from
-- (nil or missing = the body). Parts not listed are welded to the body.
export type PartRule = { role: string?, parent: string? }

AnimalMotion.PARTS = {
	Head = { role = "head" },
	Ear = { role = "ear", parent = "Head" },
	Antenna = { role = "ear", parent = "Head" },
	Stalk = { role = "ear", parent = "Head" },
	EarInner = { parent = "Ear" },
	Eye = { parent = "Head" },
	Shine = { parent = "Eye" },
	EyeBall = { parent = "Stalk" },
	Pupil = { parent = "EyeBall" },
	EyeBump = { parent = "Head" },
	Nose = { parent = "Head" },
	Snout = { parent = "Head" },
	Muzzle = { parent = "Head" },
	Beak = { parent = "Head" },
	Horn = { parent = "Head" },
	Crest = { parent = "Head" },
	Whisker = { parent = "Head" },
	Tusk = { parent = "Head" },
	Leg = { role = "leg" },
	Paw = { role = "leg" },
	-- A foot right under a leg rides on it (birds); a foot on its own is a leg (hoppers, frogs).
	Foot = { role = "leg", parent = "Leg" },
	Tail = { role = "tail" },
	TailTip = { parent = "Tail" },
	Wing = { role = "wing" },
	HindWing = { role = "wing" },
	Claw = { role = "claw" },
	Pincer = { parent = "Claw" },
} :: { [string]: PartRule }

-- The giant only sways its fins and tail; its head and mouth stay where the feast aims.
AnimalMotion.GIANT_PARTS = {
	Fin = { role = "fin" },
	TailFin = { role = "tail" },
} :: { [string]: PartRule }

-- A foot further than this (x the species scale) from its leg is treated as a separate leg.
AnimalMotion.FootAttachDistance = 1.2

-- Archetypes that fly or hover never sit down to rest.
AnimalMotion.Hovering = { moth = true }

export type Pose = {
	state: string, -- the server state attribute: Idle/Approach/Anticipate/Eat/Happy/Refuse
	pose: string?, -- idle pose attribute: wander/sniff/rest/watch
	archetype: string,
	walk: number, -- 0..1 how fast the animal is walking relative to its walk speed
	lookYaw: number, -- radians the head should turn toward something interesting (0 = ahead)
}

local sin = math.sin

-- Rotation (rx, ry, rz) in body-aligned axes (X right, Y up, -Z forward) for one joint.
-- `side` is -1/1 for left/right parts (0 in the middle); `front` is true for front legs.
function AnimalMotion.jointAngles(role: string, side: number, front: boolean, p: Pose, t: number): (number, number, number)
	local state = p.state
	local happy = state == "Happy"
	local excited = happy or state == "Anticipate"
	local s = if side == 0 then 1 else side
	if role == "leg" then
		if p.pose == "rest" and state == "Idle" then
			return (if front then -0.5 else 0.5), 0, -s * 0.15
		end
		local walk = p.walk
		if walk <= 0.02 then
			return 0, 0, 0
		end
		if p.archetype == "hopper" or p.archetype == "frog" then
			-- Both feet push off together.
			return sin(t * 10) * 0.5 * walk, 0, 0
		elseif p.archetype == "crab" then
			-- Side-stepping legs ripple up and down.
			return 0, 0, sin(t * 16 + (if front then 0 else math.pi)) * 0.35 * walk * s
		end
		-- Diagonal gait: front-left moves with back-right.
		local phase = if (side > 0) == front then 0 else math.pi
		return sin(t * (6 + 6 * walk) + phase) * 0.55 * walk, 0, 0
	elseif role == "ear" then
		if state == "Refuse" then
			return 0.2, 0, -s * 0.45
		elseif excited then
			return 0, 0, s * sin(t * 13 + side) * 0.22
		end
		-- An occasional twitch on top of a slow sway.
		local twitch = if sin(t * 0.9 + side * 2) > 0.97 then sin(t * 40) * 0.2 else 0
		return 0, 0, s * (sin(t * 1.4 + side) * 0.05 + twitch)
	elseif role == "tail" then
		if happy then
			return 0, sin(t * 18) * 0.55, 0
		elseif state == "Anticipate" then
			return 0, sin(t * 12) * 0.35, 0
		elseif state == "Refuse" then
			return 0.3, 0, 0
		end
		return 0, sin(t * 2.2) * 0.12, 0
	elseif role == "wing" then
		if p.archetype == "moth" then
			return 0, 0, s * (sin(t * (if excited then 26 else 14)) * 0.4)
		elseif happy or p.walk > 0.6 then
			return 0, 0, s * (0.25 + sin(t * 22) * 0.45)
		elseif state == "Anticipate" then
			return 0, 0, s * (0.15 + sin(t * 9) * 0.12)
		end
		return 0, 0, s * sin(t * 1.6) * 0.03
	elseif role == "claw" then
		if happy then
			return sin(t * 16 + side) * 0.35, 0, 0
		elseif state == "Eat" then
			return sin(t * 12 + (if side > 0 then 0 else math.pi)) * 0.4 - 0.2, 0, 0
		elseif state == "Refuse" then
			return 0, s * 0.35, 0
		end
		return sin(t * 2.5 + side) * 0.08, 0, 0
	elseif role == "head" then
		if state == "Eat" then
			return -0.18 + sin(t * 16) * 0.12, 0, 0
		elseif state == "Refuse" then
			return 0.08, sin(t * 22) * 0.3, 0
		elseif happy then
			return 0.1, 0, sin(t * 7) * 0.16
		elseif state == "Anticipate" then
			return 0.12, p.lookYaw, sin(t * 4) * 0.06
		elseif p.pose == "sniff" then
			return -0.28 + sin(t * 9) * 0.04, sin(t * 1.3) * 0.2, 0
		elseif p.pose == "rest" then
			return -0.12, sin(t * 0.5) * 0.1, 0.12
		elseif p.pose == "watch" then
			return 0.05, p.lookYaw, sin(t * 0.8) * 0.08
		end
		return 0, sin(t * 0.6) * 0.2 + p.lookYaw * 0.5, 0
	elseif role == "fin" then
		return 0, 0, s * sin(t * 1.2) * 0.14
	end
	return 0, 0, 0
end

--------------------------------------------------------------------------------
-- Idle behaviour (server)
--------------------------------------------------------------------------------
export type IdleChoice = { mode: string, min: number, max: number }

-- `roll` is a uniform 0..1 number. Animals mostly wander, sometimes stop to sniff the grass,
-- watch a nearby player or lie down for a rest.
function AnimalMotion.pickIdle(roll: number, archetype: string, hasWatchTarget: boolean): IdleChoice
	if roll < 0.5 then
		return { mode = "wander", min = 2.5, max = 6 }
	elseif roll < 0.7 then
		return { mode = "sniff", min = 1.8, max = 3.2 }
	elseif roll < 0.85 then
		if hasWatchTarget then
			return { mode = "watch", min = 2.5, max = 4.5 }
		end
		return { mode = "sniff", min = 1.8, max = 3.2 }
	elseif AnimalMotion.Hovering[archetype] then
		return { mode = "wander", min = 2.5, max = 6 }
	end
	return { mode = "rest", min = 4, max = 7 }
end

-- Studs an animal is pushed (dx, dz) this step to stop overlapping its neighbours.
-- `others` holds { x, z, radius } for every other animal on the same island.
function AnimalMotion.separation(x: number, z: number, radius: number, others: { { number } }, maxStep: number): (number, number)
	local px, pz = 0, 0
	for _, o in ipairs(others) do
		local dx, dz = x - o[1], z - o[2]
		local minDist = radius + o[3]
		local d2 = dx * dx + dz * dz
		if d2 < minDist * minDist then
			local d = math.sqrt(d2)
			if d < 1e-3 then
				-- Exactly on top of each other: pick a stable direction from the radius.
				dx, dz, d = 1, 0, 1
			end
			local overlap = minDist - d
			px += dx / d * overlap * 0.5
			pz += dz / d * overlap * 0.5
		end
	end
	local len = math.sqrt(px * px + pz * pz)
	if len > maxStep then
		px, pz = px / len * maxStep, pz / len * maxStep
	end
	return px, pz
end

return AnimalMotion
