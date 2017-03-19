--- Provides methods that can sanitize widget calls.
-- That includes all call-ins and any call that cross widget boundaries, due to proxy object or events. The sanitization itself means that various errors are reported through @{Logger.error} and it causes the appropriate widget to fail.
-- @module Sanitizer
-- @pragma nostrip

-- tag @pragma makes it so that the name of the module is not stripped from the function names

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

local Utils = BtUtils
return Utils:Assign("Sanitizer", function()
	local Sanitizer = {}
	
	local Debug = Utils.Debug
	local Logger = Debug.Logger
	
	function sanitize(widget, f, rethrow)
		return function(...)
			local p = {...}
			local err
			local r = { xpcall(function() return f(unpack(p)) end, function(e) Logger.error(widget:GetInfo().name, e) err = e end) }
			if(r[1])then
				table.remove(r, 1)
				return unpack(r)
			else
				if(rethrow)then
					error(unpack(err))
				else
					widget.widgetHandler:RemoveWidget(widget) -- we cannot use widgetHandler directly, because that would be a proxy to widgetHandler of the widget that runs this file (which may be a different one)
				end
				return nil
			end
		end
	end

	
	local originalKey = {} -- a handle
	local exportKey = {} -- a handle
	local sanitizerPrototype = {}
	function sanitizerPrototype:Sanitize(f)
		return sanitize(self.widget, f)
	end
	function sanitizerPrototype:Export(t)
		local result = {}
		for k, v in pairs(t) do
			if(type(v) == "function")then
				result[k] = self:Sanitize(v)
			elseif(type(v) == "table")then
				result[k] = self:Export(v)
			else
				result[k] = v
			end
		end
		
		return {
			[originalKey] = t,
			[exportKey] = result,
		}
	end
	function sanitizerPrototype:Import(foreign)
		local exportTable = foreign[exportKey]
		if(not result)then
			Logger.error("sanitizer", "Attempt to import a table that was not exported before.")
		end
		local original = foreign[originalKey]
		
		local result
		for k, v in pairs(t) do
			if(type(v) == "table")then
				result[k] = self:Import(v)
			else
				result[k] = v
			end
		end
		
		-- correct handling for Sentry-like objects
		setmetatable(result, {
			__index = original,
			__newindex = function(t, key, value)
				if(type(value) == "function")then
					value = self:Sanitize(value)
				end
				original[key] = value
			end,
		})
		
		return result
	end
	sanitizerPrototype.AsHandler = sanitizerPrototype.Sanitize
	function sanitizerPrototype:SanitizeWidget()
		return Sanitizer.sanitizeWidget(self.widget)
	end
	
	local sanitizerMetatable = { __index = sanitizerPrototype }
	function Sanitizer.forWidget(widget)
		return setmetatable({ widget = widget }, sanitizerMetatable)
	end
	
	local function isUpper(s)
		return s:lower() ~= s
	end
	function Sanitizer.sanitizeWidget(widget)
		local protectedMethods = { GetInfo = true }
		for k, v in pairs(widget) do
			if(type(k) == "string" and type(v) == "function" and isUpper(k:sub(1,1)) and not protectedMethods[k])then
				Logger.log("sanitize", "Sanitizing ", widget:GetInfo().name, ".", k)
				widget[k] = sanitize(widget, v, k == "Shutdown")
			end
		end
	end
	
	return Sanitizer
end)
