-- Oriented-box helpers shared by the offline geometry tests.
local roblox = require("@lune/roblox")

local Geo = {}

function Geo.obb(part)
	return {
		c = part.CFrame.Position,
		a = { part.CFrame.XVector, part.CFrame.YVector, part.CFrame.ZVector },
		h = { part.Size.X / 2, part.Size.Y / 2, part.Size.Z / 2 },
	}
end

function Geo.radius(box, axis)
	local r = 0
	for i = 1, 3 do
		r += box.h[i] * math.abs(box.a[i]:Dot(axis))
	end
	return r
end

-- Separating axis test (15 axes). `pad` > 0 counts near-touching as overlap; < 0 lets boxes touch.
function Geo.overlaps(a, b, pad)
	local axes = {}
	for i = 1, 3 do
		table.insert(axes, a.a[i])
		table.insert(axes, b.a[i])
		for j = 1, 3 do
			local cross = a.a[i]:Cross(b.a[j])
			if cross.Magnitude > 1e-6 then
				table.insert(axes, cross.Unit)
			end
		end
	end
	local d = b.c - a.c
	for _, axis in axes do
		if math.abs(d:Dot(axis)) > Geo.radius(a, axis) + Geo.radius(b, axis) + pad then
			return false
		end
	end
	return true
end

-- True when every corner of `inner` lies inside `outer` (a box, or a sphere for Ball parts):
-- the inner part can't be seen.
function Geo.contains(outer, inner)
	local c, s = inner.CFrame, inner.Size
	local ball = outer.Shape == roblox.Enum.PartType.Ball
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local w = c * roblox.Vector3.new(sx * s.X / 2, sy * s.Y / 2, sz * s.Z / 2)
				local local_ = outer.CFrame:Inverse() * w
				if ball then
					if local_.Magnitude > math.min(outer.Size.X, outer.Size.Y, outer.Size.Z) / 2 then
						return false
					end
				elseif
					math.abs(local_.X) > outer.Size.X / 2
					or math.abs(local_.Y) > outer.Size.Y / 2
					or math.abs(local_.Z) > outer.Size.Z / 2
				then
					return false
				end
			end
		end
	end
	return true
end

function Geo.bottomY(part)
	local r = Geo.obb(part)
	return r.c.Y - Geo.radius(r, roblox.Vector3.new(0, 1, 0))
end

return Geo
