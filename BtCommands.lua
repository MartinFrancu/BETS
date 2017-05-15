function widget:GetInfo()
  return {
    name    = "BtCommands",
    desc    = "Custom unit commands definitions. ",
    author  = "BETS team",
    date    = "02-19-2017",
    license = "GNU GPL v2",
    layer   = 0,
    enabled = true
  }
end

local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)
local Sanitizer = Utils.Sanitizer
local program = Utils.program

program("BtCommands/")

Sanitizer.sanitizeWidget(widget)
