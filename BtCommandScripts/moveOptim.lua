function getInfo()
	return {
		onNoUnits = SUCCESS,
		parameterDefs = {
			{
				name = "x",
				variableType = "number",
				componentType = "editBox",
				defaultValue = "0",
			},
			{
				name = "y",
				variableType = "number",
				componentType = "editBox",
				defaultValue = "0",
			}
		}
	}
end

local giveOrderToUnit = Spring.GiveOrderToUnit
--local getUnitDir = Spring.GetUnitDirection
local unitIsDead = Spring.GetUnitIsDead

local SHORT_PATH_LEN = 100
local SUBTARGET_TOLEARANCE_SQ = 30*30
local TOLERANCE_SQ = 30*30
local MOST_DISTANT_UNIT_DIST_SQ = 50*50
local LEADER_TOLERANCE_SQ = 50 * 50
local WAYPOINTS_DIST_SQ = 20 * 20

local function wrapResVect(f, id)
	local x, y, z = f(id)
	return { x, y, z}
end

local function getUnitPos(unitID)
  return wrapResVect(Spring.GetUnitPosition, unitID)
end

local function getUnitDir(unitID)
	return wrapResVect(Spring.GetUnitDirection, unitID)
end

local function makeVector(from, to)
	return{to[1] - from[1], to[2] - from[2], to[3] - from[3]}
end

local function direction(from, to)
	local dir = makeVector(from, to)
	local len = math.sqrt(dir[1] * dir[1] + dir[2] * dir[2] + dir[3] * dir[3])
	-- normalize vector
	return {dir[1] / len, dir[2] / len, dir[3] / len }
end

local function dirsEqual(v1, v2)
	local ratioX = v1[1] / v2[1]
	local ratioZ = v1[3] / v2[3]
	local tolerance = 0.05
	return math.abs(ratioZ - ratioX) < tolerance
end

local function distanceSq(pos1, pos2)
	local dist = 0
	for i = 1,3 do
		local d = pos1[i] - pos2[i]
		dist = dist + d * d
	end
	return dist
end

