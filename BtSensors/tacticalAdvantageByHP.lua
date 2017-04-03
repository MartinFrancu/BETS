local sensorInfo = {
	name = "tacticalAdvantageByHP",
	desc = "Return advantage value based on sums of HPs of friendly and enemy units in given radius.",
	author = "PepeAmpere",
	date = "2017-19-03",
	license = "notAlicense",
}

local EVAL_PERIOD_DEFAULT = 0 -- this sensor is not caching any values, it evaluates itself on every request
local HEALTH_IF_UNKNOWN = 300

function getInfo()
	return {
		period = EVAL_PERIOD_DEFAULT 
	}
end

-- @description Return ratio of HP of friendly and enemey units
-- @argument center [Vec3] vector which defines center of the scanned area
-- @argument radius [number] max distance scanned
-- @argument onlyOurGroup [boolean|optional] TRUE (default): all our group members in given radius considered, FALSE: all friendly units in given radius considered
-- @return number [number] value between 0 (only enemy units) and 1 (only allied units)
-- @comment 1) There exist "units" table containing all group units in given context
return function(center, radius, onlyOurGroup)
	if (onlyOurGroup == nil) then onlyOurGroup = true end -- in not defined, it is TRUE
	if (onlyOurGroup and units.length == 0) then -- if we have no units
		return 0
	end	
	if (onlyOurGroup and not Sensors.groupEnemyInRange(radius)) then -- no enemies around (the condition of the sensor is stronger than we need, but its ok)
		return 1
	end
	
	-- helper structure in case we consider only our group members (in range) as allies
	local ourGroupMapping = {}
	if (onlyOurGroup) then
		for i=1, units.length do
			ourGroupMapping[units[i]] = true
		end
	end
	
	local alliedHP = 0
	local enemyHP = 0
	
	local allUnitsAround = Spring.GetUnitsInSphere(center.x, center.y, center.z, radius)
	
	for i=1, #allUnitsAround do
		local thisUnitID = allUnitsAround[i]
		local health = Spring.GetUnitHealth(thisUnitID)
		if (health == nil) then health = HEALTH_IF_UNKNOWN end
		local isAllied = Spring.IsUnitAllied(thisUnitID)
		if (isAllied) then
			-- in case of "onlyOurGroup", not all units in radius health is used - other allied units are ignored 
			if (onlyOurGroup) then 
				if (ourGroupMapping[thisUnitID] ~= nil) then -- here we instantly check if unit with given ID is in our group
					alliedHP = alliedHP + health
				end
			else
				alliedHP = alliedHP + health
			end
		else
			enemyHP = enemyHP + health
		end
	end
	
	-- conditions at the beginning make sure we do not divide by zero
	return alliedHP/(alliedHP + enemyHP)
end