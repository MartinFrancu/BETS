function getParameterDefs()
	return {
		{ 
			name = "msg",
			variableType = "string",
			componentType = "editBox",
			defaultValue = "0",
		}
	}
end

function Run(self, unitIds, p)
	Spring.Echo(dump(p.msg))
	return SUCCESS
end