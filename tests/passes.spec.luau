-- Pass rules, the save schema for passes/cosmetics, and the pinned-food limit.
local Config = require("../src/ReplicatedStorage/Shared/Config")
local Passes = require("../src/ReplicatedStorage/Shared/Passes")
local Economy = require("../src/ReplicatedStorage/Shared/Economy")
local SaveSchema = require("../src/ReplicatedStorage/Shared/SaveSchema")

local function fresh()
	return SaveSchema.default(Config)
end

local function unlockFoods(profile, n)
	local ids = {}
	for _, id in ipairs(Config.AllFoodOrder) do
		if not Config.Foods[id].Free then
			profile.unlockedFoods[id] = true
			table.insert(ids, id)
			if #ids == n then
				break
			end
		end
	end
	return ids
end

return function(H)
	H.test("only positive integer pass IDs count as configured", function()
		for _, bad in { 0, -5, 1.5, 2 ^ 60, "123" } do
			H.check(not Passes.isConfigured({ PassId = bad }), "accepted " .. tostring(bad))
		end
		H.check(not Passes.isConfigured({}), "accepted a missing id")
		H.check(Passes.isConfigured({ PassId = 123456 }), "rejected a real-looking id")
		H.check(Passes.byPassId(Config, 0) == nil, "matched an unconfigured pass")
	end)

	H.test("every pass is fully described before purchase", function()
		for _, key in ipairs(Config.PassOrder) do
			local def = Config.Passes[key]
			H.check(def and def.Id == key, key .. " id mismatch")
			H.check(#def.Details >= 2, key .. " needs a full description")
			H.check(def.Companion == nil or Config.Companions[def.Companion], key .. " companion missing")
			for _, trail in ipairs(def.Trails or {}) do
				H.check(Config.Trails[trail], key .. " trail missing: " .. trail)
			end
		end
		local egg = Config.Passes.lantern_egg
		H.check(string.find(egg.Details[1], "no random outcome") ~= nil, "egg must say it is not random")
	end)

	H.test("the egg always hatches its companion, once, and only when owned", function()
		local p = fresh()
		local ok = Passes.tryHatch(Config, p, "lantern_egg")
		H.check(not ok, "hatched without owning")
		Passes.applyOwnership(Config, p, { lantern_egg = true })
		ok = Passes.tryHatch(Config, p, "lantern_egg")
		H.check(ok and p.cosmetics.hatched.lanternkit and p.cosmetics.companion == "lanternkit", "hatch result")
		H.check(not Passes.tryHatch(Config, p, "lantern_egg"), "hatched twice")
		H.check(Passes.trySetCompanion(Config, p, "none") and p.cosmetics.companion == nil, "hide")
		H.check(Passes.trySetCompanion(Config, p, "lanternkit") and p.cosmetics.companion == "lanternkit", "show")
	end)

	H.test("cosmetics need ownership, and losing a pass hides them", function()
		local p = fresh()
		H.check(not Passes.trySetTrail(Config, p, "ribbon"), "trail without the kit")
		H.check(not Passes.trySetCompanion(Config, p, "lanternkit"), "companion without the egg")
		Passes.applyOwnership(Config, p, { painters_kit = true, lantern_egg = true })
		Passes.tryHatch(Config, p, "lantern_egg")
		H.check(Passes.trySetTrail(Config, p, "petal") and p.cosmetics.trail == "petal", "trail with the kit")
		H.check(not Passes.trySetTrail(Config, p, "nope"), "unknown trail")
		-- A failed check (missing key) keeps the saved state...
		Passes.applyOwnership(Config, p, {})
		H.check(p.cosmetics.trail == "petal" and p.cosmetics.companion == "lanternkit", "kept on unknown result")
		-- ...a definite "not owned" removes what it unlocked, but keeps the hatch record.
		Passes.applyOwnership(Config, p, { painters_kit = false, lantern_egg = false })
		H.check(p.cosmetics.trail == nil and p.cosmetics.companion == nil, "cleared on not owned")
		H.check(p.cosmetics.hatched.lanternkit == true, "hatch record kept")
	end)

	H.test("Field Satchel raises the pin limit, and losing it trims pins", function()
		local p = fresh()
		local ids = unlockFoods(p, 6)
		for i = 1, 4 do
			H.check(Economy.tryTogglePin(Config, p, ids[i]), "pin " .. i)
		end
		H.check(not Economy.tryTogglePin(Config, p, ids[5]), "a fifth pin without the satchel")
		Passes.applyOwnership(Config, p, { field_satchel = true })
		H.check(Economy.tryTogglePin(Config, p, ids[5]) and Economy.tryTogglePin(Config, p, ids[6]), "pins 5 and 6")
		H.check(#p.pinned == 6, "six pinned")
		Passes.applyOwnership(Config, p, { field_satchel = false })
		H.check(#p.pinned == Config.FoodBar.MaxPinned, "trimmed back to the base limit")
	end)

	H.test("saves: v3 migrates, unknown pass data is dropped, extra pins survive until checked", function()
		local v3 = { schemaVersion = 3, coins = 10 }
		local migrated = SaveSchema.migrate(Config, v3)
		H.check(migrated and migrated.schemaVersion == Config.Data.SchemaVersion, "migrated")
		local p = SaveSchema.sanitize(Config, migrated)
		H.check(next(p.passes) == nil and next(p.cosmetics.hatched) == nil, "empty pass data")

		local data = SaveSchema.default(Config)
		local ids = unlockFoods(data, 6)
		data.pinned = ids
		data.passes = { field_satchel = true, made_up = true }
		data.cosmetics = { companion = "lanternkit", trail = "bogus", hatched = { lanternkit = false, other = true } }
		local clean = SaveSchema.sanitize(Config, data)
		H.check(clean.passes.field_satchel == true and clean.passes.made_up == nil, "pass keys filtered")
		H.check(clean.cosmetics.companion == nil, "companion that never hatched is dropped")
		H.check(clean.cosmetics.trail == nil and clean.cosmetics.hatched.other == nil, "bogus cosmetics dropped")
		H.check(#clean.pinned == 6, "pins kept up to the pass ceiling")
	end)
end
