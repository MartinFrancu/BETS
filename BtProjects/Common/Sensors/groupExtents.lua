function getInfo()
	return {
		period = 60,
		fields = { "center", "maxDistance" }
	}
end

local getPosition = Spring.GetUnitPosition;

local function euclidianDistance(x, z)
	return math.sqrt(x*x + z*z)
end

return function()
	if(units.length == 0)then
		return {}
	end
	
	local centerX, centerY, centerZ = getPosition(units[1])
	for i = 2, units.length do
		local x, _, z = getPosition(units[i])
		centerX = centerX + x
		centerZ = centerZ + z
	end
	centerX = centerX / units.length
	centerZ = centerZ / units.length

	local maxDistance = 0
	for i = 1, units.length do
		local x, _, z = getPosition(units[i])
		local distance = euclidianDistance(centerX - x, centerZ - z)
		if(distance > maxDistance)then
			maxDistance = distance
		end
	end
	
	return { center = Vec3(centerX, centerY, centerZ), maxDistance = maxDistance }
end