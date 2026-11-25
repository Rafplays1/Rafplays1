-- Remotes: one place that creates/finds the RemoteEvents the server and client
-- use to talk to each other. They live in ReplicatedStorage > Remotes.
--
-- Usage (server or client):  local event = Remotes.get("Ragdoll")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local Remotes = {}

function Remotes.get(name: string): RemoteEvent
	if RunService:IsServer() then
		-- The server creates things on demand.
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		local event = folder:FindFirstChild(name)
		if not event then
			event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
		return event
	end

	-- The client just waits for the server to have made it.
	return ReplicatedStorage:WaitForChild(FOLDER_NAME):WaitForChild(name)
end

return Remotes
