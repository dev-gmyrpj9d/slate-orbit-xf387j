--!strict
-- Tiny declarative helpers for building the HUD from code (no external UI assets).
--
-- Look: "island field notes" (docs/ART_DIRECTION.md). Flat unbleached-paper panels, ink text,
-- moss for actions, clay for emphasis, tide blue for information. No gradients, glows or emoji;
-- state is always spelled out in words, with colour only as a second cue. Text colours are
-- picked for at least 4.5:1 contrast against the surface they sit on.

local Ui = {}

local BUILDER_SANS = "rbxasset://fonts/families/BuilderSans.json"
Ui.TitleFont = Font.new(BUILDER_SANS, Enum.FontWeight.Bold)
Ui.BodyFont = Font.new(BUILDER_SANS, Enum.FontWeight.Medium)
Ui.BoldFont = Font.new(BUILDER_SANS, Enum.FontWeight.SemiBold)

Ui.Colors = {
	Panel = Color3.fromRGB(244, 237, 224), -- paper
	Card = Color3.fromRGB(252, 248, 240), -- a lighter sheet on the paper
	PanelDark = Color3.fromRGB(38, 52, 48), -- deep ink green (HUD chips, side menu)
	Ink = Color3.fromRGB(40, 36, 32),
	Muted = Color3.fromRGB(98, 92, 82),
	Primary = Color3.fromRGB(70, 112, 68), -- moss: the action colour
	Accent = Color3.fromRGB(176, 84, 52), -- clay: selection and emphasis
	Good = Color3.fromRGB(56, 120, 80),
	Warn = Color3.fromRGB(150, 92, 24),
	Bad = Color3.fromRGB(160, 58, 48),
	Info = Color3.fromRGB(42, 92, 114), -- tide
	Disabled = Color3.fromRGB(214, 207, 194),
	DisabledInk = Color3.fromRGB(92, 86, 76),
	Rule = Color3.fromRGB(196, 186, 168), -- hairlines and strokes
	White = Color3.fromRGB(255, 255, 255),
}

-- Compact, width-stable number text for large values: 9876, 12.3K, 4.56M, 1.00B.
function Ui.formatNumber(value: number): string
	local n = math.floor(math.max(0, value))
	if n < 10000 then
		return tostring(n)
	elseif n < 1e6 then
		return string.format("%.1fK", math.floor(n / 100) / 10)
	elseif n < 1e9 then
		return string.format("%.2fM", math.floor(n / 1e4) / 100)
	end
	return string.format("%.2fB", math.floor(n / 1e7) / 100)
end

function Ui.new(className: string, props: { [string]: any }, children: { any }?): any
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = inst
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function Ui.corner(radius: number): any
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function Ui.stroke(color: Color3, thickness: number, transparency: number?): any
	return Ui.new("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.padding(px: number): any
	return Ui.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

function Ui.list(direction: Enum.FillDirection, padding: number, align: Enum.HorizontalAlignment?): any
	return Ui.new("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, padding),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	})
end

function Ui.label(props: { [string]: any }): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Ui.BodyFont,
		TextColor3 = Ui.Colors.Ink,
		TextSize = 18,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	return Ui.new("TextLabel", defaults)
end

-- Buttons are at least 48px tall before scaling to remain comfortable touch targets. Disabled
-- buttons switch to dark text on a pale fill so their label stays readable.
function Ui.button(props: { [string]: any }, enabled: boolean?): TextButton
	local isEnabled = enabled ~= false
	local defaults: { [string]: any } = {
		BackgroundColor3 = if isEnabled then Ui.Colors.Primary else Ui.Colors.Disabled,
		FontFace = Ui.TitleFont,
		TextColor3 = if isEnabled then Ui.Colors.White else Ui.Colors.DisabledInk,
		TextSize = 19,
		TextWrapped = true,
		AutoButtonColor = isEnabled,
		Size = UDim2.new(0, 200, 0, 52),
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	if not isEnabled then
		defaults.BackgroundColor3 = Ui.Colors.Disabled
		defaults.TextColor3 = Ui.Colors.DisabledInk
	end
	local button = Ui.new("TextButton", defaults, {
		Ui.corner(8),
		Ui.new("UIStroke", {
			Color = Ui.Colors.Ink,
			Thickness = 1.5,
			Transparency = 0.75,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Ui.new("UITextSizeConstraint", { MaxTextSize = defaults.TextSize, MinTextSize = 12 }),
	})
	button.TextScaled = true
	button:SetAttribute("Enabled", isEnabled)
	return button
end

return Ui
