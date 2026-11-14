--!strict
-- Draws every nearby player's companion (the server publishes the shown companion as the
-- player's "Companion" attribute after checking ownership). Each one trots after its owner,
-- settles beside them when they stop, turns to watch them, and hops when they feed an animal.
-- Purely local and cosmetic; bounded by Config.Shop distance and count limits.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CompanionModel = require(ReplicatedStorage.Shared.CompanionModel)
local Store = require(script.Parent.Store)

local Companions = {}

type Entry = {
	id: string,
	rig: CompanionModel.Rig,
	pos: Vector3,
	yaw: number,
	groundY: number,
	nextRay: number,
	perk: number,
	light: PointLight,
}

local entries: { [Player]: Entry } = {}
local folder: Folder
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false

local FOLLOW_OFFSET = Vector3.new(2.6, 0, 2.2) -- beside and a little behind the owner
local CATCH_UP = 6 -- studs; further than this it trots, closer it strolls
local TELEPORT = 60 -- studs; further than this (respawn, teleport) it simply reappears

local function destroy(player: Player)
	local entry = entries[player]
	if entry then
		entry.rig.model:Destroy()
		entries[player] = nil
	end
end

local function create(player: Player, id: string, at: Vector3): Entry?
	local def = Config.Companions[id]
	if not def then
		return nil
	end
	local rig = CompanionModel.build(def)
	rig.model.Name = "Companion_" .. player.UserId
	local light = Instance.new("PointLight")
	light.Color = rig.lantern.Color
	light.Range = 7
	light.Brightness = 0.6
	light.Shadows = false
	light.Parent = rig.lantern
	rig.model.Parent = folder
	return { id = id, rig = rig, pos = at, yaw = 0, groundY = at.Y, nextRay = 0, perk = 0, light = light }
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	local reduced = Store.setting("reducedEffects") == true
	local drawn = 0
	-- Nearest first so the cap keeps the companions you can actually see.
	local candidates = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local id = player:GetAttribute("Companion")
		local hrp = rootOf(player)
		if type(id) == "string" and hrp then
			local distance = (hrp.Position - camera.CFrame.Position).Magnitude
			if distance <= Config.Shop.CompanionRenderDistance then
				table.insert(candidates, { player = player, id = id, hrp = hrp, distance = distance })
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)
	local keep: { [Player]: boolean } = {}
	for _, c in ipairs(candidates) do
		if drawn >= Config.Shop.MaxCompanionsDrawn then
			break
		end
		drawn += 1
		keep[c.player] = true
		local hrp: BasePart = c.hrp
		local existing = entries[c.player]
		if existing and existing.id ~= c.id then
			destroy(c.player) -- switched companion: rebuild
		end
		local target = (hrp.CFrame * CFrame.new(FOLLOW_OFFSET)).Position
		local entry: Entry? = entries[c.player] or create(c.player, c.id, target)
		if not entry then
			continue
		end
		local e: Entry = entry
		entries[c.player] = e
		local flat = Vector3.new(target.X - e.pos.X, 0, target.Z - e.pos.Z)
		local gap = flat.Magnitude
		if gap > TELEPORT then
			e.pos = target
			gap = 0
		end
		local speed = 0
		if gap > 0.4 then
			local pace = if gap > CATCH_UP then 22 else 9
			local move = math.min(gap, pace * dt)
			e.pos += flat.Unit * move
			speed = math.clamp(move / math.max(dt, 1e-3) / 16, 0, 1)
			local wantYaw = math.atan2(-flat.X, -flat.Z)
			e.yaw += (math.atan2(math.sin(wantYaw - e.yaw), math.cos(wantYaw - e.yaw))) * math.min(1, dt * 10)
		end
		-- Find the ground under it a few times a second (characters and companions excluded).
		if now >= e.nextRay then
			e.nextRay = now + 0.2
			rayParams.FilterDescendantsInstances = { folder, c.player.Character :: Instance }
			local hit = workspace:Raycast(e.pos + Vector3.new(0, 8, 0), Vector3.new(0, -30, 0), rayParams)
			e.groundY = if hit then hit.Position.Y else hrp.Position.Y - 3
		end
		local y = e.pos.Y + (e.groundY - e.pos.Y) * math.min(1, dt * 12)
		e.pos = Vector3.new(e.pos.X, y, e.pos.Z)
		-- The head turns toward the owner.
		local toOwner = hrp.Position - e.pos
		local lookYaw = math.atan2(-toOwner.X, -toOwner.Z) - e.yaw
		lookYaw = math.atan2(math.sin(lookYaw), math.cos(lookYaw))
		e.perk = math.max(0, e.perk - dt * 1.8)
		-- `perk` counts down 1 -> 0; the hop runs over that window and is flat outside it.
		local bob = CompanionModel.pose(e.rig, now, speed, if e.perk > 0 then 1 - e.perk else 0, lookYaw)
		e.rig.root.CFrame = CFrame.new(e.pos + Vector3.new(0, e.rig.halfHeight + bob, 0)) * CFrame.Angles(0, e.yaw, 0)
		e.light.Enabled = not reduced
	end
	for player in pairs(entries) do
		if not keep[player] then
			destroy(player)
		end
	end
end

function Companions.init()
	folder = Instance.new("Folder")
	folder.Name = "WildFeastCompanions"
	folder.Parent = workspace
	Players.PlayerRemoving:Connect(destroy)
	-- A short hop when the owner's food is accepted.
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FeedFx") :: RemoteEvent
	remote.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and payload.t == "fed" and payload.accepted == true then
			for player, entry in pairs(entries) do
				if player.UserId == payload.owner then
					entry.perk = 1
				end
			end
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return Companions
