--- Allows user-configurable logging.
-- The messages can be logged using `Spring.Echo`, logged into a common file, logged into separate files or ignored altogether.
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
	local FileTable = Debug.FileTable
	local getGameFrame = Spring.GetGameFrame;
	
	--- Stores the settings with regard to how to log different log-groups.
	--
	-- Instance of @{FileTable} linked with the file `LuaUI/Config/debug_utils_logger.lua`.
	Logger.settings = FileTable:New(LOGGER_SETTINGS)
	
	Logger.SPRING_ECHO = "spring"
	Logger.FUNNEL = "funnel"
	Logger.SEPARATE = "separate"
	Logger.IGNORE = "ignore"
	Logger.ECHO_AND_FUNNEL = Logger.SPRING_ECHO .. "+" .. Logger.FUNNEL

	Logger.LOGTYPE_DEFAULT = 1
	Logger.LOGTYPE_WARNING = 2
	Logger.LOGTYPE_ERROR = 3
	local DEFAULTS_FOR_LOGTYPE = {
		[ Logger.LOGTYPE_DEFAULT ] = Logger.FUNNEL,
		[ Logger.LOGTYPE_WARNING ] = Logger.ECHO_AND_FUNNEL,
		[ Logger.LOGTYPE_ERROR ] = Logger.ECHO_AND_FUNNEL,
	}
	
	local funnelFile = io.open(LOG_PATH .. "funnel-log.txt", "w")
	for k,v in Logger.settings:Pairs() do
		if(string.sub(k,1,string.len("__"))~="__")then
			io.open(LOG_PATH .. "log_" .. k .. ".txt", "w"):close() -- clear the files
		end
	end
	
	--- the __comment field is saved as a comment in the file, see @{FileTable}
	-- @local
	Logger.settings.__comment = [[
Each log-group can have one of the following values:
	"]] .. Logger.SPRING_ECHO .. [[" - uses Spring.Echo
	"]] .. Logger.FUNNEL ..      [[" - logs the message into funnel-log.txt
	"]] .. Logger.SEPARATE ..    [[" - logs the message into a sepearate file log_[log-group name].txt
	"]] .. Logger.IGNORE ..      [[" (or any other string) - ignore the message completely
	the values can be combined by putting "+" between them, eg.: "]] .. Logger.ECHO_AND_FUNNEL .. [[ "
	
Additionally, the log-group can be an array of values that determine how to treat different types of log messages:
	{ [default], [warning], [error] } 
If the array is not large enough (or log-group is missing entirely), the default values are:
	{ "]] .. Logger.FUNNEL .. [[", "]] .. Logger.ECHO_AND_FUNNEL .. [[", "]] .. Logger.ECHO_AND_FUNNEL .. [[" }
This default can be overriden by giving the new default values as settings for log-group "default".
If it is not an array, it is equivalent to an array with a single value.
]]
	
	local writers = {
		[ Logger.SPRING_ECHO ] = function(logGroup, logType, msg)
			Spring.Echo((({
				[ Logger.LOGTYPE_DEFAULT ] = "Log",
				[ Logger.LOGTYPE_WARNING ] = "Warning",
				[ Logger.LOGTYPE_ERROR ] = "ERROR",
			})[logType] or "Log") .. " " .. logGroup .. ": " .. msg)
		end,
		[ Logger.FUNNEL ] = function(logGroup, logType, msg)
			funnelFile:write("[f=" .. string.format("%07d", getGameFrame()) .. ",g=" .. logGroup .. "] " .. (logType == LOGTYPE_ERROR and "ERROR: " or "") .. msg .. "\n")
			funnelFile:flush()
		end,
		[ Logger.SEPARATE ] = function(logGroup, logType, msg)
			local file = io.open(LOG_PATH .. "log_" .. logGroup .. ".txt", "a") 
			file:write("[f=" .. string.format("%07d", getGameFrame()) .. "] " .. (logType == LOGTYPE_ERROR and "ERROR: " or "") .. msg .. "\n")
			file:close()
		end,
	}
	local handlers = {}
	local handlersForGroups = {}

	local function multipairs(t1, t2, ...)
		if(not t2)then
			return ipairs(t1)
		end
			
		local first = true
		local iter1, s1, x1 = ipairs(t1)
		local iter2, s2, x2 = multipairs(t2, ...)
		return function(s, x)
			if(not first)then
				return iter2(s2, x)
			else
				local results = { iter1(s1, x) }
				if(not results[1])then
					first = false
					return iter2(s2, x2)
				else
					return unpack(results)
				end
			end
		end, s1, x1
	end

	function internalLog(logGroup, logType, ...)
		local message = ""
		for i,v in ipairs({ ... }) do
			message = message .. (type(v) == "string" and v or dump(v))
		end
		
		if(not Logger.settings[logGroup])then
			Logger.settings[logGroup] = Logger.FUNNEL
		end
		local settingForGroup = Logger.settings[logGroup]
		if(type(settingForGroup) ~= "table")then
			settingForGroup = { settingForGroup }
		end
		local defaultSetting = Logger.settings["default"] or {};
		if(type(defaultSetting) ~= "table")then
			defaultSetting = { defaultSetting }
		end
		local writerNames = settingForGroup[logType] or defaultSetting[logType] or DEFAULTS_FOR_LOGTYPE[logType] or Logger.ECHO_AND_FUNNEL
		for name in writerNames:gmatch("[^+]+") do
			local writer = writers[name:match "^%s*(.-)%s*$"]
			if(writer)then
				writer(logGroup, logType, message)
			end
		end
		
		for _, handler in multipairs(handlersForGroups[logGroup] or {}, handlers) do
			local results = { handler(logGroup, logType, message) }
			if(results[1])then
				return unpack(results)
			end
		end
	end
	
	--- Logs the message under the supplied log-group.
	function Logger.log(
			logGroup, -- specifies the log-group under which the message belongs
			... -- the rest of the arguments forms the message after their conversion to string
		)
		return internalLog(logGroup, Logger.LOGTYPE_DEFAULT, ...)
	end
	--- Logs the warning message under the supplied log-group.
	function Logger.warn (
			logGroup, -- specifies the log-group under which the message belongs
			... -- the rest of the arguments forms the warning message after their conversion to string
		)
		return internalLog(logGroup, Logger.LOGTYPE_WARNING, ...)
	end
	--- Logs the error message under the supplied log-group.
	function Logger.error(
			logGroup, -- specifies the log-group under which the message belongs
			... -- the rest of the arguments forms the error message after their conversion to string
		)
		return internalLog(logGroup, Logger.LOGTYPE_ERROR, ...)
	end
	
	--- Disables the logging of the specified log-group.
	function Logger.disable(logGroup)
		Logger.settings[logGroup] = Logger.IGNORE
	end
	
	--- Registers a handler function that is launched whenever there is a new log message (of any kind).
	-- Additonal parameters specify whether the handler should be used for all log-groups (if there are none) or just some (the ones specified by the parameters).
	-- A non-nil return value of the handler is used as the return value of @{log}, @{warn} or @{error} functions.
	-- @remark
	function Logger.registerHandler(
			handler, -- 
			... -- list of log-group names that the handler should be used for, or no arguments if it should be applied to all
		)
		local isGlobal = true
		for _, logGroup in ipairs({ ... }) do
			isGlobal = false
			if(not handlerForGroups[logGroup])then
				table.insert(handlerForGroups[logGroup], handler)
			else
				handlerForGroups[logGroup] = { handler }
			end
		end
		
		if(isGlobal)then
			table.insert(handlers, handler)
		end
	end
	
	return Logger
end)