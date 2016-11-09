if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

BtUtils:Assign("Debug", function()
  local locators = {
    Logger = "logger",
    dump = "dump",
    copyTable = "copyTable",
    fileTable = "fileTable",
  }

  return (BtUtils.Locator:New({}, locators, "debug_utils/"))
end)

return BtUtils.Debug