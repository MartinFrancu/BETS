function getInfo()
	return {
		onNoUnits = RUNNING,
		parameterDefs = {
			{ 
				name = "condition",
				variableType = "expression",
				componentType = "editBox",
				defaultValue = "true",
			}
		}
	}
end

function Run(self, unitIds, parameter)
	local cond = parameter.condition
	if not cond then
		return RUNNING
	end
	return SUCCESS
end
