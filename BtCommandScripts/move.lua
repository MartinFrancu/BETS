function getParameterDefs()
	return {
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
end


function New(self)
	Logger.log("command", "Running New in move")
	self.targets = {}
	self.n = 0
	self.lastPositions = {}
	
	self.UnitMoved = function(self, unitID)
		x, _, z = Spring.GetUnitPosition(unitID)
		lastPos = self.lastPositions[unitID]
		
		if not lastPos then
			lastPos = {x,z}
			self.lastPositions[unitID] = lastPos
			Logger.log("move-command","unit:", unitID, "x: ", x ,", z: ", z)
			return true
		end
		
		Logger.log("move-command", "unit:", unitID, " x: ", x ,", lastX: ", lastPos[1], ", z: ", z, ", lastZ: ", lastPos[2])
		moved = x ~= lastPos[1] or z ~= lastPos[2]
		self.lastPositions[unitID] = {x,z}
		return moved
	end
end

function Run(self, unitIds, parameter)
	dx = parameter.x
	dz = parameter.y
	
	Logger.log("move-command", "Lua MOVE command run, unitIds: ", unitIds, ", dx: " .. dx .. ", dz: " .. dz .. ", tick: "..self.n)
	self.n = self.n + 1
	done = true
	noneMoved = true
	
	x,y,z = 0,0,0
	for i = 1, #unitIds do
		unitID = unitIds[i]
		x, y, z = Spring.GetUnitPosition(unitID)
		
		tarX = x + dx
		tarZ = z + dz
		
		if not self.targets[unitID] then
			self.targets[unitID] = {tarX,y,tarZ}
			Spring.GiveOrderToUnit(unitID, CMD.MOVE, self.targets[unitID], {})
			done = false
			noneMoved = false
		else
			Logger.log("move-command", "AtX: " .. x .. ", TargetX: " .. self.targets[unitID][1] .. " AtZ: " .. z .. ", TargetZ: " .. self.targets[unitID][2])
			if not self:UnitIdle(unitID) then
				done = false
			end
			if self:UnitMoved(unitID) then -- cannot get to target location
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
	self.n = 0
	self.lastPositions = {}
end