--!strict
-- Sound files the Roblox client ships under content/sounds, usable as rbxasset:// paths with no
-- uploaded or licensed assets. Source: rbxManifest.txt in MaximumADHD/Roblox-Client-Tracker
-- (client version 0.747.0.7471481, checked 2026-11-14), which lists exactly these 11 files.
-- Older paths such as swoosh.wav, electronicpingshort.wav, clickfast.wav and victory.wav are
-- NOT shipped any more (earlier passes used them, so those cues were silent); tests reject any
-- rbxasset sound path that isn't listed here.

local EngineSounds = {}

EngineSounds.ClientVersion = "0.747.0.7471481"

EngineSounds.Files = {
	"action_falling.ogg",
	"action_footsteps_plastic.mp3",
	"action_get_up.mp3",
	"action_jump.mp3",
	"action_jump_land.mp3",
	"action_swim.mp3",
	"impact_explosion_03.mp3",
	"impact_water.mp3",
	"oof.ogg",
	"ouch.ogg",
	"volume_slider.ogg",
}

local function path(file: string): string
	return "rbxasset://sounds/" .. file
end

-- The ones this game uses, by role.
EngineSounds.Path = {
	jump = path("action_jump.mp3"), -- airy push-off: the throw
	land = path("action_jump_land.mp3"), -- soft thump: eat, refuse, ground landing
	water = path("impact_water.mp3"), -- splash
	swim = path("action_swim.mp3"), -- looping water: shore ambience
	tick = path("volume_slider.ogg"), -- short UI tick: clicks and the pitched note cues
}

function EngineSounds.isShipped(id: string): boolean
	local file = string.match(id, "^rbxasset://sounds/(.+)$")
	return file ~= nil and table.find(EngineSounds.Files, file) ~= nil
end

return EngineSounds
