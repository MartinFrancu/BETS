--- Object that encapsulates a value or an outlook of there might possibly be a value.
-- Essentially an object that can be assigned a callback.
-- @classmod Promise
-- @alias promisePrototype

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end;

local Utils = BtUtils
return Utils:Assign("Promise", function()
	local Promise = {}
	
	local Sanitizer = Utils.Sanitizer
	
	local promisePrototype = {}
	--- Marks promise as fulfilled and fills it with values.
	-- @remark Each promise can be fulfilled only once.
	function promisePrototype:Fulfill(
			... -- values that should be stored in the promise
		)
		if(self.chain)then
			return self.chain:Fulfill(...)
		end
		
		if(self.fulfilled)then
			error("Cannot fulfill an already fulfilled promise.", 2)
		end
		
		if(self.callback)then
			self.callback(...)
		end
		
		self.fulfilled = { ... }
	end
	--- Schedules a callback that should be executed once the promise gets fullfilled.
	-- The callback may be executed synchronously if the promise is already fulfilled.
	-- @func f The callback will be called with the value of the promise.
	-- @remark Can also be invoked as a call to the promise, as in instead of `p:Then(f)`, you may use `p(f)`
	function promisePrototype:Then(f)
		if(self.fulfilled)then
			return f(unpack(self.fulfilled)) or Promise.fulfilled
		end
	
		if(self.callback)then
			error("There is already a callback attached to this promise and only one is allowed.", 2)
		end
		local thenResult = Promise:New()
		self.callback = function(...)
			local callbackResult = f(...)
			if(not callbackResult)then
				thenResult:Fulfill()
			else
				callbackResult:Chain(thenResult)
			end
		end
		return thenResult
	end
	--- Chains current promise to another one.
	-- @tparam Promise other
	function promisePrototype:Chain(other)
		while(other.chain)do
			other = other.chain
		end
			
		if(self.fulfilled)then
			return other:Fulfill(unpack(self.fulfilled))
		end
	
		if(self.chain)then
			error("Cannot chain an already chained promise.", 2)
		end
		if(self.callback)then
			error("Cannot chain a promise with a callback.", 2)
		end
		
		self.chain = other
		self.callback = function(...) other:Fulfill(...) end
	end
	
	local promiseMetatable = {
		__index = promisePrototype,
		__call = promisePrototype.Then,
	}
	
	--- Creates a promise.
	-- @static
	-- @tab[opt] t Optional parameters.
	-- @treturn Promise The created promise.
	function Promise:New(t)
		return setmetatable(t or {}, promiseMetatable)
	end
	

	---	An already fulfilled, but empty promise.
	-- @static
	Promise.fulfilled = Promise:New({ fulfilled = true })
	
	--- Creates a promise that represents result from a function that utilizes a callback.
	-- The function has to expect its callback as a last parameters after all of the parameters that have been used to call this function.
	-- @static
	-- @func f Function that returns its result through a callback. The regular return values are ignored.
	-- @param ... List of parameters to `f` without the last one.
	-- @treturn @{Promise} A promise representing the result of `f` that is given to its callback.
	-- @usage function doSomething(data)
	--   ...
	-- end
	-- 
	-- f(a,b,c,d, doSomething) -- regular call of f with a callback
	--
	-- local p = Promise.fromCallback(f, a,b,c,d) -- a call of f, that gives us a promise
	-- p:Then(doSomething) -- schedule the actual callback
	function Promise.fromCallback(f, ...)
		local p = Promise:New()
		local args = { ... }
		table.insert(args, Sanitizer.ignore(function(...) p:Fulfill(...) end))
		f(unpack(args))
		return p
	end
	
	return Promise
end)
