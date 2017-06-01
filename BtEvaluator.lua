function widget:GetInfo()
	return {
		name      = "BtEvaluator",
		desc      = "BtEvaluator proxy for native AI and Lua script evaluator.",
		author    = "BETS Team",
		date      = "2017-06-02",
		license   = "MIT",
		layer     = 0,
		enabled   = true, --  loaded by default?
		version   = version,
	}
end

local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)
local Sanitizer = Utils.Sanitizer
local program = Utils.program

program("BtEvaluator/")

Sanitizer.sanitizeWidget(widget)