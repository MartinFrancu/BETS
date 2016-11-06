local LOCAL_PATH = LUAUI_DIRNAME .. "Widgets/debug_utils/"
local function include(name)
  return VFS.Include(LOCAL_PATH .. name .. ".lua", nil, VFS.RAW_FIRST)
end

return include("logger"), include("dump"), include("copyTable"), include("fileTable")