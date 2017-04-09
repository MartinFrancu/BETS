function getInfo()
	return {
		onNoUnits = RUNNING,
		parameterDefs = {
			{ 
				name = "msg",
				variableType = "expression",
				componentType = "editBox",
				defaultValue = "",
			}
		}
	}
end

function Run(self, unitIds, p)
	Spring.Echo(p.msg)
	return SUCCESS
end