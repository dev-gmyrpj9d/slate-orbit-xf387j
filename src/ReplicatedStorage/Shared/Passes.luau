--!strict
-- Pure rules for optional passes and the cosmetics they unlock. No Roblox APIs, so the server,
-- the client and the offline tests share them.
--
-- `profile.passes` holds the passes the server has confirmed with Roblox (it is also the saved
-- fallback for when the ownership check is unavailable at join). Only PassService writes it.
-- `profile.cosmetics` holds what the player chose to show; every setter checks ownership.

local Passes = {}

-- A pass can be prompted only once a real, positive integer pass ID has been configured.
function Passes.isConfigured(def: any): boolean
	local id = def and def.PassId
	return type(id) == "number" and id > 0 and id == math.floor(id) and id < 2 ^ 53
end

function Passes.owns(profile: any, passKey: string): boolean
	return profile.passes ~= nil and profile.passes[passKey] == true
end

-- Finds the pass definition for a numeric Roblox pass ID (nil for unknown or unconfigured IDs).
function Passes.byPassId(config: any, passId: any): any
	if type(passId) ~= "number" then
		return nil
	end
	for _, key in ipairs(config.PassOrder) do
		local def = config.Passes[key]
		if Passes.isConfigured(def) and def.PassId == passId then
			return def
		end
	end
	return nil
end

function Passes.maxPinned(config: any, profile: any): number
	local max = config.FoodBar.MaxPinned
	for _, key in ipairs(config.PassOrder) do
		local def = config.Passes[key]
		if def.ExtraPins and Passes.owns(profile, key) then
			max += def.ExtraPins
		end
	end
	return max
end

-- The most pins any profile could ever have (used when sanitising saves before ownership is known).
function Passes.pinCeiling(config: any): number
	local max = config.FoodBar.MaxPinned
	for _, key in ipairs(config.PassOrder) do
		max += config.Passes[key].ExtraPins or 0
	end
	return max
end

local function eggFor(config: any, companionId: string): string?
	for _, key in ipairs(config.PassOrder) do
		if config.Passes[key].Companion == companionId then
			return key
		end
	end
	return nil
end

function Passes.companionUnlocked(config: any, profile: any, companionId: string): boolean
	local egg = eggFor(config, companionId)
	return egg ~= nil and Passes.owns(profile, egg) and profile.cosmetics.hatched[companionId] == true
end

function Passes.trailUnlocked(config: any, profile: any, trailId: string): boolean
	for _, key in ipairs(config.PassOrder) do
		local trails = config.Passes[key].Trails
		if trails and table.find(trails, trailId) and Passes.owns(profile, key) then
			return true
		end
	end
	return false
end

-- Hatching is deterministic: the egg always yields its configured companion, which is then shown.
function Passes.tryHatch(config: any, profile: any, passKey: string): (boolean, string)
	local def = config.Passes[passKey]
	if not def or not def.Companion then
		return false, "That isn't an egg."
	end
	if not Passes.owns(profile, passKey) then
		return false, "You don't own the " .. def.Name .. "."
	end
	local companion = config.Companions[def.Companion]
	if profile.cosmetics.hatched[def.Companion] then
		return false, "Your " .. companion.Name .. " has already hatched."
	end
	profile.cosmetics.hatched[def.Companion] = true
	profile.cosmetics.companion = def.Companion
	return true, "Your " .. companion.Name .. " hatched. It will follow you now."
end

-- `id` "none" hides the current companion.
function Passes.trySetCompanion(config: any, profile: any, id: string): (boolean, string?)
	if id == "none" then
		profile.cosmetics.companion = nil
		return true, nil
	end
	if not config.Companions[id] or not Passes.companionUnlocked(config, profile, id) then
		return false, "Hatch that companion first."
	end
	profile.cosmetics.companion = id
	return true, nil
end

-- `id` "none" goes back to the plain trail.
function Passes.trySetTrail(config: any, profile: any, id: string): (boolean, string?)
	if id == "none" then
		profile.cosmetics.trail = nil
		return true, nil
	end
	if not config.Trails[id] or not Passes.trailUnlocked(config, profile, id) then
		return false, "That trail comes with the Painter's Kit."
	end
	profile.cosmetics.trail = id
	return true, nil
end

-- Applies a fresh ownership result. `owned` maps pass key -> true/false; keys missing from it
-- (the check failed) keep their saved value. Anything the profile can no longer use is removed:
-- shown cosmetics and pins over the limit. Hatch records stay, so a restored pass restores them.
function Passes.applyOwnership(config: any, profile: any, owned: { [string]: boolean })
	for _, key in ipairs(config.PassOrder) do
		local result = owned[key]
		if result == true then
			profile.passes[key] = true
		elseif result == false then
			profile.passes[key] = nil
		end
	end
	local cosmetics = profile.cosmetics
	if cosmetics.companion and not Passes.companionUnlocked(config, profile, cosmetics.companion) then
		cosmetics.companion = nil
	end
	if cosmetics.trail and not Passes.trailUnlocked(config, profile, cosmetics.trail) then
		cosmetics.trail = nil
	end
	local max = Passes.maxPinned(config, profile)
	while #profile.pinned > max do
		table.remove(profile.pinned)
	end
end

return Passes
