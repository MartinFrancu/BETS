--- Located through @{BtUtils.Debug}.Logger.
-- @module Logger
-- @pragma nostrip

-- tag @pragma makes it so that the name of the module is not stripped from the function names

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

local Debug = BtUtils.Debug
return Debug:Assign("Logger", function()
	local Logger = {}
	
	local LOGGER_SETTINGS = LUAUI_DIRNAME .. "Config/debug_utils_logger.lua"
	local LOG_PATH = LUAUI_DIRNAME .. "Logs/"
	
	Spring.CreateDir(LOG_PATH)
	
	local dump = Debug.dump
	local fileTable = Debug.fileTable
	
	--- Stores the settings with regard to how to log different log-groups.
	--
	-- Instance of @{fileTable} linked with the file `LuaUI/Config/debug_utils_logger.lua`.
	Logger.settings = fileTable(LOGGER_SETTINGS)
	
	local SPRING_ECHO = "spring"
	local FUNNEL = "funnel"
	local SEPARATE = "separate"
	local IGNORE = "ignore"
	
	local funnelFile = io.open(LOG_PATH .. "funnel-log.txt", "w")
	for k,v in Logger.settings:Pairs() do
		if(string.sub(k,1,string.len("__"))~="__")then
			io.open(LOG_PATH .. "log_" .. k .. ".txt", "w"):close() -- clear the files
		end
	end
	
	--- the __comment field is saved as a comment in the file, see @{fileTable}
	-- @local
	Logger.settings.__comment = [[
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
	
	--- Logs the message under the supplied log-group.
	function Logger.log(
			logGroup, -- specifies the log-group under which the message belongs
			... -- the rest of the arguments forms the message after their conversion to string
		)
		local message = ""
		for i,v in ipairs({ ... }) do
			message = message .. (type(v) == "string" and v or dump(v))
		end
		
		if(not Logger.settings[logGroup])then
			Logger.settings[logGroup] = FUNNEL
		end
			
		local handler = handlers[Logger.settings[logGroup]]
		if(handler)then
			handler(logGroup, message)
		end
	end
	
	--- Disables the logging of the specified log-group.
	function Logger.disable(logGroup)
		Logger.settings[logGroup] = IGNORE
	end
	
	return Logger
end)