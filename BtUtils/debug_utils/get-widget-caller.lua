---
-- @module getWidgetCaller

local getWidgetCaller

local MAX_FAILURE_COUNT = 5

---
function getWidgetCaller()
	local level = 3 -- start with the environment of the caller
	local failureCount = 0
	local success, env
	repeat
		success, env = pcall(getfenv, level)
		if(not success)then
			failureCount = failureCount + 1
			if(failureCount >= MAX_FAILURE_COUNT)then
				error("Maximum failure count reached. getWidgetCaller was unable to find the caller widget.")
			end
		else
			failureCount = 0
		end
		level = level + 1
	until not env or env.widget
	
	return success and env and env.widget or nil
end

return getWidgetCaller