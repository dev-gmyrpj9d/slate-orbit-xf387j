-- Sound: every engine sound path in src/ must be a file the client actually ships.
local fs = require("@lune/fs")
local EngineSounds = require("../src/ReplicatedStorage/Shared/EngineSounds")

local function walk(dir, out)
	for _, entry in fs.readDir(dir) do
		local path = dir .. "/" .. entry
		if fs.isDir(path) then
			walk(path, out)
		elseif string.sub(entry, -5) == ".luau" then
			table.insert(out, path)
		end
	end
	return out
end

return function(H)
	H.test("sound: only engine files the client ships (no guessed or retired paths)", function()
		local found = 0
		for _, path in walk("src", {}) do
			local source = fs.readFile(path)
			for id in string.gmatch(source, "rbxasset://sounds/[%w_%.%-]+") do
				found += 1
				H.check(EngineSounds.isShipped(id), path .. " uses " .. id .. ", which the client doesn't ship")
			end
			H.check(not string.find(source, "rbxassetid://", 1, true), path .. " references an uploaded asset ID")
		end
		local effects = fs.readFile("src/StarterPlayer/StarterPlayerScripts/Client/Controllers/Effects.luau")
		H.check(string.find(effects, "EngineSounds.Path", 1, true), "Effects takes its sounds from EngineSounds")
		H.check(found == 0, "sound paths live only in EngineSounds (found " .. found .. " literals elsewhere)")
		for role, id in EngineSounds.Path do
			H.check(EngineSounds.isShipped(id), role .. " -> " .. id)
		end
		H.check(not EngineSounds.isShipped("rbxasset://sounds/swoosh.wav"), "retired file is rejected")
	end)
end
