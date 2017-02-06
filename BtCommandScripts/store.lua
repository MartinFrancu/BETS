function getInfo()
	return {
		onNoUnits = RUNNING,
		parameterDefs = {
			{ 
				name = "var",
				variableType = "expression",
				componentType = "editBox",
				defaultValue = "0",
			},
			{ 
				name = "value",
				variableType = "expression",
				componentType = "editBox",
				defaultValue = "0",
			}
		}
	}
end

function Run(self, unitIds, parameter)
	return SUCCESS, {
		var = parameter.value
	}
end
