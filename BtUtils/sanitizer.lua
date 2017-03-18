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
	
	local function safeWrap(widget, name, f)
		return function(...)
			local p = {...}
			local err
			local r = { xpcall(function() f(unpack(p)) end, function(e) Logger.error(widget:GetInfo().name, e) err = e end) }
			if(r[1])then
				table.remove(r, 1)
				return unpack(r)
			else
				if(name == "Shutdown")then
					error(unpack(err))
				else
					widget.widgetHandler:RemoveWidget(widget) -- we cannot use widgetHandler directly, because that would be a proxy to widgetHandler of the widget that runs this file (which may be a different one)
				end
				return nil
			end
		end
	end
	
	function Sanitizer.forWidget(widget)
		return {
			handler = function(f) return safeWrap(widget, nil, f) end,
			sanitize = function() return Sanitizer.sanitizeWidget(widget) end,
		}
	end
	
	local function isUpper(s)
		return s:lower() ~= s
	end
	function Sanitizer.sanitizeWidget(widget)
		local protectedMethods = { GetInfo = true }
		for k, v in pairs(widget) do
			if(type(k) == "string" and type(v) == "function" and isUpper(k:sub(1,1)) and not protectedMethods[k])then
				widget[k] = safeWrap(widget, name, v)
			end
		end
		
	end
	
	return Sanitizer
end)
