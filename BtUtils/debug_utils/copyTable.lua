--- Function for creating a deep-copy of a table.
-- @module copyTable

local copyTable

--- Creates a deep-copy of the given table.
-- @param obj table for which to construct the deep-copy
-- @param[opt={}] seen _(optional)_ set of already seen objects in the tree; used for recursion
-- @return a deep-copy of `obj`
function copyTable(obj, seen)
	if type(obj) ~= 'table' then return obj end
	if seen and seen[obj] then return seen[obj] end
	local s = seen or {}
	local res = setmetatable({}, getmetatable(obj))
	s[obj] = res
	for k, v in pairs(obj) do res[copyTable(k, s)] = copyTable(v, s) end
	return res
end

return copyTable