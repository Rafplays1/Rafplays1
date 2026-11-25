-- Ragdoll: makes a player's character go floppy for a few seconds, then stand up.
--
-- How it works: a character is held in shape by "Motor6D" joints (they play
-- animations). We switch those off and put loose ball-socket joints in their
-- place, so the limbs dangle. Afterwards we undo it.
--
-- Usage:  Ragdoll.apply(character, 2.5, Vector3.new(0, 50, -70))

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ragdollEvent = Remotes.get("Ragdoll")

local SOCKET_NAME = "RagdollSocket"
local ATTACHMENT_NAME = "RagdollAttachment"
local ATTRIBUTE = "Ragdolled"

local Ragdoll = {}

local function loosenJoints(character: Model)
	for _, motor in character:GetDescendants() do
		if not motor:IsA("Motor6D") or not motor.Part0 or not motor.Part1 then
			continue
		end
		-- Keep the joint that holds HumanoidRootPart to the body, so the
		-- knockback we apply to the root carries the whole character.
		if motor.Part0.Name == "HumanoidRootPart" or motor.Part1.Name == "HumanoidRootPart" then
			continue
		end

		local a0 = Instance.new("Attachment")
		a0.Name = ATTACHMENT_NAME
		a0.CFrame = motor.C0
		a0.Parent = motor.Part0

		local a1 = Instance.new("Attachment")
		a1.Name = ATTACHMENT_NAME
		a1.CFrame = motor.C1
		a1.Parent = motor.Part1

		local socket = Instance.new("BallSocketConstraint")
		socket.Name = SOCKET_NAME
		socket.Attachment0 = a0
		socket.Attachment1 = a1
		socket.LimitsEnabled = true
		socket.UpperAngle = 50
		socket.TwistLimitsEnabled = true
		socket.TwistLowerAngle = -40
		socket.TwistUpperAngle = 40
		socket.Parent = motor.Part0

		motor.Enabled = false
	end
end

local function restoreJoints(character: Model)
	for _, item in character:GetDescendants() do
		if item:IsA("Motor6D") then
			item.Enabled = true
		elseif item.Name == SOCKET_NAME or item.Name == ATTACHMENT_NAME then
			item:Destroy()
		end
	end
end

function Ragdoll.isRagdolled(character: Model): boolean
	return character:GetAttribute(ATTRIBUTE) == true
end

-- character: the player's character model
-- duration:  seconds to stay floppy
-- velocity:  optional fling (studs per second)
-- Returns true if the ragdoll started (false if they were already ragdolled, dead, etc).
function Ragdoll.apply(character: Model, duration: number, velocity: Vector3?): boolean
	local player = Players:GetPlayerFromCharacter(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not player or not humanoid or humanoid.Health <= 0 then
		return false
	end
	if Ragdoll.isRagdolled(character) then
		return false
	end

	character:SetAttribute(ATTRIBUTE, true)
	humanoid.RequiresNeck = false -- otherwise switching off the neck joint kills the player
	loosenJoints(character)
	ragdollEvent:FireClient(player, "start", velocity)

	task.delay(duration, function()
		if character.Parent == nil then
			return -- they respawned or left; nothing to undo
		end
		restoreJoints(character)
		character:SetAttribute(ATTRIBUTE, false)
		if player.Parent ~= nil then
			ragdollEvent:FireClient(player, "stop")
		end
	end)

	return true
end

return Ragdoll
