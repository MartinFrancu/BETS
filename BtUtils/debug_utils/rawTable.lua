--- Function that produces a view of a table that disregards __index metamethod (as in uses `rawget` only for accessing it).
-- @module rawTable

local rawTable

--- Produces an alternate view of the given table that diregards __index metamethod.
-- This is equivalent to a situation where we would only use rawget on the original table. The original table is not modified in any way.
function rawTable(t)
	return setmetatable({}, {
		__index = function(_, key) return rawget(t, key) end, -- retrieves only the directly stored value
		__newindex = function() error("Attempt to write to a read-only rawTable.") end, -- disallow an writing to the resulting table
		__pairs = function() return pairs(t) end, -- iterates only through the directly stored key-value pairs
	})
end

return rawTable