--!strict
-- What the throw meter says, as pure data (no Roblox APIs, so the offline tests can load it).
--
-- The meter never relies on colour: power is a count of filled segments, a notch and a
-- percentage; the outcome is a sentence ("Catch: Puffhop", "Lands 24 studs away"); the
-- next action names the actual input ("Release R2 to throw"). Copy follows ART_DIRECTION.md:
-- sentence case, no "!", no ALL CAPS.

local ThrowReadout = {}

ThrowReadout.Segments = 10

export type Input = {
	charging: boolean,
	power: number, -- 0..1
	cooldown: number, -- seconds until the next throw
	cooldownTotal: number, -- the full cooldown, for the refill
	source: string, -- "mouse" | "key" | "gamepad" | "touch"
	tapMode: boolean,
	target: string?, -- species name when the arc passes its mouth
	distance: number?, -- studs to where the visible arc lands
}

export type Readout = {
	visible: boolean,
	filled: number, -- segments to fill (0..Segments)
	level: number, -- 0..1 notch position
	headline: string, -- "62%" or "Ready in 0.6s"
	status: string, -- the predicted outcome
	action: string, -- what to do next
	cancel: string, -- how to back out ("" when there's no separate cancel input)
	catch: boolean, -- the arc reaches an animal's mouth (drawn as a heavier outline too)
}

local RELEASE = {
	mouse = "Release to throw",
	key = "Release F to throw",
	gamepad = "Release R2 to throw",
	touch = "Lift your finger to throw",
}
local TAP = {
	mouse = "Click again to throw",
	key = "Press F again to throw",
	gamepad = "Press R2 again to throw",
	touch = "Tap again to throw",
}
local CANCEL = { mouse = "X cancels", key = "X cancels", gamepad = "B cancels", touch = "" }

function ThrowReadout.filled(power: number): number
	return math.clamp(math.floor(power * ThrowReadout.Segments + 0.5), 0, ThrowReadout.Segments)
end

function ThrowReadout.compute(input: Input): Readout
	if input.charging then
		local power = math.clamp(input.power, 0, 1)
		local status
		if input.target then
			status = "Catch: " .. input.target
		elseif input.distance then
			status = string.format("Lands %d studs away", math.floor(input.distance + 0.5))
		else
			status = "Landing out of view"
		end
		local source = if RELEASE[input.source] then input.source else "mouse"
		return {
			visible = true,
			filled = ThrowReadout.filled(power),
			level = power,
			headline = string.format("%d%%", math.floor(power * 100 + 0.5)),
			status = status,
			action = if input.tapMode then TAP[source] else RELEASE[source],
			cancel = CANCEL[source],
			catch = input.target ~= nil,
		}
	elseif input.cooldown > 0 then
		local total = math.max(input.cooldownTotal, input.cooldown, 1e-3)
		local recovered = 1 - input.cooldown / total
		return {
			visible = true,
			filled = ThrowReadout.filled(recovered),
			level = recovered,
			headline = string.format("Ready in %.1fs", input.cooldown),
			status = "",
			action = "",
			cancel = "",
			catch = false,
		}
	end
	return {
		visible = false,
		filled = 0,
		level = 0,
		headline = "",
		status = "",
		action = "",
		cancel = "",
		catch = false,
	}
end

return ThrowReadout
