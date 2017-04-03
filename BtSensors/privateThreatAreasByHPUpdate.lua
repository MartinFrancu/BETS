local sensorInfo = {
	name = "privateThreatAreasByHPUpdate",
	desc = "Recalculate HP sums in list of specified areas. Ready for sequential evaluation of many areas at the same time.",
	author = "PepeAmpere",
	date = "2017-21-03",
	license = "notAlicense",
}

local EVAL_PERIOD_DEFAULT = 0 -- this sensor is not caching any values, it evaluates itself on every request
local HEALTH_IF_UNKNOWN = 300
local SpringGetUnitsInRectangle = Spring.GetUnitsInRectangle

function getInfo()
	return {
		period = EVAL_PERIOD_DEFAULT 
	}
end

-- @description Recalculate values for specified areas
-- @argument areasSpecs [array] list of areas which should be recalculated 
-- @return newValues [array] array of tables of final HP values
return function(areasSpecs)
	local newValues = {}
	local updateFrame = Spring.GetGameFrame()
	for a=1, #areasSpecs do
		local thisSpecs = areasSpecs[a]
		local allUnits = SpringGetUnitsInRectangle(thisSpecs.topX, thisSpecs.topZ, thisSpecs.bottomX, thisSpecs.bottomZ)
		local alliedHP = 0
		local alliedHPFull = 0
		local enemyHP = 0
		local enemyHPFull = 0
		for u=1, #allUnits do
			local thisUnitID = allUnits[u]
			local isAllied = Spring.IsUnitAllied(thisUnitID)
			local health, fullHealth = Spring.GetUnitHealth(thisUnitID)
			if (health == nil) then health = HEALTH_IF_UNKNOWN end
			if (fullHealth == nil) then fullHealth = HEALTH_IF_UNKNOWN end
			if (isAllied) then
				alliedHP = alliedHP + health
				alliedHPFull = alliedHPFull + fullHealth
			else
				enemyHP = enemyHP + health
				enemyHPFull = enemyHPFull + fullHealth
			end
		end
		newValues[a] = {
			alliedHP = alliedHP,
			alliedHPFull = alliedHPFull,
			enemyHP = enemyHP,
			enemyHPFull = enemyHPFull,
			updateFrame = updateFrame,
		}
	end
	return newValues
end