-- Top-down SVG map of the built place, for reviewing world layout without Studio.
-- Every visible part is drawn as its footprint (the XZ outline of its oriented box), lowest
-- first, in its own colour. With --wayfinding the runtime Wayfinding pass is applied first, so
-- the paths, signposts and lanterns it adds show up too.
-- Usage: lune run tools/mapview.luau out.svg [--wayfinding] [minX maxX minZ maxZ]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Config = require("../src/ReplicatedStorage/Shared/Config")

local args = {}
local withWayfinding = false
for _, a in process.args do
	if a == "--wayfinding" then
		withWayfinding = true
	else
		table.insert(args, a)
	end
end
local out = args[1] or "build/map.svg"
local minX, maxX = tonumber(args[2]) or -80, tonumber(args[3]) or 80
local minZ, maxZ = tonumber(args[4]) or -80, tonumber(args[5]) or 70
local SCALE = 8 -- pixels per stud

local game = roblox.deserializePlace(fs.readFile("build/WildFeastIslands.rbxl"))
local world = game:GetService("Workspace"):FindFirstChild(Config.World.FolderName)

if withWayfinding then
	local path = "src/ServerScriptService/Server/World/Wayfinding.luau"
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
	luau.load(fs.readFile(path), { debugName = path, environment = env })().apply(Config, world)
end

local SKIP = { Sea = true, Seabed = true }
local parts = {}
for _, d in world:GetDescendants() do
	if d:IsA("BasePart") and not SKIP[d.Name] and d.Transparency < 0.95 then
		table.insert(parts, d)
	end
end
local spawn = world:FindFirstChild("MeadowSpawn")
if spawn then
	table.insert(parts, spawn)
end
-- Lowest tops first, so higher things (canopies, signs) draw over the ground.
local function top(p)
	local c = p.CFrame
	local h = math.abs(c.XVector.Y) * p.Size.X / 2 + math.abs(c.YVector.Y) * p.Size.Y / 2 + math.abs(c.ZVector.Y) * p.Size.Z / 2
	return c.Position.Y + h
end
table.sort(parts, function(a, b)
	return top(a) < top(b)
end)

-- Convex hull (monotone chain) of the 8 corners projected to XZ.
local function hull(points)
	table.sort(points, function(a, b)
		return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2])
	end)
	local function cross(o, a, b)
		return (a[1] - o[1]) * (b[2] - o[2]) - (a[2] - o[2]) * (b[1] - o[1])
	end
	local lower, upper = {}, {}
	for _, p in points do
		while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], p) <= 0 do
			table.remove(lower)
		end
		table.insert(lower, p)
	end
	for i = #points, 1, -1 do
		local p = points[i]
		while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], p) <= 0 do
			table.remove(upper)
		end
		table.insert(upper, p)
	end
	table.remove(lower)
	table.remove(upper)
	for _, p in upper do
		table.insert(lower, p)
	end
	return lower
end

local width = (maxX - minX) * SCALE
local height = (maxZ - minZ) * SCALE
local svg = {
	string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">', width, height, width, height),
	string.format('<rect width="%d" height="%d" fill="rgb(64,176,235)"/>', width, height),
}
local drawn = 0
for _, p in parts do
	local c, s = p.CFrame, p.Size
	local corners = {}
	local round = p:IsA("Part") and (p.Shape == roblox.Enum.PartType.Ball or p.Shape == roblox.Enum.PartType.Cylinder)
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local w = c * roblox.Vector3.new(sx * s.X / 2, sy * s.Y / 2, sz * s.Z / 2)
				table.insert(corners, { (w.X - minX) * SCALE, (w.Z - minZ) * SCALE })
			end
		end
	end
	local outline = hull(corners)
	local inside = false
	for _, q in outline do
		if q[1] >= 0 and q[1] <= width and q[2] >= 0 and q[2] <= height then
			inside = true
		end
	end
	if inside then
		local col = p.Color
		local fill = string.format("rgb(%d,%d,%d)", col.R * 255, col.G * 255, col.B * 255)
		local opacity = 1 - p.Transparency
		if round and p.Shape == roblox.Enum.PartType.Ball then
			local pos = c.Position
			table.insert(
				svg,
				string.format(
					'<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" fill-opacity="%.2f" stroke="rgba(0,0,0,0.25)" stroke-width="1"/>',
					(pos.X - minX) * SCALE,
					(pos.Z - minZ) * SCALE,
					math.max(s.X, s.Z) / 2 * SCALE,
					fill,
					opacity
				)
			)
		else
			local pts = {}
			for _, q in outline do
				table.insert(pts, string.format("%.1f,%.1f", q[1], q[2]))
			end
			table.insert(
				svg,
				string.format(
					'<polygon points="%s" fill="%s" fill-opacity="%.2f" stroke="rgba(0,0,0,0.25)" stroke-width="1"/>',
					table.concat(pts, " "),
					fill,
					opacity
				)
			)
		end
		drawn += 1
	end
end
-- A 10-stud scale bar and a north arrow (-Z is up the page... drawn as "-Z").
table.insert(svg, string.format('<rect x="16" y="%d" width="%d" height="6" fill="white" stroke="black"/>', height - 28, 10 * SCALE))
table.insert(
	svg,
	string.format(
		'<text x="16" y="%d" font-family="sans-serif" font-size="16" fill="white" stroke="black" stroke-width="0.4">10 studs   (top = -Z)</text>',
		height - 36
	)
)
table.insert(svg, "</svg>")
fs.writeFile(out, table.concat(svg, "\n"))
print(string.format("wrote %s: %d parts, %dx%d px", out, drawn, width, height))
