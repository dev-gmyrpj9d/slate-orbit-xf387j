--!strict
-- Builds and poses pass companions from primitive parts, in the same chunky smooth-plastic style
-- as the island animals (World.AnimalFactory). Companions are client-only: each client builds
-- the ones it can see and moves them locally, so they cost the server nothing.
--
-- Rig: an anchored "Body" root; Head, four Legs and the lantern Tail hang from Motor6D joints
-- (posed through Transform); the rest is welded to the part it sits on.

local CompanionModel = {}

export type Rig = {
	model: Model,
	root: BasePart,
	head: Motor6D,
	tail: Motor6D,
	legs: { Motor6D }, -- front-left, front-right, back-left, back-right
	lantern: BasePart,
	halfHeight: number, -- root centre to ground
}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function part(model: Model, name: string, shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.Parent = model
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("Weld")
	w.Part0 = a
	w.Part1 = b
	w.C0 = a.CFrame:Inverse() * b.CFrame
	w.Parent = b
end

-- `pivot` is a point on `parent` (model space) the child rotates around.
local function joint(parent: BasePart, child: BasePart, pivot: Vector3): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = child.Name .. "Joint"
	m.Part0 = parent
	m.Part1 = child
	m.C0 = parent.CFrame:Inverse() * CFrame.new(pivot)
	m.C1 = child.CFrame:Inverse() * CFrame.new(pivot)
	m.Parent = child
	return m
end

-- Builds a companion at the origin facing -Z. `def` is a Config.Companions entry.
function CompanionModel.build(def: any, scale: number?): Rig
	local s = scale or 1
	local fur, belly, glow, ink = rgb(def.Fur), rgb(def.Belly), rgb(def.Lantern), rgb(def.Ink)
	local model = Instance.new("Model")
	model.Name = def.Name
	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(x, y, z) * s
	end
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(v(x, y, z))
	end

	local body = part(model, "Body", Enum.PartType.Block, v(1.3, 1.1, 1.9), at(0, 0, 0), fur)
	body.Anchored = true
	model.PrimaryPart = body
	weld(body, part(model, "Belly", Enum.PartType.Block, v(1.1, 0.5, 1.5), at(0, -0.35, -0.05), belly))

	local head = part(model, "Head", Enum.PartType.Block, v(1.3, 1.15, 1.2), at(0, 0.75, -1.15), fur)
	weld(head, part(model, "Muzzle", Enum.PartType.Block, v(0.7, 0.45, 0.55), at(0, 0.55, -1.85), belly))
	weld(head, part(model, "Nose", Enum.PartType.Ball, v(0.22, 0.22, 0.22), at(0, 0.72, -2.13), ink))
	for _, side in ipairs({ -1, 1 }) do
		weld(head, part(model, "Eye", Enum.PartType.Ball, v(0.24, 0.24, 0.24), at(side * 0.32, 0.95, -1.76), ink))
		local ear = part(
			model,
			"Ear",
			Enum.PartType.Block,
			v(0.42, 0.7, 0.22),
			at(side * 0.38, 1.55, -1.1) * CFrame.Angles(0, 0, math.rad(-side * 14)),
			fur
		)
		weld(head, ear)
		weld(
			ear,
			part(
				model,
				"EarInner",
				Enum.PartType.Block,
				v(0.24, 0.45, 0.06),
				at(side * 0.38, 1.5, -1.23) * CFrame.Angles(0, 0, math.rad(-side * 14)),
				belly
			)
		)
	end
	local headJoint = joint(body, head, v(0, 0.45, -0.8))

	local legs = {}
	for _, z in ipairs({ -0.6, 0.6 }) do
		for _, side in ipairs({ -1, 1 }) do
			local leg = part(model, "Leg", Enum.PartType.Block, v(0.32, 0.6, 0.32), at(side * 0.42, -0.75, z), fur:Lerp(ink, 0.45))
			table.insert(legs, joint(body, leg, v(side * 0.42, -0.45, z)))
		end
	end

	-- The tail curls up and ends in a small paper lantern: a frame, a warm panel and a cap.
	local tail = part(model, "Tail", Enum.PartType.Block, v(0.38, 0.38, 1.1), at(0, 0.35, 1.3) * CFrame.Angles(math.rad(35), 0, 0), fur)
	local tailJoint = joint(body, tail, v(0, 0.2, 0.9))
	local lantern = part(model, "Lantern", Enum.PartType.Block, v(0.55, 0.65, 0.55), at(0, 1.05, 1.85), glow)
	lantern.Material = Enum.Material.Neon
	lantern.Transparency = 0.15
	lantern.CastShadow = false
	weld(tail, lantern)
	weld(lantern, part(model, "LanternCap", Enum.PartType.Block, v(0.65, 0.12, 0.65), at(0, 1.43, 1.85), ink))
	weld(lantern, part(model, "LanternBase", Enum.PartType.Block, v(0.65, 0.1, 0.65), at(0, 0.68, 1.85), ink))

	return {
		model = model,
		root = body,
		head = headJoint,
		tail = tailJoint,
		legs = legs,
		lantern = lantern,
		halfHeight = 1.05 * s,
	}
end

-- Poses the joints. `t` is time, `speed` 0..1 how fast it is trotting, `perk` 0..1 the phase of
-- a short hop (when its owner feeds an animal; 0 when not hopping), `lookYaw` radians the head
-- turns. Returns the vertical bob to add to the root.
function CompanionModel.pose(rig: Rig, t: number, speed: number, perk: number, lookYaw: number): number
	local gait = math.sin(t * 13) * 0.75 * speed
	-- Diagonal gait: front-left with back-right.
	rig.legs[1].Transform = CFrame.Angles(gait, 0, 0)
	rig.legs[4].Transform = CFrame.Angles(gait, 0, 0)
	rig.legs[2].Transform = CFrame.Angles(-gait, 0, 0)
	rig.legs[3].Transform = CFrame.Angles(-gait, 0, 0)
	local sway = math.sin(t * 2.2) * 0.25 + math.sin(t * 13) * 0.12 * speed
	local hop = math.sin(math.clamp(perk, 0, 1) * math.pi)
	rig.tail.Transform = CFrame.Angles(math.sin(t * 1.7) * 0.08 - hop * 0.3, sway, 0)
	rig.head.Transform = CFrame.Angles(math.sin(t * 1.3) * 0.05 - hop * 0.25, math.clamp(lookYaw, -0.9, 0.9), 0)
	return math.abs(math.sin(t * 13)) * 0.12 * speed + hop * 0.9
end

return CompanionModel
