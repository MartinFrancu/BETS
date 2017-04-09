function getInfo()
	return {
		onNoUnits = RUNNING,
		parameterDefs = {}
	}
end

function Run(self, unitIds)
	Spring.Echo("flipSensor: " .. dump(Sensors.flipSensor()))
	Spring.Echo("groupExtents: " .. dump(Sensors.Common.groupExtents()))
	return SUCCESS
end