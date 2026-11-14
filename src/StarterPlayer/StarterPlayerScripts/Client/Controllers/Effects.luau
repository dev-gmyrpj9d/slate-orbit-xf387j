--!strict
-- Client-only visuals and audio: renders thrown food along the server-broadcast arc (with a
-- short trail), a closing landing ring for your own throws, bursts, catch rings, hearts,
-- floating reward text and sounds. Bounded by
-- Config.Caps.ClientEffects and the reduced-effects setting. Purely cosmetic: nothing here
-- affects rewards.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Trajectory = require(ReplicatedStorage.Shared.Trajectory)
local Feel = require(ReplicatedStorage.Shared.Feel)
local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

local Effects = {}

-- Built-in engine content sounds (no uploaded assets). If a path is unavailable the sound is
-- silently skipped. Each cue gets a little random pitch (`jitter`) so repeats don't sound
-- mechanical, and cues that share a file are pitched apart so they stay recognisable.
type SoundDef = { id: string, speed: number, volume: number, jitter: number? }
local SOUNDS: { [string]: SoundDef } = {
	throw = { id = "rbxasset://sounds/swoosh.wav", speed = 1.25, volume = 0.3, jitter = 0.08 },
	eat = { id = "rbxasset://sounds/action_jump_land.mp3", speed = 1.5, volume = 0.5, jitter = 0.1 },
	refuse = { id = "rbxasset://sounds/action_jump_land.mp3", speed = 0.7, volume = 0.35, jitter = 0.05 },
	splash = { id = "rbxasset://sounds/impact_water.mp3", speed = 1.2, volume = 0.35, jitter = 0.1 },
	thud = { id = "rbxasset://sounds/action_jump_land.mp3", speed = 1.05, volume = 0.25, jitter = 0.1 },
	reward = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 1.2, volume = 0.3, jitter = 0.04 },
	perfect = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 1.6, volume = 0.4 },
	click = { id = "rbxasset://sounds/clickfast.wav", speed = 1.1, volume = 0.3, jitter = 0.05 },
	chime = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 0.75, volume = 0.45 },
	fanfare = { id = "rbxasset://sounds/victory.wav", speed = 1, volume = 0.3 },
}
local random = Random.new()

local folder: Folder
local sounds: { [string]: Sound } = {}
type Projectile = {
	part: BasePart,
	origin: Vector3,
	velocity: Vector3,
	started: number,
	ring: BasePart?, -- landing ring (this player's own throws only)
	landsAt: number?, -- seconds after release the arc meets the ground
}
local active: { [number]: Projectile } = {}
local landParams = RaycastParams.new()
landParams.FilterType = Enum.RaycastFilterType.Include
local activeCount = 0
local transientCount = 0

function Effects.play(name: string)
	if Store.setting("sound") == false then
		return
	end
	local sound = sounds[name]
	local def = SOUNDS[name]
	if sound and def then
		local jitter = def.jitter or 0
		sound.PlaybackSpeed = def.speed * (1 + random:NextNumber(-jitter, jitter))
		SoundService:PlayLocalSound(sound)
	end
end

-- Shared impact sounds (everyone's throws) only play when they happen near this player's camera.
local HEAR_DISTANCE = 80
local function playNear(name: string, position: Vector3)
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - position).Magnitude <= HEAR_DISTANCE then
		Effects.play(name)
	end
end

local function reduced(): boolean
	return Store.setting("reducedEffects") == true
end

local function transient(lifetime: number): boolean
	if transientCount >= Config.Caps.ClientEffects then
		return false
	end
	transientCount += 1
	task.delay(lifetime, function()
		transientCount -= 1
	end)
	return true
end

function Effects.floatText(position: Vector3, text: string, color: Color3)
	if not transient(1.6) then
		return
	end
	local anchor = Ui.new("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.one * 0.2,
		CFrame = CFrame.new(position),
		Parent = folder,
	})
	local gui = Ui.new("BillboardGui", {
		Size = UDim2.fromOffset(260, 90),
		StudsOffset = Vector3.new(0, 2, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Parent = anchor,
	})
	local label = Ui.new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = text,
		TextScaled = true,
		FontFace = Ui.TitleFont,
		TextColor3 = color,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Color3.fromRGB(40, 30, 60),
		Parent = gui,
	})
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local alpha = (os.clock() - start) / 1.5
		if alpha >= 1 or not anchor.Parent then
			connection:Disconnect()
			anchor:Destroy()
			return
		end
		gui.StudsOffset = Vector3.new(0, 2 + alpha * (if reduced() then 1 else 3), 0)
		label.TextTransparency = math.max(0, alpha * 1.4 - 0.4)
		label.TextStrokeTransparency = label.TextTransparency
	end)