local function addToList(list, item)
	list[#list + 1] = item
end

local function vectSum(...)
	local sum = {0, 0, 0}
	for _,vect in ipairs(arg) do
		sum = {sum[1] + vect[1], sum[2] + vect[2], sum[3] + vect[3]}
	end
	return sum
end

local function UnitMoved(self, unitID, x, _, z)
	local lastPos = self.lastPositions[unitID]
	if not lastPos then
		lastPos = {x = x, z = z}
		self.lastPositions[unitID] = lastPos
		Logger.log("move-command","unit:", unitID, "x: ", x ,", z: ", z)
		return true
	end
	Logger.log("move-command", "unit:", unitID, " x: ", x ,", lastX: ", lastPos.x, ", z: ", z, ", lastZ: ", lastPos.z)
	moved = x ~= lastPos.x or z ~= lastPos.z
	self.lastPositions[unitID] = {x = x, z = z}
	return moved
end

function New(self)
	Logger.log("command", "Running New in move")
	self.lastPositions = {}
	self.subTargets = {}
	self.finalTargets = {}
	self.formationDiffs = {}
	self.leaderWaypoints = {}
end

local lastLeaderPos

local function EnsureLeader(self, unitIds)
	if self.leaderId and not unitIsDead(self.leaderId) and distanceSq(getUnitPos(self.leaderId), self.finalTargets[self.leaderId]) > TOLERANCE_SQ then
		return self.leaderId
	end
	
	self.leaderId = nil
	for i = 1, #unitIds do
		if not unitIsDead(unitIds[i]) then
			self.leaderId = unitIds[i]
			break
		end
	end
	
	--Logger.log("move-command", "=== finalTargets: ", self.finalTargets)
	local tar = self.finalTargets[self.leaderId]
	--Logger.log("move-command", "=== tar: ", tar)
	giveOrderToUnit(self.leaderId, CMD.MOVE, tar, {})
	return self.leaderId
end

local function InitTargetLocations(self, unitIds, parameter)
	self.finalTargets = {}
	local leaderPos = getUnitPos(self.leaderId)
	
	for i = 1, #unitIds do
		local id = unitIds[i]
		local pos = getUnitPos(id)
		--Logger.log("move-command", "=== pos: ", pos)
		local tarPos = { pos[1] + parameter.x, pos[2], pos[3] + parameter.y }
		--Logger.log("move-command", "=== tarPos: ", tarPos)
		self.finalTargets[id] = tarPos
		
		self.formationDiffs[id] = math.sqrt(distanceSq(leaderPos, pos))
	end
end


function Run(self, unitIds, parameter)
	Logger.log("move-command", "Lua MOVE command run, unitIds: ", unitIds, ", parameter.x: " .. parameter.x .. ", parameter.y: " .. parameter.y)
	
	local leader = EnsureLeader(self, unitIds)
	if not leader then
		return FAILURE
	end
	
	
	local firstTick = false
	if not self.finalTargets then
		InitTargetLocations(self, unitIds, parameter)
		firstTick = true
	end
	
	
	local leaderPos = getUnitPos(leader)
	local waypoints = self.leaderWaypoints
	
	if (#waypoints == 0 or distanceSq(leaderPos, waypoints[#waypoints]) > WAYPOINTS_DIST_SQ) then
		addToList(waypoints, leaderPos)
	end
	
	local leaderDir
	if (firstTick) then
		leaderDir = direction(leaderPos, self.finalTargets[leader])
	else
		leaderDir = direction(waypoints[#waypoints - 3] or waypoints[1], leaderPos)
	end
	
	local leaderDone = distanceSq(getUnitPos(leader), self.finalTargets[leader]) < LEADER_TOLERANCE_SQ
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
			local curDir = direction(getUnitPos(unitID), curSubTar or {0,0,0})
			
			local dist = distanceSq(curPos, self.finalTargets[unitID])
			--Logger.log("move-command", " ------ dist ", dist)
			if dist > distMax then
				distMax = dist
			end
			distSum = distSum + dist
			
			if leaderDone then
				-- go to the target location when leader reaches the target location
				if issueFinalOrder then
					--Logger.log("move-command", "=== Final order ", unitID)
					giveOrderToUnit(unitID, CMD.MOVE, self.finalTargets[unitID], {})
				end
			elseif not curSubTar or distanceSq(curPos, curSubTar) < SUBTARGET_TOLEARANCE_SQ or not dirsEqual(leaderDir, curDir) then
				-- otherwise move a small distance in the direction the leader is facing
				
				local toLeader = makeVector(curPos, leaderPos)
				
				curSubTar = vectSum(curPos, toLeader, leaderDir, formationDiffs[unitID])
				-- curSubTar = {curPos[1] + leaderDir[1] * SHORT_PATH_LEN, curPos[2], curPos[3] + leaderDir[3] * SHORT_PATH_LEN}
				self.subTargets[unitID] = curSubTar
				giveOrderToUnit(unitID, CMD.MOVE, curSubTar, {})
			end
		end
	end
	
	-- Logger.log("move-command", "dist sum - ", distSum, ", max sum - ", (unitsSize - 1) * TOLERANCE_SQ)
	if distSum < (unitsSize - 1) * TOLERANCE_SQ and distMax < MOST_DISTANT_UNIT_DIST_SQ then
		return SUCCESS
	--elseif noneMoved then
	--	return FAILURE
	else
		return RUNNING
	end
end

function Reset(self)
	Logger.log("move-command", "Lua command reset")
	self.leaderTarget = nil
	self.lastPositions = {}
	self.leaderId = nil
	self.subTargets = {}
	self.finalTargets = nil
	self.finalOrderIssued = false
	self.formationDiffs = {}
end