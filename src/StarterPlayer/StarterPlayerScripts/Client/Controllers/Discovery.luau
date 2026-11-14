--!strict
-- Discovery moments, styled as a field-notes journal plate (docs/ART_DIRECTION.md):
--   * Spotting a new animal or finding a favourite food shows a small card in the right-hand
--     column: entry number, the animal in side profile (first as an ink silhouette, then in
--     colour), its name written in letter by letter, and one line about what was learned.
--     It doesn't block play; it closes on its own, or when clicked or tapped.
--   * Arriving on an island shows its name and how many of its animals are noted, briefly.
-- Reduced effects: no silhouette fade, no letter-by-letter writing, no banner fade.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local JournalReveal = require(ReplicatedStorage.Shared.JournalReveal)
local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)
local Effects = require(script.Parent.Effects)
local Hud = require(script.Parent.Hud)

local C = Ui.Colors
local Discovery = {}

local CARD_SECONDS = 5.5
local SILHOUETTE_SECONDS = 0.35 -- ink only, before the colour comes in
local COLOUR_SECONDS = 0.45
local WRITE_SECONDS = 0.5
local ARRIVAL_SECONDS = 2.8
local ARRIVAL_REPEAT = 90 -- seconds before the same island's banner can show again
local MAX_QUEUE = 4

type Card = { speciesId: string, kicker: string, detail: string }

local queue: { Card } = {}
local showing = false
local holder: Frame
local banner: TextLabel
local lastSeen: { [string]: boolean }? = nil

local function reduced(): boolean
	return Store.setting("reducedEffects") == true
end

local function enqueue(card: Card)
	for _, queued in ipairs(queue) do
		if queued.speciesId == card.speciesId and queued.kicker == card.kicker then
			return
		end
	end
	if #queue < MAX_QUEUE then
		table.insert(queue, card)
	end
end

-- A side-profile copy of a live animal of this species, if one is nearby to copy from.
local function preview(speciesId: string, parent: Instance): { BasePart }?
	local animals = workspace:FindFirstChild("WildFeastAnimals")
	local source: Model? = nil
	if animals then
		for _, child in ipairs(animals:GetChildren()) do
			if child:IsA("Model") and child:GetAttribute("Species") == speciesId then
				source = child
				break
			end
		end
	end
	if not source then
		return nil
	end
	local wasArchivable = source.Archivable
	source.Archivable = true
	local copy = source:Clone()
	source.Archivable = wasArchivable
	if not copy then
		return nil
	end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BillboardGui") or d:IsA("Light") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	local viewport = Ui.new("ViewportFrame", {
		Size = UDim2.fromOffset(128, 96),
		BackgroundColor3 = C.Panel,
		Ambient = Color3.fromRGB(170, 160, 150),
		LightColor = Color3.fromRGB(255, 244, 228),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
		LayoutOrder = 2,
		Parent = parent,
	}, { Ui.corner(6), Ui.stroke(C.Rule, 1) })
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	copy:PivotTo(CFrame.new())
	copy.Parent = world
	local size = copy:GetExtentsSize()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	-- Side profile, like a naturalist's plate: the animal faces -Z, the camera looks from +X.
	local distance = math.max(size.X, size.Y, size.Z) * 2.4 + 2
	camera.CFrame = CFrame.lookAt(Vector3.new(distance, size.Y * 0.35, -distance * 0.18), Vector3.new(0, 0, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local parts = {}
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	return parts
end

local function showNext()
	if showing or #queue == 0 or Hud.panelOpen() then
		return
	end
	local card = table.remove(queue, 1) :: Card
	local species = Config.Species[card.speciesId]
	if not species then
		return
	end
	showing = true
	local quick = reduced()

	local frame = Ui.new("TextButton", {
		Name = "Plate",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.Card,
		AutoButtonColor = false,
		Selectable = false,
		Text = "",
		Parent = holder,
	}, { Ui.corner(8), Ui.padding(10), Ui.stroke(C.Rule, 1), Ui.list(Enum.FillDirection.Vertical, 4) })

	local top = Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = 1, Parent = frame })
	local number = JournalReveal.entryNumber(Config, card.speciesId)
	Ui.label({
		Text = if number then string.format("No. %d", number) else "Journal",
		TextSize = 14,
		FontFace = Ui.BoldFont,
		TextColor3 = C.Muted,
		Parent = top,
	})
	Ui.label({
		Text = card.kicker,
		TextSize = 14,
		FontFace = Ui.BoldFont,
		TextColor3 = C.Accent,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = top,
	})
	local parts = preview(card.speciesId, frame)
	local name = Ui.label({
		Text = if quick then species.Name else JournalReveal.writing(species.Name, 0),
		TextSize = 26,
		FontFace = Ui.TitleFont,
		LayoutOrder = 3,
		Parent = frame,
	})
	Ui.label({ Text = card.detail, TextSize = 16, TextColor3 = C.Muted, TextWrapped = true, LayoutOrder = 4, Parent = frame })
	Ui.label({
		Text = if Store.inputMode == "keyboard" then "Journal: J" else "Open the Journal from the menu",
		TextSize = 13,
		TextColor3 = C.Muted,
		LayoutOrder = 5,
		Parent = frame,
	})

	local originals: { [BasePart]: Color3 } = {}
	if parts and not quick then
		for _, part in ipairs(parts) do
			originals[part] = part.Color
			part.Color = C.Ink
		end
	end
	Effects.play("chime")

	local started = os.clock()
	local closed = false
	local connection: RBXScriptConnection
	local function close()
		if closed then
			return
		end
		closed = true
		connection:Disconnect()
		frame:Destroy()
		showing = false
		task.delay(0.25, showNext)
	end
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t > CARD_SECONDS or not frame.Parent then
			close()
			return
		end
		if not quick then
			name.Text = JournalReveal.writing(species.Name, t / WRITE_SECONDS)
			local colour = math.clamp((t - SILHOUETTE_SECONDS) / COLOUR_SECONDS, 0, 1)
			for part, original in pairs(originals) do
				part.Color = C.Ink:Lerp(original, colour)
			end
		end
	end)
	frame.Activated:Connect(close)
