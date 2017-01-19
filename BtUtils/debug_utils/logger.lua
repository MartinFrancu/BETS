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
	
	local SPRING_ECHO = "spring"
	local FUNNEL = "funnel"
	local SEPARATE = "separate"
	local IGNORE = "ignore"
	local ECHO_AND_FUNNEL = SPRING_ECHO .. "+" .. FUNNEL

	local LOGTYPE_DEFAULT = 1
	local LOGTYPE_WARNING = 2
	local LOGTYPE_ERROR = 3
	local DEFAULTS_FOR_LOGTYPE = {
		[LOGTYPE_DEFAULT] = FUNNEL,
		[LOGTYPE_WARNING] = ECHO_AND_FUNNEL,
		[LOGTYPE_ERROR] = ECHO_AND_FUNNEL,
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
	"]] .. SPRING_ECHO .. [[" - uses Spring.Echo
	"]] .. FUNNEL ..      [[" - logs the message into funnel-log.txt
	"]] .. SEPARATE ..    [[" - logs the message into a sepearate file log_[log-group name].txt
	"]] .. IGNORE ..      [[" (or any other string) - ignore the message completely
	the values can be combined by putting "+" between them, eg.: "]] .. SPRING_ECHO .. [[+]] .. FUNNEL .. [[ "
	
Additionally, the log-group can be an array of values that determine how to treat different types of log messages:
	{ [default], [warning], [error] } 
If the array is not large enough (or log-group is missing entirely), the default values are:
	{ "]] .. FUNNEL .. [[", "]] .. SPRING_ECHO .. [[+]] .. FUNNEL .. [[", "]] .. SPRING_ECHO .. [[+]] .. FUNNEL .. [[" }
This default can be overriden by giving the new default values as settings for log-group "default".
If it is not an array, it is equivalent to an array with a single value.
]]
	
	local handlers = {
		[ SPRING_ECHO ] = function(logGroup, logType, msg)
			Spring.Echo((({
				[LOGTYPE_DEFAULT] = "Log",
				[LOGTYPE_WARNING] = "Warning",
				[LOGTYPE_ERROR] = "ERROR",
			})[logType] or "Log") .. " " .. logGroup .. ": " .. msg)
		end,
		[ FUNNEL ] = function(logGroup, logType, msg)
			funnelFile:write("[f=" .. string.format("%07d", getGameFrame()) .. ",g=" .. logGroup .. "] " .. (logType == LOGTYPE_ERROR and "ERROR: " or "") .. msg .. "\n")
			funnelFile:flush()
		end,
		[ SEPARATE ] = function(logGroup, logType, msg)
			local file = io.open(LOG_PATH .. "log_" .. logGroup .. ".txt", "a") 
			file:write("[f=" .. string.format("%07d", getGameFrame()) .. "] " .. (logType == LOGTYPE_ERROR and "ERROR: " or "") .. msg .. "\n")
			file:close()
		end,
	}

	function internalLog(logGroup, logType, ...)
		local message = ""
		for i,v in ipairs({ ... }) do
			message = message .. (type(v) == "string" and v or dump(v))
		end
		
		if(not Logger.settings[logGroup])then
			Logger.settings[logGroup] = FUNNEL
		end
		local settingForGroup = Logger.settings[logGroup]
		if(type(settingForGroup) ~= "table")then
			settingForGroup = { settingForGroup }
		end
		local defaultSetting = Logger.settings["default"] or {};
		if(type(defaultSetting) ~= "table")then
			defaultSetting = { defaultSetting }
		end
		local handlerNames = settingForGroup[logType] or defaultSetting[logType] or DEFAULTS_FOR_LOGTYPE[logType] or ECHO_AND_FUNNEL
		for name in handlerNames:gmatch("[^+]+") do
			local handler = handlers[name:match "^%s*(.-)%s*$"]
			if(handler)then
				handler(logGroup, logType, message)
			end
		end
	end
	
	--- Logs the message under the supplied log-group.
	function Logger.log(
			logGroup, -- specifies the log-group under which the message belongs
			... -- the rest of the arguments forms the message after their conversion to string
		)
		internalLog(logGroup, LOGTYPE_DEFAULT, ...)
	end
	--- Logs the warning message under the supplied log-group.
	function Logger.warn (
			logGroup, -- specifies the log-group under which the message belongs
			... -- the rest of the arguments forms the warning message after their conversion to string
		)
		internalLog(logGroup, LOGTYPE_WARNING, ...)
	end
	--- Logs the error message under the supplied log-group.
	function Logger.error(
			logGroup, -- specifies the log-group under which the message belongs
			... -- the rest of the arguments forms the error message after their conversion to string
		)
		internalLog(logGroup, LOGTYPE_ERROR, ...)
	end
	
	--- Disables the logging of the specified log-group.
	function Logger.disable(logGroup)
		Logger.settings[logGroup] = IGNORE
	end
	
	return Logger
end)