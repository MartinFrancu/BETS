function getInfo()
	return {
		onNoUnits = SUCCESS,
		tooltip = "Move to absolute coordinates, specified by 'pos'. If the 'fight' checkbox is checked, then encountered enemy units are fought till death. ",
		parameterDefs = {
			{ 
				name = "pos",
				variableType = "expression",
				componentType = "editBox",
				defaultValue = "{x = 0, z = 0}",
			},
			{ 
				name = "fight",
				variableType = "expression",
				componentType = "checkBox",
				defaultValue = "false",
			}
		}
	}
end

local giveOrderToUnit = Spring.GiveOrderToUnit
local unitIsDead = Spring.GetUnitIsDead

local SHORT_PATH_LEN = 100
local SUBTARGET_TOLEARANCE_SQ = 40 * 40
local TOLERANCE_SQ = 25 * 25
local MOST_DISTANT_UNIT_DIST_SQ = 50 * 50
local LEADER_TOLERANCE_SQ = 50 * 50
local WAYPOINTS_DIST_SQ = 20 * 20

local TOLERANCE_IF_STUCK_SQ = 50 * 50
local CAN_BE_STUCK_FOR_TICKS = 3

local function wrapResVect(f, id)
	if (type(id) ~= "number") then
		return nil
	end
	local x, y, z = f(id)
	if not x then
		return nil
	end
	return Vec3(x, y, z)
end

local function getUnitPos(unitID)
  return wrapResVect(Spring.GetUnitPosition, unitID)
end

local function getUnitDir(unitID)
	return wrapResVect(Spring.GetUnitDirection, unitID)
end

local function direction(from, to)
	--Logger.log("move-command", "direction")
	return (to - from):Normalize()
end

local function dirsEqual(v1, v2)
	--Logger.log("move-command", "dirsEqual")
	local ratioX = v1.x / v2.x
	local ratioZ = v1.z / v2.z
	local tolerance = 0.2
	return math.abs(ratioZ - ratioX) < tolerance
end

