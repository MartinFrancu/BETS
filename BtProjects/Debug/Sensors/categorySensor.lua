return function(category)
	local count = 0
	for i = 1, units.length do
		local unitDefId = Spring.GetUnitDefID(units[i])
		for name, data in pairs(category) do
			if(data.id == unitDefId)then
				count = count + 1
				break
			end
		end
		--[[
		if(category[unitDefId])then
			count = count + 1
		end
		]]
	end
	return count
end