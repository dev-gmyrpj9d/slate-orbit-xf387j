-- Side-profile SVG of procedural animals (camera on +X looking at the left flank, nose left),
-- for reviewing model silhouettes without Studio. Parts are drawn far side first.
-- Usage: lune run tools/profileview.luau out.svg [factory.luau motion.luau] speciesId...
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Config = require("../src/ReplicatedStorage/Shared/Config")

local args = table.clone(process.args)
local out = table.remove(args, 1) or "build/profiles.svg"
local factoryPath = "src/ServerScriptService/Server/World/AnimalFactory.luau"
local motionPath = "src/ReplicatedStorage/Shared/AnimalMotion.luau"
if args[1] and string.sub(args[1], -5) == ".luau" then
	factoryPath = table.remove(args, 1)
	motionPath = table.remove(args, 1)
end

local motion = luau.load(fs.readFile(motionPath), { debugName = motionPath })()
local SHARED = {}
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
		return motion
	end,
}
local Factory = luau.load(fs.readFile(factoryPath), { debugName = factoryPath, environment = env })()

local SCALE, CELL = 34, 280
local svg = {}
for index, id in args do
	local built = Factory.build(Config.Species[id], "view")
	local parts = {}
	for _, p in built.model:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(parts, p)
		end
	end
	-- Painter's order for a camera on +X: whichever part reaches furthest toward the camera
	-- draws last (centres alone mis-order concentric parts such as a shell and its spiral).
	local function near(p)
		if p.Shape == roblox.Enum.PartType.Ball then
			return p.CFrame.Position.X + math.min(p.Size.X, p.Size.Y, p.Size.Z) / 2
		end
		local c, s = p.CFrame, p.Size
		return c.Position.X + math.abs(c.XVector.X) * s.X / 2 + math.abs(c.YVector.X) * s.Y / 2 + math.abs(c.ZVector.X) * s.Z / 2
	end
	table.sort(parts, function(a, b)
		return near(a) < near(b)
	end)
	local ox, oy = (index - 1) * CELL + CELL / 2, CELL * 0.62
	table.insert(
		svg,
		string.format(
			'<rect x="%d" y="0" width="%d" height="%d" fill="rgb(244,237,224)" stroke="rgb(196,186,168)"/>',
			(index - 1) * CELL,
			CELL,
			CELL
		)
	)
	for _, p in parts do
		local c, s = p.CFrame, p.Size
		local col = p.Color
		local fill = string.format("rgb(%d,%d,%d)", col.R * 255, col.G * 255, col.B * 255)
		local endOn = p.Shape == roblox.Enum.PartType.Cylinder and math.abs(c.XVector.X) > 0.99
		if endOn then
			table.insert(
				svg,
				string.format(
					'<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="rgba(0,0,0,0.35)"/>',
					ox + c.Position.Z * SCALE,
					oy - c.Position.Y * SCALE,
					math.min(s.Y, s.Z) / 2 * SCALE,
					fill
				)
			)
		elseif p.Shape == roblox.Enum.PartType.Ball then
			-- Balls are spheres (Size is uniform in Roblox; use the smallest axis).
			local r = math.min(s.X, s.Y, s.Z) / 2
			table.insert(
				svg,
				string.format(
					'<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="rgba(0,0,0,0.35)"/>',
					ox + c.Position.Z * SCALE,
					oy - c.Position.Y * SCALE,
					r * SCALE,
					fill
				)
			)
		else
			local pts = {}
			-- Project the 8 corners onto (Z, Y) and draw their outline (convex hull).
			local corners = {}
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local w = c * roblox.Vector3.new(sx * s.X / 2, sy * s.Y / 2, sz * s.Z / 2)
						table.insert(corners, { ox + w.Z * SCALE, oy - w.Y * SCALE })
					end
				end
			end
			table.sort(corners, function(a, b)
				return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2])
			end)
			local function cross(o, a, b)
				return (a[1] - o[1]) * (b[2] - o[2]) - (a[2] - o[2]) * (b[1] - o[1])
			end
			local lower, upper = {}, {}
			for _, q in corners do
				while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], q) <= 0 do
					table.remove(lower)
				end
				table.insert(lower, q)
			end
			for i = #corners, 1, -1 do
				local q = corners[i]
				while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], q) <= 0 do
					table.remove(upper)
				end
				table.insert(upper, q)
			end
			table.remove(lower)
			table.remove(upper)
			for _, q in upper do
				table.insert(lower, q)
			end
			for _, q in lower do
				table.insert(pts, string.format("%.1f,%.1f", q[1], q[2]))
			end
			table.insert(svg, string.format('<polygon points="%s" fill="%s" stroke="rgba(0,0,0,0.35)"/>', table.concat(pts, " "), fill))
		end
	end
	table.insert(
		svg,
		string.format(
			'<text x="%d" y="%d" font-family="sans-serif" font-size="18" fill="rgb(40,36,32)">%s</text>',
			(index - 1) * CELL + 12,
			CELL - 14,
			Config.Species[id].Name
		)
	)
end
local width = #args * CELL
table.insert(svg, 1, string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d">', width, CELL))
table.insert(svg, "</svg>")
fs.writeFile(out, table.concat(svg, "\n"))
print("wrote " .. out)
