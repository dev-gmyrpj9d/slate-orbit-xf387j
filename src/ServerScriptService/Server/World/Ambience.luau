--!strict
-- Scene grade for the islands: warm mid-afternoon sun, slightly richer colour, a soft bloom
-- that only catches the glowing props (mushrooms, lanterns, the starfruit) and faint sun rays.
-- Idempotent: effects are found by name and updated, so it is safe to run on every start.

local Lighting = game:GetService("Lighting")

local Ambience = {}

local function effect(className: string, name: string, props: { [string]: any })
	local inst = Lighting:FindFirstChild(name)
	if not inst or inst.ClassName ~= className then
		if inst then
			inst:Destroy()
		end
		inst = Instance.new(className)
		inst.Name = name
	end
	for key, value in pairs(props) do
		(inst :: any)[key] = value
	end
	inst.Parent = Lighting
end

function Ambience.apply()
	Lighting.ClockTime = 15.2
	Lighting.Brightness = 2.4
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.3
	effect("ColorCorrectionEffect", "WFI_Grade", {
		Saturation = 0.1,
		Contrast = 0.05,
		Brightness = 0.01,
		TintColor = Color3.fromRGB(255, 249, 240),
	})
	effect("BloomEffect", "WFI_Bloom", {
		Intensity = 0.45,
		Size = 28,
		Threshold = 1.7,
	})
	effect("SunRaysEffect", "WFI_SunRays", {
		Intensity = 0.04,
		Spread = 0.55,
	})
end

return Ambience
