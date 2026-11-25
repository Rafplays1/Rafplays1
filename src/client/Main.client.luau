-- Client entry point. Runs once on each player's device.
--
-- Right now it does one job: when the SERVER says "you got knocked down",
-- make our own character go floppy and fly. The server decides IF we were hit;
-- we only handle the physics, because each player's device controls the
-- physics of their own character.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local ragdollEvent = Remotes.get("Ragdoll")

local function getHumanoidAndRoot()
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart")
end

ragdollEvent.OnClientEvent:Connect(function(action: string, velocity: Vector3?)
	local humanoid, root = getHumanoidAndRoot()
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	if action == "start" then
		-- "Physics" state = the Humanoid stops trying to stand up or walk.
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		if velocity then
			root.AssemblyLinearVelocity = velocity
			-- A random tumble so every hit looks a little different.
			root.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-4, 4), math.random(-8, 8))
		end
	elseif action == "stop" then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end)
