-- Extracts every script in a place file into a Rojo-style source tree.
-- Usage: lune run tools/extract.luau <place.rbxl> <outDir>
--   ModuleScript -> Name.luau, Script -> Name.server.luau, LocalScript -> Name.client.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local src, out = process.args[1], process.args[2]
assert(src and out, "usage: extract.luau <place.rbxl> <outDir>")
local game = roblox.deserializePlace(fs.readFile(src))

local SUFFIX = { ModuleScript = ".luau", Script = ".server.luau", LocalScript = ".client.luau" }
local count = 0

local function walk(inst, dir)
	for _, child in inst:GetChildren() do
		local suffix = SUFFIX[child.ClassName]
		if suffix then
			fs.writeDir(dir)
			fs.writeFile(dir .. "/" .. child.Name .. suffix, child.Source)
			count += 1
		end
		walk(child, dir .. "/" .. child.Name)
	end
end

for _, service in game:GetChildren() do
	walk(service, out .. "/" .. service.ClassName)
end
print(string.format("extracted %d scripts into %s", count, out))
