local Logger = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/debug_utils/logger.lua", nil, VFS.RAW_FIRST)

local cmdClass = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtCommandScripts/command.lua", nil, VFS.RAW_FIRST)

local testBuildOrder = Spring.TestBuildOrder
local giveOrderToUnit = Spring.GiveOrderToUnit

function cmdClass.getParameterDefs()
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

local buildingIds = {
	["arm"] = {
		["mex"] = "armmex",
	},
	["core"] = {
		["mex"] = "cormex",
	},
}

function cmdClass:New()
	self.kind = select(5, Spring.GetTeamInfo(Spring.GetLocalTeamID()))
end

function cmdClass:Run(unitIds, parameter)
	local buildingName = (buildingIds[self.kind] or {})[parameter.building]
	if(not buildingName)then
		Logger.error("build", "Unknown building identifier: '", parameter.building, "'")
		return "F"
	end
	local buildingId = (UnitDefNames[buildingName] or {}).id
	if(not buildingId)then
		Logger.error("build", "Couldn't translate building name '", buildingName , "' to id.")
		return "F"
	end
	
	if(not self.inProgress)then
		local pos = parameter.pos
		if(testBuildOrder(buildingId, pos.posX, pos.height, pos.posZ, 2) ~= 0)then
			for i = 1, #unitIds do
				local unitID = unitIds[i]
				giveOrderToUnit(unitID, -buildingId, { pos.posX, pos.height, pos.posZ }, {})
			end
			self.inProgress = true
			return "R"
		else
			Logger.error("build", "Couldn't build in position: ", pos)
			return "F"
		end
	else
		for i = 1, #unitIds do
			local unitID = unitIds[i]
			if not self:UnitIdle(unitID) then
				return "R"
			end
		end
		self.inProgress = nil
		return "S"
	end
end

function cmdClass:Reset()
	self.inProgress = nil
end

return cmdClass