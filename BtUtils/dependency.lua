--- Provides mechanisms to resolve dependencies and defer actions until specified dependencies are fulfilled.
-- @module Dependency
-- @pragma nostrip

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

local Utils = BtUtils

return Utils:Assign("Dependency", function()
	--- Accessible fields.
	-- @table Dependency.
	-- @field A_Z__name__ Any key with a capital first letter represents a @{Dependency} that can be used to track what dependencies are fulfilled and allows the postponing of execution of functions and widgets.
	local Dependency = {}

	local Sanitizer = Utils.Sanitizer
	
	local Logger = Utils.Debug.Logger
	local dump = Utils.Debug.dump
	
	-- the actual table that stores the dependency identifiers
	local dependencies = {}

	--- Postpones the execution of a function until all specified dependencies are fulfilled.
	-- @func onFill Function, that should be executed once all dependencies are fulfilled.
	-- @func onClear Optional parameter; function, that should be executed after @{onFill} has been called and at least one dependency is cleared.
	-- @tparam Dependency ... A list of dependencies that need to be fulfilled.
	-- @remark If all dependencies are fulfilled at the time of the call, the @{onFill} function is executed synchronously. Otherwise, it is executed once the last dependency gets fulfilled. The @{onClear} function is executed only if the @{onFill} function was already called, meaning it is not called if the dependencies are not fulfilled initially. Once at least one dependancy is cleared, the @{onFill} function may again be called once it is fulfilled again. If you want to disable this behaviour, you can do that be returning `false` in the {onClear} function.
	function Dependency.defer(onFill, onClear, ...)
		local f, dependencies
		onFill = Sanitizer.sanitize(onFill)
		if(type(onClear) ~= "function")then
			dependencies = { onClear, ... }
			f = onFill
		else
			dependencies = { ... }
			onClear = Sanitizer.sanitize(onClear)
			f = function()
				onFill()
				
				local clearedAlready = false
				local function clearDeferer()
					if(not clearedAlready)then
						if(onClear() ~= false)then -- don't repeat only if the onClear method explicitly disables it
							Dependency.defer(onFill, onClear, unpack(dependencies))
						end
						clearedAlready = true
					end
				end
				for i, v in ipairs(dependencies) do
					table.insert(v, clearDeferer)
				end
			end
		end
		-- TODO: correctly deal with multiple dependencies and both `onFill` and `onClear`: right now, if any dependency is already filled and is later cleared, it is not identified properly
		
		local unfulfilledCount = 0
		local unfulfilled = {}
	
		for i, v in ipairs(dependencies) do
			if(not v.filled)then
				unfulfilledCount = unfulfilledCount + 1
				table.insert(unfulfilled, v)
			end
		end

		if(unfulfilledCount == 0)then
			Logger.log("dependency", "Dependencies fulfilled already.")
			f()
		elseif(unfulfilledCount == 1)then
			Logger.log("dependency", "Single unfulfilled dependency.")
			table.insert(unfulfilled[1], f)
		else
			Logger.log("dependency", "Multiple unfulfilled dependencies.")
			local function deferer()
				unfulfilledCount = unfulfilledCount - 1
				if(unfulfilledCount == 0)then
					f()
				end
			end
			
			for i, v in ipairs(unfulfilled) do
				table.insert(v, deferer)
			end
		end
	end

	local function isUpper(s)
		return s:lower() ~= s
	end
	
	--- Postpones the initialization and execution of a widget until all specified dependencies are fulfilled.
	-- Also automatically removes the widget once the dependency is cleared.
	-- This function has to be called only after all other widget setup code gets executed, which usually means the end of the script.
	-- @tparam Widget widget Widget that is dependent to the dependencies.
	-- @tparam Dependency ... A list of dependencies that need to be fulfilled.
	-- @remark Only using @{Dependency.defer} within the `Initialize` method of a widget is not enough, as the individual call-ins are still present and could be executed. And as they could end up being executed before the actual `Initialize` code gets executed, it would produce errors. Hence always use @{Dependency.deferWidget} if deferring the widget as a whole is required.
	-- @usage Dependency.deferWidget(widget, Dependency.CustomName)
	function Dependency.deferWidget(widget, ...)
		local dependenciesFulfilled = false
		local initializeTriggered = false
		local initialize = widget.Initialize
		function widget.Initialize(...)
			initializeTriggered = true
			if(dependenciesFulfilled)then
				initialize(...)
			end
		end
		local protectedMethods = { Initialize = true, GetInfo = true }
		for k, v in pairs(widget) do
			if(type(k) == "string" and type(v) == "function" and isUpper(k:sub(1,1)) and not protectedMethods[k])then
				widget[k] = function(...)
					if(dependenciesFulfilled)then
						return v(...)
					end
				end
			end
		end
		
		local sanitizer = Sanitizer.forWidget(widget)
		
		Dependency.defer(sanitizer:Sanitize(function()
			dependenciesFulfilled = true
			if(initializeTriggered)then
				Logger.log("dependency", "Deferred widget ", widget:GetInfo().name, " initialization due to dependency.")
				initialize(widget)
			else
				Logger.log("dependency", "Widget ", widget:GetInfo().name, " dependency fulfilled before initialization.")
			end
		end), sanitizer:Sanitize(function()
			Logger.log("dependency", "Removing widget ", widget:GetInfo().name, ".")
			widget.widgetHandler:RemoveWidget(widget) -- we cannot use widgetHandler directly, because that would be a proxy to widgetHandler of the widget that runs this file (which may be a different one)
			return false -- disable repeating of the onFill handler
		end), ...)
		
		return widget
	end
	
	--- Marks the specified dependency as fulfilled.
	-- Any functions defered because of only this dependency ends up being executed synchronously.
	-- @tparam Dependency dependency The dependency to mark as fulfilled.
	-- @usage Dependency.fill(Dependency.CustomName)
	function Dependency.fill(dependency)
		if(dependency.filled)then return end
		
		local handlers = {}
		for i, v in ipairs(dependency) do
			handlers[i] = v
		end
		table.clear(dependency)
		dependency.filled = true
		for i, v in ipairs(handlers) do
			v()
		end
	end
	--- Marks the specified dependency as no longer fulfilled.
	-- Any functions defered because of only this dependency that provided onClear function ends up being executed synchronously.
	-- @tparam Dependency dependency The dependency to mark as not fulfilled.
	-- @usage Dependency.fill(Dependency.CustomName)
	function Dependency.clear(dependency)
		if(not dependency.filled)then return end
		
		local handlers = {}
		for i, v in ipairs(dependency) do
			handlers[i] = v
		end
		table.clear(dependency)
		dependency.filled = false
		for i, v in ipairs(handlers) do
			v()
		end
	end
	
	setmetatable(Dependency, {
		__index = function(self, key)
			local firstCharacter = key:sub(1,1)
			if(firstCharacter:lower() == firstCharacter)then
				return nil
			end
			
			local result = { name = key }
			self[key] = result
			return result
		end,
	})
	
	return Dependency
end)
