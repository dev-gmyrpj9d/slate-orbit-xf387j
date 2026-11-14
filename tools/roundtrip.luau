-- Verifies that a built place keeps every instance of the original (by full path + class) and
-- reports what was added. Usage: lune run tools/roundtrip.luau <original.rbxl> <built.rbxl>
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local function index(file)
	local game = roblox.deserializePlace(fs.readFile(file))
	local seen = {}
	local function walk(inst, path)
		for _, c in inst:GetChildren() do
			local key = path .. "/" .. c.Name .. "<" .. c.ClassName .. ">"
			seen[key] = (seen[key] or 0) + 1
			walk(c, key)
		end
	end
	walk(game, "")
	return seen
end

local a, b = index(process.args[1]), index(process.args[2])
local missing, added = 0, 0
for k, n in a do
	if (b[k] or 0) < n then
		missing += 1
		print("MISSING", k)
	end
end
for k, n in b do
	if (a[k] or 0) < n then
		added += 1
		print("added", k)
	end
end
print(string.format("missing=%d added=%d", missing, added))
if missing > 0 then
	process.exit(1)
end
