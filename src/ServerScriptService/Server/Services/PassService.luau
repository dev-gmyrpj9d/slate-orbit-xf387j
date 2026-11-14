--!strict
-- Optional passes, server-authoritative (Creator Docs: "Passes" and MarketplaceService).
--
-- * Ownership is confirmed with UserOwnsGamePassAsync when a profile loads (bounded retries) and
--   again after PromptGamePassPurchaseFinished. The confirmed result is saved with the profile,
--   which is only a fallback for when Roblox can't be reached at join.
-- * The client can only *ask* for a prompt; the server checks the pass is configured and not
--   owned, then prompts. Unconfigured passes (PassId 0) are never prompted, so nothing can be
--   bought until real IDs are entered in Config.Passes.
-- * The shown companion and trail are published as player attributes so every client can draw
--   them; only ownership-checked values are ever written.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Guard = require(ReplicatedStorage.Shared.Guard)
local Passes = require(ReplicatedStorage.Shared.Passes)

type Deps = {
	getProfile: (Player) -> any,
	markDirty: (Player) -> (),
	notify: (Player, string, string?) -> (),
	onLoaded: ((Player) -> ()) -> (),
}

local PassService = {}

local deps: Deps
local checking: { [Player]: boolean } = {}
-- Passes bought this session. A join-time check that was already running when the purchase
-- finished may still say "not owned"; it must not take the pass back.
local boughtNow: { [Player]: { [string]: boolean } } = {}
-- Last prompt per player and pass, so a held button can't stack prompts.
local promptedAt: { [Player]: { [string]: number } } = {}
local PROMPT_COOLDOWN = 3

-- Returns true/false, or nil if Roblox couldn't answer after the allowed retries.
local function ownsWithRoblox(player: Player, passId: number): boolean?
	for attempt = 1, Config.Shop.OwnershipRetries do
		local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
		if ok and type(result) == "boolean" then
			return result
		end
		warn(string.format("[WildFeast] Pass check %d failed for %d/%d: %s", attempt, player.UserId, passId, tostring(result)))
		if attempt < Config.Shop.OwnershipRetries then
			task.wait(attempt * 1.5)
		end
		if player.Parent ~= Players then
			return nil
		end
	end
	return nil
end

-- Publishes the shown cosmetics (or clears them) for every client to draw.
function PassService.publish(player: Player)
	local profile = deps.getProfile(player)
	local cosmetics = profile and profile.cosmetics
	player:SetAttribute("Companion", cosmetics and cosmetics.companion or nil)
	player:SetAttribute("Trail", cosmetics and cosmetics.trail or nil)
end

local function refreshOwnership(player: Player)
	if checking[player] then
		return
	end
	checking[player] = true
	local owned: { [string]: boolean } = {}
	for _, key in ipairs(Config.PassOrder) do
		local def = Config.Passes[key]
		if Passes.isConfigured(def) then
			local result = ownsWithRoblox(player, def.PassId)
			if result ~= nil then
				owned[key] = result
			end
		else
			-- An unconfigured pass can't be owned: a stale saved flag (e.g. from a test ID that
			-- was later removed) must not keep granting it.
			owned[key] = false
		end
	end
	checking[player] = nil
	local profile = deps.getProfile(player)
	if not profile or player.Parent ~= Players then
		return
	end
	for key in pairs(boughtNow[player] or {}) do
		owned[key] = true
	end
	Passes.applyOwnership(Config, profile, owned)
	PassService.publish(player)
	deps.markDirty(player)
end

local function grant(player: Player, def: any)
	local profile = deps.getProfile(player)
	if not profile then
		return
	end
	boughtNow[player] = boughtNow[player] or {}
	boughtNow[player][def.Id] = true
	Passes.applyOwnership(Config, profile, { [def.Id] = true })
	PassService.publish(player)
	deps.markDirty(player)
	local next = if def.Companion then " Open the Shop to hatch it." else " It's ready in the Shop."
	deps.notify(player, "Thanks for supporting the islands. " .. def.Name .. " added." .. next, "success")
end

-- Handles a client's request to open the purchase prompt for `passKey`.
function PassService.requestPurchase(player: Player, passKey: string): (boolean, string?)
	local def = Config.Passes[passKey]
	if not def then
		return false, nil
	end
	if not Passes.isConfigured(def) then
		return false, def.Name .. " isn't on sale yet."
	end
	local profile = deps.getProfile(player)
	if profile and Passes.owns(profile, passKey) then
		return false, "You already own " .. def.Name .. "."
	end
	local times = promptedAt[player] or {}
	promptedAt[player] = times
	local now = os.clock()
	if times[passKey] and now - times[passKey] < PROMPT_COOLDOWN then
		return false, nil
	end
	times[passKey] = now
	local ok, err = pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, def.PassId)
	if not ok then
		warn("[WildFeast] PromptGamePassPurchase failed: " .. tostring(err))
		return false, "The store couldn't open. Try again in a moment."
	end
	return true, nil
end

function PassService.init(dependencies: Deps)
	deps = dependencies
	deps.onLoaded(function(player)
		PassService.publish(player) -- saved choices show at once; the check below confirms them
		task.spawn(Guard.run, "Pass ownership", refreshOwnership, player)
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if not wasPurchased then
			return
		end
		local def = Passes.byPassId(Config, passId)
		if def then
			-- Engine-fired (not client-sent). Ownership is checked again at the next join.
			Guard.run("Pass grant", grant, player, def)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		checking[player] = nil
		promptedAt[player] = nil
		boughtNow[player] = nil
	end)
end

return PassService
