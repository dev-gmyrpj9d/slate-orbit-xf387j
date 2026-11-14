--!strict
-- Server-simulated animals with a small state machine:
--   Idle (wander) -> Approach (walk to ground food) -> Eat -> Happy -> Idle
--   Idle -> Anticipate (a nearby player holds food it likes; mouth target grows)
--   Eat/Refuse are entered when food reaches the animal.
-- While idle an animal also picks a pose (wander / sniff / watch a nearby player / rest), sent to
-- clients as the "Pose" attribute so they can animate it, and neighbours gently push apart.
-- Animals are anchored single-root assemblies moved by CFrame each frame (cheap replication),
-- clamped to their island, and recovered automatically if stuck, displaced or destroyed.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Guard = require(ReplicatedStorage.Shared.Guard)
local Economy = require(ReplicatedStorage.Shared.Economy)
local AnimalMotion = require(ReplicatedStorage.Shared.AnimalMotion)
local AnimalFactory = require(script.Parent.Parent.World.AnimalFactory)

export type GroundFood = {
	id: number,
	position: Vector3,
	foodId: string,
	habitatId: string?,
	owner: Player,
	claimedBy: any?,
	removed: boolean,
	ignoredBy: { [any]: boolean },
}

export type Animal = {
	id: string,
	species: any,
	habitat: any,
	model: Model,
	root: BasePart,
	emote: TextLabel,
	mouthOffset: Vector3,
	halfHeight: number,
	home: Vector3,
	wanderRadius: number,
	pos: Vector3,
	yaw: number,
	state: string,
	stateStarted: number,
	stateEnds: number,
	nextState: string?,
	moveTarget: Vector3?,
	nextWander: number,
	food: GroundFood?,
	lookAt: Vector3?,
	bestDistance: number,
	lastProgressAt: number,
	phase: number,
	idleMode: string, -- wander | sniff | watch | rest (only meaningful while Idle)
	sink: number, -- eased 0..1 for how far a resting animal has settled down
	lastWrite: { number }?, -- last replicated root pose { x, y, z, yaw, pitch, roll }
	-- visitor slots only
	slot: { habitat: string, index: number, cursor: number, since: number, luredUntil: number, lockedUntil: number }?,
}

type Deps = {
	getProfile: (Player) -> any,
	markDirty: (Player) -> (),
}

local AnimalService = {}
-- Root CFrame writes (each one replicates to every client). Read by tests and debugging.
AnimalService.stats = { writes = 0 }

local animals: { Animal } = {}
local folder: Folder
local deps: Deps
local groundFoodsProvider: () -> { GroundFood } = function()
	return {}
end
local reachFoodCallback: (Animal, GroundFood) -> () = function(_animal: Animal, _food: GroundFood) end
local random = Random.new(Config.World.Seed + 7)

local WATCH_RADIUS = 22 -- idle animals may stop and watch a player this close
local SEPARATION_STEP = 0.6 -- most an animal is nudged away from its neighbours per AI tick
local REST_SINK = 0.22 -- fraction of its height a resting animal settles down

