--- .
-- .
-- @classmod Promise

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end;

local Utils = BtUtils
return Utils:Assign("Promise", function()
	local Promise = {}
	
	local Sanitizer = Utils.Sanitizer
	
	local promisePrototype = {}
	function promisePrototype:Fulfill(...)
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
	
	function Promise:New(t)
		return setmetatable(t or {}, promiseMetatable)
	end
	
	
	Promise.fulfilled = Promise:New({ fulfilled = true })
	function Promise.fromCallback(f, ...)
		local p = Promise:New()
		local args = { ... }
		table.insert(args, Sanitizer.ignore(function(...) p:Fulfill(...) end))
		f(unpack(args))
		return p
	end
	
	return Promise
end)
