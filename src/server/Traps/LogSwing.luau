-- LogSwing: a gate with a big log that swings down when a legend walks through.
--
-- * Only LEGENDS set it off (players can walk through safely while it's armed).
-- * Once it's swinging it hits everything: legends get knocked on their side,
--   and players standing in the way get ragdolled and launched.
-- * It winches itself back up and re-arms after a few seconds.
--
-- The swing is done with maths (a pendulum formula) instead of real physics,
-- so it behaves exactly the same every time and is cheap for phones.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local LegendRegistry = require(script.Parent.Parent.LegendRegistry)
local Ragdoll = require(script.Parent.Parent.Ragdoll)

local C = Config.LogSwing

local WOOD = Color3.fromRGB(120, 85, 55)
local WOOD_DARK = Color3.fromRGB(90, 62, 40)
local ROPE = Color3.fromRGB(200, 175, 120)

local LogSwing = {}
LogSwing.__index = LogSwing

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- groundCFrame: a spot on the ground. The legend should walk through the gate
-- along this CFrame's forward/back direction. The log waits on the BACK side
-- and swings toward the FRONT (the LookVector).
function LogSwing.new(groundCFrame: CFrame)
	local self = setmetatable({}, LogSwing)
	self.origin = groundCFrame
	self.state = "Armed" -- Armed > Swinging > Resetting > Cooldown > Armed
	self.stateTime = 0
	self.angle = math.rad(C.ArmedAngle)
	self.resetFromAngle = 0
	self.hitThisSwing = {}

	local model = Instance.new("Model")
	model.Name = "LogSwingTrap"
	self.model = model

	local halfGate = C.GateWidth / 2
	local height = C.PivotHeight

	-- The frame: two posts and a beam across the top.
	for _, side in { -1, 1 } do
		makePart(
			model,
			"Post",
			Vector3.new(2, height, 2),
			groundCFrame * CFrame.new(side * (halfGate + 1), height / 2, 0),
			WOOD_DARK,
			Enum.Material.Wood
		)
	end
	makePart(
		model,
		"Beam",
		Vector3.new(C.GateWidth + 6, 2, 2),
		groundCFrame * CFrame.new(0, height + 1, 0),
		WOOD_DARK,
		Enum.Material.Wood
	)

	-- A trip rope on the ground, just for looks.
	local tripRope = makePart(
		model,
		"TripRope",
		Vector3.new(C.GateWidth, 0.2, 0.2),
		groundCFrame * CFrame.new(0, 0.6, 0),
		ROPE,
		Enum.Material.Fabric
	)
	tripRope.CanCollide = false

	-- The swinging bits. CanCollide is off: the script decides what gets hit.
	self.ropes = {}
	for _, side in { -1, 1 } do
		local rope =
			makePart(model, "Rope", Vector3.new(0.4, C.RopeLength, 0.4), groundCFrame, ROPE, Enum.Material.Fabric)
		rope.CanCollide = false
		rope.CanQuery = false
		self.ropes[rope] = side * (halfGate - 4)
	end

	-- A cylinder's length is its X size, so this log lies across the gate.
	self.log = makePart(model, "Log", Vector3.new(C.GateWidth - 4, 3.5, 3.5), groundCFrame, WOOD, Enum.Material.Wood)
	self.log.Shape = Enum.PartType.Cylinder
	self.log.CanCollide = false

	self:_applyAngle()
	model.Parent = workspace

	self.connection = RunService.Heartbeat:Connect(function(dt)
		self:_step(dt)
	end)

	return self
end

function LogSwing:Destroy()
	self.connection:Disconnect()
	self.model:Destroy()
end

-- Moves the log and ropes to match self.angle (0 = hanging straight down).
function LogSwing:_applyAngle()
	local arm = self.origin * CFrame.new(0, C.PivotHeight, 0) * CFrame.Angles(-self.angle, 0, 0)
	self.log.CFrame = arm * CFrame.new(0, -C.RopeLength, 0)
	for rope, xOffset in self.ropes do
		rope.CFrame = arm * CFrame.new(xOffset, -C.RopeLength / 2, 0)
	end
end

function LogSwing:_setState(name: string)
	self.state = name
	self.stateTime = 0
	self.model:SetAttribute("State", name)
end

-- Is this world position inside the gate?
function LogSwing:_isInGate(position: Vector3): boolean
	local p = self.origin:PointToObjectSpace(position)
	return math.abs(p.X) < C.GateWidth / 2 and math.abs(p.Z) < 5 and p.Y > -2 and p.Y < C.PivotHeight
end

function LogSwing:_legendIsTriggering(): boolean
	for _, legend in LegendRegistry.getAll() do
		local root = legend.root
		if root and root.Parent then
			-- Check where it is now AND where it will be by the time the log
			-- comes down. That way a fast charge still gets clobbered.
			local soon = root.Position + root.AssemblyLinearVelocity * C.TriggerLeadTime
			if self:_isInGate(root.Position) or self:_isInGate(soon) then
				return true
			end
		end
	end
	return false
end

-- direction: 1 if the log is currently moving toward the front, -1 if moving back.
function LogSwing:_hitThings(direction: number)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.model }

	local push = self.origin.LookVector * direction

	for _, part in workspace:GetPartsInPart(self.log, params) do
		-- A legend?
		local legend = LegendRegistry.fromPart(part)
		if legend then
			if not self.hitThisSwing[legend] then
				self.hitThisSwing[legend] = true
				legend:Knockdown()
			end
			continue
		end

		-- A player?
		local character = part:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if player and not self.hitThisSwing[player] then
			self.hitThisSwing[player] = true
			local velocity = push * C.PlayerKnockback + Vector3.new(0, C.PlayerKnockUp, 0)
			Ragdoll.apply(character, C.PlayerRagdollTime, velocity)
		end
	end
end

function LogSwing:_step(dt: number)
	self.stateTime += dt
	local t = self.stateTime

	if self.state == "Armed" then
		if self:_legendIsTriggering() then
			self.hitThisSwing = {}
			self:_setState("Swinging")
		end
	elseif self.state == "Swinging" then
		-- Pendulum: swings back and forth, each swing a bit smaller.
		local armed = math.rad(C.ArmedAngle)
		local speed = 2 * math.pi / C.SwingPeriod
		local fade = math.exp(-C.Damping * t)
		local newAngle = armed * math.cos(speed * t) * fade

		local angularVelocity = (newAngle - self.angle) / math.max(dt, 1 / 240)
		self.angle = newAngle
		self:_applyAngle()

		if math.abs(angularVelocity) >= C.MinHitSpeed then
			-- The angle shrinking means the log is moving toward the front.
			self:_hitThings(if angularVelocity < 0 then 1 else -1)
		end

		if t >= C.SwingDuration then
			self.resetFromAngle = self.angle
			self:_setState("Resetting")
		end
	elseif self.state == "Resetting" then
		-- Winch it smoothly back up to the armed position.
		local alpha = math.clamp(t / C.ResetTime, 0, 1)
		alpha = alpha * alpha * (3 - 2 * alpha) -- ease in and out
		self.angle = self.resetFromAngle + (math.rad(C.ArmedAngle) - self.resetFromAngle) * alpha
		self:_applyAngle()
		if t >= C.ResetTime then
			self:_setState("Cooldown")
		end
	elseif self.state == "Cooldown" then
		if t >= C.RearmCooldown then
			self:_setState("Armed")
		end
	end
end

return LogSwing
