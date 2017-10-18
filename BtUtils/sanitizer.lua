--- Provides methods that can sanitize function for a particular widget.
-- That includes all call-ins and any call that cross widget boundaries, due to proxy object or events. The sanitization itself means that various errors are reported through @{Logger.error} and it causes the appropriate widget to fail.
-- @classmod Sanitizer
-- @alias sanitizerPrototype
-- @remark Any handlers passed to @{Chili} should be explicitly sanitized.

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

local Utils = BtUtils
return Utils:Assign("Sanitizer", function()
	local Sanitizer = {}
	
	local Debug = Utils.Debug
	local Logger = Debug.Logger
	
	local getWidgetCaller = Debug.getWidgetCaller
	
	local sanitizationEnvironment = {
		xpcall = xpcall,
		unpack = unpack,
		table = table,
		error = error,
	}
	
	local isRemovedField = {} -- a handle
	
	local function sanitize(widget, f, rethrow)
		return setfenv(function(...)
			-- we do not call the function if we are already removed, instead returning false (which the caller may interpret as some kind of failure)
			if(not rethrow and widget[isRemovedField])then
				return false
			end
		
			local p = {...}
			local err
			local r = { xpcall(function() return f(unpack(p)) end, function(e) Logger.error(widget:GetInfo().name, e) err = e end) }
			if(r[1])then
				table.remove(r, 1)
				return unpack(r)
			else
				if(rethrow)then
					error(err)
				else
					widget.widgetHandler:RemoveWidget(widget) -- we cannot use widgetHandler directly, because that would be a proxy to widgetHandler of the widget that runs this file (which may be a different one)
				end
				return nil
			end
		end, sanitizationEnvironment)
	end

	
	local originalKey = {} -- a handle
	local exportKey = {} -- a handle
	local sanitizerPrototype = {}
	--- Sanitizes the function.
	-- @func f The function to be sanitized
	-- @treturn func The sanitized eclosure of function `f`.
	function sanitizerPrototype:Sanitize(f)
		return sanitize(self.widget, f)
	end
	local function exportInternal(self, t, seen)
		if(seen[t])then
			return seen[t]
		end
	
		local exported = {}
		seen[t] = exported
		
		local result = {}
		for k, v in pairs(t) do
			if(type(v) == "function")then
				result[k] = self:Sanitize(v)
			elseif(type(v) == "table" and v[originalKey] == nil)then
				result[k] = exportInternal(self, v, seen)
			else
				result[k] = v
			end
		end
		
		exported[originalKey] = t
		exported[exportKey] = result
		exported.Get = function() return t end -- for debug purposes
		
		return exported;
	end
	--- Exports a table, as in creates a copy of it, that when first passed through @{Sanitizer:Import} is safe to use over widget boundaries.
	-- Useful when making interface objects.
	-- @tab t Table to be exported.
	-- @return A so-called foreign copy of `t`.
	-- @usage WG.MyInterfaceObject = sanitizer:Export(MyInterfaceObject)
	function sanitizerPrototype:Export(t)
		return exportInternal(self, t, {})
	end
	
	local function importInternal(self, foreign, seen)
		if(seen[foreign])then
			return seen[foreign]
		end	

		local exportTable = foreign[exportKey]
		if(not exportTable)then
			Logger.error("sanitizer", "Attempt to import a table that was not exported before.")
		end
		local original = foreign[originalKey]
		
		local result = {}
		seen[foreign] = result
		for k, v in pairs(exportTable) do
			if(type(v) == "table")then
				result[k] = importInternal(self, v, seen)
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
	--- Imports an object previously exported using @{Sanitizer:Export} so that it can be safely used within the widget the @{Sanitizer} was created for.
	-- @param foreign A so-called foreign copy of an object created through a call to @{Sanitizer:Export} (using a different @{Sanitizer} instance)
	-- @return Imported object with all of the methods and functionality (e.g. @{Sentry}) of the previously exported object.
	-- @usage local MyInterfaceObject
	-- ...
	-- MyInterfaceObject = sanitizer:Import(WG.MyInterfaceObject)
	function sanitizerPrototype:Import(foreign)
		return importInternal(self, foreign, {})
	end
	
	--- Alias to @{Sanitizer:Sanitize}.
	-- @function AsHandler
	-- @param f See @{Sanitizer:Sanitize}
	-- @return See @{Sanitizer:Sanitize}
	-- @set no_return_or_parms=false -- unfortunately doesn't work
	sanitizerPrototype.AsHandler = sanitizerPrototype.Sanitize
	--- Alias to @{Sanitizer.sanitizeWidget}.
	function sanitizerPrototype:SanitizeWidget()
		return Sanitizer.sanitizeWidget(self.widget)
	end
	
	local sanitizerMetatable = { __index = sanitizerPrototype }
	--- Creates a sanitizer for the specified widget.
	-- @static
	-- @tparam widget widget The widget for which to create the sanitizer.
	-- @treturn Sanitizer the created sanitizer
	function Sanitizer.forWidget(widget)
		return setmetatable({ widget = widget }, sanitizerMetatable)
	end
	--- Creates a sanitizer for a widget that is closest to this call in the call chain.
	-- @static
	-- @treturn Sanitizer the created sanitizer
	-- @see getWidgetCaller
	function Sanitizer.forCurrentWidget()
		return Sanitizer.forWidget(getWidgetCaller())
	end
	
	local function isUpper(s)
		return s:lower() ~= s
	end
	--- Sanitizes all function and call-ins of the widget.
	-- It makes sure that any errors generated by the widget are reported to Logger, as opposed to the standard error handling of SpringRTS's widget system.
	-- @static
	-- @tparam widget widget The widget that should be sanitized.
	-- @remark It should be called only after all other widget setup code gets executed, which usually means the end of the script.
	function Sanitizer.sanitizeWidget(widget)
		local protectedMethods = { GetInfo = true }
		for k, v in pairs(widget) do
			if(type(k) == "string" and type(v) == "function" and isUpper(k:sub(1,1)) and not protectedMethods[k])then
				Logger.log("sanitize", "Sanitizing ", widget:GetInfo().name, ".", k)
				local f = sanitize(widget, v, k == "Shutdown")
				if(k == "Shutdown")then
					local sanitized = f
					f = function(...) widget[isRemovedField] = true; return sanitized(...) end
				end
				widget[k] = f
			end
		end
	end

	--- Sanitizes the specified function automatically.
	-- It uses the environment that we get through @{getfenv} to find out which widget the function is coming from.
	-- @static
	-- @func f The function to sanitize.
	-- @treturn func The sanitized eclosure of function `f`.
	-- @remark When the sanitized enclosure is passed in as `f`, it is directly returned and does not enclose it again.
	function Sanitizer.sanitize(f)
		local widget = getfenv(f)
		
		-- check whether the function is not already sanitized
		if(widget == sanitizationEnvironment)then
			return f
		end
		
		-- check that the environemnt is truly a widget
		if(not widget.widget or not widget.widgetHandler)then
			error("The environment of the function is not a widget and cannot be automatically sanitized. You can sanitize it yourself using sanitizer:Sanitize() or mark it as sanitized using Sanitizer.ignore(f).")
		end

		-- acquire the true widget, as the environment may only be "inheriting" from it
		widget = widget.widget
		
		return sanitize(widget, f);
	end

	--- Marks the specified function as not needing to be sanitized.
	-- @static
	-- @func f The function to ignore.
	-- @treturn func The function `f` marked as sanitized.
	function Sanitizer.ignore(f)
		local environment = getfenv(f)
		
		-- check whether the function is not already sanitized (or ignored)
		if(environment == sanitizationEnvironment)then
			return f
		end
		
		return setfenv(function(...) return f(...) end, sanitizationEnvironment)
	end	
	return Sanitizer
end)
