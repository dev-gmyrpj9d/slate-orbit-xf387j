-- AnimalMotion: pose curves, idle choices and separation.
local AnimalMotion = require("../src/ReplicatedStorage/Shared/AnimalMotion")

local ROLES = { "head", "leg", "ear", "tail", "wing", "claw", "fin" }
local STATES = { "Idle", "Approach", "Anticipate", "Eat", "Happy", "Refuse" }
local POSES = { "wander", "sniff", "watch", "rest" }
local ARCHETYPES = { "hopper", "bird", "tortoise", "fox", "otter", "crab", "frog", "snail", "moth", "boar", "giant" }

return function(H)
	H.test("joint angles are finite and bounded for every role/state/pose", function()
		for _, role in ROLES do
			for _, state in STATES do
				for _, pose in POSES do
					for _, archetype in ARCHETYPES do
						for _, walk in { 0, 0.5, 1 } do
							for t = 0, 6, 0.37 do
								for _, side in { -1, 0, 1 } do
									local p = { state = state, pose = pose, archetype = archetype, walk = walk, lookYaw = 0.6 }
									local rx, ry, rz = AnimalMotion.jointAngles(role, side, side > 0, p, t)
									for _, v in { rx, ry, rz } do
										H.check(
											v == v and math.abs(v) <= 1.2,
											string.format("%s/%s/%s/%s -> %s", role, state, pose, archetype, tostring(v))
										)
									end
								end
							end
						end
					end
				end
			end
		end
	end)

	H.test("left and right ears/wings mirror each other", function()
		local p = { state = "Happy", pose = "wander", archetype = "bird", walk = 0, lookYaw = 0 }
		for t = 0, 2, 0.21 do
			local _, _, left = AnimalMotion.jointAngles("wing", -1, false, p, t)
			local _, _, right = AnimalMotion.jointAngles("wing", 1, false, p, t)
			H.near(left, -right, 1e-9, "wings should mirror")
		end
	end)

	H.test("legs stand still when not walking (outside rest)", function()
		local p = { state = "Idle", pose = "wander", archetype = "fox", walk = 0, lookYaw = 0 }
		local rx, ry, rz = AnimalMotion.jointAngles("leg", 1, true, p, 1.3)
		H.check(rx == 0 and ry == 0 and rz == 0, "idle legs should be neutral")
	end)

	H.test("diagonal gait: front-left moves with back-right", function()
		local p = { state = "Approach", pose = "wander", archetype = "fox", walk = 1, lookYaw = 0 }
		local fl = AnimalMotion.jointAngles("leg", -1, true, p, 0.4)
		local br = AnimalMotion.jointAngles("leg", 1, false, p, 0.4)
		local fr = AnimalMotion.jointAngles("leg", 1, true, p, 0.4)
		H.near(fl, br, 1e-9, "diagonal pair in phase")
		H.near(fl, -fr, 1e-9, "front pair opposite")
	end)

	H.test("head follows lookYaw while watching or anticipating", function()
		for _, case in { { state = "Idle", pose = "watch" }, { state = "Anticipate", pose = "wander" } } do
			local _, ry = AnimalMotion.jointAngles("head", 0, true, {
				state = case.state,
				pose = case.pose,
				archetype = "fox",
				walk = 0,
				lookYaw = 0.5,
			}, 0)
			H.near(ry, 0.5, 1e-9, case.state .. " head yaw")
		end
	end)

	H.test("pickIdle covers every mode and never rests hovering animals", function()
		local seen = {}
		for i = 0, 99 do
			local roll = i / 100
			local choice = AnimalMotion.pickIdle(roll, "fox", true)
			seen[choice.mode] = true
			H.check(choice.min > 0 and choice.max >= choice.min, "durations")
			H.check(AnimalMotion.pickIdle(roll, "moth", true).mode ~= "rest", "moth rested")
			H.check(AnimalMotion.pickIdle(roll, "fox", false).mode ~= "watch", "watch without a target")
		end
		for _, mode in { "wander", "sniff", "watch", "rest" } do
			H.check(seen[mode], "never picked " .. mode)
		end
		H.check(not seen.greet, "greeted without a friend nearby")
		local greets = 0
		for i = 0, 99 do
			if AnimalMotion.pickIdle(i / 100, "fox", true, true).mode == "greet" then
				greets += 1
			end
		end
		H.check(greets >= 20 and greets <= 40, "a friend nearby is greeted about 30% of the time")
	end)

	H.test("separation pushes overlapping animals apart, capped, and ignores distant ones", function()
		local dx, dz = AnimalMotion.separation(0, 0, 2, { { 1, 0, 2 } }, 10)
		H.near(dx, -1.5, 1e-9, "push away along -X by half the overlap")
		H.near(dz, 0, 1e-9, "no Z push")
		dx, dz = AnimalMotion.separation(0, 0, 2, { { 0.1, 0, 2 } }, 0.6)
		H.near(math.sqrt(dx * dx + dz * dz), 0.6, 1e-9, "capped at maxStep")
		dx, dz = AnimalMotion.separation(0, 0, 2, { { 10, 0, 2 } }, 0.6)
		H.check(dx == 0 and dz == 0, "far animals don't push")
		dx, dz = AnimalMotion.separation(0, 0, 2, { { 0, 0, 2 } }, 0.6)
		H.check(dx == dx and dz == dz and (dx ~= 0 or dz ~= 0), "coincident animals still separate")
	end)

	-- The pre-split server bob, kept here as the reference the split must reproduce.
	local function oldBob(state, pose, archetype, moving, t, progress)
		local sin = math.sin
		local y, extraYaw, roll, pitch = 0, 0, 0, 0
		if moving then
			if archetype == "hopper" then
				y += math.abs(sin(t * 10)) * 0.9
			elseif archetype == "bird" then
				roll = sin(t * 9) * 0.14
			elseif archetype == "crab" then
				roll = sin(t * 14) * 0.06
				y += math.abs(sin(t * 14)) * 0.15
			else
				y += math.abs(sin(t * 8)) * 0.25
			end
		elseif state == "Anticipate" then
			y += math.abs(sin(t * 6)) * 0.5
			pitch = 0.1
		elseif state == "Eat" then
			pitch = -0.12 + sin(t * 16) * 0.08
		elseif state == "Happy" then
			extraYaw = progress * math.pi * 2
			y += math.abs(sin(t * 9)) * 1.2
		elseif state == "Refuse" then
			extraYaw = sin(t * 20) * 0.35
		elseif pose == "rest" then
			y += sin(t * 1.2) * 0.04
		elseif pose == "sniff" then
			pitch = -0.06
			y += sin(t * 2) * 0.05
		else
			y += sin(t * 2) * 0.08
		end
		return y, extraYaw, pitch, roll
	end

	H.test("server bodyMotion + client idleBob reproduce the old body bob", function()
		for _, state in STATES do
			for _, pose in POSES do
				for _, archetype in ARCHETYPES do
					for _, moving in { false, true } do
						for t = 0, 5, 0.29 do
							local ey, eyaw, epitch, eroll = oldBob(state, pose, archetype, moving, t, 0.4)
							local dy, yaw, pitch, roll = AnimalMotion.bodyMotion(state, archetype, moving, t, 0.4)
							if not moving then
								local by, bp = AnimalMotion.idleBob(state, pose, t)
								dy += by
								pitch += bp
							end
							local where = string.format("%s/%s/%s/%s t=%.2f", state, pose, archetype, tostring(moving), t)
							H.near(dy, ey, 1e-9, "height " .. where)
							H.near(yaw, eyaw, 1e-9, "yaw " .. where)
							H.near(pitch, epitch, 1e-9, "pitch " .. where)
							H.near(roll, eroll, 1e-9, "roll " .. where)
						end
					end
				end
			end
		end
	end)

	-- Mirrors AnimalService.move's write decision for one animal.
	local function simulate(state, pose, moving, frames)
		local dt = 1 / 60
		local writes, t, sink, x, last = 0, 0, 0, 0, nil
		local resting = if state == "Idle" and pose == "rest" then 1 else 0
		for _ = 1, frames do
			t += dt
			if moving then
				x += 8 * dt
			end
			local dy, yaw, pitch, roll = AnimalMotion.bodyMotion(state, "fox", moving, t, 0)
			sink += (resting - sink) * math.min(1, dt * 4)
			if math.abs(resting - sink) < 1e-3 then
				sink = resting
			end
			local pose6 = { x, 6 + 1 + dy - 0.22 * sink, 0, 1.3 + yaw, pitch, roll }
			if AnimalMotion.needsWrite(last, pose6) then
				last = pose6
				writes += 1
			end
		end
		return writes
	end

	H.test("stationary idle animals stop replicating; moving ones keep updating", function()
		for _, pose in POSES do
			-- 10 s idle: a few writes while a resting animal settles, then none.
			local writes = simulate("Idle", pose, false, 600)
			H.check(writes <= 40, string.format("%s idle wrote %d times in 600 frames", pose, writes))
		end
		H.check(simulate("Eat", "wander", false, 600) <= 2, "eating (chew is client-side) should not stream")
		H.check(simulate("Idle", "wander", true, 600) >= 590, "walking animals must keep replicating")
		H.check(simulate("Happy", "wander", false, 120) >= 100, "the happy hop is gameplay feedback; it stays replicated")
	end)

	H.test("needsWrite respects the epsilon", function()
		local a = { 1, 2, 3, 0.5, 0, 0 }
		H.check(AnimalMotion.needsWrite(nil, a), "first write")
		H.check(not AnimalMotion.needsWrite(a, { 1.001, 2, 3, 0.5, 0, 0 }), "sub-epsilon move")
		H.check(AnimalMotion.needsWrite(a, { 1, 2, 3, 0.51, 0, 0 }), "yaw change")
	end)

	H.test("family personality: bird pecks, tortoise looks slowly, crab waves, moth hovers", function()
		local function head(archetype, pose, t)
			return AnimalMotion.jointAngles(
				"head",
				0,
				false,
				{ state = "Idle", pose = pose, archetype = archetype, walk = 0, lookYaw = 0 },
				t
			)
		end
		local deepest = 0
		for t = 0, 3, 0.01 do
			deepest = math.min(deepest, (head("bird", "sniff", t)))
		end
		H.check(deepest < -0.8, "birds peck: head pitch reaches " .. deepest)
		-- Tortoise head yaw changes slower than the default look-around.
		local function maxRate(archetype)
			local rate, last = 0, nil
			for t = 0, 20, 0.05 do
				local _, yaw = head(archetype, "wander", t)
				if last then
					rate = math.max(rate, math.abs(yaw - last) / 0.05)
				end
				last = yaw
			end
			return rate
		end
		H.check(maxRate("tortoise") < maxRate("fox"), "tortoise looks around more slowly")
		local idle =
			AnimalMotion.jointAngles("claw", 1, true, { state = "Idle", pose = "wander", archetype = "crab", walk = 0, lookYaw = 0 }, 1)
		local watching =
			AnimalMotion.jointAngles("claw", 1, true, { state = "Idle", pose = "watch", archetype = "crab", walk = 0, lookYaw = 0 }, 1)
		H.check(watching < idle - 0.2, "a watching crab lifts its claws")
		local lo, hi = math.huge, -math.huge
		for t = 0, 5, 0.05 do
			local dy = AnimalMotion.idleBob("Idle", "wander", t, "moth")
			lo, hi = math.min(lo, dy), math.max(hi, dy)
		end
		H.check(hi - lo > 0.25 and hi < 0.3 and lo > -0.3, "moths hover-bob gently")
		H.check(AnimalMotion.idleBob("Happy", "wander", 1, "moth") == 0, "no hover on top of server-driven states")
	end)
end