local EMOTES = {
	Idle = "",
	Approach = "?",
	Anticipate = "!",
	Eat = "nom nom",
	Happy = "♥",
	Refuse = "✕",
}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function isFinite(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e6 and math.abs(v.Z) < 1e6
end

local function habitatCenter(habitat: any): Vector3
	return Vector3.new(habitat.Center[1], 0, habitat.Center[2])
end

-- Furthest an animal may walk from its island centre (it still wanders within EdgeMargin; this
-- outer limit lets it reach food anywhere on the grass).
function AnimalService.reachRadius(habitat: any): number
	return habitat.Radius * Config.Animal.GrassApothem - Config.Animal.ReachInset
end

local function clampToIsland(animal: Animal, p: Vector3, limit: number?): Vector3
	local center = habitatCenter(animal.habitat)
	local offset = flat(p) - center
	local maxDistance = limit or (animal.habitat.Radius - Config.Animal.EdgeMargin)
	if offset.Magnitude > maxDistance then
		offset = offset.Unit * maxDistance
	end
	return center + offset
end

local function setPose(animal: Animal, mode: string)
	if animal.idleMode ~= mode then
		animal.idleMode = mode
		animal.model:SetAttribute("Pose", mode)
	end
end

local function setState(animal: Animal, state: string, duration: number?, nextState: string?)
	if state == "Idle" and animal.state ~= "Idle" then
		setPose(animal, "wander")
		animal.nextWander = 0
	end
	animal.state = state
	animal.stateStarted = os.clock()
	animal.stateEnds = if duration then os.clock() + duration else math.huge
	animal.nextState = nextState
	if animal.emote.Text ~= EMOTES[state] then
		animal.emote.Text = EMOTES[state] or ""
	end
	animal.model:SetAttribute("State", state)
end

local function releaseFood(animal: Animal)
	local food = animal.food
	if food and food.claimedBy == animal then
		food.claimedBy = nil
	end
	animal.food = nil
end

local function spawnModel(animal: Animal)
	local built = AnimalFactory.build(animal.species, animal.id)
	animal.model = built.model
	animal.root = built.root
	animal.emote = built.emote
	animal.mouthOffset = built.mouthOffset
	animal.halfHeight = built.halfHeight
	animal.lastWrite = nil -- a fresh model must be placed on its next step
	built.model:SetAttribute("Pose", animal.idleMode)
	built.model.Parent = folder
end

local function resetAnimal(animal: Animal)
	releaseFood(animal)
	animal.pos = animal.home
	animal.moveTarget = nil
	if animal.model.Parent == nil or animal.root.Parent == nil then
		pcall(function()
			animal.model:Destroy()
		end)
		spawnModel(animal)
	end
	setState(animal, "Idle")
end

function AnimalService.mouthPosition(animal: Animal): Vector3
	return animal.root.CFrame * animal.mouthOffset
end

function AnimalService.bodyPosition(animal: Animal): Vector3
	return animal.root.CFrame.Position
end

function AnimalService.isReceptive(animal: Animal): boolean
	return animal.state == "Idle" or animal.state == "Anticipate" or animal.state == "Approach"
end

function AnimalService.catchRadius(animal: Animal): number
	local radius = animal.species.MouthRadius
	if animal.state == "Anticipate" then
		radius *= Config.Animal.AnticipateCatchBonus
	end
	return radius
end

function AnimalService.getAnimals(): { Animal }
	return animals
end

-- Called by the feeding service once a reward has been resolved for this animal.
function AnimalService.onFed(animal: Animal, accepted: boolean, foodPosition: Vector3?)
	releaseFood(animal)
	animal.lookAt = foodPosition
	if accepted then
		setState(animal, "Eat", Config.Animal.EatDuration, "Happy")
	else
		setState(animal, "Refuse", Config.Animal.RefuseDuration, "Idle")
	end
end

function AnimalService.bindFeeding(provider: () -> { GroundFood }, onReach: (Animal, GroundFood) -> ())
	groundFoodsProvider = provider
	reachFoodCallback = onReach
end

local function findFood(animal: Animal): GroundFood?
	local best: GroundFood? = nil
	local bestDist = animal.species.SenseRadius
	for _, food in ipairs(groundFoodsProvider()) do
		if not food.removed and food.claimedBy == nil and not food.ignoredBy[animal] and food.habitatId == animal.habitat.Id then
			if Economy.preference(Config, animal.species.Id, food.foodId) ~= "disliked" then
				local d = (flat(food.position) - animal.pos).Magnitude
				if d < bestDist then
					best, bestDist = food, d
				end
			end
		end
	end
	return best
end

local function findEagerPlayer(animal: Animal): Vector3?
	local bestPos: Vector3? = nil
	local bestDist = Config.Animal.AnticipateRadius
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local profile = deps.getProfile(player)
		if hrp and profile and profile.unlockedHabitats[animal.habitat.Id] then
			local foodId = profile.selectedFood
			if Economy.hasFood(Config, profile, foodId) and Economy.preference(Config, animal.species.Id, foodId) ~= "disliked" then
				local d = (flat(hrp.Position) - animal.pos).Magnitude
				if d < bestDist then
					bestPos, bestDist = hrp.Position, d
				end
			end
		end
	end
	return bestPos
end

local function nearestCharacter(animal: Animal, radius: number): Vector3?
	local bestPos: Vector3? = nil
	local bestDist = radius
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			local d = (flat(hrp.Position) - animal.pos).Magnitude
			if d < bestDist then
				bestPos, bestDist = hrp.Position, d
			end
		end
	end
	return bestPos
end

-- The nearest player (within GreetRadius, on this island) who has earned this species' trust.
local function nearestFriend(animal: Animal): Vector3?
	local bestPos: Vector3? = nil
	local bestDist = Config.Animal.GreetRadius
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local profile = hrp and deps.getProfile(player)
		if hrp and profile then
			local level = Economy.trustLevel(Config, profile.trust[animal.species.Id] or 0)
			local d = (flat(hrp.Position) - animal.pos).Magnitude
			if
				level >= Config.Animal.GreetTrustLevel
				and d < bestDist
				and (flat(hrp.Position) - habitatCenter(animal.habitat)).Magnitude <= animal.habitat.Radius
			then
				bestPos, bestDist = hrp.Position, d
			end
		end
	end
	return bestPos
end

local function think(animal: Animal, now: number)
	if animal.model.Parent == nil or animal.root.Parent == nil or not isFinite(animal.pos) then
		resetAnimal(animal)
		return
	end
	local state = animal.state
	if state == "Eat" or state == "Happy" or state == "Refuse" then
		if now >= animal.stateEnds then
			local nextState = animal.nextState or "Idle"
			setState(animal, nextState, if nextState == "Happy" then Config.Animal.HappyDuration else nil, "Idle")
		end
		return
	end

	if state == "Approach" then
		local food = animal.food
		if not food or food.removed or food.claimedBy ~= animal then
			releaseFood(animal)
			setState(animal, "Idle")
			return
		end
		local dist = (flat(food.position) - animal.pos).Magnitude
		if dist <= Config.Animal.EatDistance then
			reachFoodCallback(animal, food)
			if animal.state == "Approach" then
				-- The feeding service declined (e.g. owner left); stop chasing it.
				food.ignoredBy[animal] = true
				releaseFood(animal)
				setState(animal, "Idle")
			end
			return
		end
		if dist < animal.bestDistance - Config.Animal.StuckProgressEpsilon then
			animal.bestDistance = dist
			animal.lastProgressAt = now
		elseif now - animal.lastProgressAt > Config.Animal.StuckSeconds then
			-- Stuck recovery: give up on this food and wander somewhere else.
			food.ignoredBy[animal] = true
			releaseFood(animal)
			animal.moveTarget = nil
			setState(animal, "Idle")
		end
		return
	end

	local food = findFood(animal)
	if food then
		food.claimedBy = animal
		animal.food = food
		animal.bestDistance = math.huge
		animal.lastProgressAt = now
		setState(animal, "Approach")
		return
	end

	local eager = findEagerPlayer(animal)
	if eager then
		animal.lookAt = eager
		if state ~= "Anticipate" then
			setState(animal, "Anticipate")
		end
		return
	end
	if state == "Anticipate" then
		setState(animal, "Idle")
	end
	if now >= animal.nextWander or (animal.idleMode == "wander" and not animal.moveTarget) then
		local watchTarget = nearestCharacter(animal, WATCH_RADIUS)
		local friend = nearestFriend(animal)
		local choice = AnimalMotion.pickIdle(random:NextNumber(), animal.species.Archetype, watchTarget ~= nil, friend ~= nil)
		animal.lookAt = if choice.mode == "watch" then watchTarget else nil
		animal.moveTarget = nil
		if choice.mode == "greet" and friend then
			-- Trot over and stop a few studs short, facing them; the next idle pick (often "watch",
			-- since they are close) follows once it arrives.
			setPose(animal, "wander")
			local away = animal.pos - flat(friend)
			local stop = if away.Magnitude > 1e-3 then away.Unit * Config.Animal.GreetStopDistance else Vector3.zero
			animal.moveTarget = clampToIsland(animal, flat(friend) + stop)
			animal.lookAt = friend
			animal.nextWander = now + random:NextNumber(choice.min, choice.max)
			return
		end
		setPose(animal, choice.mode)
		if choice.mode == "wander" then
			local angle = random:NextNumber(0, math.pi * 2)
			local dist = random:NextNumber(0.2, 1) * animal.wanderRadius
			animal.moveTarget = clampToIsland(animal, animal.home + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist))
			animal.nextWander = now + random:NextNumber(Config.Animal.WanderMin, Config.Animal.WanderMax)
		else
			animal.nextWander = now + random:NextNumber(choice.min, choice.max)
		end
	elseif animal.idleMode == "watch" then
		-- Keep following the player with its eyes; lose interest once they walk away.
		animal.lookAt = nearestCharacter(animal, WATCH_RADIUS)
		if not animal.lookAt then
			animal.nextWander = now
		end
	end
