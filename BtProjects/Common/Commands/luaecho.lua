function getInfo()
	return {
		onNoUnits = RUNNING,
		parameterDefs = {
			{ 
				name = "msg",
				variableType = "string",
				componentType = "editBox",
				defaultValue = "0",
			}
		}
	}
end

function Run(self, unitIds, p)
	Spring.Echo(p.msg)
	return SUCCESS
end