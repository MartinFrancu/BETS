--- Provides the capability to write sequential code that works asynchronously.
-- For the specifics how the type of usage this emulates, see @{C# async}
-- @module async

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end;

local Utils = BtUtils
return Utils:Assign("async", function()
	local async
	
	local Promise = Utils.Promise

	---	Alters the given function to work asynchronously.
	-- @func f Function that should be altered.
	-- @treturn func The altered function that can be called. The function itself then doesn't return its return values normally, but in a form of a @{Promise}.
	-- @remark When `f` is called altered using this function, it can call functions `await`, resp. `awaitFunction` to postpone itself until a promise is fulfilled, resp. a callback is called.
	-- @usage myFunction = async(function(a)
	--   local result = awaitFunction(Dialog.showDialog, { message = a, ... })
	--   return result and true or false
	-- end)
	-- 
	-- myOtherFunction = async(function())
	--   Spring.Echo("Before")
	--   if(await(myFunction("Hello")))then
	--     Spring.Echo("Hello.")
	--   end
	--   if(await(myFunction("Goodbye")))then
	--     Spring.Echo("After Goodbye.")
	--   end
	-- end)
	function async(f)
		return function(...)
			local resultPromise = Promise:New()
			local c = coroutine.wrap(function(...)
				resultPromise:Fulfill(f(...))
				return resultPromise
			end)
			
			local function await(p)
				local state = 0
				local results
				p:Then(function(...)
					if(state == 1)then
						c(...)
					else
						results = { ... }
					end
					state = 2
				end)
				if(state == 2)then
					return unpack(results)
				else
					state = 1
					return coroutine.yield(resultPromise)
				end
			end
			local function awaitFunction(f, ...)
				return await(Promise.fromCallback(f, ...))
			end
			
			-- the environment change can safely happen even after the wrap
			local oldEnvironment = getfenv(f)
			setfenv(f, setmetatable({
				Promise = Promise,
				await = await,
				awaitFunction = awaitFunction,
			}, { __index = oldEnvironment, __newindex = oldEnvironment }))
			
			return c(...)
		end
	end
	
	return async
end)
