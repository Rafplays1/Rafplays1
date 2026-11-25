-- TestArena: a quick flat test area made by script, so there is something to
-- play in before the real Whisperwood map exists. It adds:
--   * ground and a spawn point (only if your place doesn't already have them)
--   * some big trees (tagged "BigTree" so Mossback can stun itself on them)
-- and it returns where the trap and the Mossback should go.
--
-- Layout (looking from above, you spawn at the bottom):
--
--        Mossback          z = -120
--           |
--        [ trap ]          z = -40
--           |
--          YOU             z = 0

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local TestArena = {}

-- { x, z } positions for the big trees.
local TREE_SPOTS = {
	{ -35, -25 },
	{ 35, -70 },
	{ -50, -95 },
	{ 55, -125 },
	{ -80, -45 },
	{ 80, -15 },
	{ 0, -170 },
	{ -30, 45 },
	{ 40, 50 },
	{ -90, -140 },
}

local function makeTree(parent: Instance, x: number, z: number)
	local height = 40

	local trunk = Instance.new("Part")
	trunk.Name = "BigTreeTrunk"
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(height, 7, 7) -- a cylinder's length is its X size...
	trunk.CFrame = CFrame.new(x, height / 2, z) * CFrame.Angles(0, 0, math.rad(90)) -- ...so stand it upright
	trunk.Color = Color3.fromRGB(96, 70, 48)
	trunk.Material = Enum.Material.Wood
	trunk.Anchored = true
	trunk.Parent = parent
	CollectionService:AddTag(trunk, Config.BigTreeTag)

	local leaves = Instance.new("Part")
	leaves.Name = "Leaves"
	leaves.Shape = Enum.PartType.Ball
	leaves.Size = Vector3.new(26, 26, 26)
	leaves.Position = Vector3.new(x, height + 6, z)
	leaves.Color = Color3.fromRGB(58, 110, 62)
	leaves.Material = Enum.Material.Grass
	leaves.Anchored = true
	leaves.CanCollide = false
	leaves.CanQuery = false
	leaves.Parent = parent
end

function TestArena.build()
	local folder = Instance.new("Folder")
	folder.Name = "TestArena"

	-- Ground: use the template's Baseplate if there is one.
	if not workspace:FindFirstChild("Baseplate") then
		local ground = Instance.new("Part")
		ground.Name = "Ground"
		ground.Size = Vector3.new(700, 4, 700)
		ground.Position = Vector3.new(0, -2, -50) -- top surface at height 0
		ground.Color = Color3.fromRGB(74, 120, 66)
		ground.Material = Enum.Material.Grass
		ground.Anchored = true
		ground.Parent = folder
	end

	-- Spawn point: use the existing one if there is one.
	if not workspace:FindFirstChildWhichIsA("SpawnLocation", true) then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "CampSpawn"
		spawn.Size = Vector3.new(10, 1, 10)
		spawn.Position = Vector3.new(0, 0.5, 0)
		spawn.Anchored = true
		spawn.Parent = folder
	end

	for _, spot in TREE_SPOTS do
		makeTree(folder, spot[1], spot[2])
	end

	folder.Parent = workspace

	return {
		-- The trap's front faces the Mossback, so the log swings into its face.
		trapCFrame = CFrame.lookAt(Vector3.new(0, 0, -40), Vector3.new(0, 0, -120)),
		legendSpawn = Vector3.new(0, 0, -120),
		legendFacing = Vector3.new(0, 0, 1),
	}
end

return TestArena
