--!strict
-- Soft surf near the water. One looping engine sound (action_swim.mp3, slowed and quiet) whose
-- volume follows how close the camera is to an island's shoreline, so the meadow centre stays
-- quiet and the beaches and bridges hear the sea. Off when Sound is off. One Sound, updated
-- four times a second: negligible cost on low-end devices.

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local EngineSounds = require(ReplicatedStorage.Shared.EngineSounds)

local ShoreAmbience = {}

local MAX_VOLUME = 0.12
local HEAR = 30 -- studs from the shoreline where the surf fades out

-- 0..1 loudness for a point: 1 on the shoreline, fading to 0 HEAR studs inland or out to sea.
function ShoreAmbience.level(x: number, z: number): number
	local best = math.huge
	for _, id in ipairs(Config.HabitatOrder) do
		local h = Config.Habitats[id]
		local d = math.sqrt((x - h.Center[1]) ^ 2 + (z - h.Center[2]) ^ 2)
		best = math.min(best, math.abs(d - (h.Radius + 6)))
	end
	return math.clamp(1 - best / HEAR, 0, 1)
end

function ShoreAmbience.start(store: any)
	local sound = Instance.new("Sound")
	sound.Name = "WFI_Shore"
	sound.SoundId = EngineSounds.Path.swim
	sound.Looped = true
	sound.PlaybackSpeed = 0.55
	sound.Volume = 0
	sound.Parent = SoundService
	local volume = 0
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		accumulator = 0
		local camera = workspace.CurrentCamera
		local target = 0
		if camera and store.setting("sound") ~= false then
			local p = camera.CFrame.Position
			target = ShoreAmbience.level(p.X, p.Z) * MAX_VOLUME
		end
		volume += (target - volume) * 0.35
		sound.Volume = volume
		if volume > 0.004 and not sound.IsPlaying then
			sound:Play()
		elseif volume <= 0.004 and sound.IsPlaying then
			sound:Pause()
		end
	end)
end

return ShoreAmbience
