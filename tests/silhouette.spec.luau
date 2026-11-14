-- Silhouette details on every species (all 106): each feature and detail part is attached to the
-- model and visible (not floating, not buried inside another part), details that belong to a
-- moving part ride on it, and part counts stay inside a low-end budget.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Config = require("../src/ReplicatedStorage/Shared/Config")
local AnimalMotion = require("../src/ReplicatedStorage/Shared/AnimalMotion")
local Geo = require("./geometry")

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
			GetService = function()
				return { Shared = { AnimalMotion = SHARED } }
			end,
		},
		require = function()
			return AnimalMotion
		end,
	}
	return luau.load(fs.readFile(path), { debugName = path, environment = env })()
end

-- Visitor features plus the per-family details added for silhouette readability.
local DETAILS = {
	Crest = true,
	Horn = true,
	Antenna = true,
	Spot = true,
	Fluff = true,
	Glow = true,
	Whisker = true,
	WingSpot = true,
	EarTip = true,
	Chest = true,
	Ridge = true,
	WingTip = true,
	Scute = true,
	TailTip = true,
	PincerTip = true,
	Throat = true,
	Stripe = true,
	ShellBand = true,
	Swirl = true,
	Collar = true,
}
local PART_BUDGET = 64 -- parts per animal; 26 animals at most are active

local function parts(model)
	local list = {}
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			table.insert(list, p)
		end
	end
	return list
end

local function holderOf(p)
	local joint = p:FindFirstChildOfClass("WeldConstraint") or p:FindFirstChildOfClass("Motor6D")
	return joint and joint.Part0
end

return function(H)
	local Factory = loadFactory()

	H.test("every species: details are attached and visible, never floating or buried", function()
		local problems, checked = {}, 0
		for _, id in Config.AllSpeciesOrder do
			local model = Factory.build(Config.Species[id], "s").model
			local list = parts(model)
			for _, p in list do
				if DETAILS[p.Name] then
					checked += 1
					local touching, buried = false, false
					for _, q in list do
						if q ~= p then
							touching = touching or Geo.overlaps(Geo.obb(q), Geo.obb(p), 0.1)
							buried = buried or (not DETAILS[q.Name] and Geo.contains(q, p))
						end
					end
					if not touching then
						table.insert(problems, id .. ": " .. p.Name .. " floats")
					elseif buried then
						table.insert(problems, id .. ": " .. p.Name .. " is hidden inside another part")
					end
				end
			end
		end
		H.check(checked > 300, "details checked: " .. checked)
		H.check(#problems == 0, #problems .. " problems:\n       " .. table.concat(problems, "\n       "))
	end)

	H.test("every species: details ride on the part they belong to", function()
		for _, id in Config.AllSpeciesOrder do
			local model = Factory.build(Config.Species[id], "s").model
			for _, p in parts(model) do
				local rule = AnimalMotion.PARTS[p.Name]
				if DETAILS[p.Name] and rule and rule.parent and model:FindFirstChild(rule.parent) then
					local holder = holderOf(p)
					H.check(holder and holder.Name == rule.parent, string.format("%s: %s should ride on %s", id, p.Name, rule.parent))
				end
			end
		end
	end)

	H.test("every family has its signature details; moths get antennae exactly once", function()
		local want = {
			hopper = { "EarTip", "Belly" },
			fox = { "EarTip", "Chest" },
			boar = { "Ridge" },
			bird = { "WingTip", "Tail" },
			tortoise = { "Scute" },
			otter = { "TailTip" },
			crab = { "PincerTip" },
			frog = { "Throat", "Stripe" },
			snail = { "ShellBand" },
			moth = { "Collar", "Antenna" },
		}
		local biggest, biggestId = 0, ""
		for _, id in Config.AllSpeciesOrder do
			local species = Config.Species[id]
			local model = Factory.build(species, "s").model
			local count, names = 0, {}
			for _, p in parts(model) do
				count += 1
				names[p.Name] = (names[p.Name] or 0) + 1
			end
			for _, name in want[species.Archetype] or {} do
				H.check(names[name], id .. " (" .. species.Archetype .. ") lacks " .. name)
			end
			if species.Archetype == "moth" then
				local expected = if species.Feature == "glow" then 1 else 2
				H.check(names.Antenna == expected, string.format("%s has %d antennae", id, names.Antenna or 0))
			end
			if count > biggest then
				biggest, biggestId = count, id
			end
		end
		H.check(biggest <= PART_BUDGET, string.format("%s has %d parts (budget %d)", biggestId, biggest, PART_BUDGET))
	end)
end
