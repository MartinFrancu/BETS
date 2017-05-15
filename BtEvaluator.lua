function widget:GetInfo()
	return {
		name      = "BtEvaluator",
		desc      = "BtEvaluator loader and message test to this AI.",
		author    = "BETS Team",
		date      = "Sep 20, 2016",
		license   = "BY-NC-SA",
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