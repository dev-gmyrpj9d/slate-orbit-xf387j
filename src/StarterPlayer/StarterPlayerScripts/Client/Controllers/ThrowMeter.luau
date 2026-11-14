--!strict
-- The throw meter: a vertical segmented gauge beside the aim point, plus three short lines of
-- text (power, predicted outcome, next input). Placed right of centre so it never covers the
-- animal being aimed at, and drawn with shapes and words, not a colour ramp (ThrowReadout).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ThrowReadout = require(ReplicatedStorage.Shared.ThrowReadout)
local Ui = require(script.Parent.Ui)

local C = Ui.Colors
local ThrowMeter = {}

local TRACK_HEIGHT = 210
local TRACK_WIDTH = 34
local GAP = 3

type Parts = {
	root: Frame,
	segments: { Frame },
	notch: Frame,
	headline: TextLabel,
	status: TextLabel,
	action: TextLabel,
	cancel: TextLabel,
	track: Frame,
	trackStroke: UIStroke,
	card: Frame,
}

local parts: Parts
local last = ""

-- `holder` is a HUD cluster (already scaled); the meter fills it.
function ThrowMeter.build(holder: Frame)
	local root = Ui.new("Frame", {
		Name = "ThrowMeter",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = holder,
	})
	local track = Ui.new("Frame", {
		Name = "Track",
		Size = UDim2.fromOffset(TRACK_WIDTH, TRACK_HEIGHT),
		BackgroundColor3 = C.PanelDark,
		BackgroundTransparency = 0.1,
		Parent = root,
	}, { Ui.corner(8) })
	-- A light outline keeps the dark track readable over both sky and dark ground.
	local trackStroke = Ui.stroke(C.Panel, 2)
	trackStroke.Parent = track
	local segments = {}
	local n = ThrowReadout.Segments
	local inner = TRACK_HEIGHT - 2 * 5
	local segmentHeight = (inner - GAP * (n - 1)) / n
	for i = 1, n do
		segments[i] = Ui.new("Frame", {
			Name = "Segment" .. i,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -5 - (i - 1) * (segmentHeight + GAP)),
			Size = UDim2.fromOffset(TRACK_WIDTH - 10, segmentHeight),
			BackgroundColor3 = C.Panel,
			BackgroundTransparency = 0.82,
			Parent = track,
		}, { Ui.corner(3) })
	end
	-- The notch sticks out of both sides of the track, so the level reads without the fill.
	local notch = Ui.new("Frame", {
		Name = "Notch",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -5),
		Size = UDim2.fromOffset(TRACK_WIDTH + 14, 5),
		BackgroundColor3 = C.White,
		ZIndex = 3,
		Parent = track,
	}, { Ui.corner(2), Ui.stroke(C.Ink, 1) })

	local card = Ui.new("Frame", {
		Name = "Readout",
		Position = UDim2.fromOffset(TRACK_WIDTH + 14, TRACK_HEIGHT - 118),
		Size = UDim2.fromOffset(196, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.Card,
		BackgroundTransparency = 0.04,
		Parent = root,
	}, { Ui.corner(8), Ui.padding(8), Ui.list(Enum.FillDirection.Vertical, 2) })
	local function line(order: number, size: number, font: Font, color: Color3): TextLabel
		return Ui.label({
			Text = "",
			TextSize = size,
			FontFace = font,
			TextColor3 = color,
			TextWrapped = true,
			LayoutOrder = order,
			Parent = card,
		})
	end
	parts = {
		root = root,
		segments = segments,
		notch = notch,
		headline = line(1, 28, Ui.TitleFont, C.Ink),
		status = line(2, 17, Ui.BoldFont, C.Ink),
		action = line(3, 15, Ui.BodyFont, C.Muted),
		cancel = line(4, 14, Ui.BodyFont, C.Muted),
		track = track,
		trackStroke = trackStroke,
		card = card,
	}
	local cardStroke = Ui.stroke(C.Rule, 1)
	cardStroke.Name = "Edge"
	cardStroke.Parent = card
end

function ThrowMeter.update(input: ThrowReadout.Input)
	local r = ThrowReadout.compute(input)
	-- Most frames repeat the last readout; skip the property writes then.
	local key =
		string.format("%s|%d|%.3f|%s|%s|%s|%s", tostring(r.visible), r.filled, r.level, r.headline, r.status, r.action, tostring(r.catch))
	if key == last then
		return
	end
	last = key
	parts.root.Visible = r.visible
	if not r.visible then
		return
	end
	for i, segment in ipairs(parts.segments) do
		segment.BackgroundTransparency = if i <= r.filled then 0 else 0.82
	end
	parts.notch.Position = UDim2.new(0.5, 0, 1, -5 - r.level * (TRACK_HEIGHT - 10))
	parts.headline.Text = r.headline
	parts.status.Text = r.status
	parts.status.Visible = r.status ~= ""
	parts.action.Text = r.action
	parts.action.Visible = r.action ~= ""
	parts.cancel.Text = r.cancel
	parts.cancel.Visible = r.cancel ~= ""
	-- A predicted catch gets a heavier clay outline on both pieces (shape cue, not just colour).
	local edge = parts.card:FindFirstChild("Edge") :: UIStroke
	edge.Color = if r.catch then C.Accent else C.Rule
	edge.Thickness = if r.catch then 3 else 1
	parts.trackStroke.Color = if r.catch then C.Accent else C.Panel
	parts.trackStroke.Thickness = if r.catch then 3 else 2
	parts.status.TextColor3 = if r.catch then C.Accent else C.Ink
end

return ThrowMeter
