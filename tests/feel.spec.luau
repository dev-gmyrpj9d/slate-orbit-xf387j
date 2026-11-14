-- Throw meter copy, throw/landing timing curves, and discovery rules.
local Config = require("../src/ReplicatedStorage/Shared/Config")
local ThrowReadout = require("../src/ReplicatedStorage/Shared/ThrowReadout")
local Feel = require("../src/ReplicatedStorage/Shared/Feel")
local JournalReveal = require("../src/ReplicatedStorage/Shared/JournalReveal")

local SOURCES = { "mouse", "key", "gamepad", "touch" }

local function plainCopy(H, text: string, where: string)
	H.check(not string.find(text, "!", 1, true), where .. ': no "!" in ' .. text)
	for word in string.gmatch(text, "%a+") do
		H.check(#word < 3 or word ~= string.upper(word), where .. ": no ALL CAPS in " .. text)
	end
end

return function(H)
	H.test("throw meter: every state is spelled out, never colour alone", function()
		for _, source in SOURCES do
			for _, tap in { false, true } do
				for _, case in { { target = "Puffhop" }, { distance = 23.6 }, {} } do
					local r = ThrowReadout.compute({
						charging = true,
						power = 0.62,
						cooldown = 0,
						cooldownTotal = 0,
						source = source,
						tapMode = tap,
						target = case.target,
						distance = case.distance,
					})
					local where = source .. (if tap then "/tap" else "/hold")
					H.check(r.visible and r.filled == 6 and r.headline == "62%", "power shown as segments and number " .. where)
					H.check(r.action ~= "", "next input named " .. where)
					H.check(
						string.find(r.action, if tap then "again" else "elease", 1, true) or source == "touch",
						"action wording " .. r.action
					)
					for _, text in { r.headline, r.status, r.action, r.cancel } do
						plainCopy(H, text, where)
					end
					if case.target then
						H.check(r.catch and r.status == "Catch: Puffhop", "catch outcome " .. r.status)
					elseif case.distance then
						H.check(not r.catch and r.status == "Lands 24 studs away", "distance outcome " .. r.status)
					else
						H.check(r.status == "Landing out of view", "unknown landing " .. r.status)
					end
				end
			end
		end
		local gamepad = ThrowReadout.compute({
			charging = true,
			power = 1,
			cooldown = 0,
			cooldownTotal = 0,
			source = "gamepad",
			tapMode = false,
		})
		H.check(gamepad.action == "Release R2 to throw" and gamepad.cancel == "B cancels", "gamepad names its buttons")
		H.check(gamepad.filled == ThrowReadout.Segments, "full power fills every segment")
	end)

	H.test("throw meter: cooldown refills, idle hides", function()
		local early =
			ThrowReadout.compute({ charging = false, power = 0, cooldown = 0.9, cooldownTotal = 1, source = "mouse", tapMode = false })
		local late =
			ThrowReadout.compute({ charging = false, power = 0, cooldown = 0.1, cooldownTotal = 1, source = "mouse", tapMode = false })
		H.check(early.visible and early.headline == "Ready in 0.9s", "cooldown text " .. early.headline)
		H.check(late.filled > early.filled, "segments refill as the cooldown ends")
		local idle =
			ThrowReadout.compute({ charging = false, power = 0, cooldown = 0, cooldownTotal = 1, source = "mouse", tapMode = false })
		H.check(not idle.visible, "hidden when idle")
	end)

	H.test("throw arm: wind-up grows with power, release is smooth and ends at rest", function()
		H.check(Feel.windUp(1) < Feel.windUp(0.5) and Feel.windUp(0.5) < Feel.windUp(0), "more power, further back")
		for _, power in { 0, 0.4, 1 } do
			local from = Feel.windUp(power)
			H.near(Feel.followThrough(0, from) :: number, from, 1e-9, "starts where the wind-up was")
			local previous = from
			local dt = 1 / 60
			local t = dt
			while true do
				local angle = Feel.followThrough(t, from)
				if not angle then
					break
				end
				-- A real throw whips fast (~35 rad/s), but never jumps more than ~50 degrees in a frame.
				H.check(math.abs(angle - previous) < 0.9, string.format("no snap at t=%.3f (%.3f -> %.3f)", t, previous, angle))
				H.check(angle <= previous + 1e-9, "the arm keeps turning one way")
				previous = angle
				t += dt
			end
			H.near(previous, Feel.REST, 0.05, "settles at rest")
			H.check(t <= Feel.Duration + 2 * dt, "finishes on time")
		end
		H.near(Feel.remoteThrow(0) :: number, 0, 1e-9, "a remote throw starts from the rest pose")
		H.check(Feel.remoteThrow(Feel.RemoteLead + Feel.Duration + 0.05) == nil, "and ends")
	end)

	H.test("landing ring closes in as the food falls; reduced effects keep it still", function()
		local lastD, lastT = math.huge, math.huge
		for i = 0, 20 do
			local d, tr = Feel.landingRing(i / 20, false)
			H.check(d <= lastD and tr <= lastT, "ring shrinks and firms up")
			H.check(d >= 2 and tr >= 0 and tr <= 1, "ring stays visible and sane")
			lastD, lastT = d, tr
		end
		local a = table.pack(Feel.landingRing(0, true))
		local b = table.pack(Feel.landingRing(1, true))
		H.check(a[1] == b[1] and a[2] == b[2], "reduced effects: no motion")
	end)

	H.test("discovery: new animals, entry numbers, island tallies and arrival copy", function()
		local before = { puffhop = true }
		local after = { puffhop = true, mossback = true, waddlebill = true }
		local new = JournalReveal.newlySeen(Config, before, after)
		H.check(#new == 2 and new[1] == "waddlebill" and new[2] == "mossback", "journal order: " .. table.concat(new, ","))
		H.check(#JournalReveal.newlySeen(Config, nil, after) == 0, "the first snapshot isn't a discovery")
		H.check(JournalReveal.entryNumber(Config, "puffhop") == 1, "puffhop is No. 1")

		local profile = { seenSpecies = { puffhop = true }, fedCount = { waddlebill = 2 } }
		local noted, total = JournalReveal.habitatTally(Config, profile, "meadow")
		H.check(noted == 2 and total >= 2, string.format("meadow tally %d/%d", noted, total))
		local title, detail = JournalReveal.arrival(Config, profile, "meadow")
		H.check(title == "Sunpetal Meadow" and detail == string.format("2 of %d animals noted", total), detail)
		plainCopy(H, detail, "arrival")

		for _, id in Config.HabitatOrder do
			local h = Config.Habitats[id]
			H.check(JournalReveal.habitatAt(Config, h.Center[1], h.Center[2]) == id, "centre of " .. id)
		end
		H.check(JournalReveal.habitatAt(Config, 92, 8) == nil, "the grove bridge is between islands")

		H.check(JournalReveal.writing("Puffhop", 0) == "·······", "nothing written yet")
		H.check(JournalReveal.writing("Puffhop", 0.5) == "Puff···", JournalReveal.writing("Puffhop", 0.5))
		H.check(JournalReveal.writing("Sea Otter", 1) == "Sea Otter", "fully written")
		H.check(JournalReveal.writing("Sea Otter", 0) == "··· ·····", "spaces stay spaces")
	end)
end
