--- Sub-library of @{BtUtils} containing useful tools and functions for debugging purposes.
-- Any use of modules in this library should be removable from the main code that is intended for release.
-- Locatable through @{BtUtils}.
-- @locator BtUtils.Debug

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

return BtUtils:Assign("Debug", function()
	--- Locatable modules and classes.
	-- @table Debug.
	local locators = {
		Logger = "logger", -- @{Logger}
		dump = "dump", -- @{dump}
		copyTable = "copyTable", -- @{copyTable}
		FileTable = "fileTable", -- @{FileTable}
	}

	-- the return value is in brackets as we do not want to return our locators map
	return (BtUtils.Locator:New({}, locators, "debug_utils/"))
end)
