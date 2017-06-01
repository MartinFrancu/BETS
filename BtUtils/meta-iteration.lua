--- .
-- .
-- @module metaIteration

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end;

local Utils = BtUtils

local metanext = Utils:Assign("metanext", function()
	local metanext
	
	--- Function associated with @{metapairs}. Does one iteration step.
	function metanext(
			state, -- state of the iteration as returned by @{metapairs}
			key -- the current key
		)
		local result
		if(state.next)then
			result = { state.next(state.current, key) }
		else
			result = { next(state.current, key) }
		end
		
		if(result[1] ~= nil)then
			for _, t in ipairs(state.stack) do
				if(rawget(t, result[1]) ~= nil)then
					return metanext(state, result[1]) -- tail recursion, so it should be okay to skip items this way
				end	
			end
			return unpack(result)
		elseif(state.next)then
			return nil -- don't go deeper if we used a specific __pairs method
		else
			local mt = getmetatable(state.current)
			if(not mt or type(mt) ~= "table")then
				return nil
			end
			
			table.insert(state.stack, state.current)
			if(mt.__pairs)then
				state.next, state.current, key = mt.__pairs(state.current)
			elseif(type(mt.__index) == "table")then
				state.current, key = mt.__index, nil;
			else
				return nil
			end
			
			return metanext(state, key)
		end
	end
	
	return metanext
end)

local metapairs = Utils:Assign("metapairs", function()
	local metapairs
	
	--- Iterates not only through the regular pairs, but also over the pairs of a metatable.`__index`, recursively
	function metapairs(
			t -- a table to iterate over.
		)
		if(type(t) == "userdata")then
			local mt = getmetatable(t)
			if(not mt or type(mt.__index) ~= "table")then
				return function() return nil end
			end
			t = mt.__index;
		end
		return metanext, { current = t, stack = {} }, nil
	end
	
	return metapairs
end)

return metanext, metapairs
