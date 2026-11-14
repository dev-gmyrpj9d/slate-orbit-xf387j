--!strict
-- Wayfinding over the baked world, applied at server start (idempotent):
--   * Stepping-stone paths from the spawn to each bridge and to the Feast Cove pier, in one warm
--     stone colour that contrasts with the grass and always leads to a landmark.
--   * A signpost at each path's end whose board points (by shape) toward where it goes.
--   * Small paper lanterns on alternate bridge posts, so bridges read as routes from a distance.
--   * Tidier world labels: Builder Sans, sentence case, shorter draw distances so fewer
--     overlap at once.
-- Everything added is decorative and anchored. Stones and boards don't collide or block raycasts
-- (throws pass through them); posts collide so players don't walk through them. Placement rules
-- are checked offline against the built place in tests/wayfinding.spec.luau.

local Wayfinding = {}

Wayfinding.FolderName = "Wayfinding"
Wayfinding.StoneStep = 4.2 -- studs between stones
Wayfinding.StartClear = 7 -- no stones on or right next to the spawn pad
Wayfinding.EndClear = 3 -- the last stone stops short of the bridge / pier
Wayfinding.SignOffset = 9 -- signposts stand this far to the side of the path's end

local STONE = { 206, 192, 166 }
local WOOD = { 150, 100, 60 }
local BOARD = { 232, 214, 180 }
local INK = { 40, 36, 32 }
local LANTERN = { 246, 226, 180 }
local CAP = { 60, 52, 44 }

export type Piece = {
	kind: string, -- "stone" | "post" | "board" | "tip" | "lantern" | "cap"
	size: Vector3,
	cframe: CFrame,
	color: { number },
	collide: boolean,
	label: string?,
}
export type Route = { id: string, label: string, points: { Vector3 } } -- spawn first, path end last

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- The meadow pond (WorldBuilder) sits between the spawn and the lagoon bridge, so that path
-- bends north around it. Offsets are from the meadow's centre.
local POND_DETOUR = { { -28, 28.5 }, { -47, 27 } }

-- Spawn -> each bridge head on the meadow, and spawn -> the pier.
function Wayfinding.routes(config: any): { Route }
	local meadow = config.Habitats.meadow
	local y = meadow.GroundY
	local spawn = Vector3.new(config.World.SpawnPosition[1], y, config.World.SpawnPosition[3])
	local centre = Vector3.new(meadow.Center[1], y, meadow.Center[2])
	local routes = {}
	for _, id in ipairs({ "grove", "lagoon" }) do
		local h = config.Habitats[id]
		local dir = (Vector3.new(h.Center[1], y, h.Center[2]) - centre).Unit
		-- Same bridge head as WorldBuilder: the meadow end of the bridge.
		local head = centre + dir * (meadow.Radius - 4)
		local points = { spawn, head }
		if id == "lagoon" then
			points = { spawn }
			for _, offset in ipairs(POND_DETOUR) do
				table.insert(points, centre + Vector3.new(offset[1], 0, offset[2]))
			end
			table.insert(points, head)
		end
		table.insert(routes, { id = id, label = h.Name, points = points })
	end
	table.insert(routes, {
		id = "feast",
		label = "Feast Cove",
		points = { spawn, Vector3.new(meadow.Center[1], y, meadow.Center[2] - (meadow.Radius - 4)) },
	})
	return routes
end

-- Direction of a route's last leg (toward where it leads).
function Wayfinding.finalDirection(route: Route): Vector3
	local n = #route.points
	return flat(route.points[n] - route.points[n - 1]).Unit
end

