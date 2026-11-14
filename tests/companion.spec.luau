-- CompanionModel: the Lanternkit builds a valid rig and its pose curves are well behaved.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Config = require("../src/ReplicatedStorage/Shared/Config")

local function load()
	local path = "src/ReplicatedStorage/Shared/CompanionModel.luau"
	local env = {
		Instance = roblox.Instance,
		Vector3 = roblox.Vector3,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		Enum = roblox.Enum,
	}
	return luau.load(fs.readFile(path), { debugName = path, environment = env })()
end

local function close(a, b, eps)
	local d = a:Inverse() * b
	local rx, ry, rz = d:ToEulerAnglesXYZ()
	return d.Position.Magnitude < eps and math.abs(rx) + math.abs(ry) + math.abs(rz) < eps
end

return function(H)
	local CompanionModel = load()

	for id, def in Config.Companions do
		H.test(id .. " builds a rig whose joints keep the build pose", function()
			local rig = CompanionModel.build(def)
			H.check(rig.model.PrimaryPart == rig.root and rig.root.Anchored, "anchored root is the primary part")
			H.check(#rig.legs == 4, "four legs")
			for _, part in rig.model:GetChildren() do
				if part:IsA("BasePart") and part ~= rig.root then
					H.check(not part.Anchored and not part.CanCollide and not part.CanQuery, part.Name .. " is a loose cosmetic part")
					local joints = 0
					for _, j in part:GetChildren() do
						if j:IsA("Motor6D") or j:IsA("Weld") then
							joints += 1
							H.check(j.Part1 == part and j.Part0 ~= part, part.Name .. " joint parts")
							local c1 = if j:IsA("Motor6D") then j.C1 else roblox.CFrame.new()
							H.check(close(j.Part0.CFrame * j.C0, part.CFrame * c1, 1e-3), part.Name .. " joint keeps its pose")
						end
					end
					H.check(joints == 1, string.format("%s has %d joints", part.Name, joints))
				end
			end
		end)

		H.test(id .. " poses stay finite and bounded; standing still means no bob", function()
			local rig = CompanionModel.build(def)
			for t = 0, 3, 0.37 do
				for _, speed in { 0, 0.5, 1 } do
					for _, perk in { 0, 0.5, 1 } do
						local bob = CompanionModel.pose(rig, t, speed, perk, 3)
						H.check(bob == bob and bob >= 0 and bob <= 1.1, "bob in range")
						local _, yaw = rig.head.Transform:ToEulerAnglesXYZ()
						H.check(math.abs(yaw) <= 0.9 + 1e-5, "head yaw clamped: " .. yaw)
					end
				end
				H.near(CompanionModel.pose(rig, t, 0, 0, 0), 0, 1e-9, "no bob when idle")
			end
		end)
	end
end
