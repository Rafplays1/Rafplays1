-- MossbackModel: builds a PLACEHOLDER Mossback out of plain blocks, so we can
-- test the AI before the real Blender model exists.
--
-- When the Blender model is ready we replace this file and nothing else:
-- the AI only needs the things returned at the bottom (model, root, humanoid,
-- bodyJoint, antlers).
--
-- The model faces "forward" along its -Z direction (Roblox's standard front).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local C = Config.Mossback

local MOSS = Color3.fromRGB(86, 125, 70)
local MOSS_BRIGHT = Color3.fromRGB(120, 170, 80)
local FUR = Color3.fromRGB(110, 84, 60)
local FUR_DARK = Color3.fromRGB(70, 52, 38)
local ANTLER = Color3.fromRGB(150, 120, 85)

local MossbackModel = {}

function MossbackModel.build()
	local model = Instance.new("Model")
	model.Name = "Mossback"

	-- The invisible box the Humanoid actually moves around.
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = C.BodySize
	root.Transparency = 1
	root.CanCollide = false
	root.Parent = model
	model.PrimaryPart = root

	-- The visible body. Everything else is glued to this.
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = C.BodySize
	body.Color = FUR
	body.Material = Enum.Material.Sand
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.CFrame = root.CFrame
	body.Parent = model

	-- One joint between root and body. Tilting this joint tips the whole
	-- creature over (used for the knockdown).
	local bodyJoint = Instance.new("Weld")
	bodyJoint.Name = "BodyJoint"
	bodyJoint.Part0 = root
	bodyJoint.Part1 = body
	bodyJoint.Parent = root

	-- Helper: make a decoration part glued to the body.
	-- offset is where it sits relative to the middle of the body.
	local function addPart(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material?,
		shape: Enum.PartType?
	)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.Shape = shape or Enum.PartType.Block
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = false
		part.Massless = true
		part.CFrame = body.CFrame * offset
		part.Parent = model

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = part
		weld.Parent = part
		return part
	end

	-- Mossy blanket on its back
	addPart("Moss", Vector3.new(6.4, 1, 9.5), CFrame.new(0, 3.2, 0.5), MOSS, Enum.Material.Grass)
	addPart("MossLump", Vector3.new(4, 1.2, 4), CFrame.new(0, 3.9, 1.5), MOSS_BRIGHT, Enum.Material.Grass)

	-- Neck, head, snout, tail
	addPart("Neck", Vector3.new(2.6, 3.4, 3), CFrame.new(0, 2, -5.6) * CFrame.Angles(math.rad(-25), 0, 0), FUR)
	addPart("Head", Vector3.new(3, 3, 4), CFrame.new(0, 3.2, -7.4), FUR)
	addPart("Snout", Vector3.new(2, 1.8, 2), CFrame.new(0, 2.6, -10.2), FUR_DARK)
	addPart("Tail", Vector3.new(1.2, 1.2, 1.6), CFrame.new(0, 1.6, 6), MOSS_BRIGHT, Enum.Material.Grass)

	-- Eyes (glowing so the face reads from far away)
	for _, side in { -1, 1 } do
		addPart(
			"Eye",
			Vector3.new(0.3, 0.7, 0.7),
			CFrame.new(side * 1.5, 3.7, -8.4),
			Color3.fromRGB(255, 220, 90),
			Enum.Material.Neon
		)
	end

	-- Four legs. They reach from the bottom of the body down to the ground.
	local legLength = C.HipHeight
	for _, x in { -2, 2 } do
		for _, z in { -4, 4 } do
			addPart(
				"Leg",
				Vector3.new(1.6, legLength, 1.6),
				CFrame.new(x, -C.BodySize.Y / 2 - legLength / 2, z),
				FUR_DARK
			)
		end
	end

	-- Tree antlers. We remember these parts so the AI can make them glow.
	local antlers = {}
	local function addAntler(size: Vector3, offset: CFrame)
		table.insert(antlers, addPart("Antler", size, offset, ANTLER, Enum.Material.Wood))
	end
	for _, side in { -1, 1 } do
		-- side is -1 for the left antler and 1 for the right one
		addAntler(Vector3.new(0.9, 5, 0.9), CFrame.new(side * 1.8, 6.6, -7) * CFrame.Angles(0, 0, math.rad(-20 * side)))
		addAntler(
			Vector3.new(0.7, 3.5, 0.7),
			CFrame.new(side * 3.6, 7.6, -7) * CFrame.Angles(0, 0, math.rad(-60 * side))
		)
		addAntler(Vector3.new(0.7, 3, 0.7), CFrame.new(side * 2.4, 9.8, -7) * CFrame.Angles(0, 0, math.rad(10 * side)))
		addAntler(
			Vector3.new(0.6, 2.5, 0.6),
			CFrame.new(side * 3.4, 9.4, -7) * CFrame.Angles(0, 0, math.rad(-45 * side))
		)
		-- Leafy tufts on the tips ("tree antlers")
		addPart(
			"Leaves",
			Vector3.new(2.4, 2.4, 2.4),
			CFrame.new(side * 2.3, 11.6, -7),
			MOSS_BRIGHT,
			Enum.Material.Grass,
			Enum.PartType.Ball
		)
		addPart(
			"Leaves",
			Vector3.new(2, 2, 2),
			CFrame.new(side * 5.2, 8.5, -7),
			MOSS,
			Enum.Material.Grass,
			Enum.PartType.Ball
		)
		addPart(
			"Leaves",
			Vector3.new(1.8, 1.8, 1.8),
			CFrame.new(side * 4.4, 10.5, -7),
			MOSS_BRIGHT,
			Enum.Material.Grass,
			Enum.PartType.Ball
		)
	end

	-- The Humanoid is what lets us say "walk over there".
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = C.HipHeight
	humanoid.WalkSpeed = C.WalkSpeed
	humanoid.MaxHealth = 1000000
	humanoid.Health = 1000000
	humanoid.RequiresNeck = false -- it has no "Neck" joint, and that's fine
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	-- A giant elk should never jump, climb, swim or trip over.
	for _, state in
		{
			Enum.HumanoidStateType.Jumping,
			Enum.HumanoidStateType.Climbing,
			Enum.HumanoidStateType.Swimming,
			Enum.HumanoidStateType.FallingDown,
			Enum.HumanoidStateType.Ragdoll,
			Enum.HumanoidStateType.Seated,
		}
	do
		humanoid:SetStateEnabled(state, false)
	end
	humanoid.Parent = model

	CollectionService:AddTag(model, Config.LegendTag)
	model:SetAttribute("LegendName", "Mossback")

	return {
		model = model,
		root = root,
		humanoid = humanoid,
		bodyJoint = bodyJoint,
		antlers = antlers,
	}
end

return MossbackModel
