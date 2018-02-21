-- Cache the map so that we do not compute it every time this sensor is created (which is done for every group).
GlobalSensorData.mapMetal = GlobalSensorData.mapMetal or (function()
	local environment = setmetatable({ mapMetal = {} }, { __index = _G })
	-- utilize the mex_finder functionality in the Noe AI of NOTA
	VFS.Include("modules/core/ext/mathExt/mathExt.lua", environment, VFS.RAW_FIRST)
	VFS.Include("LuaRules/Configs/noe/modules/tools/mex_finder.lua", environment, VFS.RAW_FIRST)
	environment.PreparemapMetal()
	return environment.mapMetal
end)()
local mapMetal = GlobalSensorData.mapMetal

return function()
	return mapMetal
end