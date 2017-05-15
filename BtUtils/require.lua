
-- TODO: finish


function require()
	if(mame)then
		return vratit_to
	end
	
	if(rekurze)then
	  return makeSurrogate(function() return vratit_to end)
	end
	VFS.Include(..., context)
end

function include()
	VFS.Include(..., context)
end

function load()
	local topContext = getfenv(2) -- get callers context
	-- IDEA: maybe try to iterate through stack until we find a widget
	context = vyrobit_kontext
	
	context.require = require
	context.include = include
	context.mapPath = function(path) root + path end
	
	return setmetatable({}, {
		__index = function(t,k) return rawget(context, k) end,
		__newindex = function(t,k,v) return rawset(context, k, v) end,
		__pairs = function(...) return pairs(context) end,
	})
end

