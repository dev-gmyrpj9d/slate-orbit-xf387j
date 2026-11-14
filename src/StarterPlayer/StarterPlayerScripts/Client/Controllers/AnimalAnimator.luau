--!strict
-- Brings the procedural animals to life on this client. Each frame it poses their limb joints
-- (walk cycles, ear and tail wags, wing flaps, claw snaps, a head that turns toward you), makes
-- their eyes blink, and pops hearts or a puff when an animal is fed. It also adds the small
-- breathing / sniffing / chewing bob to stationary animals (AnimalMotion.idleBob): the server
-- stops writing an animal's root once it holds still, so that bob costs no network traffic.
-- The server only moves each animal's body and publishes its State/Pose attributes; nothing
-- here affects gameplay.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local AnimalMotion = require(ReplicatedStorage.Shared.AnimalMotion)
local Effects = require(script.Parent.Effects)

local AnimalAnimator = {}

type Joint = { motor: Motor6D, role: string, side: number, front: boolean }
type Eye = { part: BasePart, size: Vector3 }
type Rig = {
	model: Model,
	root: BasePart,
	archetype: string,
	walkSpeed: number,
	joints: { Joint },
	eyes: { Eye },
	shines: { BasePart },
	lastPos: Vector3,
	base: CFrame, -- the root CFrame last replicated from the server
	written: CFrame?, -- what this client last wrote on top of it (base * idle bob)
	walk: number,
	lookYaw: number,
	t: number,
	nextBlink: number,
	blinkUntil: number,
	connections: { RBXScriptConnection },
}

local MAX_DISTANCE = 170 -- animals further than this from the camera keep their last pose
local LOOK_DISTANCE = 26 -- animals turn their heads toward the player within this range
local MAX_LOOK = 0.9 -- radians a head may turn to either side
local BLINK_SECONDS = 0.12

local rigs: { [Model]: Rig } = {}
local random = Random.new()

local function addPart(rig: Rig, d: Instance)
	if d:IsA("Motor6D") then
		local role = d:GetAttribute("Role")
		if type(role) == "string" then
			local side = d:GetAttribute("Side")
			table.insert(rig.joints, {
				motor = d,
				role = role,
				side = if type(side) == "number" then side else 0,
				front = d:GetAttribute("Front") == true,
			})
		end
	elseif d:IsA("BasePart") then
		if d.Name == "Eye" or d.Name == "EyeBall" or d.Name == "Pupil" then
			table.insert(rig.eyes, { part = d, size = d.Size })
		elseif d.Name == "Shine" then
			table.insert(rig.shines, d)
		end
	end
end

local function untrack(model: Model)
	local rig = rigs[model]
	if rig then
		for _, connection in ipairs(rig.connections) do
			connection:Disconnect()
		end
		rigs[model] = nil
	end
end

local function onStateChanged(rig: Rig)
	local state = rig.model:GetAttribute("State")
	local camera = workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - rig.root.Position).Magnitude > MAX_DISTANCE then
		return
	end
	local top = rig.root.Position + Vector3.new(0, rig.root.Size.Y * 0.5 + 1, 0)
	if state == "Happy" then
		Effects.hearts(top)
	elseif state == "Refuse" then
		Effects.puff(top)
	end
end

local function track(model: Model)
	if rigs[model] then
		return
	end
	local root = model.PrimaryPart or model:FindFirstChild("Body")
	if not root or not root:IsA("BasePart") then
		return
	end
	local speciesId = model:GetAttribute("Species")
	local species = if type(speciesId) == "string" then Config.Species[speciesId] else nil
	local rig: Rig = {
		model = model,
		root = root,
		archetype = if species then species.Archetype elseif model:GetAttribute("Giant") then "giant" else "",
		walkSpeed = if species then species.WalkSpeed else 8,
		joints = {},
		eyes = {},
		shines = {},
		lastPos = root.Position,
		base = root.CFrame,
		written = nil,
		walk = 0,
		lookYaw = 0,
		t = random:NextNumber(0, 20),
		nextBlink = os.clock() + random:NextNumber(1, 4),
		blinkUntil = 0,
		connections = {},
	}
	for _, d in ipairs(model:GetDescendants()) do
		addPart(rig, d)
	end
	table.insert(
		rig.connections,
		model.DescendantAdded:Connect(function(d)
			addPart(rig, d)
		end)
	)
	table.insert(
		rig.connections,
		model:GetAttributeChangedSignal("State"):Connect(function()
			onStateChanged(rig)
		end)
	)
	table.insert(
		rig.connections,
		model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(workspace) then
				untrack(model)
			end
		end)
	)
	rigs[model] = rig
end

