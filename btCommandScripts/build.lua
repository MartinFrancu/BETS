

--local testBuildOrder = Spring.TestBuildOrder
--local giveOrderToUnit = Spring.GiveOrderToUnit

function getParameterDefs()
	return {
		{ 
			name = "pos",
			variableType = "expression",
			componentType = "editBox",
			defaultValue = "nil",
		},
		{
			name = "building",
			variableType = "string",
			componentType = "editBox",
			defaultValue = "\"mex\"",
		}
	}
end

function New(self)
	self.buildingIds = {
		["arm"] = {
			["mex"] = "armmex",
		},
		["core"] = {
			["mex"] = "cormex",
		},
	}
	self.kind = select(5, Spring.GetTeamInfo(Spring.GetLocalTeamID()))
end

function Run(self, unitIds, parameter)
	local buildingName = (self.buildingIds[self.kind] or {})[parameter.building]
	if(not buildingName)then
		Logger.error("build", "Unknown building identifier: '", parameter.building, "'")
		return FAILURE
	end
	local buildingId = (UnitDefNames[buildingName] or {}).id
	if(not buildingId)then
		Logger.error("build", "Couldn't translate building name '", buildingName , "' to id.")
		return FAILURE
	end
	
	if(not self.inProgress)then
		local pos = parameter.pos
		if(Spring.TestBuildOrder(buildingId, pos.posX, pos.height, pos.posZ, 2) ~= 0)then
			for i = 1, #unitIds do
				local unitID = unitIds[i]
				Spring.GiveOrderToUnit(unitID, -buildingId, { pos.posX, pos.height, pos.posZ }, {})
			end
			self.inProgress = true
			return RUNNING
		else
			Logger.error("build", "Couldn't build in position: ", pos)
			return FAILURE
		end
	else
		for i = 1, #unitIds do
			local unitID = unitIds[i]
			if not self:UnitIdle(unitID) then
				return RUNNING
			end
		end
		self.inProgress = nil
		Logger.log("command", "======== Run - Success")
		return SUCCESS
	end
end

function Reset(self)
	self.inProgress = nil
end
