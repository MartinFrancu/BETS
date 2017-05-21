--- .
-- .
-- @module async

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end;

local Utils = BtUtils
return Utils:Assign("async", function()
	local async
	
	local Promise = Utils.Promise
	
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
