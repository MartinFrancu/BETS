function getInfo()
	return {
		period = 60
	}
end

local getNearestEnemy = Spring.GetUnitNearestEnemy
local visibleUnits = {}
local teamID = Spring.GetLocalTeamID()
local GetUnitDefID = Spring.GetUnitDefID

-- tables to be used
-- units
-- UnitDefs
return function()
	if(units.length == 0)then
		return nil
	end
	
	local seeEnemy = false
	for i=1, units.length do
		local enemyID = getNearestEnemy(units[i], UnitDefs[ GetUnitDefID(units[i]) ].losRadius, true)
		if(enemyID) then
			seeEnemy = true
		end
	end
	
	return { any = seeEnemy }
end