-- Wayfinding: placement checks against the actual built place (build/WildFeastIslands.rbxl).
-- Run `lune run tools/build.luau` first (tools/check.sh does). Geometry rules:
--   * stones and signs sit on the meadow's grass, clear of the spawn pad and the bridge decks;
--   * nothing new overlaps an existing prop (trees, rocks, kitchen, bell, gates, signs);
--   * lanterns sit exactly on bridge post tops;
--   * applying twice gives the same result (it runs on every server start).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Config = require("../src/ReplicatedStorage/Shared/Config")

local PLACE = "build/WildFeastIslands.rbxl"
local SOURCE = "src/ServerScriptService/Server/World/Wayfinding.luau"

local function load()
	local env = {
		Instance = roblox.Instance,
		Vector3 = roblox.Vector3,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		UDim2 = roblox.UDim2,
		UDim = roblox.UDim,
		Enum = roblox.Enum,
		Font = roblox.Font,
	}
	return luau.load(fs.readFile(SOURCE), { debugName = SOURCE, environment = env })()
end

-- Oriented-box overlap (separating axis test, 15 axes). `pad` < 0 lets boxes touch.
local function obb(part)
	return {
		c = part.CFrame.Position,
		a = { part.CFrame.XVector, part.CFrame.YVector, part.CFrame.ZVector },
		h = { part.Size.X / 2, part.Size.Y / 2, part.Size.Z / 2 },
	}
end

local function radius(box, axis)
	local r = 0
	for i = 1, 3 do
		r += box.h[i] * math.abs(box.a[i]:Dot(axis))
	end
	return r
end

local function overlaps(a, b, pad)
	local axes = {}
	for i = 1, 3 do
		table.insert(axes, a.a[i])
		table.insert(axes, b.a[i])
		for j = 1, 3 do
			local cross = a.a[i]:Cross(b.a[j])
			if cross.Magnitude > 1e-6 then
				table.insert(axes, cross.Unit)
			end
		end
	end
	local d = b.c - a.c
	for _, axis in axes do
		if math.abs(d:Dot(axis)) > radius(a, axis) + radius(b, axis) + pad then
			return false
		end
	end
	return true
end

local function bottomY(part)
	local r = obb(part)
	return r.c.Y - radius(r, roblox.Vector3.new(0, 1, 0))
end

-- Parts that are ground or water, which new pieces are meant to sit on or above.
local SURFACES = { GroundTop = true, Beach = true, Cliff = true, Sea = true, Seabed = true, Deck = true }

