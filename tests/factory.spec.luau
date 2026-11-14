-- AnimalFactory: every species (core + visitors) and the giant build a valid rig.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Config = require("../src/ReplicatedStorage/Shared/Config")
local AnimalMotion = require("../src/ReplicatedStorage/Shared/AnimalMotion")

local SHARED = {}
local function loadFactory()
	local path = "src/ServerScriptService/Server/World/AnimalFactory.luau"
	local env = {
		Instance = roblox.Instance,
		Vector3 = roblox.Vector3,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
		Font = roblox.Font,
		game = {
			GetService = function(_, name)
				assert(name == "ReplicatedStorage", "unexpected service " .. tostring(name))
				return { Shared = { AnimalMotion = SHARED } }
			end,
		},
		require = function(target)
			assert(target == SHARED, "unexpected require")
			return AnimalMotion
		end,
	}
	return luau.load(fs.readFile(path), { debugName = path, environment = env })()
end

local function close(a, b, eps)
	local d = a:Inverse() * b
	local rx, ry, rz = d:ToEulerAnglesXYZ()
	return d.Position.Magnitude < eps and math.abs(rx) + math.abs(ry) + math.abs(rz) < eps
end

-- Checks the joint graph: every non-root part has exactly one joint, joints reach the root, and
-- each Motor6D's C0/C1 reproduce the build pose (so an identity Transform changes nothing).
local function checkRig(H, built, label)
	local model, root = built.model, built.root
	H.check(model.PrimaryPart == root, label .. ": PrimaryPart is the body")
	H.check(root.Anchored, label .. ": body anchored")
	local holderOf = {}
	local motors = 0
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part ~= root then
			local joints = {}
			for _, j in part:GetChildren() do
				if j:IsA("Motor6D") or j:IsA("WeldConstraint") then
					table.insert(joints, j)
				end
			end
			H.check(#joints == 1, string.format("%s: %s has %d joints", label, part.Name, #joints))
			local joint = joints[1]
			H.check(joint.Part1 == part, label .. ": joint Part1")
			H.check(joint.Part0 ~= nil and joint.Part0 ~= part, label .. ": joint Part0")
			holderOf[part] = joint.Part0
			if joint:IsA("Motor6D") then
				motors += 1
				H.check(type(joint:GetAttribute("Role")) == "string", label .. ": motor role")
				H.check(close(joint.Part0.CFrame * joint.C0, part.CFrame * joint.C1, 1e-3), label .. ": motor pose for " .. part.Name)
			end
		end
	end
	for part in holderOf do
		local cursor, steps = part, 0
		while cursor ~= root do
			cursor = holderOf[cursor]
			steps += 1
			H.check(cursor ~= nil and steps < 8, label .. ": " .. part.Name .. " does not reach the body")
		end
	end
	return motors
end

return function(H)
	local Factory = loadFactory()

	H.test("every species builds a rig with animated joints", function()
		local count = 0
		for id, species in Config.Species do
			local built = Factory.build(species, id .. "_1")
			local motors = checkRig(H, built, id)
			H.check(motors >= 2, id .. " has only " .. motors .. " animated joints")
			count += 1
		end
		H.check(count >= 100, "expected the full species list, got " .. count)
	end)

	H.test("bird feet ride on their legs; hopper and frog feet are legs", function()
		local function roleOf(built, name)
			local roles = {}
			for _, part in built.model:GetChildren() do
				if part.Name == name then
					local motor = part:FindFirstChildOfClass("Motor6D")
					table.insert(
						roles,
						if motor then motor:GetAttribute("Role") else "weld:" .. part:FindFirstChildOfClass("WeldConstraint").Part0.Name
					)
				end
			end
			return roles
		end
		for _, id in { "waddlebill" } do
			local roles = roleOf(Factory.build(Config.Species[id], "t"), "Foot")
			H.check(#roles == 2, id .. " feet")
			for _, r in roles do
				H.check(r == "weld:Leg", id .. " foot should ride on its leg, got " .. tostring(r))
			end
		end
		for _, id in { "puffhop" } do
			local roles = roleOf(Factory.build(Config.Species[id], "t"), "Foot")
			H.check(#roles == 2, "puffhop feet")
			for _, r in roles do
				H.check(r == "leg", "puffhop foot should be a leg, got " .. tostring(r))
			end
		end
	end)

	H.test("ears hang from the head and carry their inner ear", function()
		local built = Factory.build(Config.Species.puffhop, "t")
		for _, part in built.model:GetChildren() do
			if part.Name == "Ear" then
				local motor = part:FindFirstChildOfClass("Motor6D")
				H.check(motor and motor.Part0.Name == "Head", "ear joint should hang from Head")
			elseif part.Name == "EarInner" then
				H.check(part:FindFirstChildOfClass("WeldConstraint").Part0.Name == "Ear", "inner ear rides on ear")
			end
		end
	end)

	H.test("mouth offset and catch attributes are unchanged by rigging", function()
		local built = Factory.build(Config.Species.puffhop, "t")
		local scale = Config.Species.puffhop.Scale
		H.check((built.mouthOffset - roblox.Vector3.new(0, 1.1, -2.4) * scale).Magnitude < 1e-4, "puffhop mouth offset")
		H.check(built.model:GetAttribute("CatchRadius") == Config.Species.puffhop.MouthRadius, "catch radius attribute")
	end)

	H.test("the giant rigs only its fins and tail", function()
		local built = Factory.buildGiant("Test Giant")
		checkRig(H, built, "giant")
		local roles = {}
		for _, d in built.model:GetDescendants() do
			if d:IsA("Motor6D") then
				roles[d.Part1.Name] = d:GetAttribute("Role")
			end
		end
		H.check(roles.Fin == "fin" and roles.TailFin == "tail", "giant fin/tail joints")
		H.check(roles.Head == nil and roles.Mouth == nil, "giant head and mouth stay rigid")
	end)
end
