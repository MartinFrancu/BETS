local Sentry = {}

function isEventKey(key)
	return type(key) == "string" and key:sub(1, 2) == "On"
end

local eventHandlerPrototype = {
	Invoke = function(self, ...)
		for _, event in ipairs(self) do
			local result = event(...)
			if(result)then
				return result
			end
		end
		return nil
	end
}
local eventHandlerMetatable = {
	__index = eventHandlerPrototype
}

function Sentry:New(t, events)
	local t = t or {}
	local events = events or {}

	-- setting is handled by the , because we want to translate that to adding additional event handler
	-- getting is handled by, so that the __index on the t can directly delegate and only if the
	--     field not available, it then creates an empty array so that the caller can add/try to remove/call it
	
	setmetatable(t, {
		__index = events, -- pass the lookup directly to the events
		__newindex = function(self, key, value)
			-- intercept setting an event and add the events to preexisting ones
			if(isEventKey(key))then
				-- if someone assings a function directly, convert it to an array singleton
				if(type(value) == "function")then
					value = { value }
				end
				
				-- find out if the event is already set (and bypass its possible creation in __index)
				local handlers = rawget(events, key)
				if(handlers)then
					-- merge the two tables
					for i, v in ipairs(value) do
						handlers:insert(v)
					end
				else
					-- extend the supplied value into an eventHandler
					setmetatable(value, eventHandlerMetatable)
				
					-- supply the table as there is not one already
					events[key] = value
				end
			else
				-- keep the property on the main object if it is not an event
				rawset(self, key, value) -- use rawset to prevent calling this method again
			end
		end
	})

	setmetatable(events, {
		__index = function(self, key)
			-- intercept getting a non-set event and produce an empty array
			if(isEventKey(key))then
				-- create an empty eventHandler
				local result = setmetatable({}, eventHandlerMetatable)
				self[key] = result
				return result
			else
				return nil -- not event, remains nil
			end
		end
	})
	
	return t, events
end

return Sentry