-- Head yaw (body space) that points the animal's face at the local character, clamped.
local function lookYaw(rig: Rig, target: Vector3?): number
	if not target then
		return 0
	end
	local offset = rig.root.CFrame:PointToObjectSpace(target)
	local flatDistance = math.sqrt(offset.X * offset.X + offset.Z * offset.Z)
	if flatDistance > LOOK_DISTANCE or flatDistance < 0.5 or offset.Z > 0 then
		return 0 -- too far, too close, or behind: don't twist round
	end
	return math.clamp(math.atan2(-offset.X, -offset.Z), -MAX_LOOK, MAX_LOOK)
end

-- True when two CFrames are the same to within float noise.
local function same(a: CFrame, b: CFrame): boolean
	return (a.Position - b.Position).Magnitude < 1e-4
		and a.LookVector:Dot(b.LookVector) > 0.999999
		and a.UpVector:Dot(b.UpVector) > 0.999999
end

local function setBlink(rig: Rig, closed: boolean)
	for _, eye in ipairs(rig.eyes) do
		if eye.part.Parent then
			eye.part.Size = if closed then Vector3.new(eye.size.X, eye.size.Y * 0.15, eye.size.Z) else eye.size
		end
	end
	for _, shine in ipairs(rig.shines) do
		shine.LocalTransparencyModifier = if closed then 1 else 0
	end
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	if not camera or dt <= 0 then
		return
	end
	local cameraPos = camera.CFrame.Position
	local character = Players.LocalPlayer.Character
	local head = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")) :: BasePart?
	local headPos = head and head.Position
	local now = os.clock()
	dt = math.min(dt, 0.1)
	for model, rig in pairs(rigs) do
		local root = rig.root
		if not root.Parent then
			untrack(model)
			continue
		end
		-- Anything other than our own last write came from the server: that is the new base.
		local current = root.CFrame
		if not rig.written or not same(current, rig.written :: CFrame) then
			rig.base = current
		end
		local pos = rig.base.Position
		local moved = Vector3.new(pos.X - rig.lastPos.X, 0, pos.Z - rig.lastPos.Z).Magnitude
		rig.lastPos = pos
		if (pos - cameraPos).Magnitude > MAX_DISTANCE then
			continue
		end
		rig.t += dt
		local speed = math.clamp(moved / dt / math.max(rig.walkSpeed, 1), 0, 1.5)
		rig.walk += (math.min(speed, 1) - rig.walk) * math.min(1, dt * 10)
		local state = model:GetAttribute("State")
		local pose: AnimalMotion.Pose = {
			state = if type(state) == "string" then state else "Idle",
			pose = model:GetAttribute("Pose") :: string?,
			archetype = rig.archetype,
			walk = rig.walk,
			lookYaw = 0,
		}
		local desired = if pose.state == "Anticipate" or pose.state == "Idle" then lookYaw(rig, headPos) else 0
		rig.lookYaw += (desired - rig.lookYaw) * math.min(1, dt * 5)
		pose.lookYaw = rig.lookYaw
		if rig.archetype ~= "giant" then
			local dy, pitch = 0, 0
			if rig.walk < 0.05 then
				dy, pitch = AnimalMotion.idleBob(pose.state, pose.pose, rig.t)
			end
			local target = rig.base * CFrame.new(0, dy, 0) * CFrame.Angles(pitch, 0, 0)
			if not same(target, current) then
				root.CFrame = target
			end
			rig.written = root.CFrame
		end
		for _, joint in ipairs(rig.joints) do
			local rx, ry, rz = AnimalMotion.jointAngles(joint.role, joint.side, joint.front, pose, rig.t)
			joint.motor.Transform = CFrame.Angles(rx, ry, rz)
		end
		if #rig.eyes > 0 then
			if rig.blinkUntil > 0 and now >= rig.blinkUntil then
				rig.blinkUntil = 0
				setBlink(rig, false)
			elseif rig.blinkUntil == 0 and now >= rig.nextBlink then
				rig.blinkUntil = now + BLINK_SECONDS
				-- Mostly single blinks, sometimes a quick double.
				rig.nextBlink = now + (if random:NextNumber() < 0.2 then 0.3 else random:NextNumber(2.5, 5.5))
				setBlink(rig, true)
			end
		end
	end
end

local function watchFolder(folder: Instance)
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") then
			track(child)
		end
	end
	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			-- Let the whole model finish replicating before reading its joints.
			task.defer(track, child)
		end
	end)
end

function AnimalAnimator.init()
	RunService.PreSimulation:Connect(step)
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "WildFeastAnimals" then
			watchFolder(child)
		elseif child.Name == "WildFeastGiant" and child:IsA("Model") then
			task.defer(track, child)
		end
	end)
	local animals = workspace:FindFirstChild("WildFeastAnimals")
	if animals then
		watchFolder(animals)
	end
	local giant = workspace:FindFirstChild("WildFeastGiant")
	if giant and giant:IsA("Model") then
		track(giant)
	end
end

return AnimalAnimator
