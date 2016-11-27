--- Provides mechanisms to resolve dependencies and defer actions until specified dependencies are fulfilled.
-- @module Dependency
-- @pragma nostrip

if(not BtUtils)then VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST) end

local Utils = BtUtils

return Utils:Assign("Dependency", function()
	local Dependency = {}

	local Logger = Utils.Debug.Logger
	
	-- the actual table that stores the dependency identifiers
	local dependencies = {}

	--- Postpones the execution of a function until all specified dependencies are fulfilled.
	-- @func f Function, that should be executed.
	-- @tparam Dependency ... A list of dependencies that need to be fulfilled.
	-- @remark If all dependencies are fulfilled at the time of the call, the function is executed synchronously. Otherwise, it is executed once the last dependency gets fulfilled.
	function Dependency.defer(f, ...)
		local unfulfilledCount = 0
		local unfulfilled = {}
	
		for i, v in ipairs({...}) do
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
	-- @remark Only using @{Dependency.defer} within the `Initialize` method of a widget is not enough, as the individual call-ins are still present and could be executed. And as they could end up being executed before the actual `Initialize` code gets executed, it would produce errors. Hence always use @{Dependency.deferWidget} if deferring the widget as a whole is required.
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
	
		Dependency.defer(function()
			dependenciesFulfilled = true
			if(initializeTriggered)then
				Logger.log("dependency", "Defered widget initialization due to dependency.")
				initialize(widget)
			else
				Logger.log("dependency", "Widget dependency fulfilled before initialization.")
			end
		end, ...)
	end
	
	function Dependency.fill(dependency)
		if(dependency.filled)then return end
		dependency.filled = true
		
		for i, v in ipairs(dependency) do
			v()
		end
	end
	
	setmetatable(Dependency, {
		__index = function(self, key)
			local firstCharacter = key:sub(1,1)
			if(firstCharacter:lower() == firstCharacter)then
				return nil
			end
			
			local result = {}
			self[key] = result
			return result
		end,
	})
	
	return Dependency
end)