-- Stones every StoneStep along the route's legs. Hand-laid look without randomness: small,
-- repeatable wobbles from the stone's index.
function Wayfinding.stones(route: Route, groundY: number): { Piece }
	local pieces = {}
	local total = 0
	for k = 2, #route.points do
		total += flat(route.points[k] - route.points[k - 1]).Magnitude
	end
	local i = 0
	local d = Wayfinding.StartClear
	local legStart, k = 0, 2
	while d <= total - Wayfinding.EndClear do
		local leg = flat(route.points[k] - route.points[k - 1])
		while d > legStart + leg.Magnitude and k < #route.points do
			legStart += leg.Magnitude
			k += 1
			leg = flat(route.points[k] - route.points[k - 1])
		end
		local dir = leg.Unit
		local right = Vector3.new(-dir.Z, 0, dir.X)
		local yaw = math.atan2(dir.X, dir.Z)
		i += 1
		local p = route.points[k - 1] + dir * (d - legStart) + right * (math.sin(i * 1.7) * 0.45)
		table.insert(pieces, {
			kind = "stone",
			size = Vector3.new(1.8 + 0.25 * math.sin(i * 1.1), 0.24, 2.4 + 0.3 * math.sin(i * 0.7)),
			cframe = CFrame.new(p.X, groundY + 0.1, p.Z) * CFrame.Angles(0, yaw + math.sin(i * 2.3) * 0.25, 0),
			color = STONE,
			collide = false,
		})
		d += Wayfinding.StoneStep
	end
	return pieces
end

