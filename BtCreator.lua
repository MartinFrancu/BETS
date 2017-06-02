function widget:GetInfo()
	return {
		name    = "BtCreator",
		desc    = "Behaviour Tree Editor for creating complex behaviours of groups of units.",
		author  = "BETS Team",
		date    = "2017-06-02",
		license = "MIT",
		layer   = 0,
		enabled = true
	}
end

local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)
local Sanitizer = Utils.Sanitizer
local program = Utils.program

program("BtCreator/")

Sanitizer.sanitizeWidget(widget)