function getInfo()
	return {
		fields = { "pos" }
	}
end

local function distanceSquare(p1, p2)
	return (p1.x - p2.x)*(p1.x - p2.x) + (p1.z - p2.z)*(p1.z - p2.z)
end

local testBuildOrder = Spring.TestBuildOrder
local mexBuildingIdForTesting = UnitDefNames["armmex"].id

return function(toWhat)
	local metalPositions = Sensors.metalPositions()
	local center = toWhat or (Sensors.groupExtents() or {}).center
	if(not metalPositions or not center)then
		return nil
	end
	local selectedMetal, minDistance
	for i = 1, #metalPositions do
		local pos = metalPositions[i]
		if(testBuildOrder(mexBuildingIdForTesting, pos.posX, pos.height, pos.posZ, 2) ~= 0)then
			local distance = distanceSquare({ x = pos.posX, z = pos.posZ }, center)
			if(minDistance == nil or distance < minDistance)then
				selectedMetal = pos
				minDistance = distance
			end
		end
	end
	if(selectedMetal)then
		selectedMetal.pos = Vec3(selectedMetal.posX, selectedMetal.height, selectedMetal.posZ)
	end
	return selectedMetal
end