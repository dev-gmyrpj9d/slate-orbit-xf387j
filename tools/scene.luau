-- Non-script changes baked into the built place. Idempotent.
-- Lighting.Technology can only be set in Studio or the file (not by scripts), so it lives here;
-- the rest of the scene grade is applied at runtime by ServerScriptService.Server.World.Ambience.
local Scene = {}

function Scene.apply(game, roblox)
	local lighting = game:GetService("Lighting")
	-- ShadowMap: crisp sun shadows under the trees and animals; still light enough for mobile.
	lighting.Technology = roblox.Enum.Technology.ShadowMap
end

return Scene
