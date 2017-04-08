function getInfo()
	return {
		onNoUnits = SUCCESS,
		parameterDefs = {
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
	}
end

function Run(self, unitIds, parameter)
	local angle = 2 * math.pi * math.random()
	local amplitude = 60 + math.random() * 40
	return "S", {
		x = math.cos(angle) * amplitude,
		y = math.sin(angle) * amplitude
	}
end
