--- Allows the table to contain events at which others can register their handlers.
-- The functionality is seamless, as in any key that starts with `On` ends up being interpreted as an event, for purposes of registering and for purposes of calling.
--
-- There is also a special handling to make setting of handlers easier -- it is only necessary to assign a function or a table of functions to the event key and they get automatically appended to the already existing event handler list.
-- @classmod Sentry
-- @usage
-- local MyObject = Sentry:New()
--
-- -- append a two custom event handlers to the OnAction name
-- MyObject.OnAction = function(f)
--   print("acted 1")
--   return f
-- end
-- MyObject.OnAction = function(f)
--   print("acted 2")
-- end
--
-- -- invoke the event handlers
-- MyObject.OnAction:Invoke(false) -- invokes both
-- MyObject.OnAction:Invoke(true)  -- invokes only the first one
-- -- the execution of the second one is cancelled because the first one returned true

--- Accessible fields.
-- @table Sentry.
-- @tfield EventHandler|func|{func,...} On__name__ list of event handlers when accessed, function or a list of functions that appends to the event handler list when assigned to
-- @remark The @{EventHandler}s do not need to be created, they are formed when accessed for the first time.
local Sentry = {}

function isEventKey(key)
	return type(key) == "string" and key:sub(1, 2) == "On"
end

--- Represents a set of functions that handle an event.
-- @type EventHandler
local eventHandlerPrototype = {}
--- Invokes the execution of all registered functions, until one returns a non-false result.
function eventHandlerPrototype:Invoke(
		... -- any parameters that may be expected by the handlers themselves
	)
	for _, event in ipairs(self) do
		local result = event(...)
		if(result)then
			return result
		end
	end
	return nil
end

local eventHandlerMetatable = {
	__index = eventHandlerPrototype
}
--- @section end

--- Creates new instance of @{Sentry}.
-- @constructor
-- @tab t preexisting table to convert into a @{Sentry} or `nil`
-- @tparam {[string]=EventHandler} events preexisting table of event handlers or `nil`
-- @treturn Sentry
-- @treturn {[string]=EventHandler} `events` parameter or a newly created table altered in such a way, that any key starting with `On` creates a new EventHandler set
-- @remark The second return value, corresponding to the `events` parameter, should not be directly exposed to the user, as its functionality is already presented in the @{Sentry} itself.
function Sentry:New(t, events)
	local t = t or {}
	local events = events or {}

	-- setting is handled by the metatable, because we want to translate that to adding additional event handler
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