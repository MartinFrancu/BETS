--- Function for outputting the contents of a table.
-- @module dump

local dump

--- Serializes the given table to a lua-readable form.
-- @tab o asfasf
-- @int[opt] maxDepth asfa
-- @remark It is preferable that the graph of the tables that are to be serialized should not contain cycles. If it does, @{dump} might end up producing duplicite output.
function dump(o, maxDepth)
	maxDepth = maxDepth or 1
	if type(o) == 'table' then
		if (maxDepth == 0) then 
			return "..." 
		end
		if (o.name ~= nil) then -- For outputing chili objects
			return o.name
		end
		local s = '{ '
		for k,v in (o.pairs or pairs)(o) do
			 s = s .. '['..dump(k, 0)..'] = ' .. dump(v, maxDepth-1) .. ','
		end
		return s .. '} '
	elseif type(o) == 'string' then
		return string.format("%q", o)
	else
		return tostring(o)
	end
end

return dump