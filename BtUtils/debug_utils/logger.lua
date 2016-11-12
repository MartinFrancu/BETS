if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

local Debug = BtUtils.Debug
Debug:Assign("Logger", function()
	local logger = {}
	
	local LOGGER_SETTINGS = LUAUI_DIRNAME .. "Config/debug_utils_logger.lua"
	local LOG_PATH = LUAUI_DIRNAME .. "Logs/"
	
	Spring.CreateDir(LOG_PATH)
	
	local dump = Debug.dump
	local fileTable = Debug.fileTable
	
	logger.settings = fileTable(LOGGER_SETTINGS)
	
	local SPRING_ECHO = "spring"
	local FUNNEL = "funnel"
	local SEPARATE = "separate"
	local IGNORE = "ignore"
	
	local funnelFile = io.open(LOG_PATH .. "funnel-log.txt", "w")
	for k,v in logger.settings:Pairs() do
		if(string.sub(k,1,string.len("__"))~="__")then
			io.open(LOG_PATH .. "log_" .. k .. ".txt", "w"):close() -- clear the files
    end
	end
	
	logger.settings.__comment = [[
Each log-group can have one of the following values:
	"]] .. SPRING_ECHO .. [[" - uses Spring.Echo
	"]] .. FUNNEL ..      [[" - logs the message into funnel-log.txt
	"]] .. SEPARATE ..    [[" - logs the message into a sepearate file log_[log-group name].txt
	"]] .. IGNORE ..      [[" (or any other string) - ignore the message completely
]]
	
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
	
	function logger.log(logGroup, ...)
		local message = ""
		for i,v in ipairs({ ... }) do
			message = message .. (type(v) == "string" and v or dump(v))
		end
		
		if(not logger.settings[logGroup])then
			logger.settings[logGroup] = SPRING_ECHO
		end
			
		local handler = handlers[logger.settings[logGroup]]
		if(handler)then
			handler(logGroup, message)
		end
	end
	
	function logger.disable(logGroup)
		logger.settings[logGroup] = IGNORE
	end
	
	return logger
end)

return Debug.Logger