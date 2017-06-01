function widget:GetInfo()
  return {
    name    = "BtCommands",
    desc    = "Custom unit orders definitions.",
    author  = "BETS team",
    date    = "2017-06-02",
    license = "MIT",
    layer   = 0,
    enabled = true
  }
end

local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)
local Sanitizer = Utils.Sanitizer
local program = Utils.program

program("BtCommands/")

Sanitizer.sanitizeWidget(widget)
