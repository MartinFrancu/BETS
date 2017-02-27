function getInfo()
	return {
		onNoUnits = SUCCESS,
		issuesOrders = true,
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

local getUnitPos = Spring.GetUnitPosition
local giveOrderToUnit = Spring.GiveOrderToUnit

local function UnitMoved(self, unitID, x, _, z)
	-- local x, _, z = getUnitPos(unitID)
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
	self.targets = {}
	self.lastPositions = {}
end

function Run(self, unitIds, parameter)
	Logger.log("move-command", "Lua MOVE command run, unitIds: ", unitIds, ", parameter.x: " .. parameter.x .. ", parameter.y: " .. parameter.y)
	local done = true
	local noneMoved = true
	local x,y,z = 0,0,0
	local unitID
	for i=1,#unitIds do
		unitID = unitIds[i]
		x, y, z = getUnitPos(unitID)
		if not self.targets[unitID] then
			self.targets[unitID] = {x + parameter.x, y, z + parameter.y}
			giveOrderToUnit(unitID, CMD.MOVE, self.targets[unitID], {})
			done = false
			noneMoved = false
		else
			Logger.log("move-command", "AtX: " .. x .. ", TargetX: " .. self.targets[unitID][1] .. " AtZ: " .. z .. ", TargetZ: " .. self.targets[unitID][2])
			if not self:UnitIdle(unitID) then
				done = false
			end
			if UnitMoved(self, unitID, x, y, z) then -- cannot get to target location
				noneMoved = false
			end
		end
	end
	if done then
		return SUCCESS
	elseif noneMoved then
		return FAILURE
	else
		return RUNNING
	end
end

function Reset(self)
	Logger.log("move-command", "Lua command reset")
	self.targets = {}
	self.lastPositions = {}
end