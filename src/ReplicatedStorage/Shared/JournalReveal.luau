--!strict
-- Rules for discovery moments: which animals were just spotted, their journal entry number,
-- how many animals of an island are noted, and which island a position is on. Pure Luau (no
-- Roblox APIs) so the offline tests can load it; Client/Controllers/Discovery draws the card.

local JournalReveal = {}

-- Spotted animals in `after` that were not in `before`, in journal order.
function JournalReveal.newlySeen(config: any, before: { [string]: boolean }?, after: { [string]: boolean }?): { string }
	local list = {}
	if not before or not after then
		return list -- first snapshot of a session: nothing is "new" yet
	end
	for _, id in ipairs(config.AllSpeciesOrder) do
		if after[id] and not before[id] then
			table.insert(list, id)
		end
	end
	return list
end

-- 1-based journal page for a species ("No. 12").
function JournalReveal.entryNumber(config: any, speciesId: string): number?
	return table.find(config.AllSpeciesOrder, speciesId)
end

-- Same "seen" rule as the Journal tab: spotted, or fed at least once.
function JournalReveal.isNoted(profile: any, speciesId: string): boolean
	return (profile.seenSpecies and profile.seenSpecies[speciesId]) == true or ((profile.fedCount and profile.fedCount[speciesId]) or 0) > 0
end

function JournalReveal.habitatTally(config: any, profile: any, habitatId: string): (number, number)
	local noted, total = 0, 0
	for _, id in ipairs(config.AllSpeciesOrder) do
		if config.Species[id].Habitat == habitatId then
			total += 1
			if JournalReveal.isNoted(profile, id) then
				noted += 1
			end
		end
	end
	return noted, total
end

-- Island under (x, z), using its grass radius; nil over the sea or on a bridge.
function JournalReveal.habitatAt(config: any, x: number, z: number): string?
	for _, id in ipairs(config.HabitatOrder) do
		local h = config.Habitats[id]
		local dx, dz = x - h.Center[1], z - h.Center[2]
		if dx * dx + dz * dz <= (h.Radius * config.Animal.GrassApothem) ^ 2 then
			return id
		end
	end
	return nil
end

-- The name as it is written into the journal: letters appear left to right over `progress`
-- 0..1; letters not written yet show as a light dot so the name's length reads at once.
function JournalReveal.writing(name: string, progress: number): string
	local letters = {}
	for _, code in utf8.codes(name) do
		table.insert(letters, utf8.char(code))
	end
	local shown = math.clamp(math.floor(progress * #letters + 0.5), 0, #letters)
	local out = {}
	for i, letter in ipairs(letters) do
		out[i] = if i <= shown or letter == " " then letter else "·"
	end
	return table.concat(out)
end

-- The one-line banner when arriving on an island.
function JournalReveal.arrival(config: any, profile: any, habitatId: string): (string, string)
	local habitat = config.Habitats[habitatId]
	local noted, total = JournalReveal.habitatTally(config, profile, habitatId)
	local detail = if noted >= total
		then string.format("All %d animals noted", total)
		else string.format("%d of %d animals noted", noted, total)
	return habitat.Name, detail
end

return JournalReveal