end

-- Nudges animals on the same island apart so they never stand inside each other.
local function separate()
	local byHabitat: { [string]: { { number } } } = {}
	for _, animal in ipairs(animals) do
		local list = byHabitat[animal.habitat.Id]
		if not list then
			list = {}
			byHabitat[animal.habitat.Id] = list
		end
		table.insert(list, { animal.pos.X, animal.pos.Z, animal.species.BodyRadius * 0.8 })
	end
	local cursor: { [string]: number } = {}
	for _, animal in ipairs(animals) do
		local id = animal.habitat.Id
		local index = (cursor[id] or 0) + 1
		cursor[id] = index
		local list = byHabitat[id]
		-- Hide this animal's own entry while measuring its neighbours.
		local own = list[index]
		list[index] = { math.huge, math.huge, 0 }
		local dx, dz = AnimalMotion.separation(animal.pos.X, animal.pos.Z, own[3], list, SEPARATION_STEP)
		list[index] = own
		if dx ~= 0 or dz ~= 0 then
			animal.pos = clampToIsland(animal, animal.pos + Vector3.new(dx, 0, dz), AnimalService.reachRadius(animal.habitat))
		end
	end
end

local function yawToward(from: Vector3, to: Vector3, fallback: number): number
	local d = flat(to) - flat(from)
	if d.Magnitude < 0.05 then
		return fallback
	end
	return math.atan2(-d.X, -d.Z)
