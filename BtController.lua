function widget:GetInfo()
  return {
    name    = "BtController",
    desc    = "Widget to intermediate players commands to Behaviour Tree Evaluator.",
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

program("BtController/")

Sanitizer.sanitizeWidget(widget)