end

function Effects.burst(position: Vector3, color: Color3, count: number)
	if reduced() or not transient(1.2) then
		return
	end
	local anchor = Ui.new("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.one * 0.2,
		CFrame = CFrame.new(position),
		Parent = folder,
	})
	local emitter = Ui.new("ParticleEmitter", {
		Color = ColorSequence.new(color),
		LightEmission = 0.4,
		Size = NumberSequence.new(0.6, 0),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 0,
		Parent = anchor,
	})
	emitter:Emit(math.min(count, 24))
	Debris:AddItem(anchor, 1.2)
end

-- Billboard glyphs that drift up and fade (hearts for a happy animal, a puff for a refusal).
local function glyphs(position: Vector3, text: string, color: Color3, count: number, rise: number)
	if reduced() or not transient(1.4) then
		return
	end
	local anchor = Ui.new("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.one * 0.2,
		CFrame = CFrame.new(position),
		Parent = folder,
	})
	local items = {}
	for i = 1, count do
		local gui = Ui.new("BillboardGui", {
			Size = UDim2.fromOffset(34, 34),
			StudsOffset = Vector3.new(random:NextNumber(-1.2, 1.2), 0, 0),
			LightInfluence = 0,
			MaxDistance = 120,
			Parent = anchor,
		})
		local label = Ui.new("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = text,
			TextScaled = true,
			FontFace = Ui.TitleFont,
			TextColor3 = color,
			TextStrokeTransparency = 0.4,
			TextStrokeColor3 = Color3.fromRGB(70, 40, 60),
			Parent = gui,
		})
		items[i] = { gui = gui, label = label, delay = (i - 1) * 0.12, sway = random:NextNumber(0, math.pi * 2) }
	end
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - start
		if elapsed >= 1.3 or not anchor.Parent then
			connection:Disconnect()
			anchor:Destroy()
			return
		end
		for _, item in ipairs(items) do
			local alpha = math.clamp((elapsed - item.delay) / 1, 0, 1)
			local offset = item.gui.StudsOffset
			item.gui.StudsOffset = Vector3.new(offset.X, alpha * rise, math.sin(item.sway + elapsed * 5) * 0.3)
			item.label.TextTransparency = if alpha <= 0 then 1 else math.max(0, alpha * 1.6 - 0.6)
			item.label.TextStrokeTransparency = math.max(0.4, item.label.TextTransparency)
		end
	end)
end

function Effects.hearts(position: Vector3)
	glyphs(position, "♥", Color3.fromRGB(255, 120, 160), 3, 3)
end

function Effects.puff(position: Vector3)
	glyphs(position, "~", Color3.fromRGB(200, 200, 210), 2, 1.6)
end

-- A flat ring that widens and fades around the mouth on a perfect catch.
function Effects.ring(position: Vector3, color: Color3)
	if reduced() or not transient(0.6) then
		return
	end
	local ring = Ui.new("Part", {
		Shape = Enum.PartType.Cylinder,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.2,
		Size = Vector3.new(0.15, 1, 1),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Parent = folder,
	})
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local alpha = (os.clock() - start) / 0.5
		if alpha >= 1 or not ring.Parent then
			connection:Disconnect()
			ring:Destroy()
			return
		end
		local eased = 1 - (1 - alpha) ^ 3
		local diameter = 1 + eased * 7
		ring.Size = Vector3.new(0.15, diameter, diameter)
		ring.Transparency = 0.2 + alpha * 0.8
	end)
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- The thrower's Painter's Kit trail, if the server published one for them.
local function trailOf(ownerUserId: any): any
	local owner = if type(ownerUserId) == "number" then Players:GetPlayerByUserId(ownerUserId) else nil
	local id = owner and owner:GetAttribute("Trail")
	return if type(id) == "string" then Config.Trails[id] else nil
