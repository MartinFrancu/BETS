function getInfo()
	return {
		onNoUnits = RUNNING,
		parameterDefs = {
			{ 
				name = "msg",
				variableType = "expression",
				componentType = "editBox",
				defaultValue = "hello",
			}
		}
	}
end

function Run(self, unitIds, p)
	Spring.Echo(p.msg)
	return SUCCESS
end