-- A post beside the path's end with a board whose pointed tip faces the destination.
-- `back` is how far before the path's end it stands (moved back if something is in the way).
function Wayfinding.sign(route: Route, groundY: number, back: number): { Piece }
	local dir = Wayfinding.finalDirection(route)
	local right = Vector3.new(-dir.Z, 0, dir.X)
	local base = route.points[#route.points] - dir * back + right * Wayfinding.SignOffset
	local basePos = Vector3.new(base.X, groundY, base.Z)
	-- Board: long side along the path; its front face (-Z) looks back at the path.
	local boardCenter = basePos + Vector3.new(0, 5.4, 0)
	local facing = CFrame.lookAt(boardCenter, boardCenter - right)
	return {
		{
			kind = "post",
			size = Vector3.new(0.8, 7, 0.8),
			cframe = CFrame.new(basePos + Vector3.new(0, 3.5, 0)),
			color = WOOD,
			collide = true,
		},
		{
			kind = "board",
			size = Vector3.new(6.4, 1.6, 0.3),
			cframe = facing,
			color = BOARD,
			collide = false,
			label = route.label,
		},
		{
			-- The pointed end: a square turned 45 degrees at the destination end of the board.
			kind = "tip",
			size = Vector3.new(1.13, 1.13, 0.28),
			cframe = CFrame.new(boardCenter + dir * 3.2) * (facing - facing.Position) * CFrame.Angles(0, 0, math.rad(45)),
			color = BOARD,
			collide = false,
		},
	}
end

-- A lantern on top of a bridge post (post: its CFrame and size).
-- Bridge rails run RailLift studs above the post tops, so lanterns sit on the rail over a post.
Wayfinding.RailLift = 0.2
function Wayfinding.lantern(postCFrame: CFrame, postSize: Vector3): { Piece }
	local top = postCFrame.Position + Vector3.new(0, postSize.Y / 2 + Wayfinding.RailLift, 0)
	local look = postCFrame.LookVector
	local upright = CFrame.lookAt(top, top + Vector3.new(look.X, 0, look.Z))
	return {
		{
			kind = "lantern",
			size = Vector3.new(0.9, 1.0, 0.9),
			cframe = upright * CFrame.new(0, 0.5, 0),
			color = LANTERN,
			collide = false,
		},
		{
			kind = "cap",
			size = Vector3.new(1.2, 0.25, 1.2),
			cframe = upright * CFrame.new(0, 1.125, 0),
			color = CAP,
			collide = false,
		},
	}
end

-- World-space axis-aligned bounds of a box.
local function bounds(cframe: CFrame, size: Vector3): (Vector3, Vector3)
	local x, y, z = cframe.XVector, cframe.YVector, cframe.ZVector
	local half = Vector3.new(
		math.abs(x.X) * size.X / 2 + math.abs(y.X) * size.Y / 2 + math.abs(z.X) * size.Z / 2,
		math.abs(x.Y) * size.X / 2 + math.abs(y.Y) * size.Y / 2 + math.abs(z.Y) * size.Z / 2,
		math.abs(x.Z) * size.X / 2 + math.abs(y.Z) * size.Y / 2 + math.abs(z.Z) * size.Z / 2
	)
	return cframe.Position - half, cframe.Position + half
end

-- Ground and water that new pieces are meant to sit on.
Wayfinding.Surfaces = { GroundTop = true, Beach = true, Cliff = true, Sea = true, Seabed = true, Deck = true }

type Box = { lo: Vector3, hi: Vector3 }

-- Bounds of every visible prop on the meadow's level (trees, rocks, ponds, kitchen, signs...).
local function obstacles(world: Instance): { Box }
	local list = {}
	for _, d in ipairs(world:GetDescendants()) do
		if d:IsA("BasePart") and not Wayfinding.Surfaces[d.Name] and d.Transparency < 1 then
			if not d:IsDescendantOf(world:FindFirstChild(Wayfinding.FolderName) or d) then
				local lo, hi = bounds(d.CFrame, d.Size)
				table.insert(list, { lo = lo, hi = hi })
			end
		end
	end
	return list
end

local function blocked(piece: Piece, boxes: { Box }, pad: number): boolean
	local lo, hi = bounds(piece.cframe, piece.size)
	for _, b in ipairs(boxes) do
		if
			lo.X < b.hi.X + pad
			and hi.X > b.lo.X - pad
			and lo.Y < b.hi.Y + pad
			and hi.Y > b.lo.Y - pad
			and lo.Z < b.hi.Z + pad
			and hi.Z > b.lo.Z - pad
		then
			return true
		end
	end
	return false
end

-- Every piece for this world: paths and signs from config, lanterns from the bridge posts.
-- Stones that would land on an existing prop are left out (the path just has a gap there);
-- a signpost steps back along the path until it stands clear.
function Wayfinding.plan(config: any, world: Instance): { Piece }
	local pieces = {}
	local boxes = obstacles(world)
	local meadow = config.Habitats.meadow
	local groundY = meadow.GroundY
	local centre = Vector3.new(meadow.Center[1], 0, meadow.Center[2])
	local edge = meadow.Radius * config.Animal.GrassApothem - 0.5
	for _, route in ipairs(Wayfinding.routes(config)) do
		for _, piece in ipairs(Wayfinding.stones(route, groundY)) do
			-- Stones stay on the grass top (a 16-sided prism; its flat sides are the apothem away).
			local fromCentre = flat(piece.cframe.Position - centre).Magnitude + math.max(piece.size.X, piece.size.Z) / 2
			if fromCentre <= edge and not blocked(piece, boxes, 0.3) then
				table.insert(pieces, piece)
			end
		end
		for back = 12, 30, 3 do
			local sign = Wayfinding.sign(route, groundY, back)
			local clear = true
			for _, piece in ipairs(sign) do
				if blocked(piece, boxes, 0.5) then
					clear = false
				end
			end
			if clear then
				for _, piece in ipairs(sign) do
					table.insert(pieces, piece)
				end
				break
			end
		end
	end
	local bridges = world:FindFirstChild("Bridges")
	local gates: { BasePart } = {}
	local gateFolder = world:FindFirstChild("Gates")
	if gateFolder then
		for _, gate in ipairs(gateFolder:GetChildren()) do
			if gate:IsA("BasePart") then
				table.insert(gates, gate)
			end
		end
	end
	if bridges then
		for _, bridge in ipairs(bridges:GetChildren()) do
			-- Lanterns zig-zag: alternate posts along the bridge, swapping rails each time.
			local deck = bridge:FindFirstChild("Deck") :: BasePart?
			local posts: { { part: BasePart, along: number, side: number } } = {}
			for _, child in ipairs(bridge:GetChildren()) do
				if child.Name == "Post" and child:IsA("BasePart") and deck then
					local offset = deck.CFrame:Inverse() * child.CFrame.Position
					table.insert(posts, { part = child, along = offset.Z, side = if offset.X > 0 then 1 else 0 })
				end
			end
			table.sort(posts, function(a, b)
				if a.side ~= b.side then
					return a.side < b.side
				end
				return a.along < b.along
			end)
			local index = { [0] = 0, [1] = 0 }
			for _, entry in ipairs(posts) do
				local post = entry.part
				index[entry.side] += 1
				local i = index[entry.side] + entry.side
				local nearGate = false
				for _, gate in ipairs(gates) do
					if flat(gate.CFrame.Position - post.CFrame.Position).Magnitude < 9 then
						nearGate = true
					end
				end
				if i % 2 == 1 and not nearGate then
					for _, piece in ipairs(Wayfinding.lantern(post.CFrame, post.Size)) do
						table.insert(pieces, piece)
					end
				end
			end
		end
	end
	return pieces
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local LABEL_FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

local function boardText(board: BasePart, face: Enum.NormalId, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.4
	gui.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.FontFace = LABEL_FONT
	label.TextColor3 = rgb(INK)
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.12, 0)
	padding.PaddingTop = UDim.new(0.14, 0)
	padding.PaddingBottom = UDim.new(0.14, 0)
	padding.Parent = label
	gui.Parent = board
end

-- Billboard draw distances and copy for the labels WorldBuilder baked in.
local LABEL_DISTANCE = { HabitatSign = 110, FeastBoard = 140, BellPost = 140, Gate = 90, PantryTarget = 70 }

local function costText(cost: any): string
	if cost.Research > 0 then
		return string.format("%d coins + %d research", cost.Coins, cost.Research)
	end
	return string.format("%d coins", cost.Coins)
end

local function tidyLabels(config: any, world: Instance)
	for _, gui in ipairs(world:GetDescendants()) do
		if gui:IsA("BillboardGui") and gui.Parent and LABEL_DISTANCE[gui.Parent.Name] then
			gui.MaxDistance = LABEL_DISTANCE[gui.Parent.Name]
			local text = gui:FindFirstChildOfClass("TextLabel")
			if text then
				text.FontFace = LABEL_FONT
				text.TextStrokeTransparency = 0.35
				local holder = gui.Parent :: Instance
				local habitatId = holder:GetAttribute("HabitatId")
				if holder.Name == "Gate" and type(habitatId) == "string" and config.Habitats[habitatId] then
					local habitat = config.Habitats[habitatId]
					text.Text = string.format("Locked: %s\n%s, from the Map tab", habitat.Name, costText(habitat.UnlockCost))
				end
			end
		end
	end
end

function Wayfinding.apply(config: any, world: Instance): Folder
	local existing = world:FindFirstChild(Wayfinding.FolderName)
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = Wayfinding.FolderName
	for _, piece in ipairs(Wayfinding.plan(config, world)) do
		local part = Instance.new("Part")
		part.Name = string.upper(string.sub(piece.kind, 1, 1)) .. string.sub(piece.kind, 2)
		part.Size = piece.size
		part.CFrame = piece.cframe
		part.Color = rgb(piece.color)
		part.Material = if piece.kind == "stone"
			then Enum.Material.Slate
			elseif piece.kind == "post" or piece.kind == "board" or piece.kind == "tip" then Enum.Material.Wood
			else Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = piece.collide
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = piece.kind ~= "stone"
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if piece.label then
			boardText(part, Enum.NormalId.Front, piece.label)
			boardText(part, Enum.NormalId.Back, piece.label)
		end
		part.Parent = folder
	end
	folder.Parent = world
	tidyLabels(config, world)
	return folder
end

return Wayfinding
