--- BtUtils.Debug
-- @module BtUtils.Debug

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

return BtUtils:Assign("Debug", function()
	--- a.
	-- @table Debug
	local locators = {
		Logger = "logger", --- @{Logger}
		dump = "dump",
		copyTable = "copyTable",
		fileTable = "fileTable",
	}

	return (BtUtils.Locator:New({}, locators, "debug_utils/"))
end)
