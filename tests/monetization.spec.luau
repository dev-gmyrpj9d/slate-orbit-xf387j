-- Where marketplace code may live, and what passes may touch. The free game must stay whole:
-- passes never gate gameplay, never change coins/research/trust/catches, and there is no paid
-- randomness and no developer product (repeatable purchase) anywhere.
local fs = require("@lune/fs")

local PASS_SERVICE = "src/ServerScriptService/Server/Services/PassService.luau"
local SHOP_CLIENT = "src/StarterPlayer/StarterPlayerScripts/Client/Controllers/Shop.luau"
local PASSES = "src/ReplicatedStorage/Shared/Passes.luau"

local function sources(dir, out)
	for _, entry in fs.readDir(dir) do
		local path = dir .. "/" .. entry
		if fs.isDir(path) then
			sources(path, out)
		elseif string.match(entry, "%.luau$") then
			out[path] = fs.readFile(path)
		end
	end
	return out
end

local function hits(all, pattern, allowed)
	local found = {}
	for path, source in pairs(all) do
		if not allowed[path] and string.find(source, pattern) then
			table.insert(found, path)
		end
	end
	table.sort(found)
	return found
end

return function(H)
	local all = sources("src", {})

	H.test("MarketplaceService is used only by PassService (server) and Shop (client prices)", function()
		local found = hits(all, "MarketplaceService", { [PASS_SERVICE] = true, [SHOP_CLIENT] = true })
		H.check(#found == 0, "unexpected MarketplaceService use:\n" .. table.concat(found, "\n"))
	end)

	H.test("only the server prompts purchases and checks ownership", function()
		for _, pattern in { "PromptGamePassPurchase", "UserOwnsGamePassAsync" } do
			local found = hits(all, pattern, { [PASS_SERVICE] = true })
			H.check(#found == 0, pattern .. " outside PassService:\n" .. table.concat(found, "\n"))
		end
		local shop = all[SHOP_CLIENT]
		H.check(string.find(shop, "GetProductInfoAsync") ~= nil, "Shop reads live prices")
	end)

	H.test("no developer products, receipts or other purchase prompts", function()
		for _, pattern in { "ProcessReceipt", "PromptProductPurchase", "PromptPurchase%(", "PromptBundlePurchase", "PromptSubscription" } do
			local found = hits(all, pattern, {})
			H.check(#found == 0, pattern .. " found:\n" .. table.concat(found, "\n"))
		end
	end)

	H.test("pass ownership is read only through the Passes rules", function()
		local found = hits(all, "%.passes", {
			[PASSES] = true,
			["src/ReplicatedStorage/Shared/SaveSchema.luau"] = true,
		})
		H.check(#found == 0, "profile.passes read outside Passes/SaveSchema:\n" .. table.concat(found, "\n"))
	end)

	H.test("pass rules never touch currencies, trust or catches, and use no randomness", function()
		local source = all[PASSES]
		for _, pattern in { "coins", "research", "trust", "catch", "[Rr]andom", "Rng" } do
			H.check(string.find(source, pattern) == nil, "Passes.luau mentions " .. pattern)
		end
	end)
end