end

local function lerpAngle(a: number, b: number, t: number): number
	local diff = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + diff * math.clamp(t, 0, 1)
end

local function move(animal: Animal, dt: number, now: number)
	local state = animal.state
	local speed = 0
	local target: Vector3? = nil
	if state == "Approach" and animal.food then
		target = flat(animal.food.position)
		speed = animal.species.WalkSpeed
	elseif state == "Idle" and animal.moveTarget then
		target = animal.moveTarget
		speed = animal.species.WalkSpeed * 0.45
	end

	local moving = false
	local desiredYaw = animal.yaw
	if target then
		local delta = target - animal.pos
		local dist = delta.Magnitude
		if dist > 0.3 then
			local stepLen = math.min(dist, speed * dt)
			animal.pos = clampToIsland(animal, animal.pos + delta.Unit * stepLen, AnimalService.reachRadius(animal.habitat))
			desiredYaw = yawToward(Vector3.zero, delta, animal.yaw)
			moving = true
		end
	elseif animal.lookAt and (state == "Anticipate" or state == "Eat" or (state == "Idle" and animal.idleMode == "watch")) then
		desiredYaw = yawToward(animal.pos, animal.lookAt, animal.yaw)
	end
	animal.yaw = lerpAngle(animal.yaw, desiredYaw, dt * 8)
	animal.phase += dt

	local t = animal.phase
	local progress = if state == "Happy" then math.clamp((now - animal.stateStarted) / Config.Animal.HappyDuration, 0, 1) else 0
	local dy, extraYaw, pitch, roll = AnimalMotion.bodyMotion(state, animal.species.Archetype, moving, t, progress)
	local y = animal.habitat.GroundY + animal.halfHeight + dy

	local resting = if state == "Idle" and animal.idleMode == "rest" then 1 else 0
	animal.sink += (resting - animal.sink) * math.min(1, dt * 4)
	if math.abs(resting - animal.sink) < 1e-3 then
		animal.sink = resting
	end
	y -= animal.halfHeight * REST_SINK * animal.sink

	-- Only replicate real changes: a resting animal settles, then stops sending updates. The
	-- breathing / sniffing / chewing bob is added by each client (AnimalAnimator, idleBob).
	local yaw = animal.yaw + extraYaw
	local pose = { animal.pos.X, y, animal.pos.Z, yaw, pitch, roll }
	if AnimalMotion.needsWrite(animal.lastWrite, pose) then
		animal.lastWrite = pose
		animal.root.CFrame = CFrame.new(animal.pos.X, y, animal.pos.Z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, roll)
		AnimalService.stats.writes += 1
	end
end

