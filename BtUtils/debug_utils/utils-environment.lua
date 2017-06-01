--- Provides @{rawTable} view to the environment of BtUtils.
-- BtUtils uses its own environment so that any mistakenly global slot in it does not populate the global environment of the original includer and to protect the original includer of BtUtils from getWidgetCaller, when it is used from within BtUtils.
-- @module _UtilsEnvironment

--- The BtUtils environment.
-- Useful for inspection purposes.
-- @table _UtilsEnvironment.
-- @field ... Ideally nothing.

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

local Debug = BtUtils.Debug
return Debug:Assign("_UtilsEnvironment", function()
	local rawTable = Debug.rawTable
	local currentEnvironment = getfenv(1) -- retrieves the environment of the current function, which should be the environment of BtUtils
	
	return rawTable(currentEnvironment)
end)