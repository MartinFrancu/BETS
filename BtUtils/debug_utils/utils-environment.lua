if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

local Debug = BtUtils.Debug
return Debug:Assign("_UtilsEnvironment", function()
	local rawTable = Debug.rawTable
	local currentEnvironment = getfenv(1) -- retrieves the environment of the current function, which should be the environment of BtUtils
	
	return rawTable(currentEnvironment)
end)