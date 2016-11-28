--- Table that is synchronized with a specific file.
-- @classmod FileTable
-- @alias result
-- @usage
-- local config = FileTable:New("config.lua")
-- config.__comment = "Configuration of the program"
--
-- -- prints the last time the program was executed
-- print(os.date("*t", config.lastRunTime))
--
-- -- stores the current time for next time
-- config.lastTime = os.time()
-- -- no further actions are necessary, the file is saved immediately

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

local dump = BtUtils.Debug.dump
local FileTable = {}

--- Creates a new instance of a @{FileTable} mapped to the specified file.
-- @remark The file cannot access any of the standard functions, as its envorinmont is overriden to be an empty table. That makes it safe, as it cannot access parts of a code it shouldn't touch, but it also isn't capable of using any standard functions -- meaning it has to be pure data.
-- @constructor
-- @return @{FileTable}
function FileTable:New(
		path -- path within the VFS corresponding to a Lua data file
	)
	local t = VFS.FileExists(path) and VFS.Include(path, {}, VFS.RAW_FIRST) or {}
	local result = {}
	--- Replacement to using the regular @{pairs} method.
	-- This is necessary as one could otherwise not iterate over the keys due to the way @{FileTable} is internally implemented.
	function result:Pairs()
		return pairs(t)
	end
	--- Forces the writing of the file.
	-- @remark It should usually not be necessary to call this method as the file gets saved whenever any change occurs. It might only be needed if the file holds nested tables and a change occurs there.
	function result:Flush()
		local outputFile = io.open(path, "w")
		outputFile:write("return {\n")
		if(t.__comment)then
			outputFile:write("\t-- " .. t.__comment:gsub("^\n", ""):gsub("\n$", ""):gsub("\n", "\n\t-- ") .. "\n\n")
		end
		for k, v in pairs(t) do
			if(k:sub(1, 2) ~= "__")then
				outputFile:write("\t[" .. dump(k) .. "] = " .. dump(v, 10) .. ",\n")
			end
		end
		outputFile:write("}\n")
		outputFile:close()
	end
	
	local mt = {
		__tostring = function(self) return tostring(t) end,
		__pairs = result.Pairs,
		__index = t,
		__newindex = function(self, key, value)
			t[key] = value
			self:Flush()
		end,
	}
	
	return setmetatable(result, mt)
end

--- Whenever any assignment is made to this table, it is immediatelly written to the associated file.
-- @table FileTable.
-- @field[1] __comment String that should be used as a comment on the beggining of the file.
-- @field[2] ... anything not containing cycles

return FileTable