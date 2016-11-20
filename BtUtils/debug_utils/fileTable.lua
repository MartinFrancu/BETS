--- fileTable
-- @script fileTable

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

local dump = BtUtils.Debug.dump
local fileTable

--- fileTable
-- @return @{FileTable}
function fileTable(
		path -- path within the VFS
	)
	local t = VFS.FileExists(path) and VFS.Include(path, {}, VFS.RAW_FIRST) or {}
	local result = {
		Pairs = function(self) return pairs(t) end,
		Flush = function(self)
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
		end,
	}
	local mt = {
		__metatable = "locked",
		__tostring = function(self) return tostring(t) end,
		__pairs = result.Pairs,
		__index = t,
		__newindex = function(self, key, value)
			t[key] = value
			self:Flush()
		end,
	}
	setmetatable(result, mt)
	return result
end

--- FileTable
-- @table FileTable
-- @field[1] __comment String that should be used as a comment on the beggining of the file.
-- @field[2] ... anything

return fileTable