end

local function foodPart(foodId: string, ownerUserId: any): BasePart
	local food = Config.Foods[foodId] or Config.Foods.sunberry
	local color = Color3.fromRGB(food.Color[1], food.Color[2], food.Color[3])
	local part = Ui.new("Part", {
		Name = food.Name,
		Shape = if food.Shape == "Ball"
			then Enum.PartType.Ball
			elseif food.Shape == "Cylinder" then Enum.PartType.Cylinder
			else Enum.PartType.Block,
		Size = Vector3.one * food.Size,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = folder,
	})
	if not reduced() then
		-- A short tapered streak in the food's colour makes the arc easy to follow.
		-- A Painter's Kit trail replaces it with a longer one in the trail's own colours.
		local style = trailOf(ownerUserId)
		local half = food.Size * 0.3 * (if style then style.Width * 1.6 else 1)
		local a0 = Ui.new("Attachment", { Position = Vector3.new(0, half, 0), Parent = part })
		local a1 = Ui.new("Attachment", { Position = Vector3.new(0, -half, 0), Parent = part })
		Ui.new("Trail", {
			Attachment0 = a0,
			Attachment1 = a1,
			Color = if style
				then ColorSequence.new(rgb(style.Colors[1]), rgb(style.Colors[2]))
				else ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35)),
			Transparency = NumberSequence.new(if style then 0.1 else 0.35, 1),
			WidthScale = NumberSequence.new(1, 0),
			Lifetime = if style then style.Lifetime else 0.22,
			LightEmission = if style then 0 else 0.25,
			FaceCamera = true,
			Parent = part,
		})
	end
	return part
end

local function removeProjectile(id: number)
	local entry = active[id]
	if entry then
		entry.part:Destroy()
		if entry.ring then
			entry.ring:Destroy()
		end
		active[id] = nil
		activeCount -= 1
	end
end

-- Where (and when) the arc first meets the world, sampled like the server's projectile step.
local function predictLanding(origin: Vector3, velocity: Vector3): (Vector3?, number?)
	local steps = 48
	local duration = Config.Throw.MaxLifetime
	local previous = origin
	for i = 1, steps do
		local t = duration * i / steps
		local p = Trajectory.positionAt(origin, velocity, Config.Throw.Gravity, t)
		local hit = workspace:Raycast(previous, p - previous, landParams)
		if hit then
			local fraction = (hit.Position - previous).Magnitude / math.max((p - previous).Magnitude, 1e-3)
			return hit.Position, duration * (i - 1 + fraction) / steps
		end
		previous = p
	end
	return nil, nil
end