return function(H)
	if not fs.isFile(PLACE) then
		H.test("wayfinding (needs a built place)", function()
			error("build the place first: lune run tools/build.luau")
		end)
		return
	end
	local game = roblox.deserializePlace(fs.readFile(PLACE))
	local world = game:GetService("Workspace"):FindFirstChild(Config.World.FolderName)
	local Wayfinding = load()
	local meadow = Config.Habitats.meadow

	-- Existing props, captured before anything is added.
	local props = {}
	for _, d in world:GetDescendants() do
		if d:IsA("BasePart") and not SURFACES[d.Name] and d.Transparency < 1 then
			table.insert(props, { part = d, box = obb(d) })
		end
	end
	local folder = Wayfinding.apply(Config, world)
	local pieces = folder:GetChildren()

	H.test("wayfinding: stones and signs sit on the meadow grass, clear of the spawn", function()
		local centre = roblox.Vector3.new(meadow.Center[1], 0, meadow.Center[2])
		local spawn = roblox.Vector3.new(Config.World.SpawnPosition[1], 0, Config.World.SpawnPosition[3])
		local counts = { Stone = 0, Post = 0, Board = 0 }
		for _, p in pieces do
			counts[p.Name] = (counts[p.Name] or 0) + 1
			if p.Name == "Stone" or p.Name == "Post" or p.Name == "Board" or p.Name == "Tip" then
				local pos = p.CFrame.Position
				local flat = roblox.Vector3.new(pos.X, 0, pos.Z)
				-- The whole footprint (not just the centre) must be on the grass top.
				H.check(
					(flat - centre).Magnitude + math.max(p.Size.X, p.Size.Z) / 2 <= meadow.Radius * Config.Animal.GrassApothem,
					string.format("%s at %s is off the grass", p.Name, tostring(pos))
				)
				H.check((flat - spawn).Magnitude >= 5.5, p.Name .. " on the spawn pad")
			end
			if p.Name == "Stone" then
				H.check(math.abs(bottomY(p) - meadow.GroundY) < 0.05, "stone sits on the grass top")
				H.check(not p.CanCollide and not p.CanQuery, "stones never block walking or throws")
			end
		end
		H.check(counts.Stone >= 40, "paths have stones: " .. tostring(counts.Stone))
		H.check(counts.Post == 3 and counts.Board == 3, "one signpost per route")
	end)

	H.test("wayfinding: nothing new overlaps an existing prop", function()
		local clashes = {}
		for _, p in pieces do
			local box = obb(p)
			for _, prop in props do
				-- Touching is fine (lanterns rest on the rail); interpenetrating is not.
				if overlaps(box, prop.box, -0.02) then
					table.insert(clashes, string.format("%s at %s hits %s", p.Name, tostring(p.CFrame.Position), prop.part:GetFullName()))
				end
			end
		end
		H.check(#clashes == 0, #clashes .. " clashes:\n       " .. table.concat(clashes, "\n       "))
	end)

	H.test("wayfinding: signposts stand clear of the bridge decks and point the right way", function()
		for _, route in Wayfinding.routes(Config) do
			local dir = Wayfinding.finalDirection(route)
			local finish = route.points[#route.points]
			local board, tip
			for _, p in pieces do
				if p.Name == "Board" and p:FindFirstChild("LabelFront") then
					local text = (p:FindFirstChild("LabelFront") :: any):FindFirstChildOfClass("TextLabel").Text
					if text == route.label then
						board = p
					end
				end
			end
			H.check(board, "a board names " .. route.label)
			for _, p in pieces do
				if p.Name == "Tip" and (p.CFrame.Position - board.CFrame.Position).Magnitude < 4 then
					tip = p
				end
			end
			H.check(tip and (tip.CFrame.Position - board.CFrame.Position):Dot(dir) > 2, "the board's tip points toward " .. route.label)
			-- The path line itself (and so the bridge deck, 12 wide) must stay clear of the post.
			local toPost = board.CFrame.Position - finish
			local lateral = (toPost - dir * toPost:Dot(dir))
			H.check(roblox.Vector3.new(lateral.X, 0, lateral.Z).Magnitude >= 6 + 1, "signpost is beside the path, not on it")
		end
	end)

	H.test("wayfinding: lanterns sit on bridge post tops", function()
		local posts = {}
		for _, d in world:FindFirstChild("Bridges"):GetDescendants() do
			if d.Name == "Post" then
				table.insert(posts, d)
			end
		end
		local lanterns = 0
		for _, p in pieces do
			if p.Name == "Lantern" then
				lanterns += 1
				local bottom = p.CFrame.Position - roblox.Vector3.new(0, p.Size.Y / 2, 0)
				local best = math.huge
				for _, post in posts do
					local top = post.CFrame.Position + roblox.Vector3.new(0, post.Size.Y / 2, 0)
					best = math.min(best, (top - bottom).Magnitude)
				end
				H.check(math.abs(best - Wayfinding.RailLift) < 0.05, "lantern should rest on the rail over a post: " .. best)
			end
		end
		H.check(lanterns >= 8 and lanterns <= #posts, string.format("%d lanterns for %d posts", lanterns, #posts))
	end)

	H.test("wayfinding: idempotent, and world labels use plain sentence case", function()
		local count = #pieces
		Wayfinding.apply(Config, world)
		local folders = 0
		for _, child in world:GetChildren() do
			if child.Name == Wayfinding.FolderName then
				folders += 1
				H.check(#child:GetChildren() == count, "same pieces on a second run")
			end
		end
		H.check(folders == 1, "exactly one Wayfinding folder")
		for _, d in world:GetDescendants() do
			if d:IsA("TextLabel") and d.Parent and d.Parent.Parent and d.Parent.Parent.Name == "Gate" then
				H.check(not string.find(d.Text, "LOCKED", 1, true) and string.find(d.Text, "^Locked: "), "gate label: " .. d.Text)
			end
		end
	end)
end
