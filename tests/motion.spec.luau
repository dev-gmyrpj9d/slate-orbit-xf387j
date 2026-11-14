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
end
