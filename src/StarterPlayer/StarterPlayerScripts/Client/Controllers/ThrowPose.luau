--!strict
-- Gives throws a body: the throwing arm cocks back while charging (further with more power),
-- whips over the top on release and settles in a follow-through (Shared.Feel curves).
--
-- No animation asset is needed. Each client layers a rotation on the right shoulder's
-- Motor6D.Transform after the default animations are applied (PreSimulation, as the Creator
-- Docs recommend for procedural Transform changes). Every client poses every thrower from
-- the server's throw broadcast, so others see the motion too. It is cosmetic only.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Feel = require(ReplicatedStorage.Shared.Feel)
local Store = require(script.Parent.Store)
local ThrowController = require(script.Parent.ThrowController)

local ThrowPose = {}

local MAX_DISTANCE = 120 -- don't pose distant throwers
local player = Players.LocalPlayer

-- Active follow-throughs: character -> { started, from, remote }.
local swings: { [Model]: { started: number, from: number, remote: boolean } } = {}
local lastWindUp = 0

-- R15: RightShoulder in RightUpperArm, pitches about X. R6: "Right Shoulder" in Torso, about Z.
local function shoulder(character: Model): (Motor6D?, boolean)
	local upper = character:FindFirstChild("RightUpperArm")
	local r15 = upper and upper:FindFirstChild("RightShoulder")
	if r15 and r15:IsA("Motor6D") then
		return r15, true
	end
	local torso = character:FindFirstChild("Torso")
	local r6 = torso and torso:FindFirstChild("Right Shoulder")
	if r6 and r6:IsA("Motor6D") then
		return r6, false
	end
	return nil, false
end

local function apply(character: Model, angle: number)
	local motor, isR15 = shoulder(character)
	if motor then
		local turn = if isR15 then CFrame.Angles(angle, 0, 0) else CFrame.Angles(0, 0, angle)
		motor.Transform = motor.Transform * turn
	end
end

local function near(character: Model): boolean
	local camera = workspace.CurrentCamera
	local pivot = character.PrimaryPart
	return camera ~= nil and pivot ~= nil and (camera.CFrame.Position - pivot.Position).Magnitude <= MAX_DISTANCE
end

local function step()
	local now = os.clock()
	local own = player.Character
	if own and ThrowController.charging and not swings[own] then
		lastWindUp = Feel.windUp(ThrowController.power)
		apply(own, lastWindUp)
	end
	for character, swing in pairs(swings) do
		local t = now - swing.started
		local angle = if swing.remote then Feel.remoteThrow(t) else Feel.followThrough(t, swing.from)
		if angle == nil or not character.Parent then
			swings[character] = nil
		elseif near(character) then
			apply(character, angle)
		end
	end
end

function ThrowPose.init()
	-- Our own release: start at once from the wind-up we were showing (no network wait).
	Store.on("thrown", function()
		local own = player.Character
		if own then
			swings[own] = { started = os.clock(), from = lastWindUp, remote = false }
		end
	end)
	-- Everyone else's throws, from the server broadcast.
	Store.on("throwFx", function(ownerUserId: any)
		local owner = if type(ownerUserId) == "number" then Players:GetPlayerByUserId(ownerUserId) else nil
		local character = owner and owner ~= player and owner.Character
		if character then
			swings[character] = { started = os.clock(), from = 0, remote = true }
		end
	end)
	RunService.PreSimulation:Connect(step)
end

return ThrowPose
