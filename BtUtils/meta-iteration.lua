--- .
-- .
-- @module metaIteration

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end;

local Utils = BtUtils

local metanext = Utils:Assign("metanext", function()
	local metanext
	
	function metanext(state, key)
		local k, v = next(state.current, key)
		if(k ~= nil)then
			return k, v
		else
			local mt = getmetatable(state.current)
			if(not mt or type(mt) ~= "table" or type(mt.__index) ~= "table")then
				return nil
			end
			state.current = mt.__index;
			return metanext(state, nil)
		end
	end
	
	return metanext
end)

local metapairs = Utils:Assign("metapairs", function()
	local metapairs
	
	--- Iterates not only through the regular pairs, but also over the pairs of a metatable
	function metapairs(t)
		if(type(t) == "userdata")then
			local mt = getmetatable(t)
			if(not mt or type(mt.__index) ~= "table")then
				return function() return nil end
			end
			t = mt.__index;
		end
		return metanext, { current = t }, nil
	end
	
	return metapairs
end)

return metanext, metapairs
