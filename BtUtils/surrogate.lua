--- .
-- @classmod Surrogate

-- TODO: finish

local newproxy = newproxy or getfenv(0).newproxy

local Surrogate = {}

function Surrogate.isSurrogate(o)
	local mt = getmetatable(o)
	if(not mt or not mt._checkSurrogate)then return false end
	
	return mt._checkSurrogate()
end

--- .
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