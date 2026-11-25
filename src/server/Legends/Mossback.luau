-- Mossback: the brain of the giant mossy elk.
--
-- It is a "state machine": at any moment it is in exactly ONE state, and each
-- state has simple rules.
--
--   Idle       no players around. Stands still.
--   Chase      walks toward the nearest player (PathfindingService finds a way
--              around trees when it can't see them directly).
--   Telegraph  stops, antlers glow GREEN for 1 second. This is the warning!
--   Charge     runs in a straight line. Players hit get ragdolled and flung.
--              If it rams a big tree it stuns itself (its weakness).
--   Recover    catching its breath after a charge that missed.
--   Stunned    antlers flash yellow, it can't move.
--   Knockdown  flopped on its side (a Log Swing hit it).
--
-- You can watch the state live in Studio: click the Mossback model in the
-- Explorer while playing and look at "State" under Attributes.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local LegendRegistry = require(script.Parent.Parent.LegendRegistry)
local MossbackModel = require(script.Parent.MossbackModel)
local Ragdoll = require(script.Parent.Parent.Ragdoll)

local C = Config.Mossback

local GLOW_CHARGE = Color3.fromRGB(80, 255, 110)
local GLOW_STUN = Color3.fromRGB(255, 225, 80)

local Mossback = {}
Mossback.__index = Mossback

-- Removes the up/down part of a direction so the legend never aims into the
-- ground or the sky.
local function flatten(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- groundPosition: the spot on the ground where it should appear.
-- facing (optional): a direction to look in.
function Mossback.new(groundPosition: Vector3, facing: Vector3?)
	local built = MossbackModel.build()

	local self = setmetatable({}, Mossback)
	self.model = built.model
	self.root = built.root
	self.humanoid = built.humanoid
	self.bodyJoint = built.bodyJoint
	self.antlers = built.antlers

	self.state = "Idle"
	self.stateTime = 0 -- seconds spent in the current state
	self.stateDuration = 0 -- for timed states: when to leave
	self.chargeCooldown = C.FirstChargeDelay
	self.chargeDirection = Vector3.new(0, 0, -1)
	self.chargeStart = Vector3.zero
	self.chargeHits = {} -- players already hit by the current charge
	self.target = nil -- the character being chased
	self.waypoints = nil
	self.waypointIndex = 1
	self.repathTimer = 0
	self.destroyed = false

	-- Remember what the antlers normally look like so we can un-glow them.
	self.antlerLook = {}
	for _, part in self.antlers do
		self.antlerLook[part] = { Color = part.Color, Material = part.Material }
	end

	self.path = PathfindingService:CreatePath({
		AgentRadius = 5,
		AgentHeight = 12,
		AgentCanJump = false,
		WaypointSpacing = 8,
	})

	-- Put it in the world, standing on the ground.
	local rootHeight = C.HipHeight + C.BodySize.Y / 2
	local position = groundPosition + Vector3.new(0, rootHeight, 0)
	local lookDirection = flatten(facing or Vector3.new(0, 0, 1))
	if lookDirection.Magnitude < 0.01 then
		lookDirection = Vector3.new(0, 0, 1)
	end
	self.model:PivotTo(CFrame.lookAt(position, position + lookDirection))
	self.model.Parent = workspace

	-- Make the SERVER simulate its physics. Otherwise Roblox hands control to
	-- the nearest player's device, which stutters and can be exploited.
	self.root:SetNetworkOwner(nil)

	self.model:SetAttribute("State", self.state)
	LegendRegistry.register(self.model, self)

	task.spawn(function()
		while not self.destroyed and self.model.Parent do
			local dt = task.wait()
			self:_step(dt)
		end
	end)

	return self
end

function Mossback:Destroy()
	self.destroyed = true
	self.model:Destroy()
end

------------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------------

function Mossback:_setState(name: string, duration: number?)
	self.state = name
	self.stateTime = 0
	self.stateDuration = duration or 0
	self.model:SetAttribute("State", name)
end

function Mossback:_setAntlerGlow(color: Color3?)
	for _, part in self.antlers do
		if color then
			part.Color = color
			part.Material = Enum.Material.Neon
		else
			part.Color = self.antlerLook[part].Color
			part.Material = self.antlerLook[part].Material
		end
	end
end

function Mossback:_stopMoving()
	self.humanoid.WalkSpeed = 0
	self.humanoid:Move(Vector3.zero)
	self.waypoints = nil
end

-- Things our raycasts should look straight through: ourselves and all players.
function Mossback:_ignoreList()
	local list = { self.model }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

-- Returns the root part of the nearest player we could chase (or nil).
function Mossback:_findTarget(): BasePart?
	local best, bestDistance = nil, C.SightRange
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 and not Ragdoll.isRagdolled(character) then
			local distance = flatten(root.Position - self.root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = root, distance
			end
		end
	end
	return best
end

-- True if nothing solid is between us and that position.
function Mossback:_canSee(position: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = self:_ignoreList()
	params.RespectCanCollide = true
	local origin = self.root.Position
	return workspace:Raycast(origin, position - origin, params) == nil
end

------------------------------------------------------------------------------
-- Chase
------------------------------------------------------------------------------

function Mossback:_computePath(targetPosition: Vector3)
	-- Pathfinding wants points near the ground, and our root floats high up.
	local feet = self.root.Position - Vector3.new(0, C.HipHeight + C.BodySize.Y / 2 - 0.5, 0)
	local ok = pcall(function()
		self.path:ComputeAsync(feet, targetPosition)
	end)
	-- ComputeAsync takes a moment. If we got knocked over meanwhile, forget it.
	if self.state ~= "Chase" then
		return
	end
	if ok and self.path.Status == Enum.PathStatus.Success then
		self.waypoints = self.path:GetWaypoints()
		self.waypointIndex = 2 -- waypoint 1 is where we already are
	else
		self.waypoints = nil
	end
end

function Mossback:_chase(targetRoot: BasePart, distance: number, canSee: boolean, dt: number)
	self.humanoid.WalkSpeed = C.WalkSpeed

	if canSee then
		-- Clear view: just walk straight at them.
		self.waypoints = nil
		self.repathTimer = 0
		if distance > C.StopDistance then
			self.humanoid:MoveTo(targetRoot.Position)
		else
			self.humanoid:Move(Vector3.zero)
		end
		return
	end

	-- Something is in the way: ask PathfindingService for a route around it.
	self.repathTimer -= dt
	if self.repathTimer <= 0 then
		self.repathTimer = C.RepathInterval
		self:_computePath(targetRoot.Position)
		if self.state ~= "Chase" then
			return
		end
	end

	local waypoint = self.waypoints and self.waypoints[self.waypointIndex]
	if waypoint then
		self.humanoid:MoveTo(waypoint.Position)
		if flatten(waypoint.Position - self.root.Position).Magnitude < 4 then
			self.waypointIndex += 1
		end
	else
		-- No route found. Walking straight at them is better than standing still.
		self.humanoid:MoveTo(targetRoot.Position)
	end
end

------------------------------------------------------------------------------
-- Antler Charge
------------------------------------------------------------------------------

function Mossback:_beginTelegraph(targetRoot: BasePart)
	self:_stopMoving()
	self.target = targetRoot
	local direction = flatten(targetRoot.Position - self.root.Position)
	if direction.Magnitude > 0.1 then
		self.chargeDirection = direction.Unit
	end
	self:_setAntlerGlow(GLOW_CHARGE)
	self:_setState("Telegraph", C.TelegraphTime)
end

function Mossback:_telegraph(dt: number)
	-- Keep turning to face the target... until the last moment, when the aim
	-- locks. That lock is what makes a well-timed sidestep work.
	local stillAiming = self.stateTime < C.TelegraphTime - C.TelegraphLockTime
	local target = self.target
	if stillAiming and target and target.Parent then
		local direction = flatten(target.Position - self.root.Position)
		if direction.Magnitude > 0.1 then
			self.chargeDirection = direction.Unit
		end
	end

	local position = self.root.Position
	local goal = CFrame.lookAt(position, position + self.chargeDirection)
	self.root.CFrame = self.root.CFrame:Lerp(goal, math.min(1, dt * 12))

	if self.stateTime >= self.stateDuration then
		self:_beginCharge()
	end
end

function Mossback:_beginCharge()
	self.chargeStart = self.root.Position
	self.chargeHits = {}
	self.humanoid.WalkSpeed = C.ChargeSpeed
	self:_setState("Charge")
end

function Mossback:_endCharge(nextState: string, duration: number)
	self:_stopMoving()
	self.chargeCooldown = C.ChargeCooldown
	self:_setAntlerGlow(if nextState == "Stunned" then GLOW_STUN else nil)
	self:_setState(nextState, duration)
end

function Mossback:_hitPlayersInFront()
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.model }

	-- A box a bit bigger than the body, pushed slightly forward (antlers!).
	local boxCFrame = self.root.CFrame * CFrame.new(0, 0, -2)
	local boxSize = C.BodySize + Vector3.new(4, 6, 4)

	for _, part in workspace:GetPartBoundsInBox(boxCFrame, boxSize, params) do
		local character = part:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if player and not self.chargeHits[player] then
			self.chargeHits[player] = true

			-- Fling them forward, up, and a little off to whichever side they were on.
			local right = self.root.CFrame.RightVector
			local toPlayer = part.Position - self.root.Position
			local side = if toPlayer:Dot(right) >= 0 then 1 else -1
			local velocity = self.chargeDirection * C.ChargeKnockback
				+ right * side * C.ChargeKnockback * 0.4
				+ Vector3.new(0, C.ChargeKnockUp, 0)

			Ragdoll.apply(character, C.PlayerRagdollTime, velocity)
		end
	end
end

-- Returns the solid thing right in front of us, if any.
function Mossback:_obstacleAhead(): Instance?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = self:_ignoreList()
	params.RespectCanCollide = true

	local size = Vector3.new(C.BodySize.X - 1, 3, 1)
	local reach = C.BodySize.Z / 2 + 2.5
	local result = workspace:Blockcast(self.root.CFrame, size, self.chargeDirection * reach, params)
	return result and result.Instance
end

function Mossback:_charge()
	self.humanoid:Move(self.chargeDirection)
	self:_hitPlayersInFront()

	local obstacle = self:_obstacleAhead()
	if obstacle then
		if obstacle:HasTag(Config.BigTreeTag) then
			-- WEAKNESS: bonked a big tree. Stunned for twice as long.
			self:_endCharge("Stunned", C.StunTime * C.TreeStunMultiplier)
		else
			self:_endCharge("Recover", C.MissRecoverTime)
		end
		return
	end

	local travelled = flatten(self.root.Position - self.chargeStart).Magnitude
	if travelled >= C.ChargeDistance or self.stateTime >= C.ChargeMaxTime then
		self:_endCharge("Recover", C.MissRecoverTime)
	end
end

------------------------------------------------------------------------------
-- Getting hurt (called by traps, and later by bonks)
------------------------------------------------------------------------------

-- Stand still with yellow antlers for a while.
function Mossback:Stun(duration: number)
	if self.state == "Knockdown" then
		return -- already worse off
	end
	self:_stopMoving()
	self.chargeCooldown = math.max(self.chargeCooldown, 1.5)
	self:_setAntlerGlow(GLOW_STUN)
	self:_setState("Stunned", duration)
end

-- Flop over on its side for a while. Returns true if it worked.
function Mossback:Knockdown(duration: number?): boolean
	if self.state == "Knockdown" then
		return false
	end
	self:_stopMoving()
	self.chargeCooldown = math.max(self.chargeCooldown, 1.5)
	self:_setAntlerGlow(GLOW_STUN)
	self:_setState("Knockdown", duration or C.KnockdownTime)

	-- Tip the body over and drop it to the ground.
	local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
	TweenService:Create(self.bodyJoint, tweenInfo, { C0 = CFrame.Angles(0, 0, math.rad(85)) }):Play()
	TweenService:Create(self.humanoid, tweenInfo, { HipHeight = 0.3 }):Play()
	return true
end

function Mossback:_standUp()
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(self.bodyJoint, tweenInfo, { C0 = CFrame.new() }):Play()
	TweenService:Create(self.humanoid, tweenInfo, { HipHeight = C.HipHeight }):Play()
end

------------------------------------------------------------------------------
-- The brain: runs every frame
------------------------------------------------------------------------------

function Mossback:_step(dt: number)
	self.stateTime += dt
	self.chargeCooldown = math.max(0, self.chargeCooldown - dt)

	local state = self.state

	if state == "Idle" or state == "Chase" then
		local targetRoot = self:_findTarget()
		if not targetRoot then
			if state ~= "Idle" then
				self:_stopMoving()
				self:_setState("Idle")
			end
			return
		end
		if state ~= "Chase" then
			self:_setState("Chase")
		end

		local distance = flatten(targetRoot.Position - self.root.Position).Magnitude
		local canSee = self:_canSee(targetRoot.Position)

		if canSee and distance <= C.ChargeRange and self.chargeCooldown <= 0 then
			self:_beginTelegraph(targetRoot)
		else
			self:_chase(targetRoot, distance, canSee, dt)
		end
	elseif state == "Telegraph" then
		self:_telegraph(dt)
	elseif state == "Charge" then
		self:_charge()
	elseif state == "Recover" or state == "Stunned" or state == "Knockdown" then
		if self.stateTime >= self.stateDuration then
			if state == "Knockdown" then
				self:_standUp()
			end
			self:_setAntlerGlow(nil)
			self:_setState("Chase")
		end
	end
end

return Mossback
