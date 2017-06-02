function widget:GetInfo()
  return {
    name    = "BtCheat",
    desc    = "Widget to help user set up game situations for debugging behaviours.",
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

program("BtCheat/")

Sanitizer.sanitizeWidget(widget)