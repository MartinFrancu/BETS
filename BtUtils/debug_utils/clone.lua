--- Function for creating a shallow-copy of a table.
-- @module clone

local clone

--- Creates a shallow-copy of the given table.
-- @param obj table for which to construct the shallow-copy
-- @return a shallow-copy of `obj`
function clone(obj)
	if type(obj) ~= 'table' then return obj end
	local res = setmetatable({}, getmetatable(obj))
	for k, v in pairs(obj) do
		res[k] = v
	end
	return res
end

return clone