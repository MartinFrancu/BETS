local sensorInfo = {
	name = "groupEnemyInRange",
	desc = "Answers natural question: Are there any enemies in given range from all units of the group?",
	author = "PepeAmpere",
	date = "2017-19-03",
	license = "notAlicense",
}

local EVAL_PERIOD_DEFAULT = 0 -- this sensor is not caching any values, it evaluates itself on every request

local SpringGetNearestEnemy = Spring.GetUnitNearestEnemy

function getInfo()
	return {
		period = EVAL_PERIOD_DEFAULT 
	}
end

-- @description Enemies in range?
-- @argument range [number] max distance scanned from each unit of the group
-- @return enemyInRange [boolean] answer for the question
-- @comment "units" table containing all group units in given context
return function(range)
	if(units.length == 0)then
		return nil
	end

	local enemyInRange = false
	for i=1, units.length do
		local enemyID = SpringGetNearestEnemy(units[i], range, true)
		if(enemyID) then
			enemyInRange = true
		end
	end
	return enemyInRange
end