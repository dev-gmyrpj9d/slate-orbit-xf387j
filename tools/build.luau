-- Builds the playable place: loads the untouched original, writes every script from src/ into
-- it (creating Folders/scripts that don't exist yet), applies the scene patch, and saves.
-- Usage: lune run tools/build.luau [original.rbxl] [out.rbxl]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local SRC = "src"
local input = process.args[1] or "place/WildFeastIslands.original.rbxl"
local output = process.args[2] or "build/WildFeastIslands.rbxl"

local game = roblox.deserializePlace(fs.readFile(input))
local Instance = roblox.Instance

local CLASS = { [".server.luau"] = "Script", [".client.luau"] = "LocalScript", [".luau"] = "ModuleScript" }
local written, created = 0, 0

local function classify(file: string): (string?, string?)
	for _, suffix in { ".server.luau", ".client.luau", ".luau" } do
		if string.sub(file, -#suffix) == suffix then
			return string.sub(file, 1, -#suffix - 1), CLASS[suffix]
		end
	end
	return nil, nil
end

local function sync(dir: string, parent)
	for _, entry in fs.readDir(dir) do
		local path = dir .. "/" .. entry
		if fs.isDir(path) then
			local folder = parent:FindFirstChild(entry)
			if not folder then
				folder = Instance.new("Folder")
				folder.Name = entry
				folder.Parent = parent
				created += 1
			end
			sync(path, folder)
		else
			local name, className = classify(entry)
			if name and className then
				local script = parent:FindFirstChild(name)
				if script and script.ClassName ~= className then
					error(string.format("%s exists as %s, source says %s", path, script.ClassName, className))
				end
				if not script then
					script = Instance.new(className)
					script.Name = name
					script.Parent = parent
					created += 1
				end
				script.Source = fs.readFile(path)
				written += 1
			end
		end
	end
end

for _, serviceName in fs.readDir(SRC) do
	sync(SRC .. "/" .. serviceName, game:GetService(serviceName))
end

local scene = require("./scene")
scene.apply(game, roblox)

fs.writeDir(string.match(output, "^(.*)/") or ".")
fs.writeFile(output, roblox.serializePlace(game))
print(string.format("built %s: %d scripts written, %d instances created", output, written, created))
