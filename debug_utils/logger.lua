local LOCAL_PATH = LUAUI_DIRNAME .. "Widgets/debug_utils/"
local function include(name)
  return VFS.Include(LOCAL_PATH .. name .. ".lua", nil, VFS.RAW_FIRST)
end

WG = WG or {}
WG.Logger = WG.Logger or (function()
  local logger = {}
  
  local LOGGER_SETTINGS = LUAUI_DIRNAME .. "Config/debug_utils_logger.lua"
  local LOG_PATH = LUAUI_DIRNAME .. "Logs/"
  
  Spring.CreateDir(LOG_PATH)
  
  local dump = include("dump")
  local fileTable = include("fileTable")
  
  logger.settings = fileTable(LOGGER_SETTINGS)
  
  local SPRING_ECHO = "spring"
  local FUNNEL = "funnel"
  local SEPARATE = "separate"
  local IGNORE = "ignore"
  
  local funnelFile = io.open(LOG_PATH .. "funnel-log.txt", "w")
  for k,v in logger.settings:pairs() do
    if(string.sub(k,1,string.len("__"))~="__")then
      io.open(LOG_PATH .. "log_" .. k .. ".txt", "w"):close() -- clear the files
    end
  end
  
  logger.settings.__values = {
    SPRING_ECHO,
    FUNNEL,
    SEPARATE,
    IGNORE,
  }
  
  local handlers = {
    [ SPRING_ECHO ] = function(logGroup, msg)
      Spring.Echo("Log " .. logGroup .. ": " .. msg)
    end,
    [ FUNNEL ] = function(logGroup, msg)
      funnelFile:write("[" .. logGroup .. "]: " .. msg .. "\n")
      funnelFile:flush()
    end,
    [ SEPARATE ] = function(logGroup, msg)
      local file = io.open(LOG_PATH .. "log_" .. logGroup .. ".txt", "a") 
      file:write(msg .. "\n")
      file:close()
    end,
  }
  
  function logger.Log(logGroup, ...)
    local message = ""
    for i,v in ipairs({ ... }) do
      message = message .. dump(v)
    end
    
    if(not logger.settings[logGroup])then
      logger.settings[logGroup] = SPRING_ECHO
    end
      
    local handler = handlers[logger.settings[logGroup]]
    if(handler)then
      handler(logGroup, message)
    end
  end
  
  function logger.Disable(logGroup)
    logger.settings[logGroup] = IGNORE
  end
  
  return logger
end)()

return WG.Logger