-- A flat ring on the ground where your food will land. It closes in as the food falls, so you
-- can watch the animal instead of the food and still feel the landing coming (Feel.landingRing).
local function landingRing(entry: Projectile)
	local world = workspace:FindFirstChild(Config.World.FolderName)
	if not world then
		return
	end
	landParams.FilterDescendantsInstances = { world }
	local position, landsAt = predictLanding(entry.origin, entry.velocity)
	if not position or not landsAt or landsAt < 0.25 then
		return
	end
	local diameter, transparency = Feel.landingRing(0, reduced())
	entry.landsAt = landsAt
	entry.ring = Ui.new("Part", {
		Name = "LandingRing",
		Shape = Enum.PartType.Cylinder,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.SmoothPlastic,
		Color = Ui.Colors.Panel,
		Transparency = transparency,
		Size = Vector3.new(0.12, diameter, diameter),
		CFrame = CFrame.new(position + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Parent = folder,
	})
end

local QUALITY_COLORS = {
	Perfect = Color3.fromRGB(255, 230, 90),
	Good = Color3.fromRGB(160, 255, 160),
	Ground = Color3.fromRGB(255, 255, 255),
}

local function onFx(payload: any)
	if type(payload) ~= "table" then
		return
	end
	local kind = payload.t
	if kind == "throw" then
		if activeCount >= Config.Caps.ClientEffects then
			return
		end
		activeCount += 1
		local entry: Projectile =
			{ part = foodPart(payload.food, payload.owner), origin = payload.origin, velocity = payload.velocity, started = os.clock() }
		active[payload.id] = entry
		if payload.owner == Players.LocalPlayer.UserId then
			Effects.play("throw")
			landingRing(entry)
		else
			Store.emit("throwFx", payload.owner)
		end
	elseif kind == "end" then
		removeProjectile(payload.id)
		if payload.kind == "splash" then
			Effects.burst(payload.pos, Color3.fromRGB(150, 220, 255), 10)
			playNear("splash", payload.pos)
		elseif payload.kind == "feast" then
			Effects.burst(payload.pos, Color3.fromRGB(255, 220, 120), 20)
			playNear("eat", payload.pos)
		elseif payload.kind == "ground" then
			Effects.burst(payload.pos, Color3.fromRGB(220, 200, 150), 6)
			playNear("thud", payload.pos)
		end
	elseif kind == "fed" then
		if payload.accepted then
			local perfect = payload.quality == "Perfect"
			Effects.burst(payload.pos, Color3.fromRGB(255, 130, 170), if perfect then 18 else 10)
			if perfect then
				Effects.ring(payload.pos, QUALITY_COLORS.Perfect)
			end
			playNear("eat", payload.pos)
		else
			playNear("refuse", payload.pos)
		end
	elseif kind == "reward" then
		local quality = Config.Quality[payload.quality]
		local lines = {}
		if payload.accepted then
			table.insert(lines, (quality and (quality.Icon .. " " .. quality.Label)) or "")
			table.insert(lines, string.format("+%d coins", payload.coins))
		else
			table.insert(lines, "✕ Not interested")
		end
		if payload.research > 0 then
			table.insert(lines, string.format("+%d research", payload.research))
		end
		Effects.floatText(payload.pos, table.concat(lines, "\n"), QUALITY_COLORS[payload.quality] or Ui.Colors.White)
		if payload.leveledUp or (payload.discovered and payload.preference == "favorite") then
			Effects.play("fanfare")
		elseif payload.accepted then
			Effects.play(if payload.quality == "Perfect" then "perfect" else "reward")
		end
		Store.emit("reward", payload)
	end
end

function Effects.init()
	folder = Instance.new("Folder")
	folder.Name = "WildFeastClientFx"
	folder.Parent = workspace
	for name, def in pairs(SOUNDS) do
		local sound = Instance.new("Sound")
		sound.Name = "WFI_" .. name
		sound.SoundId = def.id
		sound.PlaybackSpeed = def.speed
		sound.Volume = def.volume
		sound.Parent = SoundService
		sounds[name] = sound
	end
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FeedFx") :: RemoteEvent
	remote.OnClientEvent:Connect(onFx)
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for id, entry in pairs(active) do
			local t = now - entry.started
			if t > Config.Throw.MaxLifetime + 0.5 then
				removeProjectile(id)
			else
				local pos = Trajectory.positionAt(entry.origin, entry.velocity, Config.Throw.Gravity, t)
				entry.part.CFrame = CFrame.new(pos) * CFrame.Angles(t * 6, t * 4, 0)
				local ring, landsAt = entry.ring, entry.landsAt
				if ring and landsAt then
					local diameter, transparency = Feel.landingRing(t / landsAt, reduced())
					ring.Size = Vector3.new(0.12, diameter, diameter)
					ring.Transparency = if t > landsAt + 0.15 then 1 else transparency
				end
			end
		end
	end)
end

return Effects
