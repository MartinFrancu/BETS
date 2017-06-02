-- alters the normal JSON, that throw exceptions, to return errors in the form of false, message

local JSON = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/JSON_friedl.lua")

local errorMessage
function JSON.assert(success, message)
	if(not success)then
		errorMessage = message
	end
end

return setmetatable({}, {
	__index = function(self, key)
		local value = JSON[key]
		if(type(value) == "function")then
			local replacement = function(otherSelf, ...)
				if(otherSelf == self)then
					otherSelf = JSON
				end
				
				local success = value(otherSelf, ...)
				if(success)then
					return success
				else
					return false, errorMessage
				end
			end
			rawset(self, key, replacement)
			return replacement
		end
		return value
	end,
})