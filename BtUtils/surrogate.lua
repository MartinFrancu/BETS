--- Provides capability to construct an object that acts as another, even when the other object doesn't exist yet.
-- Until an object actually starts existing, the only thing you cannot do with a surrogate, is call it. Reading slots produces more surrogates. Can be used to resolve cyclic dependencies.
-- @classmod Surrogate

local newproxy = newproxy or getfenv(0).newproxy

local Surrogate = {}

--- Checks, whether the given object is a @{Surrogate}.
-- Even if the instance itself is an instance of @{Surrogate}, it will return false if the object for whom the surrogate was created already exists.
-- @static
-- @param o Object to check.
-- @treturn bool `true` if it is a surrogate, `false` if it is an actual object
function Surrogate.isSurrogate(o)
	local mt = getmetatable(o)
	if(not mt or not mt._checkSurrogate)then return false end
	
	return mt._checkSurrogate()
end

--- Creates a surrogate for function that returns the object or `nil`.
-- @static
-- @func accessor Function that attempts to find the object the surrogate is made for.
-- @treturn Surrogate The created surrogate
-- @remark Making surrogates to surrogate is not supported.
function Surrogate:New(accessor)
	local t = accessor()
	if(t)then
		return t
	end
	
	local subsurrogates = {}
	local written = {}
	local surrogate = setmetatable({}, {}) --newproxy(true)
	
	local replace
	local metatable = getmetatable(surrogate)
	metatable.__index = function(self, key)
		local t = accessor()
		if(t)then
			replace(t)
			return self[key]
		else
			local result = written[key]
			if(result)then return result end
			result = subsurrogates[key]
			if(result)then return result end
			
			result = Surrogate:New(function()
				return (accessor() or {})[key]
			end)
			subsurrogates[key] = result
			return result
		end
	end
	metatable.__newindex = function(self, key, value)
		local t = accessor()
		if(t)then
			replace(t)
			self[key] = value
		else
			written[key] = value
		end
	end
	metatable.__call = function(self, ...)
		local t = accessor()
		if(t)then
			replace(t)
			return self(...)
		else
			error("Call attempted on a surrogate object.")
		end
	end
	metatable._checkSurrogate = function()
		local t = accessor()
		if(t)then
			replace(t)
			return false
		else
			return true
		end
	end
	metatable._isSurrogate = true
	
	function replace(t)
		metatable._checkSurrogate = function() return false end
		metatable._isSurrogate = false
		metatable.__index = t
		metatable.__newindex = t
		metatable.__call = function(self, ...) return t(...) end
		if(type(t) == "table" or type(t) == "userdata")then
			for k, v in pairs(written) do
				t[k] = v
			end
			metatable.__call = nil
		end
		metatable.__tostring = function(self) return tostring(t) end
		
		for k, v in pairs(subsurrogates) do
			getmetatable(v)._checkSurrogate()
		end
	end
	
	return surrogate
end

return Surrogate