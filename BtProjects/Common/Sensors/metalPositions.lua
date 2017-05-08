GlobalSensorData.mapMetal = GlobalSensorData.mapMetal or (function()
	local environment = setmetatable({ mapMetal = {} }, { __index = _G })
	VFS.Include("LuaRules/modules/core/ext/mathExt/mathExt.lua", environment, VFS.RAW_FIRST)
	VFS.Include("LuaRules/Configs/noe/modules/tools/mex_finder.lua", environment, VFS.RAW_FIRST)
	environment.PreparemapMetal()
	return environment.mapMetal
end)()
local mapMetal = GlobalSensorData.mapMetal

return function()
	return mapMetal
end