local function addToList(list, item)
	list[#list + 1] = item
end


local function ClearState(self)
	--Logger.log("move-command", "Lua command ClearState")
	self.leaderTarget = nil
	self.lastPositions = {}
	self.leaderId = nil
	self.subTargets = {}
	self.finalTargets = {}
	self.finalOrderIssued = false
	self.formationDiffs = {}
	self.lastDistSum = 0
	self.stuckForTicks = 0
	self.leaderWaypoints = {}
	self.lastPositions = {}
end

function New(self)
	Logger.log("move-command", "Running New in move")
	ClearState(self)
end

local function EnsureLeader(self, unitIds)
	--Logger.log("move-command", "EnsureLeader")

	-- check if the leader is still part of this group (i.e. he hasn't been assigned to another tree)
	local leaderInGroup = false
	if self.leaderId then
		for _,unitID in ipairs(unitIds) do
			if self.leaderId == unitID then
				leaderInGroup = true
				break
			end
		end
	end
	Logger.log("move-command", "leaderInGroup - ", leaderInGroup)
	
	local leaderPos = getUnitPos(self.leaderId)
	local leaderTar = self.finalTargets[self.leaderId]
	if leaderInGroup and self.leaderId and not unitIsDead(self.leaderId) and leaderPos ~= nil and leaderTar ~= nil and (leaderPos - leaderTar):LengthSqr() > TOLERANCE_SQ then
		return self.leaderId
	end
	
	self.leaderId = nil
	for i = 1, #unitIds do
		if not unitIsDead(unitIds[i]) then
			self.leaderId = unitIds[i]
			return self.leaderId
		end
	end
	
	--Logger.log("move-command", "=== finalTargets: ", self.finalTargets)

	return self.leaderId
end

local function InitTargetLocations(self, unitIds, parameter)
	--Logger.log("move-command", "InitTargetLocations")
	self.finalTargets = {}
	for i = 1, #unitIds do
		local id = unitIds[i]
		--Logger.log("move-command", "=== pos: ", pos)
		parameter.pos.y = parameter.pos.y or getUnitPos(id).y
		
		local tarPos = parameter.pos + self.formationDiffs[id]
		--Logger.log("move-command", "=== tarPos: ", tarPos)
		self.finalTargets[id] = tarPos
		Logger.log("move-command", "finalTargets[", id ,"] - ", tarPos)
	end
end

local function InitFormationDiffs(self, unitIds)
	--Logger.log("move-command", "InitFormationDiffs")
	
	--[[
	local sum = Vec3(0,0,0)
	for i = 1, #unitIds do
		sum = sum + getUnitPos(unitIds[i])
	end
	
	local centerVec = sum / #unitIds
	--]]
	
	local center = Sensors.groupExtents().center
	local centerVec = Vec3(center.x, getUnitPos(unitIds[1]).y, center.z)
	
	if center then
		centerVec = Vec3(center.x, getUnitPos(self.leaderId).y, center.z)
		Logger.log("move-command", "Vector - ", centerVec)
	else
		centerVec = getUnitPos(self.leaderId)
	end
	
	for i = 1, #unitIds do
		local id = unitIds[i]
		local pos = getUnitPos(id)
		self.formationDiffs[id] = pos - centerVec
	end
end


function Run(self, unitIds, parameter)
	Logger.log("move-command", "Lua MOVE command run, unitIds: ", unitIds, ", pos: ", parameter.pos)
	
	local leader = EnsureLeader(self, unitIds)
	if not leader or not parameter.pos then
		return FAILURE
	end
	
	local springCmd = parameter.fight and CMD.FIGHT or CMD.MOVE
	
	
	local firstTick = false
	if not self.finalTargets[leader] then
		InitFormationDiffs(self, unitIds)
		InitTargetLocations(self, unitIds, parameter)
		local leaderTar = self.finalTargets[self.leaderId]
		--Logger.log("move-command", "=== leaderTar: ", leaderTar)
		giveOrderToUnit(self.leaderId, springCmd, leaderTar:AsSpringVector(), {})
		firstTick = true
	end
	
	local leaderPos = getUnitPos(leader)
	local waypoints = self.leaderWaypoints
	
	--Logger.log("move-command", "waypoints - ", waypoints)
	if (#waypoints == 0 or (leaderPos - waypoints[#waypoints]):LengthSqr() > WAYPOINTS_DIST_SQ) then
		addToList(waypoints, leaderPos)
	end
	
	local leaderDir
	if (firstTick) then
		leaderDir = direction(leaderPos, self.finalTargets[leader])
	else
		leaderDir = direction(waypoints[#waypoints - 3] or waypoints[1], leaderPos) -- average direction in which the leader was moving during the last several ticks 
	end
	leaderDir:Normalize()
	leaderDir = leaderDir * SHORT_PATH_LEN
	
	local leaderDone = (self.finalTargets[leader] - getUnitPos(leader)):LengthSqr() < LEADER_TOLERANCE_SQ or self:UnitIdle(leader)
	-- Logger.log("move-command", "Leader done - ", leaderDone, " dist - ", distanceSq(getUnitPos(leader), self.finalTargets[leader]))
	local done = leaderDone
	
	local issueFinalOrder = false
	if leaderDone and not self.finalOrderIssued then
		self.finalOrderIssued = true
		issueFinalOrder = true
	end
	
	local unitsSize = #unitIds
	local distSum = 0
	local distMax = 0
	
	for i=1, unitsSize do
		local unitID = unitIds[i]
		if unitID ~= leader then
			local curPos = getUnitPos(unitID)
			local curSubTar = self.subTargets[unitID]
			local curDir = direction(getUnitPos(unitID), curSubTar or Vec3(0,0,0))
			
			
			local dist = (self.finalTargets[unitID] - curPos):LengthSqr();
			--Logger.log("move-command", " ------ dist ", dist)
			if dist > distMax then
				distMax = dist
			end
			--Logger.log("move-command", "self.finalTargets[unitID]: ", self.finalTargets[unitID], "; dist: ", dist)
			distSum = distSum + dist
			
			if leaderDone then
				-- go to the target location when leader reaches the target location
				if issueFinalOrder then
					--Logger.log("move-command", "=== Final order ", unitID)
					giveOrderToUnit(unitID, springCmd, self.finalTargets[unitID]:AsSpringVector(), {})
				end
			elseif not curSubTar or self:UnitIdle(unitID) or (curSubTar - curPos):LengthSqr() < SUBTARGET_TOLEARANCE_SQ then --or not dirsEqual(leaderDir, curDir) then
				-- otherwise move a small distance in the direction the leader is facing
				
				local toLeader = leaderPos - curPos
				
				-- vector to fix the formation (if the units would move in the dir this vector specifies and if the leader didn't move, 
				-- the units would be in the same formation they were at the beginning)
				local formationVect = toLeader + self.formationDiffs[unitID] 
				local curSubTar = leaderDir + formationVect + curPos
				
				self.subTargets[unitID] = curSubTar
				giveOrderToUnit(unitID, springCmd, curSubTar:AsSpringVector(), {})
			end
		end
	end
	
	local unitsMovingToTarget = false
	if self.lastDistSum and distSum < self.lastDistSum then
		unitsMovingToTarget = true
		self.stuckForTicks = 0
	else
		if leaderDone then
			self.stuckForTicks = self.stuckForTicks + 1
		end
	end
	self.lastDistSum = distSum
	
	if self.stuckForTicks >= CAN_BE_STUCK_FOR_TICKS then
		if distSum > TOLERANCE_IF_STUCK_SQ * (unitsSize - 1) then -- (unitsSize - 1) == "units without the leader"
			return FAILURE -- units got stuck too far from the target
		else
			return SUCCESS -- stuck close enough -> success
		end
	end
	
	-- Units didn't get stuck - handle normally
	-- Logger.log("move-command", "dist sum - ", distSum, ", max sum - ", (unitsSize - 1) * TOLERANCE_SQ)
	if distSum < (unitsSize - 1) * TOLERANCE_SQ and distMax < MOST_DISTANT_UNIT_DIST_SQ then
		return SUCCESS
	else
		return RUNNING
	end
end


function Reset(self)
	Logger.log("move-command", "Lua command reset")
	ClearState(self)
end
