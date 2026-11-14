-- Writes a Rojo-compatible sourcemap.json for luau-lsp from a built place, linking each script
-- to its file in src/. Usage: lune run tools/sourcemap.luau [built.rbxl] [sourcemap.json]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")

local input = process.args[1] or "build/WildFeastIslands.rbxl"
local output = process.args[2] or "sourcemap.json"
local game = roblox.deserializePlace(fs.readFile(input))
local SUFFIX = { ModuleScript = ".luau", Script = ".server.luau", LocalScript = ".client.luau" }

local function node(inst, dir)
	local n = { name = inst.Name, className = inst.ClassName }
	local suffix = SUFFIX[inst.ClassName]
	if suffix then
		n.filePaths = { dir .. suffix }
	end
	local children = {}
	for _, c in inst:GetChildren() do
		table.insert(children, node(c, dir .. "/" .. c.Name))
	end
	if #children > 0 then
		n.children = children
	end
	return n
end

local root = { name = "WildFeastIslands", className = "DataModel", children = {} }
for _, service in game:GetChildren() do
	table.insert(root.children, node(service, "src/" .. service.ClassName))
end
fs.writeFile(output, serde.encode("json", root, false))
print("wrote " .. output)
