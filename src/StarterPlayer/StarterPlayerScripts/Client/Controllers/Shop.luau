--!strict
-- Client side of the optional passes: live price lookup and 3D previews for the Shop tab.
--
-- Prices are never hard-coded. GetProductInfoAsync is asked once per configured pass (Creator
-- Docs recommend reading price on the client so personalised prices show). Until it answers, or
-- when the pass isn't configured or isn't for sale, the Shop says so and offers no Buy button.
-- Buying only *asks* the server to prompt; ownership always comes back from the server.

local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Passes = require(ReplicatedStorage.Shared.Passes)
local CompanionModel = require(ReplicatedStorage.Shared.CompanionModel)
local Ui = require(script.Parent.Ui)

local Shop = {}

export type PriceState = { status: string, price: number? } -- "unconfigured" | "loading" | "forSale" | "offSale" | "error"

local prices: { [string]: PriceState } = {}
local retried: { [string]: boolean } = {}
local listeners: { () -> () } = {}

function Shop.onPricesChanged(callback: () -> ())
	table.insert(listeners, callback)
end

local function fetch(key: string, def: any)
	prices[key] = { status = "loading" }
	task.spawn(function()
		local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, def.PassId, Enum.InfoType.GamePass)
		if ok and type(info) == "table" then
			local price = info.PriceInRobux
			if info.IsForSale == true and type(price) == "number" then
				prices[key] = { status = "forSale", price = price }
			else
				prices[key] = { status = "offSale" }
			end
		else
			warn("[WildFeast] Pass info unavailable for " .. key .. ": " .. tostring(info))
			prices[key] = { status = "error" }
		end
		for _, callback in ipairs(listeners) do
			task.spawn(callback)
		end
	end)
end

-- Current price state for a pass (starts the lookup the first time it's asked for).
function Shop.price(key: string): PriceState
	local def = Config.Passes[key]
	if not Passes.isConfigured(def) then
		return { status = "unconfigured" }
	end
	local state = prices[key]
	if state == nil or (state.status == "error" and not retried[key]) then
		-- One automatic retry after a failed lookup; after that the Shop shows the error.
		if state then
			retried[key] = true
		end
		fetch(key, def)
	end
	return prices[key]
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- A slowly turning 3D preview of the pass's companion, or a swatch strip of its trails.
-- Returns the preview frame; its animation stops when the frame is destroyed.
function Shop.preview(def: any, parent: Instance, reduced: boolean): Frame
	local holder = Ui.new("Frame", {
		Name = "Preview",
		Size = UDim2.fromOffset(150, 150),
		BackgroundColor3 = Ui.Colors.Panel,
		Parent = parent,
	}, { Ui.corner(8), Ui.stroke(Ui.Colors.Rule, 1) })
	if def.Companion then
		local viewport = Ui.new("ViewportFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(170, 160, 150),
			LightColor = Color3.fromRGB(255, 244, 228),
			LightDirection = Vector3.new(-0.6, -1, -0.4),
			Parent = holder,
		})
		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		-- A WorldModel lets the rig's welds and Motor6D joints work inside the viewport.
		local world = Instance.new("WorldModel")
		world.Parent = viewport
		local rig = CompanionModel.build(Config.Companions[def.Companion])
		rig.model.Parent = world
		camera.CFrame = CFrame.lookAt(Vector3.new(4.2, 2.4, -6.4), Vector3.new(0, 0.2, 0))
		local start = os.clock()
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			if not holder.Parent then
				connection:Disconnect()
				return
			end
			local t = os.clock() - start
			local spin = if reduced then 0.6 else t * 0.6
			CompanionModel.pose(rig, t, 0, 0, math.sin(t * 0.8) * 0.4)
			rig.root.CFrame = CFrame.Angles(0, spin, 0)
		end)
	elseif def.Trails then
		Ui.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center).Parent = holder
		Ui.padding(14).Parent = holder
		for i, id in ipairs(def.Trails) do
			local trail = Config.Trails[id]
			-- Flat swatch: the trail's head colour, a short tail in its second colour, its name.
			local strip = Ui.new("Frame", {
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				LayoutOrder = i,
				Parent = holder,
			})
			Ui.new("Frame", {
				Size = UDim2.new(0.28, 0, 0, 8 * trail.Width + 4),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				BackgroundColor3 = rgb(trail.Colors[1]),
				Parent = strip,
			}, { Ui.corner(4) })
			Ui.new("Frame", {
				Size = UDim2.new(0.14, 0, 0, 4 * trail.Width + 2),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0.3, 0.5),
				BackgroundColor3 = rgb(trail.Colors[2]),
				Parent = strip,
			}, { Ui.corner(3) })
			Ui.label({
				Text = trail.Name,
				TextSize = 14,
				FontFace = Ui.BoldFont,
				TextColor3 = Ui.Colors.Ink,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextYAlignment = Enum.TextYAlignment.Center,
				Size = UDim2.fromScale(1, 1),
				AutomaticSize = Enum.AutomaticSize.None,
				Parent = strip,
			})
		end
	else
		Ui.label({
			Text = string.format("%d → %d\npinned foods", Config.FoodBar.MaxPinned, Config.FoodBar.MaxPinned + (def.ExtraPins or 0)),
			TextSize = 22,
			FontFace = Ui.TitleFont,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			AutomaticSize = Enum.AutomaticSize.None,
			Parent = holder,
		})
	end
	return holder
end

return Shop