local function spotSpecies()
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = deps.getProfile(player)
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if profile and hrp then
			local changed = false
			for _, animal in ipairs(animals) do
				local id = animal.species.Id
				if not profile.seenSpecies[id] and profile.unlockedHabitats[animal.habitat.Id] then
					if (flat(hrp.Position) - animal.pos).Magnitude < 45 then
						profile.seenSpecies[id] = true
						changed = true
					end
				end
			end
			if changed then
				deps.markDirty(player)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Visitor slots: a few per island. Each slot shows one visiting species at a time and rotates
-- through that island's visitors; a lure takes over the slot that has shown its visitor longest
-- (never one that was lured moments ago). Only SlotsPerHabitat x islands visitor models exist.
--------------------------------------------------------------------------------
local visitorPools: { [string]: { string } } = {}
local visitorSlots: { Animal } = {}

local function randomHome(habitat: any): Vector3
	local center = habitatCenter(habitat)
	local angle = random:NextNumber(0, math.pi * 2)
	local dist = random:NextNumber(0.25, 0.6) * habitat.Radius
	return center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
end

local function showSpecies(animal: Animal, speciesId: string)
	releaseFood(animal)
	pcall(function()
		animal.model:Destroy()
	end)
	animal.species = Config.Species[speciesId]
	animal.home = randomHome(animal.habitat)
	animal.pos = clampToIsland(animal, animal.home)
	animal.moveTarget = nil
	spawnModel(animal)
	animal.model:SetAttribute("Visitor", true)
	setState(animal, "Idle")
end

function AnimalService.visitorSlots(): { Animal }
	return visitorSlots
end

-- Calls a visitor to its island. Returns (ok, message); the caller consumes the lure on success.
function AnimalService.summon(speciesId: string, _player: Player?): (boolean, string)
	local species = Config.Species[speciesId]
	if not species or not species.Visitor then
		return false, "Unknown visitor."
	end
	local now = os.clock()
	local candidate: Animal? = nil
	for _, animal in ipairs(visitorSlots) do
		local slot = animal.slot :: any
		if slot.habitat == species.Habitat then
			if animal.species.Id == speciesId then
				-- No lure is spent here, so the stay is not extended either (that was a free,
				-- repeatable way to pin a visitor in place).
				return false, species.Name .. " is already at " .. animal.habitat.Name .. ". Your lure is kept."
			end
			if now >= slot.lockedUntil and (candidate == nil or slot.since < (candidate.slot :: any).since) then
				candidate = animal
			end
		end
	end
	if not candidate then
		return false, "Every visitor spot there was just filled by a lure. Try again in a moment."
	end
	local slot = candidate.slot :: any
	showSpecies(candidate, speciesId)
	slot.since = now
	slot.luredUntil = now + Config.Visitors.LuredStaySeconds
	slot.lockedUntil = now + Config.Visitors.LureLockSeconds
	return true, string.format("A %s is on its way to %s.", species.Name, Config.Habitats[species.Habitat].Name)
end

local function rotateVisitors(now: number)
	for _, animal in ipairs(visitorSlots) do
		local slot = animal.slot :: any
		if now >= slot.luredUntil and now - slot.since >= Config.Visitors.RotateSeconds and animal.state ~= "Eat" then
			local pool = visitorPools[slot.habitat]
			-- Skip species already shown by the island's other slot.
			for _ = 1, #pool do
				slot.cursor = slot.cursor % #pool + 1
				local candidate = pool[slot.cursor]
				local taken = false
				for _, other in ipairs(visitorSlots) do
					if other ~= animal and other.species.Id == candidate then
						taken = true
					end
				end
				if not taken then
					showSpecies(animal, candidate)
					break
				end
			end
			slot.since = now
		end
	end
end