end

local function onProfile()
	local profile = Store.profile
	if not profile then
		return
	end
	for _, id in ipairs(JournalReveal.newlySeen(Config, lastSeen, profile.seenSpecies)) do
		local species = Config.Species[id]
		local habitat = Config.Habitats[species.Habitat]
		enqueue({
			speciesId = id,
			kicker = "New in your journal",
			detail = if species.Visitor
				then "A visitor to " .. habitat.Name .. ". Feed it to learn what it likes."
				else "Lives in " .. habitat.Name .. ". Feed it to learn what it likes.",
		})
	end
	lastSeen = table.clone(profile.seenSpecies or {})
	showNext()
end

local function onReward(payload: any)
	if type(payload) ~= "table" or not payload.discovered or payload.preference ~= "favorite" then
		return
	end
	local food = Config.Foods[payload.food]
	if Config.Species[payload.species] and food then
		enqueue({ speciesId = payload.species, kicker = "Favourite found", detail = "Loves " .. food.Name .. "." })
		showNext()
	end
end

-- Island arrival banner.
local lastHabitat: string? = nil
local shownAt: { [string]: number } = {}
local bannerToken = 0

local function arrive(habitatId: string)
	local profile = Store.profile
	if not profile then
		return
	end
	local now = os.clock()
	if shownAt[habitatId] and now - shownAt[habitatId] < ARRIVAL_REPEAT then
		return
	end
	shownAt[habitatId] = now
	local title, detail = JournalReveal.arrival(Config, profile, habitatId)
	bannerToken += 1
	local token = bannerToken
	banner.Text = string.format('%s\n<font size="16">%s</font>', title, detail)
	banner.Visible = true
	local quick = reduced()
	local started = now
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if token ~= bannerToken then
			connection:Disconnect()
			return
		end
		if t > ARRIVAL_SECONDS then
			banner.Visible = false
			connection:Disconnect()
			return
		end
		-- Fade in and out over a quarter second at each end.
		local alpha = if quick then 0 else 1 - math.clamp(math.min(t, ARRIVAL_SECONDS - t) / 0.25, 0, 1)
		banner.TextTransparency = alpha
		banner.BackgroundTransparency = 0.08 + alpha * 0.92
	end)
end

function Discovery.init()
	holder = Hud.cluster("Discovery", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 128),
		Size = UDim2.fromOffset(300, 200),
	})
	local arrival = Hud.cluster("Arrival", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.26),
		Size = UDim2.fromOffset(340, 64),
	})
	banner = Ui.new("TextLabel", {
		Name = "Banner",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.PanelDark,
		BackgroundTransparency = 0.08,
		TextColor3 = C.White,
		FontFace = Ui.TitleFont,
		TextSize = 24,
		RichText = true,
		Visible = false,
		Parent = arrival,
	}, { Ui.corner(8), Ui.padding(6) })

	Store.on("profile", onProfile)
	Store.on("reward", onReward)
	-- Cards that arrived while a panel was open show once it closes.
	task.spawn(function()
		while true do
			task.wait(0.5)
			showNext()
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and Store.profile then
				local here = JournalReveal.habitatAt(Config, root.Position.X, root.Position.Z)
				if here and here ~= lastHabitat then
					arrive(here)
				end
				if here then
					lastHabitat = here
				end
			end
		end
	end)
end

return Discovery
