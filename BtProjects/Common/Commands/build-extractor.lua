if(_G.loadMethods)then
	_G:loadMethods("Common.build")
end

local oldRun = Run
local oldReset = Reset
local getUnitDefId = Spring.GetUnitDefID

function getInfo()
	return {
		onNoUnits = SUCCESS,
		parameterDefs = {
			{ 
				name = "pos",
				variableType = "expression",
				componentType = "editBox",
				defaultValue = "nil",
			}
		}
	}
end

local function getBuilding(unitIds)
	local buildingCounts = {}
	for i = 1, #unitIds do
		local defId = getUnitDefId(unitIds[i])
		local def = UnitDefs[defId]
		
		local buildOptions = def.buildOptions
		
		for i = 1, #buildOptions do
			local optId = buildOptions[i]
			local buildingDef = UnitDefs[optId]
			
			
			if buildingDef and buildingDef.isExtractor then
				-- Logger.log("build-extractor", "Building name - ", buildingDef.name)
				local buildingName = buildingDef.name
				local optCount = buildingCounts[buildingName]
				if not optCount then
					buildingCounts[buildingName] = 1
				else
					buildingCounts[buildingName] = optCount + 1
				end
			end
		end
	end
	
	local mostCommon,mostCommonCount = nil,0
	for k,v in pairs(buildingCounts) do 
		if v > mostCommonCount then
			mostCommon = k
			mostCommonCount = v
		end
	end
	
	return mostCommon
end



function Run(self, unitIds, parameter)
	if not self.building then
		self.building = getBuilding(unitIds)
	end
	if not self.building then
		Logger.error("build-extractor", "No units in the group can build an extractor.")
		return FAILURE
	end
	
	parameter.building = self.building
	return oldRun(self, unitIds, parameter)
end

function Reset(self)
	self.building = nil
	oldReset(self)
end