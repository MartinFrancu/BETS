local LOCAL_PATH = LUAUI_DIRNAME .. "Widgets/debug_utils/"
local function include(name)
  return VFS.Include(LOCAL_PATH .. name .. ".lua", nil, VFS.RAW_FIRST)
end

local dump = include("dump")

local function fileTable(path)
  local t = VFS.FileExists(path) and VFS.Include(path, {}, VFS.RAW_FIRST) or {}
  local result = { pairs = function(r) return pairs(t) end }
  local mt = {
    __metatable = "locked",
    __tostring = function(r) return tostring(t) end,
    __pairs = result.pairs,
    __index = t,
    __newindex = function(r, k, v)
      t[k] = v
      local outputFile = io.open(path, "w")
      outputFile:write("return " .. dump(t, 10) .. "\n")
      outputFile:close()
    end,
  }
  setmetatable(result, mt)
  return result
end

return fileTable