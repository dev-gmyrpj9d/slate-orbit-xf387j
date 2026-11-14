-- Every gameplay feature is free: no gamepass ownership checks, purchase prompts or receipt
-- handlers anywhere in the game scripts. Fails if one is (re)introduced without review.
local fs = require("@lune/fs")

local PATTERNS = {
	"MarketplaceService",
	"UserOwnsGamePass",
	"PromptGamePassPurchase",
	"PromptProductPurchase",
	"PromptPurchase",
	"ProcessReceipt",
	"GamePass",
	"[Gg]amepass",
}

local function scan(dir, hits)
	for _, entry in fs.readDir(dir) do
		local path = dir .. "/" .. entry
		if fs.isDir(path) then
			scan(path, hits)
		elseif string.match(entry, "%.luau$") then
			local source = fs.readFile(path)
			for _, pattern in PATTERNS do
				if string.find(source, pattern) then
					table.insert(hits, path .. ": " .. pattern)
				end
			end
		end
	end
	return hits
end

return function(H)
	H.test("no gamepass gates or purchase prompts in src/", function()
		local hits = scan("src", {})
		H.check(#hits == 0, "found monetization hooks:\n" .. table.concat(hits, "\n"))
	end)
end