function AnimalService.init(dependencies: Deps)
	deps = dependencies
	local existing = workspace:FindFirstChild("WildFeastAnimals")
	if existing then
		existing:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "WildFeastAnimals"
	folder.Parent = workspace

	local spawn = Config.World.SpawnPosition
	local tutorialOffset = Config.Animal.FirstSpawnOffset
	for _, speciesId in ipairs(Config.SpeciesOrder) do
		local species = Config.Species[speciesId]
		local habitat = Config.Habitats[species.Habitat]
		local center = habitatCenter(habitat)
		local sector = if species.Order % 2 == 1 then 0 else math.pi
		for i = 1, species.Count do
			if #animals >= Config.Animal.MaxActive then
				break
			end
			local home: Vector3
			local wanderRadius = 16
			if speciesId == "puffhop" and i == 1 then
				-- Tutorial Puffhop: always a few steps in front of the spawn point.
				home = Vector3.new(spawn[1] + tutorialOffset[1], 0, spawn[3] + tutorialOffset[2])
				wanderRadius = 5
			else
				local angle = sector + random:NextNumber(-1.2, 1.2)
				local dist = random:NextNumber(0.25, 0.6) * habitat.Radius
				home = center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
			end
			local animal: Animal = {
				id = speciesId .. "_" .. i,
				species = species,
				habitat = habitat,
				model = nil :: any,
				root = nil :: any,
				emote = nil :: any,
				mouthOffset = Vector3.zero,
				halfHeight = 1,
				home = home,
				wanderRadius = wanderRadius,
				pos = home,
				yaw = random:NextNumber(0, math.pi * 2),
				state = "Idle",
				stateStarted = 0,
				stateEnds = math.huge,
				nextState = nil,
				moveTarget = nil,
				nextWander = 0,
				food = nil,
				lookAt = nil,
				bestDistance = math.huge,
				lastProgressAt = 0,
				phase = random:NextNumber(0, 10),
				idleMode = "wander",
				sink = 0,
			}
			spawnModel(animal)
			animal.pos = clampToIsland(animal, home)
			table.insert(animals, animal)
			setState(animal, "Idle")
		end
	end

	-- Visitor slots (bounded by SlotsPerHabitat x islands and the global MaxActive cap).
	for _, speciesId in ipairs(Config.VisitorOrder) do
		local habitatId = Config.Species[speciesId].Habitat
		visitorPools[habitatId] = visitorPools[habitatId] or {}
		table.insert(visitorPools[habitatId], speciesId)
	end
	for _, habitatId in ipairs(Config.HabitatOrder) do
		local pool = visitorPools[habitatId]
		for index = 1, if pool then Config.Visitors.SlotsPerHabitat else 0 do
			if #animals >= Config.Animal.MaxActive then
				break
			end
			local cursor = ((index - 1) * math.floor(#pool / Config.Visitors.SlotsPerHabitat)) % #pool + 1
			local habitat = Config.Habitats[habitatId]
			local home = randomHome(habitat)
			local animal: Animal = {
				id = "visitor_" .. habitatId .. "_" .. index,
				species = Config.Species[pool[cursor]],
				habitat = habitat,
				model = nil :: any,
				root = nil :: any,
				emote = nil :: any,
				mouthOffset = Vector3.zero,
				halfHeight = 1,
				home = home,
				wanderRadius = 16,
				pos = home,
				yaw = random:NextNumber(0, math.pi * 2),
				state = "Idle",
				stateStarted = 0,
				stateEnds = math.huge,
				nextState = nil,
				moveTarget = nil,
				nextWander = 0,
				food = nil,
				lookAt = nil,
				bestDistance = math.huge,
				lastProgressAt = 0,
				phase = random:NextNumber(0, 10),
				idleMode = "wander",
				sink = 0,
				slot = { habitat = habitatId, index = index, cursor = cursor, since = os.clock(), luredUntil = 0, lockedUntil = 0 },
			}
			spawnModel(animal)
			animal.model:SetAttribute("Visitor", true)
			animal.pos = clampToIsland(animal, home)
			table.insert(animals, animal)
			table.insert(visitorSlots, animal)
			setState(animal, "Idle")
		end
	end

	local thinkAccumulator = 0
	local spotAccumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		dt = math.min(dt, 0.1)
		thinkAccumulator += dt
		spotAccumulator += dt
		if thinkAccumulator >= 1 / Config.Animal.TickRate then
			thinkAccumulator = 0
			for _, animal in ipairs(animals) do
				if not Guard.run("Animal AI " .. animal.id, think, animal, now) then
					Guard.run("Animal reset " .. animal.id, resetAnimal, animal)
				end
			end
			Guard.run("Animal separation", separate)
		end
		for _, animal in ipairs(animals) do
			if animal.root.Parent then
				move(animal, dt, now)
			end
		end
		if spotAccumulator >= 1 then
			spotAccumulator = 0
			spotSpecies()
			Guard.run("Visitor rotation", rotateVisitors, now)
		end
	end)
end

return AnimalService
